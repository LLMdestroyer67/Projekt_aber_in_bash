#!/usr/bin/env bash

DEVICE_DIR="${DEVICE_DIR:-devices}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
SCRIPT_NAME="$(basename -- "$0")"

_is_interactive() {
  [[ -t 0 && -t 1 ]]
}

##############################
# logger.sh functions:
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

##############################
# change_device.sh functions:
_device_count_from_id() {
  local id="$1"
  log_debug "_device_count_from_id id='$id'"

  if [[ "$id" =~ ^[+-]?[0-9]+$ ]]; then
    printf '%s' 1
  else
    printf '%s' 2
  fi
}
_field_to_prefix() {
  local device_count="$1"
  local field="$2"

  # lowercase for comparison (bash-specific)
  local f="${field,,}"
  log_debug "_field_to_prefix device_count='$device_count' field='$field' normalized='$f'"

  if [[ "$device_count" -eq 1 ]]; then
    case "$f" in
      1|beschreibung|desc|description) printf '%s' 'Beschreibung=' ;;
      2|location|loc) printf '%s' 'Location=' ;;
      3|status) printf '%s' 'Status=' ;;
      4|kategorie|cat) printf '%s' 'Kategorie=' ;;
      5|besitzer|owner) printf '%s' 'Besitzer=' ;;
      *) return 1 ;;
    esac
  elif [[ "$device_count" -eq 2 ]]; then
    case "$f" in
      1|beschreibung|desc|description) printf '%s' 'Beschreibung=' ;;
      2|anzahl|count|qty|quantity) printf '%s' 'Anzahl=' ;;
      3|location|loc) printf '%s' 'Location=' ;;
      4|kategorie|cat) printf '%s' 'Kategorie=' ;;
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

  # Get device_id (arg or prompt)
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

  # Basic safety: avoid creating paths like devices/../x
  if [[ -z "$device_id" || "$device_id" == *"/"* ]]; then
    error_logged "ERROR: invalid device ID: '$device_id'"
    return 2
  fi

  local device_file="$DEVICE_DIR/$device_id.txt"
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

  # Get field (arg or prompt)
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

  # Get new_value (arg or prompt)
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

  # Safe rewrite:
  # - replace the first line starting with prefix
  # - remove duplicates of that prefix
  # - if none existed, append at end
  local tmp
  tmp="$(mktemp)" || return 1
  log_info "Temporäre Datei erzeugt tmp='$tmp'"

  awk -v p="$change_prefix" -v newline="$final_line" '
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

  log_info "Datei erfolgreich umgeschrieben device_file='$device_file'"

  # Optional outputs for a runner script
  DEVICE_ID="$device_id"
  DEVICE_count="$device_count"
  CHANGE="$change_prefix"
  FINALCHANGE="$final_line"

  log_info "change_device_main abgeschlossen DEVICE_ID='$DEVICE_ID' DEVICE_count='$DEVICE_count' CHANGE='$CHANGE' FINALCHANGE='$FINALCHANGE'"
}

##############################
# create_device.sh functions:
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

  # basic safety: avoid slashes in filename
  if [[ -z "$device_id" || "$device_id" == *"/"* ]]; then
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

  local device_file="$DEVICE_DIR/$device_id.txt"
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

  # Optional: expose results to a caller (runner) via globals
  DEVICE_ID="$device_id"
  DEVICE_count="$device_count"

  log_info "create_device_main abgeschlossen DEVICE_ID='$DEVICE_ID' DEVICE_count='$DEVICE_count'"
}

##############################
# find_and_change.sh functions:
find_and_change_main() {
  #local mode="${1-}"   # id/description/location/status/category/owner oder 1-6
  #local query="${2-}"  # Suchbegriff, optional (wird bei id meist die ID selbst sein)

  # Einfache Usage-Check
  #if [[ -z "$mode" ]]; then
  #  echo "Usage: $SCRIPT_NAME <mode> [query]" >&2
  #  echo "  mode: id/description/location/status/category/owner oder 1-6" >&2
  #  exit 2
  #fi

  # 1. Gerät(e) suchen: ruft intern find_by_* auf
  #    WICHTIG: find_device_main setzt jetzt FOUND_MATCHES / FOUND_MATCH_COUNT / FOUND_DEVICE_ID
  find_device_main #"$mode" "${query-}"

  # 2. Prüfen, was gefunden wurde
  if (( FOUND_MATCH_COUNT == 0 )); then
    echo "Kein Gerät gefunden." >&2
    return 1
  elif (( FOUND_MATCH_COUNT > 1 )); then
    echo "Mehrere Geräte gefunden (${FOUND_MATCH_COUNT}), keine eindeutige Auswahl. Bitte Suchkriterium verfeinern." >&2
    find_device_main #-> erneuter aufruf, solange man nicht die suchergebnisse anklicken kann
  fi

  # Hierher kommen wir nur, wenn genau 1 Match gefunden wurde.
  # FOUND_DEVICE_ID sollte gesetzt sein (durch find_by_id oder _find_by_key_contains).
  if [[ -z "${FOUND_DEVICE_ID:-}" ]]; then
    echo "Interner Fehler: FOUND_DEVICE_ID ist leer trotz genau 1 Treffer." >&2
    return 1
  fi

  echo "Bearbeite Gerät mit ID: $FOUND_DEVICE_ID"

  # 3. change_device_main mit dieser ID aufrufen.
  #    field und new_value lässt du einfach interaktiv abfragen (wie bisher).
  change_device_main "$FOUND_DEVICE_ID"
}

