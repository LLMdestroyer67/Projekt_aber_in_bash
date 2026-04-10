#!/usr/bin/env bash
# =============================================================================
# Test Suite: Device CRUD Operations
# Tests create, read, update, delete operations on device files
# =============================================================================

source "$(dirname "$0")/test_helpers.sh"
source "$(dirname "$0")/../experimental.sh"

# Setup test environment
setup_test_env "$(dirname "$0")"

test_section "Device File Creation"

# Test creating a device file manually
TEST_DEVICE="$TEST_DEVICE_DIR/TEST_DEVICE_001.txt"
mkdir -p "$TEST_DEVICE_DIR"
printf "Beschreibung=Test Device\nLocation=Lab\nStatus=active\n" > "$TEST_DEVICE"

assert_file_exists "$TEST_DEVICE" "Device file created successfully"

# Verify file contains expected content
assert_file_contains "$TEST_DEVICE" "Beschreibung=Test Device" "Device file contains description"
assert_file_contains "$TEST_DEVICE" "Location=Lab" "Device file contains location"
assert_file_contains "$TEST_DEVICE" "Status=active" "Device file contains status"

test_section "Device File Modification"

# Test replacing a field in device file (simulating _helper_change_rewrite_file logic)
TEST_FILE_MODIFY="$TEST_DEVICE_DIR/MODIFY_TEST.txt"
printf "Beschreibung=Old Value\nLocation=Warehouse\n" > "$TEST_FILE_MODIFY"

# Simulate field replacement with awk (same logic as _helper_change_rewrite_file)
awk -v p="Location=" -v newline="Location=UpdatedLoc" '
  BEGIN { done=0 }
  {
    if (substr($0, 1, length(p)) == p) {
      if (!done) { print newline; done=1 }
      next
    }
    print
  }
  END { if (!done) print newline }
' "$TEST_FILE_MODIFY" > "${TEST_FILE_MODIFY}.tmp" && \
mv "${TEST_FILE_MODIFY}.tmp" "$TEST_FILE_MODIFY"

assert_file_contains "$TEST_FILE_MODIFY" "Location=UpdatedLoc" "Field modification successful"

test_section "Device File Deletion"

# Test deleting device file
rm -f "$TEST_DEVICE"
assert_file_not_exists "$TEST_DEVICE" "Device file deleted successfully"

test_section "Device Count Field (Multi-type)"

# Test count field for collection devices
TEST_COLLECTION="$TEST_DEVICE_DIR/LAN_CABLE.txt"
printf "Beschreibung=Network Cables\nAnzahl=50\nLocation=Storage\n" > "$TEST_COLLECTION"

# Verify count field exists
assert_file_contains "$TEST_COLLECTION" "Anzahl=50" "Collection device has count field"

# Simulate incrementing count
awk -v p="Anzahl=" -v newline="Anzahl=51" '
  BEGIN { done=0 }
  {
    if (substr($0, 1, length(p)) == p) {
      if (!done) { print newline; done=1 }
      next
    }
    print
  }
  END { if (!done) print newline }
' "$TEST_COLLECTION" > "${TEST_COLLECTION}.tmp" && \
mv "${TEST_COLLECTION}.tmp" "$TEST_COLLECTION"

assert_file_contains "$TEST_COLLECTION" "Anzahl=51" "Count field incremented"

# Cleanup
cleanup_test_env

test_summary
