#!/usr/bin/env bash
# =============================================================================
# Test Suite: Non-Interactive Mode Behavior
# Tests that functions handle closed stdin gracefully without hanging
# =============================================================================

source "$(dirname "$0")/test_helpers.sh"
source "$(dirname "$0")/../experimental.sh"

setup_test_env "$(dirname "$0")"
mkdir -p "$TEST_DEVICE_DIR"
export DEVICE_DIR="$TEST_DEVICE_DIR"
export LOG_DIR="$TEST_LOG_DIR"

test_section "Non-Interactive Mode: Timeout & Hang Prevention"

# Test 1: read_device_main without required argument (should error, not hang)
test_output=$(run_noninteractive "source experimental.sh; SCRIPT_NAME='test' read_device_main" 5 2>&1 || true)
[[ -n "$test_output" ]] && \
  echo -e "${GREEN}✓${NC} PASS: read_device_main non-interactive returns error (no hang)" || \
  echo -e "${RED}✗${NC} FAIL: read_device_main non-interactive produced no output"

# Test 2: create_device_main without argument (should error, not hang)
test_output=$(run_noninteractive "source experimental.sh; SCRIPT_NAME='test' create_device_main" 5 2>&1 || true)
[[ -n "$test_output" ]] && \
  echo -e "${GREEN}✓${NC} PASS: create_device_main non-interactive returns error (no hang)" || \
  echo -e "${RED}✗${NC} FAIL: create_device_main non-interactive produced no output"

# Test 3: change_device_main without arguments (should error, not hang)
test_output=$(run_noninteractive "source experimental.sh; SCRIPT_NAME='test' change_device_main" 5 2>&1 || true)
[[ -n "$test_output" ]] && \
  echo -e "${GREEN}✓${NC} PASS: change_device_main non-interactive returns error (no hang)" || \
  echo -e "${RED}✗${NC} FAIL: change_device_main non-interactive produced no output"

test_section "Non-Interactive Mode: Error Messages to Stderr"

# Test 4: Errors go to stderr, not stdout
result=$(run_noninteractive "source experimental.sh; SCRIPT_NAME='test' read_device_main 2>/dev/null" 5 || true)
[[ -z "$result" ]] && \
  echo -e "${GREEN}✓${NC} PASS: Error message captured on stderr (stdout empty)" || \
  echo -e "${RED}✗${NC} FAIL: Error message leaked to stdout"

test_section "Non-Interactive Mode: _is_interactive Returns Correct Value"

# Test 5: In piped context, _is_interactive should return non-zero (false)
test_rc=$(run_noninteractive "source experimental.sh; _is_interactive; echo \$?" 2 | tail -1 || true)
if [[ "$test_rc" != "0" ]]; then
  TEST_PASS=$((TEST_PASS + 1))
  echo -e "${GREEN}✓${NC} PASS: _is_interactive returns 1 when stdin is closed"
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo -e "${RED}✗${NC} FAIL: _is_interactive returned 0 in non-interactive context"
fi

# Test 6: In interactive context (direct terminal), _is_interactive returns 0
# (This is harder to test directly, so we just verify the function exists)
test_output=$(source experimental.sh; declare -f _is_interactive)
[[ -n "$test_output" ]] && \
  echo -e "${GREEN}✓${NC} PASS: _is_interactive function exists and is callable" || \
  echo -e "${RED}✗${NC} FAIL: _is_interactive not defined"

test_section "Non-Interactive Mode: Proper Exit Codes"

# Test 7: Missing argument in non-interactive should exit with 2 (usage error)
run_noninteractive "source experimental.sh; SCRIPT_NAME='test' read_device_main" 5 >/dev/null 2>&1
rc=$?
if [[ $rc -eq 2 ]]; then
  TEST_PASS=$((TEST_PASS + 1))
  echo -e "${GREEN}✓${NC} PASS: Missing argument returns exit code 2"
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo -e "${RED}✗${NC} FAIL: Missing argument returned exit code $rc (expected 2)"
fi

test_section "Non-Interactive Mode: Functions with All Args Work"

# Setup a device first
mkdir -p "$TEST_DEVICE_DIR"
printf "Beschreibung=Test Device\nLocation=Lab\nStatus=active\n" > "$TEST_DEVICE_DIR/TEST_001.txt"

# Test 8: read_device_main with all args should work non-interactively
SCRIPT_NAME="test" read_device_main "TEST_001"
rc=$?
[[ $rc -eq 0 ]] && \
  echo -e "${GREEN}✓${NC} PASS: read_device_main with args works non-interactively" || \
  echo -e "${RED}✗${NC} FAIL: read_device_main with args failed"

# Test 9: change_device_main with all args should work non-interactively
SCRIPT_NAME="test" change_device_main "TEST_001" "Status" "maintenance"
rc=$?
[[ $rc -eq 0 ]] && \
  echo -e "${GREEN}✓${NC} PASS: change_device_main with args works non-interactively" || \
  echo -e "${RED}✗${NC} FAIL: change_device_main with args failed"

cleanup_test_env
test_summary
