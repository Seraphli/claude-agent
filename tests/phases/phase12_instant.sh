#!/usr/bin/env bash
# phase12_instant.sh — E2E test for instant workflow with worktree mode
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CA_REPO_ROOT="${CA_REPO_ROOT:-"$(cd "${SCRIPT_DIR}/../.." && pwd)"}"
export TEST_NAME="phase12-instant"
source "${CA_REPO_ROOT}/tests/e2e_common.sh"

get_workflow_dir() {
    local project_dir="${TEST_DIR}/project"
    local wid; wid="$(ls "${project_dir}/.ca/workflows/" 2>/dev/null | head -1)"
    [ -z "${wid}" ] && { echo ""; return; }
    echo "${project_dir}/.ca/workflows/${wid}"
}

setup_test_env
TEST_PROJECT="${TEST_DIR}/project"
trap 'cleanup' EXIT

# Enable worktree mode
git -C "${TEST_PROJECT}" branch -M main 2>/dev/null || true

cat > "${TEST_PROJECT}/.ca/config.md" << 'CONFIG'
interaction_language: English
comment_language: English
code_language: English
use_worktrees: true
auto_proceed_to_verify: false
auto_proceed_to_plan: false
auto_delete_worktree: true
CONFIG

cat > "${TEST_CONFIG_DIR}/.claude/ca/config.md" << 'CONFIG'
interaction_language: English
comment_language: English
code_language: English
use_worktrees: true
auto_delete_worktree: true
CONFIG

start_claude
sleep 5
pane_log "startup"

# --- /ca:instant ---
inject_command "/ca:instant add a greet(name) function to utils.js that returns 'Hello, name!' All success criteria must be [auto], no [manual] items."
wait_for_ask 120
assert_ask_header "Todo" "instant: Add Todo prompt"
sleep 1
select_option_by_text "No.*skip"
wait_for_stop 120
pane_log "instant-done"

# TC18: assert NO active.md after /ca:instant
active_file="${TEST_PROJECT}/.ca/active.md"
if [ ! -f "${active_file}" ]; then
    pass "instant: no active.md after /ca:instant (TC18)"
else
    fail "instant: no active.md after /ca:instant (TC18)"
fi

WORKFLOW_DIR="$(get_workflow_dir)"
if [ -n "${WORKFLOW_DIR}" ]; then
    assert_file_exists "${WORKFLOW_DIR}/BRIEF.md" "instant: BRIEF.md created"
    assert_file_exists "${WORKFLOW_DIR}/STATUS.md" "instant: STATUS.md created"
    assert_status_field "workflow_type" "instant" "instant: workflow_type=instant"
    assert_file_contains "${WORKFLOW_DIR}/STATUS.md" "branch_name:" "instant: branch_name in STATUS"
    assert_file_contains "${WORKFLOW_DIR}/STATUS.md" "worktree_path:" "instant: worktree_path in STATUS"
else
    fail "instant: BRIEF.md created"
    fail "instant: STATUS.md created"
    fail "instant: workflow_type=instant"
    fail "instant: branch_name in STATUS"
    fail "instant: worktree_path in STATUS"
fi

# Record event count before plan for negative guard scoping
PLAN_START_EVENT_COUNT=$(wc -l < "${EVENT_LOG}" 2>/dev/null || echo "0")

# --- /ca:plan (single confirmation) ---
inject_command "/ca:plan"

# Research (skip)
wait_for_ask 120
if echo "${LAST_ASK_HEADER}" | grep -qE "Research"; then
    pass "plan: Research prompt"
    sleep 1
    select_option_by_text "Skip"
    wait_for_ask
fi

# Single confirmation — header MUST be "[P.Plan]"
assert_ask_header "\[P\.Plan\]" "plan: single confirmation (header=[P.Plan])"
sleep 1
select_option_by_text "Confirm"
wait_for_stop 120
pane_log "plan-done"

