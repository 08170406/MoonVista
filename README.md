# MoonVista

MoonVista is a small MoonBit terminal workbench for inspecting CSV, JSON object arrays, and JSON Lines files. Its table and transformation packages are deterministic MoonBit code; filesystem and terminal input stay at the command boundary.

## What it does

- Loads CSV with quoted fields, doubled quotes, embedded newlines, UTF-8 BOM, and CRLF. Short rows are padded with nulls; rows with extra cells are rejected with a row number.
- Loads JSON arrays of objects and JSONL objects. The union of object keys becomes the columns in deterministic order; missing keys become nulls.
- Infers integer, decimal, boolean, date, and text columns and keeps null counts and inference confidence.
- Creates immutable views for stable multi-column sorting, typed filters, row search, column projection/hiding, and statistics.
- Renders fixed-size screen snapshots, selected-row ANSI output, and a line-oriented REPL backed by a pure keyboard state machine.
- Exports the current view as CSV or JSON without changing the source file.

## Prerequisites

- Install MoonBit CLI 0.1.20260915 or newer using the [official installation guide](https://www.moonbitlang.com/download), then confirm it is available with `moon version`.
- Native builds need a C toolchain. On Windows, install MSVC Build Tools with the C++ tools and Windows SDK; on Linux and macOS, use GCC, Clang, or another supported C compiler.
- The repository pins `moonbitlang/x` 0.5.5 in `moon.mod`. The first build resolves this dependency.

## Run

Use the native target for the terminal application:

```powershell
moon run cmd/main -- --help
moon run cmd/main -- samples/customers.csv
moon run cmd/main -- samples/customers.csv --filter country = Japan --sort score desc
moon run cmd/main -- samples/customers.csv --stats score
moon run cmd/main -- samples/customers.csv --export json --out filtered.json
moon run cmd/main -- samples/customers.csv --repl
```

Run the reproducible demo from the repository root:

```powershell
pwsh -NoProfile -File scripts/demo.ps1
```

In REPL mode, enter `help` for commands. For example, `search Japan`, `down`, `sort`, `clear`, and `q`.

## CLI reference

- `--sort <column> <asc|desc>` may be repeated; sort keys retain the supplied order.
- `--filter <column> <op> <value>` may be repeated. Operators are `=`, `!=`, `contains`, `>`, `>=`, `<`, and `<=`.
- Null checks use `--filter <column> is-null` and `--filter <column> is-not-null` without a value.
- `--stats <column>` may be repeated and reports statistics for the filtered view.
- `--export csv|json` writes an export to standard output. Add `--out <path>` to write it to a new file; existing destinations are refused so an export cannot replace its input.
- `--repl` starts a line-oriented terminal workbench. It cannot be combined with export or statistics flags.

The CLI recognizes input formats by `.csv`, `.json`, and `.jsonl` suffix. This is a native-target CLI because its REPL reads terminal input. The data, loader, operation, rendering, and app-state packages remain MoonBit packages.

## Limits and non-goals

MoonVista loads each input file fully into memory. It does not stream large files, edit input data, or provide SQL, a database, charts, or spreadsheet formulas. The REPL accepts one command per line instead of capturing raw keys; input lines are limited to 4095 bytes, and longer lines are discarded as one command. The default non-interactive table snapshot uses a fixed 120-column by 30-row frame, and the REPL uses a 100-column by 16-row frame.

## Development

```powershell
moon fmt
moon test
moon check --target native
moon build --target native
pwsh -NoProfile -File scripts/test-cli.ps1
pwsh -NoProfile -File scripts/test-repl.ps1
```

The MoonBit suite currently contains 50 tests. The CLI and REPL smoke scripts exercise file export safety, output parsing, interactive commands, and overlong-line handling.

The library is split into `table`, `loaders`, `ops`, `render`, `app`, and `cli` packages. CLI file I/O is isolated in `cli`; native terminal input and exclusive file creation live in the small `terminal` adapter.

## Sources and license

MoonVista is released under [Apache-2.0](LICENSE). The project uses the MoonBit standard library and `moonbitlang/x` 0.5.5 for filesystem and UTF-8 boundary helpers. The table logic, loaders, filters, renderers, and sample records are maintained in this repository; no global phone-number or other third-party metadata dataset is bundled.
