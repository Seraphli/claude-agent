#!/usr/bin/env bash
# phase7_branch_autoproceed.sh — E2E test for branch mode + auto-proceed
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CA_REPO_ROOT="${CA_REPO_ROOT:-"$(cd "${SCRIPT_DIR}/../.." && pwd)"}"
export TEST_NAME="phase7-branch"
source "${CA_REPO_ROOT}/tests/e2e_common.sh"

get_workflow_dir() {
    local project_dir="${TEST_DIR}/project"
    local active_file="${project_dir}/.ca/active.md"
    [ ! -f "${active_file}" ] && { echo ""; return; }
    local wid; wid="$(cat "${active_file}")"
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
use_branches: true
auto_proceed_to_verify: true
auto_proceed_to_plan: false
auto_delete_branch: true
CONFIG

cat > "${TEST_CONFIG_DIR}/.claude/ca/config.md" << 'CONFIG'
interaction_language: English
comment_language: English
code_language: English
use_branches: true
auto_proceed_to_verify: true
auto_delete_branch: true
CONFIG

start_claude
sleep 5
pane_log "startup"

# /ca:quick
inject_command "/ca:quick add a greet(name) function to utils.js that returns 'Hello, name!' All success criteria must be [auto], no [manual] items."
wait_for_ask 300
assert_ask_header "Add Todo" "quick: Add Todo prompt"
sleep 1
select_option_by_text "No.*skip"
wait_for_stop 300
pane_log "quick-done"

WORKFLOW_DIR="$(get_workflow_dir)"
if [ -n "${WORKFLOW_DIR}" ]; then
    assert_file_exists "${WORKFLOW_DIR}/BRIEF.md" "quick: BRIEF.md created"
    assert_file_contains "${WORKFLOW_DIR}/STATUS.md" "branch_name:" "quick: branch_name in STATUS"
else
    fail "quick: BRIEF.md created"
    fail "quick: branch_name in STATUS"
fi

CURRENT_BRANCH="$(git -C "${TEST_PROJECT}" branch --show-current)"
if echo "${CURRENT_BRANCH}" | grep -q "^ca/"; then
    pass "quick: on ca/ branch"
else
    echo "[assert] FAIL: expected ca/ branch, got ${CURRENT_BRANCH}"
    fail "quick: on ca/ branch"
fi

# /ca:plan
inject_command "/ca:next"
wait_for_ask 300
if echo "${LAST_ASK_HEADER}" | grep -qE "Research"; then
    pass "plan: Research prompt"
    sleep 1
    select_option_by_text "Skip"
    wait_for_ask 300
fi
assert_ask_header "Requirements" "plan: Requirements prompt"
sleep 1
select_option_by_text "Correct"

wait_for_ask_expect "Rough Plan" "" 300
assert_ask_header "Rough Plan" "plan: Rough Plan prompt"
sleep 1
select_option_by_text "Feasible"

wait_for_ask_expect "Detailed Plan" "" 300
assert_ask_header "Detailed Plan" "plan: Detailed Plan prompt"
sleep 1
select_option_by_text "Agree"

wait_for_ask_expect "Results" "" 300
assert_ask_header "Results" "plan: Results prompt"
sleep 1
select_option_by_text "Yes"

wait_for_stop 300
pane_log "plan-done"

# /ca:execute (auto-proceeds to verify)
inject_command "/ca:execute"
wait_for_ask 900
assert_ask_header "Results" "verify: Results prompt (auto-proceed)"
sleep 1
select_option_by_text "Accept"
wait_for_stop 600
pane_log "verify-done"

WIP_COMMIT="$(git -C "${TEST_PROJECT}" log --oneline -5 | grep -i "wip" || true)"
if [ -n "${WIP_COMMIT}" ]; then
    pass "execute: wip commit on branch"
else
    fail "execute: wip commit on branch"
fi

assert_status_field "verify_completed" "true" "verify: verify_completed=true"

# /ca:finish
inject_command "/ca:finish"
wait_for_ask 300
assert_ask_header "Commit" "finish: Commit prompt"
sleep 1
select_option_by_text "Confirm"

wait_for_stop 300
pane_log "finish-done"

FINAL_BRANCH="$(git -C "${TEST_PROJECT}" branch --show-current)"
if [ "${FINAL_BRANCH}" = "main" ]; then
    pass "finish: back on main branch"
else
    echo "[assert] FAIL: expected main, got ${FINAL_BRANCH}"
    fail "finish: back on main branch"
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
