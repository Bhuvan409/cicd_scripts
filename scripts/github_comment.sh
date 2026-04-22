#!/bin/bash

# Simple GitHub PR Comment Script
# Usage: github_comment.sh --pr <number> --comment <text> [--file <file>]

set -e

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --pr) PR_NUMBER="$2"; shift 2 ;;
        --comment) COMMENT_TEXT="$2"; shift 2 ;;
        --file) COMMENT_FILE="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Validate
if [ -z "$PR_NUMBER" ]; then
    echo "Usage: $0 --pr <number> --comment <text> [--file <file>]"
    exit 1
fi

# Set defaults
GITHUB_API="${GITHUB_API:-https://api.github.com}"
GITHUB_REPO="${GITHUB_REPO:-Bhuvan409/Meta-tisdk}"
HTTP_PROXY="${HTTP_PROXY:-}"

# Check token
if [ -z "$GITHUB_TOKEN" ]; then
    echo "ERROR: GITHUB_TOKEN not set"
    exit 1
fi

# Read from file if provided
if [ -n "$COMMENT_FILE" ] && [ -f "$COMMENT_FILE" ]; then
    COMMENT_TEXT=$(cat "$COMMENT_FILE")
fi

if [ -z "$COMMENT_TEXT" ]; then
    echo "ERROR: No comment text provided"
    exit 1
fi

echo "Posting comment to PR #${PR_NUMBER}..."

# Create JSON payload
TEMP_JSON=$(mktemp)
trap "rm -f $TEMP_JSON" EXIT

python3 << EOF > "$TEMP_JSON"
import json
comment = """$COMMENT_TEXT"""
print(json.dumps({"body": comment}))
EOF

# Post comment
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
     ${HTTP_PROXY:+--proxy "$HTTP_PROXY"} \
     -X POST \
     -H "Authorization: token $GITHUB_TOKEN" \
     -H "Accept: application/vnd.github.v3+json" \
     -H "Content-Type: application/json" \
     "$GITHUB_API/repos/$GITHUB_REPO/issues/$PR_NUMBER/comments" \
     -d @"$TEMP_JSON")

# Check result
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)

if [ "$HTTP_CODE" = "201" ]; then
    echo "Comment posted successfully"
    exit 0
else
    echo "Failed to post comment (HTTP $HTTP_CODE)"
    exit 1
fi
