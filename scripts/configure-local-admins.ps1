[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [ValidateNotNullOrEmpty()]
  [string]$Password,
  [string]$Username = 'tuph',
  [string]$Email = 'tuph@bsr.com.vn',
  [string]$OpenMetadataBootstrapEmail = 'admin@open-metadata.org',
  [string]$OpenMetadataBootstrapPassword = 'admin',
  [switch]$Restart
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $root '.env'

if (-not (Test-Path $envFile)) {
  throw "Missing $envFile. Copy .env.example first."
}

function New-RandomHex([int]$ByteCount = 32) {
  $bytes = [byte[]]::new($ByteCount)
  [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
  return [Convert]::ToHexString($bytes).ToLowerInvariant()
}

function New-FernetKey {
  $bytes = [byte[]]::new(32)
  [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
  return [Convert]::ToBase64String($bytes).Replace('+', '-').Replace('/', '_')
}

function New-UrlSafeSecret([int]$ByteCount = 32) {
  $bytes = [byte[]]::new($ByteCount)
  [System.Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
  return [Convert]::ToBase64String($bytes).Replace('+', '-').Replace('/', '_').TrimEnd('=')
}

function Set-EnvValue([string]$Name, [string]$Value) {
  $escapedName = [regex]::Escape($Name)
  $script:envLines = @($script:envLines | ForEach-Object {
    if ($_ -match "^$escapedName=") { "$Name=$Value" } else { $_ }
  })
  if (-not ($script:envLines | Where-Object { $_ -match "^$escapedName=" })) {
    $script:envLines += "$Name=$Value"
  }
}

$envLines = @(Get-Content $envFile)
function Get-EnvValue([string]$Name) {
  $escapedName = [regex]::Escape($Name)
  $line = $envLines | Where-Object { $_ -match "^$escapedName=" } | Select-Object -First 1
  if (-not $line) { return $null }
  return $line.Substring($Name.Length + 1)
}

$previousGrafanaUser = Get-EnvValue 'GRAFANA_ADMIN_USER'
$previousGrafanaPassword = Get-EnvValue 'GRAFANA_ADMIN_PASSWORD'
$previousKeycloakUser = Get-EnvValue 'KEYCLOAK_ADMIN_USER'
$previousKeycloakPassword = Get-EnvValue 'KEYCLOAK_ADMIN_PASSWORD'
$values = [ordered]@{
  SUPERSET_ADMIN_USERNAME       = $Username
  SUPERSET_ADMIN_EMAIL          = $Email
  SUPERSET_ADMIN_PASSWORD       = $Password
  SUPERSET_SECRET_KEY           = New-RandomHex
  GRAFANA_ADMIN_USER            = $Username
  GRAFANA_ADMIN_PASSWORD        = $Password
  MINIO_ROOT_USER               = $Username
  MINIO_ROOT_PASSWORD           = $Password
  KEYCLOAK_ADMIN_USER           = $Username
  KEYCLOAK_ADMIN_PASSWORD       = $Password
  AIRFLOW_ADMIN_USERNAME        = $Username
  AIRFLOW_ADMIN_PASSWORD        = $Password
  AIRFLOW_FERNET_KEY            = New-FernetKey
  AIRFLOW_API_SECRET_KEY        = New-RandomHex
  AIRFLOW_JWT_SECRET            = New-RandomHex
  PORTAL_OIDC_CLIENT_SECRET     = New-RandomHex
  OAUTH2_PROXY_COOKIE_SECRET    = New-UrlSafeSecret
  AUTHORIZER_ADMIN_PRINCIPALS   = "[$Username]"
  AUTHORIZER_PRINCIPAL_DOMAIN   = 'bsr.com.vn'
}

foreach ($entry in $values.GetEnumerator()) {
  Set-EnvValue -Name $entry.Key -Value $entry.Value
}

Set-Content -Path $envFile -Value $envLines

if (-not $Restart) {
  Write-Output 'Updated local administrator settings and generated fresh Airflow/Superset secrets.'
  Write-Output 'Run this script with -Restart to synchronize existing accounts and restart services.'
  exit 0
}

$composeFile = Join-Path $root 'infra/docker-compose/docker-compose.local.yml'
$composeArgs = @('--env-file', $envFile, '-f', $composeFile)

function Wait-HttpOk([string]$Uri, [int]$Attempts = 30) {
  foreach ($attempt in 1..$Attempts) {
    try {
      if ((Invoke-WebRequest -UseBasicParsing -Uri $Uri -TimeoutSec 5).StatusCode -lt 400) { return }
    } catch { }
    Start-Sleep -Seconds 2
  }
  throw "Service did not become ready: $Uri"
}

# Persistent Keycloak data does not reapply bootstrap credentials. Change the
# existing master-realm account before restarting its Entra configuration job.
if ($previousKeycloakUser -and $previousKeycloakPassword) {
  $keycloakCommand = @'
set -eu
KCADM=/opt/keycloak/bin/kcadm.sh
$KCADM config credentials --server http://localhost:8080 --realm master --user "$OLD_ADMIN_USER" --password "$OLD_ADMIN_PASSWORD" >/dev/null
user_id="$($KCADM get users -r master -q username="$OLD_ADMIN_USER" -q exact=true | sed -n 's/.*"id" : "\([^"]*\)".*/\1/p' | head -1)"
test -n "$user_id"
$KCADM update "users/$user_id" -r master -s username="$NEW_ADMIN_USER" -s email="$NEW_ADMIN_EMAIL" -s emailVerified=true
$KCADM set-password -r master --username "$NEW_ADMIN_USER" --new-password "$NEW_ADMIN_PASSWORD"
'@
  & docker compose @composeArgs exec -T `
    -e "OLD_ADMIN_USER=$previousKeycloakUser" `
    -e "OLD_ADMIN_PASSWORD=$previousKeycloakPassword" `
    -e "NEW_ADMIN_USER=$Username" `
    -e "NEW_ADMIN_EMAIL=$Email" `
    -e "NEW_ADMIN_PASSWORD=$Password" `
    keycloak sh -lc $keycloakCommand
  if ($LASTEXITCODE -ne 0) { throw 'Unable to synchronize the existing Keycloak administrator.' }
}

# Grafana stores its first administrator in its volume, so update that record
# through Grafana's admin API before the Compose restart.
if ($previousGrafanaUser -and $previousGrafanaPassword) {
  $grafanaLogin = @{ user = $previousGrafanaUser; password = $previousGrafanaPassword } | ConvertTo-Json -Compress
  Invoke-WebRequest -UseBasicParsing -Method Post -Uri 'http://localhost:3001/login' -ContentType 'application/json' -Body $grafanaLogin -SessionVariable grafanaSession | Out-Null
  $currentUser = Invoke-RestMethod -UseBasicParsing -WebSession $grafanaSession -Uri 'http://localhost:3001/api/user'
  Invoke-RestMethod -UseBasicParsing -Method Put -WebSession $grafanaSession -Uri "http://localhost:3001/api/admin/users/$($currentUser.id)/password" -ContentType 'application/json' -Body (@{ password = $Password } | ConvertTo-Json -Compress) | Out-Null
  Invoke-RestMethod -UseBasicParsing -Method Put -WebSession $grafanaSession -Uri "http://localhost:3001/api/users/$($currentUser.id)" -ContentType 'application/json' -Body (@{ login = $Username; email = $Email; name = $Username } | ConvertTo-Json -Compress) | Out-Null
}

# Create or update a real OpenMetadata administrator, then set the requested
# password through its supported API. The original bootstrap identity is kept
# for audit continuity rather than deleting an account unexpectedly.
$bootstrapPassword = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($OpenMetadataBootstrapPassword))
$loginBody = @{ email = $OpenMetadataBootstrapEmail; password = $bootstrapPassword } | ConvertTo-Json -Compress
$login = Invoke-RestMethod -UseBasicParsing -Method Post -Uri 'http://localhost:8585/api/v1/users/login' -ContentType 'application/json' -Body $loginBody
$headers = @{ Authorization = "Bearer $($login.accessToken)" }
$userBody = @{ name = $Username; displayName = $Username; email = $Email; isAdmin = $true } | ConvertTo-Json -Compress
Invoke-RestMethod -UseBasicParsing -Method Put -Uri 'http://localhost:8585/api/v1/users' -Headers $headers -ContentType 'application/json' -Body $userBody | Out-Null
$passwordBody = @{ username = $Username; newPassword = $Password; confirmPassword = $Password; requestType = 'USER' } | ConvertTo-Json -Compress
Invoke-RestMethod -UseBasicParsing -Method Put -Uri 'http://localhost:8585/api/v1/users/changePassword' -Headers $headers -ContentType 'application/json' -Body $passwordBody | Out-Null

# abctl owns the Airbyte Kind cluster independently of Docker Compose. Its
# credentials command persists the requested email/password and restarts it.
$abctl = Get-Command abctl -ErrorAction SilentlyContinue
if (-not $abctl) {
  $candidate = Join-Path $env:USERPROFILE 'go\bin\abctl.exe'
  if (Test-Path $candidate) { $abctl = Get-Item $candidate }
}
if ($abctl) {
  & $abctl.Source local credentials --email $Email --password $Password | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Unable to update Airbyte credentials.' }
}

& docker compose @composeArgs --profile analytics --profile portal --profile observability `
  --profile lakehouse --profile governance --profile ai --profile orchestration up -d --force-recreate
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Wait-HttpOk 'http://localhost:3000'
Wait-HttpOk 'http://localhost:8088/health'
Wait-HttpOk 'http://localhost:3001/api/health'
Wait-HttpOk 'http://localhost:8180/health/ready'
Wait-HttpOk 'http://localhost:8585'
Wait-HttpOk 'http://localhost:8001'
Write-Output 'Synchronized local administrators and restarted the complete Local Lab.'
