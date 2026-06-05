# Device operation helpers: atomic rewrite and export helpers
# Contains helpers used by change/create operations that perform file writes

# Require logging helper
if [[ -f "$SCRIPT_DIR/modules/logging.sh" ]]; then
  . "$SCRIPT_DIR/modules/logging.sh"
fi

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

_helper_change_export_globals() {
  local device_id="$1" device_count="$2" change_prefix="$3" final_line="$4"
  DEVICE_ID="$device_id"
  DEVICE_count="$device_count"
  CHANGE="$change_prefix"
  FINALCHANGE="$final_line"
}
