#!/bin/bash
# pr_checker.sh - Main script for PR testing

set -e

# Load common functions
source "${SCRIPT_DIR}/scripts/common.sh"

# Read list of PRs to test
if [ ! -f "${WORKSPACE}/prs_to_test.txt" ]; then
    echo "No PRs to test"
    exit 0
fi

prs_to_test=($(cat "${WORKSPACE}/prs_to_test.txt"))
echo "Testing ${#prs_to_test[@]} PRs"

# Process each PR
for pr_number in "${prs_to_test[@]}"; do
    pr_info=$(cat "${WORKSPACE}/pr_${pr_number}.json")
    pr_commit=$(echo "$pr_info" | jq -r '.commit')
    pr_title=$(echo "$pr_info" | jq -r '.title')
    pr_target=$(echo "$pr_info" | jq -r '.target')
    
    echo "========================================="
    echo "Testing PR #${pr_number}: ${pr_title}"
    echo "Commit: ${pr_commit}"
    echo "Target: ${pr_target}"
    echo "========================================="
    
    # Setup directories
    target_dir="${WORKSPACE}/pr-${pr_number}"
    results_dir="${WORKSPACE}/results-${pr_number}"
    
    rm -rf "${target_dir}" "${results_dir}"
    mkdir -p "${target_dir}" "${results_dir}"
    
    # Clone PR code
    echo "Cloning PR code..."
    git_clone_pr "${pr_number}" "${pr_commit}" "${target_dir}" "${pr_target}"
    
    # Post start comment to GitHub
    post_pr_comment "${pr_number}" "${pr_commit}" "started" "${results_dir}"
    
    # Get changed files
    changed_files=$(get_changed_files "${pr_number}")
    echo "Changed files: $(echo "$changed_files" | wc -l)"
    echo "$changed_files" > "${results_dir}/changed_files.txt"
    
    # Run checks
    echo "Running checks..."
    
    # Create a summary file
    summary_file="${results_dir}/summary.txt"
    echo "# PR #${pr_number} Check Results" > "${summary_file}"
    echo "" >> "${summary_file}"
    echo "PR: #${pr_number}" >> "${summary_file}"
    echo "Title: ${pr_title}" >> "${summary_file}"
    echo "Commit: ${pr_commit}" >> "${summary_file}"
    echo "Target: ${pr_target}" >> "${summary_file}"
    echo "" >> "${summary_file}"
    
    # Run all checks in the checks directory
    overall_status=0
    
    echo "## Check Results" >> "${summary_file}"
    echo "" >> "${summary_file}"
    
    # Run basic checks first
    if [ -f "${SCRIPT_DIR}/scripts/checks/basic_checks.sh" ]; then
        echo "Running basic checks..."
        check_output_file="${results_dir}/basic_checks_output.txt"
        
        export PR_NUMBER=${pr_number}
        export PR_COMMIT=${pr_commit}
        export PR_TARGET=${pr_target}
        export TARGET_DIR=${target_dir}
        export RESULTS_DIR=${results_dir}
        export CHANGED_FILES="${results_dir}/changed_files.txt"
        
        if "${SCRIPT_DIR}/scripts/checks/basic_checks.sh" > "${check_output_file}" 2>&1; then
            echo "✅ Basic Checks: PASSED" >> "${summary_file}"
        else
            check_status=$?
            echo "❌ Basic Checks: FAILED (exit code: ${check_status})" >> "${summary_file}"
            overall_status=1
        fi
    fi
    
    # Run all other checks
    for check_script in "${SCRIPT_DIR}/scripts/checks/"*; do
        if [[ "${check_script}" != *"basic_checks.sh" && -f "${check_script}" && -x "${check_script}" ]]; then
            check_name=$(basename "${check_script}" | sed 's/\.[^.]*$//')
            echo "Running ${check_name}..."
            check_output_file="${results_dir}/${check_name}_output.txt"
            
            export PR_NUMBER=${pr_number}
            export PR_COMMIT=${pr_commit}
            export PR_TARGET=${pr_target}
            export TARGET_DIR=${target_dir}
            export RESULTS_DIR=${results_dir}
            export CHANGED_FILES="${results_dir}/changed_files.txt"
            
            if "${check_script}" > "${check_output_file}" 2>&1; then
                echo "✅ ${check_name}: PASSED" >> "${summary_file}"
            else
                check_status=$?
                echo "❌ ${check_name}: FAILED (exit code: ${check_status})" >> "${summary_file}"
                overall_status=1
            fi
        fi
    done
    
    echo "" >> "${summary_file}"
    if [ ${overall_status} -eq 0 ]; then
        echo "# Overall Result: PASSED ✅" >> "${summary_file}"
    else
        echo "# Overall Result: FAILED ❌" >> "${summary_file}"
    fi
    
    # Post final comment to GitHub
    state=$([ ${overall_status} -eq 0 ] && echo "success" || echo "failure")
    post_pr_comment "${pr_number}" "${pr_commit}" "${state}" "${results_dir}"
    
    # Archive results
    echo "Archiving results..."
    
    # Update cache
    cache_key="${pr_number}-${pr_commit}"
    update_cache "${cache_key}" "${overall_status}" "${pr_title}" "${pr_info}"
    
    # Cleanup
    rm -rf "${target_dir}"
done
