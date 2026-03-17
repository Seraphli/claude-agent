#!/usr/bin/env bash
# phase2_standard.sh — E2E test for the standard workflow:
#   /ca-new → /ca-discuss → /ca-plan → /ca-execute → /ca-verify → /ca-finish
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
# Returns the full path to the active workflow dir, or empty string if not found.
get_workflow_dir() {
    local project_dir="${TEST_DIR}/project"
    local active_file="${project_dir}/.ca/active.md"
    if [ ! -f "${active_file}" ]; then
        echo ""
        return
    fi
    local workflow_id
    workflow_id="$(cat "${active_file}")"
    echo "${project_dir}/.ca/workflows/${workflow_id}"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

# Register cleanup trap so temp files are removed even on error
trap 'cleanup' EXIT

# Create isolated environment (sets TEST_DIR, TEST_CONFIG_DIR, RESULTS_FILE)
setup_test_env

# Start Claude in a tmux session inside the project directory
start_claude

# Wait for Claude to be ready at the initial prompt
sleep 5
pane_log "startup"

# ============================================================
# Step 1: /ca-new — create a new standard workflow
# ============================================================

inject_command "/ca-new Add a hello command to utils.js. All success criteria must be auto-verifiable via bash commands"
wait_for_ask 300
assert_ask_header "Add Todo" "new: Add Todo prompt"
sleep 1
select_option_by_text "No.*skip"
wait_for_stop 300
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
# Step 2: /ca-discuss — finalize requirements
# ============================================================

inject_command "/ca-discuss"

# discuss has variable clarifying questions before final "Requirements" confirmation
for i in $(seq 1 10); do
    wait_for_ask 300
    if echo "${LAST_ASK_HEADER}" | grep -qE "Requirements"; then
        assert_ask_header "Requirements" "discuss: Requirements prompt"
        sleep 1
        select_option_by_text "Accurate"
        break
    fi
    echo "[discuss] clarifying question ${i}: ${LAST_ASK_HEADER}"
    sleep 1
    select_option_smart 1
done

wait_for_stop 300
pane_log "discuss-done"

# --- Assertions: discuss ---
WORKFLOW_DIR="$(get_workflow_dir)"

if [ -n "${WORKFLOW_DIR}" ]; then
    assert_file_exists "${WORKFLOW_DIR}/REQUIREMENT.md" "discuss: REQUIREMENT.md exists"
else
    fail "discuss: REQUIREMENT.md exists"
fi

assert_status_field "discuss_completed" "true" "discuss: discuss_completed=true"

# ============================================================
# Step 3: /ca-plan — create plan and criteria
# ============================================================

inject_command "/ca-plan"

# Expect: Requirements confirmation
wait_for_ask 300
assert_ask_header "Requirements" "plan: Requirements prompt"
sleep 1
select_option_by_text "Correct"

# Expect: Rough Plan confirmation
wait_for_ask 300
assert_ask_header "Rough Plan" "plan: Rough Plan prompt"
sleep 1
select_option_by_text "Feasible"

# Expect: Detailed Plan confirmation
wait_for_ask 300
assert_ask_header "Detailed Plan" "plan: Detailed Plan prompt"
sleep 1
select_option_by_text "Agree"

# Expect: Results confirmation
wait_for_ask 300
assert_ask_header "Results" "plan: Results prompt"
sleep 1
select_option_by_text "Yes"

wait_for_stop 300
pane_log "plan-done"

# --- Assertions: plan ---
WORKFLOW_DIR="$(get_workflow_dir)"

if [ -n "${WORKFLOW_DIR}" ]; then
    assert_file_exists "${WORKFLOW_DIR}/PLAN.md"     "plan: PLAN.md exists"
    assert_file_exists "${WORKFLOW_DIR}/CRITERIA.md" "plan: CRITERIA.md exists"
else
    fail "plan: PLAN.md exists"
    fail "plan: CRITERIA.md exists"
fi

assert_status_field "plan_completed" "true" "plan: plan_completed=true"

# ============================================================
# Step 4: /ca-execute — run the plan
# ============================================================

inject_command "/ca-execute"
wait_for_stop 600
pane_log "execute-done"

# --- Assertions: execute ---
WORKFLOW_DIR="$(get_workflow_dir)"

if [ -n "${WORKFLOW_DIR}" ]; then
    assert_file_exists "${WORKFLOW_DIR}/SUMMARY.md" "execute: SUMMARY.md exists"
else
    fail "execute: SUMMARY.md exists"
fi

assert_status_field "execute_completed" "true" "execute: execute_completed=true"

# ============================================================
# Step 5: /ca-verify — run verification
# ============================================================

inject_command "/ca-verify"
wait_for_ask 600
assert_ask_header "Results" "verify: Results prompt"
sleep 1
select_option_by_text "Accept"
wait_for_stop 600
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
# Step 6: /ca-finish — archive the workflow
# ============================================================

inject_command "/ca-finish"

# Expect: Commit prompt
wait_for_ask 120
assert_ask_header "Commit" "finish: Commit prompt"
sleep 1
select_option_by_text "Yes"

# Expect: Confirm prompt
wait_for_ask 120
assert_ask_header "Confirm" "finish: Confirm prompt"
sleep 1
select_option_by_text "Yes"

wait_for_stop 300
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
