# Bash Device Manager — Fix & Stabilize Plan

## Current State

- Project: `Projekt_aber_in_bash` — bash-based device inventory CRUD system
- Phase 2 (testing + docs) is marked complete, but the test suite is **not actually passing**.
- Running `bash tests/run_all_tests.sh` reports several `✗ Test file failed` messages.
- Some failures are **test-framework / test-isolation bugs**, others are **real code bugs** in `experimental.sh` / `modules/`.

## Goal

Make `bash tests/run_all_tests.sh` run cleanly with **zero test-file failures** and **zero internal assertion failures**, without breaking the public API or interactive behavior.

---

## Part A — Fix the Test Framework & Test Isolation

### A.1 Problem: `set -e` kills the whole test file on the first failed assertion

**Evidence:**
- All test files start with `set -euo pipefail`.
- `assert_exit_code` / `assert_equals` return `1` on failure.
- When called bare (not inside `|| true`), a failed assertion triggers `set -e` and the test file exits immediately.
- `run_all_tests.sh` then prints `✗ Test file failed`, even if the internal summary would have shown only one failure.

**Fix options (pick one):**

1. **Recommended:** Remove `set -e` from test files. Keep `set -u` and `set -o pipefail`. The assertion framework already tracks `TEST_PASS` / `TEST_FAIL` and `test_summary` returns `1` if any failed. This lets all assertions run and produces a clean summary.
2. Alternative: Wrap every bare assertion in `|| true`, but this is noisy and easy to miss.

**Action:**
- Edit `tests/test_*.sh` to remove `set -e` (keep `set -uo pipefail` or `set -u; set -o pipefail`).
- Verify `test_summary` still returns non-zero on failure so `run_all_tests.sh` can report the file as failed.

### A.2 Problem: Tests share the same `test_devices/` directory and leak state

**Evidence:**
- `setup_test_env` sets `TEST_DEVICE_DIR="$test_dir/test_devices"`.
- Every test file uses the same `./test_devices/` directory relative to `tests/`.
- If a test file exits early (A.1), `cleanup_test_env` never runs, leaving files like `1001.txt`, `LAN_CABLE_50M.txt`, `TEST_SINGLE_001.txt` for the next test.
- This causes later tests to fail on "device already exists" or to read stale data.

**Fix:**
- Make each test file use a **unique, isolated directory** that is always cleaned up, even on early exit.
- Use a pattern like `TEST_DEVICE_DIR="$test_dir/test_devices_$(basename "$0" .sh)_$$"`.
- Add a `trap cleanup_test_env EXIT` in `setup_test_env` or in each test file so cleanup runs even if the script aborts.

**Action:**
- Update `setup_test_env` in `tests/test_helpers.sh` to create a unique directory per test file and register a cleanup trap.
- Or, if you prefer minimal changes, add `trap cleanup_test_env EXIT` at the top of each test file after sourcing helpers.
- Ensure `cleanup_test_env` removes the directory even if it partially exists.

### A.3 Problem: `run_all_tests.sh` swallows the per-file exit status and prints a generic message

**Evidence:**
- `run_all_tests.sh` only prints `✗ Test file failed` and does not aggregate `TOTAL_PASS` / `TOTAL_FAIL`.
- The final summary says "Tests run: 14" but does not count actual assertions.

**Fix:**
- Keep a running total of `TEST_PASS` / `TEST_FAIL` across files.
- Print a final aggregate summary at the end.
- Optionally capture per-file pass/fail counts by parsing `test_summary` output.

**Action:**
- Enhance `run_all_tests.sh` to aggregate results and print:
  ```
  Total assertion passes: X
  Total assertion failures: Y
  Test files with failures: Z
  ```

### A.4 Problem: `run_noninteractive` helper captures stderr into stdout

**Evidence:**
- `run_noninteractive` runs `timeout ... bash -c "$cmd" </dev/null 2>&1`.
- The caller then tries to test "stderr not empty / stdout empty", but both streams are merged.
- This makes the non-interactive stderr test unreliable.

**Fix:**
- Change `run_noninteractive` to capture stdout and stderr separately using temporary files or file descriptors, and return both plus the exit code.
- Or, for a simpler fix, provide two helpers: `run_noninteractive_stdout` and `run_noninteractive_stderr`.

**Action:**
- Update `tests/test_helpers.sh` `run_noninteractive` to separate stdout/stderr.
- Update `tests/test_noninteractive_mode.sh` to use the separated streams correctly.

---

## Part B — Fix Underlying Code Bugs

### B.1 Bug: Collection device creation writes `Anzahl=Anzahl=100`

**Evidence:**
- `test_mains_unit.sh` creates `LAN_CABLE_50M` with input `Anzahl=100`.
- The resulting file contains `Anzahl=Anzahl=100`.

**Likely cause:**
- The collection-device creation logic probably prepends `Anzahl=` to the user input even when the user already typed `Anzahl=...`.
- Or the prompt logic and the file-writing logic both add the prefix.

**Action:**
- Inspect `create_device_main` and the collection-field handling in `experimental.sh` / `modules/create.sh` / `modules/fields.sh`.
- Ensure the value written to file is exactly what the user provided (or exactly the parsed value), without double-prefixing.
- Add a regression test: after creating a collection device, assert the file contains exactly `Anzahl=100` (not `Anzahl=Anzahl=100`).

### B.2 Bug: `change_count_main` rejects `Status` field on collection devices

**Evidence:**
- `test_data_integrity.sh` creates `MALFORMED_002.txt` with `Status=active` and calls `change_device_main MALFORMED_002 Status inactive`.
- Output: `ERROR: invalid FIELD 'Status' for device_count=2`.

