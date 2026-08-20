# MinIO

[English](../minio.md)

## Dùng để làm gì?

MinIO là object storage tương thích S3. Local Lab dùng nó chứa file Iceberg và tự tạo bucket `warehouse`, `data-platform`.

## Khởi động và dùng

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile lakehouse up -d minio minio-init
```

Mở http://localhost:9001, đăng nhập bằng `MINIO_ROOT_USER` và `MINIO_ROOT_PASSWORD` trong `.env`. Ví dụ: kiểm tra bucket `warehouse` sau khi `minio-init` hoàn tất.

Không dùng root credential cho connector; môi trường dùng chung cần access key riêng theo workload.
