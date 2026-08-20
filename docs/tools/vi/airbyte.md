# Airbyte

[English](../airbyte.md)

## Dùng để làm gì?

Airbyte quản lý source, destination, connection và lịch đồng bộ cho các connector được hỗ trợ. Nó phù hợp với PostgreSQL, SQL Server, MySQL, Oracle, REST API và nhiều nguồn khác; API đặc thù vẫn dùng custom connector khi cần.

## Triển khai Local Lab

Airbyte dùng `abctl`, tự tạo Kind cluster trong Docker nên không phụ thuộc Kubernetes tích hợp của Docker Desktop.

```powershell
& .\scripts\start-airbyte.ps1 -InstallAbctl
& "$env:USERPROFILE\go\bin\abctl.exe" local status
```

Mở http://localhost:8001. Lấy credential local bằng `abctl local credentials`; không copy credential vào Git hoặc chat.

## Ví dụ cấu hình

1. Trong Airbyte, tạo **Source** PostgreSQL hoặc REST API bằng account chỉ có quyền đọc.
2. Tạo **Destination** PostgreSQL raw layer.
3. Tạo **Connection**, chọn primary key/cursor, thử một date range nhỏ trước.
4. Sau sync thành công, trigger Airflow để chạy dbt.

Theo dõi job lỗi, schema drift, freshness và volume. Mỗi connection phải có owner, retention và backfill runbook.

## Vận hành an toàn

Kiểm tra bằng `abctl local status`. Airbyte chạy ngoài Compose project chính nên `docker compose down` của nền tảng không dừng nó. `abctl local uninstall` xóa Kind installation local; chỉ dùng khi chủ động muốn xóa runtime data của Airbyte.
