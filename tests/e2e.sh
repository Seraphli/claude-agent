#!/usr/bin/env bash
# e2e.sh — Main E2E test orchestrator for claude-agent
#
# Usage:
#   bash tests/e2e.sh            — Run all phases (1-13) sequentially
#   bash tests/e2e.sh --phase N  — Run only phase N (1-13)
#
# Requires: tmux, claude CLI, jq, node

set -euo pipefail

# Resolve repo root from this script's location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CA_REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Parse --phase argument
PHASE_FILTER=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --phase)
            PHASE_FILTER="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Usage: bash tests/e2e.sh [--phase N]"
            exit 1
            ;;
    esac
done

# --- Log Directory ---
LOG_DIR="${CA_REPO_ROOT}/tests/logs"
mkdir -p "${LOG_DIR}"
LOG_TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

# --- ASCII Banner ---
echo ""
echo "  =================================="
echo "   claude-agent E2E Test Suite"
echo "  =================================="
echo ""
echo "  Logs: ${LOG_DIR}/"
echo ""

# Phase definitions: number|script|label
PHASES=(
    "1|${CA_REPO_ROOT}/tests/phases/phase1_quick.sh|Quick Workflow"
    "2|${CA_REPO_ROOT}/tests/phases/phase2_standard.sh|Standard Workflow"
    "3|${CA_REPO_ROOT}/tests/phases/phase3_helpers.sh|Helper Commands"
    "4|${CA_REPO_ROOT}/tests/phases/phase4_i18n.sh|i18n (Chinese)"
    "5|${CA_REPO_ROOT}/tests/phases/phase5_verify_fail.sh|Verify Failure Flow"
    "6|${CA_REPO_ROOT}/tests/phases/phase6_autofix.sh|Auto-fix Loop"
    "7|${CA_REPO_ROOT}/tests/phases/phase7_worktree_autoproceed.sh|Worktree + Auto-proceed"
    "8|${CA_REPO_ROOT}/tests/phases/phase8_batch.sh|Batch Execution"
    "9|${CA_REPO_ROOT}/tests/phases/phase9_context.sh|Context Management"
    "10|${CA_REPO_ROOT}/tests/phases/phase10_multi_workflow.sh|Multi-workflow"
    "11|${CA_REPO_ROOT}/tests/phases/phase11_project_yaml.sh|Project YAML"
    "12|${CA_REPO_ROOT}/tests/phases/phase12_instant.sh|Instant Workflow"
    "13|${CA_REPO_ROOT}/tests/phases/phase13_init.sh|Init Command"
)

# Filter phases
SELECTED_PHASES=()
if [ -n "${PHASE_FILTER}" ]; then
    for phase in "${PHASES[@]}"; do
        IFS='|' read -r num script label <<< "${phase}"
        if [ "${num}" = "${PHASE_FILTER}" ]; then
            SELECTED_PHASES+=("${phase}")
            break
        fi
    done
    if [ ${#SELECTED_PHASES[@]} -eq 0 ]; then
        echo "Invalid phase: ${PHASE_FILTER}. Must be 1-13."
        exit 1
    fi
else
    SELECTED_PHASES=("${PHASES[@]}")
fi

# Single phase mode: run sequentially (for --phase N)
if [ ${#SELECTED_PHASES[@]} -eq 1 ]; then
    IFS='|' read -r num script label <<< "${SELECTED_PHASES[0]}"
    log_file="${LOG_DIR}/phase${num}-${LOG_TIMESTAMP}.log"
    echo "  --- Phase ${num}: ${label} ---"
    echo ""
    set +e
    bash "${script}" 2>&1 | tee "${log_file}"
    phase_exit=${PIPESTATUS[0]}
    set -e
    echo ""
    echo "  Log saved: ${log_file}"
    echo ""
    echo "  =================================="
    echo "   Final E2E Summary"
    echo "  =================================="
    echo ""
    echo "  Phase ${num} (${label}): exit=${phase_exit}"
    echo ""
    echo "  Total failures: ${phase_exit}"
    echo ""
    if [ "${phase_exit}" -eq 0 ]; then
        echo "  ALL TESTS PASSED"
    else
        echo "  SOME TESTS FAILED"
    fi
    echo "  =================================="
    echo ""
    exit ${phase_exit}
fi

# Multi-phase mode: run sequentially
echo "  Running ${#SELECTED_PHASES[@]} phases sequentially..."
echo ""

TOTAL_FAIL=0
PHASE_SUMMARIES=()

for phase in "${SELECTED_PHASES[@]}"; do
    IFS='|' read -r num script label <<< "${phase}"
    log_file="${LOG_DIR}/phase${num}-${LOG_TIMESTAMP}.log"
    echo "  --- Phase ${num}: ${label} ---"
    set +e
    bash "${script}" > "${log_file}" 2>&1
    phase_exit=$?
    set -e
    PHASE_SUMMARIES+=("Phase ${num} (${label}): exit=${phase_exit}")
    TOTAL_FAIL=$((TOTAL_FAIL + phase_exit))
    if [ "${phase_exit}" -eq 0 ]; then
        echo "  [pass] Phase ${num}: ${label}"
    else
        echo "  [fail] Phase ${num}: ${label} (exit=${phase_exit})"
        echo "  Log: ${log_file}"
    fi
done

# --- Final Aggregated Summary ---
echo ""
echo "  =================================="
echo "   Final E2E Summary"
echo "  =================================="
echo ""
for summary in "${PHASE_SUMMARIES[@]}"; do
    echo "  ${summary}"
done
echo ""
echo "  Total failures: ${TOTAL_FAIL}"
echo ""

if [ "${TOTAL_FAIL}" -eq 0 ]; then
    echo "  ALL TESTS PASSED"
else
    echo "  SOME TESTS FAILED"
fi

echo "  =================================="
echo ""

# Exit code = total failures (0 = all passed)
exit ${TOTAL_FAIL}
