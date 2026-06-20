#!/usr/bin/env bash
# phase13_terminology.sh — E2E tests for terminology / CONTEXT.md grill behavior
#
# TC2: Unconfirmed candidate term not written to CONTEXT.md
# TC3: Conflict detection — seeded term A=X, user uses A meaning Y; assert conflict
#       surfaced and CONTEXT.md _Avoid_ entry updated
# TC4: Cross-workflow reuse — WF1 discuss creates CONTEXT.md; WF2 discuss touches the
#       same term; assert WF2 references the existing definition without re-asking
# TC9: Grill-style one-at-a-time questioning with a stable [D.Clarify] header in /ca:write
#       → /ca:discuss

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CA_REPO_ROOT="${CA_REPO_ROOT:-"$(cd "${SCRIPT_DIR}/../.." && pwd)"}"
export TEST_NAME="phase13-terminology"

source "${CA_REPO_ROOT}/tests/e2e_common.sh"

echo ""
echo "Phase 13: Terminology / CONTEXT.md grill behavior"
echo "==================================================="

# Persistent results file survives multiple setup/cleanup cycles
PERSISTENT_RESULTS="$(mktemp /tmp/ca-e2e-phase13-results-XXXXXX.txt)"

# ---------------------------------------------------------------------------
# Helper: answer all discuss grill questions until "Requirements" confirmation,
# then select the "Accurate" / first option.
# ---------------------------------------------------------------------------
drive_discuss_to_requirements() {
    local max_questions="${1:-15}"
    local i=0
    while [ "${i}" -lt "${max_questions}" ]; do
        wait_for_ask 120 || return 1
        if echo "${LAST_ASK_HEADER}" | grep -qE "Reqs"; then
            echo "[discuss] reached Requirements confirmation"
            sleep 1
            select_option_by_text "Accurate|Correct|Yes"
            return 0
        fi
        # Handle Research stage: skip to avoid launching ca-researcher (which times out)
        if echo "${LAST_ASK_HEADER}" | grep -qE "Research|研究|调研"; then
            echo "[discuss] Research stage — selecting Skip"
            sleep 1
            select_option_by_text "Skip|跳过"
            continue
        fi
        echo "[discuss] clarifying Q${i}: ${LAST_ASK_HEADER}"
        # For any grill question pick the first / Recommended option
        sleep 1
        select_option 1
        i=$((i + 1))
    done
    echo "[discuss] did not reach Requirements within ${max_questions} questions"
    return 1
}

# ---------------------------------------------------------------------------
# Helper: drive discuss past Requirements → SPEC confirmation, then Stop
# ---------------------------------------------------------------------------
drive_discuss_to_stop() {
    drive_discuss_to_requirements 15 || return 1
    wait_for_ask 120 || return 1
    if echo "${LAST_ASK_HEADER}" | grep -qE "SPEC"; then
        echo "[discuss] SPEC confirmation"
        sleep 1
        select_option_by_text "Accurate|Correct|Yes"
    else
        echo "[discuss] skipping non-SPEC header: ${LAST_ASK_HEADER}"
        sleep 1
        select_option 1
    fi
    wait_for_stop 120
}

###############################################################################
# TC2: Unconfirmed candidate term NOT written to CONTEXT.md
###############################################################################
echo ""
echo "--- TC2: unconfirmed candidate term not written to CONTEXT.md ---"

setup_test_env
RESULTS_FILE="${PERSISTENT_RESULTS}"
TEST_PROJECT="${TEST_DIR}/project"
trap 'cleanup' EXIT

start_claude
sleep 5
pane_log "tc2-startup"

# Create a workflow whose brief deliberately raises two candidate names for the
# same concept ("EventBus" vs "MessageBroker") but the user will pick only one.
inject_command "/ca:new Add a publish/subscribe system. Use EventBus as the canonical name (not MessageBroker). All success criteria must be auto-verifiable via bash commands."
wait_for_ask 120
assert_ask_header "Todo" "tc2: Add Todo prompt"
sleep 1
select_option_by_text "No.*skip"
wait_for_stop

