#!/usr/bin/env bash
set -euo pipefail
# Compatibility source path; new scripts should source geraeteverwaltung_funktionen.sh.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
. "$SCRIPT_DIR/geraeteverwaltung_funktionen.sh"
