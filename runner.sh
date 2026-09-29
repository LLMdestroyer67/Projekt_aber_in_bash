#!/usr/bin/env bash
# Compatibility entry point; the canonical interactive application is
# geraeteverwaltung.sh.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
exec bash "$SCRIPT_DIR/geraeteverwaltung.sh" "$@"
