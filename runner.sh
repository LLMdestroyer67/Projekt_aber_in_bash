#!/usr/bin/env bash
set -euo pipefail

# Always source files relative to this runner's location
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_NAME="$(basename -- "$0")"

# Config (override via env)
DEVICE_DIR="${DEVICE_DIR:-$SCRIPT_DIR/devices}"
RUN_INTERVAL_SECONDS="${RUN_INTERVAL_SECONDS:-2}"

# Sourcing the library of functions
. "$SCRIPT_DIR/experimental.sh"  #<---Production: common.sh

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

  if _is_interactive; then
    # Interactive example: ask what to do
    echo_logged ""
    echo_logged "Choose action: |(1) create device| |(2) change device| |(3) find device| |(4) find and change device| |(5) change count|  |(q) quit|"

    local choice=""
    read_logged '> ' choice
    log_info "Menüauswahl choice='$choice'"

    case "$choice" in
      1)
        log_info "Running create_device_main (interactive)..."
        # prompts happen inside create_device_main if args are missing
        if SCRIPT_NAME="create_device.sh" DEVICE_DIR="$DEVICE_DIR" create_device_main; then
          log_info "create_device_main erfolgreich"
        else
          rc=$?
          log_error "create_device_main fehlgeschlagen rc=$rc"
        fi
        ;;
      2)
        log_info "Running change_device_main (interactive)..."
        if SCRIPT_NAME="change_device.sh" DEVICE_DIR="$DEVICE_DIR" change_device_main; then
          log_info "change_device_main erfolgreich"
        else
          rc=$?
          log_error "change_device_main fehlgeschlagen rc=$rc"
        fi
        ;;
      3)
        log_info "Running find_device_main (interactive)..."
        if SCRIPT_NAME="find_device.sh" DEVICE_DIR="$DEVICE_DIR" find_device_main; then
          log_info "find_device_main erfolgreich"
        else
          rc=$?
          log_error "find_device_main fehlgeschlagen rc=$rc"
        fi
        ;;
      4)
        log_info "Running find_and_change_main (interactive)..."
        if SCRIPT_NAME="find_and_change.sh" DEVICE_DIR="$DEVICE_DIR" find_and_change_main; then
          log_info "find_and_change_main erfolgreich"
        else
          rc=$?
          log_error "find_and_change_main fehlgeschlagen rc=$rc"
        fi
        ;;
      5)
        log_info "Running change_count_main (interactive)..."
        if SCRIPT_NAME="change_count.sh" DEVICE_DIR="$DEVICE_DIR" change_count_main; then
          log_info "change_count_main erfolgreich"
        else
          rc=$?
          log_error "change_count_main fehlgeschlagen rc=$rc"
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

  else
    # Non-interactive example (daemon-style):
    # Your logic must provide args so the called functions don't prompt/hang.

    log_info "Non-interactive Modus erkannt"

    # ---- Example placeholder logic: do nothing by default ----
    # Replace this block with your own logic / queue / rules.
    #
    # Example calls:
    # SCRIPT_NAME="create_device.sh" DEVICE_DIR="$DEVICE_DIR" create_device_main "123"
    # SCRIPT_NAME="change_device.sh" DEVICE_DIR="$DEVICE_DIR" change_device_main "123" "Status" "active"
    #
    return 0
  fi
}

main() {
  setup_logging "$@"
  install_logging_traps

  log_info "Runner started (DEVICE_DIR=$DEVICE_DIR, interval=${RUN_INTERVAL_SECONDS}s)"

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