#!/usr/bin/env bash
# phase10_multi_workflow.sh — E2E test for multi-workflow and next routing
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CA_REPO_ROOT="${CA_REPO_ROOT:-"$(cd "${SCRIPT_DIR}/../.." && pwd)"}"
export TEST_NAME="phase10-multi"
source "${CA_REPO_ROOT}/tests/e2e_common.sh"

setup_test_env
TEST_PROJECT="${TEST_DIR}/project"
trap 'cleanup' EXIT

start_claude
sleep 5
pane_log "startup"

echo "[test] 1: Create workflow 1"
inject_command "/ca:quick add a hello function. All success criteria must be [auto], no [manual] items."
wait_for_ask 120
assert_ask_header "Todo" "quick1: Add Todo prompt"
sleep 1
select_option_by_text "No.*skip"
wait_for_stop
pane_log "quick1-done"

# Verify workflow 1 directory exists
if [ -d "${TEST_PROJECT}/.ca/workflows" ]; then
    WF1=$(ls "${TEST_PROJECT}/.ca/workflows/" | head -1)
    if [ -n "${WF1}" ]; then
        pass "multi: workflow 1 created (${WF1})"
    else
        fail "multi: workflow 1 created"
    fi
else
    fail "multi: workflow 1 created"
fi

echo "[test] 2: Create workflow 2"
inject_command "/ca:quick add a goodbye function. All success criteria must be [auto], no [manual] items."
wait_for_ask 120
assert_ask_header "Workflow" "quick2: Workflow prompt (existing)"
sleep 1
select_option_by_text "Keep"

wait_for_ask
assert_ask_header "Todo" "quick2: Add Todo prompt"
sleep 1
select_option_by_text "No.*skip"
wait_for_stop
pane_log "quick2-done"

# Verify two workflow directories exist
WF_COUNT=$(ls "${TEST_PROJECT}/.ca/workflows/" | wc -l)
if [ "${WF_COUNT}" -ge 2 ]; then
    pass "multi: two workflow directories exist"
else
    fail "multi: two workflow directories exist (got ${WF_COUNT})"
fi

# Verify no active.md file exists
if [ ! -f "${TEST_PROJECT}/.ca/active.md" ]; then
    pass "multi: no active.md file"
else
    fail "multi: no active.md file (should not exist)"
fi

echo "[test] 3: /ca:next with multiple workflows (after /clear)"
# Clear context to remove context inference, forcing workflow selection
inject_command "/clear"
sleep 3

inject_command "/ca:next"
# With 2 workflows and no context inference, must prompt Workflow selection
wait_for_ask 120
pane_log "next-done"
if echo "${LAST_ASK_HEADER}" | grep -qE "Workflow"; then
    pass "next: prompted Workflow selection with multiple workflows"
else
    fail "next: expected Workflow selection prompt, got '${LAST_ASK_HEADER}'"
fi
sleep 1
select_option 1
pass "next: workflow selected"

summarize_results
