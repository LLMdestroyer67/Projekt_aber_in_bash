# Architecture: Bash Device Manager

## Overview

The Bash Device Manager is a lightweight, terminal-based system for tracking hardware inventory (single devices and bulk collections). It uses plain-text file storage, modular Bash functions, and comprehensive logging.

**Core Philosophy:**
- Simple, maintainable codebase
- Plain-text storage (human-readable, versionable)
- Atomic device writes protected by a portable directory lock
- No external dependencies beyond GNU coreutils + Bash 4+
- Interactive and non-interactive operation modes

---

## Project Structure

```
Projekt_aber_in_bash/
├── runner.sh                 # Main entry point; orchestrates menu/workflows
├── experimental.sh           # Backward-compatible shim; sources modules/
├── modules/                  # Modular implementation (logging, I/O, workflows)
│   ├── logging.sh            # Logging, rotation, and traps
│   ├── fields.sh             # Field and mode handling
│   ├── io.sh                # Input/output helpers
│   ├── validators.sh         # Validation and change prompts
│   ├── device_ops.sh         # Atomic device-file updates
│   ├── create.sh             # Create workflow
│   ├── find.sh               # Find/search workflow
│   ├── count.sh              # Collection count workflow
│   ├── mains.sh              # Public main functions
│   └── cli.sh                # run_cli dispatcher
├── devices/                  # Plain-text device files (*.txt)
├── logs/                     # Operation logs (device_manager.log)
├── tests/                    # Test suite (Bash test framework + test files)
│   ├── test_helpers.sh       # Manual test framework (8 assertion helpers)
│   ├── test_validation.sh    # Device ID validation tests
│   ├── test_fields.sh        # Field parsing tests
│   ├── test_device_crud.sh   # Create/read/update/delete tests
│   ├── test_find.sh          # Search/find tests
│   ├── test_logging.sh       # Logging system tests
│   ├── test_edge_cases.sh    # Edge case handling
│   ├── test_integration.sh   # End-to-end workflows
│   └── run_all_tests.sh      # Test runner script
├── docs/                     # Documentation (markdown files)
│   ├── ARCHITECTURE.md       # This file
│   ├── API.md                # Public function reference
│   ├── INTERNALS.md          # Helper function reference
│   └── OPERATIONS.md         # Deployment & operations guide
└── .git/                     # Version control
```

---

## Data Model

### Device File Storage

Device data is stored as key=value pairs in plain-text files:

```
# Single device (numeric ID like "1001.txt")
Beschreibung=Server Production
Location=DataCenter Rack 3
Status=active
Kategorie=Server
Seriennummer=ABC123

# Collection/bulk device (alphanumeric ID like "LAN_CABLE_50M.txt")
Beschreibung=50-meter network cables
Anzahl=125
Location=Storage Bin A
Kategorie=Network
Verfallsdatum=2025-12-31
```

**Key Design Decisions:**
- One file per device (loose coupling, easy to version control)
- Simple key=value format (no JSON, YAML, or binary formats)
- Field definitions differ by device type (type 1 vs type 2)
- No formal schema (fields optional, extensible)

### Device Types

**Type 1: Single Device**
- ID format: Numeric (e.g., `1001`, `42`, `999`)
- Fields: Beschreibung, Location, Status, Kategorie, Seriennummer, Zustand, etc.
- Example: Physical servers, workstations, routers

**Type 2: Collection/Bulk Item**
- ID format: Alphanumeric (e.g., `LAN_CABLE_50M`, `SCREW_M4_1000`, `USB_CABLE`)
- Fields: Beschreibung, Anzahl (count), Location, Kategorie, Verfallsdatum, etc.
- Example: Inventory, consumables, grouped items

---

## Workflow Overview

### Interactive Mode (Default)

```
1. runner.sh starts in interactive mode
2. Displays menu with 4 options:
   - Create device (create_device_main)
   - Change device (change_device_main)
   - Find device (find_device_main)
   - Find and change; for collections, choose a field change or count change
     after the device is found
3. User selects option via numeric input
4. Function prompts for parameters (device ID, field name, value)
5. Operation executes, logs results
6. Returns to menu or exits
```

### Scripted Calls

```
source experimental.sh
  -> Loads modules/ and exposes the public functions
  -> Call a *_main function with all required arguments
  -> Returns exit code (0=success, 1=error, 2=usage error)
```

### Operation Flow (Example: Create Device)

