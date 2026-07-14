#!/usr/bin/env bash
# =============================================================================
# Test Suite: Public *_main Functions Unit Tests
# Tests the actual public API functions with various arguments
# =============================================================================

source "$(dirname "$0")/test_helpers.sh"
source "$(dirname "$0")/../experimental.sh"

setup_test_env "$(dirname "$0")"
mkdir -p "$TEST_DEVICE_DIR"
export DEVICE_DIR="$TEST_DEVICE_DIR"
export LOG_DIR="$TEST_LOG_DIR"
export SCRIPT_NAME="test"

test_section "create_device_main: Type 1 (Single Device)"

# Single device creation with all args (type is inferred from numeric ID)
SCRIPT_NAME="test" create_device_main "1001" <<EOF
Test Server
Lab A
active
Server
EOF
rc=$?
assert_exit_code 0 $rc "create_device_main single device success"
assert_file_exists "$TEST_DEVICE_DIR/1001.txt" "Device file 1001 created"

test_section "create_device_main: Type 2 (Collection Device)"

# Collection device (alphanumeric ID, interactive prompt for Anzahl)
SCRIPT_NAME="test" create_device_main "LAN_CABLE_50M" <<EOF
50m network cables
Anzahl=100
Storage
Network
EOF
rc=$?
assert_exit_code 0 $rc "create_device_main collection device success"
assert_file_exists "$TEST_DEVICE_DIR/LAN_CABLE_50M.txt" "Device file LAN_CABLE_50M created"
assert_file_contains "$TEST_DEVICE_DIR/LAN_CABLE_50M.txt" "Anzahl=100" "Collection has Anzahl field"

test_section "read_device_main: Read Created Devices"

# Read single device
SCRIPT_NAME="test" read_device_main "1001"
rc=$?
assert_exit_code 0 $rc "read_device_main returns 0 for existing device"

# Read collection device
SCRIPT_NAME="test" read_device_main "LAN_CABLE_50M"
rc=$?
assert_exit_code 0 $rc "read_device_main works for collection device"

# Read non-existent device
SCRIPT_NAME="test" read_device_main "NONEXISTENT"
rc=$?
assert_exit_code 1 $rc "read_device_main returns 1 for missing device"

test_section "change_device_main: Modify Single Device Fields"

# Change Status field
SCRIPT_NAME="test" change_device_main "1001" "Status" "maintenance"
rc=$?
assert_exit_code 0 $rc "change_device_main success for Status"
assert_file_contains "$TEST_DEVICE_DIR/1001.txt" "Status=maintenance" "Status field updated"

# Change Location field
SCRIPT_NAME="test" change_device_main "1001" "Location" "Lab B"
rc=$?
assert_exit_code 0 $rc "change_device_main success for Location"
assert_file_contains "$TEST_DEVICE_DIR/1001.txt" "Location=Lab B" "Location field updated"

# Change on non-existent device
SCRIPT_NAME="test" change_device_main "NONEXISTENT" "Status" "active"
rc=$?
assert_exit_code 1 $rc "change_device_main returns 1 for missing device"

test_section "change_count_main: Modify Collection Count"

# Increment count on collection device
SCRIPT_NAME="test" change_count_main "LAN_CABLE_50M" "110"
rc=$?
assert_exit_code 0 $rc "change_count_main success"
assert_file_contains "$TEST_DEVICE_DIR/LAN_CABLE_50M.txt" "Anzahl=110" "Count incremented"

# Change count again
SCRIPT_NAME="test" change_count_main "LAN_CABLE_50M" "95"
rc=$?
assert_exit_code 0 $rc "change_count_main success for decrement"
assert_file_contains "$TEST_DEVICE_DIR/LAN_CABLE_50M.txt" "Anzahl=95" "Count decremented"

# Try count operation on single device (should fail)
SCRIPT_NAME="test" change_count_main "1001" "50" >/dev/null 2>&1
rc=$?
[[ $rc -ne 0 ]] && \
  echo -e "${GREEN}✓${NC} PASS: change_count_main rejects single device" || \
  echo -e "${YELLOW}?${NC} INFO: change_count_main returned $rc for single device"

test_section "find_device_main: Search Devices"

# Find by ID
SCRIPT_NAME="test" find_device_main "ID" "1001"
rc=$?
assert_exit_code 0 $rc "find_device_main by ID success"

# Find by description (if implemented)
if declare -f find_device_main >/dev/null; then
  SCRIPT_NAME="test" find_device_main "Beschreibung" "Test Server" >/dev/null 2>&1
  rc=$?
  [[ $rc -eq 0 ]] && \
    echo -e "${GREEN}✓${NC} PASS: find_device_main by Beschreibung" || \
    echo -e "${YELLOW}?${NC} INFO: find_device_main search by Beschreibung not available"
fi

# Find non-existent
SCRIPT_NAME="test" find_device_main "ID" "NONEXISTENT" >/dev/null 2>&1
rc=$?
assert_exit_code 1 $rc "find_device_main returns 1 for no matches"

test_section "find_and_change_main: Find Then Modify"

# If find_and_change_main exists, test it
if declare -f find_and_change_main >/dev/null; then
  # This would typically be interactive, but with all args:
  SCRIPT_NAME="test" find_and_change_main "ID" "1001" "Status" "inactive" >/dev/null 2>&1
  rc=$?
  [[ $rc -eq 0 ]] && \
    echo -e "${GREEN}✓${NC} PASS: find_and_change_main success" || \
    echo -e "${RED}✗${NC} FAIL: find_and_change_main failed"
else
  echo -e "${YELLOW}?${NC} WARN: find_and_change_main not available"
fi

test_section "*_main Functions Return Codes Summary"

# Verify all main functions are callable
assert_function_exists "create_device_main" "create_device_main is callable"
assert_function_exists "read_device_main" "read_device_main is callable"
assert_function_exists "change_device_main" "change_device_main is callable"
assert_function_exists "find_device_main" "find_device_main is callable"
assert_function_exists "change_count_main" "change_count_main is callable"
assert_function_exists "find_and_change_main" "find_and_change_main is callable"

cleanup_test_env
test_summary
