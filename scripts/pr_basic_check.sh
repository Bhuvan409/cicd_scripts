#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${RESULTS_DIR:-${WORKSPACE:-$PWD}/results}"

if [[ -f "${SCRIPT_DIR}/../config/config.sh" ]]; then
    source "${SCRIPT_DIR}/../config/config.sh"
fi

# Parse arguments
PR_NUMBER=""
TARGET_BRANCH="main"

while [[ $# -gt 0 ]]; do
    case $1 in
        --pr) PR_NUMBER="$2"; shift 2 ;;
        --target) TARGET_BRANCH="$2"; shift 2 ;;
        *) echo "Unknown option: $1"; shift ;;
    esac
done

# Validate inputs
if [[ -z "$PR_NUMBER" ]]; then
    echo "ERROR: --pr required"
    echo "Usage: $0 --pr <PR_NUMBER> --target <BRANCH>"
    exit 1
fi

# Create results directory
mkdir -p "${RESULTS_DIR}"
FAILED_CHECKS=0

echo "========================================="
echo "PR Checker for PR #${PR_NUMBER}"
echo "Target Branch: ${TARGET_BRANCH}"
echo "Results Dir: ${RESULTS_DIR}"
echo "========================================="

# Export variables for check scripts
export RESULTS_DIR
export TARGET_BRANCH
export PR_NUMBER

# Run all check scripts in order
for check_script in "${SCRIPT_DIR}"/checks/*.sh; do
    if [[ ! -f "$check_script" ]]; then
        continue
    fi
    
    check_name=$(basename "$check_script" .sh)
    echo ""
    echo ">>> Running: ${check_name}"
    echo "-------------------------------------------"
    
    if bash "$check_script" --target "$TARGET_BRANCH" --results "${RESULTS_DIR}"; then
        echo "✓ ${check_name} PASSED"
    else
        echo "✗ ${check_name} FAILED"
        ((FAILED_CHECKS++))
    fi
    echo "-------------------------------------------"
done

# Summary
echo ""
echo "========================================="
echo "Check Summary"
echo "========================================="
echo "Failed Checks: ${FAILED_CHECKS}"
echo ""

if [[ $FAILED_CHECKS -eq 0 ]]; then
    echo "✅ All checks PASSED"
    exit 0
else
    echo "❌ ${FAILED_CHECKS} check(s) FAILED"
    echo ""
    echo "View detailed results in: ${RESULTS_DIR}/"
    exit 1
fi
