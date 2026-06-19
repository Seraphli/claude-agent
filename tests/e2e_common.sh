# e2e_common.sh — Shared E2E test infrastructure for claude-agent tests
#
# Usage: source this file in each e2e test script
#
# Requires: tmux, node, claude CLI (with --model, --setting-sources support)
#
# Environment expected:
#   CA_REPO_ROOT  — absolute path to the claude-agent repo root
#   TEST_NAME     — name of the current test suite (used for tmux session naming)

# Prevent any browser from opening during tests
export BROWSER=none

# --- Configuration ---

# Isolated tmux server per phase to avoid triggering production hooks
# and prevent parallel phases from interfering with each other
TMUX_CMD="tmux -L ca-e2e-${TEST_NAME:-test} -f /dev/null"

# Tmux session name, derived from test suite name to avoid collisions
TMUX_SESSION="ca-e2e-${TEST_NAME:-test}"

# Results file: each line is PASS|<name> or FAIL|<name>
RESULTS_FILE=""

# Temp dir created by setup_test_env
TEST_DIR=""

# Isolated config directory (used as CLAUDE_CONFIG_DIR)
TEST_CONFIG_DIR=""

# Idle poll interval in seconds
POLL_INTERVAL=2

# Event log file path (set by setup_test_env)
EVENT_LOG=""

# Last line count seen in EVENT_LOG (used by wait_for_event)
EVENT_LINE_COUNT=0

# Last AskUserQuestion header received (set by wait_for_ask)
LAST_ASK_HEADER=""

# --- Setup / Teardown ---

# setup_test_env — Create isolated temp environment, copy fixture, init git
#
# After calling this function:
#   TEST_DIR        — temp dir (project root for this test run)
#   TEST_CONFIG_DIR — isolated config dir used as CLAUDE_CONFIG_DIR
#   RESULTS_FILE    — initialized at TEST_DIR/results.txt
setup_test_env() {
    # Create temp dir
    TEST_DIR="$(mktemp -d /tmp/ca-e2e-XXXXXX)"

    # Create isolated config directory (used as CLAUDE_CONFIG_DIR)
    TEST_CONFIG_DIR="${TEST_DIR}/config"
    mkdir -p "${TEST_CONFIG_DIR}"

    # Copy only credentials — strip MCP servers and project configs to avoid
    # loading production MCP servers (chrome-devtools, etc.) during tests
    mkdir -p "${TEST_CONFIG_DIR}/.claude"
    cp "${HOME}/.claude/.credentials.json" "${TEST_CONFIG_DIR}/.claude/.credentials.json"
    node -e "
        const fs = require('fs');
        const src = JSON.parse(fs.readFileSync('${HOME}/.claude.json', 'utf8'));
        delete src.mcpServers;
        delete src.projects;
        delete src.claudeInChromeDefaultEnabled;
        delete src.chromeExtension;
        delete src.cachedChromeExtensionInstalled;
        fs.writeFileSync('${TEST_CONFIG_DIR}/.claude/.claude.json', JSON.stringify(src, null, 2));
    "

    # Install CA commands/agents first (does not touch settings.json in --home mode)
    node "${CA_REPO_ROOT}/bin/install.js" --home "${TEST_CONFIG_DIR}" > /dev/null 2>&1

    # Create deterministic CA config (prevents settings auto-trigger, disables branches)
    cat > "${TEST_CONFIG_DIR}/.claude/ca/config.md" << 'CONFIG'
interaction_language: English
comment_language: English
code_language: English
use_worktrees: false
auto_proceed_to_plan: false
auto_proceed_to_verify: false
CONFIG

    # Setup hook handler
    cp "${CA_REPO_ROOT}/tests/hook_handler.sh" "${TEST_DIR}/hook_handler.sh"
    chmod +x "${TEST_DIR}/hook_handler.sh"
    EVENT_LOG="${TEST_DIR}/events.log"
    touch "${EVENT_LOG}"
    EVENT_LINE_COUNT=0

    # Create settings with hooks (AFTER install.js to ensure no overwrite)
    cat > "${TEST_CONFIG_DIR}/.claude/settings.json" << SETTINGS
{
  "permissions": {
    "allow": [],
    "deny": []
  },
  "skipDangerousModePermissionPrompt": true,
  "hooks": {
    "PreToolUse": [{
      "hooks": [{
        "type": "command",
        "command": "CA_EVENT_LOG='${EVENT_LOG}' ${TEST_DIR}/hook_handler.sh",
        "timeout": 5
      }]
    }],
    "Stop": [{
      "hooks": [{
        "type": "command",
        "command": "CA_EVENT_LOG='${EVENT_LOG}' ${TEST_DIR}/hook_handler.sh",
        "timeout": 5
      }]
    }]
  }
}
SETTINGS

    # Copy fixture project into test dir
    local fixture_src="${CA_REPO_ROOT}/tests/fixtures/test-project"
    local project_dir="${TEST_DIR}/project"
    cp -r "${fixture_src}" "${project_dir}"

    # Create workspace-level CA config (highest priority, overrides global)
    mkdir -p "${project_dir}/.ca"
    cat > "${project_dir}/.ca/config.md" << 'WSCONFIG'
interaction_language: English
comment_language: English
code_language: English
use_worktrees: false
auto_proceed_to_plan: false
auto_proceed_to_verify: false
WSCONFIG

    # Initialize git repo in project dir (claude-agent requires a git repo)
    git -C "${project_dir}" init -q
    git -C "${project_dir}" config user.email "test@example.com"
    git -C "${project_dir}" config user.name "Test"
    git -C "${project_dir}" add -A
    git -C "${project_dir}" commit -q -m "init"

    # Initialize results file
    RESULTS_FILE="${TEST_DIR}/results.txt"
    touch "${RESULTS_FILE}"

    echo "[setup] TEST_DIR=${TEST_DIR}"
    echo "[setup] TEST_CONFIG_DIR=${TEST_CONFIG_DIR}"
    echo "[setup] project=${project_dir}"
}

