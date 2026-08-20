# Loki và Alloy

[English](../loki.md)

## Dùng để làm gì?

Loki lưu log; Grafana Alloy đọc log container Docker và chuyển về Loki.

## Khởi động và kiểm tra

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile observability up -d loki alloy
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml logs --tail=50 alloy
```

Trong Grafana Explore, chọn Loki và thử `{container=~".+"}` rồi lọc hẹp theo service và thời gian.

Alloy có Docker socket read-only nhưng vẫn là quyền nhạy cảm; chỉ cấp trên host được kiểm soát.
