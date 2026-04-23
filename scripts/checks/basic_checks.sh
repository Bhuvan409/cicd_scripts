#!/bin/bash
# basic_checks.sh - Basic validation checks for all PRs

# This script runs basic validation checks on the PR
# Exit with non-zero status if any checks fail

# Environment variables available:
# - PR_NUMBER: PR number
# - PR_COMMIT: PR commit hash
# - PR_TARGET: Target branch
# - TARGET_DIR: Directory containing the PR code
# - RESULTS_DIR: Directory to store results
# - CHANGED_FILES: File containing list of changed files

# Change to the target directory
cd "${TARGET_DIR}"

echo "Running basic validation checks for PR #${PR_NUMBER}"
echo "Commit: ${PR_COMMIT}"
echo "Target branch: ${PR_TARGET}"

# Check for trailing whitespace
echo "Checking for trailing whitespace..."
files_with_whitespace=$(grep -l -r "[[:space:]]$" --include="*.bb" --include="*.bbappend" --include="*.inc" .)

if [ -n "${files_with_whitespace}" ]; then
    echo "❌ ERROR: Found trailing whitespace in the following files:"
    echo "${files_with_whitespace}"
    exit 1
fi

# Check for tabs in Python files
echo "Checking for tabs in Python files..."
files_with_tabs=$(grep -l -P "\t" --include="*.py" .)

if [ -n "${files_with_tabs}" ]; then
    echo "❌ ERROR: Found tabs in Python files (should be spaces):"
    echo "${files_with_tabs}"
    exit 1
fi

# Check for executable bit on non-script files
echo "Checking for executable bit on non-script files..."
find . -type f -executable -not -path "*/\.git/*" | grep -v "\.sh$" | grep -v "\.py$" > "${RESULTS_DIR}/executable_files.txt"

if [ -s "${RESULTS_DIR}/executable_files.txt" ]; then
    echo "❌ ERROR: Found non-script files with executable bit:"
    cat "${RESULTS_DIR}/executable_files.txt"
    exit 1
fi

echo "✅ All basic checks passed!"
exit 0