# dump_debug — Print debug info (pane content and event log) for troubleshooting
dump_debug() {
    local label="${1:-cleanup}"
    echo ""
    echo "=== DEBUG DUMP [${label}] ==="
    echo "--- pane content ---"
    ${TMUX_CMD} capture-pane -t "${TMUX_SESSION}" -p -S -100 2>/dev/null || echo "(no pane content)"
    echo "--- event log (last 30 lines) ---"
    if [ -n "${EVENT_LOG}" ] && [ -f "${EVENT_LOG}" ]; then
        tail -30 "${EVENT_LOG}" 2>/dev/null || echo "(empty)"
    else
        echo "(no event log)"
    fi
    echo "=== END DEBUG DUMP ==="
    echo ""
}

# preserve_transcripts — Copy transcript JSONL files to logs dir before cleanup
preserve_transcripts() {
    if [ -z "${TEST_CONFIG_DIR}" ] || [ -z "${CA_REPO_ROOT}" ]; then
        return
    fi
    local log_dir="${CA_REPO_ROOT}/tests/logs"
    mkdir -p "${log_dir}"
    local ts
    ts="$(date +%Y%m%d-%H%M%S)"
    local count=0
    while IFS= read -r -d '' f; do
        cp "${f}" "${log_dir}/${TEST_NAME:-unknown}-${ts}-transcript-$(basename "${f}")"
        count=$((count + 1))
    done < <(find "${TEST_CONFIG_DIR}/.claude/projects" -name '*.jsonl' -print0 2>/dev/null)
    if [ "${count}" -gt 0 ]; then
        echo "[cleanup] preserved ${count} transcript(s) to ${log_dir}/"
    fi
}

# cleanup — Kill tmux session and remove temp directory
cleanup() {
    # Dump debug info before cleanup
    dump_debug "exit-cleanup"

    # Kill tmux session and server
    ${TMUX_CMD} kill-session -t "${TMUX_SESSION}" 2>/dev/null || true
    ${TMUX_CMD} kill-server 2>/dev/null || true
    sleep 2

    # Preserve transcript files before removing temp dir
    preserve_transcripts

    # Remove temp dir
    if [ -n "${TEST_DIR}" ] && [ -d "${TEST_DIR}" ]; then
        rm -rf "${TEST_DIR}"
    fi
}

# --- Claude Session Management ---

