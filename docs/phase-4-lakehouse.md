# Phase 4 — Object storage and federated SQL

The Local Lab adds a pinned legacy MinIO image strictly for local S3-compatible object storage and Trino 483 for federated SQL. Trino exposes the PostgreSQL `dwh` catalog immediately, proving a query-engine path to the existing warehouse.

## Start and validate

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile lakehouse up -d
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml exec trino trino --execute "show schemas from dwh"
```

- MinIO S3 API: `http://localhost:9000`; Console: `http://localhost:9001`.
- Trino UI/API: `http://localhost:8081`.
- Query `dwh.mart.workorder_summary` from Trino after dbt has run.

MinIO upstream moved the community edition to source-only distribution in 2026. Therefore this pinned image is a Local Lab compatibility component, not a production storage decision. For TEST/Production, use an approved ADLS Gen2 account (provisioned by `infra/azure/main.bicep`) or an organization-approved object store, then add an Iceberg REST catalog or approved catalog service before persisting lakehouse tables.
