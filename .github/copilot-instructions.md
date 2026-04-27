# Copilot instructions for Projekt_aber_in_bash

Purpose
- Short guidance to help Copilot-powered assistants work effectively in this repository.

Quick commands (build / test / lint)
- Make scripts executable: chmod +x runner.sh experimental.sh
- Run interactive app: ./runner.sh
- Run full test suite: cd tests && bash run_all_tests.sh
- Run a single test file: bash tests/test_validation.sh (or any test_*.sh)
- Run integration tests: bash tests/test_integration.sh
- No automated linter or build tool is included in the repo (scripts follow set -euo pipefail and are shellcheck-compliant).

High-level architecture (big picture)
- Entry point: runner.sh — orchestrates interactive menu and non-interactive workflows.
- Core library: experimental.sh — all business logic and helper functions (public mains + 1600+ lines of implementation).
- Data: devices/ — one plain-text file per device (key=value lines, .txt files).
- Logs: logs/ — device_manager.log with ISO-8601 entries, rotation handled by helpers.
- Tests: tests/ — manual Bash test framework (8 assertion helpers) and ~65 test cases; run_all_tests.sh runs everything.
- Docs: docs/{ARCHITECTURE.md,API.md,INTERNALS.md,OPERATIONS.md} contain authoritative design, API, internals and operations guidance — consult them for deeper context.

Key repository conventions (important, repo-specific)
- Public functions: named like *_main (create_device_main, read_device_main, change_device_main, find_device_main, find_and_change_main, change_count_main). These are the supported API surface.
- Internal helpers: prefixed with `_helper_`, `_generic_`, or `_prompt_` (keep internal vs public separation).
- Exit codes: 0 = success, 1 = logic/error, 2 = usage error (consistently used across mains).
- Device IDs and types:
  - Type 1 (single devices): numeric IDs (e.g., 1001). Fields: Beschreibung, Location, Status, Kategorie, etc.
  - Type 2 (collections): alphanumeric IDs (e.g., LAN_CABLE_50M). Fields: Beschreibung, Anzahl, Location, Kategorie, etc.
- Device storage format: one file per device, plain key=value lines (no JSON/YAML). Use atomic write (tmp then rename) when modifying.
- Logging: use log_debug/log_info/log_warn/log_error; log lines include timestamp, PID, function and line number. LOG_FILE and LOG_DIR controlled by env vars.
- Configuration: all via environment variables (DEVICE_DIR, LOG_DIR/LOG_FILE, LOG_MAX_SIZE, LOG_KEEP_DAYS, RUN_INTERVAL_SECONDS, TRACE_COMMANDS).
- Concurrency: single-threaded design. No internal file locking — do not run multiple runner.sh processes against the same DEVICE_DIR without external locking (flock or mkdir-semaphore).
- Input validation: `_helper_validate_device_id_strict` enforces allowed characters (alphanumeric, hyphen, underscore); disallows path traversal and injection chars.
- Tests: tests are pure Bash; run individual test scripts directly (bash tests/test_fields.sh). Tests also serve as usage examples for API and helpers.

Where to look first
- For usage examples and CLI behavior: docs/OPERATIONS.md and docs/API.md
- For design and decisions: docs/ARCHITECTURE.md
- For implementation details and helper contracts: docs/INTERNALS.md and experimental.sh
- For tests/examples: tests/*.sh

Notes for Copilot sessions
- When asked to modify behavior, prefer editing experimental.sh helper functions to keep public mains small and stable.
- Preserve public function signatures and exit-code semantics to maintain backward compatibility.
- Respect single-threaded assumption or add explicit external-locking logic if implementing concurrency.

If you want the Copilot instructions adjusted or expanded (examples, CI snippets, shellcheck hooks, or coverage for a specific file), say which area to expand.
