#!/usr/bin/env bash

DEVICE_DIR="${DEVICE_DIR:-devices}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
SCRIPT_NAME="$(basename -- "$0")"
# shellcheck source=./logger.sh
. "$SCRIPT_DIR/logger.sh"


FOUND_DEVICE_ID=""
FOUND_MATCHES=()
FOUND_MATCH_COUNT=0


_is_interactive() {
  [[ -t 0 && -t 1 ]]
}

# mode can be: 1/2/3/4 OR id/description/location/status (case-insensitive)
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

# Find files where the line for KEY exists (e.g. "Beschreibung=") and contains VALUE (case-insensitive, literal)

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

# Only run automatically when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail
  find_device_main "$@"
fi