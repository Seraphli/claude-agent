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
use_branches: false
auto_proceed_to_plan: false
auto_proceed_to_verify: false
CONFIG

    # Setup hook handler
    cp "${CA_REPO_ROOT}/tests/hook_handler.sh" "${TEST_DIR}/hook_handler.sh"
    chmod +x "${TEST_DIR}/hook_handler.sh"
    EVENT_LOG="${TEST_DIR}/events.log"
    touch "${EVENT_LOG}"

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
use_branches: false
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

# cleanup — Kill tmux session and remove temp directory
cleanup() {
    # Dump debug info before cleanup
    dump_debug "exit-cleanup"

    # Kill tmux session and server
    ${TMUX_CMD} kill-session -t "${TMUX_SESSION}" 2>/dev/null || true
    ${TMUX_CMD} kill-server 2>/dev/null || true
    sleep 2

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
        "cd '${project_dir}' && BROWSER=none CLAUDE_CONFIG_DIR='${TEST_CONFIG_DIR}/.claude' claude --model sonnet --dangerously-skip-permissions --setting-sources user"

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
    ${TMUX_CMD} send-keys -t "${TMUX_SESSION}" "${cmd}" Enter
}

# --- Interaction Helpers ---

# wait_for_event — Wait for a new event matching pattern in EVENT_LOG
#
# Args:
#   $1 — grep pattern to match
#   $2 — timeout in seconds (default: 300)
#
# Sets LAST_EVENT to the matching line.
# Returns 0 on match, 1 on timeout.
wait_for_event() {
    local pattern="$1"
    local timeout="${2:-300}"
    local start_lines
    start_lines=$(wc -l < "${EVENT_LOG}" 2>/dev/null || echo 0)
    local start=$SECONDS
    while (( SECONDS - start < timeout )); do
        sleep 1
        local current_lines
        current_lines=$(wc -l < "${EVENT_LOG}" 2>/dev/null || echo 0)
        if [ "${current_lines}" -gt "${start_lines}" ]; then
            local match
            match=$(tail -n +"$((start_lines + 1))" "${EVENT_LOG}" | grep -m1 "${pattern}" || true)
            if [ -n "${match}" ]; then
                LAST_EVENT="${match}"
                # Update start_lines to avoid re-matching
                EVENT_LINE_COUNT="${current_lines}"
                return 0
            fi
        fi
    done
    echo "TIMEOUT: wait_for_event pattern='${pattern}' exceeded ${timeout}s"
    return 1
}

# wait_for_ask — Wait for AskUserQuestion event and extract header into LAST_ASK_HEADER
#
# Args:
#   $1 — timeout in seconds (default: 300)
#
# Sets LAST_ASK_HEADER to the header value from the event.
# Returns 0 if AskUserQuestion received, 1 if timeout.
wait_for_ask() {
    local timeout="${1:-300}"
    if wait_for_event '"tool_name":"AskUserQuestion"' "${timeout}"; then
        LAST_ASK_HEADER=$(echo "${LAST_EVENT}" | grep -oP '"header"\s*:\s*"[^"]*"' | head -1 | sed 's/.*"header"\s*:\s*"\([^"]*\)".*/\1/')
        echo "[ask] received: ${LAST_ASK_HEADER}"
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
#   $3 — timeout in seconds (default: 300)
#
# If the received header doesn't match expected, selects option 1 and waits again.
# Retries up to 3 times before giving up.
wait_for_ask_expect() {
    local expected="$1"
    local fallback_answer="${2:-.*}"
    local timeout="${3:-300}"
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

# wait_for_step_confirmations — Handle step-by-step plan confirmation (Confirmation 2b)
#
# Loops waiting for "Step N" AskUserQuestion headers, auto-selecting "Correct" for each.
# Stops when it receives a header matching the next_expected pattern (e.g., "Results").
# Sets LAST_ASK_HEADER to the final matching header so callers can assert it directly.
#
# Args:
#   $1 — next expected header pattern after all steps (grep -E regex, e.g., "Results|结果")
#   $2 — test name prefix (e.g., "plan")
#   $3 — timeout per step in seconds (default: 300)
wait_for_step_confirmations() {
    local next_expected="$1"
    local name_prefix="$2"
    local timeout="${3:-300}"
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
#   $1 — timeout in seconds (default: 600)
#
# Returns 0 if Stop detected, 1 if timeout.
wait_for_stop() {
    local timeout="${1:-600}"
    wait_for_event '"event":"Stop"' "${timeout}"
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

    # Read status text for active workflow
    local status_text
    status_text="$(node "${status_script}" read --project-root "${project_dir}" 2>/dev/null)"

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

# fail — Record a FAIL result
#
# Args:
#   $1 — test name
fail() {
    local name="$1"
    echo "FAIL|${name}" >> "${RESULTS_FILE}"
    echo "  FAIL  ${name}"
}

# --- Debugging ---

# pane_log — Capture and print current tmux pane content for debugging
#
# Args:
#   $1 — label string to prefix the log output
pane_log() {
    local label="${1:-debug}"
    echo "=== pane_log [${label}] ==="
    ${TMUX_CMD} capture-pane -t "${TMUX_SESSION}" -p 2>/dev/null || echo "(no pane content)"
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
