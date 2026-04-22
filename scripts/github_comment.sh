#!/bin/bash

# GitHub PR Comment Script
# Usage: github_comment.sh --pr <number> --comment <text> [--file <file>]

set -e

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --pr)
            PR_NUMBER="$2"
            shift 2
            ;;
        --comment)
            COMMENT_TEXT="$2"
            shift 2
            ;;
        --file)
            COMMENT_FILE="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate required parameters
if [ -z "$PR_NUMBER" ]; then
    echo "Usage: $0 --pr <number> --comment <text> [--file <file>]"
    echo ""
    echo "Examples:"
    echo "  $0 --pr 123 --comment 'Test comment'"
    echo "  $0 --pr 123 --file comment.md"
    exit 1
fi

# Set defaults
GITHUB_API="${GITHUB_API:-https://api.github.com}"
GITHUB_REPO="${GITHUB_REPO:-Bhuvan409/Meta-tisdk}"
HTTP_PROXY="${HTTP_PROXY:-}"

# Check for GitHub token
if [ -z "$GITHUB_TOKEN" ]; then
    echo "ERROR: GITHUB_TOKEN environment variable not set"
    exit 1
fi

# Read comment from file if provided
if [ -n "$COMMENT_FILE" ] && [ -f "$COMMENT_FILE" ]; then
    COMMENT_TEXT=$(cat "$COMMENT_FILE")
fi

if [ -z "$COMMENT_TEXT" ]; then
    echo "ERROR: No comment text provided"
    exit 1
fi

echo "Posting comment to PR #${PR_NUMBER}..."

# Create temporary file for JSON payload
TEMP_JSON=$(mktemp)
trap "rm -f $TEMP_JSON" EXIT

# Escape and create JSON payload using Python
python3 << EOF > "$TEMP_JSON"
import json
import sys

comment_text = """$COMMENT_TEXT"""

payload = {
    "body": comment_text
}

print(json.dumps(payload))
EOF

# Make API call
RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" \
     ${HTTP_PROXY:+--proxy "$HTTP_PROXY"} \
     -X POST \
     -H "Authorization: token $GITHUB_TOKEN" \
     -H "Accept: application/vnd.github.v3+json" \
     -H "Content-Type: application/json" \
     "$GITHUB_API/repos/$GITHUB_REPO/issues/$PR_NUMBER/comments" \
     -d @"$TEMP_JSON")

# Parse response
HTTP_CODE=$(echo "$RESPONSE" | grep "HTTP_CODE:" | cut -d: -f2)
RESPONSE_BODY=$(echo "$RESPONSE" | sed '/HTTP_CODE:/d')

# Check result
if [ "$HTTP_CODE" = "201" ]; then
    echo "✓ Successfully posted comment to PR #${PR_NUMBER}"
    
    # Extract comment URL if possible
    COMMENT_URL=$(echo "$RESPONSE_BODY" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('html_url', ''))" 2>/dev/null || echo "")
    
    if [ -n "$COMMENT_URL" ]; then
        echo "Comment URL: $COMMENT_URL"
    fi
    
    exit 0
elif [ "$HTTP_CODE" = "403" ]; then
    echo "✗ Failed to post comment (HTTP 403 - Forbidden)"
    echo "Response: $RESPONSE_BODY"
    echo ""
    echo "This usually means:"
    echo "1. Token lacks required permissions"
    echo "2. Repository access is restricted"
    echo "3. Rate limit exceeded"
    exit 1
elif [ "$HTTP_CODE" = "401" ]; then
    echo "✗ Authentication failed (HTTP 401)"
    echo "Token is invalid or expired"
    exit 1
elif [ "$HTTP_CODE" = "404" ]; then
    echo "✗ PR not found (HTTP 404)"
    echo "Check if PR #${PR_NUMBER} exists in ${GITHUB_REPO}"
    exit 1
else
    echo "✗ Failed to post comment (HTTP $HTTP_CODE)"
    echo "Response: $RESPONSE_BODY"
    exit 1
fi
