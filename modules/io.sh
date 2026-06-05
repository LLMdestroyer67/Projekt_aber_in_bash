# IO helpers: logging wrappers, input sanitation and prompt builders
# This module contains read_logged, echo_logged, error_logged and
# helpers for prompting and normalizing user input.

# Ensure logging helpers are available
if [[ -f "$SCRIPT_DIR/modules/logging.sh" ]]; then
  . "$SCRIPT_DIR/modules/logging.sh"
else
  echo "ERROR: modules/logging.sh not found (expected at $SCRIPT_DIR/modules/logging.sh)" >&2
fi

# Echo helpers that route through logging layer
echo_logged() { printf '%s\n' "$*"; }
error_logged() { printf '%s\n' "ERROR: $*" >&2; }

# Read input with optional prompt and strip control chars
read_logged() {
  local prompt="$1" varname="$2"
  if [[ -n "$prompt" ]]; then
    printf '%s' "$prompt"
  fi
  local val
  IFS= read -r val || val=''
  # Strip CR and leading/trailing whitespace
  val="${val//$'\r'/}"; val="${val##+([[:space:]])}"; val="${val%%+([[:space:]])}"
  if [[ -n "$varname" ]]; then
    printf -v "$varname" '%s' "$val"
  else
    printf '%s' "$val"
  fi
}

# Normalize yes/no input
_helper_input_yesno() {
  local v="${1,,}"
  case "$v" in
    y|yes|j|ja|true|1) echo "yes" ;;
    n|no|nein|false|0) echo "no" ;;
    *) return 1 ;;
  esac
}

# Trim helper (portable, uses parameter expansion)
_helper_trim() {
  local s="$1"
  s="${s##+([[:space:]])}"
  s="${s%%+([[:space:]])}"
  printf '%s' "$s"
}

# Prompt builder for fields
_helper_prompt_fields() {
  local which="$1"
  if [[ "$which" == "single" ]]; then
    _helper_fields_build_prompt "${single_fields[@]}"
  else
    _helper_fields_build_prompt "${multi_fields[@]}"
  fi
}

# Normalize mode input into canonical mode
_helper_normalize_mode() {
  local raw="$1"
  _helper_modes_normalize "$raw"
}
