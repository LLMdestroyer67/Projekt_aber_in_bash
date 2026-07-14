#!/usr/bin/env bash
set -euo pipefail
# Compatibility shim: sources modularized helpers in modules/ and exposes public *_main functions

DEVICE_DIR="${DEVICE_DIR:-devices}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
SCRIPT_NAME="$(basename -- "$0")"

# Exit codes
readonly EXIT_OK=0
readonly EXIT_ERROR=1
readonly EXIT_USAGE_ERROR=2

# Defaults
LOG_MAX_SIZE="${LOG_MAX_SIZE:-10485760}"
LOG_KEEP_DAYS="${LOG_KEEP_DAYS:-7}"
TRACE_COMMANDS="${TRACE_COMMANDS:-0}"

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
if [[ -f "$SCRIPT_DIR/modules/mains.sh" ]]; then
  . "$SCRIPT_DIR/modules/mains.sh"
fi
if [[ -f "$SCRIPT_DIR/modules/cli.sh" ]]; then
  . "$SCRIPT_DIR/modules/cli.sh"
fi

# Initialize global variables used by find operations
FOUND_DEVICE_ID=""
FOUND_MATCHES=()
FOUND_MATCH_COUNT=0

