#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/test_helpers.sh"
setup_test_env
export DEVICE_DIR="$TEST_DEVICE_DIR"
export LOG_DIR="$TEST_LOG_DIR"
export LOG_FILE="$LOG_DIR/device_manager.log"
export DEVICE_LOCK_TIMEOUT_SECONDS=0
source "$(dirname "$0")/../geraeteverwaltung_funktionen.sh"

test_section "German API and compatibility aliases"
for function_name in geraet_anlegen geraet_anzeigen geraet_aendern geraet_suchen \
  geraet_suchen_und_aendern geraet_suchen_und_aendern_menue bestand_aendern \
  bestand_fuer_geraet_aendern befehl_ausfuehren \
  geraetedaten_migrieren migrate_inventory_main \
  create_device_main read_device_main change_device_main find_device_main \
  find_and_change_main find_and_change_menu_main change_count_main \
  change_device_count run_cli; do
  declare -F "$function_name" >/dev/null
  assert_rc 0 "$?" "Public function $function_name is available"
done

shim_path="$(cd -- "$(dirname -- "$0")/.." && pwd -P)/geraeteverwaltung_funktionen.sh"
config_path="$(GERAETE_VERZEICHNIS="$TEST_DIR/german-devices" \
  DEVICE_DIR="$TEST_DIR/legacy-devices" \
  bash -c 'source "$1"; printf "%s" "$DEVICE_DIR"' _ "$shim_path")"
assert_equals "$TEST_DIR/german-devices" "$config_path" \
  "Canonical German device-directory configuration takes precedence"

legacy_file="$DEVICE_DIR/LEGACY_WIDGET.txt"
printf 'Description=Old english key\nLocation=Old room\nCategory=Equipment\nStatus=active\n' \
  >"$legacy_file"

search_output="$(befehl_ausfuehren geraet-suchen standort 'Old room')"
assert_true '[[ "$search_output" == *"LEGACY_WIDGET"* ]]' \
  "German CLI search mode reads legacy Location field"

geraet_aendern LEGACY_WIDGET Standort 'New room' >/dev/null
assert_file_contains "$legacy_file" '^Standort=New room$' \
  "Editing a legacy location writes canonical Standort key"
assert_file_not_exists "$DEVICE_DIR/unused.txt" "No unrelated file created"
assert_true '[[ "$(grep -c "^Location=" "$legacy_file" || true)" == 0 ]]' \
  "Legacy Location alias replaced without duplicate"

old_command_output="$(run_cli read LEGACY_WIDGET)"
assert_true '[[ "$old_command_output" == *"Standort=New room"* ]]' \
  "Legacy CLI command and public read alias remain usable"

collision_file="$DEVICE_DIR/COLLISION.txt"
printf 'Location=First\nStandort=Second\n' >"$collision_file"
if geraet_aendern COLLISION Standort 'Unsafe overwrite' >/dev/null 2>&1; then
  collision_rc=0
else
  collision_rc=$?
fi
assert_rc 1 "$collision_rc" "Conflicting canonical and legacy keys reject updates"
assert_file_contains "$collision_file" '^Location=First$' \
  "Collision rejection preserves the legacy value"
assert_file_contains "$collision_file" '^Standort=Second$' \
  "Collision rejection preserves the canonical value"

runner_output="$(GERAETE_VERZEICHNIS="$DEVICE_DIR" \
  PROTOKOLL_VERZEICHNIS="$LOG_DIR" \
  bash "$(dirname "$0")/../geraeteverwaltung.sh" geraet-anzeigen LEGACY_WIDGET)"
assert_true '[[ "$runner_output" == *"Standort=New room"* ]]' \
  "German entry-point script dispatches canonical CLI commands"
legacy_library_output="$(bash -c 'source "$1"; declare -F create_device_main' _ \
  "$(dirname "$0")/../experimental.sh")"
assert_true '[[ "$legacy_library_output" == *"create_device_main"* ]]' \
  "experimental.sh remains a compatible library shim"

migration_dir="$TEST_DIR/migration-devices"
mkdir -p "$migration_dir"
DEVICE_DIR="$migration_dir"
GERAETE_VERZEICHNIS="$migration_dir"
migration_file="$DEVICE_DIR/700002.txt"
printf 'Description=Legacy item\nLocation=Shelf 4\nCustom=keep\n' >"$migration_file"

preview_output="$(geraetedaten_migrieren)"
assert_true '[[ "$preview_output" == *"1 Gerätedatei"* ]]' \
  "Migration defaults to a preview"
assert_file_contains "$migration_file" '^Location=Shelf 4$' \
  "Preview does not modify inventory"
backup_count="$(find "$migration_dir" -maxdepth 1 -name '700002.txt.bak.*' | wc -l)"
assert_equals 0 "$backup_count" "Preview does not create a backup"

geraetedaten_migrieren --anwenden >/dev/null
assert_file_contains "$migration_file" '^Beschreibung=Legacy item$' \
  "Apply converts known English keys"
assert_file_contains "$migration_file" '^Standort=Shelf 4$' \
  "Apply converts Location to Standort"
assert_file_contains "$migration_file" '^Custom=keep$' \
  "Apply preserves unknown fields"
backup_count="$(find "$migration_dir" -maxdepth 1 -name '700002.txt.bak.*' | wc -l)"
assert_equals 1 "$backup_count" "Apply creates a backup before replacement"
backup_file="$(find "$migration_dir" -maxdepth 1 -name '700002.txt.bak.*' -print -quit)"
assert_file_contains "$backup_file" '^Location=Shelf 4$' \
  "Backup retains the pre-migration field names"

if befehl_ausfuehren daten-migrieren >/dev/null; then
  migration_rc=0
else
  migration_rc=$?
fi
assert_rc 0 "$migration_rc" "Repeated preview is idempotent"
if befehl_ausfuehren migrate --apply >/dev/null; then
  migration_rc=0
else
  migration_rc=$?
fi
assert_rc 0 "$migration_rc" "Legacy migration command and option remain available"

collision_file="$DEVICE_DIR/700003.txt"
printf 'Location=Old room\nStandort=New room\n' >"$collision_file"
unmigrated_file="$DEVICE_DIR/700004.txt"
printf 'Description=Must stay unchanged\n' >"$unmigrated_file"
if geraetedaten_migrieren --anwenden >/dev/null 2>&1; then
  migration_rc=0
else
  migration_rc=$?
fi
assert_rc 1 "$migration_rc" "Migration rejects colliding aliases"
assert_file_contains "$collision_file" '^Location=Old room$' \
  "Collision preserves legacy value"
assert_file_contains "$collision_file" '^Standort=New room$' \
  "Collision preserves canonical value"
assert_file_contains "$unmigrated_file" '^Description=Must stay unchanged$' \
  "Global collision preflight prevents partial migration"
backup_count="$(find "$migration_dir" -maxdepth 1 -name '700004.txt.bak.*' | wc -l)"
assert_equals 0 "$backup_count" "Collision preflight creates no partial backup"

cleanup_test_env
test_summary
