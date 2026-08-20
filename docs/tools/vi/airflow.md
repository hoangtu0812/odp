# Apache Airflow

[English](../airflow.md)

## Dùng để làm gì?

Airflow điều phối pipeline: thứ tự tác vụ, lịch chạy, retry, trạng thái và log. DAG được lưu ở `airflow/dags/`.

## Khởi động

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile orchestration up -d --build
```

Mở http://localhost:8080 để xem DAG, trigger một lần, hoặc xem log task.

## Cách làm và ví dụ

Một DAG điển hình: chạy connector → `dbt run` → `dbt test` → cập nhật audit. Tác vụ phải idempotent để retry không tạo bản ghi trùng.

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml exec airflow-api-server `
  bash /opt/airflow/platform-entrypoint.sh dags list-import-errors
```

Kiểm tra import error trước khi kết luận DAG bị thiếu.
