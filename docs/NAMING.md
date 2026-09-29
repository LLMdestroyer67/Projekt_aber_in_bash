# German naming and compatibility glossary

German identifiers use ASCII transliterations (`ae`, `oe`, `ue`) in code,
environment variables, and CLI commands. Existing English entry points and
inventory keys remain supported.

## Public API

| Canonical | Legacy alias |
|---|---|
| `geraet_anlegen` | `create_device_main` |
| `geraet_anzeigen` | `read_device_main` |
| `geraet_aendern` | `change_device_main` |
| `geraet_suchen` | `find_device_main` |
| `geraet_suchen_und_aendern` | `find_and_change_main` |
| `geraet_suchen_und_aendern_menue` | `find_and_change_menu_main` |
| `bestand_aendern` | `change_count_main` |
| `bestand_fuer_geraet_aendern` | `change_device_count` |
| `befehl_ausfuehren` | `run_cli` |
| `geraetedaten_migrieren` | `migrate_inventory_main` |

## Inventory keys

| Canonical key | Accepted legacy keys |
|---|---|
| `Beschreibung` | `Description`, `description`, `desc` |
| `Standort` | `Location`, `location`, `loc` |
| `Status` | `status` |
| `Kategorie` | `Category`, `category`, `cat` |
| `Anzahl` | `Count`, `count`, `Qty`, `qty`, `Quantity`, `quantity` |
| `Besitzer` | `Owner`, `owner` |
| `Seriennummer` | `Serial`, `serial`, `SerialNumber`, `serialnumber` |
| `SAP-ID` | `SAP_ID`, `sap_id`, `SAPID`, `sapid` |
| `Hersteller` | `Manufacturer`, `manufacturer` |
| `Modell` | `Model`, `model` |
| `Anschaffungsdatum` | `PurchaseDate`, `purchase_date`, `purchasedate` |
| `Ausmusterungsdatum` | `DisposalDate`, `disposal_date`, `disposaldate` |
| `Einkaufswert` | `PurchaseValue`, `purchase_value`, `purchasevalue` |

Search and field selection accept canonical and legacy spellings. Reading or
searching a legacy key does not rewrite the device file. Explicitly changing a
single legacy field rewrites that field under the canonical key. If more than
one alias for a field is present in the same file, a change fails without
modifying the file so that neither value is silently discarded.

## Search modes and CLI commands

Canonical search modes are `geraete_id`, `beschreibung`, `standort`,
`status`, `kategorie`, `besitzer`, `seriennummer`, `sap-id`, `hersteller`,
`modell`, `anschaffungsdatum`, `ausmusterungsdatum`, and `einkaufswert`.
Aliases include `id`, `description`, `location`, and the corresponding English
field names.

| Canonical CLI command | Legacy command |
|---|---|
| `geraet-anlegen` | `create` |
| `geraet-aendern` | `change` |
| `geraet-suchen` | `find` |
| `geraet-anzeigen` | `read` |
| `geraet-suchen-und-aendern` | `find-and-change`, `find_and_change` |
| `bestand-aendern` | `change-count`, `count` |
| `daten-migrieren` | `migrate` |

`geraeteverwaltung.sh` is the canonical interactive and command-line entry
point. `runner.sh` forwards to it for existing callers.
`geraeteverwaltung_funktionen.sh` is the canonical library to source;
`experimental.sh` forwards to it for existing callers.
The module, documentation, and test directories retain their established
paths; moving those implementation paths would break existing source commands
and documentation links without improving runtime compatibility. Existing
module, test, and documentation filenames remain stable; German canonical
names are used for the public API and user-facing commands.

## Configuration

| Canonical environment variable | Legacy environment variable |
|---|---|
| `GERAETE_VERZEICHNIS` | `DEVICE_DIR` |
| `PROTOKOLL_VERZEICHNIS` | `LOG_DIR` |
| `PROTOKOLL_DATEI` | `LOG_FILE` |
| `PROTOKOLL_MAX_GROESSE` | `LOG_MAX_SIZE` |
| `PROTOKOLL_BEWAHRUNGS_TAGE` | `LOG_KEEP_DAYS` |
| `BEFEHLS_TRACE` | `TRACE_COMMANDS` |
| `LAUF_INTERVALL_SEKUNDEN` | `RUN_INTERVAL_SECONDS` |
| `GERAETE_SPERRE_WARTESEKUNDEN` | `DEVICE_LOCK_TIMEOUT_SECONDS` |

When both forms are set before startup, the canonical German variable takes
precedence. Both spellings remain available within the sourced library.

## Explicit data migration

`geraetedaten_migrieren` and the CLI command `daten-migrieren` preview known
legacy field-key conversions by default. Run `geraetedaten_migrieren
--anwenden` or `./geraeteverwaltung.sh daten-migrieren --anwenden` to apply
them. The English option `--apply` is also accepted.

Before applying any changes, migration checks the inventory for conflicting
aliases. A collision aborts the migration without rewriting any file. Applied
files are backed up alongside the original (`.bak.<timestamp>.<pid>`) and replaced
atomically; unknown
fields are retained. Running migration again is safe and reports no changes
when all known keys are already canonical.
