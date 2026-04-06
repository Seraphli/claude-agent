#!/usr/bin/env bash
# phase9_context.sh — E2E test for context management commands
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CA_REPO_ROOT="${CA_REPO_ROOT:-"$(cd "${SCRIPT_DIR}/../.." && pwd)"}"
export TEST_NAME="phase9-context"
source "${CA_REPO_ROOT}/tests/e2e_common.sh"

setup_test_env
TEST_PROJECT="${TEST_DIR}/project"
trap 'cleanup' EXIT

# Pre-create .claude/rules to avoid sensitive path permission prompts
mkdir -p "${TEST_PROJECT}/.claude/rules"

start_claude
sleep 5
pane_log "startup"

echo "[test] 1: /ca:remember"
inject_command "/ca:remember test-context-data-12345"
wait_for_ask 300
assert_ask_header "Level" "remember: Level prompt"
sleep 1
select_option_by_text "Project"
accept_write_permission 30
wait_for_stop 300
pane_log "remember-done"

CONTEXT_FILE="${TEST_PROJECT}/.claude/rules/ca:context.md"
if [ -f "${CONTEXT_FILE}" ] && grep -q "test-context-data-12345" "${CONTEXT_FILE}"; then
    pass "remember: data saved to project context"
else
    [ -f "${CONTEXT_FILE}" ] && cat "${CONTEXT_FILE}"
    fail "remember: data saved to project context"
fi

echo "[test] 2: /ca:context"
inject_command "/ca:context"
wait_for_stop 300
pane_log "context-done"

PANE_CONTENT="$(${TMUX_CMD} capture-pane -t "${TMUX_SESSION}" -p 2>/dev/null)"
if echo "${PANE_CONTENT}" | grep -qiE "(test-context-data|context|persistent)"; then
    pass "context: output shows context data"
else
    fail "context: output shows context data"
fi

echo "[test] 3: /ca:forget"
inject_command "/ca:forget test-context-data-12345"
wait_for_ask 300
assert_ask_header "Level" "forget: Level prompt"
sleep 1
select_option_by_text "Project"
accept_write_permission 30
wait_for_stop 300
pane_log "forget-done"

if [ -f "${CONTEXT_FILE}" ] && grep -q "test-context-data-12345" "${CONTEXT_FILE}"; then
    fail "forget: data removed from context"
else
    pass "forget: data removed from context"
fi

summarize_results