# Negative guard: check AskUserQuestion headers during plan phase only
PLAN_END_EVENT_COUNT=$(wc -l < "${EVENT_LOG}" 2>/dev/null || echo "0")
PLAN_EVENTS=$(sed -n "$((PLAN_START_EVENT_COUNT+1)),${PLAN_END_EVENT_COUNT}p" "${EVENT_LOG}")
PLAN_ASK_HEADERS=$(echo "${PLAN_EVENTS}" | grep '"tool_name":"AskUserQuestion"' | jq -r '.payload.tool_input.questions[0].header // empty' 2>/dev/null || true)

for forbidden_header in "[P.Reqs]" "[P.SPEC]" "[P.Rough]" "[P.Results]" "[P.Clarify]"; do
    if echo "${PLAN_ASK_HEADERS}" | grep -qF "${forbidden_header}"; then
        fail "plan: no '${forbidden_header}' header in instant plan"
    else
        pass "plan: no '${forbidden_header}' header in instant plan"
    fi
done
if echo "${PLAN_ASK_HEADERS}" | grep -qE "\[P\.Step"; then
    fail "plan: no 'Step N' headers in instant plan"
else
    pass "plan: no 'Step N' headers in instant plan"
fi

WORKFLOW_DIR="$(get_workflow_dir)"
if [ -n "${WORKFLOW_DIR}" ]; then
    assert_file_exists "${WORKFLOW_DIR}/rounds/0/PLAN.md" "plan: rounds/0/PLAN.md created"
    assert_file_exists "${WORKFLOW_DIR}/rounds/0/TASKS.csv" "plan: rounds/0/TASKS.csv created"
    assert_file_exists "${WORKFLOW_DIR}/VERIFY.csv" "plan: root VERIFY.csv created"
    assert_file_contains "${WORKFLOW_DIR}/VERIFY.csv" "test|self_check" "plan: VERIFY.csv has criterion type"
    if [ -f "${WORKFLOW_DIR}/CRITERIA.md" ]; then
        fail "plan: no CRITERIA.md for instant workflow (replaced by VERIFY.csv)"
    else
        pass "plan: no CRITERIA.md for instant workflow (replaced by VERIFY.csv)"
    fi
    if [ -f "${WORKFLOW_DIR}/SPEC.md" ]; then
        fail "plan: no SPEC.md for instant workflow"
    else
        pass "plan: no SPEC.md for instant workflow"
    fi
else
    fail "plan: rounds/0/PLAN.md created"
    fail "plan: rounds/0/TASKS.csv created"
    fail "plan: root VERIFY.csv created"
    fail "plan: VERIFY.csv has criterion type"
    fail "plan: no CRITERIA.md for instant workflow (replaced by VERIFY.csv)"
    fail "plan: no SPEC.md for instant workflow"
fi
assert_status_field "plan_completed" "true" "plan: plan_completed=true"

# --- /ca:execute ---
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

# Verify wip commit in worktree
WORKTREE_PATH=$(grep "worktree_path:" "${WORKFLOW_DIR}/STATUS.md" | awk '{print $2}')
if [ -n "${WORKTREE_PATH}" ] && [ -d "${WORKTREE_PATH}" ]; then
    if git -C "${WORKTREE_PATH}" log --oneline -1 | grep -q "wip:"; then
        pass "execute: wip commit in worktree"
    else
        fail "execute: wip commit in worktree"
    fi
else
    fail "execute: wip commit in worktree (worktree not found)"
fi

# --- /ca:next (should route to verify for instant) ---
inject_command "/ca:next"
wait_for_ask 120
assert_ask_header "Results" "verify: Results prompt"
sleep 1
select_option_by_text "Accept"
wait_for_stop 120
pane_log "verify-done"
assert_status_field "verify_completed" "true" "verify: verify_completed=true"

# --- /ca:finish (worktree mode squash) ---
inject_command "/ca:finish"
wait_for_ask 120
assert_ask_header "Commit" "finish: Commit prompt"
sleep 1
select_option_by_text "Confirm"
wait_for_stop 180
pane_log "finish-done"

# Verify worktree removed
WORKTREE_PARENT="$(dirname "${TEST_PROJECT}")/$(basename "${TEST_PROJECT}")-wt"
if [ -d "${WORKTREE_PARENT}" ] && ls -d "${WORKTREE_PARENT}"/ca-* > /dev/null 2>&1; then
    fail "finish: worktree removed"
else
    pass "finish: worktree removed"
