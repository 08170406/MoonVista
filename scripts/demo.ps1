$ErrorActionPreference = "Stop"
$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  Write-Output "CSV: filter Japan and sort by score"
  moon run cmd/main -- samples/customers.csv --filter country = Japan --sort score desc
  Write-Output "JSON: export the filtered rows to CSV on standard output"
  moon run cmd/main -- samples/customers.json --filter country = Japan --export csv
  Write-Output "JSONL: summarize scores"
  moon run cmd/main -- samples/customers.jsonl --stats score
} finally {
  Pop-Location
}
