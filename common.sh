#!/usr/bin/env bash
# common.sh — modulare Funktionsbibliothek (ein Skript), runner-kompatibel
# - Keine Auto-Ausführung beim Sourcen
# - Alle public Funktionen/Parameter bleiben gleich
# - SCRIPT_NAME/DEVICE_DIR aus Runner werden respektiert

###############################################################################
# 0) Core / Environment (env-respektierend)
###############################################################################

# Allow runner to override via env; set only if missing (important for your runner)
DEVICE_DIR="${DEVICE_DIR:-devices}"

# Resolve library directory safely; only set if missing (runner sets own SCRIPT_DIR)
SCRIPT_DIR="${SCRIPT_DIR:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)}"

# SCRIPT_NAME is used as logging context in your runner: respect env override
SCRIPT_NAME="${SCRIPT_NAME:-$(basename -- "$0")}"

_is_interactive() {
  [[ -t 0 && -t 1 ]]
}

###############################################################################
# 1) Logging + IO helpers (public)
###############################################################################

LOG_DIR="${LOG_DIR:-logs}"
LOG_FILE="${LOG_FILE:-$LOG_DIR/device_manager.log}"
TRACE_COMMANDS="${TRACE_COMMANDS:-0}" # (1) deep logging with command traces

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
  # Public: signature preserved
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
    export PS4='+ [$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [TRACE] ['"${SCRIPT_NAME:-"$(basename -- "$0")"}"'] [${FUNCNAME[0]:-MAIN}:${LINENO}] '
    set -x
    _TRACE_INITIALIZED=1
    log_info "Command trace aktiviert"
  fi
}

install_logging_traps() {
  # Public: signature preserved
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
  # Public behavior preserved:
  # - read prompt
  # - sanitize
  # - log
  # - if second arg exists -> assign to that var name, else print
  local prompt="$1"
  local value=""

  read -r -p "$prompt" value
  value="$(sanitize_input "$value")"

  log_info "Input gelesen prompt='$prompt' value='$value'"

  if [[ $# -ge 2 ]]; then
    local __target_var="$2"
    printf -v "$__target_var" '%s' "$value"
  else
    printf '%s' "$value"
  fi
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

###############################################################################
# 2) Device helpers (internal)
###############################################################################

_device_count_from_id() {
  local id="$1"
  log_debug "_device_count_from_id id='$id'"

  if [[ "$id" =~ ^[+-]?[0-9]+$ ]]; then
    printf '%s' 1
  else
    printf '%s' 2
  fi
}

_dm__validate_device_id() {
  local device_id="${1-}"
  [[ -n "$device_id" && "$device_id" != *"/"* ]]
}

_dm__device_file() {
  local device_id="$1"
  printf '%s/%s.txt' "$DEVICE_DIR" "$device_id"
}

_print_file_numbered() {
  local file="$1"
  echo_logged "----- $file -----"
  nl -ba -- "$file"
  log_info "Datei nummeriert ausgegeben '$file'"
}

_dm__rewrite_prefix_line() {
  # Replace first matching prefix line, remove duplicates, append if missing.
  local device_file="$1"
  local prefix="$2"
  local newline="$3"

  local tmp
  tmp="$(mktemp)" || return 1
  log_info "Temporäre Datei erzeugt tmp='$tmp'"

  awk -v p="$prefix" -v newline="$newline" '
    BEGIN { done=0 }
    {
      if (substr($0, 1, length(p)) == p) {
        if (!done) { print newline; done=1 }
        next
      }
      print
    }
    END { if (!done) print newline }
  ' "$device_file" >"$tmp" && mv -- "$tmp" "$device_file"
}

###############################################################################
# 3) Change device (public + internal helpers)
###############################################################################

_field_to_prefix() {
  local device_count="$1"
  local field="$2"

  local f="${field,,}"
  log_debug "_field_to_prefix device_count='$device_count' field='$field' normalized='$f'"

  if [[ "$device_count" -eq 1 ]]; then
    case "$f" in
      1|beschreibung|desc|description) printf '%s' 'Beschreibung=' ;;
      2|location|loc)                 printf '%s' 'Location=' ;;
      3|status)                       printf '%s' 'Status=' ;;
      4|kategorie|cat)                printf '%s' 'Kategorie=' ;;
      5|besitzer|owner)               printf '%s' 'Besitzer=' ;;
      *) return 1 ;;
    esac
  elif [[ "$device_count" -eq 2 ]]; then
    case "$f" in
      1|beschreibung|desc|description) printf '%s' 'Beschreibung=' ;;
      2|anzahl|count|qty|quantity)     printf '%s' 'Anzahl=' ;;
      3|location|loc)                  printf '%s' 'Location=' ;;
      4|kategorie|cat)                 printf '%s' 'Kategorie=' ;;
      *) return 1 ;;
    esac
  else
    return 1
  fi
}

