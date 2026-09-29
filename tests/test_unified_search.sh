#!/usr/bin/env bash
set -euo pipefail

source "$(dirname "$0")/test_helpers.sh"
source "$(dirname "$0")/../geraeteverwaltung_funktionen.sh"

setup_test_env
export DEVICE_DIR="$TEST_DEVICE_DIR"
export GERAETE_VERZEICHNIS="$DEVICE_DIR"
export LOG_DIR="$TEST_LOG_DIR"
export LOG_FILE="$LOG_DIR/device_manager.log"
export DEVICE_LOCK_TIMEOUT_SECONDS=0
_helper_core_is_interactive() { return 0; }

printf 'Beschreibung=Server Alpha\nStandort=Lab\nStatus=active\n' \
  >"$DEVICE_DIR/800001.txt"
printf 'Beschreibung=Server Beta\nStandort=Lab\nStatus=retired\n' \
  >"$DEVICE_DIR/800002.txt"
printf 'Beschreibung=Server Gamma\nStandort=Storage\nStatus=active\n' \
  >"$DEVICE_DIR/800003.txt"
printf 'Beschreibung=LAN cable\nStandort=Lab\nAnzahl=5\n' \
  >"$DEVICE_DIR/LAN_TEST.txt"

test_section "Refine only the current result set"
printf 'standort\nLab\nstatus\nactive\nn\n' >"$TEST_DIR/input"
geraet_suchen <"$TEST_DIR/input" >"$TEST_DIR/output" 2>&1
assert_equals 1 "$FOUND_MATCH_COUNT" "Refinement leaves one matching device"
assert_equals "$DEVICE_DIR/800001.txt" "${FOUND_MATCHES[0]}" \
  "Refinement is restricted to the previous result set"
assert_equals 800001 "$FOUND_DEVICE_ID" "Unique result ID is retained"
assert_true 'grep -q "Keine Änderung vorgenommen" "$TEST_DIR/output"' \
  "User can decline the optional change"

test_section "Leave the current multiple-match list without editing"
printf 'standort\nLab\nq\n' >"$TEST_DIR/input"
_helper_find_interactive_workflow <"$TEST_DIR/input" >"$TEST_DIR/output" 2>&1
assert_equals 3 "$FOUND_MATCH_COUNT" "Quit keeps the current matching list available"
assert_equals "" "$FOUND_DEVICE_ID" "Multiple matches do not imply a device selection"

test_section "Partial ID searches can be refined"
printf 'geraete_id\n80000\nstandort\nStorage\nn\n' >"$TEST_DIR/input"
_helper_find_interactive_workflow <"$TEST_DIR/input" >"$TEST_DIR/output" 2>&1
assert_equals 800003 "$FOUND_DEVICE_ID" \
  "Partial ID matches are narrowed within their candidate set"

test_section "Non-interactive calls remain search-only"
_helper_core_is_interactive() { return 1; }
geraet_suchen standort Lab >"$TEST_DIR/output" 2>&1
search_output="$(cat "$TEST_DIR/output")"
assert_equals 3 "$FOUND_MATCH_COUNT" "Scripted search returns its matches"
assert_true '! grep -q "Möchten Sie Gerät" <<<"$search_output"' \
  "Scripted search does not prompt for an edit"
geraet_suchen_und_aendern geraete_id 800002 Status archived \
  >"$TEST_DIR/output" 2>&1
assert_file_contains "$DEVICE_DIR/800002.txt" '^Status=archived$' \
  "Legacy four-argument search/change API still updates a unique result"
_helper_core_is_interactive() { return 0; }

test_section "Retry after an empty refinement"
printf 'standort\nLab\nstatus\nmissing\nbeschreibung\nServer Beta\nn\n' \
  >"$TEST_DIR/input"
_helper_find_interactive_workflow <"$TEST_DIR/input" >"$TEST_DIR/output" 2>&1
assert_equals 1 "$FOUND_MATCH_COUNT" "Retry can select from the retained candidates"
assert_equals "$DEVICE_DIR/800002.txt" "${FOUND_MATCHES[0]}" \
  "No-result refinement does not replace the candidate list"
assert_true 'grep -q "Kein Gerät passt innerhalb" "$TEST_DIR/output"' \
  "Empty refinement explains why another criterion is requested"

test_section "Accept change from the unified search"
printf 'standort\nLab\nbeschreibung\nServer Alpha\nj\nStatus\nmaintenance\n' \
  >"$TEST_DIR/input"
_helper_find_interactive_workflow <"$TEST_DIR/input" >"$TEST_DIR/output" 2>&1
assert_file_contains "$DEVICE_DIR/800001.txt" '^Status=maintenance$' \
  "Accepting change reuses the existing field editor"

test_section "Collection change choice"
printf 'standort\nLab\nbeschreibung\nLAN cable\nj\n2\n1\n' >"$TEST_DIR/input"
_helper_find_interactive_workflow <"$TEST_DIR/input" >"$TEST_DIR/output" 2>&1
assert_file_contains "$DEVICE_DIR/LAN_TEST.txt" '^Anzahl=6$' \
  "Unified flow reuses the collection count editor"

test_section "Legacy search-change names use the unified flow"
printf 'geraete_id\n800003\nn\n' >"$TEST_DIR/input"
geraet_suchen_und_aendern <"$TEST_DIR/input" >"$TEST_DIR/output" 2>&1
assert_equals 800003 "$FOUND_DEVICE_ID" \
  "Legacy search/change function uses the unified interaction"
printf 'beschreibung\nLAN cable\nn\n' >"$TEST_DIR/input"
geraet_suchen_und_aendern_menue <"$TEST_DIR/input" >"$TEST_DIR/output" 2>&1
assert_equals LAN_TEST "$FOUND_DEVICE_ID" \
  "Legacy search/change menu function uses the unified interaction"
printf 'beschreibung\nLAN cable\nn\n' >"$TEST_DIR/input"
bestand_aendern <"$TEST_DIR/input" >"$TEST_DIR/output" 2>&1
assert_file_contains "$DEVICE_DIR/LAN_TEST.txt" '^Anzahl=6$' \
  "Declining the unified search change does not fall through to a count edit"

cleanup_test_env
test_summary
