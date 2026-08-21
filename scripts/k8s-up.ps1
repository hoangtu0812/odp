[CmdletBinding()]
param(
  [switch]$Initialize,
  [switch]$GenerateLocalSecrets,
  [switch]$SkipAirbyte,
  [switch]$SkipOpenMetadata,
  [switch]$SkipObservability
)

<#
.SYNOPSIS
  Create the single-node LDL Kind cluster and install the Kubernetes stack.

.DESCRIPTION
  This command never calls Docker Compose, abctl, or the OpenMetadata Compose
  launcher. It loads LDL images into the one Kind cluster and installs
  third-party components from pinned Helm releases.
#>

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $root '.env.k8s'
$clusterConfig = Join-Path $root 'infra\kubernetes\cluster\kind-config.yaml'

function New-LocalSecret {
  $bytes = New-Object byte[] 32
  [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
  return [Convert]::ToBase64String($bytes).Replace('+', 'a').Replace('/', 'b').Replace('=', 'c')
}

foreach ($command in 'docker', 'kind', 'kubectl', 'helm') {
  if (-not (Get-Command $command -ErrorAction SilentlyContinue)) { throw "$command is required for local Kubernetes." }
}
if (-not (Test-Path $envFile)) {
  if (-not $Initialize) { throw "Missing .env.k8s. Run .\scripts\k8s-up.ps1 -Initialize, set non-placeholder secrets, then rerun." }
  Copy-Item (Join-Path $root '.env.k8s.example') $envFile
  if (-not $GenerateLocalSecrets) { throw 'Created .env.k8s. Replace every placeholder secret before starting the cluster.' }
}
if ($GenerateLocalSecrets) {
  $generated = Get-Content $envFile | ForEach-Object {
    if ($_ -match '^(?<name>[^#=]+)=replace-me$') { "$($Matches.name)=$(New-LocalSecret)" } else { $_ }
  }
  Set-Content -LiteralPath $envFile -Value $generated -Encoding utf8
  Write-Host 'Generated local-only Kubernetes secrets in .env.k8s.' -ForegroundColor Yellow
}
if ((Get-Content $envFile | Where-Object { $_ -match '=replace-me$' }).Count -gt 0) { throw '.env.k8s still contains replace-me values.' }

Push-Location $root
try {
  $clusterExists = @(& kind get clusters) -contains 'ldl'
  if (-not $clusterExists) { & kind create cluster --name ldl --config $clusterConfig }
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & kubectl config use-context kind-ldl
  & kubectl apply -f infra/kubernetes/namespaces/namespaces.yaml
  & kubectl -n ldl-data create configmap maximo-demo-assets --from-file=examples/maximo --dry-run=client -o yaml | kubectl apply -f -
  & kubectl -n ldl-platform create configmap airflow-dags --from-file=airflow/dags --dry-run=client -o yaml | kubectl apply -f -
  & kubectl -n ldl-platform create configmap dbt-project --from-file=dbt/bsr_analytics --dry-run=client -o yaml | kubectl apply -f -
  & kubectl -n ldl-platform create configmap ldl-policies --from-file=opa/policies --dry-run=client -o yaml | kubectl apply -f -
  & kubectl -n ldl-data create secret generic ldl-secrets --from-env-file=$envFile --dry-run=client -o yaml | kubectl apply -f -
  & kubectl -n ldl-platform create secret generic ldl-secrets --from-env-file=$envFile --dry-run=client -o yaml | kubectl apply -f -
  & kubectl -n ldl-apps create secret generic ldl-secrets --from-env-file=$envFile --dry-run=client -o yaml | kubectl apply -f -

  & docker build -t ldl-airflow:1.0.0 -f docker/airflow/Dockerfile .
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & docker build -t ldl-ai-service:1.0.0 ai-service
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & docker build -t ldl-portal:1.0.0 -f docker/portal/Dockerfile .
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & kind load docker-image --name ldl ldl-airflow:1.0.0 ldl-ai-service:1.0.0 ldl-portal:1.0.0

  & helm repo add apache-airflow https://airflow.apache.org --force-update
  & helm repo add superset https://apache.github.io/superset --force-update
  & helm repo add airbyte https://airbytehq.github.io/helm-charts --force-update
  & helm repo add open-metadata https://helm.open-metadata.org/ --force-update
  & helm repo add prometheus-community https://prometheus-community.github.io/helm-charts --force-update
  & helm repo update
  & helm upgrade --install airflow apache-airflow/airflow --version 1.22.0 -n ldl-platform -f infra/kubernetes/values/airflow.yaml
  & helm upgrade --install superset superset/superset --version 0.14.0 -n ldl-platform -f infra/kubernetes/values/superset.yaml
  if (-not $SkipAirbyte) { & helm upgrade --install airbyte airbyte/airbyte --version 1.1.0 -n ldl-platform -f infra/kubernetes/values/airbyte.yaml }
  if (-not $SkipOpenMetadata) { & helm upgrade --install openmetadata open-metadata/openmetadata --version 1.6.9 -n ldl-platform -f infra/kubernetes/values/openmetadata.yaml }
  if (-not $SkipObservability) { & helm upgrade --install observability prometheus-community/kube-prometheus-stack --version 65.5.1 -n ldl-observability -f infra/kubernetes/values/observability.yaml }

  & kubectl apply -f infra/kubernetes/ingress/ingress.yaml
  & (Join-Path $PSScriptRoot 'k8s-smoke-test.ps1')
} finally {
  Pop-Location
}