_prompt_field() {
  local device_count="$1"
  local choice=""

  log_info "_prompt_field gestartet device_count='$device_count'"

  if [[ "$device_count" -eq 1 ]]; then
    read_logged 'was wird geändert? ((1)Beschreibung, (2)Location, (3)Status), (4)Kategorie, (5)Besitzer: ' choice
  else
    read_logged 'was wird geändert? ((1)Beschreibung, (2)Anzahl, (3)Location, (4)Kategorie): ' choice
  fi

  log_info "_prompt_field choice='$choice'"
  printf '%s' "$choice"
}

change_device_main() {
  setup_logging "$@"
  install_logging_traps

  local device_id="${1-}"
  local field="${2-}"
  local new_value="${3-}"

  log_info "change_device_main gestartet device_id='${device_id-}' field='${field-}' new_value='${new_value-}'"

  if [[ -z "$device_id" ]]; then
    if _is_interactive; then
      read_logged 'Enter the device ID= ' device_id
    else
      error_logged "ERROR: missing DEVICE_ID (non-interactive)"
      return 2
    fi
  fi

  echo_logged "device ID=$device_id"
  log_info "Verwende device_id='$device_id'"

  if ! _dm__validate_device_id "$device_id"; then
    error_logged "ERROR: invalid device ID: '$device_id'"
    return 2
  fi

  local device_file
  device_file="$(_dm__device_file "$device_id")"
  log_info "device_file='$device_file'"

  if [[ ! -f "$device_file" ]]; then
    error_logged "device $device_id does not exist"
    return 1
  fi

  echo_logged "Found device: $device_id - ready to change"
  log_info "Gerätedatei gefunden"

  if _is_interactive; then
    echo_logged '------------------------------'
    nl -ba -- "$device_file"
    log_info "Datei nummeriert ausgegeben '$device_file'"
    echo_logged '------------------------------'
  fi

  local device_count
  device_count="$(_device_count_from_id "$device_id")"
  log_info "device_count='$device_count'"

  if [[ "$device_count" -eq 1 ]]; then
    echo_logged "->Einzelgerät"
  else
    echo_logged "->Sammeleintrag"
  fi

  if [[ -z "$field" ]]; then
    if _is_interactive; then
      field="$(_prompt_field "$device_count")"
    else
      error_logged "ERROR: missing FIELD (non-interactive). Provide 1/2/3/4 or name (Beschreibung/Location/Status/Anzahl/Kategorie)."
      return 2
    fi
  fi
  log_info "Verwende field='$field'"

  local change_prefix=""
  if ! change_prefix="$(_field_to_prefix "$device_count" "$field")"; then
    error_logged "ERROR: invalid FIELD '$field' for device_count=$device_count"
    return 1
  fi
  log_info "change_prefix='$change_prefix'"

  if [[ -z "$new_value" ]]; then
    if _is_interactive; then
      read_logged 'neuer Inhalt= ' new_value
    else
      error_logged "ERROR: missing NEW_VALUE (non-interactive)"
      return 2
    fi
  fi
  log_info "Verwende new_value='$new_value'"

  local final_line="${change_prefix}${new_value}"
  local old_line=""
  old_line="$(grep -m 1 -F "$change_prefix" "$device_file" || true)"
  log_info "old_line='${old_line-}' final_line='$final_line'"

  if [[ -z "$old_line" ]]; then
    echo_logged "could not find the line to change, adding it anyway"
  else
    echo_logged "ändere \"$old_line\" zu \"$final_line\""
  fi
  echo_logged "final change: $final_line"

  _dm__rewrite_prefix_line "$device_file" "$change_prefix" "$final_line"
  log_info "Datei erfolgreich umgeschrieben device_file='$device_file'"

  DEVICE_ID="$device_id"
  DEVICE_count="$device_count"
  CHANGE="$change_prefix"
  FINALCHANGE="$final_line"

  log_info "change_device_main abgeschlossen DEVICE_ID='$DEVICE_ID' DEVICE_count='$DEVICE_count' CHANGE='$CHANGE' FINALCHANGE='$FINALCHANGE'"
}

