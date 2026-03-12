#!/usr/bin/env bash

DEVICE_DIR="${DEVICE_DIR:-devices}"

complete_one_device() {
  local device_file="$1"

  local DEVICE_DESC DEVICE_LOC DEVICE_STATUS DEVICE_CAT
  read -r -p 'Beschreibung des Geräts: ' DEVICE_DESC
  read -r -p 'Location des Geräts: ' DEVICE_LOC
  read -r -p 'Status des Geräts : ' DEVICE_STATUS
  read -r -p 'Kategorie des Geräts: ' DEVICE_CAT

  printf 'Beschreibung=%s\n' "$DEVICE_DESC" >"$device_file"
  printf 'Location=%s\n'     "$DEVICE_LOC"  >>"$device_file"
  printf 'Status=%s\n'       "$DEVICE_STATUS" >>"$device_file"
  printf 'Kategorie=%s\n'    "$DEVICE_CAT"    >>"$device_file"
}

complete_more_device() {
  local device_file="$1"

  local DEVICE_DESC DEVICE_CT DEVICE_LOC DEVICE_CAT
  read -r -p 'Beschreibung des Geräts: ' DEVICE_DESC
  read -r -p 'Anzahl: '                 DEVICE_CT
  read -r -p 'Location: '               DEVICE_LOC
  read -r -p 'Kategorie: '              DEVICE_CAT

  printf 'Beschreibung=%s\n' "$DEVICE_DESC" >"$device_file"
  printf 'Anzahl=%s\n'       "$DEVICE_CT"   >>"$device_file"
  printf 'Location=%s\n'     "$DEVICE_LOC"  >>"$device_file"
  printf 'Kategorie=%s\n'    "$DEVICE_CAT"    >>"$device_file"
}

create_device_main() {
  mkdir -p -- "$DEVICE_DIR"
  echo 'device folder has been created'

  local device_id="${1-}"
  if [[ -z "$device_id" ]]; then
    read -r -p 'Enter the device ID: ' device_id
  fi

  # basic safety: avoid slashes in filename
  if [[ -z "$device_id" || "$device_id" == *"/"* ]]; then
    echo "ERROR: invalid device ID: '$device_id'" >&2
    return 2
  fi

  echo "device ID=$device_id"

  local device_count
  if [[ "$device_id" =~ ^[+-]?[0-9]+$ ]]; then
    echo "->Einzelgerät"
    device_count=1
  else
    echo "->Sammeleintrag"
    device_count=2
  fi

  local device_file="$DEVICE_DIR/$device_id.txt"
  if [[ -e "$device_file" ]]; then
    echo "device $device_id already exists" >&2
    return 1
  fi

  : >"$device_file"
  echo "device $device_id has been created"

  if [[ "$device_count" -eq 1 ]]; then
    complete_one_device "$device_file"
  elif [[ "$device_count" -eq 2 ]]; then
    complete_more_device "$device_file"
  else
    echo 'ERROR' >&2
    return 1
  fi

  # Optional: expose results to a caller (runner) via globals
  DEVICE_ID="$device_id"
  DEVICE_count="$device_count"
}

# Only auto-run when executed directly (NOT when sourced)
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail
  create_device_main "$@"
fi