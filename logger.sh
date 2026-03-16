
#!/usr/bin/env bash

LOG_DIR="${LOG_DIR:-logs}"
LOG_FILE="${LOG_FILE:-$LOG_DIR/device_manager.log}"
TRACE_COMMANDS="${TRACE_COMMANDS:-0}" # (1) -> deep logging with command traces, (0) -> only log messages

log_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

_log_escape() {
  local s="${1-}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  printf '%s' "$s"
}

log_message() {
  local level="$1"
  shift || true

  local script_name func_name line_no ts pid msg
  script_name="${SCRIPT_NAME:-$(basename -- "$0")}"
  func_name="${FUNCNAME[1]:-MAIN}"
  line_no="${BASH_LINENO[0]:-0}"
  ts="$(log_timestamp)"
  pid="$$"
  msg="$*"

  mkdir -p -- "$LOG_DIR"
  printf '%s [%s] [%s] [pid=%s] [func=%s:%s] %s\n' \
    "$ts" "$level" "$script_name" "$pid" "$func_name" "$line_no" "$(_log_escape "$msg")" >>"$LOG_FILE"
}

log_debug() { log_message "DEBUG" "$*"; }
log_info()  { log_message "INFO"  "$*"; }
log_warn()  { log_message "WARN"  "$*"; }
log_error() { log_message "ERROR" "$*"; }

setup_logging() {
  if [[ "${_LOGGING_INITIALIZED:-0}" == "1" ]]; then
    return 0
  fi

  mkdir -p -- "$LOG_DIR"
  : >>"$LOG_FILE"

  _LOGGING_INITIALIZED=1
  log_info "Logging initialisiert"
  log_info "LOG_FILE='$LOG_FILE' TRACE_COMMANDS='$TRACE_COMMANDS' args=$(printf '%q ' "$@")"

  if [[ "$TRACE_COMMANDS" == "1" && "${_TRACE_INITIALIZED:-0}" != "1" ]]; then
    exec {TRACE_FD}>>"$LOG_FILE"
    export BASH_XTRACEFD="$TRACE_FD"
    export PS4='+ [$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [TRACE] [${SCRIPT_NAME:-'"$(basename -- "$0")"'}] [${FUNCNAME[0]:-MAIN}:${LINENO}] '
    set -x
    _TRACE_INITIALIZED=1
    log_info "Command trace aktiviert"
  fi
}

install_logging_traps() {
  if [[ "${_LOGGING_TRAPS_INSTALLED:-0}" == "1" ]]; then
    return 0
  fi

  trap 'rc=$?; log_error "ERR trap rc=$rc command=$BASH_COMMAND"' ERR
  trap 'rc=$?; log_info "EXIT trap rc=$rc"' EXIT

  _LOGGING_TRAPS_INSTALLED=1
  log_info "Logging-Traps installiert"
}

sanitize_input() {
  local value="${1-}"
  value="${value//$'\r'/ }"
  value="${value//$'\n'/ }"
  printf '%s' "$value"
}

read_logged() {
  local prompt="$1"
  local __target_var="$2"
  local value=""

  read -r -p "$prompt" value
  value="$(sanitize_input "$value")"
  printf -v "$__target_var" '%s' "$value"

  log_info "Input gelesen prompt='$prompt' value='$value'"
}

echo_logged() {
  local msg="$*"
  echo "$msg"
  log_info "STDOUT: $msg"
}

error_logged() {
  local msg="$*"
  echo "$msg" >&2
  log_error "STDERR: $msg"
}
