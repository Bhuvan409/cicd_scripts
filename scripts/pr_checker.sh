#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${RESULTS_DIR:-results}"
TARGET_BRANCH="main"
PR_NUMBER=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --pr) PR_NUMBER="$2"; shift 2 ;;
        --target) TARGET_BRANCH="$2"; shift 2 ;;
        *) shift ;;
    esac
done

[[ -z "$PR_NUMBER" ]] && { echo "ERROR: --pr required"; exit 1; }

mkdir -p "${RESULTS_DIR}"
FAILED=0

echo "========================================="
echo "PR Checker for PR #${PR_NUMBER}"
echo "Target Branch: ${TARGET_BRANCH}"
echo "========================================="

export TARGET_BRANCH
export RESULTS_DIR

# Run basic checks
echo ""
echo ">>> Running Basic Checks"
if bash "${SCRIPT_DIR}/checks/basic_checks.sh"; then
    echo "PASSED: Basic checks"
else
    echo "FAILED: Basic checks"
    ((FAILED++))
fi

# Run Yocto checks
echo ""
echo ">>> Running Yocto Checks"
if python3 "${SCRIPT_DIR}/checks/yocto_checks.py"; then
    echo "PASSED: Yocto checks"
else
    echo "FAILED: Yocto checks"
    ((FAILED++))
fi

# Run layer checks
echo ""
echo ">>> Running Layer Checks"
if python3 "${SCRIPT_DIR}/checks/layer_checks.py"; then
    echo "PASSED: Layer checks"
else
    echo "FAILED: Layer checks"
    ((FAILED++))
fi

# Run recipe checks
echo ""
echo ">>> Running Recipe Checks"
if python3 "${SCRIPT_DIR}/checks/recipe_checks.py"; then
    echo "PASSED: Recipe checks"
else
    echo "FAILED: Recipe checks"
    ((FAILED++))
fi

echo ""
echo "========================================="
echo "Summary: ${FAILED} check(s) failed"
echo "========================================="

exit $FAILED
