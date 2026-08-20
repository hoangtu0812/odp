# Grafana

[English](../grafana.md)

## Dùng để làm gì?

Grafana là giao diện trực quan cho metrics Prometheus và logs Loki.

## Khởi động

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile observability up -d grafana
```

Mở http://localhost:3001 và đăng nhập bằng giá trị Grafana trong `.env`.

## Ví dụ sử dụng

Vào **Explore**, chọn Prometheus để xem service availability hoặc chọn Loki để lọc log. Dashboard nên có database health, pipeline latency, task failure và link log theo thời gian.