fi

# Verify backing branch deleted
if git -C "${TEST_PROJECT}" branch | grep -q "ca/"; then
    fail "finish: backing branch deleted"
else
    pass "finish: backing branch deleted"
fi

# Verify archived
if [ -d "${TEST_PROJECT}/.ca/history" ] && [ "$(ls -A "${TEST_PROJECT}/.ca/history" 2>/dev/null)" ]; then
    pass "finish: workflow archived"
else
    fail "finish: workflow archived"
fi

###############################################################################
# Sub-scenario A: Fix loop — verify fail → instant plan still single confirmation
###############################################################################

# Create a new instant workflow with pre-set executed state and a must-fail criterion
inject_command "/ca:instant fix a deliberate test failure"
wait_for_ask 120
assert_ask_header "Todo" "fixloop: Add Todo prompt"
sleep 1
select_option_by_text "No.*skip"
wait_for_stop 120
pane_log "fixloop-instant-done"

# Resolve the FIXLOOP workflow explicitly (newest by mtime, not alphabetical)
FIXLOOP_WF="$(ls -t "${TEST_PROJECT}/.ca/workflows/" | head -1)"
WORKFLOW_DIR="${TEST_PROJECT}/.ca/workflows/${FIXLOOP_WF}"
echo "[fixloop] resolved workflow: ${FIXLOOP_WF} → ${WORKFLOW_DIR}"

# Write rounds/0/PLAN.md, rounds/0/SUMMARY.md, and seed VERIFY.csv (no CRITERIA.md)
mkdir -p "${WORKFLOW_DIR}/rounds/0"
cat > "${WORKFLOW_DIR}/rounds/0/PLAN.md" << 'PLANEOF'
# Implementation Plan
## Requirement Summary
Fix a deliberate test failure
## Approach
Deliberately fail
## Implementation Steps
1. No-op
## Step Details
### Step 1: No-op
No changes needed.
## Expected Results
This will fail verification.
PLANEOF

cat > "${WORKFLOW_DIR}/rounds/0/SUMMARY.md" << 'SUMEOF'
# Execution Summary
## Changes Made
- No changes
## Steps Completed
1. No-op
SUMEOF

# Seed root VERIFY.csv with one failing test/auto criterion
FIXLOOP_CSV="${TEST_CONFIG_DIR}/.claude/ca/scripts/ca-csv.js"
node "${FIXLOOP_CSV}" init-verify --file "${WORKFLOW_DIR}/VERIFY.csv"
node "${FIXLOOP_CSV}" add-criterion \
    --file "${WORKFLOW_DIR}/VERIFY.csv" \
    --type test \
    --method auto \
    --criterion "File nonexistent_file_that_must_exist.txt exists in project root"

# Set execute_completed=true, plan_completed=true, plan_confirmed=true (explicit --workflow-id!)
node "${TEST_CONFIG_DIR}/.claude/ca/scripts/ca-status.js" update \
    --project-root "${TEST_PROJECT}" --workflow-id "${FIXLOOP_WF}" \
    execute_completed=true plan_completed=true plan_confirmed=true current_step=execute

# auto_fix defaults to false, so verify fail enters manual fix round → /ca:plan single confirmation

# Run verify — should fail and enter manual fix round
inject_command "/ca:verify"
wait_for_stop 180
pane_log "fixloop-verify-done"

# Assert: fix_round incremented, plan_completed reset (use FIXLOOP_WF consistently)
assert_status_field "plan_completed" "false" "fixloop: plan_completed reset after verify fail"
assert_file_exists "${WORKFLOW_DIR}/rounds/0/ISSUES.md" "fixloop: rounds/0/ISSUES.md created"

# Run plan — should use single confirmation (header "[P.Plan]"), not triple confirmation
# Note: verify may leave uncompleted tasks, so plan Step 0 may show "Tasks" cleanup prompt first
inject_command "/ca:plan"
wait_for_ask 120
if echo "${LAST_ASK_HEADER}" | grep -qE "Tasks"; then
    pass "fixloop-plan: Tasks cleanup prompt"
    sleep 1
    select_option_by_text "Clear"
    wait_for_ask 120
