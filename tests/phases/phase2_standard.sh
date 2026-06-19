#!/usr/bin/env bash
# phase2_standard.sh — E2E test for the standard workflow:
#   /ca:new → /ca:discuss → /ca:plan → /ca:execute → /ca:verify → /ca:finish
#
# Each step injects the slash command and waits for event-driven signals
# (AskUserQuestion or Stop) rather than polling for idle state.
#
# Requirements:
#   CA_REPO_ROOT — absolute path to the claude-agent repo root
#   All shared helpers come from e2e_common.sh

set -euo pipefail

# Locate e2e_common.sh relative to this script's directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CA_REPO_ROOT="${CA_REPO_ROOT:-"$(cd "${SCRIPT_DIR}/../.." && pwd)"}"

# Test suite name — drives the tmux session name (must be set before sourcing e2e_common.sh)
export TEST_NAME="phase2-standard"

source "${CA_REPO_ROOT}/tests/e2e_common.sh"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# get_workflow_dir — Find the active workflow directory under .ca/workflows/
#
# Returns the full path to the first workflow dir found, or empty string if not found.
get_workflow_dir() {
    local project_dir="${TEST_DIR}/project"
    local workflow_id
    workflow_id="$(ls "${project_dir}/.ca/workflows/" 2>/dev/null | head -1)"
    if [ -z "${workflow_id}" ]; then
        echo ""
        return
    fi
    echo "${project_dir}/.ca/workflows/${workflow_id}"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

# Register cleanup trap so temp files are removed even on error
trap 'cleanup' EXIT

# Create isolated environment (sets TEST_DIR, TEST_CONFIG_DIR, RESULTS_FILE)
setup_test_env

# Define the project dir (set by setup_test_env)
TEST_PROJECT="${TEST_DIR}/project"

# Start Claude in a tmux session inside the project directory
start_claude

# Wait for Claude to be ready at the initial prompt
sleep 5
pane_log "startup"

# ============================================================
# Step 1: /ca:new — create a new standard workflow
# ============================================================

inject_command "/ca:new Add a goodbye helper to utils.js for signing a user off — I haven't decided whether it takes a name argument or reads a default. Use 'Farewell' as the canonical term for this exit-greeting concept (avoid the aliases 'Signoff' and 'Bye message'). All success criteria must be auto-verifiable via bash commands"
wait_for_ask 120
assert_ask_header "Todo" "new: Add Todo prompt"
sleep 1
select_option_by_text "No.*skip"
wait_for_stop
pane_log "new-done"

# --- Assertions: new ---
WORKFLOW_DIR="$(get_workflow_dir)"

if [ -n "${WORKFLOW_DIR}" ]; then
    assert_file_exists "${WORKFLOW_DIR}/BRIEF.md"  "new: BRIEF.md exists"
    assert_file_exists "${WORKFLOW_DIR}/STATUS.md" "new: STATUS.md exists"
    assert_status_field "workflow_type" "standard"  "new: workflow_type=standard"
else
    fail "new: BRIEF.md exists"
    fail "new: STATUS.md exists"
    fail "new: workflow_type=standard"
fi

# ============================================================
# Step 2: /ca:discuss — finalize requirements
# ============================================================

inject_command "/ca:discuss"

# discuss has variable clarifying questions before the final [D.Reqs] confirmation
# TC8: detect the grill clarification stage by its stable header ([D.Clarify]),
# NOT by option content.
FOUND_CLARIFY=0
CLARIFY_MULTI=0
for i in $(seq 1 10); do
    wait_for_ask 120
    if echo "${LAST_ASK_HEADER}" | grep -qE "Clarify"; then
        FOUND_CLARIFY=1
        nq=$(echo "${LAST_EVENT}" | jq -r '.payload.tool_input.questions | length' 2>/dev/null || echo 1)
        if [ "${nq}" != "1" ]; then CLARIFY_MULTI=1; fi
        echo "[discuss] TC8: Clarify-stage question at ${i} (${nq} q): ${LAST_ASK_HEADER}"
    fi
    if echo "${LAST_ASK_HEADER}" | grep -qE "Reqs"; then
        assert_ask_header "Reqs" "discuss: Requirements prompt"
        sleep 1
        select_option_by_text "Accurate"
        break
    fi
    echo "[discuss] clarifying question ${i}: ${LAST_ASK_HEADER}"
    sleep 1
    select_option_smart 1
done

# TC8: ≥1 [D.Clarify]-header question AND each Clarify event carried exactly one
# question (one-at-a-time, no multi-question dump)
if [ "${FOUND_CLARIFY}" -eq 1 ] && [ "${CLARIFY_MULTI}" -eq 0 ]; then
    pass "discuss: TC8 grill conducted one-at-a-time Clarify-stage questioning"
else
    fail "discuss: TC8 grill conducted one-at-a-time Clarify-stage questioning"
fi

# Expect: SPEC confirmation after requirements
wait_for_ask
assert_ask_header "SPEC" "discuss: SPEC prompt"
sleep 1
select_option_by_text "Accurate"

wait_for_stop
pane_log "discuss-done"

# --- Assertions: discuss ---
WORKFLOW_DIR="$(get_workflow_dir)"

if [ -n "${WORKFLOW_DIR}" ]; then
    assert_file_exists "${WORKFLOW_DIR}/REQUIREMENT.md" "discuss: REQUIREMENT.md exists"
    assert_file_exists "${WORKFLOW_DIR}/SPEC.md" "discuss: SPEC.md exists"
    assert_file_contains "${WORKFLOW_DIR}/SPEC.md" "## Desired Result / User Experience" "discuss: SPEC has Desired Result section"
    assert_file_contains "${WORKFLOW_DIR}/SPEC.md" "## Verification Design" "discuss: SPEC has Verification Design section"
else
    fail "discuss: REQUIREMENT.md exists"
    fail "discuss: SPEC.md exists"
    fail "discuss: SPEC has Desired Result section"
    fail "discuss: SPEC has Verification Design section"
fi

# TC1: CONTEXT.md created under .ca/docs/ and contains _Avoid_ entry
assert_file_exists "${TEST_PROJECT}/.ca/docs/CONTEXT.md" "discuss: CONTEXT.md created"
assert_file_contains "${TEST_PROJECT}/.ca/docs/CONTEXT.md" "_Avoid_" "discuss: TC1 CONTEXT.md has _Avoid_ entry"

assert_status_field "discuss_completed" "true" "discuss: discuss_completed=true"

# Clear context between discuss and plan to reduce memory pressure
inject_command "/clear"
sleep 3

# ============================================================
# Step 3: /ca:plan — create plan and criteria
# ============================================================

inject_command "/ca:plan"

# Expect: Requirements confirmation
wait_for_ask 120
assert_ask_header "Reqs" "plan: Requirements prompt"
sleep 1
select_option_by_text "Correct"

# Expect: Rough Plan confirmation directly; standard workflow must not re-confirm SPEC
wait_for_ask
if echo "${LAST_ASK_HEADER}" | grep -qE "SPEC"; then
    fail "plan: standard workflow must not re-confirm SPEC"
fi
assert_ask_header "Rough" "plan: Rough Plan prompt"
sleep 1
select_option_by_text "Feasible"

# Expect: Step-by-step plan confirmation (Confirmation 2b)
wait_for_step_confirmations "Results" "plan" 90
assert_ask_header "Results" "plan: Results prompt"
sleep 1
select_option_by_text "Yes"

wait_for_stop 120
pane_log "plan-done"

# --- Assertions: plan ---
WORKFLOW_DIR="$(get_workflow_dir)"

if [ -n "${WORKFLOW_DIR}" ]; then
    assert_file_exists "${WORKFLOW_DIR}/rounds/0/PLAN.md"   "plan: rounds/0/PLAN.md exists"
    assert_file_exists "${WORKFLOW_DIR}/rounds/0/TASKS.csv" "plan: rounds/0/TASKS.csv exists"
    assert_file_exists "${WORKFLOW_DIR}/VERIFY.csv"         "plan: root VERIFY.csv exists"
    assert_file_contains "${WORKFLOW_DIR}/VERIFY.csv" "self_check|test" "plan: TC11 VERIFY.csv has self_check/test type"
    # Assert CRITERIA.md was NOT created (superseded by VERIFY.csv)
    if [ ! -f "${WORKFLOW_DIR}/CRITERIA.md" ]; then
        pass "plan: CRITERIA.md absent (replaced by VERIFY.csv)"
    else
        echo "[assert] FAIL: CRITERIA.md should not exist; VERIFY.csv is used instead"
        fail "plan: CRITERIA.md absent (replaced by VERIFY.csv)"
    fi

    # cpa4 Blocker fix — behavior-level boilerplate regression guard:
    # plan must derive criteria only from the SPEC, NOT auto-append the fixed 4-item self_check set.
    # This trivial task's SPEC has no generic imports/unused/comments/conventions checks, so those
    # boilerplate phrasings must be absent. (Targets the boilerplate signature, not all self_checks.)
    if grep -iE "imports?.{0,15}at[ -](the[ -])?top|no[- ]?unused|comments?.{0,20}(in |are )?english|matches.{0,15}(existing )?conventions" "${WORKFLOW_DIR}/VERIFY.csv"; then
        echo "[assert] FAIL: VERIFY.csv contains boilerplate self_check criteria (fixed 4-item set was auto-appended)"
        cat "${WORKFLOW_DIR}/VERIFY.csv"
        fail "plan: no boilerplate self_check set in VERIFY.csv (regression)"
    else
        pass "plan: no boilerplate self_check set in VERIFY.csv (regression)"
    fi
else
    fail "plan: rounds/0/PLAN.md exists"
    fail "plan: rounds/0/TASKS.csv exists"
    fail "plan: root VERIFY.csv exists"
    fail "plan: TC11 VERIFY.csv has self_check/test type"
    fail "plan: CRITERIA.md absent (replaced by VERIFY.csv)"
    fail "plan: no boilerplate self_check set in VERIFY.csv (regression)"
fi

assert_status_field "plan_completed" "true" "plan: plan_completed=true"

# ============================================================
# Step 4: /ca:execute — run the plan
# ============================================================

inject_command "/ca:execute"
wait_for_stop 240
pane_log "execute-done"

# --- Assertions: execute ---
WORKFLOW_DIR="$(get_workflow_dir)"

if [ -n "${WORKFLOW_DIR}" ]; then
    assert_file_exists "${WORKFLOW_DIR}/rounds/0/SUMMARY.md" "execute: rounds/0/SUMMARY.md exists"
    # TC10: verify that TASKS.csv dev fields are marked done after execute
    csv_get_out=$(node "${CA_REPO_ROOT}/scripts/ca-csv.js" get --file "${WORKFLOW_DIR}/rounds/0/TASKS.csv" 2>/dev/null || true)
    if echo "${csv_get_out}" | grep -qv "pending"; then
        pass "execute: TC10 TASKS.csv dev=done after execute"
    else
        echo "[assert] FAIL: TC10 TASKS.csv still has pending dev rows after execute"
        echo "[assert] TASKS.csv content: ${csv_get_out}"
        fail "execute: TC10 TASKS.csv dev=done after execute"
    fi
else
    fail "execute: rounds/0/SUMMARY.md exists"
    fail "execute: TC10 TASKS.csv dev=done after execute"
fi

assert_status_field "execute_completed" "true" "execute: execute_completed=true"

# ============================================================
# Step 5: /ca:verify — run verification
# ============================================================

inject_command "/ca:verify"
wait_for_ask 180
assert_ask_header "Results" "verify: Results prompt"
sleep 1
select_option_by_text "Accept"
wait_for_stop 180
pane_log "verify-done"

# --- Assertions: verify ---
WORKFLOW_DIR="$(get_workflow_dir)"

if [ -n "${WORKFLOW_DIR}" ] && [ -f "${WORKFLOW_DIR}/VERIFY-REPORT.md" ]; then
    pass "verify: VERIFY-REPORT.md created"
else
    # Fallback: check status field
    assert_status_field "verify_completed" "true" "verify: VERIFY-REPORT.md created"
fi

assert_status_field "verify_completed" "true" "verify: verify_completed=true"

# ============================================================
# Step 6: /ca:finish — archive the workflow
# ============================================================

inject_command "/ca:finish"

# Expect: Commit prompt
wait_for_ask 120
assert_ask_header "Commit" "finish: Commit prompt"
sleep 1
select_option_by_text "Yes"

# Expect: Confirm prompt
wait_for_ask 120
assert_ask_header "Confirm" "finish: Confirm prompt"
sleep 1
select_option_by_text "Confirm"

wait_for_stop 180
pane_log "finish-done"

# --- Assertions: finish ---
# Workflow directory should no longer exist (archived to .ca/history/)
PROJECT_DIR="${TEST_DIR}/project"
if [ ! -d "${WORKFLOW_DIR}" ]; then
    pass "finish: workflow moved to history"
else
    echo "[assert] FAIL: workflow directory still exists after finish: ${WORKFLOW_DIR}"
    fail "finish: workflow moved to history"
fi

# At least one entry should now exist in .ca/history/
if ls "${PROJECT_DIR}/.ca/history/" 2>/dev/null | grep -q .; then
    pass "finish: history entry created"
else
    echo "[assert] FAIL: no entries found in .ca/history/"
    fail "finish: history entry created"
fi

# ============================================================
# Summary
# ============================================================
summarize_results
