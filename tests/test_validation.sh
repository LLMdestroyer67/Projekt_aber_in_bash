#!/usr/bin/env bash
# =============================================================================
# Test Suite: Device ID Validation (Phase 1.5 strict validation)
# =============================================================================

source "$(dirname "$0")/test_helpers.sh"
source "$(dirname "$0")/../experimental.sh"

test_section "Device ID Validation (Strict)"

# Valid IDs should pass
_helper_validate_device_id_strict "123" && \
  echo "✓ Accepts numeric ID '123'" || \
  echo "✗ Should accept numeric ID"

_helper_validate_device_id_strict "LAN_CABLE_20M" && \
  echo "✓ Accepts alphanumeric ID 'LAN_CABLE_20M'" || \
  echo "✗ Should accept alphanumeric ID"

_helper_validate_device_id_strict "server-prod-01" && \
  echo "✓ Accepts hyphenated ID 'server-prod-01'" || \
  echo "✗ Should accept hyphenated ID"

test_section "Device ID Rejection Tests"

# Empty should fail
_helper_validate_device_id_strict "" && \
  echo "✗ Should reject empty ID" || \
  echo "✓ Correctly rejects empty ID"

# Slash should fail
_helper_validate_device_id_strict "device/123" && \
  echo "✗ Should reject ID with /" || \
  echo "✓ Correctly rejects ID with slash"

# Space should fail
_helper_validate_device_id_strict "device 123" && \
  echo "✗ Should reject ID with space" || \
  echo "✓ Correctly rejects ID with space"

# Dollar sign should fail
_helper_validate_device_id_strict "device\$123" && \
  echo "✗ Should reject ID with \$" || \
  echo "✓ Correctly rejects ID with dollar sign"

# Backtick should fail
_helper_validate_device_id_strict 'device`123' && \
  echo "✗ Should reject ID with backtick" || \
  echo "✓ Correctly rejects ID with backtick"

# Quote should fail
_helper_validate_device_id_strict 'device"123' && \
  echo "✗ Should reject ID with double quote" || \
  echo "✓ Correctly rejects ID with double quote"

# Single quote should fail
_helper_validate_device_id_strict "device'123" && \
  echo "✗ Should reject ID with single quote" || \
  echo "✓ Correctly rejects ID with single quote"

test_summary
