# Create helpers: functions to initialize device files and fill fields

# Dependencies: io, fields, logging
if [[ -f "$SCRIPT_DIR/modules/io.sh" ]]; then
  . "$SCRIPT_DIR/modules/io.sh"
fi
if [[ -f "$SCRIPT_DIR/modules/fields.sh" ]]; then
  . "$SCRIPT_DIR/modules/fields.sh"
fi
if [[ -f "$SCRIPT_DIR/modules/logging.sh" ]]; then
  . "$SCRIPT_DIR/modules/logging.sh"
fi

_helper_create_read_field() {
  local prompt="$1" target_var="$2"
  read_logged "$prompt" "$target_var"
}

_helper_create_write_field() {
  local device_file="$1" key="$2" value="$3" mode="$4"
  if [[ "$mode" == ">" ]]; then
    printf '%s=%s\n' "$key" "$value" >"$device_file"
  else
    printf '%s=%s\n' "$key" "$value" >>"$device_file"
  fi
  log_info "Geschrieben: ${key}='${value}'"
}

_helper_create_fill_fields() {
  local device_file="$1"
  shift
  local wrote=0
  for field in "$@"; do
    local prefix="${field#*:}"
    local key="${prefix%=}"
    local safe_key="${key//[^a-zA-Z0-9_]/_}"
    local var_name="FIELD_VAL_${safe_key^^}"
    _helper_create_read_field "${key} des Geräts: " "$var_name"
    local val="${!var_name}"
    if [[ -z "$val" ]]; then
      log_info "Feld '$key' wurde übersprungen (leer)"
      continue
    fi
    if [[ "$wrote" -eq 0 ]]; then
      _helper_create_write_field "$device_file" "$key" "$val" ">"
      wrote=1
    else
      _helper_create_write_field "$device_file" "$key" "$val" ">>"
    fi
  done
}

complete_one_device() {
  local device_file="$1"
  log_info "complete_one_device gestartet device_file='$device_file'"
  _helper_create_fill_fields "$device_file" "${single_fields[@]}"
  log_info "complete_one_device abgeschlossen device_file='$device_file'"
}

complete_more_device() {
  local device_file="$1"
  log_info "complete_more_device gestartet device_file='$device_file'"
  _helper_create_fill_fields "$device_file" "${multi_fields[@]}"
  log_info "complete_more_device abgeschlossen device_file='$device_file'"
}

_helper_create_resolve_device_id() {
  local device_id="$1"
  if [[ -z "$device_id" ]]; then
    read_logged 'Enter the device ID: ' device_id
  fi
  printf '%s' "$device_id"
}

_helper_create_detect_device_type() {
  local device_id="$1"
  if [[ "$device_id" =~ ^[+-]?[0-9]+$ ]]; then
    printf '%s' 1
  else
    printf '%s' 2
  fi
}

_helper_create_assert_file_not_exists() {
  local device_file="$1" device_id="$2"
  if [[ -e "$device_file" ]]; then
    error_logged "ERROR (_helper_create_assert_file_not_exists): device '$device_id' already exists at $device_file. Use 'find' to view or 'change' to modify existing device. (exit code: $EXIT_ERROR)"
    log_error "Datei existiert bereits: '$device_file'"
    return "$EXIT_ERROR"
  fi
}

_helper_create_init_device_file() {
  local device_file="$1" device_id="$2"
  : >"$device_file"
  echo_logged "device $device_id has been created"
  log_info "Leere Gerätedatei erzeugt: '$device_file'"
}

_helper_create_fill_device_file() {
  local device_file="$1" device_count="$2"
  if [[ "$device_count" -eq 1 ]]; then
    complete_one_device "$device_file"
  elif [[ "$device_count" -eq 2 ]]; then
    complete_more_device "$device_file"
  else
    error_logged 'ERROR'
    log_error "Unerwarteter device_count='$device_count'"
    return 1
  fi
}
