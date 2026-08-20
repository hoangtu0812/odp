# Data Platform Portal

[English](../portal.md)

## Dùng để làm gì?

Portal là cửa vào trực quan của Local Lab: logo ứng dụng, link truy cập và health status. Mã UI ở `frontend/portal/`, proxy health route ở `docker/portal/default.conf`.

## Khởi động

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile portal up -d --build portal
```

Mở http://localhost:3000.

## Thêm ứng dụng mới

1. Thêm card có logo, `alt`, link và mô tả ngắn vào `index.html`.
2. Nếu service có readiness endpoint ổn định, thêm `data-health` và proxy route.
3. Build lại Portal, dừng service đích để bảo đảm card báo **Chưa sẵn sàng**.

Health status chỉ tiện cho vận hành, không phải lớp authorization; môi trường dùng chung cần OIDC gateway/application session.
