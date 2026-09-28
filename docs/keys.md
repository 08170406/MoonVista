# REPL key and command reference

MoonVista provides a line-oriented REPL so it works in terminals without raw-key capture. Start it with:

```powershell
moon run cmd/main -- samples/customers.csv --repl
```

Enter one command per line. The short key forms are accepted as commands too.

| Command | Short form | Action |
| --- | --- | --- |
| `up` | `k` | Move up one row |
| `down` | `j` | Move down one row |
| `left` | `h` | Move to the previous column |
| `right` | `l` | Move to the next column |
| `page-up` |  | Move up one page |
| `page-down` |  | Move down one page |
| `home` |  | Select the first row |
| `end` |  | Select the last row |
| `search <text>` |  | Search visible cells and keep matching rows |
| `filter <value>` |  | Keep rows whose selected column equals the value |
| `sort` | `s` | Toggle sort direction for the selected column |
| `clear` | `c` | Restore the original view |
| `help` | `?` | Show the built-in help table |
| `quit` | `q` | Exit |

Search and filter results are views over the loaded table. `clear` restores the starting view, including any `--filter` and `--sort` supplied before entering the REPL.
