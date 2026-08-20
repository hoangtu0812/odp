[CmdletBinding()]
param(
  [switch]$Initialize,
  [switch]$InstallAirbyte,
  [switch]$SkipAirbyte,
  [switch]$SkipOpenMetadata,
  [switch]$SkipPortal,
  [switch]$NoBuild,
  [switch]$NoWait,
  [switch]$Restart
)

<#
.SYNOPSIS
  Starts the complete Loop Data Lab Local Lab.

.DESCRIPTION
  Coordinates the main Docker Compose stack plus the separately managed
  Airbyte (abctl/Kind) and OpenMetadata Compose runtimes. It preserves all
  named volumes and never modifies .env values.

.EXAMPLE
  .\scripts\start-local-lab.ps1

.EXAMPLE
  .\scripts\start-local-lab.ps1 -Initialize

.EXAMPLE
  .\scripts\start-local-lab.ps1 -InstallAirbyte
#>

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $root '.env'
$composeFile = Join-Path $root 'infra\docker-compose\docker-compose.local.yml'

function Get-EnvValue([string]$Name) {
  $escapedName = [regex]::Escape($Name)
  $line = Get-Content $envFile | Where-Object { $_ -match "^$escapedName=" } | Select-Object -First 1
  if (-not $line) { return $null }
  return $line.Substring($Name.Length + 1).Trim()
}

function Test-ConfiguredValue([string]$Name) {
  $value = Get-EnvValue $Name
  return -not [string]::IsNullOrWhiteSpace($value) -and
    $value -notmatch '^(change-me|replace-me|<.*>)'
}

function Wait-HttpOk([string]$Name, [string]$Uri, [int]$Attempts = 36) {
  foreach ($attempt in 1..$Attempts) {
    try {
      $response = Invoke-WebRequest -UseBasicParsing -Uri $Uri -TimeoutSec 5
      if ($response.StatusCode -lt 400) {
        Write-Host "Ready: $Name ($Uri)" -ForegroundColor Green
        return
      }
    } catch { }
    Start-Sleep -Seconds 3
  }
  throw "Timed out waiting for $Name at $Uri. Inspect: docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml logs --tail=100"
}

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  throw 'Docker Desktop and Docker Compose v2 are required. Install/start Docker Desktop, then retry.'
}

if (-not (Test-Path $envFile)) {
  if (-not $Initialize) {
    throw "Missing $envFile. Run .\scripts\start-local-lab.ps1 -Initialize, edit .env, then rerun the script."
  }
  Copy-Item (Join-Path $root '.env.example') $envFile
  Write-Host 'Created .env from .env.example.' -ForegroundColor Yellow
  throw 'Configure non-placeholder passwords and Azure Entra variables in .env, then rerun this script.'
}

if (-not $SkipPortal) {
  $requiredPortalValues = 'PORTAL_OIDC_CLIENT_SECRET', 'OAUTH2_PROXY_COOKIE_SECRET', 'AZURE_TENANT_ID', 'AZURE_CLIENT_ID', 'AZURE_CLIENT_SECRET'
  $missingPortalValues = @($requiredPortalValues | Where-Object { -not (Test-ConfiguredValue $_) })
  if ($missingPortalValues.Count -gt 0) {
    throw "Portal startup requires configured .env values: $($missingPortalValues -join ', '). Use -SkipPortal to start the remaining Local Lab services without Azure SSO."
  }
}

$composeArgs = @('--env-file', $envFile, '-f', $composeFile)
$profiles = @(
  '--profile', 'analytics',
  '--profile', 'orchestration',
  '--profile', 'observability',
  '--profile', 'lakehouse',
  '--profile', 'governance',
  '--profile', 'ai'
)
if (-not $SkipPortal) { $profiles += @('--profile', 'portal') }

if ($Restart) {
  & docker compose @composeArgs @profiles stop
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

$upArgs = @('up', '-d')
if (-not $NoBuild) { $upArgs += '--build' }
& docker compose @composeArgs @profiles @upArgs
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$airbytePort = Get-EnvValue 'AIRBYTE_PORT'
if (-not $airbytePort) { $airbytePort = '8001' }
if (-not $SkipAirbyte) {
  $airbyteArgs = @{ Port = [int]$airbytePort }
  if ($InstallAirbyte) { $airbyteArgs.InstallAbctl = $true }
  & (Join-Path $PSScriptRoot 'start-airbyte.ps1') @airbyteArgs
}

$openMetadataUiPort = Get-EnvValue 'OPENMETADATA_PORT'
$openMetadataIngestionPort = Get-EnvValue 'OPENMETADATA_INGESTION_PORT'
$openMetadataPostgresPort = Get-EnvValue 'OPENMETADATA_POSTGRES_PORT'
if (-not $openMetadataUiPort) { $openMetadataUiPort = '8585' }
if (-not $openMetadataIngestionPort) { $openMetadataIngestionPort = '8084' }
if (-not $openMetadataPostgresPort) { $openMetadataPostgresPort = '5433' }
if (-not $SkipOpenMetadata) {
  & (Join-Path $PSScriptRoot 'start-openmetadata.ps1') `
    -UiPort ([int]$openMetadataUiPort) `
    -IngestionPort ([int]$openMetadataIngestionPort) `
    -PostgresPort ([int]$openMetadataPostgresPort)
}

if (-not $NoWait) {
  Wait-HttpOk 'Superset' 'http://localhost:8088/health' 60
  Wait-HttpOk 'Airflow' 'http://localhost:8080/api/v2/monitor/health' 60
  Wait-HttpOk 'Grafana' 'http://localhost:3001/api/health'
  Wait-HttpOk 'Prometheus' 'http://localhost:9090/-/ready'
  Wait-HttpOk 'MinIO' 'http://localhost:9000/minio/health/live'
  Wait-HttpOk 'Trino' 'http://localhost:8081/v1/info'
  if (-not $SkipPortal) { Wait-HttpOk 'Loop Data Lab Portal' 'http://localhost:3000/' }
  if (-not $SkipAirbyte) { Wait-HttpOk 'Airbyte' "http://localhost:$airbytePort" 80 }
  if (-not $SkipOpenMetadata) { Wait-HttpOk 'OpenMetadata' "http://localhost:$openMetadataUiPort" 100 }
}

Write-Host ''
Write-Host 'Loop Data Lab Local Lab is running.' -ForegroundColor Green
Write-Host 'Portal:       http://localhost:3000'
Write-Host "Airbyte:      http://localhost:$airbytePort"
Write-Host "OpenMetadata: http://localhost:$openMetadataUiPort"
Write-Host 'Use -SkipAirbyte or -SkipOpenMetadata when Docker resources are limited.'
