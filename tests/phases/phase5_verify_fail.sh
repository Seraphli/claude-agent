#!/usr/bin/env bash
# phase5_verify_fail.sh — E2E test for verify failure flow
#
# Tests that when /ca:verify finds unmet criteria, it creates ISSUES.md,
# sets fix_round=1, and resets plan_completed=false for a re-plan cycle.
#
# Unlike other phases, this test manually creates a workflow in "execute completed"
# state with a criteria that will always fail (nonexistent file check).
#
# Usage:
#   CA_REPO_ROOT=/path/to/claude-agent bash tests/phases/phase5_verify_fail.sh

set -euo pipefail

# Identify repo root: use CA_REPO_ROOT env or derive from this script's location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CA_REPO_ROOT="${CA_REPO_ROOT:-"$(cd "${SCRIPT_DIR}/../.." && pwd)"}"

# Test suite name (used for tmux session naming)
export TEST_NAME="verify-fail"

# Source shared E2E infrastructure
source "${CA_REPO_ROOT}/tests/e2e_common.sh"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# get_workflow_dir — Find the active workflow directory under .ca/workflows/
get_workflow_dir() {
    local project_dir="${TEST_DIR}/project"
    local workflow_id
    workflow_id="$(ls "${project_dir}/.ca/workflows/" 2>/dev/null | head -1)"
    if [ -z "${workflow_id}" ]; then
        echo ""
        return
    fi
    echo "${project_dir}/.ca/workflows/${workflow_id}"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

# Setup isolated environment
setup_test_env

# Define the project dir (set by setup_test_env)
TEST_PROJECT="${TEST_DIR}/project"

# Cleanup tmux session and temp dir on exit
trap 'cleanup' EXIT

# ---------------------------------------------------------------------------
# Manually create workflow in "execute completed" state
# ---------------------------------------------------------------------------

WORKFLOW_ID="verify-fail-test"
WORKFLOW_DIR="${TEST_PROJECT}/.ca/workflows/${WORKFLOW_ID}"
mkdir -p "${WORKFLOW_DIR}"

# Write STATUS.md
cat > "${WORKFLOW_DIR}/STATUS.md" << 'EOF'
# Workflow Status
workflow_id: verify-fail-test
workflow_type: quick
current_step: execute
init_completed: true
discuss_completed: false
plan_completed: true
plan_confirmed: true
execute_completed: true
verify_completed: false
EOF

# Write BRIEF.md
cat > "${WORKFLOW_DIR}/BRIEF.md" << 'EOF'
# Brief
Test verify failure flow
EOF

# Write PLAN.md
cat > "${WORKFLOW_DIR}/PLAN.md" << 'EOF'
# Implementation Plan
## Requirement Summary
Test requirement
## Implementation Steps
1. Create nonexistent-test-file.js
## Step Details
### Step 1
Create the file
## Expected Results
File exists
EOF

# Write SUMMARY.md
cat > "${WORKFLOW_DIR}/SUMMARY.md" << 'EOF'
# Execution Summary
## Changes Made
- No changes made (test scenario for verify failure)
EOF

# Write VERIFY.csv with one failing test/auto criterion (discovering round fixture)
CA_CSV="${TEST_CONFIG_DIR}/.claude/ca/scripts/ca-csv.js"
node "${CA_CSV}" init-verify --file "${WORKFLOW_DIR}/VERIFY.csv"
node "${CA_CSV}" add-criterion \
    --file "${WORKFLOW_DIR}/VERIFY.csv" \
    --type test \
    --method auto \
    --criterion "File nonexistent-test-file.js must exist in the project root"

echo "[setup] workflow files created at ${WORKFLOW_DIR}"

# ---------------------------------------------------------------------------
# Start Claude and run /ca:verify
# ---------------------------------------------------------------------------

start_claude

sleep 5
pane_log "startup"

# ---------------------------------------------------------------------------
# /ca:verify — expect it to detect failure and create ISSUES.md
# ---------------------------------------------------------------------------

inject_command "/ca:verify"
wait_for_stop 240
pane_log "verify-done"

# Refresh workflow dir pointer
WORKFLOW_DIR="$(get_workflow_dir)"

# Assert ISSUES.md was created (verify failure creates this file)
if [ -n "${WORKFLOW_DIR}" ]; then
    assert_file_exists "${WORKFLOW_DIR}/rounds/0/ISSUES.md" "verify-fail: rounds/0/ISSUES.md created"
else
    fail "verify-fail: rounds/0/ISSUES.md created"
fi

# Assert fix_round=1 in STATUS.md
assert_status_field "fix_round" "1" "verify-fail: fix_round=1"

# Assert plan_completed=false (reset for re-plan cycle)
assert_status_field "plan_completed" "false" "verify-fail: plan_completed=false"

# ---------------------------------------------------------------------------
# Results
# ---------------------------------------------------------------------------

summarize_results
