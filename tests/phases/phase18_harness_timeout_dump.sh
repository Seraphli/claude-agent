#!/usr/bin/env bash
# phase18_harness_timeout_dump.sh — Harness self-test: wait_for_event captures the
# tmux pane AT the timeout moment, including when the session dies mid-wait.
#
# Regression guard for the blind spot where the only failure-time pane dump was the
# trap 'cleanup' EXIT handler — by then the inner session was gone, yielding
# "(no pane content)" and leaving timeouts undebuggable.
#
# No Claude session needed: uses plain tmux panes displaying sentinel strings.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CA_REPO_ROOT="${CA_REPO_ROOT:-"$(cd "${SCRIPT_DIR}/../.." && pwd)"}"
export TEST_NAME="phase18-harness-timeout-dump"
source "${CA_REPO_ROOT}/tests/e2e_common.sh"

setup_test_env
trap 'cleanup' EXIT

# ---------------------------------------------------------------------------
# Sub-case A: session ALIVE at timeout -> dump shows the live pane sentinel.
# ---------------------------------------------------------------------------
SENTINEL_ALIVE="SENTINEL_PANE_ALIVE_18"
${TMUX_CMD} kill-session -t "${TMUX_SESSION}" 2>/dev/null || true
${TMUX_CMD} new-session -d -s "${TMUX_SESSION}" -x 220 -y 50 \
    "printf '%s\n' '${SENTINEL_ALIVE}'; sleep 60"
sleep 2  # let the pane render and let wait_for_event snapshot it

set +e
DUMP_ALIVE="$(wait_for_event 'PATTERN_NEVER_MATCHES_18A' 3 2>&1)"
set -e
echo "${DUMP_ALIVE}"

if echo "${DUMP_ALIVE}" | grep -q "DEBUG DUMP \[timeout\]"; then
    pass "TC20: timeout emits a [timeout] debug dump"
else
    fail "TC20: timeout emits a [timeout] debug dump"
fi
if echo "${DUMP_ALIVE}" | grep -q "${SENTINEL_ALIVE}"; then
    pass "TC20: alive-session timeout dump contains live pane content"
else
    fail "TC20: alive-session timeout dump contains live pane content"
fi
if echo "${DUMP_ALIVE}" | grep -q "no pane content"; then
    fail "TC20: no '(no pane content)' fallback while session is alive"
else
    pass "TC20: no '(no pane content)' fallback while session is alive"
fi

# ---------------------------------------------------------------------------
# Sub-case B: session DIES mid-wait -> rolling last-frame still shows sentinel.
# This is the original blind spot (session gone before exit-cleanup). A live-only
# implementation (no rolling snapshot) would FAIL this sub-case.
# ---------------------------------------------------------------------------
SENTINEL_DEAD="SENTINEL_PANE_DEAD_18"
${TMUX_CMD} kill-session -t "${TMUX_SESSION}" 2>/dev/null || true
# Pane prints the sentinel, stays alive ~4s, then exits (session dies mid-wait).
${TMUX_CMD} new-session -d -s "${TMUX_SESSION}" -x 220 -y 50 \
    "printf '%s\n' '${SENTINEL_DEAD}'; sleep 4"
sleep 1  # let the pane render before the wait begins (rolling capture catches it alive)

set +e
DUMP_DEAD="$(wait_for_event 'PATTERN_NEVER_MATCHES_18B' 6 2>&1)"
set -e
echo "${DUMP_DEAD}"

if echo "${DUMP_DEAD}" | grep -q "${SENTINEL_DEAD}"; then
    pass "TC20: dead-session timeout dump retains last pane frame (rolling snapshot)"
else
    fail "TC20: dead-session timeout dump retains last pane frame (rolling snapshot)"
fi
if echo "${DUMP_DEAD}" | grep -q "session terminated"; then
    pass "TC20: dead-session dump reports session terminated"
else
    fail "TC20: dead-session dump reports session terminated"
fi

summarize_results
