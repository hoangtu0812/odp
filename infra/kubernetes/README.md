# Local Kubernetes deployment

LDL Kubernetes mode is independent of Docker Compose: it uses one Kind
cluster, Kubernetes Services/PVCs/Secrets, and pinned Helm releases. It never
calls `abctl`, the legacy OpenMetadata Compose launcher, or Compose from a pod.

## Prerequisites

* Docker Desktop with 8 CPU, 16 GB available RAM and 50 GB free disk.
* Kind, kubectl and Helm 3.19+.
* Windows hosts should map `portal.ldl.local` to `127.0.0.1` once ingress is
  installed; port-forward is the fallback while platform ingress is expanded.

## Bootstrap

```powershell
.\scripts\k8s-up.ps1 -Initialize
# edit .env.k8s and replace every value
.\scripts\k8s-up.ps1
```

The script creates Kind `ldl` pinned to Kubernetes 1.30.13, applies separated
data/platform/observability/apps namespaces, builds and loads LDL images, then
installs pinned Helm releases. `scripts/k8s-status.ps1` reports namespace pod
state; `scripts/k8s-smoke-test.ps1` verifies cluster and persistence
prerequisites; `scripts/k8s-down.ps1` deletes the cluster after confirmation.

## Version matrix

| Component | Pin |
| --- | --- |
| Kubernetes / Kind node | 1.30.13 |
| Apache Airflow Helm chart | 1.22.0 |
| Airbyte Helm chart | 1.1.0 |
| Superset Helm chart | 0.14.0 |
| OpenMetadata Helm chart | 1.6.9 |
| kube-prometheus-stack | 65.5.1 |
| PostgreSQL | 16.4-alpine |
| Trino | 483 |

Chart values are intentionally kept under `values/`; before each upgrade run
`helm lint` and `helm template` against the pinned repositories. The full
service manifests and end-to-end component health checks are delivered in
subsequent Kubernetes phases, rather than being represented as mock statuses.
