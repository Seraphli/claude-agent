#!/usr/bin/env bash
# phase4_i18n.sh — E2E test for Chinese (中文) locale support
# Runs a quick workflow with interaction_language: 中文 and asserts Chinese headers.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CA_REPO_ROOT="${CA_REPO_ROOT:-"$(cd "${SCRIPT_DIR}/../.." && pwd)"}"
export TEST_NAME="phase4-i18n"

source "${CA_REPO_ROOT}/tests/e2e_common.sh"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

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

trap 'cleanup' EXIT
setup_test_env

# Override workspace config to Chinese
cat > "${TEST_DIR}/project/.ca/config.md" << 'CNCONFIG'
interaction_language: 中文
comment_language: English
code_language: English
use_branches: false
auto_proceed_to_plan: false
auto_proceed_to_verify: false
CNCONFIG

start_claude
sleep 5
pane_log "startup"

# ---------------------------------------------------------------------------
# Step 1: /ca:quick
# ---------------------------------------------------------------------------

inject_command "/ca:quick add a greet(name) function to utils.js that returns 'Hello, name!'"
wait_for_ask 300
assert_ask_header "添加待办|Add Todo" "quick: todo prompt (中文)"
sleep 1
select_option_by_text "跳过|No.*skip"
wait_for_stop 300
pane_log "quick-done"

WORKFLOW_DIR="$(get_workflow_dir)"
if [ -n "${WORKFLOW_DIR}" ]; then
    assert_file_exists "${WORKFLOW_DIR}/BRIEF.md" "quick: BRIEF.md created"
else
    fail "quick: BRIEF.md created"
fi

# ---------------------------------------------------------------------------
# Step 2: /ca:plan
# ---------------------------------------------------------------------------

inject_command "/ca:plan"

# Research is optional — model may skip directly to Requirements
wait_for_ask 300
if echo "${LAST_ASK_HEADER}" | grep -qE "研究|Research"; then
    pass "plan: Research prompt (中文)"
    sleep 1
    select_option_by_text "跳过|Skip"
    wait_for_ask 300
fi
assert_ask_header "需求|Requirements" "plan: Requirements prompt (中文)"
sleep 1
select_option_by_text "正确|Correct"

wait_for_ask 300
assert_ask_header "粗略方案|Rough Plan" "plan: Rough Plan prompt (中文)"
sleep 1
select_option_by_text "可行|Feasible"

wait_for_ask 300
assert_ask_header "详细方案|Detailed Plan" "plan: Detailed Plan prompt (中文)"
sleep 1
select_option_by_text "同意|Agree"

wait_for_ask 300
assert_ask_header "结果|Results" "plan: Results prompt (中文)"
sleep 1
select_option_by_text "是|Yes"

wait_for_stop 300
pane_log "plan-done"

assert_status_field "plan_completed" "true" "plan: plan_completed=true"

# ---------------------------------------------------------------------------
# Step 3: /ca:execute
# ---------------------------------------------------------------------------

inject_command "/ca:execute"
wait_for_stop 600
pane_log "execute-done"

assert_status_field "execute_completed" "true" "execute: execute_completed=true"

# ---------------------------------------------------------------------------
# Step 4: /ca:verify
# ---------------------------------------------------------------------------

inject_command "/ca:verify"
wait_for_ask 600
assert_ask_header "结果|Results" "verify: Results prompt (中文)"
sleep 1
select_option_by_text "接受|Accept"
wait_for_stop 600
pane_log "verify-done"

assert_status_field "verify_completed" "true" "verify: verify_completed=true"

# ---------------------------------------------------------------------------
# Step 5: /ca:finish
# ---------------------------------------------------------------------------

inject_command "/ca:finish"

wait_for_ask 120
assert_ask_header "提交|Commit" "finish: Commit prompt (中文)"
sleep 1
select_option_by_text "是|Yes"

wait_for_ask 120
assert_ask_header "确认|Confirm" "finish: Confirm prompt (中文)"
sleep 1
select_option_by_text "确认|Confirm|是|Yes"

wait_for_stop 300
pane_log "finish-done"

# Assert workflow archived
PROJECT_DIR="${TEST_DIR}/project"
if [ -d "${PROJECT_DIR}/.ca/history" ] && [ "$(ls -A "${PROJECT_DIR}/.ca/history" 2>/dev/null)" ]; then
    pass "finish: workflow archived to history"
else
    fail "finish: workflow archived to history"
fi

summarize_results