###############################################################################
# 4) Create device (public)
###############################################################################

complete_one_device() {
  local device_file="$1"
  local DEVICE_DESC DEVICE_LOC DEVICE_STATUS DEVICE_CAT DEVICE_WHO

  log_info "complete_one_device gestartet device_file='$device_file'"

  read_logged 'Beschreibung des Geräts: ' DEVICE_DESC
  read_logged 'Location des Geräts: ' DEVICE_LOC
  read_logged 'Status des Geräts : ' DEVICE_STATUS
  read_logged 'Kategorie des Geräts: ' DEVICE_CAT
  read_logged 'Besitzer: ' DEVICE_WHO

  log_info "Schreibe Einzelgerät in Datei '$device_file'"

  printf 'Beschreibung=%s\n' "$DEVICE_DESC" >"$device_file"
  log_info "Geschrieben: Beschreibung='$DEVICE_DESC'"

  printf 'Location=%s\n' "$DEVICE_LOC" >>"$device_file"
  log_info "Geschrieben: Location='$DEVICE_LOC'"

  printf 'Status=%s\n' "$DEVICE_STATUS" >>"$device_file"
  log_info "Geschrieben: Status='$DEVICE_STATUS'"

  printf 'Kategorie=%s\n' "$DEVICE_CAT" >>"$device_file"
  log_info "Geschrieben: Kategorie='$DEVICE_CAT'"

  printf 'Besitzer=%s\n' "$DEVICE_WHO" >>"$device_file"
  log_info "Geschrieben: Besitzer='$DEVICE_WHO'"

  log_info "complete_one_device abgeschlossen device_file='$device_file'"
}

complete_more_device() {
  local device_file="$1"
  local DEVICE_DESC DEVICE_CT DEVICE_LOC DEVICE_CAT

  log_info "complete_more_device gestartet device_file='$device_file'"

  read_logged 'Beschreibung des Geräts: ' DEVICE_DESC
  read_logged 'Anzahl: ' DEVICE_CT
  read_logged 'Location: ' DEVICE_LOC
  read_logged 'Kategorie: ' DEVICE_CAT

  log_info "Schreibe Sammeleintrag in Datei '$device_file'"

  printf 'Beschreibung=%s\n' "$DEVICE_DESC" >"$device_file"
  log_info "Geschrieben: Beschreibung='$DEVICE_DESC'"

  printf 'Anzahl=%s\n' "$DEVICE_CT" >>"$device_file"
  log_info "Geschrieben: Anzahl='$DEVICE_CT'"

  printf 'Location=%s\n' "$DEVICE_LOC" >>"$device_file"
  log_info "Geschrieben: Location='$DEVICE_LOC'"

  printf 'Kategorie=%s\n' "$DEVICE_CAT" >>"$device_file"
  log_info "Geschrieben: Kategorie='$DEVICE_CAT'"

  log_info "complete_more_device abgeschlossen device_file='$device_file'"
}

