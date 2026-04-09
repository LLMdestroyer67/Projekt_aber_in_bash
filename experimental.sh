#!/usr/bin/env bash

# =============================================================================
# common.sh – Modulare Geräteverwaltungs-Bibliothek
#
# Struktur:
#   - Jede Hauptfunktion orchestriert ausschließlich Mini-Funktionen (_helper_*)
#   - Mini-Funktionen sind zustandslos und erhalten alle Daten per Parameter
#   - Seiteneffekte (Globals, Dateischreiben) nur in klar markierten Funktionen
# =============================================================================

DEVICE_DIR="${DEVICE_DIR:-devices}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
SCRIPT_NAME="$(basename -- "$0")"

# =============================================================================
# FIELD / MODE DEFINITIONS
#
# Format for single/multi fields:  "pattern1|pattern2|...:Prefix="
# Format for find modes:           "pattern1|pattern2|...:canonical:FileKey="
#   - canonical  = the normalized mode name used internally
#   - FileKey=   = the grep key used in device files (empty for "id" mode)
# =============================================================================

# Fields for single devices (Einzelgerät)
single_fields=(
  "1|beschreibung|desc|description:Beschreibung="
  "2|location|loc:Location="
  "3|status:Status="
  "4|kategorie|cat:Kategorie="
  "5|besitzer|owner:Besitzer="
  "6|Seriennummer|serial:Seriennummer="
  "7|SAP-ID|sap_id:SAP-ID="
  "8|Hersteller|manufacturer:Hersteller="
  "9|Modell|model:Modell="
  "10|Anschaffungsdatum|purchase_date:Anschaffungsdatum="
  "11|Ausmusterungsdatum|disposal_date:Ausmusterungsdatum="
  "12|Einkaufswert|purchase_value:Einkaufswert="
)

# Fields for multi/collection devices (Sammeleintrag)
multi_fields=(
  "1|beschreibung|desc|description:Beschreibung="
  "2|anzahl|count|qty|quantity:Anzahl="
  "3|location|loc:Location="
  "4|kategorie|cat:Kategorie="
)

# Find/search modes
find_modes=(
  "1|id:id:"
  "2|description|desc|beschreibung:description:Beschreibung="
  "3|location|loc:location:Location="
  "4|status:status:Status="
  "5|kategorie|cat:category:Kategorie="
  "6|besitzer|owner:owner:Besitzer="
  "7|Seriennummer|serial:serial:Seriennummer="
  "8|SAP-ID|sap_id:sap_id:SAP-ID="
  "9|Hersteller|manufacturer:manufacturer:Hersteller="
  "10|Modell|model:model:Modell="
  "11|Anschaffungsdatum|purchase_date:purchase_date:Anschaffungsdatum="
  "12|Ausmusterungsdatum|disposal_date:disposal_date:Ausmusterungsdatum="
  "13|Einkaufswert|purchase_value:purchase_value:Einkaufswert="
)

# =============================================================================
# GENERIC FIELD/MODE PARSING HELPERS
# Shared utilities to eliminate duplicate pattern-matching logic
# =============================================================================

# Parse field definition into components: patterns, prefix, canonical, filekey
# Field format: "patterns:prefix" or "patterns:canonical:filekey"
_generic_parse_field() {
  local field="$1" component="$2"
  local patterns="${field%%:*}"
  local rest="${field#*:}"
  
  case "$component" in
    patterns) printf '%s' "$patterns" ;;
    prefix)   printf '%s' "$rest" ;;  # For single/multi fields (just the prefix after colon)
    canonical) printf '%s' "${rest%%:*}" ;;  # For find modes (first part after first colon)
    filekey)   printf '%s' "${rest#*:}" ;;   # For find modes (part after second colon)
  esac
}

# Find field in array by pattern match, return specified component
# Usage: _generic_find_in_fields "input" "return_part" field1 field2 field3...
_generic_find_in_fields() {
  local input="$1" return_part="$2"
  shift 2
  
  for field in "$@"; do
    local patterns="$(_generic_parse_field "$field" patterns)"
    local IFS='|'
    read -ra pats <<< "$patterns"
    local pat
    for pat in "${pats[@]}"; do
      if [[ "$input" == "$pat" ]]; then
        case "$return_part" in
          prefix)    printf '%s' "$(_generic_parse_field "$field" prefix)" ;;
          canonical) printf '%s' "$(_generic_parse_field "$field" canonical)" ;;
          filekey)   printf '%s' "$(_generic_parse_field "$field" filekey)" ;;
        esac
        return 0
      fi
    done
  done
  return 1
}

# =============================================================================
# FIELD/MODE BUILDING HELPERS
# =============================================================================

# -----------------------------------------------------------------------------
# _helper_fields_build_prompt()
# Beschreibung: Baut einen Prompt-String aus einem fields-Array
# Parameter:    $@ = field definitions ("patterns:Prefix=")
# Rückgabe:     Prompt-String auf stdout  e.g. "(1)Beschreibung, (2)Anzahl, ..."
# Refactored: Uses _generic_parse_field for cleaner code
_helper_fields_build_prompt() {
  local parts=()
  for field in "$@"; do
    local patterns="$(_generic_parse_field "$field" patterns)"
    local prefix="$(_generic_parse_field "$field" prefix)"
    local num="${patterns%%|*}"
    local label="${prefix%=}"
    parts+=( "(${num})${label}" )
  done
  local IFS=', '
  printf '%s' "${parts[*]}"
}

# -----------------------------------------------------------------------------
# _helper_fields_match_to_prefix()
# Beschreibung: Sucht in einem fields-Array nach einem passenden Muster und
#               gibt den zugehörigen Präfix zurück
# Parameter:    $1 = Eingabe-String (normalisiert), $2.. = field definitions
# Rückgabe:     Präfix-String auf stdout; rc=1 wenn kein Treffer
# Refactored: Uses _generic_find_in_fields
_helper_fields_match_to_prefix() {
  local input="$1"
  shift
  _generic_find_in_fields "$input" "prefix" "$@"
}

