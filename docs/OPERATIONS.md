# Operations Guide: Deployment & Troubleshooting

## Installation & Setup

### Prerequisites

- **Bash 4.0+** — Required for arrays and nameref (check with `bash --version`)
- **GNU coreutils** — For date, sort, mktemp (standard on Linux/macOS)
- **Utilities:** grep, awk, sed (standard on all Unix systems)

### Quick Start

```bash
# 1. Clone or download the repository
cd /path/to/Projekt_aber_in_bash

# 2. Verify directory structure
ls -la runner.sh experimental.sh devices/ logs/

# 3. Make scripts executable
chmod +x runner.sh experimental.sh

# 4. Set environment variables (optional, defaults provided)
export DEVICE_DIR="./devices"
export LOG_DIR="./logs"
export LOG_MAX_SIZE=10485760     # 10 MB
export LOG_KEEP_DAYS=7

# 5. Run interactively
./runner.sh
```

### Directory Setup

```bash
# Ensure required directories exist
mkdir -p ./devices
mkdir -p ./logs

# Set permissions (device dir should be readable/writable)
chmod 755 ./devices ./logs

# Verify setup
ls -ld ./devices ./logs
```

---

## Running the Application

### Interactive Mode (Default)

```bash
./runner.sh
```

**Output:**
```
═══════════════════════════════════════════════════════════════
                   Device Manager - Main Menu
═══════════════════════════════════════════════════════════════

1. Create device
2. Change device
3. Find device
4. Find and change
5. Change count (Anzahl) for collections

Enter selection (1-5) or 'q' to quit: 
```

**Usage:**
1. Enter a number (1-5) and press Enter
2. Follow prompts for device ID, fields, values
3. Results are displayed and logged
4. Returns to menu for next operation

### Non-Interactive Mode

```bash
# Pass arguments directly (no prompts)
./runner.sh create SERVER_001
./runner.sh find "id=" "SERVER"
./runner.sh change SERVER_001 Status active
./runner.sh count LAN_CABLE_50M + 10
```

**Exit codes:**
- 0 — Success
- 1 — Logic error (device not found, etc)
- 2 — Usage error (wrong arguments)

**Example in scripts:**
```bash
#!/bin/bash
if ./runner.sh find "id=" "SERVER_001"; then
    echo "Device found"
else
    echo "Not found (exit code: $?)"
fi
```

---

## Configuration

### Environment Variables

Set these before running to customize behavior:

```bash
# Device storage location
export DEVICE_DIR="/data/devices"       # Default: ./devices

# Logging configuration
export LOG_DIR="/var/log/device_mgr"    # Default: ./logs
export LOG_FILE="$LOG_DIR/devices.log"  # Default: LOG_DIR/device_manager.log

# Log rotation (automatic)
export LOG_MAX_SIZE=10485760            # Default: 10 MB (bytes)
export LOG_KEEP_DAYS=7                  # Default: 7 days

# Debug/runtime
export TRACE_COMMANDS=1                 # 0 (off) or 1 (on) - enables `set -x`
export RUN_INTERVAL_SECONDS=30          # For daemon polling (if used)
```

### Persistent Configuration

Create a setup script to avoid re-entering variables:

```bash
# ~/.bashrc or /etc/profile.d/device_manager.sh
export DEVICE_DIR="/home/admin/device_manager/devices"
export LOG_DIR="/home/admin/device_manager/logs"
export LOG_MAX_SIZE=52428800            # 50 MB
export LOG_KEEP_DAYS=14                 # 2 weeks
```

Then source it before running:
```bash
source ~/.bashrc
./runner.sh
```

---

## Log Management

### Log File Location

Default: `logs/device_manager.log`

Override with:
```bash
export LOG_DIR="/custom/path"
./runner.sh
```

### Log Format

Each line contains:

```
TIMESTAMP [LEVEL] (PID) [FUNCTION:LINE] MESSAGE
```

**Example:**
```
2026-04-10T08:15:42Z [INFO] (PID 1234) [create_device_main:1087] Device created: ID=SERVER_001
2026-04-10T08:15:43Z [DEBUG] (PID 1234) [_helper_create_validate:1105] Validated device ID='SERVER_001'
2026-04-10T08:15:44Z [ERROR] (PID 1234) [read_device_main:730] device 'SERVER_999' not found
```

### Log Levels

| Level | Color | Usage | Example |
|-------|-------|-------|---------|
| DEBUG | Gray | Detailed execution trace | Variable values, function entry/exit |
| INFO | Blue | Operation success | "Device created", "Field updated" |
| WARN | Yellow | Non-fatal issues | "File missing expected field" |
| ERROR | Red | Operation failed | "Device not found", "Validation error" |

### Viewing Logs

```bash
# View last 50 lines
tail -50 logs/device_manager.log

# View logs in real-time (follow mode)
tail -f logs/device_manager.log

# Search for errors
grep ERROR logs/device_manager.log

# Search for specific device
grep "SERVER_001" logs/device_manager.log

# Count operations by type
grep "created\|changed\|found" logs/device_manager.log | wc -l

# Show logs from last 10 minutes
find logs -name "device_manager.log*" -mmin -10 -exec cat {} \;
```

