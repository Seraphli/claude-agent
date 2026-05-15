#!/bin/bash
# phase11_project_yaml.sh — E2E tests for project.yaml multi-repo worktree support

CA_REPO_ROOT="${CA_REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
TEST_NAME="phase11"
source "${CA_REPO_ROOT}/tests/e2e_common.sh"

echo ""
echo "Phase 11: project.yaml multi-repo worktree support"
echo "================================================="

# Persistent results file across multiple setup/cleanup cycles
PERSISTENT_RESULTS="$(mktemp /tmp/ca-e2e-phase11-results-XXXXXX.txt)"

# --- Test 1: /ca:new with project.yaml multi-repo worktrees ---
echo ""
echo "--- Test 1: /ca:new multi-repo worktrees ---"

setup_test_env
RESULTS_FILE="${PERSISTENT_RESULTS}"

# Enable branches in workspace config
cat > "${TEST_DIR}/project/.ca/config.md" << 'WSCONFIG'
interaction_language: English
comment_language: English
code_language: English
use_worktrees: true
auto_proceed_to_plan: false
auto_proceed_to_verify: false
WSCONFIG

# Also enable branches in global config
cat > "${TEST_CONFIG_DIR}/.claude/ca/config.md" << 'CONFIG'
interaction_language: English
comment_language: English
code_language: English
use_worktrees: true
auto_proceed_to_plan: false
auto_proceed_to_verify: false
CONFIG

# Create two mock git repos as project dirs
REPO1="${TEST_DIR}/repo1"
REPO2="${TEST_DIR}/repo2"
mkdir -p "${REPO1}" "${REPO2}"
git -C "${REPO1}" init -q
git -C "${REPO1}" config user.email "test@example.com"
git -C "${REPO1}" config user.name "Test"
touch "${REPO1}/README.md"
git -C "${REPO1}" add -A && git -C "${REPO1}" commit -q -m "init"
git -C "${REPO2}" init -q
git -C "${REPO2}" config user.email "test@example.com"
git -C "${REPO2}" config user.name "Test"
touch "${REPO2}/README.md"
git -C "${REPO2}" add -A && git -C "${REPO2}" commit -q -m "init"

# Create project.yaml in .ca/
cat > "${TEST_DIR}/project/.ca/project.yaml" << YAML
project_name: test-multi-repo
description: Test project with multiple repos
dirs:
  - label: repo1
    path: ${REPO1}
  - label: repo2
    path: ${REPO2}
YAML

start_claude

# Inject /ca:new command
inject_command "/ca:new test multi-repo requirement"

# Wait for todo link/add question
wait_for_ask 120
assert_ask_header "Link Todo|Add Todo|Todo" "new: todo question appears"
sleep 1
select_option_by_text "No.*skip|skip"

# Wait for worktree selection question (multi-repo)
wait_for_ask 120
assert_ask_header "Worktrees" "new: multi-repo worktree selection appears"
sleep 1
# Select first repo
select_option_smart 1

# Wait for stop (workflow created)
wait_for_stop

# Verify STATUS.md has project_worktrees
assert_file_contains "${TEST_DIR}/project/.ca/workflows/test-multi-repo-requirement/STATUS.md" "project_worktrees" "new: STATUS.md has project_worktrees"

# Verify worktree directory was created for repo1
# Worktree path: <repo-parent>/<repo-name>-wt/ca-<workflow-id>/
REPO1_WT_DIR=$(find "${TEST_DIR}" -type d -name "repo1-wt" 2>/dev/null | head -1)
if [ -n "${REPO1_WT_DIR}" ] && [ -d "${REPO1_WT_DIR}" ]; then
  pass "new: worktree directory created for repo1"
else
  fail "new: worktree directory not created for repo1"
fi

# Verify original repo1 stays on main
REPO1_BRANCH=$(git -C "${REPO1}" branch --show-current 2>/dev/null)
if [ "${REPO1_BRANCH}" = "main" ] || [ "${REPO1_BRANCH}" = "master" ]; then
  pass "new: original repo1 stays on main/master"
