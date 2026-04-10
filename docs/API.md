# API Reference: Public Functions

## Overview

This document describes the public API of the Bash Device Manager. All user-facing operations go through these main functions.

**Location:** `experimental.sh`
**Exit Codes:** 0=success, 1=error, 2=usage error

---

## Main Functions

### `create_device_main`

**Description:** Create a new device.

**Signature:**
```bash
create_device_main [device_id]
```

**Parameters:**
- `$1` (optional): Device ID (string). If omitted, prompts interactively.

**Returns:**
- 0 (EXIT_OK) — Device created successfully
- 1 (EXIT_ERROR) — Device ID already exists, validation failed
- 2 (EXIT_USAGE_ERROR) — Invalid device ID format

**Behavior:**
- **Interactive:** Prompts user for device ID, then for each field
- **Non-interactive:** Requires device_id argument; reads fields from stdin or uses defaults

**Logs:**
- INFO on success: `"Device created: ID=<id>"`
- ERROR on failure: `"device '<id>' already exists"` or validation error

**Example:**
```bash
# Interactive
./runner.sh 1
create_device_main

# Non-interactive
create_device_main "SERVER_001"
```

---

### `read_device_main`

**Description:** Read and display a device by ID.

**Signature:**
```bash
read_device_main device_id
```

**Parameters:**
- `$1` (required): Device ID to look up

**Returns:**
- 0 (EXIT_OK) — Device found and displayed
- 1 (EXIT_ERROR) — Device not found
- 2 (EXIT_USAGE_ERROR) — Missing device_id argument

**Behavior:**
- Looks up device file by ID
- Displays all fields in readable format
- Logs lookup operation

**Logs:**
- INFO: `"read_device_main: reading device_id='<id>'"`
- ERROR if not found: `"device '<id>' not found"`

**Example:**
```bash
read_device_main "SERVER_001"
# Output:
# Device: SERVER_001
# Beschreibung: Test Server
# Location: Lab A
# Status: active
```

---

### `change_device_main`

**Description:** Modify a field in an existing device.

**Signature:**
```bash
change_device_main [device_id] [field] [new_value]
```

**Parameters:**
- `$1` (optional): Device ID. If omitted, prompts interactively.
- `$2` (optional): Field name or number (1-4). If omitted, prompts.
- `$3` (optional): New field value. If omitted, prompts.

**Returns:**
- 0 (EXIT_OK) — Field changed successfully
- 1 (EXIT_ERROR) — Device not found, invalid field
- 2 (EXIT_USAGE_ERROR) — Missing arguments in non-interactive mode

**Behavior:**
- **Interactive:** Prompts for device ID, field, and new value
- **Non-interactive:** All three arguments required
- Validates device exists before modification
- Rewrites device file with updated field

**Logs:**
- INFO on success: `"Field updated: <field>=<new_value>"`
- ERROR on failure: descriptive message with recovery hint

**Field Numbers:**
- Type 1 devices: 1=Beschreibung, 2=Location, 3=Status, 4=Kategorie
- Type 2 devices: 1=Beschreibung, 2=Anzahl, 3=Location, 4=Kategorie

**Example:**
```bash
# Interactive
./runner.sh 2
change_device_main

# Non-interactive
change_device_main "SERVER_001" "Status" "maintenance"
change_device_main "SERVER_001" "3" "inactive"
```

---

### `find_device_main`

**Description:** Search for devices by multiple criteria.

**Signature:**
```bash
find_device_main [search_mode] [search_value]
```

**Parameters:**
- `$1` (optional): Search mode: `id=`, `desc=`, `location=`, `status=`, `kategorie=`, `anzahl=`
- `$2` (optional): Search value (string to match)

**Returns:**
- 0 (EXIT_OK) — Devices found
- 1 (EXIT_ERROR) — No devices found
- 2 (EXIT_USAGE_ERROR) — Missing arguments in non-interactive mode

**Behavior:**
- **Interactive:** Prompts for search criteria
- **Non-interactive:** Both arguments required
- Performs case-insensitive substring matching
- Returns all matching device IDs and a preview of each

**Search Modes:**
- `id=` — Search by device ID (exact or substring)
- `desc=` — Search by Beschreibung (description)
- `location=` — Search by Location
- `status=` — Search by Status
- `kategorie=` — Search by Kategorie (category)
- `anzahl=` — Search by Anzahl (count, numeric comparison)