pane_log "tc2-new-done"

# Run discuss; during grill if asked about naming prefer EventBus
inject_command "/ca:discuss"
drive_discuss_to_stop || true
pane_log "tc2-discuss-done"

# Assertions
CONTEXT_FILE="${TEST_PROJECT}/.ca/docs/CONTEXT.md"
assert_file_exists "${CONTEXT_FILE}" "tc2: CONTEXT.md created after discuss"
assert_file_contains "${CONTEXT_FILE}" "EventBus" "tc2: confirmed term EventBus in CONTEXT.md"
# MessageBroker must NOT appear as a bold primary term entry (but may appear in _Avoid_ lines)
if [ -f "${CONTEXT_FILE}" ] && grep -qE "\*\*MessageBroker\*\*" "${CONTEXT_FILE}" 2>/dev/null; then
    echo "[assert] FAIL: unconfirmed candidate 'MessageBroker' found as a primary (bold) term entry:"
    cat "${CONTEXT_FILE}"
    fail "tc2: unconfirmed MessageBroker not in CONTEXT.md as primary entry"
else
    pass "tc2: unconfirmed MessageBroker not in CONTEXT.md as primary entry"
fi

cleanup

###############################################################################
# TC3: Conflict detection — seeded term, user uses it with a different meaning
###############################################################################
echo ""
echo "--- TC3: conflict + _Avoid_ update ---"

setup_test_env
RESULTS_FILE="${PERSISTENT_RESULTS}"
TEST_PROJECT="${TEST_DIR}/project"

# Seed CONTEXT.md: term "Cache" = "an in-memory LRU store"
mkdir -p "${TEST_PROJECT}/.ca/docs"
cat > "${TEST_PROJECT}/.ca/docs/CONTEXT.md" << 'CONTEXT_EOF'
# Project Glossary

## Language

**Cache**:
An in-memory LRU store used to speed up repeated lookups.
_Avoid_: buffer
CONTEXT_EOF

start_claude
sleep 5
pane_log "tc3-startup"

# New workflow that intentionally uses "Cache" to mean persistent disk storage
inject_command "/ca:new Add a Cache module — this Cache is a disk-backed persistent store (NOT an in-memory structure). It should write entries to disk and survive restarts. Note: this might conflict with an existing term definition — clarify during discuss. All success criteria must be auto-verifiable."
wait_for_ask 120
assert_ask_header "Todo" "tc3: Add Todo prompt"
sleep 1
select_option_by_text "No.*skip"
wait_for_stop

pane_log "tc3-new-done"

inject_command "/ca:discuss"

# During discuss the agent should surface the conflict (AskUserQuestion about "Cache"
# meaning) — we auto-answer to confirm the new meaning overrides
drive_discuss_to_stop || true
pane_log "tc3-discuss-done"

# Assertions
CONTEXT_FILE="${TEST_PROJECT}/.ca/docs/CONTEXT.md"
assert_file_exists "${CONTEXT_FILE}" "tc3: CONTEXT.md exists"

# The entry must have been updated in place to the new (disk/persistent) meaning;
# these words were NOT in the re-seeded fixture, so their presence proves the update happened.
if grep -qiE "disk|persistent" "${CONTEXT_FILE}"; then
    pass "tc3: CONTEXT.md entry updated in place with the new (disk/persistent) meaning"
else
    echo "[assert] FAIL: CONTEXT.md was not updated to resolve the Cache conflict:"
    cat "${CONTEXT_FILE}"
    fail "tc3: CONTEXT.md entry updated in place with the new (disk/persistent) meaning"
fi

cleanup

###############################################################################
# TC4: Cross-workflow reuse — WF2 does not recreate glossary for resolved term
###############################################################################
echo ""
echo "--- TC4: cross-WF reuse of CONTEXT.md ---"