# -----------------------------------------------------------------------------
# _helper_modes_build_prompt()
# Beschreibung: Baut Prompt- und Fehlertext aus dem find_modes-Array
# Parameter:    $1 = "prompt" oder "error"
# Rückgabe:     Fertiger String auf stdout
# -----------------------------------------------------------------------------
_helper_modes_build_prompt() {
  local type="$1"
  local prompt_parts=() error_parts=()
  for m in "${find_modes[@]}"; do
    local patterns="${m%%:*}"
    local rest="${m#*:}"
    local canonical="${rest%%:*}"
    local num="${patterns%%|*}"
    prompt_parts+=( "(${num})${canonical}" )
    error_parts+=( "${canonical}/${num}" )
  done
  if [[ "$type" == "prompt" ]]; then
    local IFS=', '
    printf 'Find device by %s: ' "${prompt_parts[*]}"
  else
    local IFS='/'
    printf '%s' "${error_parts[*]}"
  fi
}

# -----------------------------------------------------------------------------
# _helper_modes_normalize()
# Beschreibung: Normalisiert einen Suchmodus-String auf den kanonischen Wert
# Parameter:    $1 = roher Modus-String
# Rückgabe:     Kanonischer Modus auf stdout; rc=1 bei ungültigem Modus
# Refactored: Uses _generic_find_in_fields
_helper_modes_normalize() {
  local input="${1,,}"
  _generic_find_in_fields "$input" "canonical" "${find_modes[@]}"
}

# -----------------------------------------------------------------------------
# _helper_modes_get_file_key()
# Beschreibung: Gibt den Datei-Schlüssel (z.B. "Beschreibung=") für einen
#               kanonischen Modus zurück
# Parameter:    $1 = canonical mode
# Rückgabe:     FileKey= auf stdout; rc=1 wenn nicht gefunden
# Refactored: Manual loop since we search by canonical instead of patterns
_helper_modes_get_file_key() {
  local canonical="$1"
  for m in "${find_modes[@]}"; do
    local c="$(_generic_parse_field "$m" canonical)"
    if [[ "$c" == "$canonical" ]]; then
      _generic_parse_field "$m" filekey
      return 0
    fi
  done
  return 1
}

#=============================================================================
# -----------------------------------------------------------------------------
# _helper_core_is_interactive()
# Beschreibung: Prüft ob stdin und stdout interaktive Terminals sind
# Parameter:    keine
# Rückgabe:     0 = interaktiv, 1 = nicht interaktiv
# -----------------------------------------------------------------------------
_helper_core_is_interactive() {
  [[ -t 0 || -t 1 ]]
}

_is_interactive() {
  _helper_core_is_interactive
}

##############################
# logger.sh functions
##############################

LOG_DIR="${LOG_DIR:-logs}"
LOG_FILE="${LOG_FILE:-$LOG_DIR/device_manager.log}"
TRACE_COMMANDS="${TRACE_COMMANDS:-0}"

# -----------------------------------------------------------------------------
# _helper_log_timestamp()
# Beschreibung: Gibt den aktuellen UTC-Zeitstempel im ISO-8601-Format aus
# Parameter:    keine
# Rückgabe:     Zeitstempel-String auf stdout
# -----------------------------------------------------------------------------
_helper_log_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

# -----------------------------------------------------------------------------
# _helper_log_escape_string()
# Beschreibung: Ersetzt Newline/CR-Zeichen durch Escape-Sequenzen
# Parameter:    $1 = zu escapender String
# Rückgabe:     Bereinigter String auf stdout
# -----------------------------------------------------------------------------
_helper_log_escape_string() {
  local s="${1-}"
  s="${s//$'\n'/\\n}"
  s="${s//$'\r'/\\r}"
  printf '%s' "$s"
}

# -----------------------------------------------------------------------------
# _helper_log_ensure_dir()
# Beschreibung: Stellt sicher, dass das Log-Verzeichnis existiert
# Parameter:    $1 = Pfad zum Log-Verzeichnis
# Rückgabe:     keine (Seiteneffekt: Verzeichnis wird ggf. erstellt)
# -----------------------------------------------------------------------------
_helper_log_ensure_dir() {
  local dir="$1"
  mkdir -p -- "$dir"
}

# -----------------------------------------------------------------------------
# _helper_log_build_context()
# Beschreibung: Ermittelt Skriptname, Funktionsname und Zeilennummer für den Log
# Parameter:    keine (liest BASH-interne Variablen)
# Rückgabe:     Drei Werte via printf: script_name func_name line_no (tab-getrennt)
# -----------------------------------------------------------------------------
_helper_log_build_context() {
  local script_name func_name line_no
  script_name="${SCRIPT_NAME:-$(basename -- "$0")}"
  func_name="${FUNCNAME[2]:-MAIN}"
  line_no="${BASH_LINENO[1]:-0}"
  printf '%s\t%s\t%s' "$script_name" "$func_name" "$line_no"
}

# -----------------------------------------------------------------------------
# _helper_log_format_entry()
# Beschreibung: Formatiert einen vollständigen Log-Eintrag als String
# Parameter:    $1 = level, $2 = script_name, $3 = func_name,
#               $4 = line_no, $5 = ts, $6 = pid, $7 = msg
# Rückgabe:     Formatierter Log-Eintrag auf stdout
# -----------------------------------------------------------------------------
_helper_log_format_entry() {
  local level="$1" script_name="$2" func_name="$3"
  local line_no="$4" ts="$5" pid="$6" msg="$7"
  printf '%s [%s] [%s] [pid=%s] [func=%s:%s] %s\n' \
    "$ts" "$level" "$script_name" "$pid" "$func_name" "$line_no" \
    "$(_helper_log_escape_string "$msg")"
}

# -----------------------------------------------------------------------------
# _helper_log_write_entry()
# Beschreibung: Schreibt einen formatierten Log-Eintrag in die Log-Datei
# Parameter:    $1 = level, $2 = message
# Rückgabe:     keine (Seiteneffekt: Schreibt in LOG_FILE)
# -----------------------------------------------------------------------------
_helper_log_write_entry() {
  local level="$1"
  shift || true
  local msg="$*"

  local ctx script_name func_name line_no
  ctx="$(_helper_log_build_context)"
  IFS=$'\t' read -r script_name func_name line_no <<< "$ctx"

  local ts pid
  ts="$(_helper_log_timestamp)"
  pid="$$"

  _helper_log_ensure_dir "$LOG_DIR"
  _helper_log_format_entry \
    "$level" "$script_name" "$func_name" "$line_no" "$ts" "$pid" "$msg" \
    >>"$LOG_FILE"
}

