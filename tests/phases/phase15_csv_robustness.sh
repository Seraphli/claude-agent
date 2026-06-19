#!/usr/bin/env bash
# phase15_csv_robustness.sh — E2E test for ca-csv.js CSV robustness
#
# TC14: CSV round-trip with special characters (comma, double-quote in description)
#       + sequential add-task/update calls and state verification.
# TC19: Enum validation for add-criterion (type/method/result), rejection of
#       invalid enum values and id-field update, absence of Chinese enum values.
#
# These tests invoke ca-csv.js directly (no Claude session needed).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export CA_REPO_ROOT="${CA_REPO_ROOT:-"$(cd "${SCRIPT_DIR}/../.." && pwd)"}"
export TEST_NAME="phase15-csv-robustness"
source "${CA_REPO_ROOT}/tests/e2e_common.sh"

setup_test_env
TEST_PROJECT="${TEST_DIR}/project"
trap 'cleanup' EXIT

# Resolve ca-csv.js path via installed location (install.js copies scripts there)
CSV_JS="${TEST_CONFIG_DIR}/.claude/ca/scripts/ca-csv.js"
TASKS_CSV="${TEST_DIR}/TASKS.csv"
VERIFY_CSV="${TEST_DIR}/VERIFY.csv"

echo "[phase15] TC14: CSV round-trip with special characters"

# Init TASKS.csv
node "${CSV_JS}" init-tasks --file "${TASKS_CSV}"
if [ -f "${TASKS_CSV}" ]; then
    pass "TC14: init-tasks creates file"
else
    fail "TC14: init-tasks creates file"
fi

# Add task with description containing a comma and a double-quote
DESC_WITH_SPECIAL='task with comma, and "double-quote" inside'
node "${CSV_JS}" add-task --file "${TASKS_CSV}" \
    --phase 1 \
    --title "special-chars" \
    --description "${DESC_WITH_SPECIAL}"

# Verify raw CSV has exactly header + 1 data row (2 lines total, ignoring trailing newline)
LINE_COUNT=$(grep -c "" "${TASKS_CSV}" || true)
# serializeCsv adds trailing newline → wc -l gives 2 lines for header+1row
if [ "${LINE_COUNT}" -ge 2 ]; then
    pass "TC14: TASKS.csv has header + 1 row"
else
    echo "[assert] FAIL: TASKS.csv line count=${LINE_COUNT}, expected >=2"
    echo "[assert] file contents:"
    cat "${TASKS_CSV}"
    fail "TC14: TASKS.csv has header + 1 row"
fi

# Verify the description round-trips intact via --json
ROUNDTRIP=$(node "${CSV_JS}" get --file "${TASKS_CSV}" --json 2>&1)
if echo "${ROUNDTRIP}" | EXPECTED_DESC="${DESC_WITH_SPECIAL}" node -e "
    const data = JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
    const desc = data[0] && data[0].description;
    const expected = process.env.EXPECTED_DESC;
    if (desc === expected) { process.exit(0); }
    process.stderr.write('got: ' + JSON.stringify(desc) + '\n');
    process.stderr.write('expected: ' + JSON.stringify(expected) + '\n');
    process.exit(1);
" 2>/dev/null; then
    pass "TC14: description round-trips intact (comma + double-quote)"
else
    echo "[assert] FAIL: round-trip mismatch"
    echo "${ROUNDTRIP}"
    fail "TC14: description round-trips intact (comma + double-quote)"
fi

# Sequential add-task and update calls (single-writer model)
node "${CSV_JS}" add-task --file "${TASKS_CSV}" --phase 1 --title "task-two"
node "${CSV_JS}" add-task --file "${TASKS_CSV}" --phase 2 --title "task-three"

# Update task 2 dev=done, task 3 git=skipped
node "${CSV_JS}" update --file "${TASKS_CSV}" --id 2 --field dev --value done
node "${CSV_JS}" update --file "${TASKS_CSV}" --id 3 --field git --value skipped

# Assert all three row states are correct
ROWS_JSON=$(node "${CSV_JS}" get --file "${TASKS_CSV}" --json)

