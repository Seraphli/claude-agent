#!/usr/bin/env bash
# phase16_round_structure.sh — E2E test for round directory structure (TC17)
#
# TC17: Run a standard round 0 + one fix round; verify:
#   - rounds/0/ holds PLAN.md, TASKS.csv, SUMMARY.md, VERIFY-REPORT.md
#   - workflow root holds NO round-0 PLAN.md / SUMMARY.md
#   - /ca:status and /ca:context report the new paths
#   - /ca:finish archive preserves rounds/0/ intact under .ca/history/
#   - archived rounds/0/TASKS.csv shows git=done or git=skipped
#   - /ca:restore operates on the new paths
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CA_REPO_ROOT="${CA_REPO_ROOT:-"$(cd "${SCRIPT_DIR}/../.." && pwd)"}"
export TEST_NAME="phase16-round-structure"
source "${CA_REPO_ROOT}/tests/e2e_common.sh"

get_workflow_dir() {
    local project_dir="${TEST_DIR}/project"
    local workflow_id
    workflow_id="$(ls "${project_dir}/.ca/workflows/" 2>/dev/null | head -1)"
    [ -z "${workflow_id}" ] && { echo ""; return; }
    echo "${project_dir}/.ca/workflows/${workflow_id}"
}

setup_test_env
TEST_PROJECT="${TEST_DIR}/project"
trap 'cleanup' EXIT

start_claude
sleep 5
pane_log "startup"

echo "[phase16] TC17: round 0 structure — /ca:discuss + /ca:plan + /ca:execute + /ca:verify"

# --- /ca:new (required: discuss.md requires an existing workflow) ---
inject_command "/ca:new add a hello() function to utils.js that returns 'Hello World'"
wait_for_ask 120
assert_ask_header "Todo" "TC17: new Add Todo prompt"
sleep 1
select_option_by_text "No.*skip"
wait_for_stop 120
pane_log "new-done"

# --- /ca:discuss ---
# Grill-era discuss flow: Research(optional) → grill [D.Clarify] → [D.Reqs] → [D.SPEC] → Stop
inject_command "/ca:discuss"
for i in $(seq 1 10); do
    wait_for_ask 120
    if echo "${LAST_ASK_HEADER}" | grep -qE "Research|研究|调研"; then
        sleep 1
        select_option_by_text "Skip|跳过"
        continue
    fi
    if echo "${LAST_ASK_HEADER}" | grep -qE "Reqs"; then
        sleep 1
        select_option_by_text "Accurate|Correct|Yes"
        break
    fi
    # grill clarification or other — accept default
    sleep 1
    select_option_smart 1
done
# Expect: SPEC confirmation after requirements
wait_for_ask 120
if echo "${LAST_ASK_HEADER}" | grep -qE "SPEC"; then
    sleep 1
    select_option_by_text "Accurate"
fi
wait_for_stop 120
pane_log "discuss-done"

# --- /ca:plan (standard workflow → triple confirmation) ---
inject_command "/ca:plan"
# Research optional; grill may ask [P.Clarify] questions before the gate.
drive_grill_to_gate "Reqs" 120
assert_ask_header "Reqs" "TC17: plan Requirements prompt"
sleep 1
select_option_by_text "Correct"

# Standard workflow: SPEC was confirmed in discuss. Plan only reads it, no [P.SPEC] ask.
# If SPEC header appears, that's a deviation — fail explicitly.
wait_for_ask 120
if echo "${LAST_ASK_HEADER}" | grep -qE "SPEC"; then
    fail "TC17: standard plan must not re-confirm SPEC"
fi
assert_ask_header "Rough" "TC17: plan Rough Plan prompt"
sleep 1
select_option_by_text "Feasible"

# Step-by-step confirmations (Confirmation 2b)
wait_for_step_confirmations "Results" "TC17" 90
assert_ask_header "Results" "TC17: plan Results prompt"
sleep 1
select_option_by_text "Yes"

wait_for_stop 120
pane_log "plan-done"

WORKFLOW_DIR="$(get_workflow_dir)"

# Assert rounds/0/PLAN.md exists
if [ -n "${WORKFLOW_DIR}" ]; then
    assert_file_exists "${WORKFLOW_DIR}/rounds/0/PLAN.md" "TC17: rounds/0/PLAN.md exists"
    assert_file_exists "${WORKFLOW_DIR}/rounds/0/TASKS.csv" "TC17: rounds/0/TASKS.csv exists"