### Log Rotation

**Automatic rotation** triggered when log file size ≥ `LOG_MAX_SIZE`:

```
device_manager.log     (current, being written)
device_manager.log.1   (rotated today)
device_manager.log.2   (rotated yesterday)
...
device_manager.log.7   (oldest, kept)
device_manager.log.8   (deleted if exists)
```

**Manual rotation:**
```bash
# Create backup
cp logs/device_manager.log logs/device_manager.log.backup.$(date +%s)

# Clear current log
> logs/device_manager.log

# Remove old rotated logs
rm -f logs/device_manager.log.{8..99}
```

---

## Troubleshooting

### Issue: "Command not found: runner.sh"

**Cause:** Script not in PATH or not executable

**Solution:**
```bash
# Make executable
chmod +x runner.sh

# Run with full path
/path/to/runner.sh

# Or add to PATH
export PATH="/path/to/Projekt_aber_in_bash:$PATH"
runner.sh
```

---

### Issue: "Device not found" error

**Cause:** Device file doesn't exist or ID is wrong

**Solution:**
```bash
# 1. Find all devices
./runner.sh
# Select "Find device" option

# 2. Or search directly
./runner.sh find "id=" ""    # Lists all devices

# 3. Check file directly
ls -l devices/

# 4. Verify device ID format
# Type 1: numeric (123, 1001)
# Type 2: alphanumeric (LAN_CABLE_50M)
```

---

### Issue: "Invalid device ID" rejected

**Cause:** ID contains forbidden characters

**Forbidden characters:**
- `/` (path traversal)
- Space, tab, newline
- `$` (command injection)
- `` ` `` (command substitution)
- `"` `'` (quote injection)

**Solution:** Use only alphanumeric, hyphens (-), underscores (_)

```bash
# Bad IDs (will be rejected)
SERVER-001/PROD
SERVER 001
DEVICE$1
DEVICE`whoami`

# Good IDs (will be accepted)
SERVER_001
SERVER-001
SERVER001
LAN_CABLE_50M
SCREW_M4_1000
```

---

### Issue: Permission denied on logs/

**Cause:** Directory not writable

**Solution:**
```bash
# Check permissions
ls -ld logs/

# Make writable
chmod 755 logs/

# Or fix owner
chown $USER:$USER logs/
```

---

### Issue: "Can't find device_manager.log"

**Cause:** LOG_DIR doesn't exist

**Solution:**
```bash
# Create logs directory
mkdir -p ./logs
chmod 755 ./logs

# Or set custom path
export LOG_DIR="/var/log/device_mgr"
mkdir -p "$LOG_DIR"
```

---

### Issue: Log file grows too large

**Cause:** Log rotation not triggered (file size check)

**Solution:**
```bash
# Check log size
du -h logs/device_manager.log

# Manual rotation
cp logs/device_manager.log logs/device_manager.log.backup
> logs/device_manager.log

# Or adjust rotation threshold
export LOG_MAX_SIZE=5242880    # 5 MB instead of 10 MB
./runner.sh
```

---

### Issue: Script crashes silently

**Cause:** Error not captured, exit trap not working

**Solution:**
```bash
# 1. Enable debug output
bash -x runner.sh 2>&1 | tee debug.log

# 2. Check logs
tail -50 logs/device_manager.log

# 3. Verify Bash version (need 4+)
bash --version

# 4. Check disk space
df -h .

# 5. Test individual functions
source experimental.sh
create_device_main "TEST_ID"
echo "Exit code: $?"
```

---

### Issue: Concurrent runners corrupt files

**Cause:** Single-threaded design, no file locking

**This is a known limitation.** Multiple runner.sh processes accessing same devices will corrupt data.

**Solution:**
- Run only one process at a time
- Use external locking (flock)
- Wrap with a mutex script:

```bash
#!/bin/bash
LOCK="/tmp/device_manager.lock"

# Acquire lock
exec 200>"$LOCK"
flock -x 200

# Run command
./runner.sh "$@"
EXIT=$?

# Release lock
flock -u 200
exit $EXIT
```

Usage:
```bash
./run_with_lock.sh find "id=" "SERVER"
./run_with_lock.sh create SERVER_002
```

---

## Testing

### Run Full Test Suite

```bash
cd tests/
bash run_all_tests.sh
```

**Output shows:**
- Test sections (Device ID Validation, CRUD ops, etc)
- Pass/fail for each assertion
- Summary at end

### Run Individual Test Files

```bash
bash test_validation.sh
bash test_fields.sh
bash test_device_crud.sh
bash test_find.sh
bash test_logging.sh
bash test_edge_cases.sh
bash test_integration.sh
```

### Test Coverage

- **65+ test cases** covering:
  - Device ID validation
  - Field parsing
  - CRUD operations
  - Search/find
  - Logging
  - Edge cases (empty files, Unicode, large values)
  - End-to-end workflows

---

## Monitoring & Health Checks

### Verify System Health

