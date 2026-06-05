# Validators and change helpers
# Functions for validating device IDs and common change helpers.

# Require IO and logging helpers
if [[ -f "$SCRIPT_DIR/modules/io.sh" ]]; then
  . "$SCRIPT_DIR/modules/io.sh"
fi

# Keep _helper_core_is_interactive in experimental.sh; these helpers call it.

# Strict validation for device IDs
_helper_validate_device_id_strict() {
  local id="$1"
  [[ -z "$id" ]] && return 1
  [[ "$id" =~ [/\ \`\"\'] ]] && return 1
  return 0
}

# Resolve device_id (argument or interactive)
_helper_change_resolve_device_id() {
  local device_id="$1"
  if [[ -z "$device_id" ]]; then
    if _helper_core_is_interactive; then
      read_logged 'Enter the device ID= ' device_id
    else
      error_logged "ERROR: missing DEVICE_ID (non-interactive)"
      return 2
    fi
  fi
  printf '%s' "$device_id"
}

# Assert device file exists
_helper_change_assert_device_file_exists() {
  local device_file="$1" device_id="$2"
  if [[ ! -f "$device_file" ]]; then
    error_logged "ERROR (_helper_device_file_validate): device '$device_id' not found. Use 'find' to list devices or 'create' to add new one. (exit code: $EXIT_ERROR)"
    return "$EXIT_ERROR"
  fi
}

# Print file if interactive
_helper_change_print_file_interactive() {
  local device_file="$1"
  if _helper_core_is_interactive; then
    echo_logged '------------------------------'
    nl -ba -- "$device_file"
    log_info "Datei nummeriert ausgegeben '$device_file'"
    echo_logged '------------------------------'
  fi
}

# Announce device type
_helper_change_announce_device_type() {
  local device_count="$1"
  if [[ "$device_count" -eq 1 ]]; then
    echo_logged "->Einzelgerät"
  else
    echo_logged "->Sammeleintrag"
  fi
}

# Find old line matching prefix
_helper_change_find_old_line() {
  local device_file="$1" change_prefix="$2"
  grep -m 1 -F "$change_prefix" "$device_file" || true
}
