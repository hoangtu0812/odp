[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
& kubectl cluster-info --context kind-ldl | Out-Null
foreach ($namespace in 'ldl-data', 'ldl-platform', 'ldl-observability', 'ldl-apps') {
  & kubectl get namespace $namespace | Out-Null
}
& kubectl get pvc -A
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host 'Base Kubernetes cluster, namespaces and PVC query are reachable.' -ForegroundColor Green
Write-Host 'Component health checks run after each pinned Helm release is installed.' -ForegroundColor Yellow