##############################
# find_device.sh functions:
FOUND_DEVICE_ID=""
FOUND_MATCHES=()
FOUND_MATCH_COUNT=0
_normalize_mode() {
  local m="${1-}"
  m="${m,,}"
  log_debug "_normalize_mode raw='${1-}' normalized='$m'"

  case "$m" in
    1|id) printf '%s' "id" ;;
    2|description|desc|beschreibung) printf '%s' "description" ;;
    3|location|loc) printf '%s' "location" ;;
    4|status) printf '%s' "status" ;;
    5|kategorie|cat) printf '%s' "category" ;;
    6|besitzer|owner) printf '%s' "owner" ;;
    *) return 1 ;;
  esac
}
_print_file_numbered() {
  local file="$1"
  echo_logged "----- $file -----"
  nl -ba -- "$file"
  log_info "Datei nummeriert ausgegeben '$file'"
}
find_by_id() {
  local device_id="${1-}"
  #local matches=()
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

  # simple safety: avoid slashes creating paths
  if [[ "$device_id" == *"/"* || -z "$device_id" ]]; then
    error_logged "ERROR: invalid device ID: '$device_id'"
    return 2
  fi

  local device_file="$DEVICE_DIR/$device_id.txt"
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
  local key="$1" # e.g. "Beschreibung="
  local value="${2-}"
  local matches=()

  log_info "_find_by_key_contains gestartet key='$key' value='${value-}'"

  if [[ -z "$value" ]]; then
    if _is_interactive; then
      # ACHTUNG: hier jetzt Command Substitution
      value="$(read_logged "Find device by ${key%=}: ")"
      log_debug "_find_by_key_contains: nach read_logged value='$value'"
    else
      error_logged "ERROR: missing search value for ${key%=} (non-interactive)"
      return 2
    fi
  fi

  # Build list of *.txt safely (handles no matches)
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

    # get the first line that starts with the key (case-insensitive)
    line="$(grep -m 1 -iE "^${key}" "$file" 2>/dev/null || true)"
    [[ -z "$line" ]] && {
      log_debug "Kein passender key in '$file'"
      continue
    }

    log_debug "Gefundene Zeile in '$file': '$line'"

    # does that line contain the value? (case-insensitive, fixed string)
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
    log_info "match_file='$match_file'"
    local filename="${match_file##*/}" #-> 1234.txt
    local device_id="${filename%.txt}" #-> 1234   <- ID
    log_info "device_id='$device_id'"
    echo_logged "device ID: $device_id"
    printf "device ID: %s\n" "$device_id"
    FOUND_DEVICE_ID="$device_id" 
    #FOUND_MATCHES=( "$device_file" )
    FOUND_MATCH_COUNT="${#matches[@]}"

    return 0

  fi

  for file in "${matches[@]}"; do
    _print_file_numbered "$file"
  done
}
find_by_description() { _find_by_key_contains "Beschreibung=" "${1-}"; }
find_by_location() { _find_by_key_contains "Location=" "${1-}"; }
find_by_status() { _find_by_key_contains "Status=" "${1-}"; }
find_by_category() { _find_by_key_contains "Kategorie=" "${1-}"; }
find_by_owner() { _find_by_key_contains "Besitzer=" "${1-}"; }
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
    id) find_by_id "$query" ;;
    description) find_by_description "$query" ;;
    location) find_by_location "$query" ;;
    status) find_by_status "$query" ;;
    category) find_by_category "$query" ;;
    owner) find_by_owner "$query" ;;
  esac

  log_info "find_device_main abgeschlossen"
}

###########################################################ab hier dann das richtige, darüber nur dependencies
###########################################################################################################

