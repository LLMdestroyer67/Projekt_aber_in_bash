# Find helpers: search devices by various keys and handle results

# Dependencies: fields, io, logging
if [[ -f "$SCRIPT_DIR/modules/fields.sh" ]]; then
  . "$SCRIPT_DIR/modules/fields.sh"
fi
if [[ -f "$SCRIPT_DIR/modules/io.sh" ]]; then
  . "$SCRIPT_DIR/modules/io.sh"
fi
if [[ -f "$SCRIPT_DIR/modules/logging.sh" ]]; then
  . "$SCRIPT_DIR/modules/logging.sh"
fi

_helper_find_resolve_search_value() {
  local value="$1" key="$2"
  if [[ -z "$value" ]]; then
    if _helper_core_is_interactive; then
      value="$(read_logged "Find device by ${key%=}: ")" || return $?
      log_debug "_helper_find_resolve_search_value: nach read_logged value='$value'"
    else
      error_logged "ERROR (find_device_main): missing search value for ${key%=}. Non-interactive mode requires explicit search criteria as argument. (exit code: $EXIT_USAGE_ERROR)"
      return "$EXIT_USAGE_ERROR"
    fi
  fi
  printf '%s' "$value"
}

_helper_find_resolve_device_id_interactive() {
  local device_id="$1"
  if [[ -z "$device_id" ]]; then
    if _helper_core_is_interactive; then
      read_logged 'Find device by ID: ' device_id || return $?
    else
      error_logged "ERROR: missing DEVICE_ID (non-interactive)"
      return "$EXIT_USAGE_ERROR"
    fi
  fi
  printf '%s' "$device_id"
}

_helper_find_print_file_numbered() {
  local file="$1"
  echo_logged "----- $file -----"
  nl -ba -- "$file"
  log_info "Datei nummeriert ausgegeben '$file'"
}

_helper_find_collect_device_files() {
  local -n files_ref="$1"
  shopt -s nullglob
  files_ref=( "$DEVICE_DIR"/*.txt )
  shopt -u nullglob
  if (( ${#files_ref[@]} == 0 )); then
    error_logged "No device files found in '$DEVICE_DIR'"
    return 1
  fi
}

find_by_id() {
  local device_id="${1-}"
  device_id="$(_helper_find_resolve_device_id_interactive "$device_id")" || return $?
  echo_logged "device ID: $device_id"
  if ! _helper_validate_device_id_strict "$device_id"; then
    error_logged "ERROR: invalid device ID: '$device_id'"
    return "$EXIT_USAGE_ERROR"
  fi
  local device_file="$DEVICE_DIR/$device_id.txt"
  if [[ ! -f "$device_file" ]]; then
    error_logged "ERROR: device '$device_id' not found"
    return 1
  fi
  echo_logged "Found device: $device_id"
  _helper_find_print_file_numbered "$device_file"
  FOUND_DEVICE_ID="$device_id"
  FOUND_MATCHES=( "$device_file" )
  FOUND_MATCH_COUNT=1
}

_helper_find_file_matches_key_value() {
  local file="$1" key="$2" value="$3"
  local line="" alias=""
  local canonical_key="$(_helper_inventory_key_canonical "$key")"
  while IFS= read -r alias; do
    line="$(grep -m 1 -iE "^${alias}=" "$file" 2>/dev/null || true)"
    [[ -n "$line" ]] && break
  done < <(_helper_inventory_key_aliases "$canonical_key")
  [[ -z "$line" ]] && return 1
  log_debug "Gefundene Zeile in '$file': '$line'"
  printf '%s\n' "$line" | grep -qiF -- "$value"
}

_helper_find_extract_id_from_file() {
  local match_file="$1"
  local filename="${match_file##*/}"
  printf '%s' "${filename%.txt}"
}

_helper_find_handle_single_match() {
  local match_file="$1" key="$2" value="$3"
  echo_logged "Found 1 device with ${key%=} '$value':"
  _helper_find_print_file_numbered "$match_file"
  log_info "find_by_key_contains abgeschlossen mit 1 Treffer: '${match_file}'"

  local device_id
  device_id="$(_helper_find_extract_id_from_file "$match_file")"
  log_info "device_id='$device_id'"

  echo_logged "device ID: $device_id"
  printf "device ID: %s\n" "$device_id"

  FOUND_DEVICE_ID="$device_id"
  FOUND_MATCH_COUNT=1
}

_helper_find_handle_multi_match() {
  local file
  for file in "$@"; do
    _helper_find_print_file_numbered "$file"
  done
}

_find_by_key_contains() {
  local key="$1"
  local value="${2-}"
  local matches=()
  FOUND_DEVICE_ID=""
  FOUND_MATCH_COUNT=0

  log_info "_find_by_key_contains gestartet key='$key' value='${value-}'"

  value="$(_helper_find_resolve_search_value "$value" "$key")" || return $?

  local files=()
  _helper_find_collect_device_files files || return $?

  local file
  for file in "${files[@]}"; do
    log_debug "Prüfe Datei '$file' für key='$key' value='$value'"
    if _helper_find_file_matches_key_value "$file" "$key" "$value"; then
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
    _helper_find_handle_single_match "${matches[0]}" "$key" "$value"
    return 0
  fi

  _helper_find_handle_multi_match "${matches[@]}"
}

# Dynamic find_by_<mode> generation
for _fmode in "${find_modes[@]}"; do
  _frest="${_fmode#*:}"
  _fcanonical="${_frest%%:*}"
  _fkey="${_frest#*:}"
  [[ "$_fcanonical" == "geraete_id" ]] && continue
  eval "find_by_${_fcanonical}() { _find_by_key_contains '${_fkey}' \"\${1-}\"; }"
done
unset _fmode _frest _fcanonical _fkey

# Keep both spellings available for callers that invoke the lower-level
# search helpers directly.
find_by_geraete_id() { find_by_id "$@"; }

_helper_find_resolve_mode() {
  local mode="$1"
  if [[ -z "$mode" ]]; then
    if _helper_core_is_interactive; then
      read_logged "$(_helper_modes_build_prompt prompt)" mode || return $?
    else
      error_logged "ERROR: missing mode (non-interactive). Use: $(_helper_modes_build_prompt error)"
      return 2
    fi
  fi
  printf '%s' "$mode"
}

_helper_find_normalize_mode() {
  _helper_modes_normalize "${1-}"
}

_helper_find_dispatch_by_mode() {
  local normalized="$1" query="$2"
  if [[ "$normalized" == "geraete_id" ]]; then
    find_by_id "$query"
  else
    "find_by_${normalized}" "$query"
  fi
}
