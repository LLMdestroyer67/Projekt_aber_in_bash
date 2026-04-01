#!/usr/bin/env bash

DEVICE_DIR="${DEVICE_DIR:-devices}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
SCRIPT_NAME="$(basename -- "$0")"
# shellcheck source=./logger.sh
. "$SCRIPT_DIR/logger.sh"

complete_one_device() {
  local device_file="$1"
  local DEVICE_DESC DEVICE_LOC DEVICE_STATUS DEVICE_CAT DEVICE_WHO

  log_info "complete_one_device gestartet device_file='$device_file'"

  read_logged 'Beschreibung des Geräts: ' DEVICE_DESC
  read_logged 'Location des Geräts: ' DEVICE_LOC
  read_logged 'Status des Geräts : ' DEVICE_STATUS
  read_logged 'Kategorie des Geräts: ' DEVICE_CAT
  read_logged 'Besitzer: ' DEVICE_WHO

  log_info "Schreibe Einzelgerät in Datei '$device_file'"

  printf 'Beschreibung=%s\n' "$DEVICE_DESC" >"$device_file"
  log_info "Geschrieben: Beschreibung='$DEVICE_DESC'"

  printf 'Location=%s\n' "$DEVICE_LOC" >>"$device_file"
  log_info "Geschrieben: Location='$DEVICE_LOC'"

  printf 'Status=%s\n' "$DEVICE_STATUS" >>"$device_file"
  log_info "Geschrieben: Status='$DEVICE_STATUS'"

  printf 'Kategorie=%s\n' "$DEVICE_CAT" >>"$device_file"
  log_info "Geschrieben: Kategorie='$DEVICE_CAT'"

  printf 'Besitzer=%s\n' "$DEVICE_WHO" >>"$device_file"
  log_info "Geschrieben: Besitzer='$DEVICE_WHO'"

  log_info "complete_one_device abgeschlossen device_file='$device_file'"
}

complete_more_device() {
  local device_file="$1"
  local DEVICE_DESC DEVICE_CT DEVICE_LOC DEVICE_CAT

  log_info "complete_more_device gestartet device_file='$device_file'"

  read_logged 'Beschreibung des Geräts: ' DEVICE_DESC
  read_logged 'Anzahl: ' DEVICE_CT
  read_logged 'Location: ' DEVICE_LOC
  read_logged 'Kategorie: ' DEVICE_CAT

  log_info "Schreibe Sammeleintrag in Datei '$device_file'"

  printf 'Beschreibung=%s\n' "$DEVICE_DESC" >"$device_file"
  log_info "Geschrieben: Beschreibung='$DEVICE_DESC'"

  printf 'Anzahl=%s\n' "$DEVICE_CT" >>"$device_file"
  log_info "Geschrieben: Anzahl='$DEVICE_CT'"

  printf 'Location=%s\n' "$DEVICE_LOC" >>"$device_file"
  log_info "Geschrieben: Location='$DEVICE_LOC'"

  printf 'Kategorie=%s\n' "$DEVICE_CAT" >>"$device_file"
  log_info "Geschrieben: Kategorie='$DEVICE_CAT'"

  log_info "complete_more_device abgeschlossen device_file='$device_file'"
}

create_device_main() {
  setup_logging "$@"
  install_logging_traps

  log_info "create_device_main gestartet"

  mkdir -p -- "$DEVICE_DIR"
  echo_logged 'device folder has been created'
  log_info "DEVICE_DIR bereit: '$DEVICE_DIR'"

  local device_id="${1-}"
  log_info "Argument device_id='${device_id-}'"

  if [[ -z "$device_id" ]]; then
    read_logged 'Enter the device ID: ' device_id
  fi

  # basic safety: avoid slashes in filename
  if [[ -z "$device_id" || "$device_id" == *"/"* ]]; then
    error_logged "ERROR: invalid device ID: '$device_id'"
    log_error "Ungültige device_id='$device_id'"
    return 2
  fi

  echo_logged "device ID=$device_id"
  log_info "Verwende device_id='$device_id'"

  local device_count
  if [[ "$device_id" =~ ^[+-]?[0-9]+$ ]]; then
    echo_logged "->Einzelgerät"
    device_count=1
    log_info "Gerätetyp erkannt: Einzelgerät"
  else
    echo_logged "->Sammeleintrag"
    device_count=2
    log_info "Gerätetyp erkannt: Sammeleintrag"
  fi

  local device_file="$DEVICE_DIR/$device_id.txt"
  log_info "device_file='$device_file'"

  if [[ -e "$device_file" ]]; then
    error_logged "device $device_id already exists"
    log_error "Datei existiert bereits: '$device_file'"
    return 1
  fi

  : >"$device_file"
  echo_logged "device $device_id has been created"
  log_info "Leere Gerätedatei erzeugt: '$device_file'"

  if [[ "$device_count" -eq 1 ]]; then
    complete_one_device "$device_file"
  elif [[ "$device_count" -eq 2 ]]; then
    complete_more_device "$device_file"
  else
    error_logged 'ERROR'
    log_error "Unerwarteter device_count='$device_count'"
    return 1
  fi

  # Optional: expose results to a caller (runner) via globals
  DEVICE_ID="$device_id"
  DEVICE_count="$device_count"

  log_info "create_device_main abgeschlossen DEVICE_ID='$DEVICE_ID' DEVICE_count='$DEVICE_count'"
}

# Only auto-run when executed directly (NOT when sourced)
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail
  create_device_main "$@"
fi