# start_claude — Launch claude in a new tmux session inside the project dir
#
# Uses CLAUDE_CONFIG_DIR to redirect user scope (~/.claude/) to an isolated
# temp config dir where CA commands/agents are pre-installed. This ensures
# slash command discovery works via the user scope without polluting ~/.claude/.
start_claude() {
    local project_dir="${TEST_DIR}/project"

    # Kill any existing session with this name
    ${TMUX_CMD} kill-session -t "${TMUX_SESSION}" 2>/dev/null || true

    # Start new detached tmux session running claude in the project dir
    # CLAUDE_CONFIG_DIR redirects user scope (~/.claude/) to our temp config dir
    # BROWSER=none prevents any browser from opening (e.g., auth, MCP)
    ${TMUX_CMD} new-session -d -s "${TMUX_SESSION}" \
        -x 220 -y 50 \
        "cd '${project_dir}' && BROWSER=none CLAUDE_CONFIG_DIR='${TEST_CONFIG_DIR}/.claude' claude --model sonnet --dangerously-skip-permissions --setting-sources user 2>'${TEST_DIR}/cc-stderr.log'; echo \$? > '${TEST_DIR}/cc-exit.log'"

    echo "[claude] started tmux session: ${TMUX_SESSION}"

    # Wait for Claude to start, auto-answer trust prompt if it appears
    local start_wait=0
    while [ ${start_wait} -lt 30 ]; do
        sleep 2
        start_wait=$((start_wait + 2))
        local pane
        pane="$(${TMUX_CMD} capture-pane -t "${TMUX_SESSION}" -p 2>/dev/null)" || true
        # Check for trust prompt ("Yes, I trust this folder")
        if echo "${pane}" | grep -q "trust this folder"; then
            echo "[claude] trust prompt detected, auto-accepting..."
            ${TMUX_CMD} send-keys -t "${TMUX_SESSION}" Enter
            sleep 3
            break
        fi
        # Check if Claude is ready (shows the prompt line)
        if echo "${pane}" | grep -q "^❯"; then
            echo "[claude] ready (no trust prompt)"
            break
        fi
    done
}

# inject_command — Send a command string to the claude tmux pane
#
# Args:
#   $1 — command text to send (will be followed by Enter)
inject_command() {
    local cmd="$1"
    pane_log "before-inject"
    ${TMUX_CMD} send-keys -t "${TMUX_SESSION}" "${cmd}" ""
    sleep 2
    pane_log "after-text-before-enter"
    ${TMUX_CMD} send-keys -t "${TMUX_SESSION}" Enter
    sleep 2
    pane_log "after-enter"
}

# --- Interaction Helpers ---

# check_session_idle — Query idle API for the E2E test session's busy/idle state
#
# Outputs one of: "busy", "idle", "unknown"
# Requires globals: TMUX_CMD, TMUX_SESSION
check_session_idle() {
    local pane_id socket_path tmux_target idle_json idle_val
    pane_id="$(${TMUX_CMD} display-message -t "${TMUX_SESSION}" -p '#{pane_id}' 2>/dev/null || true)"
    socket_path="$(${TMUX_CMD} display-message -t "${TMUX_SESSION}" -p '#{socket_path}' 2>/dev/null || true)"
    if [ -z "${pane_id}" ] || [ -z "${socket_path}" ]; then
        echo "unknown"
        return
    fi
    tmux_target="${pane_id}@${socket_path}"
    local encoded_target
    encoded_target="$(printf "%s" "${tmux_target}" | python3 -c "import sys,urllib.parse; print(urllib.parse.quote(sys.stdin.read()))" 2>/dev/null || true)"
    if [ -z "${encoded_target}" ]; then
        echo "unknown"
        return
    fi
    idle_json="$(curl -s "http://127.0.0.1:12500/session/idle?target=${encoded_target}" 2>/dev/null || true)"
    if [ -z "${idle_json}" ]; then
        echo "unknown"
        return
    fi
    idle_val="$(echo "${idle_json}" | jq -r '[.sessions | to_entries[].value.idle | tostring] | first // empty' 2>/dev/null || true)"
    if [ "${idle_val}" = "true" ]; then
        echo "idle"
    elif [ "${idle_val}" = "false" ]; then
        echo "busy"
    else
        echo "unknown"
    fi
}

