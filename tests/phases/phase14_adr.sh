#!/usr/bin/env bash
# phase14_adr.sh — E2E tests for ADR (Architecture Decision Record) behavior in /ca:plan
#
# TC5: ADR offered — drive a plan decision meeting all three ADR conditions
#      (hard-to-reverse, surprising, real tradeoff); select Yes when the ADR
#      AskUserQuestion appears; assert .ca/docs/adr/0001-*.md exists.
# TC6: No-spam — plan with only trivial decisions; assert no ADR prompt fires
#      and .ca/docs/adr/ contains no new file.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CA_REPO_ROOT="${CA_REPO_ROOT:-"$(cd "${SCRIPT_DIR}/../.." && pwd)"}"
export TEST_NAME="phase14-adr"

source "${CA_REPO_ROOT}/tests/e2e_common.sh"

echo ""
echo "Phase 14: ADR (Architecture Decision Record) behavior"
echo "======================================================"

# Persistent results file survives multiple setup/cleanup cycles
PERSISTENT_RESULTS="$(mktemp /tmp/ca-e2e-phase14-results-XXXXXX.txt)"

# ---------------------------------------------------------------------------
# Globals: set before drive_discuss_to_stop since ADR detection now happens
# during discuss (header [D.ADR]), not plan.
#
#   ADR_SEEN     — 1 if any AskUserQuestion header matched "ADR", else 0
#   ADR_SELECTED — 1 if we answered "Yes" to an ADR question
# ---------------------------------------------------------------------------
ADR_SEEN=0
ADR_SELECTED=0

# ---------------------------------------------------------------------------
# Helper: drive /ca:discuss grill to completion (Requirements → SPEC → Stop)
# ---------------------------------------------------------------------------
drive_discuss_to_stop() {
    local max_questions="${1:-15}"
    local i=0
    while [ "${i}" -lt "${max_questions}" ]; do
        wait_for_ask 120 || return 1
        if echo "${LAST_ASK_HEADER}" | grep -qE "Reqs"; then
            echo "[discuss] Requirements confirmation"
            sleep 1
            select_option_by_text "Accurate|Correct|Yes"
            # Next: SPEC or Stop
            wait_for_ask 60 || { wait_for_stop 60; return 0; }
            if echo "${LAST_ASK_HEADER}" | grep -qE "SPEC"; then
                sleep 1
                select_option_by_text "Accurate|Correct|Yes"
            else
                sleep 1
                select_option_smart 1
            fi
            wait_for_stop 120 || true
            return 0
        fi
        # Handle ADR offer during discuss grill
        if echo "${LAST_ASK_HEADER}" | grep -qiE "ADR"; then
            ADR_SEEN=1
            echo "[discuss] ADR question detected — selecting Yes"
            sleep 1
            select_option_by_text "Yes"
            ADR_SELECTED=1
            i=$((i + 1))
            continue
        fi
        # Handle Research stage: skip to avoid launching ca-researcher
        if echo "${LAST_ASK_HEADER}" | grep -qE "Research|研究|调研"; then
            echo "[discuss] Research stage — selecting Skip"
            sleep 1
            select_option_by_text "Skip|跳过"
            continue
        fi
        echo "[discuss] grill Q${i}: ${LAST_ASK_HEADER}"
        sleep 1
        select_option_smart 1
        i=$((i + 1))
    done
    return 1
}

# ---------------------------------------------------------------------------
# Helper: drive /ca:plan through Requirements → Rough Plan → Steps → Results.
# ADR detection has moved to discuss; this helper no longer watches for ADR.
# ---------------------------------------------------------------------------