**Logs:**
- INFO: `"find_device_main: mode='<mode>' value='<value>'"`
- INFO: `"Found N device(s)"`

**Example:**
```bash
# Interactive
./runner.sh 3
find_device_main

# Non-interactive
find_device_main "id=" "SERVER"
find_device_main "location=" "Lab"
find_device_main "status=" "active"

# Output:
# Found 2 device(s):
#   SERVER_001: Test Server
#   SERVER_002: Production Server
```

---

### `find_and_change_main`

**Description:** Find a device and modify it in one operation.

**Signature:**
```bash
find_and_change_main [search_mode] [search_value] [field] [new_value]
```

**Parameters:**
- `$1` (optional): Search mode (same as find_device_main)
- `$2` (optional): Search value
- `$3` (optional): Field name/number to change
- `$4` (optional): New value

**Returns:**
- 0 (EXIT_OK) — Device found and changed
- 1 (EXIT_ERROR) — Device not found, multiple matches, invalid field
- 2 (EXIT_USAGE_ERROR) — Missing arguments

**Behavior:**
- First finds device matching search criteria
- If exactly one match, modifies the specified field
- If multiple or no matches, returns error (requires finding first)
- Useful for quick find-then-modify workflows

**Logs:**
- INFO: `"find_and_change: found <id>, updating field=<field>"`
- ERROR: `"found N devices; cannot auto-select"` (if not unique)

**Example:**
```bash
# Find devices with "active" status and set to "maintenance"
find_and_change_main "status=" "active" "Status" "maintenance"
```

---

### `change_count_main`

**Description:** Increment or decrement the Anzahl (count) field for collection devices (Type 2).

**Signature:**
```bash
change_count_main [device_id] [operation] [amount]
```

**Parameters:**
- `$1` (optional): Device ID (must be Type 2 collection)
- `$2` (optional): Operation: `+` (increment), `-` (decrement)
- `$3` (optional): Amount (integer)

**Returns:**
- 0 (EXIT_OK) — Count changed successfully
- 1 (EXIT_ERROR) — Device not found, not a collection, invalid operation
- 2 (EXIT_USAGE_ERROR) — Missing arguments

**Behavior:**
- **Interactive:** Prompts for device ID, operation, amount
- **Non-interactive:** All three arguments required
- Only works for Type 2 devices (detected by device ID format)
- Validates new count is non-negative

**Device Type Detection:**
- Type 1: Numeric ID (e.g., 123, 1001) — cannot change count
- Type 2: Alphanumeric ID (e.g., LAN_CABLE_50M) — can change count

**Logs:**
- INFO on success: `"Anzahl updated: <old> → <new>"`
- ERROR if Type 1 device: `"device 'ID' is not a collection (type 1)"`

**Example:**
```bash
# Interactive
./runner.sh 5
change_count_main

# Non-interactive
change_count_main "LAN_CABLE_50M" "+" "10"    # Add 10 cables
change_count_main "SCREW_M4_1000" "-" "50"    # Remove 50 screws
```

---

## Exit Code Reference

| Code | Meaning | When Used |
|------|---------|-----------|
| 0 | SUCCESS | Operation completed as expected |
| 1 | ERROR | Logic error (device not found, validation failed, no matches) |
| 2 | USAGE_ERROR | User provided wrong arguments (missing required arg, bad format) |

**Shell check pattern:**
```bash
if create_device_main "TEST_ID"; then
  echo "Device created successfully"
elif [[ $? -eq 2 ]]; then
  echo "Usage error - missing or invalid arguments"
else
  echo "Logic error - device already exists"
fi
```

---

## Error Message Format

All error messages follow this pattern:

```
ERROR (function_name): description. Recovery hint (exit code: X)
```

**Examples:**

```
ERROR (create_device_main): invalid device ID 'BAD/ID'. 
Device IDs must be alphanumeric with optional hyphens/underscores. (exit code: 2)

ERROR (read_device_main): device 'SERVER_999' not found. 
Use 'find' to list devices or 'create' to add new one. (exit code: 1)

ERROR (find_device_main): no devices found in /path/to/devices. 
Use 'create' to add new device. (exit code: 1)
```

---

## Device Type Specifications

### Type 1: Single Device

**ID Format:** Numeric (e.g., 123, 1001, 999)

