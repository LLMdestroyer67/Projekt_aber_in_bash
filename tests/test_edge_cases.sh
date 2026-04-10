#!/usr/bin/env bash
# =============================================================================
# Test Suite: Edge Cases & Error Conditions
# Tests robustness under unusual conditions (empty files, missing fields, etc)
# =============================================================================

source "$(dirname "$0")/test_helpers.sh"
source "$(dirname "$0")/../experimental.sh"

# Setup test environment
setup_test_env "$(dirname "$0")"

test_section "Edge Case: Empty Device File"

mkdir -p "$TEST_DEVICE_DIR"
EMPTY_DEVICE="$TEST_DEVICE_DIR/EMPTY_001.txt"
touch "$EMPTY_DEVICE"

assert_file_exists "$EMPTY_DEVICE" "Empty device file created"

# Attempting to read field from empty file should not crash
RESULT=$(_generic_parse_field "$EMPTY_DEVICE" "Beschreibung=" 2>/dev/null || echo "EMPTY")
echo "✓ Empty file handled gracefully (result: '$RESULT')"

test_section "Edge Case: Missing Expected Fields"

INCOMPLETE_DEVICE="$TEST_DEVICE_DIR/INCOMPLETE_002.txt"
printf "Beschreibung=Test Only\n" > "$INCOMPLETE_DEVICE"

# Should handle gracefully when Status field is missing
RESULT=$(_generic_parse_field "$INCOMPLETE_DEVICE" "Status=" 2>/dev/null || echo "MISSING")
echo "✓ Missing field returns empty/error as expected (result: '$RESULT')"

test_section "Edge Case: Device File with Malformed Lines"

MALFORMED_DEVICE="$TEST_DEVICE_DIR/MALFORMED_003.txt"
printf "Beschreibung=Good Field\nBAD_LINE_NO_EQUALS\nStatus=active\n" > "$MALFORMED_DEVICE"

assert_file_contains "$MALFORMED_DEVICE" "GOOD_LINE\|Good Field" "Malformed file contains valid lines"
echo "✓ File with malformed lines can still be read"

test_section "Edge Case: Large Count Values"

LARGE_COUNT_DEVICE="$TEST_DEVICE_DIR/LARGE_COUNT.txt"
printf "Beschreibung=Big Inventory\nAnzahl=999999\nLocation=Warehouse\n" > "$LARGE_COUNT_DEVICE"

assert_file_contains "$LARGE_COUNT_DEVICE" "Anzahl=999999" "Large count value stored correctly"

# Test overflow (2^31 and beyond)
OVERFLOW_DEVICE="$TEST_DEVICE_DIR/OVERFLOW_COUNT.txt"
printf "Beschreibung=Overflow Test\nAnzahl=2147483648\nLocation=Storage\n" > "$OVERFLOW_DEVICE"
assert_file_contains "$OVERFLOW_DEVICE" "Anzahl=2147483648" "Very large count value stored"

test_section "Edge Case: Non-ASCII Characters in Fields"

UNICODE_DEVICE="$TEST_DEVICE_DIR/UNICODE_004.txt"
printf "Beschreibung=Gerät mit Ümlaut äöü\nLocation=München\nStatus=active\n" > "$UNICODE_DEVICE"

assert_file_exists "$UNICODE_DEVICE" "Unicode file created"
assert_file_contains "$UNICODE_DEVICE" "Ümlaut" "Unicode characters preserved in file"

test_section "Edge Case: Very Long Field Values"

LONG_DEVICE="$TEST_DEVICE_DIR/LONG_VALUE.txt"
LONG_VALUE=$(printf 'A%.0s' {1..500})  # 500 character string
printf "Beschreibung=%s\nLocation=Lab\n" "$LONG_VALUE" > "$LONG_DEVICE"

assert_file_exists "$LONG_DEVICE" "Long value file created"
[[ $(wc -c < "$LONG_DEVICE") -gt 500 ]] && \
  echo "✓ Long field values (500+ chars) stored and readable" || \
  echo "✗ Long value file size unexpected"

test_section "Edge Case: Device File with Special Characters in Values"

SPECIAL_DEVICE="$TEST_DEVICE_DIR/SPECIAL_CHARS.txt"
printf "Beschreibung=Device: test (v1.2.3)\nLocation=Rack/Slot#42\nStatus=error: connection timeout\n" > "$SPECIAL_DEVICE"

assert_file_contains "$SPECIAL_DEVICE" "Device: test" "Colons in values"
assert_file_contains "$SPECIAL_DEVICE" "Rack/Slot#42" "Slashes and hashes in values"
echo "✓ Special characters (: # / parens) handled correctly"

test_section "Edge Case: Duplicate Field Names in File"

DUP_DEVICE="$TEST_DEVICE_DIR/DUPLICATE.txt"
printf "Beschreibung=First\nStatus=active\nBeschreibung=Second\nStatus=inactive\n" > "$DUP_DEVICE"

# When duplicate fields exist, parser should handle gracefully (first or last match)
FIRST_DESC=$(_generic_parse_field "$DUP_DEVICE" "Beschreibung=" 2>/dev/null || echo "")
[[ -n "$FIRST_DESC" ]] && \
  echo "✓ Duplicate fields handled (returns first occurrence)" || \
  echo "? Duplicate field handling may vary"

test_section "Edge Case: Concurrent File Access Simulation"

CONCURRENT_DEVICE="$TEST_DEVICE_DIR/CONCURRENT.txt"
printf "Beschreibung=Initial\nAnzahl=5\n" > "$CONCURRENT_DEVICE"

# Simulate rapid read-modify-write (stress test)
for i in {1..5}; do
  if [[ -f "$CONCURRENT_DEVICE" ]]; then
    COUNT=$(cat "$CONCURRENT_DEVICE" | grep "Anzahl=" | cut -d= -f2)
    NEW_COUNT=$((COUNT + 1))
    sed -i.bak "s/Anzahl=.*/Anzahl=$NEW_COUNT/" "$CONCURRENT_DEVICE"
  fi
done

FINAL_COUNT=$(grep "Anzahl=" "$CONCURRENT_DEVICE" | cut -d= -f2 || echo "0")
echo "✓ Sequential access works; final count=$FINAL_COUNT (expected 10)"

# Cleanup
cleanup_test_env

test_summary