# wait_for_event — Wait for a new event matching pattern in EVENT_LOG
#
# Args:
#   $1 — grep pattern to match
#   $2 — timeout in seconds (default: 45)
#
# Sets LAST_EVENT to the matching line.
# Returns 0 on match, 1 on timeout.
#
# On timeout, queries the idle API to diagnose busy vs idle:
#   - idle: pattern was not emitted (functional issue), fails immediately
#   - busy: LLM still processing, retries up to 3 additional rounds
#   - unknown: API unavailable, falls back to original timeout behavior
wait_for_event() {
    local pattern="$1"
    local timeout="${2:-45}"
    local caller_line="${3:-${BASH_SOURCE[1]##*/}:${BASH_LINENO[0]:-unknown}}"
    local start_lines="${EVENT_LINE_COUNT:-0}"
    local last_pane=""
    local max_retries=3
    local retry=0
    local idle_diagnosis=""

    while true; do
        local start=$SECONDS
        while (( SECONDS - start < timeout )); do
            idle_diagnosis="$(check_session_idle)"
            local current_lines
            current_lines=$(wc -l < "${EVENT_LOG}" 2>/dev/null || echo 0)
            if [ "${current_lines}" -gt "${start_lines}" ]; then
                local match
                match=$(tail -n +"$((start_lines + 1))" "${EVENT_LOG}" | grep -m1 "${pattern}" || true)
                if [ -n "${match}" ]; then
                    LAST_EVENT="${match}"
                    EVENT_LINE_COUNT="${current_lines}"
                    return 0
                fi
            fi
            local snap
            snap="$(${TMUX_CMD} capture-pane -t "${TMUX_SESSION}" -p -S -100 2>/dev/null || true)"
            if [ -n "${snap}" ]; then last_pane="${snap}"; fi
            sleep 1
        done

        if [ "${idle_diagnosis}" = "busy" ] && (( retry < max_retries )); then
            retry=$((retry + 1))
            echo "BUSY: LLM still processing, extending wait (round ${retry}/${max_retries}, +${timeout}s)..."
            continue
        fi
        break
    done

    local timeout_prefix="TIMEOUT"
    if [ -n "${caller_line}" ]; then timeout_prefix="TIMEOUT [${caller_line}]"; fi

    if ! ${TMUX_CMD} has-session -t "${TMUX_SESSION}" 2>/dev/null; then
        echo "CC_SESSION_TERMINATED [${caller_line}]: wait_for_event pattern='${pattern}' exceeded ${timeout}s — claude process exited"
    elif [ "${idle_diagnosis}" = "busy" ]; then
        echo "WARNING: LLM still busy after ${max_retries} retry rounds (total wait: ~$(( timeout * (max_retries + 1) ))s)"
        echo "${timeout_prefix}: wait_for_event pattern='${pattern}' exceeded ${timeout}s x$((max_retries + 1)) — LLM timeout (busy, ${max_retries} retries exhausted)"
    elif [ "${idle_diagnosis}" = "idle" ]; then
        echo "${timeout_prefix}: wait_for_event pattern='${pattern}' exceeded ${timeout}s — pattern not detected (idle)"
    else
        echo "${timeout_prefix}: wait_for_event pattern='${pattern}' exceeded ${timeout}s"
    fi

    echo "=== DEBUG DUMP [timeout] ==="
    echo "--- pane content (at timeout) ---"
    local now_pane
    now_pane="$(${TMUX_CMD} capture-pane -t "${TMUX_SESSION}" -p -S -100 2>/dev/null || true)"
    if [ -n "${now_pane}" ]; then
        printf '%s\n' "${now_pane}"
    elif [ -n "${last_pane}" ]; then
        echo "(session gone at timeout — last snapshot taken during the wait:)"
        printf '%s\n' "${last_pane}"
    else
        echo "(no pane content — session terminated and no snapshot was captured)"
    fi
    echo "--- session alive? ---"
    if ${TMUX_CMD} has-session -t "${TMUX_SESSION}" 2>/dev/null; then
        echo "yes (stuck/slow — session still running)"
    else
        echo "no (session terminated during wait)"
    fi
    echo "--- idle API diagnosis ---"
    echo "status: ${idle_diagnosis:-not checked}"
    if (( retry > 0 )); then
        echo "retried: ${retry}/${max_retries} rounds (total wait: ~$(( timeout * (retry + 1) ))s)"
    fi
    echo "--- event log (last 30 lines) ---"
    if [ -n "${EVENT_LOG}" ] && [ -f "${EVENT_LOG}" ]; then
        tail -30 "${EVENT_LOG}" 2>/dev/null || echo "(empty)"
    else
        echo "(no event log)"
    fi
    echo "--- cc exit info ---"
    if [ -n "${TEST_DIR}" ] && [ -f "${TEST_DIR}/cc-exit.log" ]; then
        echo "exit code: $(cat "${TEST_DIR}/cc-exit.log" 2>/dev/null)"
        if [ -f "${TEST_DIR}/cc-stderr.log" ]; then
            echo "stderr (last 20 lines):"
            tail -20 "${TEST_DIR}/cc-stderr.log" 2>/dev/null || echo "(empty)"
        fi
    else
        echo "(no cc-exit.log — claude may still be running)"
    fi
    echo "=== END DEBUG DUMP ==="
    return 1
}