create_device_main() {
  setup_logging "$@"
  install_logging_traps

  log_info "create_device_main gestartet"

  mkdir -p -- "$DEVICE_DIR"
  echo_logged 'device folder has been created'
  log_info "DEVICE_DIR bereit: '$DEVICE_DIR'"

  local device_id="${1-}"
  log_info "Argument device_id='${device_id-}'"

  if [[ -z "$device_id" ]]; then
    read_logged 'Enter the device ID: ' device_id
  fi

  if ! _dm__validate_device_id "$device_id"; then
    error_logged "ERROR: invalid device ID: '$device_id'"
    log_error "Ungültige device_id='$device_id'"
    return 2
  fi

  echo_logged "device ID=$device_id"
  log_info "Verwende device_id='$device_id'"

  local device_count
  if [[ "$device_id" =~ ^[+-]?[0-9]+$ ]]; then
    echo_logged "->Einzelgerät"
    device_count=1
    log_info "Gerätetyp erkannt: Einzelgerät"
  else
    echo_logged "->Sammeleintrag"
    device_count=2
    log_info "Gerätetyp erkannt: Sammeleintrag"
  fi

  local device_file
  device_file="$(_dm__device_file "$device_id")"
  log_info "device_file='$device_file'"

  if [[ -e "$device_file" ]]; then
    error_logged "device $device_id already exists"
    log_error "Datei existiert bereits: '$device_file'"
    return 1
  fi

  : >"$device_file"
  echo_logged "device $device_id has been created"
  log_info "Leere Gerätedatei erzeugt: '$device_file'"

  if [[ "$device_count" -eq 1 ]]; then
    complete_one_device "$device_file"
  elif [[ "$device_count" -eq 2 ]]; then
    complete_more_device "$device_file"
  else
    error_logged 'ERROR'
    log_error "Unerwarteter device_count='$device_count'"
    return 1
  fi

  DEVICE_ID="$device_id"
  DEVICE_count="$device_count"

  log_info "create_device_main abgeschlossen DEVICE_ID='$DEVICE_ID' DEVICE_count='$DEVICE_count'"
}

###############################################################################
# 5) Find device (public)
###############################################################################

FOUND_DEVICE_ID=""
FOUND_MATCHES=()
FOUND_MATCH_COUNT=0

_normalize_mode() {
  local m="${1-}"
  m="${m,,}"
  log_debug "_normalize_mode raw='${1-}' normalized='$m'"

  case "$m" in
    1|id)                           printf '%s' "id" ;;
    2|description|desc|beschreibung) printf '%s' "description" ;;
    3|location|loc)                 printf '%s' "location" ;;
    4|status)                       printf '%s' "status" ;;
    5|kategorie|cat)                printf '%s' "category" ;;
    6|besitzer|owner)               printf '%s' "owner" ;;
    *) return 1 ;;
  esac
}

find_by_id() {
  local device_id="${1-}"
  log_info "find_by_id gestartet device_id='${device_id-}'"

  if [[ -z "$device_id" ]]; then
    if _is_interactive; then
      read_logged 'Find device by ID: ' device_id
    else
      error_logged "ERROR: missing DEVICE_ID (non-interactive)"
      return 2
    fi
  fi

  echo_logged "device ID: $device_id"

  if [[ "$device_id" == *"/"* || -z "$device_id" ]]; then
    error_logged "ERROR: invalid device ID: '$device_id'"
    return 2
  fi

  local device_file
  device_file="$(_dm__device_file "$device_id")"
  log_info "device_file='$device_file'"

  if [[ ! -f "$device_file" ]]; then
    error_logged "device $device_id does not exist"
    return 1
  fi

  echo_logged "Found device: $device_id"
  _print_file_numbered "$device_file"
  log_info "find_by_id abgeschlossen"

  FOUND_DEVICE_ID="$device_id"
  FOUND_MATCHES=( "$device_file" )
  FOUND_MATCH_COUNT=1
}