drive_plan_watch_for_adr() {
    local saw_requirements=0
    local max_asks=20
    local i=0

    while [ "${i}" -lt "${max_asks}" ]; do
        wait_for_ask 90 || break
        echo "[plan] header: ${LAST_ASK_HEADER}"

        # Requirements
        if echo "${LAST_ASK_HEADER}" | grep -qE "Reqs"; then
            saw_requirements=1
            sleep 1
            select_option_by_text "Correct|Accurate|Yes"
            i=$((i + 1))
            continue
        fi

        # Rough Plan
        if echo "${LAST_ASK_HEADER}" | grep -qE "Rough"; then
            sleep 1
            select_option_by_text "Feasible|Correct|Confirm|Yes"
            i=$((i + 1))
            continue
        fi

        # Step-by-step confirmations
        if echo "${LAST_ASK_HEADER}" | grep -qE "Step"; then
            sleep 1
            select_option_by_text "Correct|Yes|Confirm"
            i=$((i + 1))
            continue
        fi

        # Results — end of plan
        if echo "${LAST_ASK_HEADER}" | grep -qE "Results"; then
            sleep 1
            select_option_by_text "Yes|Confirm"
            break
        fi

        # Handle Research stage: skip to avoid launching ca-researcher
        if echo "${LAST_ASK_HEADER}" | grep -qE "Research|研究|调研"; then
            echo "[plan] Research stage — selecting Skip"
            sleep 1
            select_option_by_text "Skip|跳过"
            i=$((i + 1))
            continue
        fi

        # Anything else — pick option 1
        sleep 1
        select_option_smart 1
        i=$((i + 1))
    done

    wait_for_stop 120 || true
}

###############################################################################
# TC5: ADR offered when plan has a hard-to-reverse, surprising, real-tradeoff decision
###############################################################################
echo ""
echo "--- TC5: ADR offered for architectural decision ---"

setup_test_env
RESULTS_FILE="${PERSISTENT_RESULTS}"
TEST_PROJECT="${TEST_DIR}/project"
trap 'cleanup' EXIT

start_claude
sleep 5
pane_log "tc5-startup"

# Brief engineered to force a hard architectural choice:
# - Choosing between REST vs GraphQL API is hard-to-reverse (client coupling),
#   surprising (not obvious which is better), and has real tradeoffs (schema
#   flexibility vs simplicity).  All three ADR conditions should be met.
inject_command "/ca:new Build a public data API for a product catalog. CRITICAL DECISION: choose between REST and GraphQL as the query interface. The choice is hard to reverse once clients depend on it, and each has real tradeoffs: REST is simpler but GraphQL allows flexible client queries. Justify the choice. All success criteria must be auto-verifiable via bash commands."
wait_for_ask 120
assert_ask_header "Todo" "tc5: Add Todo prompt"
sleep 1
select_option_by_text "No.*skip"
wait_for_stop
pane_log "tc5-new-done"

inject_command "/ca:discuss"
drive_discuss_to_stop || true
pane_log "tc5-discuss-done"

# Assertions: ADR now triggers during discuss (header [D.ADR])
ADR_DIR="${TEST_PROJECT}/.ca/docs/adr"

if [ "${ADR_SEEN}" -eq 1 ]; then
    pass "tc5: ADR AskUserQuestion appeared during discuss"
else
    echo "[assert] FAIL: ADR prompt not observed during discuss"
    fail "tc5: ADR AskUserQuestion appeared during discuss"
fi

if [ "${ADR_SELECTED}" -eq 1 ]; then
    pass "tc5: user selected Yes to ADR"
else
    echo "[assert] FAIL: ADR question never offered/answered Yes"
    fail "tc5: user selected Yes to ADR"
fi

# Check for .ca/docs/adr/0001-*.md
ADR_FILE=$(find "${ADR_DIR}" -name "0001-*.md" 2>/dev/null | head -1)
if [ -n "${ADR_FILE}" ]; then
    pass "tc5: .ca/docs/adr/0001-*.md created"
    # ADR must contain grill-format content (decision + rationale)
    if grep -qiE "decision|rationale|tradeoff|consequence|REST|GraphQL" "${ADR_FILE}"; then
        pass "tc5: ADR file contains decision/rationale content"
    else
        echo "[assert] FAIL: ADR file lacks expected content:"
        cat "${ADR_FILE}"
        fail "tc5: ADR file contains decision/rationale content"
    fi
