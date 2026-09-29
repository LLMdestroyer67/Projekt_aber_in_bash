# API Reference: Public Functions

## Overview

This document describes the public API of the Bash Device Manager. All user-facing operations go through these main functions.

**Location:** `geraeteverwaltung_funktionen.sh` (loads the implementation in `modules/`; `experimental.sh` remains a compatibility shim)
**Exit Codes:** 0=success, 1=error, 2=usage error

## Canonical German API

German ASCII identifiers are the canonical public names. The English names
remain callable wrappers with unchanged signatures and exit codes.

| Canonical name | Compatible legacy name |
|---|---|
| `geraet_anlegen` | `create_device_main` |
| `geraet_anzeigen` | `read_device_main` |
| `geraet_aendern` | `change_device_main` |
| `geraet_suchen` | `find_device_main` |
| `geraet_suchen_und_aendern` | `find_and_change_main` |
| `geraet_suchen_und_aendern_menue` | `find_and_change_menu_main` |
| `bestand_aendern` | `change_count_main` |
| `bestand_fuer_geraet_aendern` | `change_device_count` |
| `befehl_ausfuehren` | `run_cli` |
| `geraetedaten_migrieren` | `migrate_inventory_main` |

The signatures and exit codes below describe both spellings. Prefer the
canonical German names in new scripts.

---

## Main Functions

### `geraetedaten_migrieren`

**Description:** Preview or explicitly apply known legacy inventory field-key
migrations.

**Signature:**
```bash
geraetedaten_migrieren [--anwenden]
```

**Behavior:**
- With no option, reports which device files would be migrated and does not
  modify data.
- With `--anwenden` (or legacy `--apply`), creates a sibling backup and
  atomically replaces files using canonical German field keys.
- Checks all files for duplicate aliases before applying any migration;
  collisions fail without changing inventory files.
- Preserves unknown fields and is idempotent.

The CLI equivalent is `./geraeteverwaltung.sh daten-migrieren [--anwenden]`; `migrate`
remains accepted as a legacy command.

### `geraet_anlegen`

Legacy alias: `create_device_main`.

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
./geraeteverwaltung.sh
geraet_anlegen

# Non-interactive
geraet_anlegen "SERVER_001"
```

---

### `geraet_anzeigen`

Legacy alias: `read_device_main`.

**Description:** Read and display a device by ID.

**Signature:**
```bash
geraet_anzeigen geraete_id
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
- INFO: `"geraet_anzeigen: reading geraete_id='<id>'"`
- ERROR if not found: `"device '<id>' not found"`

**Example:**
```bash
geraet_anzeigen "SERVER_001"
# Output:
# Device: SERVER_001
# Beschreibung: Test Server
# Standort: Lab A
# Status: active
```

---

### `geraet_aendern`

Legacy alias: `change_device_main`.

**Description:** Modify a field in an existing device.

**Signature:**
```bash
geraet_aendern [geraete_id] [feld] [neuer_wert]
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
- Type 1 devices: 1=Beschreibung, 2=Standort, 3=Status, 4=Kategorie
- Type 2 devices: 1=Beschreibung, 2=Anzahl, 3=Standort, 4=Kategorie

**Example:**
```bash
# Interactive
./geraeteverwaltung.sh
geraet_aendern

# Non-interactive
geraet_aendern "SERVER_001" "Status" "maintenance"
geraet_aendern "SERVER_001" "3" "inactive"
```

---

### `geraet_suchen`

Legacy alias: `find_device_main`. Canonical modes are `geraete_id`,
`beschreibung`, `standort`, `status`, `kategorie`, `besitzer`,
`seriennummer`, `sap-id`, `hersteller`, `modell`, `anschaffungsdatum`,
`ausmusterungsdatum`, and `einkaufswert`. Historical modes such as `id`,
`description`, and `location` remain accepted.

**Description:** Search for devices by multiple criteria.

**Signature:**
```bash
geraet_suchen [suchmodus] [suchwert]
```

**Parameters:**
- `$1` (optional): Search mode such as `geraete_id`, `beschreibung`,
  `standort`, `status`, or `kategorie` (English spellings remain aliases)
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
- `geraete_id` — Search by device ID (exact or substring)
- `beschreibung` — Search by Beschreibung
- `standort` — Search by Standort
- `status` — Search by Status
- `kategorie` — Search by Kategorie
- `anzahl` — Search by Anzahl

**Logs:**
- INFO: `"find_device_main: mode='<mode>' value='<value>'"`
- INFO: `"Found N device(s)"`

**Example:**
```bash
# Interactive
./geraeteverwaltung.sh
geraet_suchen

# Non-interactive
geraet_suchen "geraete_id" "SERVER"
geraet_suchen "standort" "Lab"
geraet_suchen "status" "active"

