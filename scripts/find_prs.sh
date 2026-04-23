#!/bin/bash
# find_prs.sh - Find PRs that need testing

set -e

# Load common functions
source "${SCRIPT_DIR}/scripts/common.sh"

echo "Finding open PRs for ${GITHUB_REPO}..."

# Get open PRs from GitHub API
response=$(curl_github -s -w "\nHTTP_CODE:%{http_code}" \
    "${GITHUB_API}/repos/${GITHUB_REPO}/pulls?state=open&per_page=100")

http_code=$(echo "$response" | grep "HTTP_CODE:" | sed 's/HTTP_CODE://')
json_response=$(echo "$response" | grep -v "HTTP_CODE:")

echo "GitHub API HTTP response code: ${http_code}"

if [ "$http_code" != "200" ]; then
    echo "ERROR: GitHub API returned HTTP ${http_code}"
    echo "$json_response"
    exit 1
fi

# Debug: Print raw response
echo "DEBUG: Raw response from GitHub API:"
echo "$json_response" | head -20
echo "..."

# Parse JSON response to get PR info
if ! command -v jq &> /dev/null; then
    echo "ERROR: jq is not installed. Cannot parse JSON response."
    exit 1
fi

# Validate JSON response
if ! echo "$json_response" | jq . > /dev/null 2>&1; then
    echo "ERROR: Invalid JSON response from GitHub API"
    echo "$json_response"
    exit 1
fi

prs_json=$(echo "$json_response" | jq '.')
pr_count=$(echo "$prs_json" | jq '. | length')

echo "Found ${pr_count} open PR(s)"

if [ "$pr_count" -eq 0 ]; then
    echo "NO_PRS_TO_TEST"
    exit 0
fi

# Load cache if exists
cache="{}"
if [ -f "$CACHE_FILE" ]; then
    echo "Loading cache from ${CACHE_FILE}"
    cache=$(cat "$CACHE_FILE")
    
    # Validate cache JSON
    if ! echo "$cache" | jq . > /dev/null 2>&1; then
        echo "WARNING: Invalid cache JSON, resetting cache"
        cache="{}"
    fi
else
    echo "No cache file found, creating new cache"
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
    
    # Debug: Show cache check
    echo "DEBUG: Checking cache for key: ${cache_key}"
    
    # Check if PR is already in cache
    if echo "$cache" | jq -e ".[\"$cache_key\"]" > /dev/null 2>&1; then
        echo "PR #${pr_number}: ${pr_title} - ALREADY TESTED (found in cache)"
    else
        echo "PR #${pr_number}: ${pr_title} - NEEDS TESTING (not in cache)"
        # Save PR info to a file for pr_checker.sh to use
        pr_info="{\"number\": $pr_number, \"commit\": \"$pr_sha\", \"title\": \"$pr_title\", \"author\": \"$pr_author\", \"branch\": \"$pr_branch\", \"target\": \"$pr_target\"}"
        echo "$pr_info" > "${WORKSPACE}/pr_${pr_number}.json"
        prs_to_test+=($pr_number)
    fi
done

if [ ${#prs_to_test[@]} -eq 0 ]; then
    echo "All PRs have already been tested"
    echo "NO_PRS_TO_TEST"
    exit 0
fi

echo "Found ${#prs_to_test[@]} PR(s) that need testing: ${prs_to_test[@]}"

# Save list of PRs to test
echo "${prs_to_test[@]}" > "${WORKSPACE}/prs_to_test.txt"

# Output the number of PRs to test (for Jenkins to read)
echo "${#prs_to_test[@]}"
