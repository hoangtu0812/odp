# LDL local Kubernetes

See [the Kubernetes deployment guide](../infra/kubernetes/README.md) for
prerequisites, the version matrix, bootstrap and teardown. Kubernetes mode is
separate from Compose and uses the Maximo data journey.

The expected path is:

```text
Maximo → raw.maximo_workorder → Airflow → dbt maintenance marts
       → Trino / Superset / OpenMetadata / AI Assistant
```

Use `scripts/k8s-up.ps1`, `scripts/k8s-status.ps1`,
`scripts/k8s-smoke-test.ps1` and `scripts/k8s-down.ps1`; none invoke Docker
Compose or create a second Airbyte cluster.
