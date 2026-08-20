# OpenMetadata

[English](../openmetadata.md)

## Dùng để làm gì?

OpenMetadata là data catalog trung tâm: dataset description, owner, tag, glossary, lineage, data quality và discovery. Nó nhận metadata từ PostgreSQL, dbt, Airflow, Superset và Trino.

## Triển khai Local Lab

OpenMetadata cần server, ingestion, database và Elasticsearch nên chạy như stack riêng. Script sau tải file Compose PostgreSQL chính thức version-pinned, đổi cổng ingestion sang `8084` để không đụng Airflow, rồi khởi động stack:

```powershell
.\scripts\start-openmetadata.ps1
docker compose --project-name open-source-data-platform-openmetadata `
  -f .runtime\openmetadata\docker-compose.yml ps
```

Giao diện chuẩn là http://localhost:8585. Đảm bảo Docker Desktop có thêm tối thiểu 6 GB RAM cho stack này; port ingestion mặc định có thể trùng Airflow, do đó phải đổi mapping trước khi chạy cùng Local Lab.

## Thứ tự tích hợp và ví dụ

1. Register PostgreSQL và Trino services.
2. Ingest dbt metadata để có model/test/lineage.
3. Ingest Airflow để có pipeline và owner.
4. Ingest Superset để có dashboard lineage.
5. Gán owner, description, glossary và SLA freshness cho curated mart.

Không đưa source password vào tài liệu hay catalog export.
