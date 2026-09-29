# CLI dispatcher: minimal non-interactive command routing
# Provides a simple run_cli "$@" entry that maps top-level commands to *_main functions

# Dependencies: logging, io
if [[ -f "$SCRIPT_DIR/modules/logging.sh" ]]; then
  . "$SCRIPT_DIR/modules/logging.sh"
fi
if [[ -f "$SCRIPT_DIR/modules/io.sh" ]]; then
  . "$SCRIPT_DIR/modules/io.sh"
fi

# Canonical CLI dispatcher. English command spellings remain aliases.
# Usage: befehl_ausfuehren <befehl> [argumente...]
befehl_ausfuehren() {
  local cmd="${1-}"
  shift || true
  case "$cmd" in
    geraet-anlegen|geraet_anlegen|anlegen|create)
      geraet_anlegen "$@" ;;
    geraet-aendern|geraet_aendern|aendern|change)
      geraet_aendern "$@" ;;
    geraet-suchen|geraet_suchen|suchen|find)
      geraet_suchen "$@" ;;
    geraet-anzeigen|geraet_anzeigen|anzeigen|read)
      geraet_anzeigen "$@" ;;
    geraet-suchen-und-aendern|geraet_suchen_und_aendern|suchen-und-aendern|find-and-change|find_and_change)
      geraet_suchen_und_aendern "$@" ;;
    bestand-aendern|bestand_aendern|change-count|count)
      bestand_aendern "$@" ;;
    daten-migrieren|daten_migrieren|migrate)
      geraetedaten_migrieren "$@" ;;
    '')
      echo "Kein Befehl angegeben. Verfügbar: geraet-anlegen, geraet-aendern, geraet-suchen, geraet-anzeigen, bestand-aendern, daten-migrieren" >&2
      return 2 ;;
    *)
      echo "Unbekannter Befehl: $cmd" >&2
      return 2 ;;
  esac
}

run_cli() { befehl_ausfuehren "$@"; }