else
    echo "[assert] FAIL: no .ca/docs/adr/0001-*.md found"
    fail "tc5: .ca/docs/adr/0001-*.md created"
    fail "tc5: ADR file contains decision/rationale content"
fi

# Clear context between discuss and plan to reduce memory pressure
inject_command "/clear"
sleep 3

inject_command "/ca:plan"
drive_plan_watch_for_adr
pane_log "tc5-plan-done"

cleanup

###############################################################################
# TC6: No-spam — trivial plan produces no ADR prompt and no adr/ file
###############################################################################
echo ""
echo "--- TC6: no ADR prompt for trivial decisions ---"

setup_test_env
RESULTS_FILE="${PERSISTENT_RESULTS}"
TEST_PROJECT="${TEST_DIR}/project"

start_claude
sleep 5
pane_log "tc6-startup"

# Brief with only trivial, obvious, easily-reversible implementation detail —
# no hard architecture choice.  ADR conditions should NOT be met.
inject_command "/ca:new Add a helper function formatDate(date) to utils.js that formats a JavaScript Date as YYYY-MM-DD string. All success criteria must be auto-verifiable via bash commands."
wait_for_ask 120
assert_ask_header "Todo" "tc6: Add Todo prompt"
sleep 1
select_option_by_text "No.*skip"
wait_for_stop
pane_log "tc6-new-done"

# Record event count before discuss so we can inspect only discuss-phase events
DISCUSS_START_EVENT_COUNT=$(wc -l < "${EVENT_LOG}" 2>/dev/null || echo "0")

inject_command "/ca:discuss"
drive_discuss_to_stop || true
pane_log "tc6-discuss-done"

DISCUSS_END_EVENT_COUNT=$(wc -l < "${EVENT_LOG}" 2>/dev/null || echo "0")

# Extract only AskUserQuestion headers that appeared during the discuss phase
DISCUSS_EVENTS=$(sed -n "$((DISCUSS_START_EVENT_COUNT+1)),${DISCUSS_END_EVENT_COUNT}p" "${EVENT_LOG}" 2>/dev/null || echo "")
DISCUSS_ADR_ASKS=$(echo "${DISCUSS_EVENTS}" | grep '"tool_name":"AskUserQuestion"' | jq -r '.payload.tool_input.questions[0].header // empty' 2>/dev/null | grep -iE "ADR|Architecture Decision" || true)

if [ -z "${DISCUSS_ADR_ASKS}" ]; then
    pass "tc6: no ADR AskUserQuestion appeared for trivial discuss"
else
    echo "[assert] FAIL: unexpected ADR question(s) for trivial discuss:"
    echo "${DISCUSS_ADR_ASKS}"
    fail "tc6: no ADR AskUserQuestion appeared for trivial discuss"
fi

# Clear context between discuss and plan to reduce memory pressure
inject_command "/clear"
sleep 3

inject_command "/ca:plan"
drive_plan_watch_for_adr
pane_log "tc6-plan-done"

# No .ca/docs/adr/ directory (or if it exists it must be empty / have no *.md files)
ADR_DIR="${TEST_PROJECT}/.ca/docs/adr"
if [ -d "${ADR_DIR}" ]; then
    ADR_FILE_COUNT=$(find "${ADR_DIR}" -name "*.md" 2>/dev/null | wc -l)
else
    ADR_FILE_COUNT=0
fi
if [ "${ADR_FILE_COUNT}" -eq 0 ]; then
    pass "tc6: no ADR file created for trivial plan"
else
    echo "[assert] FAIL: unexpected ADR files for trivial plan:"
    find "${ADR_DIR}" -name "*.md" 2>/dev/null
    fail "tc6: no ADR file created for trivial plan"
fi

cleanup

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
RESULTS_FILE="${PERSISTENT_RESULTS}"
summarize_results
result=$?
rm -f "${PERSISTENT_RESULTS}"
exit ${result}
