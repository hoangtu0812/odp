# Loop Data Lab (LDL) — hướng dẫn ứng dụng và vận hành

## 1. Mục đích và luồng vận hành

Nền tảng triển khai theo từng vertical slice, bắt đầu với Maximo Work Order. Luồng dữ liệu hiện tại là:

```text
Maximo REST MBO / JSON fixture
        │
        ▼
Custom Maximo connector ─── audit + watermark ─── platform_metadata
        │
        ▼
PostgreSQL dwh.raw
        │
        ▼
dbt: staging → core → mart
        │                    │
        ▼                    └── dbt tests
Airflow schedule
        │
        ▼
Superset / Trino / Portal
        │
        ▼
Prometheus → Grafana
```

`raw` giữ dữ liệu nguồn; `staging` chuẩn hóa kiểu và mã; `core` tạo dim/fact; `mart` là dữ liệu nghiệp vụ an toàn cho BI. Không kết nối Superset trực tiếp vào `raw`.

## 2. Danh mục ứng dụng

| Ứng dụng | Port local | Dùng để làm gì | Trạng thái |
| --- | ---: | --- | --- |
| PostgreSQL | 5432 | DWH và metadata cho Airflow/Superset/ingestion | Đang chạy |
| Maximo connector | one-off/Airflow | Nạp Work Order incremental, upsert, audit/watermark | Sẵn sàng; cần credential hợp lệ |
| dbt | CLI container | Transform raw → mart và kiểm tra chất lượng dữ liệu | Đang chạy |
| Airflow | 8080 | Lập lịch ingestion + dbt, retry và lưu log | Đang chạy |
| Superset | 8088 | Dashboard/report từ schema `mart` | Đang chạy |
| Portal | 3000 | Launcher tập trung cho các ứng dụng | Đang chạy |
| Grafana | 3001 | Dashboard vận hành cho availability, độ trễ và PostgreSQL | Đang chạy |
| Prometheus | 9090 | Thu thập metrics/probe Local Lab, retention 15 ngày | Đang chạy |
| MinIO | 9000/9001 | Object storage S3-compatible Local Lab | Đang chạy |
| Trino | 8081 | SQL federation, hiện truy vấn PostgreSQL DWH | Đang chạy |
| Airbyte | 8001 | Quản lý connector/source/destination chạy trong Kind | Đang chạy độc lập qua `abctl` |
| OpenMetadata | 8585 | Data catalog, ownership, lineage và data quality | Đang chạy độc lập qua Compose |
| Keycloak | 8180 | Identity broker và Azure Entra SSO cho Portal | Đang chạy |
| Azure Bicep | CLI | Khai báo ACR, storage, Key Vault, Log Analytics | Đã validate; chưa deploy |

## 3. Khởi động local

Chạy từ repository root trong PowerShell. Docker Desktop phải đang chạy. Script duy nhất dưới đây điều phối các profile Compose chính, Airbyte `abctl`/Kind và OpenMetadata Compose độc lập:

```powershell
.\scripts\start-local-lab.ps1
```

Trên máy mới, chạy `.\scripts\start-local-lab.ps1 -InstallAirbyte` để cài `abctl` (cần Go). Nếu chưa có `.env`, chạy `-Initialize`, điền password/secret và ba biến Azure Entra, rồi chạy lại. Khi Docker thiếu tài nguyên, chạy `-SkipAirbyte -SkipOpenMetadata`; khi không muốn khởi động Portal Azure, thêm `-SkipPortal`.

Kiểm tra tổng quan:

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml ps
Invoke-WebRequest http://localhost:8080/api/v2/monitor/health
Invoke-WebRequest http://localhost:8088/health
Invoke-WebRequest http://localhost:3000
Invoke-WebRequest http://localhost:3001/api/health
Invoke-WebRequest http://localhost:9090/-/ready
Invoke-WebRequest http://localhost:8081/v1/info
Invoke-WebRequest http://localhost:9000/minio/health/live
& "$env:USERPROFILE\go\bin\abctl.exe" local status
docker compose --project-name open-source-data-platform-openmetadata `
  -f .runtime\openmetadata\docker-compose.yml ps
```

## 4. Vận hành ingestion Maximo

### Chạy fixture không gọi Maximo

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile ingestion run --rm maximo-ingest --fixture /app/sample_workorders.json
```

### Chạy Maximo thật

1. Đặt `MAXIMO_BASE_URL`, `MAXIMO_USER`, `MAXIMO_PASS` trong `.env`. Connector dùng `MAXIMO_AUTH_MODE=maxauth` mặc định, tương ứng header `maxauth` của Maximo REST; chỉ đặt `MAXIMO_MAXAUTH` khi quản trị Maximo cấp sẵn token base64 riêng. Với Maximo REST MBO, đặt `MAXIMO_API_STYLE=rest_mbo` và `MAXIMO_WORKORDER_PATH=/rest/mbo/workorder/`.
2. Ưu tiên HTTPS. HTTP nội bộ chỉ dùng khi được phê duyệt và phải đặt `MAXIMO_ALLOW_INSECURE_HTTP=true`.
3. Kiểm tra account có quyền đọc REST MBO Work Order (`/rest/mbo/workorder/`) hoặc đặt `MAXIMO_WORKORDER_PATH` theo object structure được Maximo cấp.
4. Do Maximo hiện có hàng triệu Work Order, đặt `MAXIMO_INITIAL_SYNC_SINCE` theo retention được chủ dữ liệu phê duyệt (ví dụ mốc go-live hoặc 12 tháng gần nhất). Connector không cho phép full snapshot REST MBO nếu chưa đặt mốc này; chỉ dùng `MAXIMO_ALLOW_FULL_SNAPSHOT=true` khi được phê duyệt rõ ràng.
5. Chạy một lần thủ công trước:

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile ingestion run --rm maximo-ingest
```

