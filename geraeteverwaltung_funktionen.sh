#!/usr/bin/env bash
set -euo pipefail
# German-named library entry point; loads implementation modules and public API.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
SCRIPT_NAME="$(basename -- "$0")"

# German configuration names are canonical. Legacy English variables remain
# accepted and are kept as aliases for callers of the historical interface.
DEVICE_DIR="${GERAETE_VERZEICHNIS:-${DEVICE_DIR:-devices}}"
GERAETE_VERZEICHNIS="$DEVICE_DIR"
LOG_DIR="${PROTOKOLL_VERZEICHNIS:-${LOG_DIR:-logs}}"
PROTOKOLL_VERZEICHNIS="$LOG_DIR"
LOG_FILE="${PROTOKOLL_DATEI:-${LOG_FILE:-$LOG_DIR/device_manager.log}}"
PROTOKOLL_DATEI="$LOG_FILE"

# Exit codes
readonly EXIT_OK=0
readonly EXIT_ERROR=1
readonly EXIT_USAGE_ERROR=2

# Defaults
LOG_MAX_SIZE="${PROTOKOLL_MAX_GROESSE:-${LOG_MAX_SIZE:-10485760}}"
PROTOKOLL_MAX_GROESSE="$LOG_MAX_SIZE"
LOG_KEEP_DAYS="${PROTOKOLL_BEWAHRUNGS_TAGE:-${LOG_KEEP_DAYS:-7}}"
PROTOKOLL_BEWAHRUNGS_TAGE="$LOG_KEEP_DAYS"
TRACE_COMMANDS="${BEFEHLS_TRACE:-${TRACE_COMMANDS:-0}}"
BEFEHLS_TRACE="$TRACE_COMMANDS"
DEVICE_LOCK_TIMEOUT_SECONDS="${GERAETE_SPERRE_WARTESEKUNDEN:-${DEVICE_LOCK_TIMEOUT_SECONDS:-10}}"
GERAETE_SPERRE_WARTESEKUNDEN="$DEVICE_LOCK_TIMEOUT_SECONDS"

# Source modules (order matters)
if [[ -f "$SCRIPT_DIR/modules/logging.sh" ]]; then
  . "$SCRIPT_DIR/modules/logging.sh"
else
  echo "ERROR: modules/logging.sh not found" >&2
fi
if [[ -f "$SCRIPT_DIR/modules/fields.sh" ]]; then
  . "$SCRIPT_DIR/modules/fields.sh"
fi
if [[ -f "$SCRIPT_DIR/modules/io.sh" ]]; then
  . "$SCRIPT_DIR/modules/io.sh"
fi
if [[ -f "$SCRIPT_DIR/modules/validators.sh" ]]; then
  . "$SCRIPT_DIR/modules/validators.sh"
fi
if [[ -f "$SCRIPT_DIR/modules/device_ops.sh" ]]; then
  . "$SCRIPT_DIR/modules/device_ops.sh"
fi
if [[ -f "$SCRIPT_DIR/modules/create.sh" ]]; then
  . "$SCRIPT_DIR/modules/create.sh"
fi
if [[ -f "$SCRIPT_DIR/modules/find.sh" ]]; then
  . "$SCRIPT_DIR/modules/find.sh"
fi
if [[ -f "$SCRIPT_DIR/modules/count.sh" ]]; then
  . "$SCRIPT_DIR/modules/count.sh"
fi
if [[ -f "$SCRIPT_DIR/modules/migrate.sh" ]]; then
  . "$SCRIPT_DIR/modules/migrate.sh"
fi
if [[ -f "$SCRIPT_DIR/modules/mains.sh" ]]; then
  . "$SCRIPT_DIR/modules/mains.sh"
fi
if [[ -f "$SCRIPT_DIR/modules/cli.sh" ]]; then
  . "$SCRIPT_DIR/modules/cli.sh"
fi
