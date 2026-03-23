#!/usr/bin/env bash
# e2e.sh — Main E2E test orchestrator for claude-agent
#
# Usage:
#   bash tests/e2e.sh            — Run all phases (1-10) with parallel execution (max 4)
#   bash tests/e2e.sh --phase N  — Run only phase N (1-10)
#
# Requires: tmux, claude CLI, jq, node

set -euo pipefail

# Resolve repo root from this script's location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CA_REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Max parallel phases
MAX_PARALLEL=4

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
    "7|${CA_REPO_ROOT}/tests/phases/phase7_branch_autoproceed.sh|Branch + Auto-proceed"
    "8|${CA_REPO_ROOT}/tests/phases/phase8_batch.sh|Batch Execution"
    "9|${CA_REPO_ROOT}/tests/phases/phase9_context.sh|Context Management"
    "10|${CA_REPO_ROOT}/tests/phases/phase10_multi_workflow.sh|Multi-workflow"
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
        echo "Invalid phase: ${PHASE_FILTER}. Must be 1-10."
        exit 1
    fi
else
    SELECTED_PHASES=("${PHASES[@]}")
fi

# --- Parallel Execution with Pool ---

# Temp dir for exit codes
EXIT_DIR="$(mktemp -d /tmp/ca-e2e-exits-XXXXXX)"
PIDS=()
PHASE_LABELS=()

run_phase_bg() {
    local phase_num="$1"
    local phase_script="$2"
    local phase_label="$3"
    local log_file="${LOG_DIR}/phase${phase_num}-${LOG_TIMESTAMP}.log"

    echo "  [start] Phase ${phase_num}: ${phase_label}"

    (
        set +e
        bash "${phase_script}" > "${log_file}" 2>&1
        echo $? > "${EXIT_DIR}/phase${phase_num}.exit"
        set -e
    ) &
    PIDS+=($!)
    PHASE_LABELS+=("${phase_num}|${phase_label}")
}

# Wait for any one process to finish (frees a slot)
wait_for_slot() {
    while [ ${#PIDS[@]} -ge ${MAX_PARALLEL} ]; do
        local new_pids=()
        for pid in "${PIDS[@]}"; do
            if kill -0 "${pid}" 2>/dev/null; then
                new_pids+=("${pid}")
            fi
        done
        PIDS=("${new_pids[@]}")
        if [ ${#PIDS[@]} -ge ${MAX_PARALLEL} ]; then
            sleep 5
        fi
    done
}

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

# Multi-phase mode: run in parallel with pool
echo "  Running ${#SELECTED_PHASES[@]} phases (max ${MAX_PARALLEL} parallel)..."
echo ""

for phase in "${SELECTED_PHASES[@]}"; do
    IFS='|' read -r num script label <<< "${phase}"
    wait_for_slot
    run_phase_bg "${num}" "${script}" "${label}"
done

# Wait for all remaining processes
wait

# --- Collect Results ---
TOTAL_FAIL=0
PHASE_SUMMARIES=()

for entry in "${PHASE_LABELS[@]}"; do
    IFS='|' read -r num label <<< "${entry}"
    exit_file="${EXIT_DIR}/phase${num}.exit"
    if [ -f "${exit_file}" ]; then
        phase_exit=$(cat "${exit_file}")
    else
        phase_exit=1
    fi
    PHASE_SUMMARIES+=("Phase ${num} (${label}): exit=${phase_exit}")
    TOTAL_FAIL=$((TOTAL_FAIL + phase_exit))
done

# Cleanup exit dir
rm -rf "${EXIT_DIR}"

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
