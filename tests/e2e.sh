#!/usr/bin/env bash
# e2e.sh — Main E2E test orchestrator for claude-agent
#
# Usage:
#   bash tests/e2e.sh            — Run all phases (1, 2, 3, 4, 5)
#   bash tests/e2e.sh --phase N  — Run only phase N (1, 2, 3, 4, or 5)
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

# Aggregate results across all phases
TOTAL_PASS=0
TOTAL_FAIL=0
PHASE_SUMMARIES=()

# run_phase — Execute a single phase script and collect results
#
# Args:
#   $1 — phase number (1, 2, or 3)
#   $2 — phase script path
#   $3 — phase display label
run_phase() {
    local phase_num="$1"
    local phase_script="$2"
    local phase_label="$3"

    echo "  --- Phase ${phase_num}: ${phase_label} ---"
    echo ""

    # Log file for this phase
    local log_file="${LOG_DIR}/phase${phase_num}-${LOG_TIMESTAMP}.log"

    # Run the phase script, tee to log file and console
    local phase_exit=0
    set +e
    bash "${phase_script}" 2>&1 | tee "${log_file}"
    phase_exit=${PIPESTATUS[0]}
    set -e

    echo ""
    echo "  Log saved: ${log_file}"

    # phase exit code is the number of failures in that phase
    local phase_fail=${phase_exit}

    # Count PASSes and FAILs from the output by re-running summary on the results file
    # Phase scripts call summarize_results which already prints their summary.
    # Here we track overall totals using the exit code (fail count).
    # To get pass count we need to sum from a results file — phases handle their own
    # summarize_results call and print individual counts. We accumulate via exit code.
    PHASE_SUMMARIES+=("Phase ${phase_num} (${phase_label}): exit=${phase_fail}")

    TOTAL_FAIL=$((TOTAL_FAIL + phase_fail))

    echo ""
}

# Determine which phases to run
run_phase_1=false
run_phase_2=false
run_phase_3=false
run_phase_4=false
run_phase_5=false

if [ -z "${PHASE_FILTER}" ]; then
    run_phase_1=true
    run_phase_2=true
    run_phase_3=true
    run_phase_4=true
    run_phase_5=true
else
    case "${PHASE_FILTER}" in
        1) run_phase_1=true ;;
        2) run_phase_2=true ;;
        3) run_phase_3=true ;;
        4) run_phase_4=true ;;
        5) run_phase_5=true ;;
        *)
            echo "Invalid phase: ${PHASE_FILTER}. Must be 1, 2, 3, 4, or 5."
            exit 1
            ;;
    esac
fi

# Execute selected phases
if [ "${run_phase_1}" = true ]; then
    run_phase 1 "${CA_REPO_ROOT}/tests/phases/phase1_quick.sh" "Quick Workflow"
fi

if [ "${run_phase_2}" = true ]; then
    run_phase 2 "${CA_REPO_ROOT}/tests/phases/phase2_standard.sh" "Standard Workflow"
fi

if [ "${run_phase_3}" = true ]; then
    run_phase 3 "${CA_REPO_ROOT}/tests/phases/phase3_helpers.sh" "Helper Commands"
fi

if [ "${run_phase_4}" = true ]; then
    run_phase 4 "${CA_REPO_ROOT}/tests/phases/phase4_i18n.sh" "i18n (Chinese)"
fi

if [ "${run_phase_5}" = true ]; then
    run_phase 5 "${CA_REPO_ROOT}/tests/phases/phase5_verify_fail.sh" "Verify Failure Flow"
fi

# --- Final Aggregated Summary ---
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
