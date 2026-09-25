#!/usr/bin/env bash
# =============================================================================
# Test Suite: Field Parsing & Mode Normalization
# Tests core parsing functions for field definitions and search modes
# =============================================================================

source "$(dirname "$0")/test_helpers.sh"
source "$(dirname "$0")/../experimental.sh"
setup_test_env
export LOG_DIR="$TEST_LOG_DIR"

test_section "Field Parsing Tests"

# Test _generic_parse_field - patterns
_generic_parse_field "1|desc|description:Beschreibung=" patterns | grep -q "1|desc|description" && \
  echo "✓ parse patterns from field definition" || \
  echo "✗ parse patterns from field definition"

# Test _generic_parse_field - prefix
PREFIX=$(_generic_parse_field "1|desc|description:Beschreibung=" prefix)
assert_equals "Beschreibung=" "$PREFIX" "_generic_parse_field extracts prefix"

# Test _generic_find_in_fields - successful match
RESULT=$(_generic_find_in_fields "description" "prefix" "${single_fields[@]}" || true)
assert_equals "Beschreibung=" "$RESULT" "_generic_find_in_fields matches 'description'"

test_section "Mode Normalization Tests"

# Test _helper_modes_normalize - ID mode
MODE_ID=$(_helper_modes_normalize "id")
assert_equals "id" "$MODE_ID" "Normalize 'id' mode"

# Test _helper_modes_normalize - lowercase
MODE_DESC=$(_helper_modes_normalize "description")
assert_equals "description" "$MODE_DESC" "Normalize 'description' mode"

# Test _helper_modes_normalize - invalid should fail
_helper_modes_normalize "invalid_mode" && \
  echo "✗ Should fail on invalid mode" || \
  echo "✓ Correctly rejects invalid mode"

test_section "Field Building Tests"

# Test _helper_fields_build_prompt
PROMPT=$(_helper_fields_build_prompt "${single_fields[@]:0:2}")
[[ "$PROMPT" == *"(1)"* ]] && [[ "$PROMPT" == *"(2)"* ]] && \
  echo "✓ _helper_fields_build_prompt includes field numbers" || \
  echo "✗ _helper_fields_build_prompt format incorrect"

test_section "Mode File Key Tests"

# Test _helper_modes_get_file_key
FILEKEY=$(_helper_modes_get_file_key "description")
assert_equals "Beschreibung=" "$FILEKEY" "_helper_modes_get_file_key finds file key for description mode"

cleanup_test_env
test_summary