```bash
#!/bin/bash
set -euo pipefail

echo "Device Manager Health Check"
echo "============================"

# Check directories exist
[[ -d "devices" ]] && echo "✓ devices/ exists" || echo "✗ devices/ missing"
[[ -d "logs" ]] && echo "✓ logs/ exists" || echo "✗ logs/ missing"

# Check scripts executable
[[ -x runner.sh ]] && echo "✓ runner.sh executable" || echo "✗ runner.sh not executable"
[[ -x experimental.sh ]] && echo "✓ experimental.sh executable" || echo "✗ experimental.sh not executable"

# Check recent logs
RECENT=$(find logs -name "device_manager.log*" -mmin -60)
if [[ -n "$RECENT" ]]; then
    echo "✓ Recent log activity (< 60 min)"
else
    echo "? No recent log activity"
fi

# Count devices
DEVICE_COUNT=$(find devices -name "*.txt" 2>/dev/null | wc -l)
echo "ℹ Devices stored: $DEVICE_COUNT"

# Check log size
LOG_SIZE=$(du -h logs/device_manager.log 2>/dev/null | cut -f1)
echo "ℹ Log file size: $LOG_SIZE"

echo "============================"
echo "Health check complete"
```

Run as:
```bash
bash health_check.sh
```

---

## Performance Tuning

### For Large Device Inventories (1000+ devices)

```bash
# Increase log rotation size
export LOG_MAX_SIZE=52428800            # 50 MB

# Reduce log verbosity (optional)
# Note: This requires code changes, not config

# Use faster storage
export DEVICE_DIR="/ssd/devices"        # If available

# Consider caching (Phase 3 enhancement)
```

### Profiling a Slow Operation

```bash
# Time a find operation
time ./runner.sh find "id=" "SERVER"

# Profile with bash tracing
time bash -x ./runner.sh find "id=" "SERVER" 2>&1 | tee profile.log

# Analyze profile log
sort profile.log | uniq -c | sort -rn | head -20
```

---

## Backup & Recovery

### Backup Strategy

```bash
#!/bin/bash
BACKUP_DIR="./backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

mkdir -p "$BACKUP_DIR"

# Backup devices
tar czf "$BACKUP_DIR/devices_$TIMESTAMP.tar.gz" devices/

# Backup logs
tar czf "$BACKUP_DIR/logs_$TIMESTAMP.tar.gz" logs/

echo "Backup complete: $BACKUP_DIR/devices_$TIMESTAMP.tar.gz"
```

Run regularly (e.g., daily cron job):
```bash
0 2 * * * /path/to/backup.sh
```

### Restore from Backup

```bash
# List available backups
ls -lh backups/

# Restore devices to a point-in-time
tar xzf backups/devices_20260410_020000.tar.gz

# Verify restoration
ls devices/ | head -10
```

---

## Scheduling with Cron

### Periodic Device Audits

```bash
# /etc/cron.d/device_manager
# Run device inventory check every day at 6 AM
0 6 * * * /path/to/Projekt_aber_in_bash/run_audit.sh

# Create run_audit.sh
#!/bin/bash
export DEVICE_DIR="/data/devices"
export LOG_DIR="/var/log/device_mgr"

cd /path/to/Projekt_aber_in_bash

# Find all devices without location
./runner.sh find "location=" "" >> /var/log/device_manager_audit.log

# Show device count
echo "Device count: $(find devices -name "*.txt" | wc -l)" >> /var/log/device_manager_audit.log
```

---

## Integration with Other Tools

### Export Device List (Shell Script)

```bash
#!/bin/bash
# Export all devices to CSV

echo "ID,Description,Location,Status" > inventory.csv

for file in devices/*.txt; do
    ID=$(basename "$file" .txt)
    DESC=$(grep "Beschreibung=" "$file" | cut -d= -f2)
    LOC=$(grep "Location=" "$file" | cut -d= -f2)
    STATUS=$(grep "Status=" "$file" | cut -d= -f2)
    
    echo "$ID,$DESC,$LOC,$STATUS" >> inventory.csv
done

echo "Exported to inventory.csv"
```

---

## Documentation Updates

When you update the system:

1. Update `ARCHITECTURE.md` if structure changes
2. Update `API.md` if function signatures change
3. Update `OPERATIONS.md` if deployment/troubleshooting changes
4. Update `INTERNALS.md` if helper functions change

---

## Version Information

Current Version: 1.1 (Phase 2 Complete)

**Features:**
- ✓ Core device management (CRUD)
- ✓ Search/find operations
- ✓ Logging with rotation
- ✓ Input validation
- ✓ Comprehensive test suite
- ✓ Full documentation
- ✓ Error recovery hints

**Known Limitations:**
- Single-threaded only (no concurrent access)
- No database backend (intentional, plain-text only)
- Manual test runs (no CI/CD integration)

---

## Support & Contacts

For issues:
1. Check this file (troubleshooting section)
2. Review logs: `tail -100 logs/device_manager.log`
3. Run tests: `cd tests/ && bash run_all_tests.sh`
4. Check code comments in `experimental.sh`
5. Review `API.md` for function usage

For feature requests:
- Document use case in an issue/ticket
- Link to `ARCHITECTURE.md` for design context
- Provide test case if possible
