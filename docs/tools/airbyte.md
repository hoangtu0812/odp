# Airbyte

## Role

Airbyte is the planned connector-management layer for repeatable source-to-destination synchronization. It complements, rather than replaces, source-specific code when a system needs custom authentication, pagination, or audit behavior.

## Deploy in the Local Lab

Airbyte is deployed by its official `abctl` tool. It creates a dedicated Kind Kubernetes cluster inside Docker, so it does not use the Docker Desktop Kubernetes setting.

```powershell
& .\scripts\start-airbyte.ps1 -InstallAbctl
& "$env:USERPROFILE\go\bin\abctl.exe" local status
```

Open http://localhost:8001. Retrieve generated local credentials only when needed with `abctl local credentials`; do not commit or paste them into platform documentation.

## Example connection

1. Create a read-only source (for example PostgreSQL or HTTP API).
2. Create a destination that lands in the raw layer.
3. Create a connection with a primary key and incremental cursor; test a bounded date range first.
4. On successful sync, trigger Airflow to run dbt models and tests.

Record source owner, selected streams, cursor field, primary key, schedule, retention, and backfill method in the connector runbook.

## Operate safely

Check readiness with `abctl local status`. Airbyte runs outside the platform Compose project, so `docker compose down` for the platform does not stop it. `abctl local uninstall` removes the local Kind installation; use it only when you intentionally want to remove Airbyte runtime data.

## Operational checklist

- Use a dedicated source identity with minimum permissions.
- Test one stream and a bounded date window before enabling schedules.
- Store configuration secrets in the platform secret mechanism, not in exported connection JSON.
- Monitor sync failures, freshness, schema drift, and volume changes.
- Keep a custom connector whenever the upstream API contract cannot be safely expressed by a generic connector.
