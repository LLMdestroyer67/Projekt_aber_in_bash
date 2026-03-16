#!/usr/bin/env bash

DEVICE_DIR="${DEVICE_DIR:-devices}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
SCRIPT_NAME="$(basename -- "$0")"
# shellcheck source=./logger.sh
. "$SCRIPT_DIR/logger.sh"

_is_interactive() {
  [[ -t 0 && -t 1 ]]
}

# Decide mode from ID like you did: numeric => Einzelgerät
_device_count_from_id() {
  local id="$1"
  log_debug "_device_count_from_id id='$id'"

  if [[ "$id" =~ ^[+-]?[0-9]+$ ]]; then
    printf '%s' 1
  else
    printf '%s' 2
  fi
}

# Normalize FIELD (number or name) into a prefix (Beschreibung=/Location=/Status=/Anzahl=)
# based on device_count (1 or 2).
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

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail
  change_device_main "$@"
fi