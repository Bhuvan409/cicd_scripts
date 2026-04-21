#!/bin/bash

set -euo pipefail

# GitHub configuration
GITHUB_API="${GITHUB_API:-https://api.github.com}"
GITHUB_REPO="${GITHUB_REPO:-Bhuvan409/Meta-tisdk}"

# Parse arguments
COMMIT=""
STATE=""
DESCRIPTION=""
URL="${BUILD_URL:-}"
CONTEXT="Jenkins PR Checker"

while [[ $# -gt 0 ]]; do
    case $1 in
        --commit) COMMIT="$2"; shift 2 ;;
        --state) STATE="$2"; shift 2 ;;
        --description) DESCRIPTION="$2"; shift 2 ;;
        --url) URL="$2"; shift 2 ;;
        --context) CONTEXT="$2"; shift 2 ;;
        *) shift ;;
    esac
done

# Validate required parameters
if [[ -z "$COMMIT" ]]; then
    echo "ERROR: --commit required"
    exit 1
fi

if [[ -z "$STATE" ]]; then
    echo "ERROR: --state required (pending|success|failure|error)"
    exit 1
fi

if [[ -z "$GITHUB_TOKEN" ]]; then
    echo "ERROR: GITHUB_TOKEN environment variable not set"
    exit 1
fi

# Validate state
case "$STATE" in
    pending|success|failure|error) ;;
    *)
        echo "ERROR: Invalid state '$STATE'. Must be: pending|success|failure|error"
        exit 1
        ;;
esac

# Build JSON payload
PAYLOAD=$(cat <<EOF
{
  "state": "${STATE}",
  "target_url": "${URL}",
  "description": "${DESCRIPTION}",
  "context": "${CONTEXT}"
}
EOF
)

# Post to GitHub API
echo "Updating GitHub status for commit ${COMMIT:0:7}..."
echo "State: ${STATE}"
echo "Description: ${DESCRIPTION}"

HTTP_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    -H "Content-Type: application/json" \
    "${GITHUB_API}/repos/${GITHUB_REPO}/statuses/${COMMIT}" \
    -d "${PAYLOAD}")

HTTP_CODE=$(echo "$HTTP_RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$HTTP_RESPONSE" | sed '$d')

# Check response
if [[ "$HTTP_CODE" =~ ^2[0-9][0-9]$ ]]; then
    echo "✓ GitHub status updated successfully"
    exit 0
else
    echo "✗ Failed to update GitHub status (HTTP ${HTTP_CODE})"
    echo "Response: ${RESPONSE_BODY}"
    exit 1
fi