# wait_for_ask — Wait for AskUserQuestion event and extract header into LAST_ASK_HEADER
#
# Args:
#   $1 — timeout in seconds (default: 45)
#
# Sets LAST_ASK_HEADER to the header value from the event.
# Returns 0 if AskUserQuestion received, 1 if timeout.
wait_for_ask() {
    local timeout="${1:-45}"
    if wait_for_event '"tool_name":"AskUserQuestion"' "${timeout}" "${BASH_SOURCE[1]##*/}:${BASH_LINENO[0]}"; then
        LAST_ASK_HEADER=$(echo "${LAST_EVENT}" | grep -oP '"header"\s*:\s*"[^"]*"' | head -1 | sed 's/.*"header"\s*:\s*"\([^"]*\)".*/\1/')
        local ask_question ask_options
        ask_question=$(echo "${LAST_EVENT}" | jq -r '.payload.tool_input.questions[0].question // empty' 2>/dev/null)
        ask_options=$(echo "${LAST_EVENT}" | jq -r '.payload.tool_input.questions[0].options[].label' 2>/dev/null | tr '\n' ', ' | sed 's/,$//')
        echo "[ask] received: ${LAST_ASK_HEADER}"
        echo "[ask]   question: ${ask_question}"
        echo "[ask]   options: [${ask_options}]"
        return 0
    fi
    return 1
}

# assert_ask_header — Assert that LAST_ASK_HEADER matches an expected pattern
#
# Args:
#   $1 — expected header pattern (grep -E regex)
#   $2 — human-readable test name
assert_ask_header() {
    local expected="$1"
    local name="$2"
    if echo "${LAST_ASK_HEADER}" | grep -qE "${expected}"; then
        pass "${name}"
    else
        echo "[assert] FAIL: expected header matching '${expected}', got '${LAST_ASK_HEADER}'"
        fail "${name}"
    fi
}

# wait_for_ask_expect — Wait for a specific AskUserQuestion header, auto-answering unexpected ones
#
# Args:
#   $1 — expected header pattern (grep -E regex)
#   $2 — answer pattern for unexpected headers (select_option_by_text pattern)
#   $3 — timeout in seconds (default: 45)
#
# If the received header doesn't match expected, selects option 1 and waits again.
# Retries up to 3 times before giving up.
wait_for_ask_expect() {
    local expected="$1"
    local fallback_answer="${2:-.*}"
    local timeout="${3:-45}"
    local retries=0
    while [ ${retries} -lt 3 ]; do
        wait_for_ask "${timeout}" || return 1
        if echo "${LAST_ASK_HEADER}" | grep -qE "${expected}"; then
            return 0
        fi
        echo "[ask-expect] got '${LAST_ASK_HEADER}', expected '${expected}', auto-answering and retrying..."
        sleep 1
        select_option 1
        retries=$((retries + 1))
    done
    echo "[ask-expect] gave up after ${retries} retries, last header: ${LAST_ASK_HEADER}"
    return 1
}

