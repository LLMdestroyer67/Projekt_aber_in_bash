# Public mains extracted from experimental.sh
# Dependencies: logging, fields, io, validators, device_ops, create, find, count

if [[ -f "$SCRIPT_DIR/modules/logging.sh" ]]; then
  . "$SCRIPT_DIR/modules/logging.sh"
fi
if [[ -f "$SCRIPT_DIR/modules/fields.sh" ]]; then
  . "$SCRIPT_DIR/modules/fields.sh"
fi
if [[ -f "$SCRIPT_DIR/modules/io.sh" ]]; then
  . "$SCRIPT_DIR/modules/io.sh"
fi
if [[ -f "$SCRIPT_DIR/modules/validators.sh" ]]; then
  . "$SCRIPT_DIR/modules/validators.sh"
fi
if [[ -f "$SCRIPT_DIR/modules/device_ops.sh" ]]; then
  . "$SCRIPT_DIR/modules/device_ops.sh"
fi
if [[ -f "$SCRIPT_DIR/modules/create.sh" ]]; then
  . "$SCRIPT_DIR/modules/create.sh"
fi
if [[ -f "$SCRIPT_DIR/modules/find.sh" ]]; then
  . "$SCRIPT_DIR/modules/find.sh"
fi
if [[ -f "$SCRIPT_DIR/modules/count.sh" ]]; then
  . "$SCRIPT_DIR/modules/count.sh"
fi

_helper_fac_search_device() {
  find_device_main
}

_helper_fac_check_match_count() {
  local count="$1"
  if (( count == 0 )); then
    echo "Kein Gerät gefunden." >&2
    return 1
  elif (( count > 1 )); then
    echo "Mehrere Geräte gefunden (${count}), keine eindeutige Auswahl. Bitte Suchkriterium verfeinern." >&2
    return 2
  fi
}

_helper_fac_assert_found_id() {
  local found_id="$1"
  if [[ -z "$found_id" ]]; then
    echo "Interner Fehler: FOUND_DEVICE_ID ist leer trotz genau 1 Treffer." >&2
    return 1
  fi
}

geraet_aendern() {
  # Change device field value
  # Args: $1=device_id (optional), $2=field (optional), $3=new_value (optional)
  # Exit codes: 0=success, 1=not found/error, 2=usage error
  setup_logging "$@"
  install_logging_traps

  local device_id="${1-}"
  local field="${2-}"
  local new_value="${3-}"

  log_info "change_device_main gestartet device_id='${device_id-}' field='${field-}' new_value='${new_value-}'"

  device_id="$(_helper_change_resolve_device_id "$device_id")" || return $?
  echo_logged "device ID=$device_id"
  log_info "Verwende device_id='$device_id'"

  if ! _helper_validate_device_id_strict "$device_id"; then
    error_logged "ERROR: invalid device ID: '$device_id'"
    return 2
  fi

  local device_file="$DEVICE_DIR/$device_id.txt"
  log_info "device_file='$device_file'"

  _helper_change_assert_device_file_exists "$device_file" "$device_id" || return $?

  echo_logged "Found device: $device_id - ready to change"
  log_info "Gerätedatei gefunden"

  _helper_change_print_file_interactive "$device_file"

  local device_count
  device_count="$(_helper_change_device_count_from_id "$device_id")"
  log_info "device_count='$device_count'"

  _helper_change_announce_device_type "$device_count"

  field="$(_helper_change_resolve_field "$field" "$device_count")" || return $?
  log_info "Verwende field='$field'"

  local change_prefix=""
  if ! change_prefix="$(_field_to_prefix "$device_count" "$field")"; then
    error_logged "ERROR: invalid FIELD '$field' for device_count=$device_count"
    return 1
  fi
  log_info "change_prefix='$change_prefix'"

  new_value="$(_helper_change_resolve_new_value "$new_value")" || return $?
  log_info "Verwende new_value='$new_value'"

  local final_line="${change_prefix}${new_value}"
  local old_line=""
  old_line="$(_helper_change_find_old_line "$device_file" "$change_prefix")"
  log_info "old_line='${old_line-}' final_line='$final_line'"

  _helper_change_announce_change "$old_line" "$final_line"

  _helper_change_rewrite_file "$device_file" "$change_prefix" "$final_line" || return 1
  log_info "Datei erfolgreich umgeschrieben device_file='$device_file'"

  _helper_change_export_globals "$device_id" "$device_count" "$change_prefix" "$final_line"
  log_info "change_device_main abgeschlossen DEVICE_ID='$DEVICE_ID' DEVICE_count='$DEVICE_count' CHANGE='$CHANGE' FINALCHANGE='$FINALCHANGE'"
}

