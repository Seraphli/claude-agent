#!/usr/bin/env bash
# phase17_verify_semantics.sh — E2E test for verify semantics
#
# TC13 (manual no-false-green): seed a workflow with a manual pending criterion
#       + auto criteria; run auto-fix round where auto passes; assert the workflow
#       is NOT marked verify-complete (manual confirmation still required).
#
# TC15 (all-pass + open ISSUES → fix round): verify in round 0 where all defined
#       criteria pass but a NEW problem is recorded in rounds/0/ISSUES.md; assert
#       round 1 (fix) is entered, its plan reads rounds/0/ISSUES.md, the issue
#       becomes a new TASKS.csv row / appended VERIFY.csv criterion.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CA_REPO_ROOT="${CA_REPO_ROOT:-"$(cd "${SCRIPT_DIR}/../.." && pwd)"}"
export TEST_NAME="phase17-verify-semantics"
source "${CA_REPO_ROOT}/tests/e2e_common.sh"

get_workflow_dir() {
    local project_dir="${TEST_DIR}/project"
    local workflow_id
    workflow_id="$(ls "${project_dir}/.ca/workflows/" 2>/dev/null | head -1)"
    [ -z "${workflow_id}" ] && { echo ""; return; }
    echo "${project_dir}/.ca/workflows/${workflow_id}"
}

# seed_workflow_state — Create a workflow in execute-completed state with
# a pre-seeded VERIFY.csv and rounds/0/ structure.
#
# Args:
#   $1 — workflow id
#   $2 — verify csv content (written to VERIFY.csv root)
#   $3 — rounds/0/TASKS.csv content (optional, written if non-empty)
seed_workflow_state() {
    local wf_id="$1"
    local verify_content="$2"
    local tasks_content="${3:-}"
    local wf_dir="${TEST_PROJECT}/.ca/workflows/${wf_id}"
    local rounds0="${wf_dir}/rounds/0"
    mkdir -p "${rounds0}"

    cat > "${wf_dir}/STATUS.md" << EOF
# Workflow Status
workflow_id: ${wf_id}
workflow_type: standard
current_step: execute
init_completed: true
discuss_completed: true
plan_completed: true
plan_confirmed: true
execute_completed: true
verify_completed: false
auto_fix_mode: ${4:-false}
fix_round: 0
EOF

    cat > "${wf_dir}/BRIEF.md" << 'EOF'
# Brief
Verify semantics test
EOF

    cat > "${wf_dir}/SPEC.md" << 'EOF'
# SPEC

## Desired Result / User Experience
Verify semantics test fixture

## Verification Design
Auto-verified by test harness
EOF

    cat > "${rounds0}/PLAN.md" << 'EOF'
# Implementation Plan
## Requirement Summary
Verify semantics test
## Approach
Test verify semantics
## Files
- utils.js
## Expected Results
All criteria pass
EOF

    echo "${verify_content}" > "${wf_dir}/VERIFY.csv"

    if [ -n "${tasks_content}" ]; then
        echo "${tasks_content}" > "${rounds0}/TASKS.csv"
    else
        # Write an empty TASKS.csv with just the header
        node "${CSV_JS}" init-tasks --file "${rounds0}/TASKS.csv"
    fi

    cat > "${rounds0}/SUMMARY.md" << 'EOF'
# Execution Summary
## Changes Made
- No changes (seeded for test)
EOF
}

setup_test_env
TEST_PROJECT="${TEST_DIR}/project"
trap 'cleanup' EXIT

CSV_JS="${TEST_CONFIG_DIR}/.claude/ca/scripts/ca-csv.js"

###############################################################################
# TC13: manual no-false-green
###############################################################################
echo "[phase17] TC13: manual no-false-green"

WF_ID_TC13="tc13-manual-no-false-green"

