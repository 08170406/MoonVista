$ErrorActionPreference = "Stop"
$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  $longLine = "x" * 5000
  $output = @($longLine, "search Japan", "q") | moon run cmd/main -- samples/customers.csv --repl
  $text = $output -join "`n"
  if ($text -notmatch "moonvista>") {
    throw "REPL smoke check failed: the prompt did not appear."
  }
  if ($text -notmatch "name") {
    throw "REPL smoke check failed: the input table was not rendered."
  }
  if ($text -notmatch "Input line is longer than 4095 bytes") {
    throw "REPL smoke check failed: an overlong line was not rejected."
  }
  if ($text -notmatch "Matched 2 rows") {
    throw "REPL smoke check failed: the search command did not filter the table."
  }
  Write-Output "REPL smoke check passed."
} finally {
  Pop-Location
}
