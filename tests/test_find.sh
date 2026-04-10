#!/usr/bin/env bash
# =============================================================================
# Test Suite: Device Search/Find Functionality
# Tests search by ID, description, location, and other fields
# =============================================================================

source "$(dirname "$0")/test_helpers.sh"
source "$(dirname "$0")/../experimental.sh"

# Setup test environment with sample devices
setup_test_env "$(dirname "$0")"

test_section "Device Search - Setup"

# Create test devices
mkdir -p "$TEST_DEVICE_DIR"

# Device 1: Numeric ID (single device)
printf "Beschreibung=Server Production\nLocation=DataCenter\nStatus=active\n" > "$TEST_DEVICE_DIR/1001.txt"
echo "✓ Created device 1001"

# Device 2: Numeric ID (single device)
printf "Beschreibung=Server Backup\nLocation=DataCenter\nStatus=inactive\n" > "$TEST_DEVICE_DIR/1002.txt"
echo "✓ Created device 1002"

# Device 3: String ID (collection)
printf "Beschreibung=Network Cables 20m\nAnzahl=45\nLocation=Storage\n" > "$TEST_DEVICE_DIR/LAN_CABLE_20M.txt"
echo "✓ Created device LAN_CABLE_20M"

test_section "Device ID Extraction"

# Test _helper_find_extract_id_from_file
ID=$(_helper_find_extract_id_from_file "$TEST_DEVICE_DIR/1001.txt")
assert_equals "1001" "$ID" "Extract device ID from file path"

ID=$(_helper_find_extract_id_from_file "$TEST_DEVICE_DIR/LAN_CABLE_20M.txt")
assert_equals "LAN_CABLE_20M" "$ID" "Extract collection device ID from file path"

test_section "Device File Matching"

# Test _helper_find_file_matches_key_value
_helper_find_file_matches_key_value "$TEST_DEVICE_DIR/1001.txt" "Location=" "DataCenter" && \
  echo "✓ Find matches device with correct location" || \
  echo "✗ Should match device with location DataCenter"

_helper_find_file_matches_key_value "$TEST_DEVICE_DIR/1001.txt" "Status=" "active" && \
  echo "✓ Find matches device with correct status" || \
  echo "✗ Should match device with status active"

_helper_find_file_matches_key_value "$TEST_DEVICE_DIR/1001.txt" "Status=" "inactive" && \
  echo "✗ Should not match wrong status" || \
  echo "✓ Correctly rejects wrong status value"

test_section "Collection Device Detection"

# Test _helper_change_device_count_from_id
COUNT=$(_helper_change_device_count_from_id "1001")
assert_equals "1" "$COUNT" "Numeric ID detected as single device (type 1)"

COUNT=$(_helper_change_device_count_from_id "LAN_CABLE_20M")
assert_equals "2" "$COUNT" "String ID detected as collection (type 2)"

# Cleanup
cleanup_test_env

test_summary
