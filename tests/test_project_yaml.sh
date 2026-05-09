#!/bin/bash
# test_project_yaml.sh — Script-level tests for project.yaml parsing in ca-config.js

set -euo pipefail

CA_REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PASS=0
FAIL=0

pass() { echo "  PASS  $1"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL  $1"; FAIL=$((FAIL + 1)); }

echo "=== Script-level tests: project.yaml ==="

# Test 1: No project.yaml — backward compatible
TEST_DIR=$(mktemp -d /tmp/ca-test-XXXXXX)
mkdir -p "${TEST_DIR}/.ca"
cat > "${TEST_DIR}/.ca/config.md" << 'EOF'
interaction_language: English
comment_language: English
code_language: English
EOF
OUTPUT=$(node "${CA_REPO_ROOT}/scripts/ca-config.js" --project-root "${TEST_DIR}" 2>/dev/null)
if echo "${OUTPUT}" | grep -q "## Project"; then
  fail "no-project-yaml: should not contain ## Project"
else
  pass "no-project-yaml: backward compatible"
fi
rm -rf "${TEST_DIR}"

# Test 2: Valid project.yaml — correct parsing
TEST_DIR=$(mktemp -d /tmp/ca-test-XXXXXX)
mkdir -p "${TEST_DIR}/.ca"
cat > "${TEST_DIR}/.ca/config.md" << 'EOF'
interaction_language: English
comment_language: English
code_language: English
EOF
cat > "${TEST_DIR}/.ca/project.yaml" << 'EOF'
project_name: test-project
description: A test project
dirs:
  - label: code
    path: /tmp/test-code
  - label: docs
    path: /tmp/test-docs
rules:
  - /tmp/test-code/CLAUDE.md
EOF
OUTPUT=$(node "${CA_REPO_ROOT}/scripts/ca-config.js" --project-root "${TEST_DIR}" 2>/dev/null)
if echo "${OUTPUT}" | grep -q "## Project"; then
  pass "valid-yaml: has ## Project section"
else
  fail "valid-yaml: missing ## Project section"
fi
if echo "${OUTPUT}" | grep -q "project_name: test-project"; then
  pass "valid-yaml: has project_name"
else
  fail "valid-yaml: missing project_name"
fi
if echo "${OUTPUT}" | grep -q "description: A test project"; then
  pass "valid-yaml: has description"
else
  fail "valid-yaml: missing description"
fi
if echo "${OUTPUT}" | grep -q "label: code, path: /tmp/test-code"; then
  pass "valid-yaml: has dirs entry"
else
  fail "valid-yaml: missing dirs entry"
fi
if echo "${OUTPUT}" | grep -q "/tmp/test-code/CLAUDE.md"; then
  pass "valid-yaml: has rules entry"
else
  fail "valid-yaml: missing rules entry"
fi
rm -rf "${TEST_DIR}"

# Test 3: Invalid YAML — warning on stderr
TEST_DIR=$(mktemp -d /tmp/ca-test-XXXXXX)
mkdir -p "${TEST_DIR}/.ca"
cat > "${TEST_DIR}/.ca/config.md" << 'EOF'
interaction_language: English
comment_language: English
code_language: English
EOF
echo "invalid: yaml: [broken" > "${TEST_DIR}/.ca/project.yaml"
STDERR=$(node "${CA_REPO_ROOT}/scripts/ca-config.js" --project-root "${TEST_DIR}" 2>&1 1>/dev/null || true)
if echo "${STDERR}" | grep -qi "warning\|error\|fail"; then
  pass "invalid-yaml: produces warning/error"
else
  fail "invalid-yaml: no warning/error on stderr"
fi
rm -rf "${TEST_DIR}"

# Summary
TOTAL=$((PASS + FAIL))
echo ""
echo "================================"
echo " Test Results: ${PASS}/${TOTAL} passed"
echo "================================"
exit ${FAIL}
