#!/usr/bin/env bash
# =============================================================================
# Test Suite: Device ID Validation (Phase 1.5 strict validation)
# =============================================================================

source "$(dirname "$0")/test_helpers.sh"
source "$(dirname "$0")/../experimental.sh"
setup_test_env
export LOG_DIR="$TEST_LOG_DIR"

assert_valid_id() {
  local id="$1"
  if _helper_validate_device_id_strict "$id"; then
    assert_equals 0 0 "Accepts device ID '$id'"
  else
    assert_equals 0 1 "Accepts device ID '$id'"
  fi
}

assert_invalid_id() {
  local id="$1"
  if _helper_validate_device_id_strict "$id"; then
    assert_equals 0 1 "Rejects device ID '$id'"
  else
    assert_equals 0 0 "Rejects device ID '$id'"
  fi
}

test_section "Device ID Validation (Strict)"

# Valid IDs should pass
assert_valid_id "123"
assert_valid_id "LAN_CABLE_20M"
assert_valid_id "server-prod-01"

test_section "Device ID Rejection Tests"

# Rejected IDs should fail
assert_invalid_id ""
assert_invalid_id "device/123"
assert_invalid_id "device 123"
assert_invalid_id 'device$123'
assert_invalid_id 'device`123'
assert_invalid_id 'device"123'
assert_invalid_id "device'123"

cleanup_test_env
test_summary