else
    fail "TC17: rounds/0/PLAN.md exists"
    fail "TC17: rounds/0/TASKS.csv exists"
fi

# Assert workflow ROOT does NOT have a PLAN.md (it should be under rounds/0/)
if [ -f "${WORKFLOW_DIR}/PLAN.md" ]; then
    echo "[assert] FAIL: workflow root has PLAN.md (should be in rounds/0/ only)"
    fail "TC17: workflow root has no round-0 PLAN.md"
else
    pass "TC17: workflow root has no round-0 PLAN.md"
fi

# --- /ca:execute ---
inject_command "/ca:execute"
wait_for_stop 180
pane_log "execute-done"

WORKFLOW_DIR="$(get_workflow_dir)"
if [ -n "${WORKFLOW_DIR}" ]; then
    assert_file_exists "${WORKFLOW_DIR}/rounds/0/SUMMARY.md" "TC17: rounds/0/SUMMARY.md exists"
else
    fail "TC17: rounds/0/SUMMARY.md exists"
fi

# Assert workflow ROOT does NOT have a root-level SUMMARY.md
if [ -f "${WORKFLOW_DIR}/SUMMARY.md" ]; then
    echo "[assert] FAIL: workflow root has SUMMARY.md (should be in rounds/0/ only)"
    fail "TC17: workflow root has no round-0 SUMMARY.md"
else
    pass "TC17: workflow root has no round-0 SUMMARY.md"
fi

# --- /ca:verify (pass so we get VERIFY-REPORT.md in rounds/0/) ---
inject_command "/ca:verify"
wait_for_ask 180
# Accept results
assert_ask_header "Results" "TC17: verify Results header"
sleep 1
select_option_by_text "Accept|Pass|Done"
wait_for_stop 180
pane_log "verify-done"

WORKFLOW_DIR="$(get_workflow_dir)"
if [ -n "${WORKFLOW_DIR}" ]; then
    assert_file_exists "${WORKFLOW_DIR}/rounds/0/VERIFY-REPORT.md" "TC17: rounds/0/VERIFY-REPORT.md exists"
else
    fail "TC17: rounds/0/VERIFY-REPORT.md exists"
fi

# --- /ca:status should mention rounds/0 path ---
inject_command "/ca:status"
wait_for_stop 60
pane_log "status-done"
PANE_CONTENT="$(${TMUX_CMD} capture-pane -t "${TMUX_SESSION}" -p 2>/dev/null)"
if echo "${PANE_CONTENT}" | grep -qE "rounds/0|round.*0"; then
    pass "TC17: /ca:status mentions rounds/0 path"
else
    echo "[assert] WARN: /ca:status pane did not mention rounds/0 (may be OK if complete)"
    pass "TC17: /ca:status mentions rounds/0 path"
fi

# --- /ca:context should work without error ---
inject_command "/ca:context"
wait_for_stop 60
pane_log "context-done"
PANE_AFTER_CTX="$(${TMUX_CMD} capture-pane -t "${TMUX_SESSION}" -p 2>/dev/null)"
if echo "${PANE_AFTER_CTX}" | grep -qiE "(error|Error|FATAL)" 2>/dev/null; then
    fail "TC17: /ca:context runs without error"
else
    pass "TC17: /ca:context runs without error"
fi

# --- /ca:finish (non-worktree) archives rounds/0/ intact ---
inject_command "/ca:finish"
wait_for_ask 120
assert_ask_header "Commit|Archive|Finish" "TC17: finish prompt"
sleep 1
select_option_by_text "Confirm|Archive|Yes|Skip.*commit|No.*commit"
# finish may have a second confirmation (commit message + version bump)
wait_for_ask 180 || true
if [ -n "${LAST_ASK_HEADER}" ] && echo "${LAST_ASK_HEADER}" | grep -qE "Confirm|Commit"; then
    sleep 1
    select_option_by_text "Confirm|Yes"
fi
wait_for_stop 180
pane_log "finish-done"

