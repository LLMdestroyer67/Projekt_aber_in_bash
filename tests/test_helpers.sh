#!/usr/bin/env bash
# =============================================================================
# Test Helpers Library (Phase 2 - Bash Manual Testing Framework)
# 
# Provides assertion functions for testing Bash scripts without external deps.
# Usage: source this file, then call assert_* functions
# =============================================================================

set -euo pipefail

# Global test counters
TEST_PASS=0
TEST_FAIL=0
TEST_CURRENT=""

# Color codes for output (optional)
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# ============================================================================
# Core Assertion Functions
# ============================================================================

assert_equals() {
  local expected="$1"
  local actual="$2"
  local msg="${3:-}"
  
  if [[ "$expected" == "$actual" ]]; then
    TEST_PASS=$((TEST_PASS + 1))
    echo -e "${GREEN}✓${NC} PASS: $msg (expected='$expected')"
    return 0
  else
    TEST_FAIL=$((TEST_FAIL + 1))
    echo -e "${RED}✗${NC} FAIL: $msg"
    echo "  Expected: '$expected'"
    echo "  Actual:   '$actual'"
    return 1
  fi
}

assert_not_equals() {
  local not_expected="$1"
  local actual="$2"
  local msg="${3:-}"
  
  if [[ "$not_expected" != "$actual" ]]; then
    TEST_PASS=$((TEST_PASS + 1))
    echo -e "${GREEN}✓${NC} PASS: $msg (value != '$not_expected')"
    return 0
  else
    TEST_FAIL=$((TEST_FAIL + 1))
    echo -e "${RED}✗${NC} FAIL: $msg"
    echo "  Should not be: '$not_expected'"
    echo "  But got:       '$actual'"
    return 1
  fi
}

assert_rc() {
  local expected_rc="$1"
  local actual_rc="$2"
  local msg="${3:-}"
  
  if [[ "$expected_rc" == "$actual_rc" ]]; then
    TEST_PASS=$((TEST_PASS + 1))
    echo -e "${GREEN}✓${NC} PASS: $msg (exit code=$actual_rc)"
    return 0
  else
    TEST_FAIL=$((TEST_FAIL + 1))
    echo -e "${RED}✗${NC} FAIL: $msg"
    echo "  Expected exit code: $expected_rc"
    echo "  Actual exit code:   $actual_rc"
    return 1
  fi
}

assert_file_exists() {
  local filepath="$1"
  local msg="${2:-File should exist: $filepath}"
  
  if [[ -f "$filepath" ]]; then
    TEST_PASS=$((TEST_PASS + 1))
    echo -e "${GREEN}✓${NC} PASS: $msg"
    return 0
  else
    TEST_FAIL=$((TEST_FAIL + 1))
    echo -e "${RED}✗${NC} FAIL: $msg"
    return 1
  fi
}

assert_file_not_exists() {
  local filepath="$1"
  local msg="${2:-File should not exist: $filepath}"
  
  if [[ ! -f "$filepath" ]]; then
    TEST_PASS=$((TEST_PASS + 1))
    echo -e "${GREEN}✓${NC} PASS: $msg"
    return 0
  else
    TEST_FAIL=$((TEST_FAIL + 1))
    echo -e "${RED}✗${NC} FAIL: $msg"
    return 1
  fi
}

assert_file_contains() {
  local filepath="$1"
  local pattern="$2"
  local msg="${3:-File should contain: $pattern}"
  
  if [[ -f "$filepath" ]] && grep -q "$pattern" "$filepath"; then
    TEST_PASS=$((TEST_PASS + 1))
    echo -e "${GREEN}✓${NC} PASS: $msg"
    return 0
  else
    TEST_FAIL=$((TEST_FAIL + 1))
    echo -e "${RED}✗${NC} FAIL: $msg"
    return 1
  fi
}

assert_dir_exists() {
  local dirpath="$1"
  local msg="${2:-Directory should exist: $dirpath}"
  
  if [[ -d "$dirpath" ]]; then
    TEST_PASS=$((TEST_PASS + 1))
    echo -e "${GREEN}✓${NC} PASS: $msg"
    return 0
  else
    TEST_FAIL=$((TEST_FAIL + 1))
    echo -e "${RED}✗${NC} FAIL: $msg"
    return 1
  fi
}

assert_true() {
  local condition="$1"
  local msg="${2:-}"
  
  if eval "$condition"; then
    TEST_PASS=$((TEST_PASS + 1))
    echo -e "${GREEN}✓${NC} PASS: $msg"
    return 0
  else
    TEST_FAIL=$((TEST_FAIL + 1))
    echo -e "${RED}✗${NC} FAIL: $msg (condition: $condition)"
    return 1
  fi
}