change_device_count() {
  setup_logging "$@"
  install_logging_traps

  local device_id="${1-}"
  local field="${2-}"
  local new_value="${3-}"

  log_info "change_device_count gestartet device_id='${device_id-}' field='${field-}' new_value='${new_value-}'"

  # Get device_id (arg or prompt)
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

  # Basic safety: avoid creating paths like devices/../x
  if [[ -z "$device_id" || "$device_id" == *"/"* ]]; then
    error_logged "ERROR: invalid device ID: '$device_id'"
    return 2
  fi

  local device_file="$DEVICE_DIR/$device_id.txt"
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

  # Get field (arg or prompt)
  if [[ -z "$field" ]]; then
    if _is_interactive; then
      field="Anzahl="
    else
      error_logged "ERROR: missing FIELD (non-interactive). Provide 1/2/3/4 or name (Beschreibung/Location/Status/Anzahl/Kategorie)."
      return 2
    fi
  fi
  log_info "Verwende field='$field'"
  change_prefix="Anzahl="

  
  local old_line=""
  old_line="$(grep -m 1 -F "$change_prefix" "$device_file" || true)"
  old_value="${old_line#$change_prefix}"
  log_info "old_value='$old_value'"

  read_logged 'Möchten Sie die Anzahl erhöhen oder verringern? |(1) Erhöhen|  |(2) Verringern|    |(3) Ändern| ' auswahl
  log_info "count_more_or_less Auswahl='$auswahl'"

  if [[ "$auswahl" != @(1|2|3) ]]; then
    error_logged "Ungültige Auswahl: '$auswahl'. Bitte 1, 2 oder 3 eingeben."
    return 2
  elif [[ "$auswahl" == "1" ]]; then
    new_value=$(( old_value + 1 ))
    log_info "Anzahl wird erhöht: old_value='$old_value' new_value='$new_value'"
  elif [[ "$auswahl" == "2" ]]; then
    new_value=$(( old_value - 1 ))
    log_info "Anzahl wird verringert: old_value='$old_value' new_value='$new_value'"
  elif [[ "$auswahl" == "3" ]]; then
    log_info "Anzahl wird direkt geändert: old_value='$old_value' bisherige new_value='$new_value'"
    read_logged 'neue Anzahl= ' new_value
  fi
  local final_line="${change_prefix}${new_value}"
  log_info "old_line='${old_line-}' final_line='$final_line'"


  # Get new_value (arg or prompt)
  if [[ -z "$new_value" ]]; then
    if _is_interactive; then
      read_logged 'neue Anzahl= ' new_value
    else
      error_logged "ERROR: missing NEW_VALUE (non-interactive)"
      return 2
    fi
  fi
  log_info "Verwende new_value='$new_value'"

  if [[ -z "$old_line" ]]; then
    echo_logged "could not find the line to change, adding it anyway"
  else
    echo_logged "ändere \"$old_line\" zu \"$final_line\""
  fi
  echo_logged "final change: $final_line"

  # Safe rewrite:
  # - replace the first line starting with prefix
  # - remove duplicates of that prefix
  # - if none existed, append at end
  local tmp
  tmp="$(mktemp)" || return 1
  log_info "Temporäre Datei erzeugt tmp='$tmp'"

  awk -v p="$change_prefix" -v newline="$final_line" '
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

  log_info "Datei erfolgreich umgeschrieben device_file='$device_file'"

  # Optional outputs for a runner script
  DEVICE_ID="$device_id"
  DEVICE_count="$device_count"
  CHANGE="$change_prefix"
  FINALCHANGE="$final_line"

  log_info "change_device_main abgeschlossen DEVICE_ID='$DEVICE_ID' DEVICE_count='$DEVICE_count' CHANGE='$CHANGE' FINALCHANGE='$FINALCHANGE'"
}
find_and_change_anzahl() {
  #local mode="${1-}"   # id/description/location/status/category/owner oder 1-6
  #local query="${2-}"  # Suchbegriff, optional (wird bei id meist die ID selbst sein)

  # Einfache Usage-Check
  #if [[ -z "$mode" ]]; then
  #  echo "Usage: $SCRIPT_NAME <mode> [query]" >&2
  #  echo "  mode: id/description/location/status/category/owner oder 1-6" >&2
  #  exit 2
  #fi

  # 1. Gerät(e) suchen: ruft intern find_by_* auf
  #    WICHTIG: find_device_main setzt jetzt FOUND_MATCHES / FOUND_MATCH_COUNT / FOUND_DEVICE_ID
  find_device_main #"$mode" "${query-}"

  # 2. Prüfen, was gefunden wurde
  if (( FOUND_MATCH_COUNT == 0 )); then
    echo "Kein Gerät gefunden." >&2
    return 1
  elif (( FOUND_MATCH_COUNT > 1 )); then
    echo "Mehrere Geräte gefunden (${FOUND_MATCH_COUNT}), keine eindeutige Auswahl. Bitte Suchkriterium verfeinern." >&2
    find_device_main #-> erneuter aufruf, solange man nicht die suchergebnisse anklicken kann
  fi

  # Hierher kommen wir nur, wenn genau 1 Match gefunden wurde.
  # FOUND_DEVICE_ID sollte gesetzt sein (durch find_by_id oder _find_by_key_contains).
  if [[ -z "${FOUND_DEVICE_ID:-}" ]]; then
    echo "Interner Fehler: FOUND_DEVICE_ID ist leer trotz genau 1 Treffer." >&2
    return 1
  fi

  echo "Bearbeite Gerät mit ID: $FOUND_DEVICE_ID"

  # 3. change_device_main mit dieser ID aufrufen.
  #    field und new_value lässt du einfach interaktiv abfragen (wie bisher).
  change_device_count "$FOUND_DEVICE_ID"
}
