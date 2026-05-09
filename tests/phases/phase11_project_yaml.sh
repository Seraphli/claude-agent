#!/bin/bash
# phase11_project_yaml.sh — E2E tests for project.yaml multi-repo branch support

CA_REPO_ROOT="${CA_REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
TEST_NAME="phase11"
source "${CA_REPO_ROOT}/tests/e2e_common.sh"

echo ""
echo "Phase 11: project.yaml multi-repo branch support"
echo "================================================="

# Persistent results file across multiple setup/cleanup cycles
PERSISTENT_RESULTS="$(mktemp /tmp/ca-e2e-phase11-results-XXXXXX.txt)"

# --- Test 1: /ca:new with project.yaml multi-repo branches ---
echo ""
echo "--- Test 1: /ca:new multi-repo branches ---"

setup_test_env
RESULTS_FILE="${PERSISTENT_RESULTS}"

# Enable branches in workspace config
cat > "${TEST_DIR}/project/.ca/config.md" << 'WSCONFIG'
interaction_language: English
comment_language: English
code_language: English
use_branches: true
auto_proceed_to_plan: false
auto_proceed_to_verify: false
WSCONFIG

# Also enable branches in global config
cat > "${TEST_CONFIG_DIR}/.claude/ca/config.md" << 'CONFIG'
interaction_language: English
comment_language: English
code_language: English
use_branches: true
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

# Wait for branch selection question (multi-repo)
wait_for_ask 120
assert_ask_header "Branches" "new: multi-repo branch selection appears"
sleep 1
# Select first repo
select_option_smart 1

# Wait for stop (workflow created)
wait_for_stop 120

# Verify STATUS.md has project_branches
assert_file_contains "${TEST_DIR}/project/.ca/workflows/test-multi-repo-requirement/STATUS.md" "project_branches" "new: STATUS.md has project_branches"

# Verify branch was created in repo1
REPO1_BRANCH=$(git -C "${REPO1}" branch --list "ca/*" 2>/dev/null)
if [ -n "${REPO1_BRANCH}" ]; then
  pass "new: branch created in repo1"
else
  fail "new: branch not created in repo1"
fi

cleanup

# --- Test 2: /ca:quick with project.yaml multi-repo branches ---
echo ""
echo "--- Test 2: /ca:quick multi-repo branches ---"

setup_test_env
RESULTS_FILE="${PERSISTENT_RESULTS}"

# Enable branches
cat > "${TEST_DIR}/project/.ca/config.md" << 'WSCONFIG'
interaction_language: English
comment_language: English
code_language: English
use_branches: true
auto_proceed_to_plan: false
auto_proceed_to_verify: false
WSCONFIG

cat > "${TEST_CONFIG_DIR}/.claude/ca/config.md" << 'CONFIG'
interaction_language: English
comment_language: English
code_language: English
use_branches: true
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

# Wait for branch selection question (multi-repo)
wait_for_ask 120
assert_ask_header "Branches" "quick: multi-repo branch selection appears"
sleep 1
select_option_smart 1

# Wait for stop (workflow created)
wait_for_stop 120

# Verify STATUS.md has project_branches
assert_file_contains "${TEST_DIR}/project/.ca/workflows/quick-multi-repo-test/STATUS.md" "project_branches" "quick: STATUS.md has project_branches"

# Verify branch was created in repo1
REPO1_BRANCH=$(git -C "${REPO1}" branch --list "ca/*" 2>/dev/null)
if [ -n "${REPO1_BRANCH}" ]; then
  pass "quick: branch created in repo1"
else
  fail "quick: branch not created in repo1"
fi

cleanup

# --- Summary ---
summarize_results
result=$?
rm -f "${PERSISTENT_RESULTS}"
exit $result