# drive_grill_to_gate — consume ONLY pre-gate grill clarification ([P/D.Clarify])
# and Research questions until a target confirmation-gate header appears. Any other
# unexpected header (or a later gate out of order) is treated as a FAILURE, so header
# drift / misordering surfaces instead of being silently answered.
# Sets GRILL_CLARIFY_SEEN=1 if at least one Clarify-stage question was consumed.
#
# Args:
#   $1 — target gate header pattern (grep -E regex, e.g. "Reqs|需求")
#   $2 — timeout per ask in seconds (default: 120)
#   $3 — max questions to consume before giving up (default: 15)
# Returns 0 when the target header is reached, 1 on timeout / unexpected header / give-up.
drive_grill_to_gate() {
    local target="$1"
    local timeout="${2:-120}"
    local maxq="${3:-15}"
    GRILL_CLARIFY_SEEN=0
    local i=0
    while [ "${i}" -lt "${maxq}" ]; do
        wait_for_ask "${timeout}" || return 1
        if echo "${LAST_ASK_HEADER}" | grep -qE "${target}"; then
            return 0
        fi
        if echo "${LAST_ASK_HEADER}" | grep -qE "Clarify"; then
            local nq
            nq=$(echo "${LAST_EVENT}" | jq -r '.payload.tool_input.questions | length' 2>/dev/null || echo 1)
            if [ "${nq}" != "1" ]; then
                echo "[gate] Clarify event has ${nq} questions — violates one-at-a-time (multi-question dump)"
                return 1
            fi
            GRILL_CLARIFY_SEEN=1
            echo "[gate] consumed Clarify question (1 q): ${LAST_ASK_HEADER}"
            sleep 1
            select_option 1
        elif echo "${LAST_ASK_HEADER}" | grep -qE "Research|研究|调研"; then
            echo "[gate] skipping Research: ${LAST_ASK_HEADER}"
            sleep 1
            select_option_by_text "Skip|跳过"
        else
            echo "[gate] UNEXPECTED pre-gate header '${LAST_ASK_HEADER}' (expected ${target}, Clarify, or Research) — failing"
            return 1
        fi
        i=$((i + 1))
    done
    echo "[gate] gave up after ${maxq} questions, last header: ${LAST_ASK_HEADER}"
    return 1
}

# wait_for_step_confirmations — Handle step-by-step plan confirmation (Confirmation 2b)
#
# Loops waiting for "Step N" AskUserQuestion headers, auto-selecting "Correct" for each.
# Stops when it receives a header matching the next_expected pattern (e.g., "Results").
# Sets LAST_ASK_HEADER to the final matching header so callers can assert it directly.
#
# Args:
#   $1 — next expected header pattern after all steps (grep -E regex, e.g., "Results|结果")
#   $2 — test name prefix (e.g., "plan")
#   $3 — timeout per step in seconds (default: 45)
wait_for_step_confirmations() {
    local next_expected="$1"
    local name_prefix="$2"
    local timeout="${3:-45}"
    local step_count=0
    while true; do
        wait_for_ask "${timeout}" || return 1
        if echo "${LAST_ASK_HEADER}" | grep -qE "${next_expected}"; then
            echo "[steps] confirmed ${step_count} steps, reached '${LAST_ASK_HEADER}'"
            pass "${name_prefix}: step-by-step confirmation (${step_count} steps)"
            return 0
        elif echo "${LAST_ASK_HEADER}" | grep -qE "Step|步骤"; then
            step_count=$((step_count + 1))
            echo "[steps] confirming step ${step_count}: ${LAST_ASK_HEADER}"
            sleep 1
            select_option_by_text "Correct|正确"
        else
            echo "[steps] unexpected header '${LAST_ASK_HEADER}', auto-answering..."
            sleep 1
            select_option 1
        fi
    done
}

# wait_for_stop — Wait for Stop event (Claude finished processing)
#
# Args:
#   $1 — timeout in seconds (default: 60)
#
# Returns 0 if Stop detected, 1 if timeout.
wait_for_stop() {
    local timeout="${1:-60}"
    wait_for_event '"event":"Stop"' "${timeout}" "${BASH_SOURCE[1]##*/}:${BASH_LINENO[0]}"
}

# select_option — Navigate AskUserQuestion picker by index and confirm
#
# Args:
#   $1 — 1-based option index to select
#
# Sends Down arrow (n-1) times then Enter to choose the nth option.
select_option() {
    local n="$1"
    local i=1

    # Send Down arrow (n-1) times to reach the target option
    while [ "${i}" -lt "${n}" ]; do
        ${TMUX_CMD} send-keys -t "${TMUX_SESSION}" "Down" ""
        sleep 0.1
        i=$((i + 1))
    done

    # Confirm selection
    ${TMUX_CMD} send-keys -t "${TMUX_SESSION}" "" Enter
}