6. Chỉ sau khi chạy thành công và chủ dữ liệu phê duyệt riêng một lịch gửi credential qua HTTP nội bộ lặp lại, đặt `MAXIMO_INGEST_ENABLED=true`, recreate Airflow, và Airflow sẽ chạy pipeline mỗi 15 phút.

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile orchestration up -d --force-recreate
```

Xem lịch sử nạp dữ liệu:

```sql
select pipeline_name, status, records_read, records_loaded, started_at, error_message
from public.ingestion_audit
order by audit_id desc;
```

Chạy câu lệnh này trong database `platform_metadata`.

## 5. Transform, quality và BI

Chạy transform/test thủ công:

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile tools run --rm dbt run
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile tools run --rm dbt test
```

Superset đăng nhập tại `http://localhost:8088`. Tạo database connection tới host `postgres`, database `dwh`, user `superset_bi`, schema `mart`; dùng `mart.workorder_summary` làm dataset đầu tiên. Role `superset_bi` không được cấp quyền `raw`, `staging` hay `core`.

## 6. Trino và object storage

Trino truy vấn DWH thông qua catalog `dwh`:

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml exec trino trino --execute "select * from dwh.mart.workorder_summary order by reported_date"
```

MinIO là object storage Local Lab. Không dùng image MinIO legacy cho production; môi trường Azure phải dùng ADLS Gen2 theo `infra/azure/main.bicep`. Trước khi tạo bảng Iceberg bền vững, cần chọn và vận hành một catalog được phê duyệt (ưu tiên Iceberg REST catalog) và cấu hình object storage production.

## 7. Kiến trúc môi trường triển khai

| Lớp | Local Lab | TEST/Production |
| --- | --- | --- |
| Compute | Docker Compose một máy | Kubernetes/Container Apps được phê duyệt, autoscaling/HA |
| DWH | PostgreSQL container | PostgreSQL managed/HA, backup/restore test |
| Object storage | MinIO legacy local | ADLS Gen2 private endpoint |
| Secrets | `.env` bị gitignore | Key Vault + managed identity |
| Identity | Local-only accounts | Entra ID/Keycloak, RBAC, MFA |
| Network | localhost/Docker network | VNet, private endpoints, TLS, firewall egress |
| Observability | service logs/health endpoints | Prometheus/Grafana/Loki/Log Analytics, alerts có owner |
| Delivery | GitHub Actions validation | Image scan, ACR, IaC `what-if`, approval gates |

## 8. Azure deployment

`infra/azure/main.bicep` đã được compile local và chỉ tạo foundation: ACR, Storage, Key Vault, Log Analytics. Cần Resource Group đã được phê duyệt để chạy `what-if` và deploy.

```powershell
az deployment group what-if --resource-group <resource-group> --template-file infra/azure/main.bicep --parameters infra/azure/parameters.example.json
```

Không lưu Azure secrets, Maximo password hoặc file parameters thật trong Git.

## 9. Xử lý sự cố nhanh

| Triệu chứng | Kiểm tra/Hành động |
| --- | --- |
| `database dwh does not exist` | Chạy `postgres-migrations`, sau đó kiểm tra `docker compose ps` |
| Maximo `BMXAA0021E` / HTTP 401 | Cập nhật service-account credential hoặc API key/quyền OSLc; không bật schedule khi chưa đúng |
| Airflow health lỗi | Kiểm tra `http://localhost:8080/api/v2/monitor/health` và `docker compose logs airflow-scheduler` |
| dbt test fail | Xem output test, kiểm tra uniqueness `source_key` trong raw và valid status |
| Superset không đọc data | Đảm bảo dùng user `superset_bi`, database `dwh`, schema `mart` |
| Trino không thấy DWH | Kiểm tra `docker compose logs trino` và `show schemas from dwh` |

## 10. Quy tắc vận hành an toàn

- Không commit `.env`, private key, certificate, token, hoặc password.
- Chỉ bật Maximo schedule sau một lần manual run thành công.
- Ưu tiên HTTPS; HTTP nội bộ là ngoại lệ cần phê duyệt và phải chuyển sang TLS trước khi đưa vào môi trường dùng chung.
- Backup metadata và DWH trước khi nâng cấp image/migration; kiểm thử restore định kỳ.
- Mọi Azure deployment chạy `what-if` trước, sau đó qua approval gate.
