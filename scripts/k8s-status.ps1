[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
if (-not (Get-Command kubectl -ErrorAction SilentlyContinue)) { throw 'kubectl is required.' }
Write-Host 'Loop Data Lab Kubernetes' -ForegroundColor Cyan
foreach ($namespace in 'ldl-data', 'ldl-platform', 'ldl-observability', 'ldl-apps') {
  $pods = & kubectl get pods -n $namespace --no-headers 2>$null
  $state = if ($LASTEXITCODE -eq 0 -and $pods) { 'READY (inspect pods below)' } else { 'NOT READY' }
  Write-Host ("{0,-20} {1}" -f $namespace, $state)
  if ($pods) { $pods | ForEach-Object { Write-Host "  $_" } }
}
