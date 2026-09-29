#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# geraeteverwaltung.sh – German-named device inventory entry point
#
# With command-line arguments, runner.sh dispatches one non-interactive
# operation through run_cli. With no arguments, it retains the interactive loop.
# =============================================================================

# Always source files relative to this runner's location
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename -- "$0")"

# Config (override via env)
DEVICE_DIR="${GERAETE_VERZEICHNIS:-${DEVICE_DIR:-$SCRIPT_DIR/devices}}"
GERAETE_VERZEICHNIS="$DEVICE_DIR"
RUN_INTERVAL_SECONDS="${LAUF_INTERVALL_SEKUNDEN:-${RUN_INTERVAL_SECONDS:-2}}"
LAUF_INTERVALL_SEKUNDEN="$RUN_INTERVAL_SECONDS"

# Sourcing the canonical library of functions
. "$SCRIPT_DIR/geraeteverwaltung_funktionen.sh"

shutdown=0

handle_shutdown() {
  local signal="$1"
  log_info "Signal empfangen: $signal"
  shutdown=1
}

trap 'handle_shutdown INT' INT
trap 'handle_shutdown TERM' TERM

run_once() {
  log_info "run_once gestartet"

  # ===========================
  # LOGIC
  # ===========================

  if _helper_core_is_interactive; then
    # Interactive example: ask what to do
    echo_logged ""
    echo_logged "Aktion wählen: |(1) Gerät anlegen| |(2) Gerät ändern| |(3) Gerät suchen| |(4) Gerät suchen und ändern|  |(q) beenden|"

    local choice=""
    read_logged '> ' choice
    if (( READ_LOGGED_EOF )); then
      log_info "Interaktive Eingabe beendet (EOF)"
      shutdown=1
      return 0
    fi
    log_info "Menüauswahl choice='$choice'"

    case "$choice" in
      1)
        log_info "Running geraet_anlegen (interactive)..."
        if SCRIPT_NAME="geraet_anlegen.sh" DEVICE_DIR="$DEVICE_DIR" geraet_anlegen; then
          log_info "geraet_anlegen erfolgreich"
        else
          rc=$?
          log_error "geraet_anlegen fehlgeschlagen rc=$rc"
          if [[ "$rc" -eq 3 ]]; then shutdown=1; fi
        fi
        ;;
      2)
        log_info "Running geraet_aendern (interactive)..."
        if SCRIPT_NAME="geraet_aendern.sh" DEVICE_DIR="$DEVICE_DIR" geraet_aendern; then
          log_info "geraet_aendern erfolgreich"
        else
          rc=$?
          log_error "geraet_aendern fehlgeschlagen rc=$rc"
          if [[ "$rc" -eq 3 ]]; then shutdown=1; fi
        fi
        ;;
      3)
        log_info "Running geraet_suchen (interactive)..."
        if SCRIPT_NAME="geraet_suchen.sh" DEVICE_DIR="$DEVICE_DIR" geraet_suchen; then
          log_info "geraet_suchen erfolgreich"
        else
          rc=$?
          log_error "geraet_suchen fehlgeschlagen rc=$rc"
          if [[ "$rc" -eq 3 ]]; then shutdown=1; fi
        fi
        ;;
      4)
        log_info "Running geraet_suchen_und_aendern_menue (interactive)..."
        if SCRIPT_NAME="geraet_suchen_und_aendern_menue.sh" DEVICE_DIR="$DEVICE_DIR" geraet_suchen_und_aendern_menue; then
          log_info "geraet_suchen_und_aendern_menue erfolgreich"
        else
          rc=$?
          log_error "geraet_suchen_und_aendern_menue fehlgeschlagen rc=$rc"
          if [[ "$rc" -eq 3 ]]; then shutdown=1; fi
        fi
        ;;
      q|Q)
        log_info "Benutzer hat Quit gewählt"
        shutdown=1
        ;;
      *)
        error_logged "Unknown choice: $choice"
        ;;
    esac

  fi
}

main() {
  setup_logging "$@"
  install_logging_traps

  log_info "Runner gestartet (GERAETE_VERZEICHNIS=$DEVICE_DIR, intervall=${RUN_INTERVAL_SECONDS}s)"

  if (( $# > 0 )); then
    befehl_ausfuehren "$@"
    return $?
  fi

  while [[ "$shutdown" -eq 0 ]]; do
    # Don’t let one failure kill the loop; capture rc and continue.
    if run_once; then
      log_info "run_once erfolgreich abgeschlossen"
    else
      rc=$?
      log_error "run_once error rc=$rc (continuing)"
    fi

    [[ "$shutdown" -eq 1 ]] && break

    log_debug "Sleep ${RUN_INTERVAL_SECONDS}s"
    sleep "$RUN_INTERVAL_SECONDS"
  done

  log_info "Runner stopped"
}
 
main "$@"