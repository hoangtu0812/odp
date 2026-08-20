param(
  [int]$Port = 8001,
  [switch]$InstallAbctl
)

$ErrorActionPreference = 'Stop'
$abctl = Join-Path (go env GOPATH) 'bin\abctl.exe'

if (-not (Test-Path $abctl)) {
  if (-not $InstallAbctl) {
    throw "abctl is not installed. Run: go install github.com/airbytehq/abctl@v0.30.4, or rerun this script with -InstallAbctl."
  }
  go install github.com/airbytehq/abctl@v0.30.4
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

& $abctl local install --port=$Port --low-resource-mode --no-browser
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $abctl local status
