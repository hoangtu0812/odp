# Trino

## Role

Trino is the federated SQL engine. It exposes PostgreSQL and Iceberg catalogs so analysts and tools can query multiple stores through one SQL interface.

## Start and verify

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile lakehouse up -d trino
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml exec -T trino `
  trino --execute "SHOW CATALOGS"
```

## Useful SQL

```sql
SHOW SCHEMAS FROM postgres;
SHOW SCHEMAS FROM iceberg;
SHOW TABLES FROM postgres.mart;
```

Catalog definitions are in `docker/trino/catalog/`. Keep connector-specific credentials in environment variables or a secret manager, never in catalog files committed to Git.
