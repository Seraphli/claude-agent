#!/usr/bin/env bash
# phase1_quick.sh — E2E test for the quick workflow: quick → plan → execute → verify → finish
#
# Tests the full lifecycle of a /ca:quick workflow on a minimal Node.js fixture project.
# Each phase injects the slash command, waits for Claude to finish, then asserts file state.
#
# Usage:
#   CA_REPO_ROOT=/path/to/claude-agent bash tests/phases/phase1_quick.sh

set -euo pipefail

# Identify repo root: use CA_REPO_ROOT env or derive from this script's location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CA_REPO_ROOT="${CA_REPO_ROOT:-"$(cd "${SCRIPT_DIR}/../.." && pwd)"}"

# Test suite name (used for tmux session naming)
export TEST_NAME="phase1-quick"

# Source shared E2E infrastructure
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

# Setup isolated environment
setup_test_env

# Define the project dir (set by setup_test_env)
TEST_PROJECT="${TEST_DIR}/project"

# Cleanup tmux session and temp dir on exit
trap 'cleanup' EXIT

# Start claude in the fixture project
start_claude

# Wait for Claude to be ready at the initial prompt
sleep 5
pane_log "startup"

# ---------------------------------------------------------------------------
# Step 1: /ca:quick — create workflow, expect "Add Todo" prompt
# ---------------------------------------------------------------------------

inject_command "/ca:quick add a greeting helper to utils.js for welcoming a user. All success criteria must be [auto], no [manual] items."
wait_for_ask 120
assert_ask_header "Todo" "quick: Add Todo prompt"
sleep 1
select_option_by_text "No.*skip"
wait_for_stop
pane_log "quick-done"

# Assert BRIEF.md and STATUS.md were created in the workflow directory
WORKFLOW_DIR="$(get_workflow_dir)"

if [ -n "${WORKFLOW_DIR}" ]; then
    assert_file_exists "${WORKFLOW_DIR}/BRIEF.md" "quick: BRIEF.md created"
    assert_file_exists "${WORKFLOW_DIR}/STATUS.md" "quick: STATUS.md created"
else
    fail "quick: BRIEF.md created"
    fail "quick: STATUS.md created"
fi

# ---------------------------------------------------------------------------
# Step 2: /ca:plan — generate PLAN.md and CRITERIA.md
# ---------------------------------------------------------------------------

inject_command "/ca:plan"

# TC8: the injected /ca:quick requirement is intentionally under-specified, so plan's
# grill (§1c) should conduct a clarification stage — at least one [P.Clarify] question.
# Consume pre-gate Research/Clarify questions until the [P.Reqs] gate; the helper sets
# GRILL_CLARIFY_SEEN=1 if a Clarify question appeared (asserted by HEADER, not options).
drive_grill_to_gate "Reqs" 120
assert_ask_header "Reqs" "plan: Requirements prompt"
sleep 1
select_option_by_text "Correct"

# Expect: SPEC confirmation (quick workflow creates SPEC during plan)
wait_for_ask
assert_ask_header "SPEC" "plan: SPEC prompt"
sleep 1
select_option_by_text "Accurate"

# Expect: Rough Plan confirmation
wait_for_ask_expect "Rough" "" 45
assert_ask_header "Rough" "plan: Rough Plan prompt"
sleep 1
select_option_by_text "Feasible"

# Expect: Step-by-step plan confirmation (Confirmation 2b)
# Loops through "Step N" prompts, auto-confirming each, until "Results" header appears
wait_for_step_confirmations "Results" "plan" 45
assert_ask_header "Results" "plan: Results prompt"
sleep 1
select_option_by_text "Yes"

wait_for_stop 120
pane_log "plan-done"

# Refresh workflow dir in case it changed
WORKFLOW_DIR="$(get_workflow_dir)"

if [ -n "${WORKFLOW_DIR}" ]; then
    assert_file_exists "${WORKFLOW_DIR}/rounds/0/PLAN.md"   "plan: rounds/0/PLAN.md created"
    assert_file_exists "${WORKFLOW_DIR}/rounds/0/TASKS.csv" "plan: rounds/0/TASKS.csv created"
    assert_file_exists "${WORKFLOW_DIR}/SPEC.md" "plan: SPEC.md created"
    assert_file_contains "${WORKFLOW_DIR}/SPEC.md" "## Desired Result / User Experience" "plan: SPEC has Desired Result section"
    assert_file_contains "${WORKFLOW_DIR}/SPEC.md" "## Verification Design" "plan: SPEC has Verification Design section"
    # TC1: the generated SPEC's Verification Design must be a behavioral test
    # (a concrete invocation of the function under test), not a grep-source static check.
    awk '/^## Verification Design/{f=1;next} /^## /{f=0} f' "${WORKFLOW_DIR}/SPEC.md" > "${TEST_DIR}/spec_vd.txt"
    assert_file_contains "${TEST_DIR}/spec_vd.txt" "greet\\(" "plan: SPEC VD is a behavioral test (invokes greet)"
    assert_file_exists "${WORKFLOW_DIR}/VERIFY.csv" "plan: root VERIFY.csv created"
    assert_file_contains "${WORKFLOW_DIR}/VERIFY.csv" "self_check|test" "plan: TC11 VERIFY.csv has self_check/test type"
    # Assert CRITERIA.md was NOT created (superseded by VERIFY.csv)
    if [ ! -f "${WORKFLOW_DIR}/CRITERIA.md" ]; then
        pass "plan: CRITERIA.md absent (replaced by VERIFY.csv)"
    else
        echo "[assert] FAIL: CRITERIA.md should not exist; VERIFY.csv is used instead"
        fail "plan: CRITERIA.md absent (replaced by VERIFY.csv)"
    fi
    # TC8: assert grill conducted a clarification stage ([P.Clarify] question seen)
    if [ "${GRILL_CLARIFY_SEEN:-0}" -eq 1 ]; then
        pass "plan: TC8 grill conducted Clarify-stage questioning"
    else
        fail "plan: TC8 grill conducted Clarify-stage questioning"
    fi