_find_by_key_contains() {
  local key="$1"   # e.g. "Beschreibung="
  local value="${2-}"

  log_info "_find_by_key_contains gestartet key='$key' value='${value-}'"

  if [[ -z "$value" ]]; then
    if _is_interactive; then
      value="$(read_logged "Find device by ${key%=}: ")"
      log_debug "_find_by_key_contains: nach read_logged value='$value'"
    else
      error_logged "ERROR: missing search value for ${key%=} (non-interactive)"
      return 2
    fi
  fi

  local files=()
  shopt -s nullglob
  files=( "$DEVICE_DIR"/*.txt )
  shopt -u nullglob

  log_info "Anzahl Gerätedateien='${#files[@]}'"

  if (( ${#files[@]} == 0 )); then
    error_logged "No device files found in '$DEVICE_DIR'"
    return 1
  fi

  local matches=()
  local file line
  for file in "${files[@]}"; do
    log_debug "Prüfe Datei '$file' für key='$key' value='$value'"

    line="$(grep -m 1 -iE "^${key}" "$file" 2>/dev/null || true)"
    [[ -z "$line" ]] && {
      log_debug "Kein passender key in '$file'"
      continue
    }

    log_debug "Gefundene Zeile in '$file': '$line'"

    if printf '%s\n' "$line" | grep -qiF -- "$value"; then
      matches+=( "$file" )
      log_info "Treffer in '$file'"
      FOUND_MATCH_COUNT="${#matches[@]}"
    fi
  done

  if (( ${#matches[@]} == 0 )); then
    error_logged "device with ${key%=} '$value' does not exist"
    return 1
  fi

  log_info "Trefferanzahl='${#matches[@]}'"

  if (( ${#matches[@]} == 1 )); then
    echo_logged "Found 1 device with ${key%=} '$value':"
    _print_file_numbered "${matches[0]}"
    log_info "find_by_key_contains abgeschlossen mit 1 Treffer: das ist der allerbeste treffer '${matches[0]}'"

    local match_file="${matches[0]}"
    local filename="${match_file##*/}"
    local device_id="${filename%.txt}"

    log_info "device_id='$device_id'"

    echo_logged "device ID: $device_id"
    printf "device ID: %s\n" "$device_id"

    FOUND_DEVICE_ID="$device_id"
    FOUND_MATCHES=( "${matches[@]}" )
    FOUND_MATCH_COUNT="${#matches[@]}"
    return 0
  fi

  FOUND_MATCHES=( "${matches[@]}" )
  FOUND_MATCH_COUNT="${#matches[@]}"
  FOUND_DEVICE_ID=""

  for file in "${matches[@]}"; do
    _print_file_numbered "$file"
  done
}

find_by_description() { _find_by_key_contains "Beschreibung=" "${1-}"; }
find_by_location()    { _find_by_key_contains "Location=" "${1-}"; }
find_by_status()      { _find_by_key_contains "Status=" "${1-}"; }
find_by_category()    { _find_by_key_contains "Kategorie=" "${1-}"; }
find_by_owner()       { _find_by_key_contains "Besitzer=" "${1-}"; }

find_device_main() {
  setup_logging "$@"
  install_logging_traps

  local mode="${1-}"
  local query="${2-}"

  log_info "find_device_main gestartet mode='${mode-}' query='${query-}'"

  if [[ -z "$mode" ]]; then
    if _is_interactive; then
      read_logged 'Find device by (1)ID, (2)description, (3)location, (4)status, (5)category, (6)owner: ' mode
    else
      error_logged "ERROR: missing mode (non-interactive). Use: id/description/location/status/category/owner (or 1/2/3/4/5/6)"
      return 2
    fi
  fi

  local normalized=""
  if ! normalized="$(_normalize_mode "$mode")"; then
    error_logged "invalid input: mode='$mode'"
    return 2
  fi
  log_info "normalized mode='$normalized'"

  case "$normalized" in
    id)          find_by_id "$query" ;;
    description) find_by_description "$query" ;;
    location)    find_by_location "$query" ;;
    status)      find_by_status "$query" ;;
    category)    find_by_category "$query" ;;
    owner)       find_by_owner "$query" ;;
  esac

  log_info "find_device_main abgeschlossen"
}

