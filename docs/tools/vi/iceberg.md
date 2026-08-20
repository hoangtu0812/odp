# Apache Iceberg

[English](../iceberg.md)

## Dùng để làm gì?

Iceberg là định dạng bảng mở cho lakehouse: schema evolution, snapshot và time travel. Local Lab dùng REST catalog và MinIO làm storage.

## Khởi động và kiểm tra

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile lakehouse up -d iceberg-rest
Invoke-WebRequest http://localhost:8181/v1/config -UseBasicParsing
```

## Ví dụ

Tạo bảng Iceberg thông qua catalog `iceberg` của Trino. Metadata bảng nằm ở REST catalog, còn file dữ liệu nằm trong bucket `warehouse`.

```sql
CREATE SCHEMA IF NOT EXISTS iceberg.analytics;
```
