# Prometheus

[English](../prometheus.md)

## Dùng để làm gì?

Prometheus thu thập metrics, đánh giá rule cảnh báo và làm datasource cho Grafana.

## Khởi động

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile observability up -d prometheus blackbox-exporter postgres-exporter alertmanager
```

Mở http://localhost:9090, vào **Status → Targets** để xác minh scrape target.

## Ví dụ

Thêm health endpoint cho service trước, sau đó thêm probe vào `docker/prometheus/prometheus.yml`. Rule nằm trong `docker/prometheus/rules.yml`; Alertmanager Local Lab dùng receiver no-op để không gửi cảnh báo ra ngoài.
