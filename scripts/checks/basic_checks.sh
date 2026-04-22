#!/bin/bash
set -euo pipefail

TARGET_BRANCH="${TARGET_BRANCH:-main}"
RESULTS_DIR="${RESULTS_DIR:-results}"
RESULT_FILE="${RESULTS_DIR}/basic_checks.txt"
FAILED=0

get_changed_files() {
    git diff --name-only "origin/${TARGET_BRANCH}...HEAD" 2>/dev/null || echo ""
}

echo "Basic Checks" > "$RESULT_FILE"
echo "============" >> "$RESULT_FILE"

# File size check
echo "Checking file sizes..."
MAX_SIZE=$((10 * 1024 * 1024))
while IFS= read -r file; do
    [[ -z "$file" || ! -f "$file" ]] && continue
    SIZE=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo 0)
    if [[ $SIZE -gt $MAX_SIZE ]]; then
        echo "FAIL: $file exceeds 10MB" | tee -a "$RESULT_FILE"
        FAILED=1
    fi
done < <(get_changed_files)

# Binary files check
echo "Checking binary files..."
while IFS= read -r file; do
    [[ -z "$file" || ! -f "$file" ]] && continue
    [[ "$file" =~ \.(png|jpg|jpeg|gif|pdf|tar|gz|bz2|xz|zip)$ ]] && continue
    if file "$file" 2>/dev/null | grep -qi "executable\|binary"; then
        echo "FAIL: Unwanted binary: $file" | tee -a "$RESULT_FILE"
        FAILED=1
    fi
done < <(get_changed_files)

# Line endings check
echo "Checking line endings..."
while IFS= read -r file; do
    [[ -z "$file" || ! -f "$file" ]] && continue
    [[ "$file" =~ \.(bb|bbappend|bbclass|inc|conf|sh|py)$ ]] || continue
    if file "$file" 2>/dev/null | grep -q "CRLF"; then
        echo "FAIL: $file has CRLF line endings" | tee -a "$RESULT_FILE"
        FAILED=1
    fi
done < <(get_changed_files)

# Shell syntax check
echo "Checking shell scripts..."
while IFS= read -r file; do
    [[ -z "$file" || ! -f "$file" ]] && continue
    if ! bash -n "$file" 2>/dev/null; then
        echo "FAIL: Shell syntax error in $file" | tee -a "$RESULT_FILE"
        FAILED=1
    fi
done < <(get_changed_files | grep '\.sh
```)

# Python syntax check
echo "Checking Python files..."
while IFS= read -r file; do
    [[ -z "$file" || ! -f "$file" ]] && continue
    if ! python3 -m py_compile "$file" 2>/dev/null; then
        echo "FAIL: Python syntax error in $file" | tee -a "$RESULT_FILE"
        FAILED=1
    fi
done < <(get_changed_files | grep '\.py
```)

[[ $FAILED -eq 0 ]] && echo "All basic checks passed" | tee -a "$RESULT_FILE"

exit $FAILED
