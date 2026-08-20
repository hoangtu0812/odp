param(
  [string]$Version = '1.12.6',
  [int]$UiPort = 8585,
  [int]$IngestionPort = 8084,
  [int]$PostgresPort = 5433,
  [switch]$RefreshCompose
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$runtimeDirectory = Join-Path $root '.runtime\openmetadata'
$composeFile = Join-Path $runtimeDirectory 'docker-compose.yml'
$releaseUrl = "https://github.com/open-metadata/OpenMetadata/releases/download/$Version-release/docker-compose-postgres.yml"

New-Item -ItemType Directory -Force -Path $runtimeDirectory | Out-Null
if ($RefreshCompose -or -not (Test-Path $composeFile)) {
  Invoke-WebRequest -UseBasicParsing -Uri $releaseUrl -OutFile $composeFile
  $compose = Get-Content -Raw $composeFile
  $compose = $compose -replace '^version:.*\r?\n', ''
  $compose = $compose -replace '"8585:8585"', "`"$UiPort`:8585`""
  $compose = $compose -replace '"8080:8080"', "`"$IngestionPort`:8080`""
  $compose = $compose -replace '"5432:5432"', "`"$PostgresPort`:5432`""
  Set-Content -NoNewline -Path $composeFile -Value $compose
}

$envFile = Join-Path $root '.env'
if (-not (Test-Path $envFile)) {
  throw "Missing $envFile. Run .\scripts\start-local-lab.ps1 -Initialize, configure .env, then retry."
}
docker compose --env-file $envFile --project-name open-source-data-platform-openmetadata -f $composeFile up -d
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "OpenMetadata UI: http://localhost:$UiPort"
Write-Host "OpenMetadata ingestion: http://localhost:$IngestionPort"
