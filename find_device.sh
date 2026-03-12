#!/usr/bin/env bash

DEVICE_DIR="${DEVICE_DIR:-devices}"

_is_interactive() {
  [[ -t 0 && -t 1 ]]
}

# mode can be: 1/2/3/4 OR id/description/location/status (case-insensitive)
_normalize_mode() {
  local m="${1-}"
  m="${m,,}"
  case "$m" in
    1|id)           printf '%s' "id" ;;
    2|description|desc|beschreibung) printf '%s' "description" ;;
    3|location|loc) printf '%s' "location" ;;
    4|status)       printf '%s' "status" ;;
    5|kategorie|cat) printf '%s' "category" ;;
    6|besitzer|owner) printf '%s' "owner" ;;
    *) return 1 ;;
  esac
}

_print_file_numbered() {
  local file="$1"
  echo "----- $file -----"
  nl -ba -- "$file"
}

find_by_id() {
  local device_id="${1-}"
  if [[ -z "$device_id" ]]; then
    if _is_interactive; then
      read -r -p 'Find device by ID: ' device_id
    else
      echo "ERROR: missing DEVICE_ID (non-interactive)" >&2
      return 2
    fi
  fi

  echo "device ID: $device_id"

  # simple safety: avoid slashes creating paths
  if [[ "$device_id" == *"/"* || -z "$device_id" ]]; then
    echo "ERROR: invalid device ID: '$device_id'" >&2
    return 2
  fi

  local device_file="$DEVICE_DIR/$device_id.txt"
  if [[ ! -f "$device_file" ]]; then
    echo "device $device_id does not exist" >&2
    return 1
  fi

  echo "Found device: $device_id"
  _print_file_numbered "$device_file"
}

# Find files where the line for KEY exists (e.g. "Beschreibung=") and contains VALUE (case-insensitive, literal)
_find_by_key_contains() {
  local key="$1"   # e.g. "Beschreibung="
  local value="${2-}"

  if [[ -z "$value" ]]; then
    if _is_interactive; then
      read -r -p "Find device by ${key%=}: " value
    else
      echo "ERROR: missing search value for ${key%=} (non-interactive)" >&2
      return 2
    fi
  fi

  # Build list of *.txt safely (handles no matches)
  local files=()
  shopt -s nullglob
  files=( "$DEVICE_DIR"/*.txt )
  shopt -u nullglob

  if (( ${#files[@]} == 0 )); then
    echo "No device files found in '$DEVICE_DIR'" >&2
    return 1
  fi

  local matches=()
  local file line
  for file in "${files[@]}"; do
    # get the first line that starts with the key (case-insensitive)
    line="$(grep -m 1 -iE "^${key}" "$file" 2>/dev/null || true)"
    [[ -z "$line" ]] && continue

    # does that line contain the value? (case-insensitive, fixed string)
    if printf '%s\n' "$line" | grep -qiF -- "$value"; then
      matches+=( "$file" )
    fi
  done

  if (( ${#matches[@]} == 0 )); then
    echo "device with ${key%=} '$value' does not exist" >&2
    return 1
  fi

  for file in "${matches[@]}"; do
    _print_file_numbered "$file"
  done
}

find_by_description() { _find_by_key_contains "Beschreibung=" "${1-}"; }
find_by_location()    { _find_by_key_contains "Location="     "${1-}"; }
find_by_status()      { _find_by_key_contains "Status="       "${1-}"; }
find_by_category()    { _find_by_key_contains "Kategorie="    "${1-}"; }
find_by_owner()       { _find_by_key_contains "Besitzer="     "${1-}"; }

find_device_main() {
  local mode="${1-}"
  local query="${2-}"

  if [[ -z "$mode" ]]; then
    if _is_interactive; then
      read -r -p 'Find device by (1)ID, (2)description, (3)location, (4)status, (5)category, (6)owner: ' mode
    else
      echo "ERROR: missing mode (non-interactive). Use: id|description|location|status|category|owner (or 1/2/3/4/5/6)" >&2
      return 2
    fi
  fi

  local normalized=""
  if ! normalized="$(_normalize_mode "$mode")"; then
    echo "invalid input: mode='$mode'" >&2
    return 2
  fi

  case "$normalized" in
    id)          find_by_id "$query" ;;
    description) find_by_description "$query" ;;
    location)    find_by_location "$query" ;;
    status)      find_by_status "$query" ;;
    category)    find_by_category "$query" ;;
    owner)       find_by_owner "$query" ;;
  esac
}

# Only run automatically when executed directly, not when sourced
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail
  find_device_main "$@"
fi