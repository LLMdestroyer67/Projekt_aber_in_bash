#!/usr/bin/env bash
set -euo pipefail

# Simple check: sourcing experimental.sh should define _is_interactive
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"/..  # repo root
cd "$SCRIPT_DIR"

# Source the library
source experimental.sh >/dev/null 2>&1 || { echo "sourcing experimental.sh failed"; exit 1; }

# Verify function exists
if declare -f _is_interactive >/dev/null 2>&1; then
  echo "OK: _is_interactive defined"
  exit 0
else
  echo "FAIL: _is_interactive not defined"
  exit 2
fi