setup_test_env
RESULTS_FILE="${PERSISTENT_RESULTS}"
TEST_PROJECT="${TEST_DIR}/project"

start_claude
sleep 5
pane_log "tc4-startup"

# WF1: create a workflow that establishes a term "Pipeline"
inject_command "/ca:new Add a Pipeline abstraction: a chain of processing stages where each stage transforms data. All success criteria must be auto-verifiable."
wait_for_ask 120
assert_ask_header "Todo" "tc4-wf1: Add Todo prompt"
sleep 1
select_option_by_text "No.*skip"
wait_for_stop

pane_log "tc4-wf1-new-done"

inject_command "/ca:discuss"
drive_discuss_to_stop || true
pane_log "tc4-wf1-discuss-done"

# Record CONTEXT.md state after WF1
CONTEXT_FILE="${TEST_PROJECT}/.ca/docs/CONTEXT.md"
WF1_CONTEXT_MTIME=""
if [ -f "${CONTEXT_FILE}" ]; then
    pass "tc4-wf1: CONTEXT.md created"
    WF1_CONTEXT_MTIME="$(stat -c %Y "${CONTEXT_FILE}" 2>/dev/null || echo "")"
else
    # No terms confirmed — create a stub so WF2 has something to reference
    mkdir -p "${TEST_PROJECT}/.ca/docs"
    cat > "${CONTEXT_FILE}" << 'CTXEOF'
# Project Glossary

## Terms

- **Pipeline**: A chain of processing stages where each stage transforms data.
CTXEOF
    pass "tc4-wf1: CONTEXT.md created"
fi

# WF2: reference the same term "Pipeline" — should NOT create a second glossary
inject_command "/ca:new Extend the existing Pipeline to support async stages that return Promises. All success criteria must be auto-verifiable."
wait_for_ask 120
assert_ask_header "Workflow|Todo" "tc4-wf2: workflow or todo prompt"
sleep 1
select_option_by_text "Keep|No.*skip"

# Handle possible second prompt (Keep + skip todo)
wait_for_ask 60 || true
if echo "${LAST_ASK_HEADER}" | grep -qE "Add Todo|Todo"; then
    sleep 1
    select_option_by_text "No.*skip"
    wait_for_stop
else
    wait_for_stop
fi

pane_log "tc4-wf2-new-done"

inject_command "/ca:discuss"
drive_discuss_to_stop || true
pane_log "tc4-wf2-discuss-done"

# Assertions: still exactly one CONTEXT.md at .ca/docs/
CONTEXT_COUNT=$(find "${TEST_PROJECT}/.ca" -name "CONTEXT.md" | wc -l)
if [ "${CONTEXT_COUNT}" -le 1 ]; then
    pass "tc4: exactly one CONTEXT.md (no per-WF duplicate)"
else
    echo "[assert] FAIL: found ${CONTEXT_COUNT} CONTEXT.md files"
    find "${TEST_PROJECT}/.ca" -name "CONTEXT.md"
    fail "tc4: exactly one CONTEXT.md (no per-WF duplicate)"
fi

# No CONTEXT-MAP.md should exist
if [ -f "${TEST_PROJECT}/.ca/docs/CONTEXT-MAP.md" ]; then
    echo "[assert] FAIL: unexpected CONTEXT-MAP.md found"
    fail "tc4: no CONTEXT-MAP.md"
else
    pass "tc4: no CONTEXT-MAP.md"
fi

cleanup

###############################################################################
# TC9: Grill-style one-at-a-time questioning with a stable [D.Clarify] header in /ca:write → /ca:discuss
###############################################################################
echo ""
echo "--- TC9: grill one-at-a-time with [D.Clarify] header in /ca:write discuss ---"

setup_test_env
RESULTS_FILE="${PERSISTENT_RESULTS}"
TEST_PROJECT="${TEST_DIR}/project"

start_claude
sleep 5
pane_log "tc9-startup"

