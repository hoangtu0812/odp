# OpenMetadata

## Role

OpenMetadata is the planned central catalog for datasets, ownership, glossary terms, lineage, and data-quality observability. It receives metadata from warehouse, transformation, orchestration, BI, and query services.

## Deploy in the Local Lab

OpenMetadata runs as an isolated, official version-pinned Compose stack because it includes a server, ingestion service, PostgreSQL, and Elasticsearch. The provided script downloads the upstream `1.12.6` PostgreSQL quickstart, moves its ingestion UI to port `8084` to avoid Airflow, and starts it under a separate Compose project.

```powershell
.\scripts\start-openmetadata.ps1
docker compose --project-name open-source-data-platform-openmetadata `
  -f .runtime\openmetadata\docker-compose.yml ps
```

Open the catalog at http://localhost:8585. Allocate at least 6 GB additional Docker memory before starting the stack. Before connecting services, define ownership, service accounts, metadata retention, authoritative catalog entities, and the Keycloak/Entra integration model.

## Integration order

1. Register PostgreSQL and Trino services.
2. Ingest dbt metadata for models, tests, and lineage.
3. Ingest Airflow metadata for pipelines and ownership.
4. Register Superset dashboards and data products.
5. Assign owners, glossary terms, descriptions, and freshness expectations.

Do not publish credentials through catalog configuration or documentation.
