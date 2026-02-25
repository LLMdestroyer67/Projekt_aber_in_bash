#!/usr/bin/env bash

DEVICE_DIR="${DEVICE_DIR:-devices}"

_is_interactive() {
  [[ -t 0 && -t 1 ]]
}

# Decide mode from ID like you did: numeric => Einzelgerät
_device_count_from_id() {
  local id="$1"
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

  if [[ "$device_count" -eq 1 ]]; then
    case "$f" in
      1|beschreibung|desc|description) printf '%s' 'Beschreibung=' ;;
      2|location|loc)                 printf '%s' 'Location=' ;;
      3|status)                       printf '%s' 'Status=' ;;
      *) return 1 ;;
    esac
  elif [[ "$device_count" -eq 2 ]]; then
    case "$f" in
      1|beschreibung|desc|description) printf '%s' 'Beschreibung=' ;;
      2|anzahl|count|qty|quantity)     printf '%s' 'Anzahl=' ;;
      3|location|loc)                  printf '%s' 'Location=' ;;
      *) return 1 ;;
    esac
  else
    return 1
  fi
}

_prompt_field() {
  local device_count="$1"
  local choice=""
  if [[ "$device_count" -eq 1 ]]; then
    read -r -p 'was wird geändert? ((1)Beschreibung, (2)Location, (3)Status): ' choice
  else
    read -r -p 'was wird geändert? ((1)Beschreibung, (2)Anzahl, (3)Location): ' choice
  fi
  printf '%s' "$choice"
}

change_device_main() {
  local device_id="${1-}"
  local field="${2-}"
  local new_value="${3-}"

  # Get device_id (arg or prompt)
  if [[ -z "$device_id" ]]; then
    if _is_interactive; then
      read -r -p 'Enter the device ID= ' device_id
    else
      echo "ERROR: missing DEVICE_ID (non-interactive)" >&2
      return 2
    fi
  fi
  echo "device ID=$device_id"

  # Basic safety: avoid creating paths like devices/../x
  if [[ -z "$device_id" || "$device_id" == *"/"* ]]; then
    echo "ERROR: invalid device ID: '$device_id'" >&2
    return 2
  fi

  local device_file="$DEVICE_DIR/$device_id.txt"
  if [[ ! -f "$device_file" ]]; then
    echo "device $device_id does not exist" >&2
    return 1
  fi
  echo "Found device: $device_id - ready to change"

  if _is_interactive; then
    echo '------------------------------'
    nl -ba -- "$device_file"
    echo '------------------------------'
  fi

  local device_count
  device_count="$(_device_count_from_id "$device_id")"
  if [[ "$device_count" -eq 1 ]]; then
    echo "->Einzelgerät"
  else
    echo "->Sammeleintrag"
  fi

  # Get field (arg or prompt)
  if [[ -z "$field" ]]; then
    if _is_interactive; then
      field="$(_prompt_field "$device_count")"
    else
      echo "ERROR: missing FIELD (non-interactive). Provide 1/2/3 or name (Beschreibung/Location/Status/Anzahl)." >&2
      return 2
    fi
  fi

  local change_prefix=""
  if ! change_prefix="$(_field_to_prefix "$device_count" "$field")"; then
    echo "ERROR: invalid FIELD '$field' for device_count=$device_count" >&2
    return 1
  fi

  # Get new_value (arg or prompt)
  if [[ -z "$new_value" ]]; then
    if _is_interactive; then
      read -r -p 'neuer Inhalt= ' new_value
    else
      echo "ERROR: missing NEW_VALUE (non-interactive)" >&2
      return 2
    fi
  fi

  local final_line="${change_prefix}${new_value}"

  local old_line=""
  old_line="$(grep -m 1 -F "$change_prefix" "$device_file" || true)"
  if [[ -z "$old_line" ]]; then
    echo "could not find the line to change, adding it anyway"
  else
    echo "ändere \"$old_line\" zu \"$final_line\""
  fi
  echo "final change: $final_line"

  # Safe rewrite:
  # - replace the first line starting with prefix
  # - remove duplicates of that prefix
  # - if none existed, append at end
  local tmp
  tmp="$(mktemp)" || return 1
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

  # Optional outputs for a runner script
  DEVICE_ID="$device_id"
  DEVICE_count="$device_count"
  CHANGE="$change_prefix"
  FINALCHANGE="$final_line"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail
  change_device_main "$@"
fi