**Likely cause:**
- `change_device_main` routes to `change_count_main` for type-2 devices, or the field validator for type-2 devices only allows a fixed list (e.g., `Beschreibung`, `Anzahl`, `Location`, `Kategorie`, `Verfallsdatum`) and rejects `Status`.

**Action:**
- Decide the intended behavior:
  - If type-2 devices should support `Status`, add it to the allowed fields.
  - If type-2 devices should not support `Status`, update the test to use an allowed field (e.g., `Beschreibung` or `Location`).
- The test name says "Change operation on file with duplicate keys", so the field being changed is not the point — change it to a field that type-2 allows.

### B.3 Bug: `run_cli change` command fails

**Evidence:**
- `test_cli_dispatch.sh` calls `run_cli change "CLI_TEST_001" "Status" "maintenance"` and the test file exits early.

**Likely cause:**
- `run_cli` may not dispatch the `change` command correctly, or it may require interactive input, or it may pass wrong arguments to `change_device_main`.

**Action:**
- Inspect `run_cli` in `modules/cli.sh`.
- Verify argument parsing for `change <id> <field> <value>`.
- Ensure it calls `change_device_main "$id" "$field" "$value"` correctly.
- Add a focused unit test for `run_cli change` once fixed.

### B.4 Bug: Error messages go to stdout instead of stderr in non-interactive mode

**Evidence:**
- `test_noninteractive_mode.sh` test 4 fails with `FAIL: Error message leaked to stdout`.

**Likely cause:**
- `error_logged` or the non-interactive error path prints to stdout instead of stderr.

**Action:**
- Inspect `error_logged` and the non-interactive argument-check paths in `experimental.sh` / `modules/io.sh` / `modules/logging.sh`.
- Ensure all error messages are written to `stderr` (file descriptor 2).
- Update the test to verify stderr content explicitly once streams are separated (A.4).

### B.5 Bug: `_is_interactive` returns `0` in non-interactive context

**Evidence:**
- `test_noninteractive_mode.sh` test 5 expects `_is_interactive` to return `1` when stdin is closed, but it returns `0`.

**Likely cause:**
- `_is_interactive` may check `[[ -t 0 ]]` (stdin is a terminal), but in the test context stdin is closed (`</dev/null`), which is not a terminal, so it should return non-zero.
- Or the function checks the wrong thing (e.g., `[[ -t 1 ]]` stdout).

**Action:**
- Inspect `_is_interactive` and `_helper_core_is_interactive`.
- Ensure it correctly detects interactive use (e.g., `[[ -t 0 && -t 1 ]]` or `[[ -p /dev/stdin ]]` depending on intended semantics).
- Document the exact semantics in `INTERNALS.md` if changed.

### B.6 Bug: Missing-argument handling in non-interactive mode may hang or return wrong code

**Evidence:**
- Some tests expect exit code `2` for missing arguments in non-interactive mode.
- Need to verify each `_main` function checks argument count before attempting to prompt.

**Action:**
- For each public `_main` function, ensure:
  - If not `_is_interactive` and required args are missing, print error to stderr and return `EXIT_USAGE_ERROR` (2).
  - If interactive, prompt for missing values.

---

## Part C — Verification Steps

1. Run the full suite:
   ```bash
   cd /workspaces/Projekt_aber_in_bash
   bash tests/run_all_tests.sh
   ```
2. Confirm:
   - No `✗ Test file failed` messages.
   - No internal `✗ FAIL` assertions.
   - Aggregate summary shows `Total assertion failures: 0`.
3. Run shellcheck on changed files:
   ```bash
   shellcheck experimental.sh modules/*.sh tests/*.sh runner.sh
   ```
4. Run a quick manual smoke test:
   ```bash
   ./runner.sh
   ```
   Verify interactive menu still works.
5. Run a non-interactive smoke test:
   ```bash
   ./runner.sh create TEST_SMOKE_001 <<EOF
   Smoke Test
   Lab A
   active
   EOF
   ./runner.sh read TEST_SMOKE_001
   ./runner.sh change TEST_SMOKE_001 Status maintenance
   ./runner.sh find ID TEST_SMOKE_001
   ```

---

## Part D — Suggested Order of Work

1. **Start with A.1 and A.2** — fix the test framework so failures are reported accurately and tests do not leak state. This will make the remaining failures easier to diagnose.
2. **Then fix B.1** (double `Anzahl=` prefix) — it is a clear data-corruption bug.
3. **Then fix B.2** or update the corresponding test — decide whether type-2 devices support `Status`.
4. **Then fix B.3** (`run_cli change`).
5. **Then fix B.4 and B.5** (non-interactive stderr and `_is_interactive`).
6. **Then A.3 and A.4** — polish the runner output and the non-interactive test helper.
7. **Finally run Part C verification**.

---

## Part E — Notes for the Next Session

- Do not trust the `PHASE_2_SUMMARY.md` claim that all tests pass. The current suite has hidden failures due to `set -e` early-exit behavior.
- The two modified log files (`logs/device_manager.log` and `tests/logs/device_manager.log`) are currently uncommitted. Decide whether to commit them, discard them, or add them to `.gitignore` before finishing.
- Keep changes minimal and consistent with the existing bash style (`set -euo pipefail`, quoted variables, `SCREAMING_SNAKE_CASE` globals).
- If a behavior decision is ambiguous (e.g., should type-2 devices support `Status`?), prefer the behavior that makes the existing tests pass, then document it.
