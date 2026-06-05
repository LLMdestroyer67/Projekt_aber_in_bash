# Count helpers and change_count operations
# Dependencies: io, logging, device_ops, validators
if [[ -f "$SCRIPT_DIR/modules/io.sh" ]]; then
  . "$SCRIPT_DIR/modules/io.sh"
fi
if [[ -f "$SCRIPT_DIR/modules/logging.sh" ]]; then
  . "$SCRIPT_DIR/modules/logging.sh"
fi
if [[ -f "$SCRIPT_DIR/modules/device_ops.sh" ]]; then
  . "$SCRIPT_DIR/modules/device_ops.sh"
fi
if [[ -f "$SCRIPT_DIR/modules/validators.sh" ]]; then
  . "$SCRIPT_DIR/modules/validators.sh"
fi

_helper_count_resolve_old_value() {
  local device_file="$1" change_prefix="$2"
  local old_line
  old_line="$(grep -m 1 -F "$change_prefix" "$device_file" || true)"
  printf '%s' "${old_line#"$change_prefix"}"
}

_helper_count_prompt_operation() {
  local auswahl=""
  read_logged 'Möchten Sie die Anzahl erhöhen oder verringern? |(1) Erhöhen|  |(2) Verringern|    |(3) Ändern| ' auswahl
  printf '%s' "$auswahl"
}

_helper_count_validate_operation() {
  local auswahl="$1"
  if [[ "$auswahl" != @(1|2|3) ]]; then
    error_logged "Ungültige Auswahl: '$auswahl'. Bitte 1, 2 oder 3 eingeben."
    return 2
  fi
}

_helper_count_compute_new_value() {
  local auswahl="$1" old_value="$2"
  local new_value
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
      log_info "Anzahl wird direkt geändert: old_value='$old_value'"
      read_logged 'neue Anzahl= ' new_value
      ;;
  esac
  printf '%s' "$new_value"
}

_helper_count_resolve_final_new_value() {
  local new_value="$1"
  if [[ -z "$new_value" ]]; then
    if _helper_core_is_interactive; then
      read_logged 'neue Anzahl= ' new_value
    else
      error_logged "ERROR: missing NEW_VALUE (non-interactive)"
      return 2
    fi
  fi
  printf '%s' "$new_value"
}

change_device_count() {
  setup_logging "$@"
  install_logging_traps

  local device_id="${1-}"
  local field="${2-}"
  local new_value="${3-}"

  log_info "change_device_count gestartet device_id='${device_id-}' field='${field-}' new_value='${new_value-}'"

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

  if [[ "$device_count" -eq 2 ]]; then
    echo_logged "->Sammeleintrag"
  else
    echo_logged "->Einzelgerät -> keine Anzahl"
    return 1
  fi

  if [[ -z "$field" ]]; then
    if _helper_core_is_interactive; then
      field="Anzahl="
    else
      error_logged "ERROR: missing FIELD (non-interactive). Provide 1/2/3/4 or name (Beschreibung/Location/Status/Anzahl/Kategorie)."
      return 2
    fi
  fi
  log_info "Verwende field='$field'"

  local change_prefix="Anzahl="

  local old_value
  old_value="$(_helper_count_resolve_old_value "$device_file" "$change_prefix")"
  log_info "old_value='$old_value'"

  local auswahl
  auswahl="$(_helper_count_prompt_operation)"
  log_info "count_more_or_less Auswahl='$auswahl'"

  _helper_count_validate_operation "$auswahl" || return $?

  new_value="$(_helper_count_compute_new_value "$auswahl" "$old_value")"

  new_value="$(_helper_count_resolve_final_new_value "$new_value")" || return $?
  log_info "Verwende new_value='$new_value'"

  local final_line="${change_prefix}${new_value}"
  local old_line
  old_line="$(_helper_change_find_old_line "$device_file" "$change_prefix")"
  log_info "old_line='${old_line-}' final_line='$final_line'"

  _helper_change_announce_change "$old_line" "$final_line"

  _helper_change_rewrite_file "$device_file" "$change_prefix" "$final_line" || return 1
  log_info "Datei erfolgreich umgeschrieben device_file='$device_file'"

  _helper_change_export_globals "$device_id" "$device_count" "$change_prefix" "$final_line"
  log_info "change_device_main abgeschlossen DEVICE_ID='$DEVICE_ID' DEVICE_count='$DEVICE_count' CHANGE='$CHANGE' FINALCHANGE='$FINALCHANGE'"
}

change_count_main() {
  # Find device then modify collection count (orchestrator)
  # Exit codes: 0=success, 1=not found, 2=ambiguous/invalid
  # 1. Gerät(e) suchen
  find_device_main

  # 2. Prüfen, was gefunden wurde
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
