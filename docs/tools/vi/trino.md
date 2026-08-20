# Trino

[English](../trino.md)

## Dùng để làm gì?

Trino là SQL engine liên kết nhiều nguồn. Nó cung cấp một điểm truy vấn cho PostgreSQL warehouse và Iceberg lakehouse.

## Khởi động và kiểm tra

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile lakehouse up -d trino
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml exec -T trino `
  trino --execute "SHOW CATALOGS"
```

## Ví dụ

```sql
SHOW SCHEMAS FROM dwh;
SHOW SCHEMAS FROM iceberg;
SHOW TABLES FROM dwh.mart;
```

Catalog được cấu hình trong `docker/trino/catalog/`; không ghi credential trực tiếp vào file catalog.
