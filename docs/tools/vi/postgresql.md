# PostgreSQL warehouse

[English](../postgresql.md)

## Dùng để làm gì?

PostgreSQL là kho dữ liệu quan hệ của Local Lab. Database `dwh` lưu các lớp dữ liệu và metadata; thay đổi cấu trúc được quản lý bởi migration trong `sql/migrations/`.

## Khởi động và kiểm tra

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml up -d postgres postgres-migrations
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml exec postgres `
  psql -U platform_admin -d dwh -c "select current_database(), now();"
```

## Cách dùng và ví dụ

Tạo migration mới có số thứ tự tiếp theo, ví dụ `004_add_asset_owner.sql`, rồi khởi động lại `postgres-migrations`. Không sửa migration đã chạy.

```sql
select * from mart.workorder_summary order by reported_date desc;
```

Chỉ công bố dữ liệu tiêu thụ từ `mart`; không cấp Superset hoặc người dùng quyền đọc trực tiếp lớp `raw`.