# Output:
# Found 2 device(s):
#   SERVER_001: Test Server
#   SERVER_002: Production Server
```

---

### `geraet_suchen_und_aendern`

Legacy alias: `find_and_change_main`.

**Description:** Find a device and modify it in one operation.

**Signature:**
```bash
geraet_suchen_und_aendern [suchmodus] [suchwert] [feld] [neuer_wert]
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
geraet_suchen_und_aendern "status" "active" "Status" "maintenance"
```

---

### `bestand_aendern`

Legacy alias: `change_count_main`.

**Description:** Find a unique collection device and interactively change its
`Anzahl` field.

**Signature:**
```bash
bestand_aendern [suchmodus] [suchwert]
```

**Parameters:**
- `$1` (optional): Search mode accepted by `find_device_main` (for example
  `id`, `location`, or `kategorie`). In interactive mode, this is prompted.
- `$2` (optional): Search value. In interactive mode, this is prompted.

**Returns:**
- 0 (EXIT_OK) — A unique collection device was found and its count changed
- 1 (EXIT_ERROR) — No device was found, or the selected device is not a
  collection
- 2 (EXIT_USAGE_ERROR) — Missing or invalid search input, or ambiguous result

**Behavior:**
- Searches using the same mode/value handling as `find_device_main`.
- Requires exactly one matching device.
- Prompts for the count operation and new value through
  `change_device_count`.
- Only collection devices (alphanumeric IDs with `Anzahl=`) can be changed.

**Device Type Detection:**
- Type 1: Numeric ID (e.g., 123, 1001) — cannot change count
- Type 2: Alphanumeric ID (e.g., LAN_CABLE_50M) — can change count

**Logs:**
- INFO on success: `"Anzahl updated: <old> → <new>"`
- ERROR if Type 1 device: `"device 'ID' is not a collection (type 1)"`

**Example:**
```bash
# Interactive
./geraeteverwaltung.sh
# Choose "find and change", then select the count operation
bestand_aendern

# Non-interactive
printf '1\n1\n10\n' | bestand_aendern "geraete_id" "LAN_CABLE_50M"
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
| 2 | Standort | Physical location | DataCenter Rack 3 |
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
| 3 | Standort | Storage location | Storage Bin A |
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
geraet_suchen "geraete_id" ""    # Search by empty ID (matches all)
```

### Find Specific Device and Show Details

```bash
geraet_suchen "geraete_id" "SERVER_001"
geraet_anzeigen "SERVER_001"
```

### Find and Modify in One Step

```bash
# Find all servers, change first one's status
geraet_suchen "kategorie" "Server"
geraet_aendern "SERVER_001" "Status" "maintenance"

# Or combined:
geraet_suchen_und_aendern "geraete_id" "SERVER_001" "Status" "maintenance"
```

### Bulk Update Collection Counts

```bash
printf '1\n1\n100\n' | bestand_aendern "geraete_id" "LAN_CABLE_50M"
```

### Scripted Workflow

```bash
#!/bin/bash
set -euo pipefail
source geraeteverwaltung_funktionen.sh

# Create 3 devices
geraet_anlegen "SERVER_001" || true
geraet_anlegen "SERVER_002" || true
geraet_anlegen "LAN_CABLE_50M" || true

# Find all devices by category
geraet_suchen "kategorie" "Server"

# Update a count (the operation/value are read from stdin)
printf '1\n1\n10\n' | bestand_aendern "geraete_id" "LAN_CABLE_50M"

# Search and modify
geraet_suchen_und_aendern "geraete_id" "SERVER_001" "Status" "active"
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
| `GERAETE_VERZEICHNIS` (`DEVICE_DIR`) | devices/ | Directory containing device files |
| `PROTOKOLL_VERZEICHNIS` (`LOG_DIR`) | logs/ | Directory containing logs |
| `PROTOKOLL_DATEI` (`LOG_FILE`) | logs/device_manager.log | Log file path |
| `PROTOKOLL_MAX_GROESSE` (`LOG_MAX_SIZE`) | 10485760 (10 MB) | Max log size before rotation |
| `PROTOKOLL_BEWAHRUNGS_TAGE` (`LOG_KEEP_DAYS`) | 7 | Days to keep rotated logs |
| `BEFEHLS_TRACE` (`TRACE_COMMANDS`) | 0 | Enable debug tracing (1 = on) |
| `LAUF_INTERVALL_SEKUNDEN` (`RUN_INTERVAL_SECONDS`) | 2 in runner | Interactive-loop delay |
| `GERAETE_SPERRE_WARTESEKUNDEN` (`DEVICE_LOCK_TIMEOUT_SECONDS`) | 10 | Device lock wait timeout |

If both names are supplied when the library/runner starts, the German
configuration variable takes precedence. The English variable remains
available for existing deployments.

## Canonical command-line interface

`geraeteverwaltung.sh` accepts the canonical commands `geraet-anlegen`,
`geraet-aendern`, `geraet-suchen`, `geraet-anzeigen`, and `bestand-aendern`.
The legacy commands `create`, `change`, `find`, `read`, `find-and-change`,
`change-count`, and their historical underscore variants remain supported.
`runner.sh` remains a compatibility wrapper for `geraeteverwaltung.sh`.

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
