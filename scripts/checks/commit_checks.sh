#!/bin/bash


set -euo pipefail

TARGET_BRANCH="${TARGET_BRANCH:-main}"
RESULTS_DIR="${RESULTS_DIR:-results}"

while [[ $# -gt 0 ]]; do
    case $1 in
        --target) TARGET_BRANCH="$2"; shift 2 ;;
        --results) RESULTS_DIR="$2"; shift 2 ;;
        *) shift ;;
    esac
done

FAILED=0
RESULT_FILE="${RESULTS_DIR}/03_commit_checks.txt"

echo "Commit Message Checks" > "$RESULT_FILE"
echo "=====================" >> "$RESULT_FILE"
echo "" >> "$RESULT_FILE"

# Get commits in PR
COMMITS=$(git log --format=%H "origin/${TARGET_BRANCH}..HEAD" 2>/dev/null || \
          git log --format=%H "${TARGET_BRANCH}..HEAD" 2>/dev/null || \
          echo "")

if [[ -z "$COMMITS" ]]; then
    echo "⚠ No commits found to check" | tee -a "$RESULT_FILE"
    exit 0
fi

COMMIT_COUNT=$(echo "$COMMITS" | wc -l)
echo "Checking $COMMIT_COUNT commit(s)..." | tee -a "$RESULT_FILE"
echo "" >> "$RESULT_FILE"

# Check each commit
while IFS= read -r commit; do
    [[ -z "$commit" ]] && continue
    
    MSG=$(git log --format=%B -n 1 "$commit")
    SUBJECT=$(echo "$MSG" | head -n1)
    COMMIT_SHORT=$(git log --format=%h -n 1 "$commit")
    COMMIT_AUTHOR=$(git log --format='%an' -n 1 "$commit")
    
    echo "Commit: $COMMIT_SHORT - $COMMIT_AUTHOR" | tee -a "$RESULT_FILE"
    echo "Subject: $SUBJECT" >> "$RESULT_FILE"
    
    HAS_ISSUES=0
    
    # Check 1: Subject line length (max 72 chars)
    if [[ ${#SUBJECT} -gt 72 ]]; then
        echo "   WARN: Subject line too long (${#SUBJECT} chars, recommended max 72)" | tee -a "$RESULT_FILE"
        HAS_ISSUES=1
    fi
    
    # Check 2: Subject should not end with period
    if [[ "$SUBJECT" =~ \.$ ]]; then
        echo "  WARN: Subject line should not end with period" | tee -a "$RESULT_FILE"
        HAS_ISSUES=1
    fi
    
    # Check 3: Blank line after subject (if body exists)
    LINE_COUNT=$(echo "$MSG" | wc -l)
    if [[ $LINE_COUNT -gt 1 ]]; then
        SECOND_LINE=$(echo "$MSG" | sed -n '2p')
        if [[ -n "$SECOND_LINE" ]]; then
            echo "  ⚠ WARN: Missing blank line after subject" | tee -a "$RESULT_FILE"
            HAS_ISSUES=1
        fi
    fi
    
    # Check 4: Signed-off-by (REQUIRED)
    if ! echo "$MSG" | grep -q "^Signed-off-by:"; then
        echo "   FAIL: Missing 'Signed-off-by:' line" | tee -a "$RESULT_FILE"
        echo "    Add with: git commit --amend --signoff" >> "$RESULT_FILE"
        FAILED=1
        HAS_ISSUES=1
    fi
    
    # Check 5: Empty commit message
    if [[ -z "$SUBJECT" ]] || [[ "$SUBJECT" =~ ^[[:space:]]*$ ]]; then
        echo "   FAIL: Empty commit message" | tee -a "$RESULT_FILE"
        FAILED=1
        HAS_ISSUES=1
    fi
    
    if [[ $HAS_ISSUES -eq 0 ]]; then
        echo "   Commit message format OK" | tee -a "$RESULT_FILE"
    fi
    
    echo "" >> "$RESULT_FILE"
    
done <<< "$COMMITS"

# Summary
echo "Summary" >> "$RESULT_FILE"
echo "-------" >> "$RESULT_FILE"
if [[ $FAILED -eq 0 ]]; then
    echo "✓ All commit checks PASSED" | tee -a "$RESULT_FILE"
else
    echo "✗ Commit checks FAILED (missing Signed-off-by)" | tee -a "$RESULT_FILE"
fi

exit $FAILED