log_message() {
  local level="$1"
  shift || true
  _helper_log_write_entry "$level" "$@"
}

log_debug() { log_message "DEBUG" "$*"; }
log_info()  { log_message "INFO"  "$*"; }
log_warn()  { log_message "WARN"  "$*"; }
log_error() { log_message "ERROR" "$*"; }

# -----------------------------------------------------------------------------
# _helper_logging_init_file()
# Beschreibung: Erstellt Log-Verzeichnis und berührt die Log-Datei
# Parameter:    $1 = log_dir, $2 = log_file
# Rückgabe:     keine (Seiteneffekt: Verzeichnis/Datei werden erzeugt)
# -----------------------------------------------------------------------------
_helper_logging_init_file() {
  local log_dir="$1" log_file="$2"
  mkdir -p -- "$log_dir"
  : >>"$log_file"
}

# -----------------------------------------------------------------------------
# _helper_logging_log_startup()
# Beschreibung: Schreibt initiale Log-Einträge nach dem Setup
# Parameter:    $@ = ursprüngliche Skript-Argumente
# Rückgabe:     keine (Seiteneffekt: Schreibt in LOG_FILE)
# -----------------------------------------------------------------------------
_helper_logging_log_startup() {
  log_info "Logging initialisiert"
  log_info "LOG_FILE='$LOG_FILE' TRACE_COMMANDS='$TRACE_COMMANDS' args=$(printf '%q ' "$@")"
}

# -----------------------------------------------------------------------------
# _helper_logging_enable_trace()
# Beschreibung: Aktiviert Bash-Trace-Logging (set -x) in die Log-Datei
# Parameter:    keine
# Rückgabe:     keine (Seiteneffekt: Setzt BASH_XTRACEFD, PS4, set -x, _TRACE_INITIALIZED)
# -----------------------------------------------------------------------------
_helper_logging_enable_trace() {
  exec {TRACE_FD}>>"$LOG_FILE"
  export BASH_XTRACEFD="$TRACE_FD"
  export PS4='+ [$(date -u +"%Y-%m-%dT%H:%M:%SZ")] [TRACE] [${SCRIPT_NAME:-'"$(basename -- "$0")"'}] [${FUNCNAME[0]:-MAIN}:${LINENO}] '
  set -x
  _TRACE_INITIALIZED=1
  log_info "Command trace aktiviert"
}

setup_logging() {
  if [[ "${_LOGGING_INITIALIZED:-0}" == "1" ]]; then
    return 0
  fi

  _helper_logging_init_file "$LOG_DIR" "$LOG_FILE"
  _LOGGING_INITIALIZED=1
  _helper_logging_log_startup "$@"

  if [[ "$TRACE_COMMANDS" == "1" && "${_TRACE_INITIALIZED:-0}" != "1" ]]; then
    _helper_logging_enable_trace
  fi
}

# -----------------------------------------------------------------------------
# _helper_traps_install_err()
# Beschreibung: Installiert den ERR-Trap für Fehlerprotokollierung
# Parameter:    keine
# Rückgabe:     keine (Seiteneffekt: trap ERR)
# -----------------------------------------------------------------------------
_helper_traps_install_err() {
  trap 'rc=$?; log_error "ERR trap rc=$rc command=$BASH_COMMAND"' ERR
}

# -----------------------------------------------------------------------------
# _helper_traps_install_exit()
# Beschreibung: Installiert den EXIT-Trap für Abschlussprotokollierung
# Parameter:    keine
# Rückgabe:     keine (Seiteneffekt: trap EXIT)
# -----------------------------------------------------------------------------
_helper_traps_install_exit() {
  trap 'rc=$?; log_info "EXIT trap rc=$rc"' EXIT
}

install_logging_traps() {
  if [[ "${_LOGGING_TRAPS_INSTALLED:-0}" == "1" ]]; then
    return 0
  fi

  _helper_traps_install_err
  _helper_traps_install_exit

  _LOGGING_TRAPS_INSTALLED=1
  log_info "Logging-Traps installiert"
}

# -----------------------------------------------------------------------------
# _helper_input_strip_control_chars()
# Beschreibung: Entfernt CR und LF aus einem String
# Parameter:    $1 = Eingabe-String
# Rückgabe:     Bereinigter String auf stdout
# -----------------------------------------------------------------------------
_helper_input_strip_control_chars() {
  local value="${1-}"
  value="${value//$'\r'/ }"
  value="${value//$'\n'/ }"
  printf '%s' "$value"
}

# -----------------------------------------------------------------------------
# _helper_input_read_raw()
# Beschreibung: Liest eine Zeile von stdin mit Prompt
# Parameter:    $1 = Prompt-String
# Rückgabe:     Eingelesener Wert auf stdout
# -----------------------------------------------------------------------------
_helper_input_read_raw() {
  local prompt="$1"
  local value=""
  read -r -p "$prompt" value
  printf '%s' "$value"
}