```
runner.sh
  ↓
experimental.sh (compatibility shim)
  ↓
create_device_main() [modules/mains.sh]
  ├─ _helper_core_is_interactive() → check if TTY
  ├─ _helper_create_resolve_device_id() → prompt or use arg
  ├─ _helper_validate_device_id_strict() → validate chars
  ├─ _helper_create_assert_file_not_exists() → check no duplicate
  ├─ _prompt_field_value() × N → prompt for each field
  ├─ _helper_core_is_type_1() → determine device type
  ├─ write device file with all fields
  ├─ _helper_log_rotate_if_needed() → check log size
  ├─ log_info() → log operation
  └─ echo_logged() → show result to user
```

---

## Function Organization

### Public Functions (User-Facing)

The public functions are implemented in `modules/mains.sh` and
`modules/count.sh`, then exposed through `experimental.sh`:

- `create_device_main` — Add new device
- `change_device_main` — Modify device field
- `find_device_main` — Search devices by criteria
- `find_and_change_main` — Find then modify in one operation
- `change_count_main` — Increment/decrement count (for type 2 only)
- `find_and_change_menu_main` — Interactive menu workflow that offers field
  or count changes after finding a device

All return exit codes: 0 (success), 1 (error), 2 (usage error).

### Helper Functions (Internal)

Prefixed with `_helper_` or specific prefixes:

**Core helpers:**
- `_helper_core_is_interactive()` — Check if running interactively
- `_helper_core_is_type_1()` — Determine if device is type 1 (numeric) or type 2 (string)

**Logging:**
- `log_debug()`, `log_info()`, `log_warn()`, `log_error()` — Logging levels
- `_helper_log_format_entry()` — Format log line
- `_helper_log_rotate_if_needed()` — Rotate logs if too large
- `echo_logged()` — Output + log
- `error_logged()` — Error output + log

**Field/Mode parsing:**
- `_generic_parse_field()` — Extract key=value from file
- `_generic_find_in_fields()` — Search for key in list
- `_helper_modes_normalize()` — Normalize user input
- `_helper_fields_build_prompt()` — Build field selection prompt

**Device operations:**
- `_helper_device_file_validate()` — Ensure device file exists
- `_helper_create_resolve_device_id()` — Get or prompt for ID
- `_helper_validate_device_id_strict()` — Validate ID format
- `_helper_change_rewrite_file()` — Update a field in device file
- `_helper_find_file_matches_key_value()` — Check if device matches criteria

**User input:**
- `read_logged()` — Read user input with logging
- `_prompt_field()` — Prompt for field selection
- `_prompt_field_value()` — Prompt for field value

---

## Configuration

### Environment Variables

All configuration is via environment variables (no config files):

```bash
# Device storage
export DEVICE_DIR="/workspaces/Projekt_aber_in_bash/devices"

# Logging
export LOG_DIR="/workspaces/Projekt_aber_in_bash/logs"
export LOG_FILE="$LOG_DIR/device_manager.log"
export LOG_MAX_SIZE=10485760          # 10 MB (bytes)
export LOG_KEEP_DAYS=7                # Keep 7 days of rotated logs

# Runtime
export RUN_INTERVAL_SECONDS=10        # Polling interval (if used as daemon)
export TRACE_COMMANDS=0               # Enable `set -x` debugging (1 = enabled)
```

---

## Logging System

### Log Format

ISO-8601 timestamp with PID, level, function, message:

```
2026-04-10T08:15:42Z [INFO] (PID 1234) [create_device_main:1087] Device created: ID=TEST_SERVER_001
2026-04-10T08:15:43Z [ERROR] (PID 1234) [read_device_main:730] device 'BAD_ID' not found
```

### Log Levels

- `DEBUG` — Function entry/exit, variable values
- `INFO` — Operation success, state changes
- `WARN` — Non-fatal issues, unusual conditions
- `ERROR` — Operation failed, error state

### Log Rotation

Automatic rotation triggered when log file size ≥ `LOG_MAX_SIZE`:

```
Before: device_manager.log (10.5 MB)
         → device_manager.log (rotated to .1)
After:  device_manager.log (new, empty)
         → device_manager.log.1 (compressed or kept as-is)
         → device_manager.log.2 (older)
         → ...
         → device_manager.log.9 (oldest kept)
```

Logs older than `LOG_KEEP_DAYS` are deleted automatically.

---

## Error Handling

### Exit Codes

