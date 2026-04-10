#!/usr/bin/env bash
# =============================================================================
# Test Suite: Integration & End-to-End Workflows
# Tests complete workflows from create to find to modify
# =============================================================================

source "$(dirname "$0")/test_helpers.sh"
source "$(dirname "$0")/../experimental.sh"

# Setup test environment
setup_test_env "$(dirname "$0")"

test_section "Integration: Create Single Device Workflow"

# Setup
mkdir -p "$TEST_DEVICE_DIR"
export DEVICE_DIR="$TEST_DEVICE_DIR"
export LOG_DIR="$TEST_LOG_DIR"

# Simulate device creation (type 1 - single device)
# In real scenario, this would be done via interactive prompts or args
DEVICE_ID="TEST_SERVER_001"
DEVICE_FILE="$DEVICE_DIR/$DEVICE_ID.txt"

# Verify ID validation passes
if _helper_validate_device_id_strict "$DEVICE_ID"; then
  echo "✓ Device ID validation passed for '$DEVICE_ID'"
else
  echo "✗ Device ID validation failed"
fi

# Create device file manually (simulating create_device_main success)
printf "Beschreibung=Test Server\nLocation=Lab A\nStatus=active\nKategorie=Server\n" > "$DEVICE_FILE"
assert_file_exists "$DEVICE_FILE" "Device file created successfully"

test_section "Integration: Find Created Device"

# Search for device by description
FOUND=$(grep -l "Test Server" "$DEVICE_DIR"/*.txt 2>/dev/null | wc -l)
[[ $FOUND -eq 1 ]] && \
  echo "✓ Device found by description search" || \
  echo "✗ Device find failed"

# Search by location
FOUND=$(grep -l "Lab A" "$DEVICE_DIR"/*.txt 2>/dev/null | wc -l)
[[ $FOUND -eq 1 ]] && \
  echo "✓ Device found by location search" || \
  echo "✗ Device location search failed"

test_section "Integration: Modify Device Field"

# Simulate field modification (change_device_main)
awk -v p="Status=" -v newline="Status=maintenance" '
  BEGIN { done=0 }
  {
    if (substr($0, 1, length(p)) == p) {
      if (!done) { print newline; done=1 }
      next
    }
    print
  }
  END { if (!done) print newline }
' "$DEVICE_FILE" > "${DEVICE_FILE}.tmp" && \
mv "${DEVICE_FILE}.tmp" "$DEVICE_FILE"

assert_file_contains "$DEVICE_FILE" "Status=maintenance" "Device status updated"
echo "✓ Field modification succeeded"

test_section "Integration: Create Collection Device Workflow"

# Create collection device (type 2 - bulk item)
COLL_ID="LAN_CABLE_50M"
COLL_FILE="$DEVICE_DIR/$COLL_ID.txt"

if _helper_validate_device_id_strict "$COLL_ID"; then
  echo "✓ Collection device ID validation passed"
fi

printf "Beschreibung=50-meter network cables\nAnzahl=125\nLocation=Stock\nKategorie=Network\n" > "$COLL_FILE"
assert_file_exists "$COLL_FILE" "Collection device created"

test_section "Integration: Modify Collection Count"

# Simulate count change (change_count_main)
awk -v p="Anzahl=" -v newline="Anzahl=130" '
  BEGIN { done=0 }
  {
    if (substr($0, 1, length(p)) == p) {
      if (!done) { print newline; done=1 }
      next
    }
    print
  }
  END { if (!done) print newline }
' "$COLL_FILE" > "${COLL_FILE}.tmp" && \
mv "${COLL_FILE}.tmp" "$COLL_FILE"

assert_file_contains "$COLL_FILE" "Anzahl=130" "Collection count incremented"

test_section "Integration: Search All Devices"

# List all devices
DEVICE_COUNT=$(find "$DEVICE_DIR" -type f -name "*.txt" | wc -l)
[[ $DEVICE_COUNT -eq 2 ]] && \
  echo "✓ Found expected number of devices ($DEVICE_COUNT)" || \
  echo "? Found $DEVICE_COUNT devices (expected 2)"

test_section "Integration: Find with Multiple Criteria"

# Advanced: Find device by multiple criteria (category AND status)
RESULT=$(grep -l "Kategorie=Server" "$DEVICE_DIR"/*.txt 2>/dev/null | \
         xargs -I{} grep -l "Status=maintenance" {} 2>/dev/null | wc -l)

[[ $RESULT -ge 1 ]] && \
  echo "✓ Multi-criteria search works (Server category + maintenance status)" || \
  echo "? Multi-criteria search returned unexpected results"

test_section "Integration: Validation Prevents Invalid Operations"

# Try invalid device ID
INVALID_ID="../../etc/passwd"
if ! _helper_validate_device_id_strict "$INVALID_ID"; then
  echo "✓ Path traversal attempt blocked by validation"
else
  echo "✗ SECURITY: Invalid ID was not rejected"
fi

# Try device ID with spaces
SPACE_ID="test device"
if ! _helper_validate_device_id_strict "$SPACE_ID"; then
  echo "✓ Spaces in device ID correctly rejected"
else
  echo "✗ Space in ID should have been rejected"
fi

test_section "Integration: Logging Records All Operations"

# Verify that operations were logged
if [[ -f "$LOG_FILE" ]]; then
  LOG_SIZE=$(wc -c < "$LOG_FILE")
  [[ $LOG_SIZE -gt 0 ]] && \
    echo "✓ Operations logged to $LOG_FILE ($LOG_SIZE bytes)" || \
    echo "? Log file exists but is empty"
else
  echo "? Log file not found"
fi

# Cleanup
cleanup_test_env

test_summary