# select_option_by_text — Find option by label pattern and select it
#
# Args:
#   $1 — grep pattern to match option label (e.g., "Skip" or "No.*skip")
#
# Uses LAST_EVENT to extract option labels from AskUserQuestion payload.
# Falls back to select_option 1 if no match found.
select_option_by_text() {
    local pattern="$1"
    local labels
    labels=$(echo "${LAST_EVENT}" | jq -r '.payload.tool_input.questions[0].options[].label' 2>/dev/null)
    if [ -z "${labels}" ]; then
        echo "[select] WARNING: could not extract options from event, falling back to option 1"
        echo "[select]   raw event: ${LAST_EVENT:0:500}"
        select_option 1
        return
    fi
    local index=1
    while IFS= read -r label; do
        if echo "${label}" | grep -qiE "${pattern}"; then
            echo "[select] matched option ${index}: ${label}"
            select_option "${index}"
            return
        fi
        index=$((index + 1))
    done <<< "${labels}"
    echo "[select] WARNING: no option matching '${pattern}', falling back to option 1"
    echo "[select]   available options: [${labels}]"
    select_option 1
}

# select_option_smart — Select option with automatic multiSelect detection
#
# Args:
#   $1 — 1-based option index to select
#
# Checks LAST_EVENT for multiSelect flag. If multiSelect, uses Space to toggle
# the target option then Enter to submit. Otherwise, uses normal select_option.
select_option_smart() {
    local n="$1"
    if echo "${LAST_EVENT}" | grep -q '"multiSelect"[[:space:]]*:[[:space:]]*true'; then
        echo "[select] multiSelect detected, using Space+Enter"
        local i=1
        while [ "${i}" -lt "${n}" ]; do
            ${TMUX_CMD} send-keys -t "${TMUX_SESSION}" "Down" ""
            sleep 0.1
            i=$((i + 1))
        done
        ${TMUX_CMD} send-keys -t "${TMUX_SESSION}" Space
        sleep 0.3
        ${TMUX_CMD} send-keys -t "${TMUX_SESSION}" Tab
        sleep 0.3
        ${TMUX_CMD} send-keys -t "${TMUX_SESSION}" Enter
    else
        select_option "${n}"
    fi
}

# send_text — Type a free-text response for AskUserQuestion free-input mode
#
# Args:
#   $1 — text to type (followed by Enter)
send_text() {
    local text="$1"
    ${TMUX_CMD} send-keys -t "${TMUX_SESSION}" "${text}" Enter
}

# accept_write_permission — Accept .claude/ file write permission prompt
#
# Polls the tmux pane for "Do you want to create" prompt and sends Enter.
# Args:
#   $1 — timeout in seconds (default: 30)
accept_write_permission() {
    local timeout="${1:-30}"
    local start=$SECONDS
    local found=0
    while (( SECONDS - start < timeout )); do
        local pane
        pane="$(${TMUX_CMD} capture-pane -t "${TMUX_SESSION}" -p 2>/dev/null)"
        if echo "${pane}" | grep -qE "allow Claude to edit|Do you want to proceed|requested permissions"; then
            echo "[permission] detected write permission prompt, accepting..."
            sleep 1
            ${TMUX_CMD} send-keys -t "${TMUX_SESSION}" Enter
            found=1
            sleep 2
            continue
        fi
        if [ "${found}" -eq 1 ]; then
            echo "[permission] no more permission prompts"
            return 0
        fi
        sleep 1
    done
    if [ "${found}" -eq 0 ]; then
        echo "[permission] no write permission prompt detected within ${timeout}s (may not be needed)"
    fi
    return 0
}

# --- Assertions ---

# assert_file_exists — Assert that a file exists at the given path
#
# Args:
#   $1 — file path to check
#   $2 — human-readable test name
assert_file_exists() {
    local file_path="$1"
    local name="$2"

    if [ -f "${file_path}" ]; then
        pass "${name}"
    else
        echo "[assert] FAIL: file not found: ${file_path}"
        fail "${name}"
    fi
}

# assert_file_contains — Assert that a file contains a regex pattern
#
# Args:
#   $1 — file path
#   $2 — grep-compatible regex pattern
#   $3 — human-readable test name
assert_file_contains() {
    local file_path="$1"
    local pattern="$2"
    local name="$3"

    if [ ! -f "${file_path}" ]; then
        echo "[assert] FAIL: file not found: ${file_path}"
        fail "${name}"
        return
    fi

    if grep -qE "${pattern}" "${file_path}"; then
        pass "${name}"
    else
        echo "[assert] FAIL: pattern '${pattern}' not found in ${file_path}"
        echo "[assert] file contents:"
        cat "${file_path}"
        fail "${name}"
    fi
}