assert_false() {
  local condition="$1"
  local msg="${2:-}"
  
  if ! eval "$condition"; then
    TEST_PASS=$((TEST_PASS + 1))
    echo -e "${GREEN}✓${NC} PASS: $msg"
    return 0
  else
    TEST_FAIL=$((TEST_FAIL + 1))
    echo -e "${RED}✗${NC} FAIL: $msg (condition should be false: $condition)"
    return 1
  fi
}

# ============================================================================
# Test Utilities
# ============================================================================

test_section() {
  local name="$1"
  echo ""
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${YELLOW}$name${NC}"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

test_summary() {
  echo ""
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo "TEST SUMMARY"
  echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "Passed: ${GREEN}$TEST_PASS${NC}"
  echo -e "Failed: ${RED}$TEST_FAIL${NC}"
  local total=$((TEST_PASS + TEST_FAIL))
  echo "Total:  $total"
  echo ""
  
  if [[ $TEST_FAIL -eq 0 ]]; then
    echo -e "${GREEN}✓ ALL TESTS PASSED${NC}"
    return 0
  else
    echo -e "${RED}✗ SOME TESTS FAILED${NC}"
    return 1
  fi
}

setup_test_env() {
  local test_dir="${1:-.}"
  export TEST_DIR="$test_dir"
  export TEST_DEVICE_DIR="$test_dir/test_devices"
  export TEST_LOG_DIR="$test_dir/test_logs"
  
  mkdir -p "$TEST_DEVICE_DIR" "$TEST_LOG_DIR"
}

cleanup_test_env() {
  [[ -d "$TEST_DEVICE_DIR" ]] && rm -rf "$TEST_DEVICE_DIR"
  [[ -d "$TEST_LOG_DIR" ]] && rm -rf "$TEST_LOG_DIR"
}

# ============================================================================
# Additional Assertion Functions (Phase 2+ enhancements)
# ============================================================================

assert_function_exists() {
  local func_name="$1"
  local msg="${2:-Function should exist: $func_name}"
  
  if declare -f "$func_name" >/dev/null 2>&1; then
    TEST_PASS=$((TEST_PASS + 1))
    echo -e "${GREEN}✓${NC} PASS: $msg"
    return 0
  else
    TEST_FAIL=$((TEST_FAIL + 1))
    echo -e "${RED}✗${NC} FAIL: $msg"
    return 1
  fi
}

assert_exit_code() {
  local expected_code="$1"
  local actual_code="$2"
  local msg="${3:-Exit code check}"
  
  if [[ "$expected_code" -eq "$actual_code" ]]; then
    TEST_PASS=$((TEST_PASS + 1))
    echo -e "${GREEN}✓${NC} PASS: $msg (exit=$actual_code)"
    return 0
  else
    TEST_FAIL=$((TEST_FAIL + 1))
    echo -e "${RED}✗${NC} FAIL: $msg"
    echo "  Expected exit code: $expected_code"
    echo "  Actual exit code:   $actual_code"
    return 1
  fi
}

assert_stderr_not_empty() {
  local stderr_content="$1"
  local msg="${2:-Stderr should not be empty}"
  
  if [[ -n "$stderr_content" ]]; then
    TEST_PASS=$((TEST_PASS + 1))
    echo -e "${GREEN}✓${NC} PASS: $msg"
    return 0
  else
    TEST_FAIL=$((TEST_FAIL + 1))
    echo -e "${RED}✗${NC} FAIL: $msg"
    return 1
  fi
}

assert_stdout_empty() {
  local stdout_content="$1"
  local msg="${2:-Stdout should be empty}"
  
  if [[ -z "$stdout_content" ]]; then
    TEST_PASS=$((TEST_PASS + 1))
    echo -e "${GREEN}✓${NC} PASS: $msg"
    return 0
  else
    TEST_FAIL=$((TEST_FAIL + 1))
    echo -e "${RED}✗${NC} FAIL: $msg"
    echo "  Got output: $stdout_content"
    return 1
  fi
}

# Helper for testing non-interactive functions with closed stdin
run_noninteractive() {
  local cmd="$1"
  local timeout_sec="${2:-5}"
  
  # Run command with stdin closed and capture output + exit code
  timeout "$timeout_sec" bash -c "$cmd" </dev/null 2>&1
  return $?
}

# Helper to verify device file has required fields
verify_device_file_valid() {
  local device_file="$1"
  local msg="${2:-Device file should be valid}"
  
  if [[ ! -f "$device_file" ]]; then
    TEST_FAIL=$((TEST_FAIL + 1))
    echo -e "${RED}✗${NC} FAIL: $msg (file not found)"
    return 1
  fi
  
  # Check for at least one required field
  if grep -q "^Beschreibung=" "$device_file"; then
    TEST_PASS=$((TEST_PASS + 1))
    echo -e "${GREEN}✓${NC} PASS: $msg"
    return 0
  else
    TEST_FAIL=$((TEST_FAIL + 1))
    echo -e "${RED}✗${NC} FAIL: $msg (missing Beschreibung field)"
    return 1
  fi
}