else
    fail "plan: rounds/0/PLAN.md created"
    fail "plan: rounds/0/TASKS.csv created"
    fail "plan: SPEC.md created"
    fail "plan: SPEC has Desired Result section"
    fail "plan: SPEC has Verification Design section"
    fail "plan: SPEC VD is a behavioral test (invokes greet)"
    fail "plan: root VERIFY.csv created"
    fail "plan: TC11 VERIFY.csv has self_check/test type"
    fail "plan: CRITERIA.md absent (replaced by VERIFY.csv)"
    fail "plan: TC8 grill conducted Clarify-stage questioning"
fi

assert_status_field "plan_completed" "true" "plan: plan_completed=true"

# ---------------------------------------------------------------------------
# Step 3: /ca:execute — run executor agent, produce SUMMARY.md
# ---------------------------------------------------------------------------

inject_command "/ca:execute"
wait_for_stop 180
pane_log "execute-done"

WORKFLOW_DIR="$(get_workflow_dir)"

if [ -n "${WORKFLOW_DIR}" ]; then
    assert_file_exists "${WORKFLOW_DIR}/rounds/0/SUMMARY.md" "execute: rounds/0/SUMMARY.md created"
else
    fail "execute: rounds/0/SUMMARY.md created"
fi

assert_status_field "execute_completed" "true" "execute: execute_completed=true"
assert_file_exists "${TEST_DIR}/project/.ca/map.md" "execute: map.md exists after execute"

# ---------------------------------------------------------------------------
# Step 4: /ca:verify — run verifier agent, produce VERIFY-REPORT.md
# ---------------------------------------------------------------------------

inject_command "/ca:verify"

# Expect: Results acceptance prompt
wait_for_ask 180
assert_ask_header "Results" "verify: Results prompt"
sleep 1
select_option_by_text "Accept"

wait_for_stop 180
pane_log "verify-done"

WORKFLOW_DIR="$(get_workflow_dir)"

# Either VERIFY-REPORT.md exists or verify_completed is true (both are valid signals)
if [ -n "${WORKFLOW_DIR}" ] && [ -f "${WORKFLOW_DIR}/VERIFY-REPORT.md" ]; then
    pass "verify: VERIFY-REPORT.md created"
else
    # Fallback: check status field
    assert_status_field "verify_completed" "true" "verify: VERIFY-REPORT.md created"
fi

assert_status_field "verify_completed" "true" "verify: verify_completed=true"

# ---------------------------------------------------------------------------
# Step 5: /ca:finish — archive workflow to .ca/history/
# ---------------------------------------------------------------------------

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

# After finish, the workflow is moved to .ca/history/
HISTORY_DIR="${TEST_PROJECT}/.ca/history"

if [ -d "${HISTORY_DIR}" ] && [ "$(ls -A "${HISTORY_DIR}" 2>/dev/null)" ]; then
    pass "finish: workflow archived to history"
else
    fail "finish: workflow archived to history"
fi

# ---------------------------------------------------------------------------
# Step 6: /ca:restore — restore archived workflow
# ---------------------------------------------------------------------------

inject_command "/ca:restore"

# Expect: archive selection prompt
wait_for_ask 120
assert_ask_header "Restore|恢复" "restore: archive selection prompt"
sleep 1
select_option 1

wait_for_stop 180
pane_log "restore-done"

# Refresh workflow dir
WORKFLOW_DIR="$(get_workflow_dir)"

# Verify workflow restored to workflows/
if [ -n "${WORKFLOW_DIR}" ]; then
    assert_file_exists "${WORKFLOW_DIR}/STATUS.md" "restore: STATUS.md exists in workflows"
    assert_file_exists "${WORKFLOW_DIR}/BRIEF.md" "restore: BRIEF.md preserved"
else
    fail "restore: STATUS.md exists in workflows"
    fail "restore: BRIEF.md preserved"
fi

# Verify archive directory removed (history should be empty now)
if [ "$(ls -A "${HISTORY_DIR}" 2>/dev/null)" ]; then
    echo "[assert] FAIL: archive directory still exists in history"
    fail "restore: archive removed from history"
else
    pass "restore: archive removed from history"
fi

# Verify STATUS.md fields reset
if [ -n "${WORKFLOW_DIR}" ]; then
    assert_file_contains "${WORKFLOW_DIR}/STATUS.md" "verify_completed: false" "restore: verify_completed reset"
    assert_file_contains "${WORKFLOW_DIR}/STATUS.md" "current_step: plan" "restore: current_step is plan"
    assert_file_contains "${WORKFLOW_DIR}/STATUS.md" "fix_round: 1" "restore: fix_round set to 1"
    # Assert rounds/0/ survived the archive+restore round-trip
    if [ -d "${WORKFLOW_DIR}/rounds/0" ]; then
        pass "restore: rounds/0/ survived archive+restore"
    else
        echo "[assert] FAIL: rounds/0/ directory missing after restore"
        fail "restore: rounds/0/ survived archive+restore"
    fi
fi

# ---------------------------------------------------------------------------
# Results
# ---------------------------------------------------------------------------

summarize_results
