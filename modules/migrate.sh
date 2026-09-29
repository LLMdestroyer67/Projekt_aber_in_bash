# Explicit migration of known legacy inventory keys to canonical German keys.

_datenmigration_pruefen_datei() {
  local datei="$1" zeile schluessel kanonisch
  local -A vorhandene_schluessel=()
  local geaendert=0

  while IFS= read -r zeile || [[ -n "$zeile" ]]; do
    [[ "$zeile" == *=* ]] || continue
    schluessel="${zeile%%=*}"
    kanonisch="$(_helper_inventory_key_canonical "$schluessel")"
    if [[ -n "${vorhandene_schluessel[$kanonisch]+x}" ]]; then
      error_logged "Mehrere Feldnamen für '$kanonisch' in '$datei'; Migration abgebrochen."
      return 1
    fi
    vorhandene_schluessel["$kanonisch"]=1
    [[ "$schluessel" == "$kanonisch" ]] || geaendert=1
  done <"$datei"

  (( geaendert == 0 )) || return 10
  return 0
}

_datenmigration_datei_anwenden() {
  local datei="$1" sicherung="$2"
  local temp="" zeile schluessel kanonisch status=0

  temp="$(mktemp "${datei}.tmp.XXXXXX")" || {
    error_logged "Temporäre Datei für '$datei' konnte nicht angelegt werden."
    return 1
  }
  if ! cp -p -- "$datei" "$temp"; then
    rm -f -- "$temp"
    error_logged "Datei '$datei' konnte nicht für die Migration vorbereitet werden."
    return 1
  fi
  : >"$temp"
  while IFS= read -r zeile || [[ -n "$zeile" ]]; do
    if [[ "$zeile" == *=* ]]; then
      schluessel="${zeile%%=*}"
      kanonisch="$(_helper_inventory_key_canonical "$schluessel")"
      if [[ "$schluessel" != "$kanonisch" ]]; then
        zeile="${kanonisch}=${zeile#*=}"
      fi
    fi
    printf '%s\n' "$zeile" >>"$temp" || status=1
  done <"$datei"

  if (( status == 0 )) && ! cp -p -- "$datei" "$sicherung"; then
    error_logged "Sicherung für '$datei' konnte nicht erstellt werden."
    status=1
  fi
  if (( status == 0 )) && ! mv -- "$temp" "$datei"; then
    error_logged "Migrierte Datei '$datei' konnte nicht atomar ersetzt werden."
    status=1
  fi

  [[ ! -e "$temp" ]] || rm -f -- "$temp"
  return "$status"
}

geraetedaten_migrieren() {
  local anwenden=0 datei rc sicherung zeitstempel
  case "${1-}" in
    '') ;;
    --anwenden|--apply) anwenden=1 ;;
    *) error_logged "Verwendung: geraetedaten_migrieren [--anwenden]"; return "$EXIT_USAGE_ERROR" ;;
  esac
  if (( $# > 1 )); then
    error_logged "Verwendung: geraetedaten_migrieren [--anwenden]"
    return "$EXIT_USAGE_ERROR"
  fi

  local dateien=("$DEVICE_DIR"/*.txt)
  if [[ ! -f "${dateien[0]-}" ]]; then
    echo_logged "Keine Gerätedateien in '$DEVICE_DIR' gefunden."
    return 0
  fi

  if (( anwenden )); then
    _helper_device_lock_acquire || return 1
  fi

  local -a zu_migrieren=()
  for datei in "${dateien[@]}"; do
    if _datenmigration_pruefen_datei "$datei"; then
      rc=0
    else
      rc=$?
    fi
    if (( rc == 1 )); then
      (( anwenden )) && _helper_device_lock_release
      return 1
    elif (( rc == 10 )); then
      zu_migrieren+=( "$datei" )
    elif (( rc != 0 )); then
      (( anwenden )) && _helper_device_lock_release
      return "$rc"
    fi
  done

  if (( ${#zu_migrieren[@]} == 0 )); then
    echo_logged "Alle Gerätedateien verwenden bereits die kanonischen Feldnamen."
    (( anwenden )) && _helper_device_lock_release
    return 0
  fi

  if (( ! anwenden )); then
    printf 'Vorschau: %s Gerätedatei(en) würden migriert. Zum Anwenden --anwenden angeben.\n' \
      "${#zu_migrieren[@]}"
    printf '  %s\n' "${zu_migrieren[@]}"
    return 0
  fi

  zeitstempel="$(date +%Y%m%d%H%M%S).$$"
  for datei in "${zu_migrieren[@]}"; do
    sicherung="${datei}.bak.${zeitstempel}"
    if [[ -e "$sicherung" ]]; then
      error_logged "Sicherungsdatei '$sicherung' existiert bereits; Migration abgebrochen."
      _helper_device_lock_release
      return 1
    fi
    if ! _datenmigration_datei_anwenden "$datei" "$sicherung"; then
      _helper_device_lock_release
      return 1
    fi
    echo_logged "Migriert: '$datei' (Sicherung: '$sicherung')"
  done
  _helper_device_lock_release
}

migrate_inventory_main() { geraetedaten_migrieren "$@"; }