```bash
EXIT_OK=0               # Operation succeeded
EXIT_ERROR=1            # Logic error (device not found, validation failed, etc)
EXIT_USAGE_ERROR=2      # Usage error (missing argument, invalid arg, etc)
```

### Error Messages

All errors include:
- Function name (e.g., `ERROR (create_device_main):`)
- Clear description
- Actionable recovery hint
- Exit code (if applicable)

Example:
```
ERROR (read_device_main): device 'BAD_ID' not found. 
Use 'find' to list devices or 'create' to add new one. (exit code: 1)
```

### Signal Handling

```bash
# set -euo pipefail in all scripts
# ERR trap logs errors
# EXIT trap cleans up temp files
```

---

## Concurrency & Thread Safety

**IMPORTANT: Single-threaded only.**

Device writes acquire `$DEVICE_DIR.lock` using `mkdir`, wait up to
`DEVICE_LOCK_TIMEOUT_SECONDS` (default 10 seconds), and fail explicitly on
timeout. Rewrites remain atomic through a temporary file followed by `mv`.

**Workarounds:**
- Run one process at a time
- Use external locking (flock, mkdir-based semaphore)
- Document as operational requirement

---

## Security Considerations

### Input Validation

Device IDs are validated to prevent path traversal and shell injection:

```bash
# Rejected characters
- / (path traversal)
- space, tab, newline (field injection)
- $ ` (command injection)
- " ' (quote injection)

# Allowed
- alphanumeric (a-z, A-Z, 0-9)
- hyphen (-), underscore (_)
```

Field values are not validated (intentionally flexible for user data).

### File Operations

- Temporary files use mktemp (OS-provided randomization)
- Write-then-rename pattern for atomicity
- No world-writable directories

---

## Testing Strategy

### Test Framework

Manual Bash test framework (no external dependencies):
- 8 assertion helpers (assert_equals, assert_file_exists, etc)
- Test environment setup/cleanup
- Output formatting with section dividers

### Test Coverage

- **Validation:** Device ID validation (9 cases)
- **Fields:** Field parsing, mode normalization (6 cases)
- **Device CRUD:** Create, read, update, delete (10 cases)
- **Find:** Search by ID, description, location (8 cases)
- **Logging:** Levels, rotation, formatting (10+ cases)
- **Edge cases:** Empty files, Unicode, large values, special chars (12 cases)
- **Integration:** Full workflows, multi-step operations (10 cases)

The test suite covers validation, fields, CRUD, search, logging, edge cases,
and integration workflows.

### Running Tests

```bash
cd tests/
bash run_all_tests.sh               # Run all tests
bash test_validation.sh             # Run specific test file
bash test_integration.sh            # Run integration tests
```

---

## Performance Characteristics

### Time Complexity

- Create device: O(1) — single file write
- Read device: O(1) — grep single file
- Find device: O(N) — grep all N device files
- Change device: O(N) — rewrite all fields
- Change count: O(N) — rewrite all fields

### Space Complexity

- Device files: ~500 bytes per device (typical)
- Logs: 10 MB rotated (configurable)
- Runtime: ~5 MB bash process + temp files

### Scalability Limits

- Device count: No hard limit (tested to 1000+ devices)
- Single device size: No hard limit (shell awk/grep handle large files)
- Log rotation: Handles multi-MB logs efficiently

---

---

## Development Guidelines

### Adding New Features

1. **Preserve backward compatibility** — No changes to user workflows
2. **Add helper function** — Keep main functions lean
3. **Log all operations** — Use log_info/log_error
4. **Validate inputs** — Check early, fail clearly
5. **Write tests** — Add test cases to tests/ directory
6. **Document changes** — Update INTERNALS.md or API.md
7. **Single commit** — One logical change per commit

### Code Style

- Use `set -euo pipefail` in all scripts
- Quote all variables: `"$var"`
- Prefix internals with `_helper_` or `_internal_`
- Use UPPER_CASE for globals, lower_case for locals
- Indent with 2 spaces (shell convention)
- Comment complex blocks (awk scripts, conditionals)

---

## Version History

- **v1.0** (Phase 1 Complete) — Stabilization & bug fixes
  - Removed debug output
  - Standardized exit codes
  - Implemented log rotation
  - Added input validation
  - Documented concurrency limitations and write locking

- **Current implementation** — Runtime code is modular under `modules/`;
  `experimental.sh` remains the compatibility shim for existing callers.

---

## Support & Troubleshooting

See `OPERATIONS.md` for:
- Installation & setup
- Common issues
- Log analysis
- Performance tuning
