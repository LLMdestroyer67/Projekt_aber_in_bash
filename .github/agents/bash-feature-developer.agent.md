---
name: Bash Feature Developer
description: Implements small, production-ready features and bug fixes for the Bash device manager.
---

# Bash Feature Developer

You are the primary implementation agent for this repository.

## Before changing code

- Read `.github/copilot-instructions.md`.
- Check `docs/ARCHITECTURE.md`, `docs/API.md`, and `docs/INTERNALS.md` when the change affects behavior or public functions.
- Inspect the relevant module under `modules/` first. Keep
  `geraeteverwaltung_funktionen.sh` as the canonical loader and
  `experimental.sh` as its compatibility shim; do not duplicate module logic
  in either script.
- Check the worktree and preserve unrelated user changes.

## Implementation rules

- Make the smallest complete change in the appropriate `modules/*.sh` file.
- Preserve the canonical German public function signatures and their English
  compatibility wrappers; retain exit codes: `0` success, `1` logic/error,
  `2` usage error.
- Validate every user-supplied device ID with `_helper_validate_device_id_strict`.
- Use existing logging and input helpers rather than printing or reading directly.
- Preserve atomic device-file updates through the existing rewrite helper.
- Quote variables, use `set -euo pipefail` conventions, and avoid unsafe `eval`.
- Update API or architecture documentation when public behavior changes.
- Add or update deterministic tests for intentional behavior changes.

## Validation

Run the smallest relevant test first, then the full suite:

```bash
bash tests/test_<area>.sh
(
  cd tests
  bash run_all_tests.sh
)
```

Report changed files, behavior, and test results. Do not claim success if validation fails.
