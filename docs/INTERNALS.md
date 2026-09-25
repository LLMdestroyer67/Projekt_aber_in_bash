# Internals: Helper Function Reference

## Overview

This document describes internal helper functions used by the public API. These are implementation details; most users don't need to know them.

**Location:** `modules/` (loaded by the compatibility shim `experimental.sh`)
**Prefix Convention:** `_helper_*`, `_generic_*`, `_prompt_*`, `_section_*`

---

## Logging Helpers

### `log_debug(message)`

**Purpose:** Log debug-level message (lowest verbosity).

**Signature:**
```bash
log_debug "Debug message here"
```

**Behavior:**
- Logs only if debugging is enabled (or uses default verbosity)
- Includes function name and line number
- Useful for variable inspection during development

**Example:**
```bash
log_debug "_helper_create_validate: device_id='$device_id' is_type_1=$is_type_1"
```

---

### `log_info(message)`

**Purpose:** Log info-level message (operational events).

**Signature:**
```bash
log_info "Device created: ID=SERVER_001"
```

**Behavior:**
- Logs operation success, state changes
- Includes timestamp, PID, function
- Used in all main functions

**Example:**
```bash
log_info "find_device_main: found 3 devices matching 'Server'"
```

---

### `log_warn(message)`

**Purpose:** Log warning-level message (non-fatal issues).

**Signature:**
```bash
log_warn "Field may be missing from device file"
```

**Behavior:**
- Logs unusual but recoverable conditions
- Includes timestamp and context
- Rarely used in current codebase

---

### `log_error(message)`

**Purpose:** Log error-level message (operation failed).

**Signature:**
```bash
log_error "Device file not found at $device_file"
```

**Behavior:**
- Logs failures, invalid inputs, error conditions
- Includes full context for debugging
- Typically paired with return 1 or return 2

**Example:**
```bash
if ! _helper_validate_device_id_strict "$device_id"; then
  log_error "invalid device_id='$device_id': contains forbidden chars"
  return 2
fi
```

---

### `_helper_log_timestamp()`

**Purpose:** Return current ISO-8601 timestamp.

**Returns:** `YYYY-MM-DDTHH:MM:SSZ` on stdout

**Example:**
```bash
TIMESTAMP=$(_helper_log_timestamp)
echo "$TIMESTAMP [INFO] Operation completed"
```

---

### `_helper_log_escape_string(string)`

**Purpose:** Escape special characters in strings for safe logging.

**Parameters:**
- `$1` — String to escape

**Returns:** Escaped string on stdout

**Escapes:**
- Newlines → `\n`
- Carriage returns → `\r`
- Tabs → `\t`

**Example:**
```bash
SAFE=$(_helper_log_escape_string "$user_input")
log_info "User entered: $SAFE"
```

---

### `_helper_log_format_entry(level, file, func, line, ts, pid, message)`

**Purpose:** Format a complete log entry.

**Parameters:**
- `$1` — Log level (INFO, ERROR, WARN, DEBUG)
- `$2` — Filename (e.g., experimental.sh)
- `$3` — Function name
- `$4` — Line number
- `$5` — ISO-8601 timestamp
- `$6` — Process ID
- `$7` — Message

**Returns:** Formatted log line on stdout

**Example:**
```bash
ENTRY=$(_helper_log_format_entry "INFO" "modules/mains.sh" "create_device_main" "1087" "2026-04-10T08:15:42Z" "$$" "Device created")
echo "$ENTRY" >> "$LOG_FILE"
```

---

### `_helper_log_rotate_if_needed(log_file, max_size, keep_days)`

**Purpose:** Rotate logs if file exceeds `max_size`.

**Parameters:**
- `$1` — Path to log file
- `$2` — Max size in bytes (e.g., 10485760 for 10 MB)
- `$3` — Keep logs newer than N days

**Behavior:**
- Checks if log file size ≥ max_size
- If true: rotates to .1, .2, ... .9
- Deletes logs older than keep_days
- Returns 0 if rotation happened, 1 if no rotation needed

**Example:**
```bash
_helper_log_rotate_if_needed "$LOG_FILE" "$LOG_MAX_SIZE" "$LOG_KEEP_DAYS"
if [[ $? -eq 0 ]]; then
  log_info "Log rotated"
fi
```

---

### `echo_logged(message)`

**Purpose:** Print message to stdout AND log it.

**Signature:**
```bash
echo_logged "Device created successfully: SERVER_001"
```

**Behavior:**
- Shows message to user (stdout)
- Also logs to file
- Used for confirmations and results

**Example:**
```bash
echo_logged "Found 3 devices matching 'Server'"
```

