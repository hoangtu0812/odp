# Open Source Data Platform

Local Lab theo roadmap cho vertical slice Maximo Work Order: ingestion → PostgreSQL DWH → dbt → Airflow → Superset.

Tài liệu đầy đủ về từng ứng dụng, cách vận hành và kiến trúc môi trường: [Platform Operations Guide](docs/platform-operations-guide.md).

## Phạm vi hiện tại

```text
Maximo OSLc / fixture → raw → staging → core → mart → Superset
                         ↓       dbt       ↑
                      audit + watermark   Airflow
```

Local Compose có các profile `ingestion`, `orchestration`, `analytics` và `tools`. Maximo live ingestion mặc định tắt để không tự gửi credential ra endpoint trước khi được xác thực.

## Điều kiện cần

- Docker Desktop (hoặc Docker Engine) và Docker Compose v2
- Git

## Chạy Local Lab

Tạo file cấu hình local:

```powershell
Copy-Item .env.example .env
```

Đổi `POSTGRES_PASSWORD`, `DBT_PASSWORD`, Airflow secrets và Superset secrets trước khi dùng ngoài máy local. Khởi động PostgreSQL và migration:

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml up -d postgres postgres-migrations
```

Xác minh connector bằng fixture cục bộ, rồi build mô hình dbt:

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile ingestion build maximo-ingest
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile ingestion run --rm maximo-ingest --fixture /app/sample_workorders.json
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile tools run --rm dbt run
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile tools run --rm dbt test
```

Kiểm tra kết quả:

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml exec postgres `
  psql -U platform_admin -d dwh -c "select * from mart.workorder_summary order by reported_date;"
```

Nếu container đã khởi tạo nhưng database `dwh` bị thiếu (ví dụ bootstrap từng bị gián đoạn), chạy lại bootstrap an toàn, không cần xóa volume:

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml exec postgres `
  bash /docker-entrypoint-initdb.d/01-create-databases.sh
```

## Chạy ingestion Maximo thật

Sau khi chủ hệ thống xác nhận endpoint Maximo REST MBO và mốc nạp ban đầu, chạy một lần thủ công:

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile ingestion run --rm maximo-ingest
```

Connector dùng header `maxauth` mặc định (hoặc Basic/API key khi được cấu hình), chỉ chấp nhận pagination URL cùng hostname, nạp incremental bằng `changedate`, và lưu trạng thái vào `platform_metadata.public.ingestion_audit`/`ingestion_watermark`. Với Maximo REST MBO, đặt `MAXIMO_API_STYLE=rest_mbo`, `MAXIMO_WORKORDER_PATH=/rest/mbo/workorder/` và `MAXIMO_INITIAL_SYNC_SINCE`. HTTPS là mặc định; HTTP nội bộ chỉ dùng khi được phê duyệt rõ ràng qua `MAXIMO_ALLOW_INSECURE_HTTP=true`.

Để giao việc cho Airflow sau khi lần chạy thủ công đã được xác nhận, cần phê duyệt riêng việc gửi credential qua HTTP nội bộ lặp lại mỗi 15 phút; sau đó thêm `MAXIMO_INGEST_ENABLED=true` vào `.env` rồi khởi động Airflow.

## Airflow orchestration

Airflow chạy Maximo ingestion (khi được bật), rồi `dbt run` và `dbt test` mỗi 15 phút cho DAG `maximo_dbt_pipeline`.

Khởi động Airflow:

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile orchestration up -d --build
```

Mở `http://localhost:8080`. Local Lab dùng chế độ không yêu cầu đăng nhập và chỉ được expose trên máy phát triển. Không dùng cấu hình này cho TEST/Production.

## Monitoring và portal

Khởi động Grafana, Prometheus, exporters và portal:

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile observability --profile portal up -d --build
```

- Portal: `http://localhost:3000`
- Grafana: `http://localhost:3001`
- Prometheus: `http://localhost:9090`

Chi tiết dashboard, metric và giới hạn Local Lab: [Phase 3 observability](docs/phase-3-observability.md).

Kiểm tra lỗi import DAG và trigger một lần ngay lập tức:

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml exec airflow-api-server `
  bash /opt/airflow/platform-entrypoint.sh dags list-import-errors
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml exec airflow-api-server `
  bash /opt/airflow/platform-entrypoint.sh dags trigger maximo_dbt_pipeline
```

## Cấu trúc

- `docker/postgres/init`: tạo các database metadata và schema DWH lúc PostgreSQL khởi tạo lần đầu.
- `infra/docker-compose`: Docker Compose cho Local Lab.
- `dbt/bsr_analytics`: transformations, tests và seed demo tùy chọn.
- `ingestion/maximo`: connector OSLc incremental và fixture test.
- `airflow/dags`: DAG orchestration.
- `docker/superset`: image, cấu hình và bootstrap BI.
- `infra/azure`: Bicep foundation và hướng dẫn Azure.
- `docs`: tài liệu vận hành và kiến trúc.

## BI

Khởi động Superset:

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile analytics up -d --build superset
```

Mở `http://localhost:8088`. Metadata Superset nằm trong database `superset`; role `superset_bi` chỉ có quyền đọc schema `mart` của `dwh`. Tạo kết nối PostgreSQL trong Superset bằng host `postgres`, database `dwh`, user `superset_bi`, rồi chọn dataset `mart.workorder_summary`.

## Data Platform Portal

Portal launcher theo kiến trúc tham chiếu có link trực tiếp tới Airflow và Superset, đồng thời thể hiện các năng lực roadmap còn lại:

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile portal up -d --build portal
```

Mở `http://localhost:3000`. Đây là launcher local; xác thực tập trung sẽ được thêm cùng Keycloak/Entra trong Phase 5.

## Lakehouse foundation

MinIO và Trino được thêm cho Local Lab. Xem [Phase 4 runbook](docs/phase-4-lakehouse.md) để khởi động và kiểm tra query `dwh.mart.workorder_summary` qua Trino.

## Azure và CI

- Bicep foundation: [infra/azure/README.md](infra/azure/README.md).
- GitHub Actions kiểm tra Python và Docker Compose: `.github/workflows/validate.yml`.

## Lưu ý vận hành

- Không commit `.env`, secrets hoặc certificates.
- Script khởi tạo PostgreSQL chỉ chạy khi volume còn mới. Để thêm schema/migration sau này, dùng thư mục `sql/migrations`.
- Superset chỉ được cấp quyền đọc schema `mart`, không truy vấn trực tiếp `raw`.
- Docker Compose là Local Lab/single-host; TEST/Production dùng nền tảng container có HA, private networking, SSO/RBAC và backup theo hướng dẫn Azure.
