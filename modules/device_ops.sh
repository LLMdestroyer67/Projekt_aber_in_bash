# Device operation helpers: atomic rewrite and export helpers
# Contains helpers used by change/create operations that perform file writes

# Require logging helper
if [[ -f "$SCRIPT_DIR/modules/logging.sh" ]]; then
  . "$SCRIPT_DIR/modules/logging.sh"
fi

_helper_device_lock_acquire() {
  local lock_dir="${DEVICE_DIR}.lock"
  local timeout="${DEVICE_LOCK_TIMEOUT_SECONDS:-10}"
  local deadline=$((SECONDS + timeout))

  mkdir -p -- "$DEVICE_DIR"
  while ! mkdir -- "$lock_dir" 2>/dev/null; do
    if (( SECONDS >= deadline )); then
      error_logged "ERROR: timed out waiting for device lock '$lock_dir'"
      return 1
    fi
    sleep 0.05
  done
  DEVICE_LOCK_DIR="$lock_dir"
}

_helper_device_lock_release() {
  if [[ -n "${DEVICE_LOCK_DIR:-}" ]]; then
    rmdir -- "$DEVICE_LOCK_DIR" 2>/dev/null || true
    unset DEVICE_LOCK_DIR
  fi
}

_helper_change_rewrite_file() {
  local device_file="$1" change_prefix="$2" final_line="$3"
  local tmp="" rc=0
  _helper_device_lock_acquire || return 1
  tmp="$(mktemp)" || rc=1
  if (( rc == 0 )); then
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
    ' "$device_file" >"$tmp" && mv -- "$tmp" "$device_file" || rc=1
  fi
  [[ -n "$tmp" && -e "$tmp" ]] && rm -f -- "$tmp"
  _helper_device_lock_release
  return "$rc"
}

_helper_change_export_globals() {
  local device_id="$1" device_count="$2" change_prefix="$3" final_line="$4"
  DEVICE_ID="$device_id"
  DEVICE_count="$device_count"
  CHANGE="$change_prefix"
  FINALCHANGE="$final_line"
}