---

### `error_logged(message)`

**Purpose:** Print error to stderr AND log it.

**Signature:**
```bash
error_logged "ERROR (create_device_main): device already exists"
```

**Behavior:**
- Shows error to user (stderr)
- Also logs to file
- Used by all error paths

---

## Core Helpers

### `_helper_core_is_interactive()`

**Purpose:** Detect if running in interactive mode (TTY).

**Returns:** 0 if interactive, 1 if non-interactive

**Behavior:**
- Checks whether standard input is attached to a terminal.
- Does not require standard output to be a terminal because interactive
  resolvers run inside command substitutions whose output is captured.

**Example:**
```bash
if _helper_core_is_interactive; then
  field="$(_prompt_field "$device_count")"
else
  error_logged "ERROR: missing FIELD (non-interactive)"
  return 2
fi
```

---

### `_helper_core_is_type_1(device_id)`

**Purpose:** Determine if device is Type 1 (single) or Type 2 (collection).

**Parameters:**
- `$1` — Device ID to check

**Returns:**
- 0 if Type 1 (numeric ID)
- 1 if Type 2 (alphanumeric ID)

**Logic:**
- Type 1: ID contains only digits (0-9)
- Type 2: ID contains any letter or non-digit

**Example:**
```bash
if _helper_core_is_type_1 "$device_id"; then
  echo "Single device (can't change count)"
else
  echo "Collection device (can change count)"
fi
```

---

## Field Parsing Helpers

### `_generic_parse_field(file, key_prefix)`

**Purpose:** Extract value for a key from a device file.

**Parameters:**
- `$1` — Path to device file
- `$2` — Key prefix to search for (e.g., "Status=")

**Returns:** Field value on stdout, empty if not found

**Example:**
```bash
STATUS=$(_generic_parse_field "devices/SERVER_001.txt" "Status=")
echo "Current status: $STATUS"
```

**How it works:**
```bash
grep "^Status=" devices/SERVER_001.txt | cut -d= -f2
```

---

### `_generic_find_in_fields(search_field, field_list)`

**Purpose:** Find a matching key in a pipe-separated field list.

**Parameters:**
- `$1` — Key to search for (e.g., "Status")
- `$2` — Pipe-separated list (e.g., "Status|state|status")

**Returns:** 0 if found, 1 if not found

**Example:**
```bash
if _generic_find_in_fields "Status" "Status|state|status|zustand"; then
  echo "Field found"
fi
```

---

### `_helper_modes_normalize(user_input)`

**Purpose:** Normalize user input to standard field name.

**Parameters:**
- `$1` — User input (can be number 1-4, partial name, etc)

**Returns:** Normalized field name on stdout

**Normalization:**
- "1" → "Beschreibung"
- "desc" → "Beschreibung" (partial match)
- "location" → "Location"
- "Status" → "Status" (already correct)

**Example:**
```bash
FIELD=$(_helper_modes_normalize "3")
echo "Selected field: $FIELD"  # Output: Status
```

---

### `_helper_fields_build_prompt(device_count)`

**Purpose:** Build a field selection prompt based on device type.

**Parameters:**
- `$1` — Device count (1 for Type 1, 2 for Type 2)

**Returns:** Prompt text on stdout

**Example:**
```bash
PROMPT=$(_helper_fields_build_prompt 1)
echo "$PROMPT"
# Output:
# [1] Beschreibung
# [2] Location
# [3] Status
# [4] Kategorie
```

---

## Device Operation Helpers

### `_helper_device_file_validate(device_file, device_id)`

**Purpose:** Ensure device file exists; error if not.

**Parameters:**
- `$1` — Path to device file
- `$2` — Device ID (for error messages)

**Returns:**
- 0 if file exists
- 1 if file doesn't exist (also logs error)

**Example:**
```bash
if _helper_device_file_validate "$DEVICE_FILE" "$device_id"; then
  echo "Device exists, proceeding..."
else
  return 1  # Error already logged
fi
```

---

### `_helper_validate_device_id_strict(device_id)`

**Purpose:** Validate device ID format (strict).

**Parameters:**
- `$1` — Device ID to validate

**Returns:**
- 0 if valid
- 1 if invalid

**Validation:**
- Rejects empty string
- Rejects `/` (path traversal)
- Rejects whitespace (space, tab, newline)
- Rejects `$` and `` ` `` (command injection)
- Rejects `"` and `'` (quote injection)
- Allows alphanumeric, hyphens, underscores

**Example:**
```bash
if _helper_validate_device_id_strict "SERVER_001"; then
  echo "Valid ID"
else
  error_logged "Invalid device ID"
fi
```

