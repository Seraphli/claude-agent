#!/bin/bash
# phase13_init.sh — E2E tests for /ca:init project.yaml generation
CA_REPO_ROOT="${CA_REPO_ROOT:-$(cd "$(dirname "$0")/../.." && pwd)}"
TEST_NAME="phase19"
source "${CA_REPO_ROOT}/tests/e2e_common.sh"

echo ""
echo "Phase 19: /ca:init project.yaml generation"
echo "=========================================="

PERSISTENT_RESULTS="$(mktemp /tmp/ca-e2e-phase19-results-XXXXXX.txt)"

# --- Test 1: /ca:init generates a valid project.yaml ---
echo ""
echo "--- Test 1: /ca:init generates project.yaml ---"
setup_test_env
RESULTS_FILE="${PERSISTENT_RESULTS}"

DIR1="${TEST_DIR}/repo1"
DIR2="${TEST_DIR}/repo2"
mkdir -p "${DIR1}" "${DIR2}"
# project_rules entries are FILE PATHS (execute.md reads each file's content)
RULEFILE="${TEST_DIR}/myrules.md"
echo "Always run tests before finishing." > "${RULEFILE}"

start_claude

inject_command "/ca:init Create project.yaml. project_name: test-init-proj. Directories: label repo1 at path ${DIR1}; label repo2 at path ${DIR2}. One rule file at path ${RULEFILE}."

wait_for_ask 120
assert_ask_header "Confirm" "init: write confirmation appears"
sleep 1
select_option_by_text "Write"
wait_for_stop

PROJECT_YAML="${TEST_DIR}/project/.ca/project.yaml"
assert_file_exists "${PROJECT_YAML}" "init: project.yaml created"
assert_file_contains "${PROJECT_YAML}" "project_name:.*test-init-proj" "init: project_name written"
assert_file_contains "${PROJECT_YAML}" "label:.*repo1" "init: repo1 label written"
assert_file_contains "${PROJECT_YAML}" "label:.*repo2" "init: repo2 label written"
assert_file_contains "${PROJECT_YAML}" "${DIR1}" "init: repo1 path written"
assert_file_contains "${PROJECT_YAML}" "${DIR2}" "init: repo2 path written"
assert_file_contains "${PROJECT_YAML}" "${RULEFILE}" "init: rule file path written"

# ca-config.js MUST be run from the installed isolated path (it requires js-yaml,
# which install.js places at ${TEST_CONFIG_DIR}/.claude/ca/node_modules/js-yaml).
# The repo/worktree source path has no node_modules (gitignored).
CONFIG_OUT="$(node "${TEST_CONFIG_DIR}/.claude/ca/scripts/ca-config.js" --project-root "${TEST_DIR}/project" 2>/dev/null)"
if echo "${CONFIG_OUT}" | grep -q "## Project" \
   && echo "${CONFIG_OUT}" | grep -q "project_dirs:" \
   && echo "${CONFIG_OUT}" | grep -q "project_rules:"; then
  pass "init: ca-config.js parses generated project.yaml (## Project + project_dirs + project_rules)"
else
  echo "[assert] config output:"; echo "${CONFIG_OUT}"
  fail "init: ca-config.js parses generated project.yaml"
fi
cleanup

# --- Test 2: /ca:init guards an existing project.yaml ---
echo ""
echo "--- Test 2: /ca:init existing-file guard ---"
setup_test_env
RESULTS_FILE="${PERSISTENT_RESULTS}"

cat > "${TEST_DIR}/project/.ca/project.yaml" << 'YAML'
project_name: pre-existing-sentinel
dirs:
  - label: old
    path: /tmp/old
YAML

start_claude
inject_command "/ca:init"

wait_for_ask 120
assert_ask_header "Overwrite" "init: overwrite guard question appears"
sleep 1
select_option_by_text "Cancel"
wait_for_stop

assert_file_contains "${TEST_DIR}/project/.ca/project.yaml" "pre-existing-sentinel" "init: existing project.yaml preserved on cancel"
cleanup

# --- Summary ---
summarize_results
result=$?
rm -f "${PERSISTENT_RESULTS}"
exit $result
