# Apache Superset

[English](../superset.md)

## Dùng để làm gì?

Superset cung cấp data exploration, chart và dashboard trên dữ liệu mart đã được quản trị.

## Khởi động

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile analytics up -d --build
```

Mở http://localhost:8088; sử dụng tài khoản administrator trong `.env`.

## Cách làm và ví dụ

1. Tạo database connection PostgreSQL tới host `postgres`, database `dwh`, role BI riêng.
2. Tạo dataset từ `mart.workorder_summary`.
3. Khai báo metric, ví dụ `SUM(work_order_count)`.
4. Tạo chart rồi đưa vào dashboard.

Dashboard dùng chung nên dựa vào certified dataset, không truy vấn bảng raw.
