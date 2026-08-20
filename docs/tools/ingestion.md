# Connector framework

## Role

The `ingestion/` directory holds source-specific connectors. A connector is responsible for secure retrieval, pagination, normalization, idempotent landing, audit records, and watermarks.

## Local fixture run

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile ingestion build maximo-ingest
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile ingestion run --rm maximo-ingest --fixture /app/sample_workorders.json
```

## Connector contract

- Retrieve only from explicitly allowed hostnames and use TLS by default.
- Record source time range, record count, outcome, and watermark in platform metadata.
- Normalize source fields before dbt consumes them.
- Reject unsafe pagination URLs and use time-bounded incremental requests.
- Treat a source credential as a secret; never print it to logs or commit it.

For each new system, add a dedicated guide describing its object contract, authentication owner, freshness requirement, error handling, and backfill procedure.