fi
if echo "${LAST_ASK_HEADER}" | grep -qE "Research"; then
    pass "fixloop-plan: Research prompt"
    sleep 1
    select_option_by_text "Skip"
    wait_for_ask 120
fi
assert_ask_header "\[P\.Plan\]" "fixloop-plan: single confirmation (header=[P.Plan])"
sleep 1
select_option_by_text "Confirm"
wait_for_stop 120
pane_log "fixloop-plan-done"

# Archive fixloop workflow so Sub-scenario B starts with no active workflows
mv "${WORKFLOW_DIR}" "${TEST_PROJECT}/.ca/history/"
pass "fixloop: archived ${FIXLOOP_WF} to .ca/history/"

###############################################################################
# Sub-scenario B: Non-worktree wip commit — use_worktrees:false + instant execute
###############################################################################

# Switch config to non-worktree mode
sed -i 's/^use_worktrees: true/use_worktrees: false/' "${TEST_PROJECT}/.ca/config.md"
sed -i 's/^use_worktrees: true/use_worktrees: false/' "${TEST_CONFIG_DIR}/.claude/ca/config.md"

# Create a new instant workflow (non-worktree mode)
# Note: sub-scenario A left an active workflow, so /ca:instant will prompt about it first
inject_command "/ca:instant add a farewell(name) function to utils.js that returns 'Goodbye, name!'"
wait_for_ask 120
if echo "${LAST_ASK_HEADER}" | grep -qE "Workflow"; then
    pass "non-worktree: Workflow prompt for existing active workflow"
    sleep 1
    select_option_by_text "Keep"
    wait_for_ask
fi
assert_ask_header "Todo" "non-worktree: Add Todo prompt"
sleep 1
select_option_by_text "No.*skip"
wait_for_stop 120
pane_log "nonbranch-instant-done"

WORKFLOW_DIR="$(get_workflow_dir)"
# Confirm no worktree_path in STATUS
if grep -q "worktree_path:" "${WORKFLOW_DIR}/STATUS.md" 2>/dev/null; then
    fail "non-worktree: no worktree_path in STATUS"
else
    pass "non-worktree: no worktree_path in STATUS"
fi

# Plan (single confirmation)
inject_command "/ca:plan"
wait_for_ask 120
if echo "${LAST_ASK_HEADER}" | grep -qE "Tasks"; then
    sleep 1
    select_option_by_text "Clear"
    wait_for_ask
fi
if echo "${LAST_ASK_HEADER}" | grep -qE "Research"; then
    sleep 1
    select_option_by_text "Skip"
    wait_for_ask
fi
assert_ask_header "\[P\.Plan\]" "non-worktree-plan: single confirmation"
sleep 1
select_option_by_text "Confirm"
wait_for_stop 120
pane_log "nonbranch-plan-done"

# Execute
inject_command "/ca:execute"
wait_for_stop 120
pane_log "nonbranch-execute-done"

# Assert wip commit in project root (not worktree)
if git -C "${TEST_PROJECT}" log --oneline -1 | grep -q "wip:"; then
    pass "non-worktree: wip commit in project root"
else
    fail "non-worktree: wip commit in project root"
fi

###############################################################################
# Sub-scenario C: Legacy config key backward compatibility
###############################################################################

# Write old key names to a temp config and verify ca-config.js normalizes them
cat > "${TEST_PROJECT}/.ca/config.md" << 'LEGACY'
interaction_language: English
use_branches: false
auto_delete_branch: false
LEGACY

CONFIG_OUTPUT=$(node "${TEST_CONFIG_DIR}/.claude/ca/scripts/ca-config.js" --project-root "${TEST_PROJECT}" 2>&1)
if echo "${CONFIG_OUTPUT}" | grep -q "use_worktrees: false"; then
    pass "legacy-compat: use_branches normalized to use_worktrees"
else
    fail "legacy-compat: use_branches normalized to use_worktrees"
fi
if echo "${CONFIG_OUTPUT}" | grep -q "auto_delete_worktree: false"; then
    pass "legacy-compat: auto_delete_branch normalized to auto_delete_worktree"
else
    fail "legacy-compat: auto_delete_branch normalized to auto_delete_worktree"
fi

summarize_results
