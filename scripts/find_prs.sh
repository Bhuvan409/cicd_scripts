#!/bin/bash
# find_prs.sh - Find PRs that need testing

set -e

# Load common functions
source "${SCRIPT_DIR}/scripts/common.sh"

# Get open PRs from GitHub API
response=$(curl_github -s -w "\nHTTP_CODE:%{http_code}" \
    "${GITHUB_API}/repos/${GITHUB_REPO}/pulls?state=open&per_page=100")

http_code=$(echo "$response" | grep "HTTP_CODE:" | sed 's/HTTP_CODE://')
json_response=$(echo "$response" | grep -v "HTTP_CODE:")

if [ "$http_code" != "200" ]; then
    echo "GitHub API returned HTTP ${http_code}"
    echo "$json_response"
    exit 1
fi

# Parse JSON response to get PR info
prs_json=$(echo "$json_response" | jq '.')
pr_count=$(echo "$prs_json" | jq '. | length')

if [ "$pr_count" -eq 0 ]; then
    echo "NO_PRS_TO_TEST"
    exit 0
fi

echo "$pr_count"

# Load cache if exists
if [ -f "$CACHE_FILE" ]; then
    cache=$(cat "$CACHE_FILE")
else
    cache="{}"
fi

# Find PRs that need testing
prs_to_test=()
for i in $(seq 0 $(($pr_count - 1))); do
    pr_number=$(echo "$prs_json" | jq -r ".[$i].number")
    pr_sha=$(echo "$prs_json" | jq -r ".[$i].head.sha")
    pr_title=$(echo "$prs_json" | jq -r ".[$i].title")
    pr_author=$(echo "$prs_json" | jq -r ".[$i].user.login")
    pr_branch=$(echo "$prs_json" | jq -r ".[$i].head.ref")
    pr_target=$(echo "$prs_json" | jq -r ".[$i].base.ref")
    
    cache_key="${pr_number}-${pr_sha}"
    if ! echo "$cache" | jq -e ".[\"$cache_key\"]" > /dev/null 2>&1; then
        echo "PR #${pr_number}: ${pr_title} - NEEDS TESTING"
        # Save PR info to a file for pr_checker.sh to use
        echo "{\"number\": $pr_number, \"commit\": \"$pr_sha\", \"title\": \"$pr_title\", \"author\": \"$pr_author\", \"branch\": \"$pr_branch\", \"target\": \"$pr_target\"}" > "${WORKSPACE}/pr_${pr_number}.json"
        prs_to_test+=($pr_number)
    else
        echo "PR #${pr_number}: ${pr_title} - ALREADY TESTED"
    fi
done

if [ ${#prs_to_test[@]} -eq 0 ]; then
    echo "NO_PRS_TO_TEST"
    exit 0
fi

# Save list of PRs to test
echo "${prs_to_test[@]}" > "${WORKSPACE}/prs_to_test.txt"
