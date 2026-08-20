# Phase 3 — BI và observability local

## Thành phần đã triển khai

- **Grafana** tại `http://localhost:3001`: UI theo dõi vận hành. Datasource Prometheus và dashboard `Open Source Data Platform — Local Overview` được provision tự động.
- **Prometheus** tại `http://localhost:9090`: thu thập metrics mỗi 15 giây, retention local 15 ngày.
- **Blackbox Exporter**: probe HTTP cho Airflow, Superset, MinIO, Trino và portal.
- **PostgreSQL Exporter**: thu thập availability và database size của DWH.
- **Portal** tại `http://localhost:3000`: launcher và health check thực tế cho các ứng dụng.

Khởi động các thành phần observability:

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile observability --profile portal up -d --build
```

Grafana dùng `GRAFANA_ADMIN_USER` và `GRAFANA_ADMIN_PASSWORD` trong `.env`; thay giá trị mặc định trước khi mở cho mạng dùng chung.

## Phạm vi dashboard hiện tại

- Sẵn sàng HTTP của các dịch vụ ứng dụng.
- Độ trễ probe HTTP.
- Tính sẵn sàng PostgreSQL.
- Kích thước các database PostgreSQL.

Loki, thu thập Docker/host metrics (cAdvisor hoặc node exporter), alert routing và SSO Grafana là hạng mục tiếp theo. Chúng không được giả định là production-ready trong Local Lab.