---

### `_helper_create_resolve_device_id(device_id)`

**Purpose:** Get or prompt for device ID in create workflow.

**Parameters:**
- `$1` — Device ID (can be empty)

**Returns:**
- If interactive and empty: prompts user, returns input
- If non-interactive and empty: returns 2 (usage error)
- Otherwise: returns device ID

**Example:**
```bash
device_id=$(_helper_create_resolve_device_id "$device_id")
```

---

### `_helper_create_assert_file_not_exists(device_file, device_id)`

**Purpose:** Ensure device doesn't already exist.

**Parameters:**
- `$1` — Path to device file
- `$2` — Device ID (for error messages)

**Returns:**
- 0 if file doesn't exist (OK to create)
- 1 if file exists (error, can't create duplicate)

**Example:**
```bash
if _helper_create_assert_file_not_exists "$DEVICE_FILE" "$device_id"; then
  # Create the device
  printf "Beschreibung=$desc\n" > "$DEVICE_FILE"
else
  return 1  # File already exists, error logged
fi
```

---

### `_helper_change_rewrite_file(file, key_prefix, new_value)`

**Purpose:** Update a field in a device file.

**Parameters:**
- `$1` — Path to device file
- `$2` — Key prefix (e.g., "Status=")
- `$3` — New value

**Behavior:**
- Reads file
- Replaces line matching key_prefix with "key_prefix=new_value"
- If key doesn't exist, appends it
- Uses atomic write-temp-then-rename

**Example:**
```bash
_helper_change_rewrite_file "devices/SERVER_001.txt" "Status=" "inactive"
# File now contains: Status=inactive
```

---

### `_helper_change_device_count_from_id(device_id)`

**Purpose:** Determine device type from ID.

**Parameters:**
- `$1` — Device ID

**Returns:**
- 1 if Type 1 (single device)
- 2 if Type 2 (collection)

**Example:**
```bash
COUNT=$(_helper_change_device_count_from_id "SERVER_001")
echo "Type: $COUNT"  # Output: 1
```

---

### `_helper_find_extract_id_from_file(filepath)`

**Purpose:** Extract device ID from file path.

**Parameters:**
- `$1` — Full file path (e.g., "/path/devices/SERVER_001.txt")

**Returns:** Device ID on stdout (e.g., "SERVER_001")

**Example:**
```bash
ID=$(_helper_find_extract_id_from_file "/devices/SERVER_001.txt")
echo "ID: $ID"  # Output: SERVER_001
```

---

### `_helper_find_file_matches_key_value(file, key_prefix, value)`

**Purpose:** Check if a device file matches a search criterion.

**Parameters:**
- `$1` — Path to device file
- `$2` — Key prefix to search (e.g., "Location=")
- `$3` — Value to match

**Returns:**
- 0 if file contains key with matching value (case-insensitive substring)
- 1 if no match

**Example:**
```bash
if _helper_find_file_matches_key_value "devices/SERVER_001.txt" "Location=" "Lab"; then
  echo "Device is in Lab"
fi
```

---

## User Input Helpers

### `read_logged(prompt)`

**Purpose:** Read user input with logging.

**Parameters:**
- `$1` — Prompt text

**Returns:** User input on stdout

**Behavior:**
- Displays the prompt on stderr so command substitutions capture only the
  entered value
- Reads line from stdin
- Logs the fact that input was read

**Example:**
```bash
DEVICE_ID=$(read_logged "Enter device ID: ")
echo "You entered: $DEVICE_ID"
```

---

### `_prompt_field(device_count)`

**Purpose:** Prompt user to select a field.

**Parameters:**
- `$1` — Device type (1 or 2)

**Returns:** Selected field name on stdout

**Behavior:**
- Shows numbered field list
- Prompts user to select by number or name
- Validates input
- Returns normalized field name

**Example:**
```bash
FIELD=$(_prompt_field 1)
# Displays:
# [1] Beschreibung
# [2] Location
# [3] Status
# [4] Kategorie
# Select field: 3
# Returns: "Status"
```

---

### `_prompt_field_value(field_name)`

**Purpose:** Prompt user for a field value.

**Parameters:**
- `$1` — Field name (e.g., "Status")

**Returns:** User input on stdout

**Behavior:**
- Prompts "Enter <field_name>: "
- Reads and validates input
- Returns value

**Example:**
```bash
STATUS=$(_prompt_field_value "Status")
# Prompt: "Enter Status: "
# User enters: "active"
# Returns: "active"
```

---

## Setup & Initialization

### `setup_logging()`

**Purpose:** Initialize logging system.

**Behavior:**
- Creates LOG_DIR if needed
- Creates or opens LOG_FILE
- Sets up trap handlers for errors
- Sets up trap handlers for exit cleanup

**Called automatically** by main functions, but can be called explicitly:
```bash
setup_logging || exit 2
```

---

## Utility Functions (awk/sed based)

### `_helper_output_stderr_and_log(message)`

**Purpose:** Output to stderr and log the message.

**Parameters:**
- `$1` — Message text

**Behavior:**
- Writes to stderr (appears to user)
- Also logs to LOG_FILE

**Used by:**
- `error_logged()` wraps this
- Internal error paths

---

## Function Index (All Helpers)

| Function | Purpose | Returns |
|----------|---------|---------|
| `log_debug()` | Log debug message | void |
| `log_info()` | Log info message | void |
| `log_warn()` | Log warning message | void |
| `log_error()` | Log error message | void |
| `_helper_log_timestamp()` | ISO-8601 timestamp | string |
| `_helper_log_escape_string()` | Escape log strings | string |
| `_helper_log_format_entry()` | Format log line | string |
| `_helper_log_rotate_if_needed()` | Rotate logs | 0/1 |
| `echo_logged()` | Print + log | void |
| `error_logged()` | Error + log | void |
| `_helper_core_is_interactive()` | Check if TTY | 0/1 |
| `_helper_core_is_type_1()` | Device type | 0/1 |
| `_generic_parse_field()` | Extract field value | string |
| `_generic_find_in_fields()` | Search field list | 0/1 |
| `_helper_modes_normalize()` | Normalize input | string |
| `_helper_fields_build_prompt()` | Build field prompt | string |
| `_helper_device_file_validate()` | Check file exists | 0/1 |
| `_helper_validate_device_id_strict()` | Validate ID | 0/1 |
| `_helper_create_resolve_device_id()` | Get/prompt ID | string |
| `_helper_create_assert_file_not_exists()` | Check no duplicate | 0/1 |
| `_helper_change_rewrite_file()` | Update field | void |
| `_helper_change_device_count_from_id()` | Get device type | 1/2 |
| `_helper_find_extract_id_from_file()` | Extract ID from path | string |
| `_helper_find_file_matches_key_value()` | Check match | 0/1 |
| `read_logged()` | Read input + log | string |
| `_prompt_field()` | Prompt field select | string |
| `_prompt_field_value()` | Prompt field value | string |
| `setup_logging()` | Init logging | void |

---

## Common Patterns

### Check and Error Pattern

```bash
if ! _helper_device_file_validate "$DEVICE_FILE" "$device_id"; then
  # Error already logged by _helper_device_file_validate
  return "$EXIT_ERROR"
fi
# Continue with operation
```

### Validate Input Pattern

```bash
if ! _helper_validate_device_id_strict "$device_id"; then
  error_logged "ERROR (my_func): invalid device ID '$device_id'"
  return "$EXIT_USAGE_ERROR"
fi
```

### Parse and Use Pattern

```bash
LOCATION=$(_generic_parse_field "$DEVICE_FILE" "Location=")
if [[ -z "$LOCATION" ]]; then
  log_warn "Device missing Location field: $device_id"
  LOCATION="unknown"
fi
echo "Location: $LOCATION"
```

---

## Module locations

| Area | Module |
|------|--------|
| Logging and traps | `modules/logging.sh` |
| Input/output | `modules/io.sh` |
| Fields and modes | `modules/fields.sh` |
| Validation and change prompts | `modules/validators.sh` |
| Atomic file updates | `modules/device_ops.sh` |
| Create and find workflows | `modules/create.sh`, `modules/find.sh` |
| Public mains | `modules/mains.sh` |
| Collection counts | `modules/count.sh` |
| Non-interactive dispatch | `modules/cli.sh` |

`experimental.sh` remains a source-compatible loading shim. It is not the
implementation location for new helpers.

## Modification Guidelines

When adding new helper functions:

1. **Prefix appropriately:**
   - `_helper_*` for general utilities
   - `_generic_*` for field/data operations
   - `_prompt_*` for user input
   - `_section_*` for code organization

2. **Follow return conventions:**
   - Success: 0 or return value on stdout
   - Error: 1 or 2, log error first

3. **Document in header:**
   - Description
   - Parameters
   - Return value
   - Usage example

4. **Log operations:**
   - Use `log_debug()` for entry/exit
   - Use `log_error()` for failures
   - Use `log_info()` for state changes

5. **Keep functions small:**
   - Single responsibility principle
   - Easier to test and reuse
   - Better readability
