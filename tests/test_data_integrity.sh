#!/usr/bin/env bash
# =============================================================================
# Test Suite: Data Integrity & Edge Cases
# Tests behavior with malformed files, edge cases, and data corruption
# =============================================================================

source "$(dirname "$0")/test_helpers.sh"
source "$(dirname "$0")/../experimental.sh"

setup_test_env "$(dirname "$0")"
mkdir -p "$TEST_DEVICE_DIR"
export DEVICE_DIR="$TEST_DEVICE_DIR"
export LOG_DIR="$TEST_LOG_DIR"

test_section "Malformed Device Files"

# Test 1: Device file with missing required fields
MALFORMED_1="$TEST_DEVICE_DIR/MALFORMED_001.txt"
printf "Location=Lab\nStatus=active\n" > "$MALFORMED_1"
# read_device_main should still work (reads what's there)
SCRIPT_NAME="test" read_device_main "MALFORMED_001"
rc=$?
[[ $rc -eq 0 ]] && \
  echo -e "${GREEN}✓${NC} PASS: Device with missing Beschreibung still readable" || \
  echo -e "${RED}✗${NC} FAIL: Device with missing Beschreibung not readable"

# Test 2: Device file with duplicate field keys (last one wins)
MALFORMED_2="$TEST_DEVICE_DIR/MALFORMED_002.txt"
printf "Status=active\nStatus=maintenance\nLocation=Lab\n" > "$MALFORMED_2"
grep "^Status=" "$MALFORMED_2" | wc -l | grep -q "2" && \
  echo -e "${GREEN}✓${NC} PASS: Device file with duplicate keys created" || \
  echo -e "${RED}✗${NC} FAIL: Could not create duplicate key file"

# Test 3: Change operation on file with duplicate keys (should update first occurrence)
SCRIPT_NAME="test" change_device_main "MALFORMED_002" "Status" "inactive"
rc=$?
result=$(head -1 "$MALFORMED_2" | grep "^Status=" || true)
[[ "$result" == "Status=inactive" ]] && \
  echo -e "${GREEN}✓${NC} PASS: Change updates first occurrence of duplicate key" || \
  echo -e "${RED}✗${NC} FAIL: Change did not update correctly"

test_section "Edge Case: Empty Device Files"

# Test 4: Empty device file
EMPTY_FILE="$TEST_DEVICE_DIR/EMPTY.txt"
touch "$EMPTY_FILE"
SCRIPT_NAME="test" read_device_main "EMPTY" >/dev/null 2>&1
rc=$?
# Should handle gracefully (either succeed with no data or return error)
[[ $rc -eq 0 || $rc -eq 1 ]] && \
  echo -e "${GREEN}✓${NC} PASS: Empty device file handled gracefully (rc=$rc)" || \
  echo -e "${RED}✗${NC} FAIL: Empty device file caused error (rc=$rc)"

test_section "Edge Case: Device Files Without Newline at End"

# Test 5: Device file missing final newline
NO_NEWLINE="$TEST_DEVICE_DIR/NO_NEWLINE.txt"
printf "Beschreibung=No newline\nLocation=Lab" > "$NO_NEWLINE"  # No final \n
SCRIPT_NAME="test" read_device_main "NO_NEWLINE"
rc=$?
[[ $rc -eq 0 ]] && \
  echo -e "${GREEN}✓${NC} PASS: Device file without final newline handled" || \
  echo -e "${RED}✗${NC} FAIL: Device file without final newline not readable"

test_section "Edge Case: Device ID Length"

# Test 6: Very long device ID
LONG_ID=""
for ((i=0; i<50; i++)); do LONG_ID+="a"; done
echo "" | SCRIPT_NAME="test" create_device_main "$LONG_ID" \
  <<EOF 2>/dev/null
Long ID Device
Location
EOF
rc=$?
[[ $rc -eq 0 ]] && \
  echo -e "${GREEN}✓${NC} PASS: Very long device ID accepted" || \
  echo -e "${RED}✗${NC} FAIL: Very long device ID rejected"

# Test 7: Empty device ID (should be rejected)
echo "" | SCRIPT_NAME="test" create_device_main "" \
  <<EOF 2>/dev/null
Empty ID Device
Location
EOF
rc=$?
[[ $rc -ne 0 ]] && \
  echo -e "${GREEN}✓${NC} PASS: Empty device ID rejected (rc=$rc)" || \
  echo -e "${RED}✗${NC} FAIL: Empty device ID was accepted"

test_section "Edge Case: Device Field Values"

# Test 8: Very long field value
DEVICE_LONG_VALUE="$TEST_DEVICE_DIR/LONG_VALUE.txt"
LONG_VALUE=""
for ((i=0; i<500; i++)); do LONG_VALUE+="x"; done
printf "Beschreibung=%s\nLocation=Lab\n" "$LONG_VALUE" > "$DEVICE_LONG_VALUE"
SCRIPT_NAME="test" read_device_main "LONG_VALUE" >/dev/null 2>&1
rc=$?
[[ $rc -eq 0 ]] && \
  echo -e "${GREEN}✓${NC} PASS: Very long field value handled" || \
  echo -e "${RED}✗${NC} FAIL: Very long field value caused error"

# Test 9: Field value with special characters
SPECIAL_DEVICE="$TEST_DEVICE_DIR/SPECIAL.txt"
printf "Beschreibung=Device with \$pecial & chars (pipes|etc)\nLocation=Lab\n" > "$SPECIAL_DEVICE"
SCRIPT_NAME="test" read_device_main "SPECIAL" >/dev/null 2>&1
rc=$?
[[ $rc -eq 0 ]] && \
  echo -e "${GREEN}✓${NC} PASS: Field value with special chars handled" || \
  echo -e "${RED}✗${NC} FAIL: Field value with special chars caused error"

test_section "Edge Case: Count Operations on Single Devices"

# Test 10: Try to increment count on single device (should fail or skip)
SINGLE_DEVICE="$TEST_DEVICE_DIR/SINGLE_TYPE.txt"
printf "Beschreibung=Single Device\nLocation=Lab\nStatus=active\n" > "$SINGLE_DEVICE"
SCRIPT_NAME="test" change_count_main "SINGLE_TYPE" "100" >/dev/null 2>&1
rc=$?
# Should fail or error (type 1 devices don't have Anzahl)
[[ $rc -ne 0 ]] && \
  echo -e "${GREEN}✓${NC} PASS: Count operation on single device rejected" || \
  echo -e "${YELLOW}?${NC} WARN: Count operation on single device returned 0"

test_section "Field Replacement: Edge Cases"

# Test 11: Replace field that doesn't exist (should be added)
NO_EXIST="$TEST_DEVICE_DIR/NO_STATUS.txt"
printf "Beschreibung=No Status\nLocation=Lab\n" > "$NO_EXIST"
SCRIPT_NAME="test" change_device_main "NO_STATUS" "Status" "active"
rc=$?
grep -q "^Status=active" "$NO_EXIST" && \
  echo -e "${GREEN}✓${NC} PASS: Non-existent field is added on change" || \
  echo -e "${RED}✗${NC} FAIL: Non-existent field was not added"

cleanup_test_env
test_summary
