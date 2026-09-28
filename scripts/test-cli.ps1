$ErrorActionPreference = "Stop"
$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
try {
  $inputPath = Join-Path $repoRoot "samples/customers.csv"
  $before = (Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash
  $collisionOutput = & moon run cmd/main -- $inputPath --export json --out $inputPath 2>&1
  if ($LASTEXITCODE -eq 0 -or ($collisionOutput -join "`n") -notmatch "refusing to overwrite existing file") {
    throw "CLI smoke check failed: an existing output path was not refused."
  }
  $after = (Get-FileHash -LiteralPath $inputPath -Algorithm SHA256).Hash
  if ($before -ne $after) {
    throw "CLI smoke check failed: the input sample changed."
  }

  $jsonOutput = & moon run cmd/main -- $inputPath --filter country = Japan --sort score desc --export json
  if ($LASTEXITCODE -ne 0) {
    throw "CLI smoke check failed: JSON export command returned an error."
  }
  $rows = ($jsonOutput -join "`n") | ConvertFrom-Json
  if ($rows.Count -ne 2 -or $rows[0].score -ne 96 -or $rows[1].score -ne 91) {
    throw "CLI smoke check failed: filtered and sorted JSON was incorrect."
  }

  $outPath = Join-Path ([System.IO.Path]::GetTempPath()) ("moonvista-export-" + [guid]::NewGuid().ToString("N") + ".json")
  try {
    & moon run cmd/main -- $inputPath --filter country = Japan --export json --out $outPath
    if ($LASTEXITCODE -ne 0) {
      throw "CLI smoke check failed: writing a new export file failed."
    }
    $savedRows = (Get-Content -LiteralPath $outPath -Raw) | ConvertFrom-Json
    if ($savedRows.Count -ne 2) {
      throw "CLI smoke check failed: the saved export was incorrect."
    }
  } finally {
    if (Test-Path -LiteralPath $outPath) {
      Remove-Item -LiteralPath $outPath
    }
  }
  Write-Output "CLI smoke check passed."
} finally {
  Pop-Location
}
