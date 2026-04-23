#!/bin/bash
# common.sh - Common functions for PR checker scripts

# Function to make GitHub API calls with proxy settings
curl_github() {
    curl -x "${HTTP_PROXY}" --proxy-header "User-Agent: curl/7.58.0" "$@" \
         -H "Authorization: token ${GITHUB_TOKEN}" \
         -H "Accept: application/vnd.github.v3+json"
}

# Function to clone a PR
git_clone_pr() {
    local pr_number=$1
    local pr_commit=$2
    local target_dir=$3
    local pr_target=$4
    
    git clone --depth 1 \
        --branch "pr/${pr_number}" \
        --single-branch \
        "${TARGET_REPO_URL}" \
        "${target_dir}" || true
    
    cd "${target_dir}"
    git fetch origin "pull/${pr_number}/head:pr/${pr_number}"
    git checkout "${pr_commit}"
    git fetch origin "${pr_target}:${pr_target}"
}

# Function to get changed files in a PR
get_changed_files() {
    local pr_number=$1
    
    response=$(curl_github -s "${GITHUB_API}/repos/${GITHUB_REPO}/pulls/${pr_number}/files?per_page=100")
    echo "$response" | jq -r '.[].filename'
}

# Function to post a comment to a PR
post_pr_comment() {
    local pr_number=$1
    local pr_commit=$2
    local state=$3
    local results_dir=$4
    
    comment_file="${WORKSPACE}/comment-${pr_number}.txt"
    
    if [ "${state}" == "started" ]; then
        cat > "${comment_file}" << EOF
## PR Checker Started

PR: #${pr_number}
Commit: ${pr_commit:0:7}
Running checks...
EOF
    else
        # Use summary file if it exists
        if [ -f "${results_dir}/summary.txt" ]; then
            cat "${results_dir}/summary.txt" > "${comment_file}"
            
            # Add detailed results
            echo -e "\n## Detailed Check Results\n" >> "${comment_file}"
            
            # Add each check output as a collapsible section
            for output_file in "${results_dir}"/*_output.txt; do
                if [ -f "${output_file}" ]; then
                    check_name=$(basename "${output_file}" | sed 's/_output\.txt$//')
                    echo -e "<details>\n<summary>${check_name}</summary>\n" >> "${comment_file}"
                    echo -e "\`\`\`" >> "${comment_file}"
                    cat "${output_file}" >> "${comment_file}"
                    echo -e "\`\`\`\n</details>\n" >> "${comment_file}"
                fi
            done
        else
            # Fallback if summary doesn't exist
            if [ "${state}" == "success" ]; then
                echo "## PR Checker - PASSED ✅" > "${comment_file}"
            elif [ "${state}" == "failure" ]; then
                echo "## PR Checker - FAILED ❌" > "${comment_file}"
            else
                echo "## PR Checker - ERROR ⚠️" > "${comment_file}"
            fi
            
            echo -e "\nPR: #${pr_number}" >> "${comment_file}"
            echo "Commit: ${pr_commit:0:7}" >> "${comment_file}"
        fi
        
        # Add footer
        echo -e "\n---\nJenkins Build: [${BUILD_NUMBER}](${BUILD_URL}console)" >> "${comment_file}"
        echo "Timestamp: $(date '+%Y-%m-%d %H:%M:%S')" >> "${comment_file}"
    fi
    
    # Post the comment
    curl_github -s -X POST \
        "${GITHUB_API}/repos/${GITHUB_REPO}/issues/${pr_number}/comments" \
        -d @- << EOF
{
  "body": $(jq -R -s '.' < "${comment_file}")
}
EOF
}

# Function to update the cache
update_cache() {
    local cache_key=$1
    local status=$2
    local title=$3
    local pr_info=$4
    
    if [ -f "${CACHE_FILE}" ]; then
        cache=$(cat "${CACHE_FILE}")
    else
        cache="{}"
    fi
    
    result=$([ ${status} -eq 0 ] && echo "PASSED" || echo "FAILED")
    
    cache=$(echo "${cache}" | jq --arg key "${cache_key}" \
                               --arg timestamp "$(date '+%Y-%m-%d %H:%M:%S')" \
                               --arg result "${result}" \
                               --arg title "${title}" \
                               --arg author "$(echo ${pr_info} | jq -r '.author')" \
                               '.[$key] = {timestamp: $timestamp, result: $result, title: $title, author: $author}')
    
    echo "${cache}" > "${CACHE_FILE}"
}
