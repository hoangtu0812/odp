[CmdletBinding()]
param([switch]$Force)
$ErrorActionPreference = 'Stop'
if (-not $Force) {
  $confirmation = Read-Host 'Delete the ldl Kind cluster and all persistent demo data? Type DELETE to continue'
  if ($confirmation -ne 'DELETE') { Write-Host 'Cancelled.'; exit 0 }
}
& kind delete cluster --name ldl
exit $LASTEXITCODE
