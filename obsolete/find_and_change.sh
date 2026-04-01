#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
SCRIPT_NAME="$(basename -- "$0")"

# Beide Skripte sourcen – sie bringen logger.sh selbst mit
. "$SCRIPT_DIR/find_device.sh"
. "$SCRIPT_DIR/change_device.sh"

find_and_change_main() {
  #local mode="${1-}"   # id/description/location/status/category/owner oder 1-6
  #local query="${2-}"  # Suchbegriff, optional (wird bei id meist die ID selbst sein)

  # Einfache Usage-Check
  #if [[ -z "$mode" ]]; then
  #  echo "Usage: $SCRIPT_NAME <mode> [query]" >&2
  #  echo "  mode: id/description/location/status/category/owner oder 1-6" >&2
  #  exit 2
  #fi

  # 1. Gerät(e) suchen: ruft intern find_by_* auf
  #    WICHTIG: find_device_main setzt jetzt FOUND_MATCHES / FOUND_MATCH_COUNT / FOUND_DEVICE_ID
  find_device_main #"$mode" "${query-}"

  # 2. Prüfen, was gefunden wurde
  if (( FOUND_MATCH_COUNT == 0 )); then
    echo "Kein Gerät gefunden." >&2
    return 1
  elif (( FOUND_MATCH_COUNT > 1 )); then
    echo "Mehrere Geräte gefunden (${FOUND_MATCH_COUNT}), keine eindeutige Auswahl. Bitte Suchkriterium verfeinern." >&2
    find_device_main #-> erneuter aufruf, solange man nicht die suchergebnisse anklicken kann
  fi

  # Hierher kommen wir nur, wenn genau 1 Match gefunden wurde.
  # FOUND_DEVICE_ID sollte gesetzt sein (durch find_by_id oder _find_by_key_contains).
  if [[ -z "${FOUND_DEVICE_ID:-}" ]]; then
    echo "Interner Fehler: FOUND_DEVICE_ID ist leer trotz genau 1 Treffer." >&2
    return 1
  fi

  echo "Bearbeite Gerät mit ID: $FOUND_DEVICE_ID"

  # 3. change_device_main mit dieser ID aufrufen.
  #    field und new_value lässt du einfach interaktiv abfragen (wie bisher).
  change_device_main "$FOUND_DEVICE_ID"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  find_and_change_main "$@"
fi