###############################################################################
# 6) Orchestrators (public)
###############################################################################

find_and_change_main() {
  find_device_main

  if (( FOUND_MATCH_COUNT == 0 )); then
    echo "Kein Gerät gefunden." >&2
    return 1
  elif (( FOUND_MATCH_COUNT > 1 )); then
    echo "Mehrere Geräte gefunden (${FOUND_MATCH_COUNT}), keine eindeutige Auswahl. Bitte Suchkriterium verfeinern." >&2
    find_device_main
  fi

  if [[ -z "${FOUND_DEVICE_ID:-}" ]]; then
    echo "Interner Fehler: FOUND_DEVICE_ID ist leer trotz genau 1 Treffer." >&2
    return 1
  fi

  echo "Bearbeite Gerät mit ID: $FOUND_DEVICE_ID"
  change_device_main "$FOUND_DEVICE_ID"
}

###############################################################################
# 7) Count change (public) — robust ohne extglob-Abhängigkeit
###############################################################################

change_device_count() {
  setup_logging "$@"
  install_logging_traps

  local device_id="${1-}"
  local field="${2-}"
  local new_value="${3-}"

  log_info "change_device_count gestartet device_id='${device_id-}' field='${field-}' new_value='${new_value-}'"

  if [[ -z "$device_id" ]]; then
    if _is_interactive; then
      read_logged 'Enter the device ID= ' device_id
    else
      error_logged "ERROR: missing DEVICE_ID (non-interactive)"
      return 2
    fi
  fi

  echo_logged "device ID=$device_id"
  log_info "Verwende device_id='$device_id'"

  if ! _dm__validate_device_id "$device_id"; then
    error_logged "ERROR: invalid device ID: '$device_id'"
    return 2
  fi

  local device_file
  device_file="$(_dm__device_file "$device_id")"
  log_info "device_file='$device_file'"

  if [[ ! -f "$device_file" ]]; then
    error_logged "device $device_id does not exist"
    return 1
  fi

  echo_logged "Found device: $device_id - ready to change"
  log_info "Gerätedatei gefunden"

  if _is_interactive; then
    echo_logged '------------------------------'
    nl -ba -- "$device_file"
    log_info "Datei nummeriert ausgegeben '$device_file'"
    echo_logged '------------------------------'
  fi

  local device_count
  device_count="$(_device_count_from_id "$device_id")"
  log_info "device_count='$device_count'"

  if [[ "$device_count" -eq 2 ]]; then
    echo_logged "->Sammeleintrag"
  else
    echo_logged "->Einzelgerät -> keine Anzahl"
    return 1
  fi

  if [[ -z "$field" ]]; then
    if _is_interactive; then
      field="Anzahl="
    else
      error_logged "ERROR: missing FIELD (non-interactive)."
      return 2
    fi
  fi
  log_info "Verwende field='$field'"

  local change_prefix="Anzahl="

  local old_line=""
  old_line="$(grep -m 1 -F "$change_prefix" "$device_file" || true)"

  local old_value=""
  old_value="${old_line#$change_prefix}"
  log_info "old_value='$old_value'"

  local auswahl=""
  read_logged 'Möchten Sie die Anzahl erhöhen oder verringern? |(1) Erhöhen|  |(2) Verringern|    |(3) Ändern| ' auswahl
  log_info "count_more_or_less Auswahl='$auswahl'"

  # Robust: keine Abhängigkeit von extglob (bei set -euo pipefail wichtig)
  case "$auswahl" in
    1)
      new_value=$(( old_value + 1 ))
      log_info "Anzahl wird erhöht: old_value='$old_value' new_value='$new_value'"
      ;;
    2)
      new_value=$(( old_value - 1 ))
      log_info "Anzahl wird verringert: old_value='$old_value' new_value='$new_value'"
      ;;
    3)
      log_info "Anzahl wird direkt geändert: old_value='$old_value' bisherige new_value='$new_value'"
      read_logged 'neue Anzahl= ' new_value
      ;;
    *)
      error_logged "Ungültige Auswahl: '$auswahl'. Bitte 1, 2 oder 3 eingeben."
      return 2
      ;;
  esac

  if [[ -z "$new_value" ]]; then
    if _is_interactive; then
      read_logged 'neue Anzahl= ' new_value
    else
      error_logged "ERROR: missing NEW_VALUE (non-interactive)"
      return 2
    fi
  fi
  log_info "Verwende new_value='$new_value'"

  local final_line="${change_prefix}${new_value}"
  log_info "old_line='${old_line-}' final_line='$final_line'"

  if [[ -z "$old_line" ]]; then
    echo_logged "could not find the line to change, adding it anyway"
  else
    echo_logged "ändere \"$old_line\" zu \"$final_line\""
  fi
  echo_logged "final change: $final_line"

  _dm__rewrite_prefix_line "$device_file" "$change_prefix" "$final_line"
  log_info "Datei erfolgreich umgeschrieben device_file='$device_file'"

  DEVICE_ID="$device_id"
  DEVICE_count="$device_count"
  CHANGE="$change_prefix"
  FINALCHANGE="$final_line"

  log_info "change_device_main abgeschlossen DEVICE_ID='$DEVICE_ID' DEVICE_count='$DEVICE_count' CHANGE='$CHANGE' FINALCHANGE='$FINALCHANGE'"
}

