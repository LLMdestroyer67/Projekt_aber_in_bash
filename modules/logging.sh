# Logging helpers moved from experimental.sh
# Sourced module — do not set -euo here; caller scripts handle shell options

LOG_DIR="${LOG_DIR:-logs}"
LOG_FILE="${LOG_FILE:-$LOG_DIR/device_manager.log}"
TRACE_COMMANDS="${TRACE_COMMANDS:-0}"
LOG_MAX_SIZE="${LOG_MAX_SIZE:-10485760}"
LOG_KEEP_DAYS="${LOG_KEEP_DAYS:-7}"

# -----------------------------------------------------------------------------
# _helper_log_timestamp()
# Returns current UTC timestamp in ISO-8601
# -----------------------------------------------------------------------------
_helper_log_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# -----------------------------------------------------------------------------
# _helper_log_escape_string()
# Replace newline/CR with escape sequences
# -----------------------------------------------------------------------------
_helper_log_escape_string() {
  local s="${1-}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  printf '%s' "$s"
}

# -----------------------------------------------------------------------------
# _helper_log_ensure_dir()
# Ensure log directory exists
# -----------------------------------------------------------------------------
_helper_log_ensure_dir() {
  local dir="$1"
  mkdir -p -- "$dir"
}

# -----------------------------------------------------------------------------
# _helper_log_build_context()
# Build script/function/line context for log entries
# -----------------------------------------------------------------------------
_helper_log_build_context() {
  local script_name func_name line_no
  script_name="${SCRIPT_NAME:-$(basename -- "$0") }"
  func_name="${FUNCNAME[2]:-MAIN}"
  line_no="${BASH_LINENO[1]:-0}"
  printf '%s\t%s\t%s' "$script_name" "$func_name" "$line_no"
}

# -----------------------------------------------------------------------------
# _helper_log_format_entry()
# Format a log line
# -----------------------------------------------------------------------------
_helper_log_format_entry() {
  local level="$1" script_name="$2" func_name="$3"
  local line_no="$4" ts="$5" pid="$6" msg="$7"
  printf '%s [%s] [%s] [pid=%s] [func=%s:%s] %s\n' \
    "$ts" "$level" "$script_name" "$pid" "$func_name" "$line_no" \
    "$(_helper_log_escape_string "$msg")"
}

# -----------------------------------------------------------------------------
# _helper_log_rotate_if_needed()
# Rotate log file if size >= max_size; keep rotated days
# -----------------------------------------------------------------------------
_helper_log_rotate_if_needed() {
  local logfile="$1"
  local max_size="${2:-$LOG_MAX_SIZE}"
  local keep_days="${3:-$LOG_KEEP_DAYS}"

  [[ ! -f "$logfile" ]] && return 0

  local current_size
  current_size=$(stat -f%z -- "$logfile" 2>/dev/null || stat -c%s -- "$logfile" 2>/dev/null || echo 0)

  if (( current_size >= max_size )); then
    local i
    for (( i = 9; i >= 1; i-- )); do
      [[ -f "${logfile}.${i}" ]] && rm -f "${logfile}.$((i+1))" 2>/dev/null
      [[ -f "${logfile}.${i}" ]] && mv -- "${logfile}.${i}" "${logfile}.$((i+1))"
    done
    [[ -f "$logfile" ]] && mv -- "$logfile" "${logfile}.1"
    find "$(dirname "$logfile")" -name "$(basename "$logfile")".\* -mtime +${keep_days} -delete 2>/dev/null || true
  fi
}

# -----------------------------------------------------------------------------
# _helper_log_write_entry()
# Write formatted log entry to LOG_FILE
# -----------------------------------------------------------------------------
_helper_log_write_entry() {
  local level="$1"
  shift || true
  local msg="$*"

  local ctx script_name func_name line_no
  ctx="$(_helper_log_build_context)"
  IFS=$'\t' read -r script_name func_name line_no <<< "$ctx"

  local ts pid
  ts="$(_helper_log_timestamp)"
  pid="$$"

  _helper_log_ensure_dir "$LOG_DIR"
  _helper_log_rotate_if_needed "$LOG_FILE"
  _helper_log_format_entry \
    "$level" "$script_name" "$func_name" "$line_no" "$ts" "$pid" "$msg" \
    >>"$LOG_FILE"
}

log_message() {
  local level="$1"
  shift || true
  _helper_log_write_entry "$level" "$@"
}

log_debug() { log_message "DEBUG" "$*"; }
log_info()  { log_message "INFO"  "$*"; }
log_warn()  { log_message "WARN"  "$*"; }
log_error() { log_message "ERROR" "$*"; }

# -----------------------------------------------------------------------------
# _helper_logging_init_file()
# Create log dir and touch file
# -----------------------------------------------------------------------------
_helper_logging_init_file() {
  local log_dir="$1" log_file="$2"
  mkdir -p -- "$log_dir"
  : >>"$log_file"
}

# -----------------------------------------------------------------------------
# _helper_logging_log_startup()
# Log initial startup info
# -----------------------------------------------------------------------------
_helper_logging_log_startup() {
  log_info "Logging initialisiert"
  log_info "LOG_FILE='$LOG_FILE' TRACE_COMMANDS='$TRACE_COMMANDS' args=$(printf '%q ' "$@")"
}

# -----------------------------------------------------------------------------
# _helper_logging_enable_trace()
# Enable bash tracing into log file
# -----------------------------------------------------------------------------
_helper_logging_enable_trace() {
  exec {TRACE_FD}>>"$LOG_FILE"
  export BASH_XTRACEFD="$TRACE_FD"
  export PS4='+ [$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [TRACE] [${SCRIPT_NAME:-'"$(basename -- "$0")"'}] [${FUNCNAME[0]:-MAIN}:${LINENO}] '
  set -x
  _TRACE_INITIALIZED=1
  log_info "Command trace aktiviert"
}

setup_logging() {
  if [[ "${_LOGGING_INITIALIZED:-0}" == "1" ]]; then
    return 0
  fi

  _helper_logging_init_file "$LOG_DIR" "$LOG_FILE"
  _LOGGING_INITIALIZED=1
  _helper_logging_log_startup "$@"

  if [[ "$TRACE_COMMANDS" == "1" && "${_TRACE_INITIALIZED:-0}" != "1" ]]; then
    _helper_logging_enable_trace
  fi
}

# -----------------------------------------------------------------------------
# Traps for logging
# -----------------------------------------------------------------------------
_helper_traps_install_err() {
  trap 'rc=$?; log_error "ERR trap rc=$rc command=$BASH_COMMAND"' ERR
}

_helper_traps_install_exit() {
  trap 'rc=$?; log_info "EXIT trap rc=$rc"' EXIT
}

install_logging_traps() {
  if [[ "${_LOGGING_TRAPS_INSTALLED:-0}" == "1" ]]; then
    return 0
  fi

  _helper_traps_install_err
  _helper_traps_install_exit

  _LOGGING_TRAPS_INSTALLED=1
  log_info "Logging-Traps installiert"
}
