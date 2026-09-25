#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/test_helpers.sh"
source "$(dirname "$0")/../experimental.sh"

setup_test_env
export DEVICE_DIR="$TEST_DEVICE_DIR"
export LOG_DIR="$TEST_LOG_DIR"
export DEVICE_LOCK_TIMEOUT_SECONDS=0

printf 'Beschreibung=CLI device\nLocation=Lab\nStatus=active\nKategorie=Server\n' \
  >"$DEVICE_DIR/700001.txt"

test_section "CLI dispatcher"

read_output="$(run_cli read 700001)"
assert_true '[[ "$read_output" == *"Beschreibung=CLI device"* ]]' \
  "run_cli read dispatches to read_device_main"

if run_cli change 700001 Status maintenance >/dev/null 2>&1; then
  change_rc=0
else
  change_rc=$?
fi
assert_rc 0 "$change_rc" "run_cli change dispatches successfully"
assert_file_contains "$DEVICE_DIR/700001.txt" "Status=maintenance" \
  "run_cli change updates the device"

find_output="$(run_cli find id 700001)"
assert_true '[[ "$find_output" == *"700001"* ]]' \
  "run_cli find dispatches to find_device_main"

runner_output="$(DEVICE_DIR="$DEVICE_DIR" LOG_DIR="$LOG_DIR" \
  bash "$(dirname "$0")/../runner.sh" read 700001)"
assert_true '[[ "$runner_output" == *"Beschreibung=CLI device"* ]]' \
  "runner.sh dispatches explicit commands"

if run_cli does-not-exist >/dev/null 2>&1; then
  unknown_rc=0
else
  unknown_rc=$?
fi
assert_rc 2 "$unknown_rc" "Unknown CLI command returns usage error"

test_section "Device write lock"

lock_dir="$DEVICE_DIR.lock"
mkdir -- "$lock_dir"
if _helper_change_rewrite_file "$DEVICE_DIR/700001.txt" "Status=" "Status=blocked"; then
  lock_rc=0
else
  lock_rc=$?
fi
assert_rc 1 "$lock_rc" "Write fails while another process holds the lock"
assert_file_contains "$DEVICE_DIR/700001.txt" "Status=maintenance" \
  "Locked write leaves the device unchanged"
rmdir -- "$lock_dir"

cleanup_test_env
test_summary
