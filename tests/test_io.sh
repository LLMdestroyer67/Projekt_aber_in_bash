#!/usr/bin/env bash
# =============================================================================
# Test Suite: Input/output helper contracts
# =============================================================================

source "$(dirname "$0")/test_helpers.sh"
source "$(dirname "$0")/../experimental.sh"
REPO_ROOT="$(cd -- "$(dirname "$0")/.." && pwd -P)"
setup_test_env
export LOG_DIR="$TEST_LOG_DIR"

test_section "read_logged prompt and captured-value contract"

prompt_file="$(mktemp)"
trap 'rm -f "$prompt_file"; cleanup_test_env' EXIT

captured_value="$(printf '900001\n' | _helper_create_resolve_device_id '' 2>"$prompt_file")"
captured_prompt="$(<"$prompt_file")"

assert_equals "900001" "$captured_value" \
  "captured device ID contains only the entered value"
assert_equals "Enter the device ID: " "$captured_prompt" \
  "device ID prompt remains visible on stderr"

test_section "interactive detection with captured stdout"

pty_output="$(
  printf '1\n' |
    script -qefc \
      "source '$REPO_ROOT/experimental.sh'; mode=\"\$(_helper_find_resolve_mode '')\"; printf 'resolved=%s\\n' \"\$mode\"" \
      /dev/null
)"

if [[ "$pty_output" == *"resolved=1"* ]]; then
  TEST_PASS=$((TEST_PASS + 1))
  echo -e "${GREEN}✓${NC} PASS: interactive resolver still prompts when stdout is captured"
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo -e "${RED}✗${NC} FAIL: interactive resolver did not return the entered mode"
fi
if [[ "$pty_output" != *"missing mode (non-interactive)"* ]]; then
  TEST_PASS=$((TEST_PASS + 1))
  echo -e "${GREEN}✓${NC} PASS: captured interactive resolver was not misclassified"
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo -e "${RED}✗${NC} FAIL: captured interactive resolver was misclassified"
fi

test_section "direct terminal prompts use the visible output stream"

pty_prompt_output="$(
  printf 'value\n' |
    script -qefc \
      "source '$REPO_ROOT/experimental.sh'; read_logged 'Visible prompt: ' answer 2>/dev/null; printf 'resolved=%s\\n' \"\$answer\"" \
      /dev/null
)"
if [[ "$pty_prompt_output" == *"Visible prompt: "* && "$pty_prompt_output" == *"resolved=value"* ]]; then
  TEST_PASS=$((TEST_PASS + 1))
  echo -e "${GREEN}✓${NC} PASS: terminal prompt is visible when stderr is redirected"
else
  TEST_FAIL=$((TEST_FAIL + 1))
  echo -e "${RED}✗${NC} FAIL: terminal prompt was not visible on stdout"
fi

test_summary
