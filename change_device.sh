#!/usr/bin/env bash

DEVICE_DIR="${DEVICE_DIR:-devices}"

_select_change_prefix_one_device() {
  # outputs chosen prefix into the variable name passed as $1
  local __outvar="$1"
  local choice

  read -r -p 'was wird geändert? ((1)Beschreibung, (2)Location, (3)Status): ' choice
  case "$choice" in
    1) printf -v "$__outvar" '%s' 'Beschreibung=' ;;
    2) printf -v "$__outvar" '%s' 'Location=' ;;
    3) printf -v "$__outvar" '%s' 'Status=' ;;
    *) echo 'invalid input' >&2; return 1 ;;
  esac
}

_select_change_prefix_more_device() {
  local __outvar="$1"
  local choice

  read -r -p 'was wird geändert? ((1)Beschreibung, (2)Anzahl, (3)Location): ' choice
  case "$choice" in
    1) printf -v "$__outvar" '%s' 'Beschreibung=' ;;
    2) printf -v "$__outvar" '%s' 'Anzahl=' ;;
    3) printf -v "$__outvar" '%s' 'Location=' ;;
    *) echo 'invalid input' >&2; return 1 ;;
  esac
}

change_device_main() {
  local device_id="${1-}"
  if [[ -z "$device_id" ]]; then
    read -r -p 'Enter the device ID= ' device_id
  fi
  echo "device ID=$device_id"

  # sanity: don't allow slashes in filename
  if [[ -z "$device_id" || "$device_id" == *"/"* ]]; then
    echo "ERROR: invalid device ID: '$device_id'" >&2
    return 2
  fi

  if [[ ! -d "$DEVICE_DIR" ]]; then
    echo "ERROR: device dir '$DEVICE_DIR' does not exist" >&2
    return 1
  fi

  local device_file="$DEVICE_DIR/$device_id.txt"
  if [[ ! -f "$device_file" ]]; then
    echo "device $device_id does not exist" >&2
    return 1
  fi
  echo "Found device: $device_id - ready to change"

  echo '------------------------------'
  nl -ba -- "$device_file"
  echo '------------------------------'

  # decide mode (your original logic: numeric ID => one device)
  local device_count
  if [[ "$device_id" =~ ^[+-]?[0-9]+$ ]]; then
    echo "->Einzelgerät"
    device_count=1
  else
    echo "->Sammeleintrag"
    device_count=2
  fi

  local change_prefix=""
  if [[ "$device_count" -eq 1 ]]; then
    _select_change_prefix_one_device change_prefix || return 1
  elif [[ "$device_count" -eq 2 ]]; then
    _select_change_prefix_more_device change_prefix || return 1
  else
    echo 'ERROR' >&2
    return 1
  fi

  local old_line=""
  old_line="$(grep -m 1 -F "$change_prefix" "$device_file" || true)"
  echo "------->>>>$old_line<<<-------"

  local new_value=""
  read -r -p 'neuer Inhalt= ' new_value

  local final_line="${change_prefix}${new_value}"
  if [[ -z "$old_line" ]]; then
    echo 'could not find the line to change, adding it anyway'
  else
    echo "ändere \"$old_line\" zu \"$final_line\""
  fi
  echo "final change: $final_line"

  # Rewrite file: replace first line starting with prefix, drop duplicates, or append if missing
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
    END {
      if (!done) print newline
    }
  ' "$device_file" >"$tmp" && mv -- "$tmp" "$device_file"

  # Optional: expose to a caller (runner) via globals
  DEVICE_ID="$device_id"
  DEVICE_count="$device_count"
  CHANGE="$change_prefix"
  FINALCHANGE="$final_line"
}

# run only when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail
  change_device_main "$@"
fi