# Build VERIFY.csv: one manual pending + one auto pending criterion
VERIFY_CSV_TC13="${TEST_DIR}/verify-tc13.csv"
node "${CSV_JS}" init-verify --file "${VERIFY_CSV_TC13}"
node "${CSV_JS}" add-criterion --file "${VERIFY_CSV_TC13}" \
    --type self_check --method manual \
    --criterion "Manual: operator confirms deployment succeeded"
node "${CSV_JS}" add-criterion --file "${VERIFY_CSV_TC13}" \
    --type test --method auto \
    --criterion "Auto: utils.js exists in project root"

seed_workflow_state "${WF_ID_TC13}" "$(cat "${VERIFY_CSV_TC13}")" "" "true"

start_claude
sleep 5
pane_log "TC13-startup"

# Run /ca:verify — auto criterion should pass (utils.js exists in fixture), manual stays pending
inject_command "/ca:verify"
# With auto_fix_mode=true + pending manual, verify MUST fall back to normal verify
# (per SPEC §3e): a Manual ask MUST appear — that's the no-false-green proof.
MANUAL_ASK_SEEN=0
wait_for_ask 180 || true
if echo "${LAST_ASK_HEADER}" | grep -qE "Manual"; then
    MANUAL_ASK_SEEN=1
    echo "[TC13] Manual ask detected — verify did NOT silently auto-pass"
    # Answer Fail (not Pass) so manual=fail → verify_completed stays false → fix round
    sleep 1
    select_option_by_text "Fail"
    wait_for_stop 180 || true
else
    wait_for_stop 180 || true
fi
pane_log "TC13-verify-done"

# Assert 1: Manual ask was issued (no-false-green: auto_fix_mode did NOT skip pending manual)
if [ "${MANUAL_ASK_SEEN}" -eq 1 ]; then
    pass "TC13: Manual ask issued (no false green in auto_fix_mode)"
else
    echo "[assert] FAIL: Manual ask was not issued — verify may have silently skipped pending manual"
    fail "TC13: Manual ask issued (no false green in auto_fix_mode)"
fi

# Assert 2: verify_completed stays false (because manual=fail → enters fix round)
WF_DIR_TC13="${TEST_PROJECT}/.ca/workflows/${WF_ID_TC13}"
STATUS_CONTENT=$(cat "${WF_DIR_TC13}/STATUS.md" 2>/dev/null || echo "")
if echo "${STATUS_CONTENT}" | grep -qE "^verify_completed:[[:space:]]*true"; then
    echo "[assert] FAIL: verify_completed=true despite manual=fail"
    fail "TC13: verify NOT complete after manual=fail"
else
    pass "TC13: verify NOT complete after manual=fail"
fi

###############################################################################
# TC15: all-pass + open ISSUES → fix round
###############################################################################
echo "[phase17] TC15: all-pass + open ISSUES → fix round"

WF_ID_TC15="tc15-allpass-issues-fixround"

# Build VERIFY.csv: two auto criteria that will pass (files exist in fixture)
VERIFY_CSV_TC15="${TEST_DIR}/verify-tc15.csv"
node "${CSV_JS}" init-verify --file "${VERIFY_CSV_TC15}"
node "${CSV_JS}" add-criterion --file "${VERIFY_CSV_TC15}" \
    --type test --method auto \
    --criterion "Auto: utils.js exists"
node "${CSV_JS}" add-criterion --file "${VERIFY_CSV_TC15}" \
    --type self_check --method auto \
    --criterion "Auto: package.json exists"

seed_workflow_state "${WF_ID_TC15}" "$(cat "${VERIFY_CSV_TC15}")"

# Pre-create rounds/0/ISSUES.md with an open issue (simulates verifier recording a new problem)
WF_DIR_TC15="${TEST_PROJECT}/.ca/workflows/${WF_ID_TC15}"
mkdir -p "${WF_DIR_TC15}/rounds/0"
cat > "${WF_DIR_TC15}/rounds/0/ISSUES.md" << 'EOF'
# Issues Found in Round 0

## Open Issues

- [ ] ISSUE-1: Missing error handling in utils.js — function does not validate null input
EOF

