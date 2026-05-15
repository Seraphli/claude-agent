#!/usr/bin/env bash
# phase7_worktree_autoproceed.sh — E2E test for worktree mode + auto-proceed
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CA_REPO_ROOT="${CA_REPO_ROOT:-"$(cd "${SCRIPT_DIR}/../.." && pwd)"}"
export TEST_NAME="phase7-branch"
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

git -C "${TEST_PROJECT}" branch -M main 2>/dev/null || true

cat > "${TEST_PROJECT}/.ca/config.md" << 'CONFIG'
interaction_language: English
comment_language: English
code_language: English
use_worktrees: true
auto_proceed_to_verify: true
auto_proceed_to_plan: false
auto_delete_worktree: true
CONFIG

cat > "${TEST_CONFIG_DIR}/.claude/ca/config.md" << 'CONFIG'
interaction_language: English
comment_language: English
code_language: English
use_worktrees: true
auto_proceed_to_verify: true
auto_delete_worktree: true
CONFIG

start_claude
sleep 5
pane_log "startup"

# /ca:quick
inject_command "/ca:quick add a greet(name) function to utils.js that returns 'Hello, name!' All success criteria must be [auto], no [manual] items."
wait_for_ask 120
assert_ask_header "Add Todo" "quick: Add Todo prompt"
sleep 1
select_option_by_text "No.*skip"
wait_for_stop
pane_log "quick-done"

WORKFLOW_DIR="$(get_workflow_dir)"
if [ -n "${WORKFLOW_DIR}" ]; then
    assert_file_exists "${WORKFLOW_DIR}/BRIEF.md" "quick: BRIEF.md created"
    assert_file_contains "${WORKFLOW_DIR}/STATUS.md" "branch_name:" "quick: branch_name in STATUS"
    assert_file_contains "${WORKFLOW_DIR}/STATUS.md" "worktree_path:" "quick: worktree_path in STATUS"
else
    fail "quick: BRIEF.md created"
    fail "quick: branch_name in STATUS"
    fail "quick: worktree_path in STATUS"
fi

# Verify worktree directory exists (main repo stays on its current branch)
WORKTREE_PARENT="${TEST_PROJECT}-wt"
if [ -d "${WORKTREE_PARENT}" ] && ls -d "${WORKTREE_PARENT}"/ca-* > /dev/null 2>&1; then
    pass "quick: worktree directory created"
else
    echo "[assert] FAIL: expected worktree directory under ${WORKTREE_PARENT}"
    fail "quick: worktree directory created"
fi

# Verify main repo stays on main (not switched to ca/ branch)
CURRENT_BRANCH="$(git -C "${TEST_PROJECT}" branch --show-current)"
if [ "${CURRENT_BRANCH}" = "main" ]; then
    pass "quick: main repo stays on main branch"
else
    echo "[assert] FAIL: expected main repo on main, got ${CURRENT_BRANCH}"
    fail "quick: main repo stays on main branch"
fi

# /ca:plan
inject_command "/ca:next"
wait_for_ask 120
if echo "${LAST_ASK_HEADER}" | grep -qE "Research"; then
    pass "plan: Research prompt"
    sleep 1
    select_option_by_text "Skip"
    wait_for_ask
fi
assert_ask_header "Requirements" "plan: Requirements prompt"
sleep 1
select_option_by_text "Correct"

wait_for_ask_expect "Rough Plan" "" 90
assert_ask_header "Rough Plan" "plan: Rough Plan prompt"
sleep 1
select_option_by_text "Feasible"

# Expect: Step-by-step plan confirmation (Confirmation 2b)
wait_for_step_confirmations "Results" "plan" 90
assert_ask_header "Results" "plan: Results prompt"
sleep 1
select_option_by_text "Yes"

wait_for_stop 120
pane_log "plan-done"

# /ca:execute (auto-proceeds to verify)
inject_command "/ca:execute"
wait_for_ask 240
assert_ask_header "Results" "verify: Results prompt (auto-proceed)"
sleep 1
select_option_by_text "Accept"
wait_for_stop 120
pane_log "verify-done"

# WIP commit lands in the worktree branch; check worktree dir if it exists, else main repo
WORKTREE_DIR="$(ls -d "${WORKTREE_PARENT}"/ca-* 2>/dev/null | head -1 || true)"
if [ -n "${WORKTREE_DIR}" ]; then
    WIP_COMMIT="$(git -C "${WORKTREE_DIR}" log --oneline -5 | grep -i "wip" || true)"
else
    WIP_COMMIT="$(git -C "${TEST_PROJECT}" log --oneline -5 | grep -i "wip" || true)"
fi
if [ -n "${WIP_COMMIT}" ]; then
    pass "execute: wip commit on branch"
else
    fail "execute: wip commit on branch"
fi

assert_status_field "verify_completed" "true" "verify: verify_completed=true"

# /ca:finish
inject_command "/ca:finish"
wait_for_ask 120
assert_ask_header "Commit" "finish: Commit prompt"
sleep 1
select_option_by_text "Confirm"

wait_for_stop 120
pane_log "finish-done"

# Verify worktree removed after finish
if [ -d "${WORKTREE_PARENT}" ] && ls -d "${WORKTREE_PARENT}"/ca-* > /dev/null 2>&1; then
    echo "[assert] FAIL: worktree directory still exists under ${WORKTREE_PARENT}"
    fail "finish: worktree removed"
else
    pass "finish: worktree removed"
fi

if git -C "${TEST_PROJECT}" branch | grep -q "ca/"; then
    echo "[assert] FAIL: ca/ branch still exists"
    fail "finish: workflow branch deleted"
else
    pass "finish: workflow branch deleted"
fi

if [ -d "${TEST_PROJECT}/.ca/history" ] && [ "$(ls -A "${TEST_PROJECT}/.ca/history" 2>/dev/null)" ]; then
    pass "finish: workflow archived"
else
    fail "finish: workflow archived"
fi

summarize_results
