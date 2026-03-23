#!/usr/bin/env bash
# phase8_batch.sh — E2E test for batch execution
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CA_REPO_ROOT="${CA_REPO_ROOT:-"$(cd "${SCRIPT_DIR}/../.." && pwd)"}"
export TEST_NAME="phase8-batch"
source "${CA_REPO_ROOT}/tests/e2e_common.sh"

setup_test_env
TEST_PROJECT="${TEST_DIR}/project"
trap 'cleanup' EXIT

cat > "${TEST_PROJECT}/.ca/config.md" << 'CONFIG'
interaction_language: English
comment_language: English
code_language: English
use_branches: false
auto_proceed_to_plan: false
auto_proceed_to_verify: false
CONFIG

WF1_DIR="${TEST_PROJECT}/.ca/workflows/batch-task-1"
mkdir -p "${WF1_DIR}"
cat > "${WF1_DIR}/STATUS.md" << 'EOF'
# Workflow Status
workflow_id: batch-task-1
workflow_type: quick
current_step: plan
init_completed: true
discuss_completed: true
plan_completed: true
plan_confirmed: true
execute_completed: false
verify_completed: false
EOF
cat > "${WF1_DIR}/BRIEF.md" << 'EOF'
# Brief
Create file batch-result-1.js that exports a multiply function
EOF
cat > "${WF1_DIR}/PLAN.md" << 'EOF'
# Implementation Plan
## Requirement Summary
Create batch-result-1.js with multiply function
## Implementation Steps
1. Create batch-result-1.js
## Step Details
### Step 1
Create `batch-result-1.js` in project root:
```js
module.exports = { multiply: (a, b) => a * b };
```
## Expected Results
File exists with working multiply function
EOF
cat > "${WF1_DIR}/CRITERIA.md" << 'EOF'
# Success Criteria
**[auto]**
- File `batch-result-1.js` must exist in the project root and export a `multiply` function
EOF

printf '%s' "batch-task-1" > "${TEST_PROJECT}/.ca/active.md"

start_claude
sleep 5
pane_log "startup"

inject_command "/ca:batch"
wait_for_ask 300
assert_ask_header "Batch" "batch: Batch prompt"
sleep 1
select_option_by_text "Execute"

wait_for_stop 900
pane_log "batch-done"

if [ -f "${TEST_PROJECT}/batch-result-1.js" ]; then
    pass "batch: batch-result-1.js created"
else
    fail "batch: batch-result-1.js created"
fi

STATUS_FILE="${TEST_PROJECT}/.ca/workflows/batch-task-1/STATUS.md"
if [ -f "${STATUS_FILE}" ] && grep -q "execute_completed: true" "${STATUS_FILE}"; then
    pass "batch: batch-task-1 execute_completed=true"
else
    fail "batch: batch-task-1 execute_completed=true"
fi

summarize_results
