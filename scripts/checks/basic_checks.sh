#!/bin/bash

set -euo pipefail

TARGET_BRANCH="${TARGET_BRANCH:-main}"
RESULTS_DIR="${RESULTS_DIR:-results}"
RESULT_FILE="${RESULTS_DIR}/basic_checks.txt"
FAILED=0

# Create results directory if it doesn't exist
mkdir -p "$RESULTS_DIR"

get_changed_files() {
    git diff --name-only "origin/${TARGET_BRANCH}...HEAD" 2>/dev/null || echo ""
}

echo "Basic Checks" > "$RESULT_FILE"
echo "============" >> "$RESULT_FILE"
echo "" >> "$RESULT_FILE"

# File size check
echo "Checking file sizes..." | tee -a "$RESULT_FILE"
MAX_SIZE=$((10 * 1024 * 1024))  # Fixed: Use * instead of _

while IFS= read -r file; do
    [[ -z "$file" || ! -f "$file" ]] && continue
    
    # Handle both Linux (stat -c) and macOS (stat -f)
    SIZE=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo 0)
    
    if [[ $SIZE -gt $MAX_SIZE ]]; then
        echo "FAIL: $file exceeds 10MB (size: $SIZE bytes)" | tee -a "$RESULT_FILE"
        FAILED=1
    fi
done < <(get_changed_files)

echo "" >> "$RESULT_FILE"

# Binary files check
echo "Checking binary files..." | tee -a "$RESULT_FILE"

while IFS= read -r file; do
    [[ -z "$file" || ! -f "$file" ]] && continue
    
    # Skip known binary file types
    [[ "$file" =~ \.(png|jpg|jpeg|gif|pdf|tar|gz|bz2|xz|zip)$ ]] && continue
    
    if file "$file" 2>/dev/null | grep -qi "executable\|binary"; then
        echo "FAIL: Unwanted binary: $file" | tee -a "$RESULT_FILE"
        FAILED=1
    fi
done < <(get_changed_files)

echo "" >> "$RESULT_FILE"

# Line endings check
echo "Checking line endings..." | tee -a "$RESULT_FILE"

while IFS= read -r file; do
    [[ -z "$file" || ! -f "$file" ]] && continue
    
    # Only check specific file types
    [[ "$file" =~ \.(bb|bbappend|bbclass|inc|conf|sh|py)$ ]] || continue
    
    if file "$file" 2>/dev/null | grep -q "CRLF"; then
        echo "FAIL: $file has CRLF line endings" | tee -a "$RESULT_FILE"
        FAILED=1
    fi
done < <(get_changed_files)

echo "" >> "$RESULT_FILE"

# Shell syntax check
echo "Checking shell scripts..." | tee -a "$RESULT_FILE"

while IFS= read -r file; do
    [[ -z "$file" || ! -f "$file" ]] && continue
    
    if ! bash -n "$file" 2>&1 | tee -a "$RESULT_FILE"; then
        echo "FAIL: Shell syntax error in $file" | tee -a "$RESULT_FILE"
        FAILED=1
    fi
done < <(get_changed_files | grep '\.sh$')  # Fixed: Proper regex end anchor

echo "" >> "$RESULT_FILE"

# Python syntax check
echo "Checking Python files..." | tee -a "$RESULT_FILE"

while IFS= read -r file; do
    [[ -z "$file" || ! -f "$file" ]] && continue
    
    if ! python3 -m py_compile "$file" 2>&1 | tee -a "$RESULT_FILE"; then
        echo "FAIL: Python syntax error in $file" | tee -a "$RESULT_FILE"
        FAILED=1
    fi
done < <(get_changed_files | grep '\.py$')  # Fixed: Proper regex end anchor

echo "" >> "$RESULT_FILE"
echo "============" >> "$RESULT_FILE"

if [[ $FAILED -eq 0 ]]; then
    echo "All basic checks passed" | tee -a "$RESULT_FILE"
else
    echo "Some checks failed" | tee -a "$RESULT_FILE"
fi

exit $FAILED
