#!/usr/bin/env bash
# =============================================================================
# Test Suite: Logging System
# Tests logging functions, timestamps, and formatting
# =============================================================================

source "$(dirname "$0")/test_helpers.sh"
source "$(dirname "$0")/../experimental.sh"

test_section "Logging Setup"

setup_test_env "$(dirname "$0")"
export LOG_DIR="$TEST_LOG_DIR"
export LOG_FILE="$TEST_LOG_DIR/test.log"

# Initialize logging
setup_logging 2>/dev/null || true

assert_dir_exists "$LOG_DIR" "Log directory created"
assert_file_exists "$LOG_FILE" "Log file created"

test_section "Timestamp Format"

# Test _helper_log_timestamp
TIMESTAMP=$(_helper_log_timestamp)
[[ "$TIMESTAMP" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] && \
  echo "✓ Timestamp in ISO-8601 format: $TIMESTAMP" || \
  echo "✗ Timestamp format incorrect: $TIMESTAMP"

test_section "Log Escape"

# Test _helper_log_escape_string
ESCAPED=$(_helper_log_escape_string $'Test\nWith\rNewlines')
[[ "$ESCAPED" == *"\\n"* ]] && [[ "$ESCAPED" == *"\\r"* ]] && \
  echo "✓ Newlines and carriage returns escaped" || \
  echo "✗ Escape function not working properly"

test_section "Log Entry Format"

# Test _helper_log_format_entry
ENTRY=$(_helper_log_format_entry "INFO" "test.sh" "test_func" "42" "2026-04-10T00:00:00Z" "1234" "Test message")
[[ "$ENTRY" == *"INFO"* ]] && [[ "$ENTRY" == *"test.sh"* ]] && [[ "$ENTRY" == *"Test message"* ]] && \
  echo "✓ Log entry formatted correctly" || \
  echo "✗ Log entry format incorrect"

test_section "Logging at Different Levels"

# Clear log file
> "$LOG_FILE"

# Log at different levels
log_debug "Debug message" 2>/dev/null || true
log_info "Info message" 2>/dev/null || true
log_warn "Warning message" 2>/dev/null || true
log_error "Error message" 2>/dev/null || true

# Verify log entries
[[ -s "$LOG_FILE" ]] && \
  echo "✓ Log file contains entries" || \
  echo "✗ Log file is empty"

grep -q "DEBUG" "$LOG_FILE" && \
  echo "✓ Debug level logged" || \
  echo "✗ Debug message not in log"

grep -q "INFO" "$LOG_FILE" && \
  echo "✓ Info level logged" || \
  echo "✗ Info message not in log"

grep -q "WARN" "$LOG_FILE" && \
  echo "✓ Warn level logged" || \
  echo "✗ Warn message not in log"

grep -q "ERROR" "$LOG_FILE" && \
  echo "✓ Error level logged" || \
  echo "✗ Error message not in log"

test_section "Log Rotation"

# Test log rotation with small size
export LOG_MAX_SIZE=100  # 100 bytes for testing
LOG_ROTATE_TEST="$TEST_LOG_DIR/rotate_test.log"

# Fill log to trigger rotation
for i in {1..20}; do
  _helper_log_format_entry "INFO" "test" "func" "1" "2026-04-10T00:00:00Z" "1234" "Test line $i" >> "$LOG_ROTATE_TEST"
done

# Manually call rotation
_helper_log_rotate_if_needed "$LOG_ROTATE_TEST" 100 7

# Check if rotation happened
[[ -f "${LOG_ROTATE_TEST}.1" ]] && \
  echo "✓ Log rotation created backup" || \
  echo "✗ Log rotation did not create backup"

# Cleanup
cleanup_test_env

test_summary
