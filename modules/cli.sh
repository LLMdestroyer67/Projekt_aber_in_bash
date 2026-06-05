# CLI dispatcher: minimal non-interactive command routing
# Provides a simple run_cli "$@" entry that maps top-level commands to *_main functions

# Dependencies: logging, io
if [[ -f "$SCRIPT_DIR/modules/logging.sh" ]]; then
  . "$SCRIPT_DIR/modules/logging.sh"
fi
if [[ -f "$SCRIPT_DIR/modules/io.sh" ]]; then
  . "$SCRIPT_DIR/modules/io.sh"
fi

# run_cli: dispatch command to the corresponding main function
# Usage: run_cli <command> [args...]
# Commands supported: create, change, find, read, find-and-change, change-count
run_cli() {
  local cmd="${1-}"
  shift || true
  case "$cmd" in
    create)
      create_device_main "$@" ;;
    change)
      change_device_main "$@" ;;
    find)
      find_device_main "$@" ;;
    read)
      read_device_main "$@" ;;
    find-and-change|find_and_change)
      find_and_change_main "$@" ;;
    change-count|count)
      change_count_main "$@" ;;
    '')
      echo "No command provided. Supported: create, change, find, read, find-and-change, change-count" >&2
      return 2 ;;
    *)
      echo "Unknown command: $cmd" >&2
      return 2 ;;
  esac
}
