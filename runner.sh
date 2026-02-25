#!/usr/bin/env bash
set -euo pipefail

# Always source files relative to this runner's location
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

# Config (override via env)
DEVICE_DIR="${DEVICE_DIR:-$SCRIPT_DIR/devices}"
RUN_INTERVAL_SECONDS="${RUN_INTERVAL_SECONDS:-2}"

# Source your modules (these files must NOT auto-run when sourced)
source "$SCRIPT_DIR/create_device.sh"   # must provide: create_device_main
source "$SCRIPT_DIR/change_device.sh"   # must provide: change_device_main

log() { printf '[%(%F %T)T] %s\n' -1 "$*"; }

shutdown=0
trap 'shutdown=1' INT TERM

run_once() {
  # ===========================
  # PUT YOUR LOGIC HERE
  #
  # Decide what to do next and in what order.
  # Examples below show both interactive and non-interactive calling.
  # ===========================

  if [[ -t 0 && -t 1 ]]; then
    # Interactive example: ask what to do
    echo
    echo "Choose action: (1) create device  (2) change device  (q) quit"
    read -r -p '> ' choice

    case "$choice" in
      1)
        log "Running create_device_main (interactive)..."
        # prompts happen inside create_device_main if args are missing
        if ! DEVICE_DIR="$DEVICE_DIR" create_device_main; then
          log "create failed (rc=$?)"
        fi
        ;;
      2)
        log "Running change_device_main (interactive)..."
        if ! DEVICE_DIR="$DEVICE_DIR" change_device_main; then
          log "change failed (rc=$?)"
        fi
        ;;
      q|Q)
        shutdown=1
        ;;
      *)
        log "Unknown choice: $choice"
        ;;
    esac

  else
    # Non-interactive example (daemon-style):
    # Your logic must provide args so the called functions don't prompt/hang.

    # ---- Example placeholder logic: do nothing by default ----
    # Replace this block with your own logic / queue / rules.
    #
    # Example calls:
    # DEVICE_DIR="$DEVICE_DIR" create_device_main "123"
    # DEVICE_DIR="$DEVICE_DIR" change_device_main "123" "Status" "active"
    #
    return 0
  fi
}

main() {
  log "Runner started (DEVICE_DIR=$DEVICE_DIR, interval=${RUN_INTERVAL_SECONDS}s)"

  while [[ "$shutdown" -eq 0 ]]; do
    # Don’t let one failure kill the loop; capture rc and continue.
    if ! run_once; then
      rc=$?
      log "run_once error rc=$rc (continuing)"
    fi

    [[ "$shutdown" -eq 1 ]] && break
    sleep "$RUN_INTERVAL_SECONDS"
  done

  log "Runner stopped"
}

main "$@"