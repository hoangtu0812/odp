# dbt

[English](../dbt.md)

## Dùng để làm gì?

dbt biến dữ liệu đã nạp thành các mô hình warehouse có kiểm thử và tài liệu. Project đặt ở `dbt/bsr_analytics`, theo các lớp raw → staging → core → mart.

## Chạy

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile tools run --rm dbt debug
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile tools run --rm dbt run
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile tools run --rm dbt test
```

## Cách làm và ví dụ

Tạo model SQL trong `models/`, khai báo schema/test trong file YAML, rồi chạy:

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile tools run --rm dbt build --select workorder_summary+
```

Ví dụ test `not_null` và `unique` đảm bảo khóa nghiệp vụ không rỗng, không trùng. Seed demo mặc định tắt để không đi vào pipeline thật.
