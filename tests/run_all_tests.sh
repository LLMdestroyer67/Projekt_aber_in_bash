#!/usr/bin/env bash
# =============================================================================
# Test Runner - Execute all tests and report results
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "╔═════════════════════════════════════════════════════════════════════════╗"
echo "║                   BASH DEVICE MANAGER - TEST SUITE                      ║"
echo "║                        Phase 2: Test Framework                          ║"
echo "╚═════════════════════════════════════════════════════════════════════════╝"
echo ""

TOTAL_PASS=0
TOTAL_FAIL=0
TESTS_RUN=0

run_test_file() {
  local test_file="$1"
  local test_name="$(basename "$test_file" .sh)"
  
  echo "▶ Running: $test_name"
  
  if bash "$test_file" 2>&1; then
    TESTS_RUN=$((TESTS_RUN + 1))
  else
    echo "  ✗ Test file failed"
    TOTAL_FAIL=$((TOTAL_FAIL + 1))
    TESTS_RUN=$((TESTS_RUN + 1))
  fi
  echo ""
}

# Run all test files
for test_file in test_*.sh; do
  [[ "$test_file" == "test_helpers.sh" ]] && continue
  run_test_file "$test_file"
done

echo "╔═════════════════════════════════════════════════════════════════════════╗"
echo "║                      TEST SUITE EXECUTION COMPLETE                      ║"
echo "╚═════════════════════════════════════════════════════════════════════════╝"
echo ""
echo "Tests run: $TESTS_RUN"
echo ""
if [[ "$TOTAL_FAIL" -eq 0 ]]; then
  echo "All test suites passed."
else
  echo "Failed test suites: $TOTAL_FAIL"
  exit 1
fi