else
  fail "new: original repo1 not on main/master (got: ${REPO1_BRANCH})"
fi

cleanup

# --- Test 2: /ca:quick with project.yaml multi-repo worktrees ---
echo ""
echo "--- Test 2: /ca:quick multi-repo worktrees ---"

setup_test_env
RESULTS_FILE="${PERSISTENT_RESULTS}"

# Enable branches
cat > "${TEST_DIR}/project/.ca/config.md" << 'WSCONFIG'
interaction_language: English
comment_language: English
code_language: English
use_worktrees: true
auto_proceed_to_plan: false
auto_proceed_to_verify: false
WSCONFIG

cat > "${TEST_CONFIG_DIR}/.claude/ca/config.md" << 'CONFIG'
interaction_language: English
comment_language: English
code_language: English
use_worktrees: true
auto_proceed_to_plan: false
auto_proceed_to_verify: false
CONFIG

# Create mock repos
REPO1="${TEST_DIR}/repo1"
REPO2="${TEST_DIR}/repo2"
mkdir -p "${REPO1}" "${REPO2}"
git -C "${REPO1}" init -q
git -C "${REPO1}" config user.email "test@example.com"
git -C "${REPO1}" config user.name "Test"
touch "${REPO1}/README.md"
git -C "${REPO1}" add -A && git -C "${REPO1}" commit -q -m "init"
git -C "${REPO2}" init -q
git -C "${REPO2}" config user.email "test@example.com"
git -C "${REPO2}" config user.name "Test"
touch "${REPO2}/README.md"
git -C "${REPO2}" add -A && git -C "${REPO2}" commit -q -m "init"

# Create project.yaml
cat > "${TEST_DIR}/project/.ca/project.yaml" << YAML
project_name: test-multi-repo-quick
description: Test quick workflow with multiple repos
dirs:
  - label: repo1
    path: ${REPO1}
  - label: repo2
    path: ${REPO2}
YAML

# Pre-create todos.md to stabilize LLM behavior
touch "${TEST_DIR}/project/.ca/todos.md"

start_claude

# Inject /ca:quick command
inject_command "/ca:quick quick multi-repo test"

# Wait for todo link/add question
wait_for_ask 120
assert_ask_header "Link Todo|Add Todo|Todo" "quick: todo question appears"
sleep 1
select_option_by_text "No.*skip|skip"

# Wait for worktree selection question (multi-repo)
wait_for_ask 120
assert_ask_header "Worktrees" "quick: multi-repo worktree selection appears"
sleep 1
select_option_smart 1

# Wait for stop (workflow created)
wait_for_stop

# Verify STATUS.md has project_worktrees
assert_file_contains "${TEST_DIR}/project/.ca/workflows/quick-multi-repo-test/STATUS.md" "project_worktrees" "quick: STATUS.md has project_worktrees"

# Verify worktree directory was created for repo1
REPO1_WT_DIR=$(find "${TEST_DIR}" -type d -name "repo1-wt" 2>/dev/null | head -1)
if [ -n "${REPO1_WT_DIR}" ] && [ -d "${REPO1_WT_DIR}" ]; then
  pass "quick: worktree directory created for repo1"
else
  fail "quick: worktree directory not created for repo1"
fi

# Verify original repo1 stays on main
REPO1_BRANCH=$(git -C "${REPO1}" branch --show-current 2>/dev/null)
if [ "${REPO1_BRANCH}" = "main" ] || [ "${REPO1_BRANCH}" = "master" ]; then
  pass "quick: original repo1 stays on main/master"
else
  fail "quick: original repo1 not on main/master (got: ${REPO1_BRANCH})"
fi

cleanup

# --- Summary ---
summarize_results
result=$?
rm -f "${PERSISTENT_RESULTS}"
exit $result
