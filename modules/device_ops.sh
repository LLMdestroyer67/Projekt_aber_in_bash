# Device operation helpers: atomic rewrite and export helpers
# Contains helpers used by change/create operations that perform file writes

# Require logging helper
if [[ -f "$SCRIPT_DIR/modules/logging.sh" ]]; then
  . "$SCRIPT_DIR/modules/logging.sh"
fi

_helper_device_lock_acquire() {
  local lock_dir="${DEVICE_DIR}.lock"
  local timeout="${GERAETE_SPERRE_WARTESEKUNDEN:-${DEVICE_LOCK_TIMEOUT_SECONDS:-10}}"
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

  local requested_key="${change_prefix%=}"
  local canonical_key="$requested_key"
  if declare -F _helper_inventory_key_canonical >/dev/null; then
    canonical_key="$(_helper_inventory_key_canonical "$requested_key")"
  fi
  local aliases=("$canonical_key")
  if declare -F _helper_inventory_key_aliases >/dev/null; then
    mapfile -t aliases < <(_helper_inventory_key_aliases "$canonical_key")
  fi

  # Refuse to rewrite ambiguous legacy/canonical duplicates. This avoids
  # silently dropping inventory data when both spellings exist in a file.
  local line file_key alias match_count=0
  while IFS= read -r line || [[ -n "$line" ]]; do
    [[ "$line" == *=* ]] || continue
    file_key="${line%%=*}"
    for alias in "${aliases[@]}"; do
      if [[ "${file_key,,}" == "${alias,,}" ]]; then
        match_count=$((match_count + 1))
        break
      fi
    done
  done <"$device_file"
  if (( match_count > 1 )); then
    error_logged "ERROR: conflicting aliases for inventory field '$canonical_key' in '$device_file'; no data was changed"
    _helper_device_lock_release
    return 1
  fi

  tmp="$(mktemp)" || rc=1
  if (( rc == 0 )); then
    log_info "Temporäre Datei erzeugt tmp='$tmp'"

    local aliases_nl
    aliases_nl="$(printf '%s\n' "${aliases[@]}")"
    local new_value="${final_line#*=}"
    awk -v aliases="$aliases_nl" -v canonical="$canonical_key" -v value="$new_value" '
    BEGIN {
      done=0
      count=split(aliases, keys, "\n")
      for (i=1; i<=count; i++) keys[i]=tolower(keys[i])
    }
    {
      separator=index($0, "=")
      key=(separator ? substr($0, 1, separator-1) : "")
      matched=0
      for (i=1; i<=count; i++) {
        if (tolower(key) == keys[i]) { matched=1; break }
      }
      if (matched) {
        if (!done) { print canonical "=" value; done=1 }
        next
      }
      print
    }
    END { if (!done) print canonical "=" value }
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