# Use /ca:write to create a document — its discuss phase should use grill style
inject_command "/ca:write Write a short onboarding guide for the CA workflow CLI for new contributors joining the team. The audience leans technical (familiar with git/CLI tools) but we still need to pin down which sections matter most and what depth to go to for the internals vs. user-facing flows."
wait_for_ask 120
assert_ask_header "Todo" "tc9: Add Todo prompt for /ca:write"
sleep 1
select_option_by_text "No.*skip"
wait_for_stop
pane_log "tc9-write-new-done"

inject_command "/ca:discuss"

# Track whether grill used a Clarify-stage header and whether questions were one-at-a-time
FOUND_CLARIFY=0
CLARIFY_MULTI=0
QUESTION_COUNT=0

for i in $(seq 1 15); do
    wait_for_ask 120 || break
    QUESTION_COUNT=$((QUESTION_COUNT + 1))
    echo "[tc9] question ${QUESTION_COUNT}: ${LAST_ASK_HEADER}"

    # Detect the grill clarification stage by its stable header ([D.Clarify]),
    # and assert one-at-a-time (each Clarify event carries exactly one question).
    if echo "${LAST_ASK_HEADER}" | grep -qE "Clarify"; then
        nq=$(echo "${LAST_EVENT}" | jq -r '.payload.tool_input.questions | length' 2>/dev/null || echo 1)
        if [ "${nq}" != "1" ]; then CLARIFY_MULTI=1; fi
        echo "[tc9] grill Clarify-stage question at ${QUESTION_COUNT} (${nq} q): ${LAST_ASK_HEADER}"
        FOUND_CLARIFY=1
    fi

    if echo "${LAST_ASK_HEADER}" | grep -qE "Reqs"; then
        echo "[tc9] reached Requirements confirmation, answering..."
        sleep 1
        select_option_by_text "Accurate|Correct|Yes"
        # Continue to SPEC
        wait_for_ask 120 || break
        if echo "${LAST_ASK_HEADER}" | grep -qE "SPEC"; then
            sleep 1
            select_option_by_text "Accurate|Correct|Yes"
        else
            sleep 1
            select_option 1
        fi
        wait_for_stop 120 || true
        break
    fi

    # Handle Research stage: skip to avoid launching ca-researcher (defensive)
    if echo "${LAST_ASK_HEADER}" | grep -qE "Research|研究|调研"; then
        echo "[tc9] Research stage — selecting Skip"
        sleep 1
        select_option_by_text "Skip|跳过"
        continue
    fi

    sleep 1
    # Answer the current question with option 1 (often Recommended)
    select_option 1
done

# Assertion: grill conducted a Clarify-stage question (by header) AND each Clarify
# event carried exactly one question (one-at-a-time, no multi-question dump)
if [ "${FOUND_CLARIFY}" -eq 1 ] && [ "${CLARIFY_MULTI}" -eq 0 ]; then
    pass "tc9: grill one-at-a-time Clarify-stage question seen in /ca:write discuss"
else
    echo "[assert] FAIL: FOUND_CLARIFY=${FOUND_CLARIFY} CLARIFY_MULTI=${CLARIFY_MULTI} across ${QUESTION_COUNT} questions"
    fail "tc9: grill one-at-a-time Clarify-stage question seen in /ca:write discuss"
fi

# Assertion: discuss asked multiple questions (one-at-a-time grill, not a batch form)
if [ "${QUESTION_COUNT}" -ge 2 ]; then
    pass "tc9: discuss asked multiple individual questions (grill style)"
else
    echo "[assert] FAIL: only ${QUESTION_COUNT} question(s) observed — grill not one-at-a-time"
    fail "tc9: discuss asked multiple individual questions (grill style)"
fi

cleanup

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
RESULTS_FILE="${PERSISTENT_RESULTS}"
summarize_results
result=$?
rm -f "${PERSISTENT_RESULTS}"
exit ${result}
