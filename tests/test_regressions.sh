#!/usr/bin/env bash
# Regression coverage for the modular public mains used by runner.sh.

source "$(dirname "$0")/test_helpers.sh"
source "$(dirname "$0")/../experimental.sh"

setup_test_env "$(dirname "$0")"
export DEVICE_DIR="$TEST_DEVICE_DIR"
export LOG_DIR="$TEST_LOG_DIR"

printf 'Beschreibung=Numeric device\nLocation=Lab\nStatus=active\nKategorie=Server\n' \
  >"$DEVICE_DIR/900003.txt"
printf 'Beschreibung=Five metre cable\nAnzahl=10\nLocation=Stock\nKategorie=Cable\n' \
  >"$DEVICE_DIR/CABLE_5M.txt"

test_section "Regression: numeric single-device change"
if change_device_main "900003" "3" "maintenance"; then
  change_rc=0
else
  change_rc=$?
fi
assert_rc 0 "$change_rc" "Numeric device field change succeeds"
assert_file_contains "$DEVICE_DIR/900003.txt" "Status=maintenance" \
  "Numeric device status is updated"

test_section "Regression: find by ID"
if find_device_main "1" "900003"; then
  find_rc=0
else
  find_rc=$?
fi
assert_rc 0 "$find_rc" "Find by numeric mode and ID succeeds"
assert_equals "900003" "${FOUND_DEVICE_ID:-}" "Find by ID sets FOUND_DEVICE_ID"
assert_equals "1" "${FOUND_MATCH_COUNT:-0}" "Find by ID sets one match"

test_section "Regression: missing non-interactive search mode"
if change_count_main "missing"; then
  count_rc=0
else
  count_rc=$?
fi
assert_rc 2 "$count_rc" "Missing search mode returns usage error"
assert_equals "0" "${FOUND_MATCH_COUNT:-0}" \
  "Failed search leaves a safe zero match count"

cleanup_test_env
test_summary
