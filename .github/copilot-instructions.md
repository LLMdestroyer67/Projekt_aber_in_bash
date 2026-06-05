# Copilot instructions for Projekt_aber_in_bash

Purpose
- Short guidance to help Copilot-powered assistants work effectively in this repository.

Quick commands (build / test / lint)
- Make scripts executable: chmod +x runner.sh experimental.sh
- Run interactive app: ./runner.sh
- Run a single public function (no runner):
  - source experimental.sh
  - create_device_main "DEVICE_ID"  # or any other *_main
- Run full test suite: cd tests && bash run_all_tests.sh
- Run a single test file: bash tests/test_validation.sh (or any test_*.sh)
- Run a single test with debug tracing: bash -x tests/test_validation.sh
- Run integration tests: bash tests/test_integration.sh
- View recent logs: tail -50 logs/device_manager.log
- No automated linter/build tool included; scripts follow set -euo pipefail and are shellcheck-friendly.

High-level architecture (big picture)
- Entry point: runner.sh — interactive menu and a thin orchestrator for non-interactive workflows.
- Core library: experimental.sh — monolithic implementation (public *_main functions + many `_helper_` utilities). Prefer editing helpers there.
- Data model: devices/ — one plain-text file per device (key=value lines, *.txt). Two device types: numeric single devices and alphanumeric collections (with `Anzahl=`).
- Logging: logs/device_manager.log — ISO-8601 timestamped entries; automatic rotation handled by helper.
- Tests: tests/ — small Bash test framework (test_helpers.sh) and multiple test_* scripts that are the authoritative usage examples.
- Docs: docs/ contain ARCHITECTURE.md, API.md, INTERNALS.md, OPERATIONS.md — consult these before large changes.

Key repository conventions (repo-specific)
- Public API: functions named *_main (create_device_main, read_device_main, change_device_main, find_device_main, find_and_change_main, change_count_main). Keep these stable.
- Internal helpers: prefixes `_helper_`, `_generic_`, `_prompt_` (do not export unless needed).
- Exit codes: 0 = success, 1 = logic/error, 2 = usage error. Use consistently for public mains.
- Device IDs and detection:
  - Type 1 (single): numeric IDs (e.g., 1001) — no `Anzahl` field.
  - Type 2 (collection): alphanumeric IDs (e.g., LAN_CABLE_50M) — includes `Anzahl=` field and count operations.
- Device file format: plain key=value lines. When updating, use atomic write (mktemp -> write -> mv) as in `_helper_change_rewrite_file`.
- Logging helpers: use log_debug/log_info/log_warn/log_error and echo_logged / error_logged for combined stdout+log messages.
- Input helpers: use read_logged to prompt and log user input consistently.
- Validation: use `_helper_validate_device_id_strict` to reject dangerous IDs (/, spaces, $, `, quotes). Always validate user-supplied IDs in mains.
- Tests as examples: tests/* are also usage examples — prefer adding tests when changing behavior.
- Concurrency: intentionally single-threaded. If enabling concurrency, implement an external locking wrapper (flock) and add tests demonstrating safe behavior.
- Commit message convention: when making commits during automated assistant sessions, append the Co-authored-by trailer:
  Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>

Where to look first (fast path)
- Quick feature change: experimental.sh — search for the relevant `_helper_` then update small helper functions.
- To understand public behavior: docs/API.md then tests/* for concrete examples.
- For logging/diagnostics: docs/OPERATIONS.md and logs/device_manager.log

Guidance for Copilot sessions (practical rules)
- Make small, surgical edits to experimental.sh helpers. Avoid wholesale rewrites of the file.
- Run tests locally after changes: cd tests && bash run_all_tests.sh. Fix failures before committing.
- When adding or changing public mains, update docs/API.md and add corresponding tests under tests/.
- Preserve exit codes and public function signatures for backward compatibility.
- Use existing test helpers (test_helpers.sh) for new tests; keep tests deterministic (no network/time dependence).

Files to avoid changing unless necessary
- docs/ — these are the canonical design docs; update when behavior or API changes.
- tests/ — keep tests authoritative; update only to reflect intentional behavioral changes.

If you want this file expanded (examples, CI snippets, shellcheck hooks, or targeted areas to cover), say which area to expand.