change_count_main() {
  find_device_main

  if (( FOUND_MATCH_COUNT == 0 )); then
    echo "Kein Gerät gefunden." >&2
    return 1
  elif (( FOUND_MATCH_COUNT > 1 )); then
    echo "Mehrere Geräte gefunden (${FOUND_MATCH_COUNT}), keine eindeutige Auswahl. Bitte Suchkriterium verfeinern." >&2
    find_device_main
  fi

  if [[ -z "${FOUND_DEVICE_ID:-}" ]]; then
    echo "Interner Fehler: FOUND_DEVICE_ID ist leer trotz genau 1 Treffer." >&2
    return 1
  fi

  echo "Bearbeite Gerät mit ID: $FOUND_DEVICE_ID"
  change_device_count "$FOUND_DEVICE_ID"
}

###############################################################################
# 8) Optional dispatcher (ONLY when executed directly; safe for source)
###############################################################################

_dm__dispatch() {
  local base
  base="$(basename -- "$0")"

  case "$base" in
    create_device.sh)      create_device_main "$@"; return $? ;;
    change_device.sh)      change_device_main "$@"; return $? ;;
    find_device.sh)        find_device_main "$@"; return $? ;;
    find_and_change.sh)    find_and_change_main "$@"; return $? ;;
    change_count.sh)       change_count_main "$@"; return $? ;;
  esac

  local cmd="${1-}"
  case "$cmd" in
    create) shift; create_device_main "$@" ;;
    change) shift; change_device_main "$@" ;;
    find) shift; find_device_main "$@" ;;
    find_and_change) shift; find_and_change_main "$@" ;;
    change_count) shift; change_count_main "$@" ;;
    ""|help|-h|--help)
      cat <<'EOF'
Usage:
  ./common.sh <command> [args...]

Commands:
  create [device_id]
  change [device_id] [field] [new_value]
  find [mode] [query]
  find_and_change
  change_count
EOF
      return 2
      ;;
    *)
      error_logged "Unknown command '$cmd'. Use --help."
      return 2
      ;;
  esac
}

# Critical: do not auto-run when sourced (your runner sources common.sh)
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  _dm__dispatch "$@"
fi