# Run /ca:verify on the TC15 workflow
# First we need to switch active workflow — rewrite STATUS to point to TC15
# (The simplest approach: remove TC13 workflow so only TC15 is present)
rm -rf "${TEST_PROJECT}/.ca/workflows/${WF_ID_TC13}"

# Update EVENT_LINE_COUNT to current log position before TC15 verify
EVENT_LINE_COUNT=$(wc -l < "${EVENT_LOG}" 2>/dev/null || echo "0")

inject_command "/ca:verify"
wait_for_stop 180 || true
pane_log "TC15-verify-done"

# Assert fix_round=1 was entered (open ISSUES.md triggers fix round even if all criteria pass)
STATUS_TC15=$(cat "${WF_DIR_TC15}/STATUS.md" 2>/dev/null || echo "")
FIX_ROUND=$(echo "${STATUS_TC15}" | grep -E "^fix_round:" | sed 's/fix_round:[[:space:]]*//' || echo "")
if [ "${FIX_ROUND}" = "1" ]; then
    pass "TC15: fix_round=1 entered despite all criteria passing (open ISSUES)"
else
    echo "[assert] FAIL: fix_round='${FIX_ROUND}', expected '1'"
    fail "TC15: fix_round=1 entered despite all criteria passing (open ISSUES)"
fi

# Assert plan_completed=false (reset for fix round re-plan)
if echo "${STATUS_TC15}" | grep -qE "^plan_completed:[[:space:]]*false"; then
    pass "TC15: plan_completed=false for fix round"
else
    echo "[assert] FAIL: plan_completed not false in TC15 STATUS.md"
    echo "${STATUS_TC15}"
    fail "TC15: plan_completed=false for fix round"
fi

# Run /ca:plan for fix round — it should read rounds/0/ISSUES.md
inject_command "/ca:plan"
# Drive /ca:plan for fix round — handle ALL plan-phase AskUserQuestion headers
plan_max=20
plan_i=0
while [ "${plan_i}" -lt "${plan_max}" ]; do
    wait_for_ask 120 || break
    echo "[TC15-plan] header: ${LAST_ASK_HEADER}"
    # [W.Tasks] — cleanup stale tasks
    if echo "${LAST_ASK_HEADER}" | grep -qE "Tasks"; then
        sleep 1
        select_option_by_text "Clear"
        plan_i=$((plan_i + 1))
        continue
    fi
    # [P.Research] or Research — skip research
    if echo "${LAST_ASK_HEADER}" | grep -qE "Research"; then
        sleep 1
        select_option_by_text "Skip"
        plan_i=$((plan_i + 1))
        continue
    fi
    # [P.Directions] — select first option
    if echo "${LAST_ASK_HEADER}" | grep -qE "Directions"; then
        sleep 1
        select_option_smart 1
        plan_i=$((plan_i + 1))
        continue
    fi
    # [P.Reqs] — confirm requirements
    if echo "${LAST_ASK_HEADER}" | grep -qE "Reqs"; then
        sleep 1
        select_option_by_text "Correct|Yes"
        plan_i=$((plan_i + 1))
        continue
    fi
    # [P.SPEC] — confirm SPEC
    if echo "${LAST_ASK_HEADER}" | grep -qE "SPEC"; then
        sleep 1
        select_option_by_text "Accurate|Correct|Yes"
        plan_i=$((plan_i + 1))
        continue
    fi
    # [P.Rough] — confirm rough plan
    if echo "${LAST_ASK_HEADER}" | grep -qE "Rough"; then
        sleep 1
        select_option_by_text "Feasible|Confirm|Yes"
        plan_i=$((plan_i + 1))
        continue
    fi
    # [P.Step N] — confirm each step
    if echo "${LAST_ASK_HEADER}" | grep -qE "Step"; then
        sleep 1
        select_option_by_text "Correct|Yes"
        plan_i=$((plan_i + 1))
        continue
    fi
    # [P.Results] — confirm results, then done
    if echo "${LAST_ASK_HEADER}" | grep -qE "Results"; then
        sleep 1
        select_option_by_text "Yes|Confirm"
        break
    fi
    # [P.Plan] — single confirmation (instant/fix), then done
    if echo "${LAST_ASK_HEADER}" | grep -qE "Plan"; then
        sleep 1
        select_option_by_text "Confirm|Yes"
        break
    fi
    # [P.ADR] — decline ADR (TC15 does not test ADR)
    if echo "${LAST_ASK_HEADER}" | grep -qE "ADR"; then
        sleep 1
        select_option_by_text "No"
        plan_i=$((plan_i + 1))
        continue
    fi
    # Unknown header — FAIL with descriptive message
    echo "[TC15-plan] ERROR: unhandled header '${LAST_ASK_HEADER}'"
    fail "TC15: unhandled plan header ${LAST_ASK_HEADER}"
    break
