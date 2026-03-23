#!/usr/bin/env bash
# phase10_multi_workflow.sh — E2E test for switch and next commands
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CA_REPO_ROOT="${CA_REPO_ROOT:-"$(cd "${SCRIPT_DIR}/../.." && pwd)"}"
export TEST_NAME="phase10-multi"
source "${CA_REPO_ROOT}/tests/e2e_common.sh"

get_active_id() {
    local active_file="${TEST_DIR}/project/.ca/active.md"
    [ -f "${active_file}" ] && cat "${active_file}" || echo ""
}

setup_test_env
TEST_PROJECT="${TEST_DIR}/project"
trap 'cleanup' EXIT

start_claude
sleep 5
pane_log "startup"

echo "[test] 1: Create workflow 1"
inject_command "/ca:quick add a hello function. All success criteria must be [auto], no [manual] items."
wait_for_ask 300
assert_ask_header "Add Todo" "quick1: Add Todo prompt"
sleep 1
select_option_by_text "No.*skip"
wait_for_stop 300
pane_log "quick1-done"

ACTIVE_1="$(get_active_id)"

echo "[test] 2: Create workflow 2"
inject_command "/ca:quick add a goodbye function. All success criteria must be [auto], no [manual] items."
wait_for_ask 300
assert_ask_header "Workflow" "quick2: Workflow prompt (existing)"
sleep 1
select_option_by_text "Keep"

wait_for_ask 300
assert_ask_header "Add Todo" "quick2: Add Todo prompt"
sleep 1
select_option_by_text "No.*skip"
wait_for_stop 300
pane_log "quick2-done"

ACTIVE_2="$(get_active_id)"
if [ "${ACTIVE_1}" != "${ACTIVE_2}" ]; then
    pass "multi: two different workflow IDs"
else
    fail "multi: two different workflow IDs"
fi

echo "[test] 3: /ca:switch"
inject_command "/ca:switch"
# LLM may or may not show Switch AskUserQuestion (non-deterministic with 1 option)
if wait_for_ask 30 2>/dev/null; then
    echo "[switch] AskUserQuestion appeared, selecting option 1"
    sleep 1
    select_option 1
fi
wait_for_stop 300
pane_log "switch-done"

ACTIVE_AFTER="$(get_active_id)"
if [ "${ACTIVE_AFTER}" = "${ACTIVE_1}" ]; then
    pass "switch: active changed to workflow 1"
else
    echo "[assert] FAIL: expected ${ACTIVE_1}, got ${ACTIVE_AFTER}"
    fail "switch: active changed to workflow 1"
fi

summarize_results
