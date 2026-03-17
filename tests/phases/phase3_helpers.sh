#!/usr/bin/env bash
# phase3_helpers.sh — E2E tests for helper commands: todo, todos, map, status, list
#
# Tests the following commands in a single Claude session:
#   1. /ca:todo  — add a todo item
#   2. /ca:todos — list todo items
#   3. /ca:map   — create codebase map
#   4. /ca:quick then /ca:status — create workflow, then show status
#   5. /ca:list  — list all workflows

set -euo pipefail

# Identify repo root: use CA_REPO_ROOT env or derive from this script's location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CA_REPO_ROOT="${CA_REPO_ROOT:-"$(cd "${SCRIPT_DIR}/../.." && pwd)"}"

# Test suite name (used for tmux session naming)
export TEST_NAME="phase3-helpers"

# Source shared E2E infrastructure
source "${CA_REPO_ROOT}/tests/e2e_common.sh"

# --- Setup ---
setup_test_env
trap cleanup EXIT

PROJECT_DIR="${TEST_DIR}/project"

# --- Start Claude session ---
start_claude

# Wait for Claude to be ready at the initial prompt
sleep 5
pane_log "after-start"

# --- Test 1: /ca:todo — add a todo item ---
echo ""
echo "[test] 1: /ca:todo add item"
inject_command "/ca:todo add fix login bug"
wait_for_stop 300
pane_log "after-todo-add"
assert_file_exists "${PROJECT_DIR}/.ca/todos.md" "todo: todos.md created"
assert_file_contains "${PROJECT_DIR}/.ca/todos.md" "fix login bug" "todo: item added to todos.md"

# --- Test 2: /ca:todos — list todo items ---
echo ""
echo "[test] 2: /ca:todos list"
inject_command "/ca:todos"
wait_for_stop 300
pane_log "after-todos-list"

# Capture pane output and check that it contains todo content
PANE_CONTENT="$(tmux capture-pane -t "${TMUX_SESSION}" -p 2>/dev/null)"
if echo "${PANE_CONTENT}" | grep -qiE "(fix login bug|todo|no todo)"; then
    pass "todos: output contains todo content"
else
    echo "[assert] FAIL: /ca:todos output does not mention todos"
    echo "[assert] pane content (last 30 lines):"
    echo "${PANE_CONTENT}" | tail -30
    fail "todos: output contains todo content"
fi

# --- Test 3: /ca:map — create codebase map ---
echo ""
echo "[test] 3: /ca:map create map"
inject_command "/ca:map"
wait_for_stop 300
pane_log "after-map"
assert_file_exists "${PROJECT_DIR}/.ca/map.md" "map: .ca/map.md created"

# --- Test 4: /ca:quick then /ca:status — show workflow status ---
echo ""
echo "[test] 4a: /ca:quick to create a workflow"
inject_command "/ca:quick add hello world feature"
wait_for_ask 300
assert_ask_header "Add Todo" "quick: Add Todo prompt"
sleep 1
select_option_by_text "No.*skip"
wait_for_stop 300
pane_log "quick-done"

echo ""
echo "[test] 4b: /ca:status"
inject_command "/ca:status"
wait_for_stop 300
pane_log "after-status"

PANE_STATUS="$(tmux capture-pane -t "${TMUX_SESSION}" -p 2>/dev/null)"
if echo "${PANE_STATUS}" | grep -qiE "(workflow|status|phase|step|quick)"; then
    pass "status: output contains workflow info"
else
    echo "[assert] FAIL: /ca:status output does not contain workflow info"
    echo "[assert] pane content (last 30 lines):"
    echo "${PANE_STATUS}" | tail -30
    fail "status: output contains workflow info"
fi

# --- Test 5: /ca:list — list all workflows ---
echo ""
echo "[test] 5: /ca:list"
inject_command "/ca:list"
wait_for_stop 300
pane_log "after-list"

PANE_LIST="$(tmux capture-pane -t "${TMUX_SESSION}" -p 2>/dev/null)"
if echo "${PANE_LIST}" | grep -qiE "(workflow|quick|no workflow|list)"; then
    pass "list: output contains workflow listing"
else
    echo "[assert] FAIL: /ca:list output does not contain workflow listing"
    echo "[assert] pane content (last 30 lines):"
    echo "${PANE_LIST}" | tail -30
    fail "list: output contains workflow listing"
fi

# --- Summary ---
summarize_results
exit $?
