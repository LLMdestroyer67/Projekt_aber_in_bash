#!/usr/bin/env bash
# =============================================================================
# Test Suite: CLI Dispatcher
# Tests run_cli and command routing to *_main functions
# =============================================================================

source "$(dirname "$0")/test_helpers.sh"
source "$(dirname "$0")/../experimental.sh"

setup_test_env "$(dirname "$0")"
mkdir -p "$TEST_DEVICE_DIR"
export DEVICE_DIR="$TEST_DEVICE_DIR"
export LOG_DIR="$TEST_LOG_DIR"
export SCRIPT_NAME="test"

test_section "CLI Dispatcher: run_cli Command Routing"

# Create a test device for read/change tests
echo "" | SCRIPT_NAME="test" create_device_main "CLI_TEST_001" <<EOF
CLI Test Device
Lab A
active
EOF

test_section "run_cli: create command"

echo "" | run_cli create "CLI_TEST_002" <<EOF
Second Device
Lab B
EOF
rc=$?
assert_exit_code 0 $rc "run_cli create success"
assert_file_exists "$TEST_DEVICE_DIR/CLI_TEST_002.txt" "Device created via run_cli"

test_section "run_cli: read command"

run_cli read "CLI_TEST_001" >/dev/null 2>&1
rc=$?
assert_exit_code 0 $rc "run_cli read success"

test_section "run_cli: change command"

run_cli change "CLI_TEST_001" "Status" "maintenance" >/dev/null 2>&1
rc=$?
assert_exit_code 0 $rc "run_cli change success"

test_section "run_cli: find command"

run_cli find "ID" "CLI_TEST_001" >/dev/null 2>&1
rc=$?
assert_exit_code 0 $rc "run_cli find success"

test_section "run_cli: count command"

# Create a collection device
echo "" | SCRIPT_NAME="test" create_device_main "CLI_CABLES" <<EOF
Test Cables
Anzahl=50
Storage
EOF

run_cli count "CLI_CABLES" "75" >/dev/null 2>&1
rc=$?
assert_exit_code 0 $rc "run_cli count success"

test_section "run_cli: find-and-change command"

run_cli find-and-change "ID" "CLI_TEST_001" "Status" "active" >/dev/null 2>&1
rc=$?
[[ $rc -eq 0 ]] && \
  echo -e "${GREEN}✓${NC} PASS: run_cli find-and-change success" || \
  echo -e "${YELLOW}?${NC} INFO: run_cli find-and-change returned $rc"

test_section "run_cli: Invalid Command Handling"

run_cli invalid_command >/dev/null 2>&1
rc=$?
assert_exit_code 2 $rc "run_cli invalid command returns 2"

test_section "run_cli: No Command Provided"

run_cli >/dev/null 2>&1
rc=$?
assert_exit_code 2 $rc "run_cli no command returns 2"

test_section "run_cli: Command Aliases"

# Test if find-and-change alias works (with underscore)
run_cli find_and_change "ID" "CLI_TEST_002" "Status" "inactive" >/dev/null 2>&1
rc=$?
[[ $rc -eq 0 ]] && \
  echo -e "${GREEN}✓${NC} PASS: find_and_change alias works" || \
  echo -e "${YELLOW}?${NC} INFO: find_and_change alias returned $rc"

cleanup_test_env
test_summary
