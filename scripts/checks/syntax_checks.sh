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
RESULT_FILE="${RESULTS_DIR}/02_syntax_checks.txt"

get_changed_files() {
    git diff --name-only "origin/${TARGET_BRANCH}...HEAD" 2>/dev/null || \
    git diff --name-only "${TARGET_BRANCH}...HEAD" 2>/dev/null || \
    echo ""
}

echo "Syntax Checks" > "$RESULT_FILE"
echo "=============" >> "$RESULT_FILE"
echo "" >> "$RESULT_FILE"

# Check 1: Shell scripts
echo "Check 1: Shell Script Syntax"
echo "-----------------------------"
SHELL_ERRORS=()

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ -f "$file" ]] || continue
    
    ERROR_FILE="${RESULTS_DIR}/shell_error_$(basename $file).txt"
    
    if ! bash -n "$file" 2>"$ERROR_FILE"; then
        SHELL_ERRORS+=("$file")
        echo "  ✗ FAIL: Shell syntax error in $file" | tee -a "$RESULT_FILE"
        echo "    Error details:" >> "$RESULT_FILE"
        sed 's/^/      /' "$ERROR_FILE" >> "$RESULT_FILE"
        FAILED=1
    else
        rm -f "$ERROR_FILE"
    fi
done < <(get_changed_files | grep '\.sh$')

if [[ ${#SHELL_ERRORS[@]} -eq 0 ]]; then
    echo "  ✓ All shell scripts have valid syntax" | tee -a "$RESULT_FILE"
fi
echo "" >> "$RESULT_FILE"

# Check 2: Python files
echo "Check 2: Python Syntax"
echo "----------------------"
PYTHON_ERRORS=()

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ -f "$file" ]] || continue
    
    ERROR_FILE="${RESULTS_DIR}/python_error_$(basename $file).txt"
    
    if ! python3 -m py_compile "$file" 2>"$ERROR_FILE"; then
        PYTHON_ERRORS+=("$file")
        echo "  ✗ FAIL: Python syntax error in $file" | tee -a "$RESULT_FILE"
        echo "    Error details:" >> "$RESULT_FILE"
        sed 's/^/      /' "$ERROR_FILE" >> "$RESULT_FILE"
        FAILED=1
    else
        rm -f "$ERROR_FILE"
        # Clean up __pycache__
        rm -rf "$(dirname $file)/__pycache__"
    fi
done < <(get_changed_files | grep '\.py$')

if [[ ${#PYTHON_ERRORS[@]} -eq 0 ]]; then
    echo "  ✓ All Python files have valid syntax" | tee -a "$RESULT_FILE"
fi
echo "" >> "$RESULT_FILE"

# Check 3: JSON files
echo "Check 3: JSON Validation"
echo "------------------------"
JSON_ERRORS=()

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    [[ -f "$file" ]] || continue
    
    ERROR_FILE="${RESULTS_DIR}/json_error_$(basename $file).txt"
    
    if ! python3 -c "import json; json.load(open('$file'))" 2>"$ERROR_FILE"; then
        JSON_ERRORS+=("$file")
        echo "  ✗ FAIL: Invalid JSON in $file" | tee -a "$RESULT_FILE"
        echo "    Error details:" >> "$RESULT_FILE"
        sed 's/^/      /' "$ERROR_FILE" >> "$RESULT_FILE"
        FAILED=1
    else
        rm -f "$ERROR_FILE"
    fi
done < <(get_changed_files | grep '\.json$')

if [[ ${#JSON_ERRORS[@]} -eq 0 ]]; then
    echo "  ✓ All JSON files are valid" | tee -a "$RESULT_FILE"
fi
echo "" >> "$RESULT_FILE"

# Summary
echo "Summary" >> "$RESULT_FILE"
echo "-------" >> "$RESULT_FILE"
if [[ $FAILED -eq 0 ]]; then
    echo "✓ All syntax checks PASSED" | tee -a "$RESULT_FILE"
else
    echo "✗ Syntax checks FAILED" | tee -a "$RESULT_FILE"
fi

exit $FAILED
