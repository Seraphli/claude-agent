#!/usr/bin/env bash
# phase6_autofix.sh — E2E test for auto-fix loop
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CA_REPO_ROOT="${CA_REPO_ROOT:-"$(cd "${SCRIPT_DIR}/../.." && pwd)"}"
export TEST_NAME="phase6-autofix"
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

cat > "${TEST_PROJECT}/.ca/config.md" << 'CONFIG'
interaction_language: English
comment_language: English
code_language: English
use_worktrees: false
auto_proceed_to_plan: false
auto_proceed_to_verify: false
auto_fix: true
max_fix_rounds: 2
CONFIG

WORKFLOW_ID="autofix-test"
WF_DIR="${TEST_PROJECT}/.ca/workflows/${WORKFLOW_ID}"
mkdir -p "${WF_DIR}"

cat > "${WF_DIR}/STATUS.md" << 'EOF'
# Workflow Status
workflow_id: autofix-test
workflow_type: quick
current_step: execute
init_completed: true
discuss_completed: true
plan_completed: true
plan_confirmed: true
execute_completed: true
verify_completed: false
EOF

cat > "${WF_DIR}/BRIEF.md" << 'EOF'
# Brief
Create a file autofix-result.js that exports an add function
EOF

cat > "${WF_DIR}/PLAN.md" << 'EOF'
# Implementation Plan
## Requirement Summary
Create autofix-result.js that exports an add function
## Implementation Steps
1. Create autofix-result.js
## Step Details
### Step 1
Create `autofix-result.js` in project root:
```js
module.exports = { add: (a, b) => a + b };
```
## Expected Results
File autofix-result.js exists with working add function
EOF

cat > "${WF_DIR}/SUMMARY.md" << 'EOF'
# Execution Summary
## Changes Made
- No changes made (simulated incomplete execution)
EOF

# Seed root VERIFY.csv with one failing test/auto criterion
CA_CSV="${TEST_CONFIG_DIR}/.claude/ca/scripts/ca-csv.js"
node "${CA_CSV}" init-verify --file "${WF_DIR}/VERIFY.csv"
node "${CA_CSV}" add-criterion \
    --file "${WF_DIR}/VERIFY.csv" \
    --type test \
    --method auto \
    --criterion "File autofix-result.js must exist in the project root and must export an add function that returns the sum of two arguments"

start_claude
sleep 5
pane_log "startup"

inject_command "/ca:verify"
wait_for_stop 600
pane_log "autofix-done"

WORKFLOW_DIR="$(get_workflow_dir)"
if [ -n "${WORKFLOW_DIR}" ]; then
    assert_file_exists "${WORKFLOW_DIR}/rounds/0/ISSUES.md" "autofix: rounds/0/ISSUES.md created"
    assert_file_exists "${WORKFLOW_DIR}/rounds/1/PLAN.md" "autofix: rounds/1/PLAN.md created"
else
    fail "autofix: rounds/0/ISSUES.md created"
    fail "autofix: rounds/1/PLAN.md created"
fi

if [ -f "${TEST_PROJECT}/autofix-result.js" ]; then
    pass "autofix: file created by auto-fix"
else
    fail "autofix: file created by auto-fix"
fi

WF_ID="$(ls "${TEST_PROJECT}/.ca/workflows/" 2>/dev/null | head -1)"
STATUS_TEXT="$(node "${CA_REPO_ROOT}/scripts/ca-status.js" read --project-root "${TEST_PROJECT}" --workflow-id "${WF_ID}" 2>/dev/null)" || true
FIX_ROUND="$(echo "${STATUS_TEXT}" | grep -oP '^fix_round:\s*\K\d+' || echo "0")"
if [ -n "${FIX_ROUND}" ] && [ "${FIX_ROUND}" -ge 1 ] 2>/dev/null; then
    pass "autofix: fix_round >= 1"
else
    echo "[assert] FAIL: fix_round=${FIX_ROUND:-unknown}, expected >= 1"
    fail "autofix: fix_round >= 1"
fi

# TC12: assert VERIFY.csv result/last_verified_round refreshed after the auto-fix round
VERIFY_CSV="${WORKFLOW_DIR}/VERIFY.csv"
if [ -f "${VERIFY_CSV}" ]; then
    VERIFY_RESULT="$(node "${CA_CSV}" get --file "${VERIFY_CSV}" --json 2>/dev/null | jq -r '.[0].result // ""' 2>/dev/null || echo "")"
    VERIFY_ROUND="$(node "${CA_CSV}" get --file "${VERIFY_CSV}" --json 2>/dev/null | jq -r '.[0].last_verified_round // ""' 2>/dev/null || echo "")"
    if [ "${VERIFY_RESULT}" = "pass" ]; then
        pass "autofix: VERIFY.csv result=pass after fix round (TC12)"
    else
        echo "[assert] FAIL: VERIFY.csv result='${VERIFY_RESULT}', expected 'pass'"
        fail "autofix: VERIFY.csv result=pass after fix round (TC12)"
    fi
    if [ -n "${VERIFY_ROUND}" ]; then
        pass "autofix: VERIFY.csv last_verified_round set after fix round (TC12)"
    else
        echo "[assert] FAIL: VERIFY.csv last_verified_round is empty"
        fail "autofix: VERIFY.csv last_verified_round set after fix round (TC12)"
    fi
else
    fail "autofix: VERIFY.csv result=pass after fix round (TC12)"
    fail "autofix: VERIFY.csv last_verified_round set after fix round (TC12)"
fi

summarize_results