**Standard Fields:**
| # | Field Name | Description | Example |
|---|------------|-------------|---------|
| 1 | Beschreibung | Description | Server Production |
| 2 | Location | Physical location | DataCenter Rack 3 |
| 3 | Status | Current status | active, inactive, maintenance |
| 4 | Kategorie | Category/type | Server, Router, Workstation |

**Optional Fields:**
- Seriennummer — Serial number
- Zustand — Condition (good, needs_repair, retired)
- IPAdresse — IP address
- Hostname — DNS name
- Betriebssystem — OS/software

### Type 2: Collection/Bulk

**ID Format:** Alphanumeric (e.g., LAN_CABLE_50M, SCREW_M4_1000)

**Standard Fields:**
| # | Field Name | Description | Example |
|---|------------|-------------|---------|
| 1 | Beschreibung | Description | 50-meter network cables |
| 2 | Anzahl | Quantity/count | 125 |
| 3 | Location | Storage location | Storage Bin A |
| 4 | Kategorie | Category | Network, Hardware, Consumables |

**Optional Fields:**
- Einheit — Unit (meters, pieces, kg)
- Preis — Unit price
- Verfallsdatum — Expiration date
- Mindestbestand — Minimum stock level

---

## Common Usage Patterns

### List All Devices

```bash
find_device_main "id=" ""    # Search by empty ID (matches all)
```

### Find Specific Device and Show Details

```bash
find_device_main "id=" "SERVER_001"
read_device_main "SERVER_001"
```

### Find and Modify in One Step

```bash
# Find all servers, change first one's status
find_device_main "kategorie=" "Server"
change_device_main "SERVER_001" "Status" "maintenance"

# Or combined:
find_and_change_main "id=" "SERVER_001" "Status" "maintenance"
```

### Bulk Update Collection Counts

```bash
change_count_main "LAN_CABLE_50M" "+" "100"
change_count_main "SCREW_M4_1000" "-" "250"
change_count_main "USB_CABLE" "+" "50"
```

### Scripted Workflow

```bash
#!/bin/bash
set -euo pipefail
source experimental.sh

# Create 3 devices
create_device_main "SERVER_001" || true
create_device_main "SERVER_002" || true
create_device_main "LAN_CABLE_50M" || true

# Find all devices by category
find_device_main "kategorie=" "Server"

# Update counts
change_count_main "LAN_CABLE_50M" "+" "10"

# Search and modify
find_and_change_main "id=" "SERVER_001" "Status" "active"
```

---

## Logging in API Calls

All main functions log their operations to `$LOG_FILE` (default: `logs/device_manager.log`).

Log entries include:
- ISO-8601 timestamp
- Log level (INFO, ERROR, WARN)
- PID and function name
- User-readable message

**Example log output:**
```
2026-04-10T08:15:42Z [INFO] (PID 1234) [create_device_main:1087] Device created: ID=SERVER_001
2026-04-10T08:15:43Z [DEBUG] (PID 1234) [change_device_main:800] Updating field Status to 'active'
2026-04-10T08:15:44Z [ERROR] (PID 1234) [read_device_main:730] device 'BAD_ID' not found
```

---

## Environment Variables Used

| Variable | Default | Purpose |
|----------|---------|---------|
| DEVICE_DIR | devices/ | Directory containing device files |
| LOG_FILE | logs/device_manager.log | Log file path |
| LOG_MAX_SIZE | 10485760 (10 MB) | Max log file size before rotation |
| LOG_KEEP_DAYS | 7 | Days of rotated logs to keep |
| TRACE_COMMANDS | 0 | Enable debug tracing (1 = on) |

---

## Backward Compatibility

This API is designed for long-term stability:

- Function signatures are fixed (new params added as optional only)
- Exit codes are standardized (0, 1, 2)
- Device file format is fixed (key=value, one per line)
- Main functions preserved across versions
- Deprecated functions removed only after explicit notice

---

## Version Support

| Version | Status | API Changes |
|---------|--------|------------|
| 1.0 | Current | Initial standardized API |
| 1.1 | Current | Added exit code constants, improved error messages |
| 2.0 | Planned | (No breaking changes anticipated) |

---

## Questions & Support

For questions about using the API:
1. Check `INTERNALS.md` for helper function details
2. Review test files in `tests/` for usage examples
3. Consult `OPERATIONS.md` for troubleshooting
4. Check log file for error details and context