geraet_anlegen() {
  # Create new device (type 1=single, type 2=collection)
  # Args: $1=device_id (optional, prompted if missing)
  # Exit codes: 0=success, 1=file exists/error, 2=invalid input
  setup_logging "$@"
  install_logging_traps

  log_info "create_device_main gestartet"

  mkdir -p -- "$DEVICE_DIR"
  echo_logged 'device folder has been created'
  log_info "DEVICE_DIR bereit: '$DEVICE_DIR'"

  local device_id="${1-}"
  log_info "Argument device_id='${device_id-}'"

  device_id="$(_helper_create_resolve_device_id "$device_id")" || return $?

  if ! _helper_validate_device_id_strict "$device_id"; then
    error_logged "ERROR (create_device_main): invalid device ID '$device_id'. Device IDs must be alphanumeric with optional hyphens/underscores. Rejected chars: /, space, dollar-sign, backtick, quotes. (exit code: $EXIT_USAGE_ERROR)"
    log_error "Ungültige device_id='$device_id'"
    return "$EXIT_USAGE_ERROR"
  fi

  echo_logged "device ID=$device_id"
  log_info "Verwende device_id='$device_id'"

  local device_count
  device_count="$(_helper_create_detect_device_type "$device_id")"
  log_info "device_count='$device_count'"

  local device_file="$DEVICE_DIR/$device_id.txt"
  log_info "device_file='$device_file'"

  _helper_device_lock_acquire || return 1
  if ! _helper_create_assert_file_not_exists "$device_file" "$device_id"; then
    _helper_device_lock_release
    return 1
  fi
  _helper_create_init_device_file "$device_file" "$device_id"
  if ! _helper_create_fill_device_file "$device_file" "$device_count"; then
    _helper_device_lock_release
    return 1
  fi
  _helper_device_lock_release

  DEVICE_ID="$device_id"
  DEVICE_count="$device_count"

  log_info "create_device_main abgeschlossen DEVICE_ID='$DEVICE_ID' DEVICE_count='$DEVICE_count'"
}

geraet_suchen_und_aendern() {
  # Find device then modify a field
  # Exit codes: 0=success, 1=not found/error, 2=ambiguous results
  local search_rc=0
  _helper_fac_search_device || search_rc=$?
  local match_count="${FOUND_MATCH_COUNT:-0}"
  if [[ ! "$match_count" =~ ^[0-9]+$ ]]; then
    match_count=0
  fi
  if (( search_rc != 0 )); then
    return "$search_rc"
  fi

  local rc
  _helper_fac_check_match_count "$match_count"
  rc=$?

  if (( rc == 1 )); then
    return 1
  elif (( rc == 2 )); then
    local search_rc=0
    find_device_main || search_rc=$?
    if (( search_rc != 0 )); then
      return "$search_rc"
    fi
  fi

  _helper_fac_assert_found_id "${FOUND_DEVICE_ID:-}" || return 1

  echo "Bearbeite Gerät mit ID: $FOUND_DEVICE_ID"
  change_device_main "$FOUND_DEVICE_ID"
}

geraet_suchen_und_aendern_menue() {
  # Interactive menu workflow for both field and collection-count changes.
  local search_rc=0
  find_device_main || search_rc=$?
  if (( search_rc != 0 )); then
    return "$search_rc"
  fi

  _helper_fac_check_match_count "${FOUND_MATCH_COUNT:-0}" || return $?
  _helper_fac_assert_found_id "${FOUND_DEVICE_ID:-}" || return 1

  local device_count
  device_count="$(_helper_change_device_count_from_id "$FOUND_DEVICE_ID")"
  if [[ "$device_count" -eq 2 ]]; then
    local change_choice=""
    read_logged 'Was soll geändert werden? |(1) Feld|  |(2) Anzahl| ' change_choice || return $?
    case "$change_choice" in
      1)
        change_device_main "$FOUND_DEVICE_ID"
        ;;
      2)
        change_device_count "$FOUND_DEVICE_ID"
        ;;
      *)
        error_logged "Ungültige Auswahl: '$change_choice'. Bitte 1 oder 2 eingeben."
        return 2
        ;;
    esac
  else
    change_device_main "$FOUND_DEVICE_ID"
  fi
}

geraet_suchen() {
  # Find device by ID, description, location, status, etc.
  # Args: $1=mode (id/description/location/...), $2=query
  # Exit codes: 0=found, 1=not found, 2=invalid mode
  setup_logging "$@"
  install_logging_traps

  local mode="${1-}"
  local query="${2-}"
  FOUND_DEVICE_ID=""
  FOUND_MATCHES=()
  FOUND_MATCH_COUNT=0

  log_info "find_device_main gestartet mode='${mode-}' query='${query-}'"

  mode="$(_helper_find_resolve_mode "$mode")" || return $?

  local normalized=""
  if ! normalized="$(_helper_find_normalize_mode "$mode")"; then
    error_logged "invalid input: mode='$mode'"
    return 2
  fi
  log_info "normalized mode='$normalized'"

  local rc=0
  _helper_find_dispatch_by_mode "$normalized" "$query" || rc=$?

  log_info "find_device_main abgeschlossen"
  return "$rc"
}

geraet_anzeigen() {
  # Read and display a device by ID
  # Args: $1=device_id (required in non-interactive mode)
  setup_logging "$@"
  install_logging_traps

  local device_id="${1-}"
  device_id="$(_helper_find_resolve_device_id_interactive "${device_id}")" || return $?

  echo_logged "device ID: $device_id"

  if ! _helper_validate_device_id_strict "$device_id"; then
    error_logged "ERROR: invalid device ID: '$device_id'"
    return 2
  fi

  local device_file="$DEVICE_DIR/$device_id.txt"
  _helper_change_assert_device_file_exists "$device_file" "$device_id" || return $?

  _helper_find_print_file_numbered "$device_file"
  log_info "read_device_main abgeschlossen device_id='$device_id'"
}

# Legacy public names remain thin wrappers around the German canonical API.
create_device_main() { geraet_anlegen "$@"; }
read_device_main() { geraet_anzeigen "$@"; }
change_device_main() { geraet_aendern "$@"; }
find_device_main() { geraet_suchen "$@"; }
find_and_change_main() { geraet_suchen_und_aendern "$@"; }
find_and_change_menu_main() { geraet_suchen_und_aendern_menue "$@"; }
