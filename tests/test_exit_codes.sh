#!/usr/bin/env bash
# =============================================================================
# Test Suite: Exit Code Verification
# Tests that all operations return correct exit codes (0, 1, 2)
# =============================================================================

source "$(dirname "$0")/test_helpers.sh"
source "$(dirname "$0")/../experimental.sh"

setup_test_env "$(dirname "$0")"
mkdir -p "$TEST_DEVICE_DIR"
export DEVICE_DIR="$TEST_DEVICE_DIR"
export LOG_DIR="$TEST_LOG_DIR"

test_section "create_device_main: Exit Code Tests"

# Test 1: Success case
DEVICE_ID="TEST_SINGLE_001"
echo "" | SCRIPT_NAME="test" create_device_main "$DEVICE_ID" \
  <<EOF
Test Description
Test Location
active
EOF
rc=$?
assert_exit_code 0 $rc "create_device_main success returns 0"

# Test 2: Duplicate device error
echo "" | SCRIPT_NAME="test" create_device_main "$DEVICE_ID" \
  <<EOF
Another Description
Location2
EOF
rc=$?
assert_exit_code 1 $rc "create_device_main duplicate returns 1"

# Test 3: Invalid device ID (with /)
echo "" | SCRIPT_NAME="test" create_device_main "../../etc/passwd" \
  <<EOF
Bad
EOF
rc=$?
assert_exit_code 2 $rc "create_device_main invalid ID returns 2"

test_section "read_device_main: Exit Code Tests"

# Test 1: Success
SCRIPT_NAME="test" read_device_main "$DEVICE_ID"
rc=$?
assert_exit_code 0 $rc "read_device_main success returns 0"

# Test 2: Not found
SCRIPT_NAME="test" read_device_main "NONEXISTENT_DEVICE"
rc=$?
assert_exit_code 1 $rc "read_device_main not found returns 1"

# Test 3: Missing argument (non-interactive)
SCRIPT_NAME="test" read_device_main </dev/null
rc=$?
assert_exit_code 2 $rc "read_device_main missing arg returns 2"

test_section "change_device_main: Exit Code Tests"

# Create another test device for change operations
DEVICE_ID2="TEST_SINGLE_002"
echo "" | SCRIPT_NAME="test" create_device_main "$DEVICE_ID2" \
  <<EOF
Description for Device 2
Location 2
active
Server
EOF

# Test 1: Success
SCRIPT_NAME="test" change_device_main "$DEVICE_ID2" "Status" "maintenance"
rc=$?
assert_exit_code 0 $rc "change_device_main success returns 0"

# Test 2: Device not found
SCRIPT_NAME="test" change_device_main "NONEXISTENT" "Status" "active"
rc=$?
assert_exit_code 1 $rc "change_device_main device not found returns 1"

# Test 3: Missing device ID (non-interactive)
SCRIPT_NAME="test" change_device_main </dev/null
rc=$?
assert_exit_code 2 $rc "change_device_main missing device ID returns 2"

test_section "Collection Device: change_count_main Tests"

# Create a collection device
COLL_ID="LAN_CABLES_50M"
echo "" | SCRIPT_NAME="test" create_device_main "$COLL_ID" \
  <<EOF
50-meter network cables
Anzahl=100
Storage
EOF

# Test 1: Increment count (success)
SCRIPT_NAME="test" change_count_main "$COLL_ID" "110"
rc=$?
assert_exit_code 0 $rc "change_count_main success returns 0"

# Test 2: Collection device not found
SCRIPT_NAME="test" change_count_main "NONEXISTENT_COLL" "50"
rc=$?
assert_exit_code 1 $rc "change_count_main device not found returns 1"

# Test 3: Missing device ID (non-interactive)
SCRIPT_NAME="test" change_count_main </dev/null
rc=$?
assert_exit_code 2 $rc "change_count_main missing device ID returns 2"

test_section "find_device_main: Exit Code Tests"

# Test 1: Find by ID success
SCRIPT_NAME="test" find_device_main "ID" "$DEVICE_ID"
rc=$?
assert_exit_code 0 $rc "find_device_main ID success returns 0"

# Test 2: Find not found
SCRIPT_NAME="test" find_device_main "ID" "NONEXISTENT"
rc=$?
assert_exit_code 1 $rc "find_device_main not found returns 1"

# Test 3: Missing search mode (non-interactive)
SCRIPT_NAME="test" find_device_main </dev/null
rc=$?
assert_exit_code 2 $rc "find_device_main missing mode returns 2"

cleanup_test_env
test_summary