# assert_status_field — Assert a workflow STATUS.md field value via ca-status.js
#
# Args:
#   $1 — field name (e.g., "current_step")
#   $2 — expected value (string)
#   $3 — human-readable test name
#
# Reads the active workflow status using node scripts/ca-status.js read
assert_status_field() {
    local field="$1"
    local expected="$2"
    local name="$3"
    local project_dir="${TEST_DIR}/project"
    local status_script="${CA_REPO_ROOT}/scripts/ca-status.js"

    # Discover workflow ID from .ca/workflows/ directory (first workflow found)
    local wf_id
    wf_id="$(ls "${project_dir}/.ca/workflows/" 2>/dev/null | head -1)"
    if [ -z "${wf_id}" ]; then
        echo "[assert] FAIL: no workflows found in ${project_dir}/.ca/workflows/"
        fail "${name}"
        return
    fi
    local status_text
    status_text="$(node "${status_script}" read --project-root "${project_dir}" --workflow-id "${wf_id}" 2>/dev/null)"

    if [ $? -ne 0 ] || [ -z "${status_text}" ]; then
        echo "[assert] FAIL: could not read status for project: ${project_dir}"
        fail "${name}"
        return
    fi

    # Extract field value from text output (format: "field: value" or "- label: completed/not completed")
    local actual=""
    # Try direct "field: value" format first
    actual="$(echo "${status_text}" | grep -E "^${field}:" | head -1 | sed "s/^${field}:[[:space:]]*//" || true)"

    # If not found, check progress section for boolean fields (e.g., plan_completed → "- plan: completed")
    if [ -z "${actual}" ]; then
        local label="${field%_completed}"
        if [ "${label}" != "${field}" ]; then
            local progress_line
            progress_line="$(echo "${status_text}" | grep -E "^- ${label}:" | head -1 || true)"
            if [ -n "${progress_line}" ]; then
                if echo "${progress_line}" | grep -q "not completed"; then
                    actual="false"
                elif echo "${progress_line}" | grep -q "completed"; then
                    actual="true"
                fi
            fi
        fi
    fi

    if [ "${actual}" = "${expected}" ]; then
        pass "${name}"
    else
        echo "[assert] FAIL: status.${field} = '${actual}', expected '${expected}'"
        echo "[assert] full status: ${status_text}"
        fail "${name}"
    fi
}

# --- Result Recording ---

# pass — Record a PASS result
#
# Args:
#   $1 — test name
pass() {
    local name="$1"
    echo "PASS|${name}" >> "${RESULTS_FILE}"
    echo "  PASS  ${name}"
}

# fail — Record a FAIL result and abort the phase script (fail-fast)
#
# Args:
#   $1 — test name
fail() {
    local name="$1"
    echo "FAIL|${name}" >> "${RESULTS_FILE}"
    echo "  FAIL  ${name}"
    echo ""
    echo "  [fail-fast] Aborting phase on first failure."
    summarize_results || true
    exit 1
}

# --- Debugging ---

# pane_log — Capture and print current tmux pane content for debugging
#
# Args:
#   $1 — label string to prefix the log output
pane_log() {
    local label="${1:-debug}"
    echo "=== pane_log [${label}] ==="
    ${TMUX_CMD} capture-pane -t "${TMUX_SESSION}" -p -S - 2>/dev/null || echo "(no pane content)"
    echo "=== end pane_log ==="
}

# --- Summary ---

# summarize_results — Print PASS/FAIL summary and exit with fail count
#
# Reads RESULTS_FILE, counts PASS and FAIL entries, prints summary table,
# then returns the number of failures as exit code.
summarize_results() {
    local pass_count=0
    local fail_count=0
    local failed_names=()

    if [ ! -f "${RESULTS_FILE}" ]; then
        echo "[summary] No results file found."
        return 1
    fi

    while IFS='|' read -r status name; do
        if [ "${status}" = "PASS" ]; then
            pass_count=$((pass_count + 1))
        elif [ "${status}" = "FAIL" ]; then
            fail_count=$((fail_count + 1))
            failed_names+=("${name}")
        fi
    done < "${RESULTS_FILE}"

    local total=$((pass_count + fail_count))
    echo ""
    echo "================================"
    echo " Test Results: ${pass_count}/${total} passed"
    echo "================================"

    if [ ${fail_count} -gt 0 ]; then
        echo " Failed tests:"
        for name in "${failed_names[@]}"; do
            echo "   - ${name}"
        done
    fi

    echo "================================"
    echo ""

    return ${fail_count}
}
