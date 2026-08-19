# BSR Open-Source Data Platform

Local Lab khởi đầu cho BSR Data Platform, theo roadmap: PostgreSQL DWH và dbt cho use case Maximo Work Order.

## Phạm vi hiện tại

```text
Maximo sample data
        ↓
PostgreSQL: raw → staging → core → mart
        ↑
       dbt
```

Airflow đã được thêm để điều phối transform/test. Airbyte, Superset và monitoring sẽ được bổ sung sau theo từng vertical slice.

## Điều kiện cần

- Docker Desktop (hoặc Docker Engine) và Docker Compose v2
- Git

## Chạy Local Lab

Tạo file cấu hình local:

```powershell
Copy-Item .env.example .env
```

Đổi `POSTGRES_PASSWORD` và `DBT_PASSWORD` trong `.env` thành cùng một mật khẩu mạnh, rồi khởi động PostgreSQL:

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml up -d postgres
```

Nạp dữ liệu Maximo mẫu và build mô hình dbt:

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile tools run --rm dbt seed
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile tools run --rm dbt build
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

## Airflow orchestration

Airflow chạy `dbt run` rồi `dbt test` mỗi 15 phút cho DAG `maximo_dbt_pipeline`. Dữ liệu nguồn thật sẽ được Airbyte hoặc custom ingestion nạp vào `raw` trước khi DAG này chạy.

Khởi động Airflow:

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile orchestration up -d --build
```

Mở `http://localhost:8080`. Local Lab dùng chế độ không yêu cầu đăng nhập và chỉ được expose trên máy phát triển. Không dùng cấu hình này cho TEST/Production.

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
- `dbt/bsr_analytics`: transformations, tests và seed Work Order mẫu.
- `ingestion`: nơi chứa connector/script theo từng nguồn khi triển khai ingestion thật.
- `airflow/dags`: nơi chứa DAG sau khi Airflow được thêm vào Phase 2.
- `docs`: tài liệu vận hành và kiến trúc.

## Lưu ý vận hành

- Không commit `.env`, secrets hoặc certificates.
- Script khởi tạo PostgreSQL chỉ chạy khi volume còn mới. Để thêm schema/migration sau này, dùng thư mục `sql/migrations`.
- Superset chỉ được cấp quyền đọc schema `mart`, không truy vấn trực tiếp `raw`.