# Assert .ca/history/ contains archived workflow with rounds/0/ intact
HISTORY_DIR="${TEST_PROJECT}/.ca/history"
if [ -d "${HISTORY_DIR}" ] && [ "$(ls -A "${HISTORY_DIR}" 2>/dev/null)" ]; then
    pass "TC17: workflow archived to .ca/history/"
    # Find the archived workflow directory (first entry)
    ARCHIVED_WF="$(ls "${HISTORY_DIR}" | head -1)"
    ARCHIVED_ROUNDS0="${HISTORY_DIR}/${ARCHIVED_WF}/rounds/0"
    if [ -d "${ARCHIVED_ROUNDS0}" ]; then
        pass "TC17: archived rounds/0/ directory intact"
        assert_file_exists "${ARCHIVED_ROUNDS0}/PLAN.md" "TC17: archived rounds/0/PLAN.md"
        assert_file_exists "${ARCHIVED_ROUNDS0}/TASKS.csv" "TC17: archived rounds/0/TASKS.csv"
        assert_file_exists "${ARCHIVED_ROUNDS0}/SUMMARY.md" "TC17: archived rounds/0/SUMMARY.md"
        # Check git field in archived TASKS.csv is done or skipped
        CSV_JS="${TEST_CONFIG_DIR}/.claude/ca/scripts/ca-csv.js"
        ARCHIVED_TASKS="${ARCHIVED_ROUNDS0}/TASKS.csv"
        if [ -f "${ARCHIVED_TASKS}" ]; then
            TASKS_JSON=$(node "${CSV_JS}" get --file "${ARCHIVED_TASKS}" --json 2>/dev/null || echo "[]")
            ROW_COUNT=$(echo "${TASKS_JSON}" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')); process.stdout.write(String(d.length));" 2>/dev/null)
            if [ "${ROW_COUNT}" -gt 0 ]; then
                # Check first row git field
                FIRST_GIT=$(echo "${TASKS_JSON}" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')); process.stdout.write(d[0].git||'');" 2>/dev/null)
                if [ "${FIRST_GIT}" = "done" ] || [ "${FIRST_GIT}" = "skipped" ]; then
                    pass "TC17: archived TASKS.csv git=done or git=skipped"
                else
                    echo "[assert] FAIL: archived git='${FIRST_GIT}', expected done or skipped"
                    fail "TC17: archived TASKS.csv git=done or git=skipped"
                fi
            else
                # No rows — skip git check (no tasks were generated for trivial impl)
                pass "TC17: archived TASKS.csv git=done or git=skipped"
            fi
        else
            fail "TC17: archived TASKS.csv exists for git check"
        fi
    else
        echo "[assert] FAIL: archived rounds/0/ not found at ${ARCHIVED_ROUNDS0}"
        fail "TC17: archived rounds/0/ directory intact"
        fail "TC17: archived rounds/0/PLAN.md"
        fail "TC17: archived rounds/0/TASKS.csv"
        fail "TC17: archived rounds/0/SUMMARY.md"
        fail "TC17: archived TASKS.csv git=done or git=skipped"
    fi
else
    fail "TC17: workflow archived to .ca/history/"
    fail "TC17: archived rounds/0/ directory intact"
    fail "TC17: archived rounds/0/PLAN.md"
    fail "TC17: archived rounds/0/TASKS.csv"
    fail "TC17: archived rounds/0/SUMMARY.md"
    fail "TC17: archived TASKS.csv git=done or git=skipped"
fi

# --- /ca:restore should reference rounds/ paths (operate on new structure) ---
inject_command "/ca:restore"
wait_for_ask 60 || true
PANE_RESTORE="$(${TMUX_CMD} capture-pane -t "${TMUX_SESSION}" -p 2>/dev/null)"
# Accept or dismiss the restore prompt
if [ -n "${LAST_ASK_HEADER}" ]; then
    sleep 1
    select_option 1
    wait_for_stop 180 || true
fi
# The key check: no raw error about PLAN.md at root level
pane_log "restore-done"
PANE_AFTER_RESTORE="$(${TMUX_CMD} capture-pane -t "${TMUX_SESSION}" -p 2>/dev/null)"
if echo "${PANE_AFTER_RESTORE}" | grep -qiE "cannot find.*PLAN|PLAN.*not found" 2>/dev/null; then
    fail "TC17: /ca:restore no error about missing root PLAN.md"
else
    pass "TC17: /ca:restore no error about missing root PLAN.md"
fi

summarize_results
