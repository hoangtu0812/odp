[CmdletBinding()]
param(
  [int]$Workorders = 10000,
  [int]$Seed = 42,
  [switch]$Kubernetes,
  [switch]$SkipAirbyte,
  [switch]$SkipOpenMetadata
)

<#
.SYNOPSIS
  Run the deterministic LDL Maximo end-to-end demonstration.

.DESCRIPTION
  The local fixture uses the same Maximo normalizer and database upsert as the
  live connector. It is marked as fixture mode in ingestion audit records;
  production Maximo ingestion still requires a validated HTTPS configuration.
#>

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if ($Kubernetes) {
  & (Join-Path $PSScriptRoot 'k8s-demo.ps1') -Workorders $Workorders -Seed $Seed
  exit $LASTEXITCODE
}
if (-not (Get-Command python -ErrorAction SilentlyContinue)) { throw 'Python 3 is required to generate the Maximo fixture.' }
if (-not (Test-Path (Join-Path $root '.env'))) { throw 'Missing .env. Copy .env.example and configure local passwords first.' }

Push-Location $root
try {
  & python .\examples\maximo\generate_fixture.py --workorders $Workorders --seed $Seed
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  $env:MAXIMO_FIXTURE_PATH = '/opt/ingestion/maximo-demo/generated/workorders.json'

  $startArgs = @{ SkipPortal = $true }
  if ($SkipAirbyte) { $startArgs.SkipAirbyte = $true }
  if ($SkipOpenMetadata) { $startArgs.SkipOpenMetadata = $true }
  & (Join-Path $PSScriptRoot 'start-local-lab.ps1') @startArgs
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

  function Get-EnvValue([string]$Name) {
    $line = Get-Content .env | Where-Object { $_ -match "^$([regex]::Escape($Name))=" } | Select-Object -First 1
    if (-not $line) { throw "Missing $Name in .env" }
    return $line.Substring($Name.Length + 1).Trim()
  }
  $username = Get-EnvValue 'AIRFLOW_ADMIN_USERNAME'
  $password = Get-EnvValue 'AIRFLOW_ADMIN_PASSWORD'
  $authorization = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("${username}:${password}"))
  $headers = @{ Authorization = "Basic $authorization" }
  $run = Invoke-RestMethod -Uri 'http://localhost:8080/api/v2/dags/maximo_dbt_pipeline/dagRuns' -Method Post -Headers $headers -ContentType 'application/json' -Body '{}'
  $runId = $run.dag_run_id
  Write-Host "Triggered Maximo pipeline run $runId" -ForegroundColor Cyan

  foreach ($attempt in 1..180) {
    Start-Sleep -Seconds 5
    $state = (Invoke-RestMethod -Uri "http://localhost:8080/api/v2/dags/maximo_dbt_pipeline/dagRuns/$runId" -Headers $headers).state
    Write-Host "Pipeline state: $state"
    if ($state -eq 'success') { break }
    if ($state -in @('failed', 'failed', 'upstream_failed')) { throw "Maximo pipeline finished with $state" }
    if ($attempt -eq 180) { throw 'Timed out waiting for Maximo pipeline.' }
  }
  Write-Host 'LDL Maximo demo completed successfully.' -ForegroundColor Green
  Write-Host 'Airflow:  http://localhost:8080/dags/maximo_dbt_pipeline/grid'
  Write-Host 'Superset: http://localhost:8088'
  Write-Host 'Trino:    http://localhost:8081'
} finally {
  Pop-Location
}
