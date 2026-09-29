# Field and mode definitions + parsing helpers
# This module defines single_fields, multi_fields, find_modes and
# parsing helpers used across the codebase.

# Fields for single devices (Einzelgerät)
single_fields=(
  "1|beschreibung|desc|description:Beschreibung="
  "2|standort|location|loc:Standort="
  "3|status:Status="
  "4|kategorie|category|cat:Kategorie="
  "5|besitzer|owner:Besitzer="
  "6|seriennummer|serial|serialnumber:Seriennummer="
  "7|sap-id|sap_id|sapid:SAP-ID="
  "8|hersteller|manufacturer:Hersteller="
  "9|modell|model:Modell="
  "10|anschaffungsdatum|purchase_date|purchasedate:Anschaffungsdatum="
  "11|ausmusterungsdatum|disposal_date|disposaldate:Ausmusterungsdatum="
  "12|einkaufswert|purchase_value|purchasevalue:Einkaufswert="
)

# Fields for multi/collection devices (Sammeleintrag)
multi_fields=(
  "1|beschreibung|desc|description:Beschreibung="
  "2|anzahl|count|qty|quantity:Anzahl="
  "3|standort|location|loc:Standort="
  "4|kategorie|category|cat:Kategorie="
)

# Canonical German search modes. The previous English names remain accepted
# as aliases so existing scripts do not need to change immediately.
find_modes=(
  "1|geraete_id|id:geraete_id:"
  "2|beschreibung|description|desc:beschreibung:Beschreibung="
  "3|standort|location|loc:standort:Standort="
  "4|status:status:Status="
  "5|kategorie|category|cat:kategorie:Kategorie="
  "6|besitzer|owner:besitzer:Besitzer="
  "7|seriennummer|serial|serialnumber:seriennummer:Seriennummer="
  "8|sap-id|sap_id|sapid:sap-id:SAP-ID="
  "9|hersteller|manufacturer:hersteller:Hersteller="
  "10|modell|model:modell:Modell="
  "11|anschaffungsdatum|purchase_date|purchasedate:anschaffungsdatum:Anschaffungsdatum="
  "12|ausmusterungsdatum|disposal_date|disposaldate:ausmusterungsdatum:Ausmusterungsdatum="
  "13|einkaufswert|purchase_value|purchasevalue:einkaufswert:Einkaufswert="
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
      if [[ "${input,,}" == "${pat,,}" ]]; then
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
    printf 'Gerät suchen nach %s: ' "${prompt_parts[*]}"
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
  local canonical="$(_helper_modes_normalize "$1")" || return 1
  for m in "${find_modes[@]}"; do
    local c="$(_generic_parse_field "$m" canonical)"
    if [[ "${c,,}" == "${canonical,,}" ]]; then
      _generic_parse_field "$m" filekey
      return 0
    fi
  done
  return 1
}

# Resolve an old or canonical inventory key to its canonical German spelling.
_helper_inventory_key_canonical() {
  local key="${1%=}"
  case "${key,,}" in
    beschreibung|description|desc) printf '%s' 'Beschreibung' ;;
    standort|location|loc) printf '%s' 'Standort' ;;
    status) printf '%s' 'Status' ;;
    kategorie|category|cat) printf '%s' 'Kategorie' ;;
    anzahl|count|qty|quantity) printf '%s' 'Anzahl' ;;
    besitzer|owner) printf '%s' 'Besitzer' ;;
    seriennummer|serial|serialnumber) printf '%s' 'Seriennummer' ;;
    sap-id|sap_id|sapid) printf '%s' 'SAP-ID' ;;
    hersteller|manufacturer) printf '%s' 'Hersteller' ;;
    modell|model) printf '%s' 'Modell' ;;
    anschaffungsdatum|purchase_date|purchasedate) printf '%s' 'Anschaffungsdatum' ;;
    ausmusterungsdatum|disposal_date|disposaldate) printf '%s' 'Ausmusterungsdatum' ;;
    einkaufswert|purchase_value|purchasevalue) printf '%s' 'Einkaufswert' ;;
    *) printf '%s' "$key" ;;
  esac
}

# Print the known aliases for a canonical or legacy inventory key.
_helper_inventory_key_aliases() {
  case "$(_helper_inventory_key_canonical "$1")" in
    Beschreibung) printf '%s\n' Beschreibung Description description desc ;;
    Standort) printf '%s\n' Standort Location location loc ;;
    Status) printf '%s\n' Status status ;;
    Kategorie) printf '%s\n' Kategorie Category category cat ;;
    Anzahl) printf '%s\n' Anzahl Count count Qty qty Quantity quantity ;;
    Besitzer) printf '%s\n' Besitzer Owner owner ;;
    Seriennummer) printf '%s\n' Seriennummer Serial serial SerialNumber serialnumber ;;
    SAP-ID) printf '%s\n' SAP-ID SAP_ID sap_id SAPID sapid ;;
    Hersteller) printf '%s\n' Hersteller Manufacturer manufacturer ;;
    Modell) printf '%s\n' Modell Model model ;;
    Anschaffungsdatum) printf '%s\n' Anschaffungsdatum PurchaseDate purchase_date purchasedate ;;
    Ausmusterungsdatum) printf '%s\n' Ausmusterungsdatum DisposalDate disposal_date disposaldate ;;
    Einkaufswert) printf '%s\n' Einkaufswert PurchaseValue purchase_value purchasevalue ;;
    *) printf '%s\n' "$1" ;;
  esac
}

# Resolve a change field using the field definitions for the device type.
_helper_change_field_to_prefix_single() {
  _helper_fields_match_to_prefix "${1,,}" "${single_fields[@]}"
}

_helper_change_field_to_prefix_multi() {
  _helper_fields_match_to_prefix "${1,,}" "${multi_fields[@]}"
}

_field_to_prefix() {
  local device_count="$1" field="$2"
  if [[ "$device_count" -eq 1 ]]; then
    _helper_change_field_to_prefix_single "$field"
  elif [[ "$device_count" -eq 2 ]]; then
    _helper_change_field_to_prefix_multi "$field"
  else
    return 1
  fi
}

_helper_change_prompt_field_single() {
  local choice=""
  read_logged "was wird geändert? ($(_helper_fields_build_prompt "${single_fields[@]}")): " choice || return $?
  printf '%s' "$choice"
}

_helper_change_prompt_field_multi() {
  local choice=""
  read_logged "was wird geändert? ($(_helper_fields_build_prompt "${multi_fields[@]}")): " choice || return $?
  printf '%s' "$choice"
}

_prompt_field() {
  local device_count="$1"
  if [[ "$device_count" -eq 1 ]]; then
    _helper_change_prompt_field_single
  else
    _helper_change_prompt_field_multi
  fi
}

_helper_change_resolve_field() {
  local field="$1" device_count="$2"
  if [[ -z "$field" ]]; then
    if _helper_core_is_interactive; then
      field="$(_prompt_field "$device_count")" || return $?
    else
      error_logged "ERROR (change_device_main): missing FIELD argument"
      return "$EXIT_USAGE_ERROR"
    fi
  fi
  printf '%s' "$field"
}
