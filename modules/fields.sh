# Field and mode definitions + parsing helpers
# This module defines single_fields, multi_fields, find_modes and
# parsing helpers used across the codebase.

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

# -----------------------------------------------------------------------------
# Generic parsing helpers
# -----------------------------------------------------------------------------

_generic_parse_field() {
  local field="$1" component="$2"
  local patterns="${field%%:*}"
  local rest="${field#*:}"

  case "$component" in
    patterns) printf '%s' "$patterns" ;;
    prefix)   printf '%s' "$rest" ;;  # For single/multi fields
    canonical) printf '%s' "${rest%%:*}" ;;  # For find modes
    filekey)   printf '%s' "${rest#*:}" ;;   # For find modes
  esac
}

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

# -----------------------------------------------------------------------------
# Field/mode builders
# -----------------------------------------------------------------------------

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

_helper_fields_match_to_prefix() {
  local input="$1"
  shift
  _generic_find_in_fields "$input" "prefix" "$@"
}

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

_helper_modes_normalize() {
  local input="${1,,}"
  _generic_find_in_fields "$input" "canonical" "${find_modes[@]}"
}

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
