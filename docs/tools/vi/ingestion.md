# Khung connector

[English](../ingestion.md)

## Dùng để làm gì?

Thư mục `ingestion/` chứa connector theo từng hệ thống nguồn. Connector thực hiện xác thực, pagination, chuẩn hóa, nạp idempotent, audit và watermark.

## Ví dụ chạy fixture

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile ingestion build maximo-ingest
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile ingestion run --rm maximo-ingest --fixture /app/sample_workorders.json
```

## Quy tắc xây dựng

- Dùng HTTPS mặc định và chỉ cho phép hostname đã phê duyệt.
- Lưu thời gian nạp, số bản ghi, kết quả và watermark.
- Chống URL phân trang ngoài hostname nguồn.
- Không in password/token vào log.

Với nguồn mới, tạo runbook ghi rõ object, chủ sở hữu credential, cursor, khóa, lịch nạp, backfill và xử lý lỗi.