# -----------------------------------------------------------------------------
# _helper_input_assign_or_print()
# Beschreibung: Weist einen Wert einer Variablen zu oder gibt ihn auf stdout aus
# Parameter:    $1 = Wert, $2 = (optional) Ziel-Variablenname
# Rückgabe:     Wert auf stdout wenn kein Ziel angegeben, sonst Zuweisung
# -----------------------------------------------------------------------------
_helper_input_assign_or_print() {
  local value="$1"
  if [[ $# -ge 2 ]]; then
    local __target_var="$2"
    printf -v "$__target_var" '%s' "$value"
  else
    printf '%s' "$value"
  fi
}

read_logged() {
  local prompt="$1"
  local value=""

  value="$(_helper_input_read_raw "$prompt")"
  value="$(_helper_input_strip_control_chars "$value")"

  log_info "Input gelesen prompt='$prompt' value='$value'"

  if [[ $# -ge 2 ]]; then
    _helper_input_assign_or_print "$value" "$2"
  else
    printf '%s' "$value"
  fi
}

# -----------------------------------------------------------------------------
# Generic output and log helper for any stream + level
# Parameter: $1 = message, $2 = fd (1=stdout, 2=stderr), $3 = log_level
_helper_output_and_log() {
  local msg="$1" fd="${2:-1}" level="${3:-INFO}"
  echo "$msg" >&"$fd"
  log_message "$level" "$msg"
}

# Public wrappers for convenience
_helper_output_stdout_and_log() {
  _helper_output_and_log "$1" 1 INFO
}

_helper_output_stderr_and_log() {
  _helper_output_and_log "$1" 2 ERROR
}

echo_logged() {
  _helper_output_stdout_and_log "$*"
}

error_logged() {
  _helper_output_stderr_and_log "$*"
}

##############################
# change_device.sh functions
##############################

# -----------------------------------------------------------------------------
# _helper_change_device_count_from_id()
# Beschreibung: Bestimmt ob eine ID ein Einzelgerät (1) oder Sammeleintrag (2) ist
# Parameter:    $1 = device_id
# Rückgabe:     "1" oder "2" auf stdout
# -----------------------------------------------------------------------------
_helper_change_device_count_from_id() {
  local id="$1"
  log_debug "_helper_change_device_count_from_id id='$id'"

  if [[ "$id" =~ ^[+-]?[0-9]+$ ]]; then
    printf '%s' 1
  else
    printf '%s' 2
  fi
}

# -----------------------------------------------------------------------------
# _helper_change_field_to_prefix_single()
# Beschreibung: Mappt Feldbezeichner auf Datei-Präfix für Einzelgeräte
# Parameter:    $1 = normalisierter Feldbezeichner
# Rückgabe:     Präfix-String auf stdout, rc=1 bei ungültigem Feld
# -----------------------------------------------------------------------------
_helper_change_field_to_prefix_single() {
  local f="${1,,}"
  _helper_fields_match_to_prefix "$f" "${single_fields[@]}"
}

# -----------------------------------------------------------------------------
# _helper_change_field_to_prefix_multi()
# Beschreibung: Mappt Feldbezeichner auf Datei-Präfix für Sammeleinträge
# Parameter:    $1 = normalisierter Feldbezeichner
# Rückgabe:     Präfix-String auf stdout, rc=1 bei ungültigem Feld
# -----------------------------------------------------------------------------
_helper_change_field_to_prefix_multi() {
  local f="${1,,}"
  _helper_fields_match_to_prefix "$f" "${multi_fields[@]}"
}

_field_to_prefix() {
  local device_count="$1"
  local field="$2"
  local f="${field,,}"
  log_debug "_field_to_prefix device_count='$device_count' field='$field' normalized='$f'"

  if [[ "$device_count" -eq 1 ]]; then
    _helper_change_field_to_prefix_single "$f"
  elif [[ "$device_count" -eq 2 ]]; then
    _helper_change_field_to_prefix_multi "$f"
  else
    return 1
  fi
}

# -----------------------------------------------------------------------------
# _helper_change_prompt_field_single()
# Beschreibung: Fragt den Benutzer nach dem zu ändernden Feld für Einzelgeräte
# Parameter:    keine
# Rückgabe:     Benutzereingabe auf stdout
# -----------------------------------------------------------------------------
_helper_change_prompt_field_single() {
  local choice=""
  local prompt
  prompt="was wird geändert? ($(_helper_fields_build_prompt "${single_fields[@]}")): "
  read_logged "$prompt" choice
  printf '%s' "$choice"
}

# -----------------------------------------------------------------------------
# _helper_change_prompt_field_multi()
# Beschreibung: Fragt den Benutzer nach dem zu ändernden Feld für Sammeleinträge
# Parameter:    keine
# Rückgabe:     Benutzereingabe auf stdout
# -----------------------------------------------------------------------------
_helper_change_prompt_field_multi() {
  local choice=""
  local prompt
  prompt="was wird geändert? ($(_helper_fields_build_prompt "${multi_fields[@]}")): "
  read_logged "$prompt" choice
  printf '%s' "$choice"
}

_prompt_field() {
  local device_count="$1"
  local choice=""

  log_info "_prompt_field gestartet device_count='$device_count'"

  if [[ "$device_count" -eq 1 ]]; then
    choice="$(_helper_change_prompt_field_single)"
  else
    choice="$(_helper_change_prompt_field_multi)"
  fi

  log_info "_prompt_field choice='$choice'"
  printf '%s' "$choice"
}

# -----------------------------------------------------------------------------
# _helper_change_validate_device_id()
# Beschreibung: Prüft ob eine device_id nicht leer und ohne Slash ist
# Parameter:    $1 = device_id
# Rückgabe:     rc=0 gültig, rc=1 ungültig
# -----------------------------------------------------------------------------
_helper_change_validate_device_id() {
  local device_id="$1"
  if [[ -z "$device_id" || "$device_id" == *"/"* ]]; then
    return 1
  fi
  return 0
}

# -----------------------------------------------------------------------------
# _helper_change_resolve_device_id()
# Beschreibung: Gibt device_id zurück (aus Argument oder interaktiver Eingabe)
# Parameter:    $1 = device_id (kann leer sein)
# Rückgabe:     Aufgelöste device_id auf stdout; rc=2 bei Fehler
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# _helper_change_assert_device_file_exists()
# Beschreibung: Prüft ob die Gerätedatei existiert und gibt Fehler aus wenn nicht
# Parameter:    $1 = device_file, $2 = device_id
# Rückgabe:     rc=0 existiert, rc=1 nicht gefunden
# -----------------------------------------------------------------------------
_helper_change_assert_device_file_exists() {
  local device_file="$1" device_id="$2"
  if [[ ! -f "$device_file" ]]; then
    error_logged "device $device_id does not exist"
    return 1
  fi
}

# -----------------------------------------------------------------------------
# _helper_change_print_file_interactive()
# Beschreibung: Gibt die Gerätedatei nummeriert aus, wenn interaktiv
# Parameter:    $1 = device_file
# Rückgabe:     keine (Seiteneffekt: stdout)
# -----------------------------------------------------------------------------
_helper_change_print_file_interactive() {
  local device_file="$1"
  if _helper_core_is_interactive; then
    echo_logged '------------------------------'
    nl -ba -- "$device_file"
    log_info "Datei nummeriert ausgegeben '$device_file'"
    echo_logged '------------------------------'
  fi
}

# -----------------------------------------------------------------------------
# _helper_change_announce_device_type()
# Beschreibung: Gibt aus ob es ein Einzelgerät oder Sammeleintrag ist
# Parameter:    $1 = device_count
# Rückgabe:     keine (Seiteneffekt: stdout)
# -----------------------------------------------------------------------------
_helper_change_announce_device_type() {
  local device_count="$1"
  if [[ "$device_count" -eq 1 ]]; then
    echo_logged "->Einzelgerät"
  else
    echo_logged "->Sammeleintrag"
  fi
}

# -----------------------------------------------------------------------------
# _helper_change_resolve_field()
# Beschreibung: Gibt field zurück (aus Argument oder interaktiver Eingabe)
# Parameter:    $1 = field (kann leer sein), $2 = device_count
# Rückgabe:     Aufgelöstes field auf stdout; rc=2 bei Fehler
# -----------------------------------------------------------------------------
_helper_change_resolve_field() {
  local field="$1" device_count="$2"
  if [[ -z "$field" ]]; then
    if _helper_core_is_interactive; then
      field="$(_prompt_field "$device_count")"
    else
      error_logged "ERROR: missing FIELD (non-interactive). Provide 1/2/3/4 or name (Beschreibung/Location/Status/Anzahl/Kategorie)."
      return 2
    fi
  fi
  printf '%s' "$field"
}

# -----------------------------------------------------------------------------
# _helper_change_resolve_new_value()
# Beschreibung: Gibt new_value zurück (aus Argument oder interaktiver Eingabe)
# Parameter:    $1 = new_value (kann leer sein)
# Rückgabe:     Aufgelöster Wert auf stdout; rc=2 bei Fehler
# -----------------------------------------------------------------------------
_helper_change_resolve_new_value() {
  local new_value="$1"
  if [[ -z "$new_value" ]]; then
    if _helper_core_is_interactive; then
      read_logged 'neuer Inhalt= ' new_value
    else
      error_logged "ERROR: missing NEW_VALUE (non-interactive)"
      return 2
    fi
  fi
  printf '%s' "$new_value"
}

# -----------------------------------------------------------------------------
# _helper_change_find_old_line()
# Beschreibung: Sucht die erste Zeile in einer Datei, die mit einem Präfix beginnt
# Parameter:    $1 = device_file, $2 = change_prefix
# Rückgabe:     Gefundene Zeile auf stdout (leer wenn nicht gefunden)
# -----------------------------------------------------------------------------
_helper_change_find_old_line() {
  local device_file="$1" change_prefix="$2"
  grep -m 1 -F "$change_prefix" "$device_file" || true
}

# -----------------------------------------------------------------------------
# _helper_change_announce_change()
# Beschreibung: Gibt aus was geändert wird (alte vs. neue Zeile)
# Parameter:    $1 = old_line, $2 = final_line
# Rückgabe:     keine (Seiteneffekt: stdout)
# -----------------------------------------------------------------------------
_helper_change_announce_change() {
  local old_line="$1" final_line="$2"
  if [[ -z "$old_line" ]]; then
    echo_logged "could not find the line to change, adding it anyway"
  else
    echo_logged "ändere \"$old_line\" zu \"$final_line\""
  fi
  echo_logged "final change: $final_line"
}

# -----------------------------------------------------------------------------
# _helper_change_rewrite_file()
# Beschreibung: Schreibt die Gerätedatei atomar neu mit ersetzter/hinzugefügter Zeile
# Parameter:    $1 = device_file, $2 = change_prefix, $3 = final_line
# Rückgabe:     rc=0 Erfolg, rc=1 Fehler (Seiteneffekt: Datei wird überschrieben)
# -----------------------------------------------------------------------------
_helper_change_rewrite_file() {
  local device_file="$1" change_prefix="$2" final_line="$3"
  local tmp
  tmp="$(mktemp)" || return 1
  log_info "Temporäre Datei erzeugt tmp='$tmp'"

  awk -v p="$change_prefix" -v newline="$final_line" '
    BEGIN { done=0 }
    {
      if (substr($0, 1, length(p)) == p) {
        if (!done) { print newline; done=1 }
        next
      }
      print
    }
    END { if (!done) print newline }
  ' "$device_file" >"$tmp" && mv -- "$tmp" "$device_file"
}

# -----------------------------------------------------------------------------
# _helper_change_export_globals()
# Beschreibung: Setzt globale Ausgabe-Variablen für aufrufende Runner-Skripte
# Parameter:    $1 = device_id, $2 = device_count, $3 = change_prefix, $4 = final_line
# Rückgabe:     keine (Seiteneffekt: Globals DEVICE_ID, DEVICE_count, CHANGE, FINALCHANGE)
# -----------------------------------------------------------------------------
_helper_change_export_globals() {
  local device_id="$1" device_count="$2" change_prefix="$3" final_line="$4"
  DEVICE_ID="$device_id"
  DEVICE_count="$device_count"
  CHANGE="$change_prefix"
  FINALCHANGE="$final_line"
}

change_device_main() {
  setup_logging "$@"
  install_logging_traps

  local device_id="${1-}"
  local field="${2-}"
  local new_value="${3-}"

  log_info "change_device_main gestartet device_id='${device_id-}' field='${field-}' new_value='${new_value-}'"

  device_id="$(_helper_change_resolve_device_id "$device_id")" || return $?
  echo_logged "device ID=$device_id"
  log_info "Verwende device_id='$device_id'"

  if ! _helper_change_validate_device_id "$device_id"; then
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

##############################
# create_device.sh functions
##############################

# -----------------------------------------------------------------------------
# _helper_create_read_field()
# Beschreibung: Liest einen einzelnen Gerätedaten-Wert interaktiv ein
# Parameter:    $1 = Prompt-Text, $2 = Ziel-Variablenname
# Rückgabe:     keine (Seiteneffekt: Ziel-Variable wird gesetzt)
# -----------------------------------------------------------------------------
_helper_create_read_field() {
  local prompt="$1" target_var="$2"
  read_logged "$prompt" "$target_var"
}

# -----------------------------------------------------------------------------
# _helper_create_write_field()
# Beschreibung: Schreibt ein Schlüssel=Wert-Paar in eine Datei (append oder overwrite)
# Parameter:    $1 = device_file, $2 = key, $3 = value, $4 = mode (">" oder ">>")
# Rückgabe:     keine (Seiteneffekt: Datei wird beschrieben)
# -----------------------------------------------------------------------------
_helper_create_write_field() {
  local device_file="$1" key="$2" value="$3" mode="$4"
  if [[ "$mode" == ">" ]]; then
    printf '%s=%s\n' "$key" "$value" >"$device_file"
  else
    printf '%s=%s\n' "$key" "$value" >>"$device_file"
  fi
  log_info "Geschrieben: ${key}='${value}'"
}

# -----------------------------------------------------------------------------
# _helper_create_fill_fields()
# Beschreibung: Liest und schreibt alle Felder eines fields-Arrays in eine Datei
# Parameter:    $1 = device_file, $2.. = field definitions ("patterns:Prefix=")
# Rückgabe:     keine (Seiteneffekt: Datei wird beschrieben)
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# _helper_create_resolve_device_id()
# Beschreibung: Gibt device_id zurück (aus Argument oder interaktiver Eingabe)
# Parameter:    $1 = device_id (kann leer sein)
# Rückgabe:     Aufgelöste device_id auf stdout
# -----------------------------------------------------------------------------
_helper_create_resolve_device_id() {
  local device_id="$1"
  if [[ -z "$device_id" ]]; then
    read_logged 'Enter the device ID: ' device_id
  fi
  printf '%s' "$device_id"
}

# -----------------------------------------------------------------------------
# _helper_create_detect_device_type()
# Beschreibung: Erkennt anhand der ID ob Einzelgerät (1) oder Sammeleintrag (2)
# Parameter:    $1 = device_id
# Rückgabe:     "1" oder "2" auf stdout (KEIN echo_logged hier – wird per $() aufgerufen)
# -----------------------------------------------------------------------------
_helper_create_detect_device_type() {
  local device_id="$1"
  if [[ "$device_id" =~ ^[+-]?[0-9]+$ ]]; then
    printf '%s' 1
  else
    printf '%s' 2
  fi
}

# -----------------------------------------------------------------------------
# _helper_create_assert_file_not_exists()
# Beschreibung: Prüft ob eine Gerätedatei noch nicht existiert
# Parameter:    $1 = device_file, $2 = device_id
# Rückgabe:     rc=0 nicht vorhanden, rc=1 bereits vorhanden
# -----------------------------------------------------------------------------
_helper_create_assert_file_not_exists() {
  local device_file="$1" device_id="$2"
  if [[ -e "$device_file" ]]; then
    error_logged "device $device_id already exists"
    log_error "Datei existiert bereits: '$device_file'"
    return 1
  fi
}

# -----------------------------------------------------------------------------
# _helper_create_init_device_file()
# Beschreibung: Erzeugt eine leere Gerätedatei
# Parameter:    $1 = device_file, $2 = device_id
# Rückgabe:     keine (Seiteneffekt: leere Datei wird erzeugt)
# -----------------------------------------------------------------------------
_helper_create_init_device_file() {
  local device_file="$1" device_id="$2"
  : >"$device_file"
  echo_logged "device $device_id has been created"
  log_info "Leere Gerätedatei erzeugt: '$device_file'"
}

# -----------------------------------------------------------------------------
# _helper_create_fill_device_file()
# Beschreibung: Befüllt die Gerätedatei je nach Typ mit Feldern
# Parameter:    $1 = device_file, $2 = device_count
# Rückgabe:     rc=0 Erfolg, rc=1 unbekannter Typ
# -----------------------------------------------------------------------------
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

create_device_main() {
  setup_logging "$@"
  install_logging_traps

  log_info "create_device_main gestartet"

  mkdir -p -- "$DEVICE_DIR"
  echo_logged 'device folder has been created'
  log_info "DEVICE_DIR bereit: '$DEVICE_DIR'"

  local device_id="${1-}"
  log_info "Argument device_id='${device_id-}'"

  device_id="$(_helper_create_resolve_device_id "$device_id")"

  if ! _helper_change_validate_device_id "$device_id"; then
    error_logged "ERROR: invalid device ID: '$device_id'"
    log_error "Ungültige device_id='$device_id'"
    return 2
  fi

  echo_logged "device ID=$device_id"
  log_info "Verwende device_id='$device_id'"

  local device_count
  device_count="$(_helper_create_detect_device_type "$device_id")"
  log_info "device_count='$device_count'"

  local device_file="$DEVICE_DIR/$device_id.txt"
  log_info "device_file='$device_file'"

  _helper_create_assert_file_not_exists "$device_file" "$device_id" || return $?
  _helper_create_init_device_file "$device_file" "$device_id"
  _helper_create_fill_device_file "$device_file" "$device_count" || return $?

  DEVICE_ID="$device_id"
  DEVICE_count="$device_count"

  log_info "create_device_main abgeschlossen DEVICE_ID='$DEVICE_ID' DEVICE_count='$DEVICE_count'"
}

##############################
# find_and_change.sh functions
##############################

# -----------------------------------------------------------------------------
# _helper_fac_search_device()
# Beschreibung: Führt die Gerätesuche aus und setzt FOUND_*-Globals
# Parameter:    keine
# Rückgabe:     keine (Seiteneffekt: FOUND_MATCH_COUNT, FOUND_DEVICE_ID)
# -----------------------------------------------------------------------------
_helper_fac_search_device() {
  find_device_main
}

# -----------------------------------------------------------------------------
# _helper_fac_check_match_count()
# Beschreibung: Prüft die Anzahl der Treffer und gibt Fehlermeldung aus
# Parameter:    $1 = FOUND_MATCH_COUNT
# Rückgabe:     rc=0 genau 1 Treffer, rc=1 kein Treffer, rc=2 mehrere Treffer
# -----------------------------------------------------------------------------
_helper_fac_check_match_count() {
  local count="$1"
  if (( count == 0 )); then
    echo "Kein Gerät gefunden." >&2
    return 1
  elif (( count > 1 )); then
    echo "Mehrere Geräte gefunden (${count}), keine eindeutige Auswahl. Bitte Suchkriterium verfeinern." >&2
    return 2
  fi
  return 0
}

# -----------------------------------------------------------------------------
# _helper_fac_assert_found_id()
# Beschreibung: Prüft ob FOUND_DEVICE_ID gesetzt ist
# Parameter:    $1 = FOUND_DEVICE_ID
# Rückgabe:     rc=0 gesetzt, rc=1 leer
# -----------------------------------------------------------------------------
_helper_fac_assert_found_id() {
  local found_id="$1"
  if [[ -z "$found_id" ]]; then
    echo "Interner Fehler: FOUND_DEVICE_ID ist leer trotz genau 1 Treffer." >&2
    return 1
  fi
}

find_and_change_main() {
  _helper_fac_search_device

  local rc
  _helper_fac_check_match_count "$FOUND_MATCH_COUNT"
  rc=$?

  if (( rc == 1 )); then
    return 1
  elif (( rc == 2 )); then
    find_device_main
  fi

  _helper_fac_assert_found_id "${FOUND_DEVICE_ID:-}" || return 1

  echo "Bearbeite Gerät mit ID: $FOUND_DEVICE_ID"
  change_device_main "$FOUND_DEVICE_ID"
}

##############################
# find_device.sh functions
##############################

FOUND_DEVICE_ID=""
FOUND_MATCHES=()
FOUND_MATCH_COUNT=0

# -----------------------------------------------------------------------------
# _helper_find_normalize_mode()
# Beschreibung: Normalisiert einen Suchmodus-String auf einen kanonischen Wert
# Parameter:    $1 = roher Modus-String
# Rückgabe:     Normalisierter Modus auf stdout; rc=1 bei ungültigem Modus
# -----------------------------------------------------------------------------
_helper_find_normalize_mode() {
  _helper_modes_normalize "${1-}"
}

_normalize_mode() {
  _helper_find_normalize_mode "${1-}"
}

# -----------------------------------------------------------------------------
# _helper_find_print_file_numbered()
# Beschreibung: Gibt eine Datei mit Zeilennummern und Trennzeile aus
# Parameter:    $1 = Dateipfad
# Rückgabe:     keine (Seiteneffekt: stdout)
# -----------------------------------------------------------------------------
_helper_find_print_file_numbered() {
  local file="$1"
  echo_logged "----- $file -----"
  nl -ba -- "$file"
  log_info "Datei nummeriert ausgegeben '$file'"
}

_print_file_numbered() {
  _helper_find_print_file_numbered "$1"
}

# -----------------------------------------------------------------------------
# _helper_find_resolve_device_id_interactive()
# Beschreibung: Liest device_id interaktiv ein wenn nicht angegeben
# Parameter:    $1 = device_id (kann leer sein)
# Rückgabe:     Aufgelöste device_id auf stdout; rc=2 bei Fehler
# -----------------------------------------------------------------------------
_helper_find_resolve_device_id_interactive() {
  local device_id="$1"
  if [[ -z "$device_id" ]]; then
    if _helper_core_is_interactive; then
      read_logged 'Find device by ID: ' device_id
    else
      error_logged "ERROR: missing DEVICE_ID (non-interactive)"
      return 2
    fi
  fi
  printf '%s' "$device_id"
}

# -----------------------------------------------------------------------------
# _helper_find_set_found_globals_single()
# Beschreibung: Setzt FOUND_*-Globals für genau einen Treffer per ID
# Parameter:    $1 = device_id, $2 = device_file
# Rückgabe:     keine (Seiteneffekt: FOUND_DEVICE_ID, FOUND_MATCHES, FOUND_MATCH_COUNT)
# -----------------------------------------------------------------------------
_helper_find_set_found_globals_single() {
  local device_id="$1" device_file="$2"
  FOUND_DEVICE_ID="$device_id"
  FOUND_MATCHES=( "$device_file" )
  FOUND_MATCH_COUNT=1
}

find_by_id() {
  local device_id="${1-}"
  log_info "find_by_id gestartet device_id='${device_id-}'"

  device_id="$(_helper_find_resolve_device_id_interactive "$device_id")" || return $?

  echo_logged "device ID: $device_id"

  if ! _helper_change_validate_device_id "$device_id"; then
    error_logged "ERROR: invalid device ID: '$device_id'"
    return 2
  fi

  local device_file="$DEVICE_DIR/$device_id.txt"
  log_info "device_file='$device_file'"

  _helper_change_assert_device_file_exists "$device_file" "$device_id" || return $?

  echo_logged "Found device: $device_id"
  _helper_find_print_file_numbered "$device_file"
  log_info "find_by_id abgeschlossen"

  _helper_find_set_found_globals_single "$device_id" "$device_file"
}

# -----------------------------------------------------------------------------
# _helper_find_collect_device_files()
# Beschreibung: Sammelt alle *.txt-Dateien im DEVICE_DIR in ein Array
# Parameter:    $1 = Ziel-Array-Name (nameref)
# Rückgabe:     rc=0 Dateien gefunden, rc=1 keine Dateien
# -----------------------------------------------------------------------------
_helper_find_collect_device_files() {
  local -n _files_ref="$1"
  shopt -s nullglob
  _files_ref=( "$DEVICE_DIR"/*.txt )
  shopt -u nullglob

  log_info "Anzahl Gerätedateien='${#_files_ref[@]}'"

  if (( ${#_files_ref[@]} == 0 )); then
    error_logged "No device files found in '$DEVICE_DIR'"
    return 1
  fi
}

# -----------------------------------------------------------------------------
# _helper_find_resolve_search_value()
# Beschreibung: Gibt Suchwert zurück (aus Argument oder interaktiver Eingabe)
# Parameter:    $1 = value (kann leer sein), $2 = key (für Prompt-Text)
# Rückgabe:     Aufgelöster Suchwert auf stdout; rc=2 bei Fehler
# -----------------------------------------------------------------------------
_helper_find_resolve_search_value() {
  local value="$1" key="$2"
  if [[ -z "$value" ]]; then
    if _helper_core_is_interactive; then
      value="$(read_logged "Find device by ${key%=}: ")"
      log_debug "_helper_find_resolve_search_value: nach read_logged value='$value'"
    else
      error_logged "ERROR: missing search value for ${key%=} (non-interactive)"
      return 2
    fi
  fi
  printf '%s' "$value"
}

# -----------------------------------------------------------------------------
# _helper_find_file_matches_key_value()
# Beschreibung: Prüft ob eine Datei eine Zeile mit key enthält, die value enthält
# Parameter:    $1 = file, $2 = key, $3 = value
# Rückgabe:     rc=0 Treffer, rc=1 kein Treffer
# -----------------------------------------------------------------------------
_helper_find_file_matches_key_value() {
  local file="$1" key="$2" value="$3"
  local line
  line="$(grep -m 1 -iE "^${key}" "$file" 2>/dev/null || true)"
  [[ -z "$line" ]] && return 1
  log_debug "Gefundene Zeile in '$file': '$line'"
  printf '%s\n' "$line" | grep -qiF -- "$value"
}

# -----------------------------------------------------------------------------
# _helper_find_extract_id_from_file()
# Beschreibung: Extrahiert die device_id aus einem Dateipfad (Dateiname ohne .txt)
# Parameter:    $1 = Dateipfad
# Rückgabe:     device_id auf stdout
# -----------------------------------------------------------------------------
_helper_find_extract_id_from_file() {
  local match_file="$1"
  local filename="${match_file##*/}"
  printf '%s' "${filename%.txt}"
}

# -----------------------------------------------------------------------------
# _helper_find_handle_single_match()
# Beschreibung: Verarbeitet genau einen Treffer: Ausgabe + Globals setzen
# Parameter:    $1 = match_file, $2 = key, $3 = value
# Rückgabe:     keine (Seiteneffekt: FOUND_DEVICE_ID, FOUND_MATCH_COUNT, stdout)
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# _helper_find_handle_multi_match()
# Beschreibung: Gibt alle Treffer-Dateien nummeriert aus
# Parameter:    $@ = Liste der Treffer-Dateipfade
# Rückgabe:     keine (Seiteneffekt: stdout)
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# find_by_* functions — generated dynamically from find_modes
# Each non-id mode gets a find_by_<canonical>() function that calls
# _find_by_key_contains with the correct file key.
# -----------------------------------------------------------------------------
for _fmode in "${find_modes[@]}"; do
  _frest="${_fmode#*:}"
  _fcanonical="${_frest%%:*}"
  _fkey="${_frest#*:}"
  [[ "$_fcanonical" == "id" ]] && continue
  eval "find_by_${_fcanonical}() { _find_by_key_contains '${_fkey}' \"\${1-}\"; }"
done
unset _fmode _frest _fcanonical _fkey

# -----------------------------------------------------------------------------
# _helper_find_resolve_mode()
# Beschreibung: Gibt Suchmodus zurück (aus Argument oder interaktiver Eingabe)
# Parameter:    $1 = mode (kann leer sein)
# Rückgabe:     Aufgelöster Modus auf stdout; rc=2 bei Fehler
# -----------------------------------------------------------------------------
_helper_find_resolve_mode() {
  local mode="$1"
  if [[ -z "$mode" ]]; then
    if _helper_core_is_interactive; then
      read_logged "$(_helper_modes_build_prompt prompt)" mode
    else
      error_logged "ERROR: missing mode (non-interactive). Use: $(_helper_modes_build_prompt error)"
      return 2
    fi
  fi
  printf '%s' "$mode"
}

# -----------------------------------------------------------------------------
# _helper_find_dispatch_by_mode()
# Beschreibung: Ruft die passende find_by_*-Funktion anhand des normalisierten Modus auf
# Parameter:    $1 = normalized mode, $2 = query
# Rückgabe:     Delegiert an find_by_*-Funktion
# -----------------------------------------------------------------------------
_helper_find_dispatch_by_mode() {
  local normalized="$1" query="$2"
  if [[ "$normalized" == "id" ]]; then
    find_by_id "$query"
  else
    "find_by_${normalized}" "$query"
  fi
}

find_device_main() {
  setup_logging "$@"
  install_logging_traps

  local mode="${1-}"
  local query="${2-}"

  log_info "find_device_main gestartet mode='${mode-}' query='${query-}'"

  mode="$(_helper_find_resolve_mode "$mode")" || return $?

  local normalized=""
  if ! normalized="$(_helper_find_normalize_mode "$mode")"; then
    error_logged "invalid input: mode='$mode'"
    return 2
  fi
  log_info "normalized mode='$normalized'"

  _helper_find_dispatch_by_mode "$normalized" "$query"

  log_info "find_device_main abgeschlossen"
}

##############################
# entnahme / change_device_count
##############################

# -----------------------------------------------------------------------------
# _helper_count_resolve_old_value()
# Beschreibung: Liest den aktuellen Anzahl-Wert aus der Gerätedatei
# Parameter:    $1 = device_file, $2 = change_prefix
# Rückgabe:     Alter Wert auf stdout
# -----------------------------------------------------------------------------
_helper_count_resolve_old_value() {
  local device_file="$1" change_prefix="$2"
  local old_line
  old_line="$(grep -m 1 -F "$change_prefix" "$device_file" || true)"
  printf '%s' "${old_line#"$change_prefix"}"
}

# -----------------------------------------------------------------------------
# _helper_count_prompt_operation()
# Beschreibung: Fragt den Benutzer nach der gewünschten Zähloperation
# Parameter:    keine
# Rückgabe:     Auswahl ("1", "2" oder "3") auf stdout
# -----------------------------------------------------------------------------
_helper_count_prompt_operation() {
  local auswahl=""
  read_logged 'Möchten Sie die Anzahl erhöhen oder verringern? |(1) Erhöhen|  |(2) Verringern|    |(3) Ändern| ' auswahl
  printf '%s' "$auswahl"
}

# -----------------------------------------------------------------------------
# _helper_count_validate_operation()
# Beschreibung: Prüft ob die Auswahl ein gültiger Wert (1/2/3) ist
# Parameter:    $1 = auswahl
# Rückgabe:     rc=0 gültig, rc=2 ungültig
# -----------------------------------------------------------------------------
_helper_count_validate_operation() {
  local auswahl="$1"
  if [[ "$auswahl" != @(1|2|3) ]]; then
    error_logged "Ungültige Auswahl: '$auswahl'. Bitte 1, 2 oder 3 eingeben."
    return 2
  fi
}

# -----------------------------------------------------------------------------
# _helper_count_compute_new_value()
# Beschreibung: Berechnet den neuen Anzahl-Wert basierend auf Auswahl und altem Wert
# Parameter:    $1 = auswahl, $2 = old_value
# Rückgabe:     Neuer Wert auf stdout
# -----------------------------------------------------------------------------
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

# -----------------------------------------------------------------------------
# _helper_count_resolve_final_new_value()
# Beschreibung: Stellt sicher dass new_value gesetzt ist (Fallback: interaktive Eingabe)
# Parameter:    $1 = new_value (kann leer sein)
# Rückgabe:     Aufgelöster Wert auf stdout; rc=2 bei Fehler
# -----------------------------------------------------------------------------
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

  if ! _helper_change_validate_device_id "$device_id"; then
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

##############################
# change_count_main
##############################

change_count_main() {
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