param(
  [string]$Version = '1.12.6',
  [int]$UiPort = 8585,
  [int]$IngestionPort = 8084
)

$ErrorActionPreference = 'Stop'
$runtimeDirectory = Join-Path $PSScriptRoot '..\.runtime\openmetadata'
$composeFile = Join-Path $runtimeDirectory 'docker-compose.yml'
$releaseUrl = "https://github.com/open-metadata/OpenMetadata/releases/download/$Version-release/docker-compose-postgres.yml"

New-Item -ItemType Directory -Force -Path $runtimeDirectory | Out-Null
Invoke-WebRequest -UseBasicParsing -Uri $releaseUrl -OutFile $composeFile

$compose = Get-Content -Raw $composeFile
$compose = $compose -replace '"8585:8585"', "`"$UiPort`:8585`""
$compose = $compose -replace '"8080:8080"', "`"$IngestionPort`:8080`""
Set-Content -NoNewline -Path $composeFile -Value $compose

docker compose --project-name open-source-data-platform-openmetadata -f $composeFile up -d
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "OpenMetadata UI: http://localhost:$UiPort"
Write-Host "OpenMetadata ingestion: http://localhost:$IngestionPort"
