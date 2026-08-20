param(
  [int]$Port = 8001,
  [switch]$InstallAbctl
)

$ErrorActionPreference = 'Stop'
$abctlCommand = Get-Command abctl -ErrorAction SilentlyContinue
if ($abctlCommand) {
  $abctl = $abctlCommand.Source
} elseif (Get-Command go -ErrorAction SilentlyContinue) {
  $abctl = Join-Path (go env GOPATH) 'bin\abctl.exe'
} else {
  $abctl = $null
}

if (-not $abctl -or -not (Test-Path $abctl)) {
  if (-not $InstallAbctl) {
    throw "abctl is not installed. Install Go, then rerun this script with -InstallAbctl."
  }
  if (-not (Get-Command go -ErrorAction SilentlyContinue)) {
    throw 'Go is required to install abctl. Install Go, reopen PowerShell, then rerun this script with -InstallAbctl.'
  }
  go install github.com/airbytehq/abctl@v0.30.4
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  $abctl = Join-Path (go env GOPATH) 'bin\abctl.exe'
}

& $abctl local install --port=$Port --low-resource-mode --no-browser
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

& $abctl local status