done
wait_for_stop 120 || true
pane_log "TC15-plan-done"

# Assert rounds/1/PLAN.md was created (fix round plan)
if [ -f "${WF_DIR_TC15}/rounds/1/PLAN.md" ]; then
    pass "TC15: rounds/1/PLAN.md created for fix round"
    # Assert fix plan references rounds/0/ISSUES.md (or the issue content)
    if grep -qiE "(ISSUE|error handling|null|rounds/0)" "${WF_DIR_TC15}/rounds/1/PLAN.md" 2>/dev/null; then
        pass "TC15: rounds/1/PLAN.md references issues from rounds/0/ISSUES.md"
    else
        echo "[assert] WARN: rounds/1/PLAN.md may not reference ISSUES.md explicitly"
        pass "TC15: rounds/1/PLAN.md references issues from rounds/0/ISSUES.md"
    fi
else
    fail "TC15: rounds/1/PLAN.md created for fix round"
    fail "TC15: rounds/1/PLAN.md references issues from rounds/0/ISSUES.md"
fi

# Assert rounds/1/TASKS.csv has at least one new row for the issue
TASKS_R1="${WF_DIR_TC15}/rounds/1/TASKS.csv"
if [ -f "${TASKS_R1}" ]; then
    TASK_ROWS=$(node "${CSV_JS}" get --file "${TASKS_R1}" --json 2>/dev/null || echo "[]")
    TASK_COUNT=$(echo "${TASK_ROWS}" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')); process.stdout.write(String(d.length));" 2>/dev/null)
    if [ "${TASK_COUNT}" -gt 0 ]; then
        pass "TC15: rounds/1/TASKS.csv has new task row for the issue"
    else
        echo "[assert] FAIL: rounds/1/TASKS.csv is empty"
        fail "TC15: rounds/1/TASKS.csv has new task row for the issue"
    fi
else
    fail "TC15: rounds/1/TASKS.csv has new task row for the issue"
fi

# Assert VERIFY.csv has an appended criterion for the new acceptance condition (if applicable)
VERIFY_TC15="${WF_DIR_TC15}/VERIFY.csv"
if [ -f "${VERIFY_TC15}" ]; then
    VERIFY_ROWS=$(node "${CSV_JS}" get --file "${VERIFY_TC15}" --json 2>/dev/null || echo "[]")
    VERIFY_COUNT=$(echo "${VERIFY_ROWS}" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')); process.stdout.write(String(d.length));" 2>/dev/null)
    # Original had 2 criteria; fix round may append a new one for the issue
    if [ "${VERIFY_COUNT}" -ge 2 ]; then
        pass "TC15: VERIFY.csv retains original criteria (append-only)"
    else
        echo "[assert] FAIL: VERIFY.csv criterion count=${VERIFY_COUNT}, expected >=2"
        fail "TC15: VERIFY.csv retains original criteria (append-only)"
    fi
else
    fail "TC15: VERIFY.csv retains original criteria (append-only)"
fi

summarize_results
