# MinIO

## Role

MinIO supplies S3-compatible object storage for the Local Lab. It stores lakehouse files and is initialized with `warehouse` and `data-platform` buckets.

## Start and verify

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile lakehouse up -d minio minio-init
```

Open http://localhost:9001 and use `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` from `.env`.

## Operations

- Use dedicated buckets and access keys per workload outside the Local Lab.
- Store table data in `warehouse`; avoid mixing application uploads and warehouse tables.
- Do not use root credentials in connectors or BI tools.
- Named volume `minio_data` retains files after `docker compose down`.