ROW1_DEV=$(echo "${ROWS_JSON}" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')); process.stdout.write(d[0].dev);" 2>/dev/null)
ROW2_DEV=$(echo "${ROWS_JSON}" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')); process.stdout.write(d[1].dev);" 2>/dev/null)
ROW3_GIT=$(echo "${ROWS_JSON}" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')); process.stdout.write(d[2].git);" 2>/dev/null)

if [ "${ROW1_DEV}" = "pending" ]; then
    pass "TC14: row1 dev=pending (unchanged)"
else
    echo "[assert] FAIL: row1 dev='${ROW1_DEV}', expected 'pending'"
    fail "TC14: row1 dev=pending (unchanged)"
fi
if [ "${ROW2_DEV}" = "done" ]; then
    pass "TC14: row2 dev=done (updated)"
else
    echo "[assert] FAIL: row2 dev='${ROW2_DEV}', expected 'done'"
    fail "TC14: row2 dev=done (updated)"
fi
if [ "${ROW3_GIT}" = "skipped" ]; then
    pass "TC14: row3 git=skipped (updated)"
else
    echo "[assert] FAIL: row3 git='${ROW3_GIT}', expected 'skipped'"
    fail "TC14: row3 git=skipped (updated)"
fi

echo "[phase15] TC19: Enum validation for VERIFY.csv"

# Init VERIFY.csv
node "${CSV_JS}" init-verify --file "${VERIFY_CSV}"
if [ -f "${VERIFY_CSV}" ]; then
    pass "TC19: init-verify creates file"
else
    fail "TC19: init-verify creates file"
fi

# Add a valid criterion: type=self_check, method=auto
node "${CSV_JS}" add-criterion --file "${VERIFY_CSV}" \
    --type self_check \
    --method auto \
    --criterion "Check that output is correct"

# Assert stored fields are valid enum values
CRIT_JSON=$(node "${CSV_JS}" get --file "${VERIFY_CSV}" --json)

STORED_TYPE=$(echo "${CRIT_JSON}" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')); process.stdout.write(d[0].type);" 2>/dev/null)
STORED_METHOD=$(echo "${CRIT_JSON}" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')); process.stdout.write(d[0].method);" 2>/dev/null)
STORED_RESULT=$(echo "${CRIT_JSON}" | node -e "const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8')); process.stdout.write(d[0].result);" 2>/dev/null)

VALID_TYPES="self_check test"
VALID_METHODS="auto manual"
VALID_RESULTS="pass fail pending"

if echo "${VALID_TYPES}" | grep -qw "${STORED_TYPE}"; then
    pass "TC19: stored type '${STORED_TYPE}' is in {self_check,test}"
else
    echo "[assert] FAIL: stored type='${STORED_TYPE}'"
    fail "TC19: stored type '${STORED_TYPE}' is in {self_check,test}"
fi
if echo "${VALID_METHODS}" | grep -qw "${STORED_METHOD}"; then
    pass "TC19: stored method '${STORED_METHOD}' is in {auto,manual}"
else
    echo "[assert] FAIL: stored method='${STORED_METHOD}'"
    fail "TC19: stored method '${STORED_METHOD}' is in {auto,manual}"
fi
if echo "${VALID_RESULTS}" | grep -qw "${STORED_RESULT}"; then
    pass "TC19: stored result '${STORED_RESULT}' is in {pass,fail,pending}"
else
    echo "[assert] FAIL: stored result='${STORED_RESULT}'"
    fail "TC19: stored result '${STORED_RESULT}' is in {pass,fail,pending}"
fi

# Assert add-criterion --type 自查 is REJECTED (non-zero exit)
if node "${CSV_JS}" add-criterion --file "${VERIFY_CSV}" \
    --type 自查 \
    --method auto \
    --criterion "chinese type test" 2>/dev/null; then
    echo "[assert] FAIL: expected non-zero exit for --type 自查"
    fail "TC19: add-criterion --type 自查 is rejected (enum validation)"
else
    pass "TC19: add-criterion --type 自查 is rejected (enum validation)"
fi

# Assert update --field id is REJECTED (append-only)
if node "${CSV_JS}" update --file "${VERIFY_CSV}" \
    --id v1 \
    --field id \
    --value v99 2>/dev/null; then
    echo "[assert] FAIL: expected non-zero exit for update --field id"
    fail "TC19: update --field id is rejected (append-only)"
else
    pass "TC19: update --field id is rejected (append-only)"
fi

# Assert VERIFY.csv and TASKS.csv contain no Chinese structural enum values
CHINESE_ENUM_PATTERN="自查|测试|自动|手动|通过|失败|待定|挂起"

if grep -qP "${CHINESE_ENUM_PATTERN}" "${VERIFY_CSV}" 2>/dev/null; then
    echo "[assert] FAIL: VERIFY.csv contains Chinese enum values"
    cat "${VERIFY_CSV}"
    fail "TC19: VERIFY.csv has no Chinese structural enum values"
else
    pass "TC19: VERIFY.csv has no Chinese structural enum values"
fi

if grep -qP "${CHINESE_ENUM_PATTERN}" "${TASKS_CSV}" 2>/dev/null; then
    echo "[assert] FAIL: TASKS.csv contains Chinese enum values"
    cat "${TASKS_CSV}"
    fail "TC19: TASKS.csv has no Chinese structural enum values"
else
    pass "TC19: TASKS.csv has no Chinese structural enum values"
fi

summarize_results
