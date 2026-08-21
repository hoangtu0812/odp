[CmdletBinding()]
param([int]$Workorders = 10000, [int]$Seed = 42)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if (-not (Get-Command python -ErrorAction SilentlyContinue)) { throw 'Python 3 is required.' }
Push-Location $root
try {
  & python .\examples\maximo\generate_fixture.py --workorders $Workorders --seed $Seed
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  Write-Host 'Fixture generated. Use the in-cluster Airflow Maximo DAG after the Maximo demo assets ConfigMap has been refreshed.' -ForegroundColor Yellow
  Write-Host 'Run .\scripts\k8s-up.ps1 to apply the current assets and install the pinned releases.'
} finally { Pop-Location }
