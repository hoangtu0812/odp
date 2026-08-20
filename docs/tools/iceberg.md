# Apache Iceberg

## Role

Apache Iceberg supplies an open table format with schema evolution, snapshots, and time-travel metadata. The Local Lab uses an Iceberg REST catalog with MinIO as its object store.

## Start and verify

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile lakehouse up -d iceberg-rest
Invoke-WebRequest http://localhost:8181/v1/config -UseBasicParsing
```

## Use through Trino

Create schemas and tables through the `iceberg` catalog in Trino. The REST service stores catalog metadata; actual table files are placed in the `warehouse` bucket.

For shared environments, replace local static credentials with a scoped identity and a managed catalog service appropriate to the target platform.
