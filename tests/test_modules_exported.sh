#!/usr/bin/env bash
# =============================================================================
# Test Suite: Module Export Verification
# Ensures all expected functions are available after sourcing experimental.sh
# =============================================================================

source "$(dirname "$0")/test_helpers.sh"
source "$(dirname "$0")/../experimental.sh"

setup_test_env "$(dirname "$0")"

test_section "Public Main Functions Available"

# All public *_main functions MUST be defined
assert_function_exists "create_device_main" "create_device_main exported"
assert_function_exists "read_device_main" "read_device_main exported"
assert_function_exists "change_device_main" "change_device_main exported"
assert_function_exists "find_device_main" "find_device_main exported"
assert_function_exists "find_and_change_main" "find_and_change_main exported"
assert_function_exists "change_count_main" "change_count_main exported"

test_section "Logging Functions Available"

assert_function_exists "setup_logging" "setup_logging exported"
assert_function_exists "log_debug" "log_debug exported"
assert_function_exists "log_info" "log_info exported"
assert_function_exists "log_warn" "log_warn exported"
assert_function_exists "log_error" "log_error exported"

test_section "I/O Functions Available"

assert_function_exists "read_logged" "read_logged exported"
assert_function_exists "echo_logged" "echo_logged exported"
assert_function_exists "error_logged" "error_logged exported"

test_section "Interactive Check Functions Available"

assert_function_exists "_is_interactive" "_is_interactive exported"
assert_function_exists "_helper_core_is_interactive" "_helper_core_is_interactive exported"

test_section "Validation Functions Available"

assert_function_exists "_helper_validate_device_id_strict" "_helper_validate_device_id_strict exported"

test_section "Field & Mode Helpers Available"

assert_function_exists "_helper_fields_build_prompt" "_helper_fields_build_prompt exported"
assert_function_exists "_helper_modes_build_prompt" "_helper_modes_build_prompt exported"
assert_function_exists "_helper_modes_normalize" "_helper_modes_normalize exported"

test_section "Device Operation Helpers Available"

assert_function_exists "_helper_change_rewrite_file" "_helper_change_rewrite_file exported"
assert_function_exists "_helper_change_device_count_from_id" "_helper_change_device_count_from_id exported"

test_section "Find & Search Helpers Available"

assert_function_exists "find_by_id" "find_by_id exported"
assert_function_exists "_find_by_key_contains" "_find_by_key_contains exported"

test_section "CLI Dispatch Available"

assert_function_exists "run_cli" "run_cli exported"

test_section "Global Variables & Arrays Defined"

# Check that field and mode definitions exist
if [[ -v single_fields ]]; then
  TEST_PASS=$((TEST_PASS + 1))
  echo -e "${GREEN}✓${NC} PASS: single_fields array defined"
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo -e "${RED}✗${NC} FAIL: single_fields array not defined"
fi

if [[ -v multi_fields ]]; then
  TEST_PASS=$((TEST_PASS + 1))
  echo -e "${GREEN}✓${NC} PASS: multi_fields array defined"
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo -e "${RED}✗${NC} FAIL: multi_fields array not defined"
fi

if [[ -v find_modes ]]; then
  TEST_PASS=$((TEST_PASS + 1))
  echo -e "${GREEN}✓${NC} PASS: find_modes array defined"
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo -e "${RED}✗${NC} FAIL: find_modes array not defined"
fi

test_section "Exit Code Constants Defined"

assert_true "[[ $EXIT_OK -eq 0 ]]" "EXIT_OK = 0"
assert_true "[[ $EXIT_ERROR -eq 1 ]]" "EXIT_ERROR = 1"
assert_true "[[ $EXIT_USAGE_ERROR -eq 2 ]]" "EXIT_USAGE_ERROR = 2"

cleanup_test_env
test_summary
