# Lộ trình triển khai Open-Source Data Platform

## 1. Mục tiêu

Xây dựng một nền tảng dữ liệu doanh nghiệp theo hướng open-source, có khả năng:

- Thu thập dữ liệu từ nhiều nguồn như SAP, Maximo, PI System, PostgreSQL, SQL Server, REST API, Excel/CSV.
- Lập lịch và điều phối pipeline dữ liệu.
- Chuẩn hóa và mô hình hóa dữ liệu phục vụ phân tích.
- Cung cấp dashboard BI và dashboard vận hành.
- Hỗ trợ Data Lake/Lakehouse khi dữ liệu tăng lớn.
- Quản lý metadata, lineage, data quality và data governance.
- Tích hợp SSO và phân quyền dữ liệu.
- Có thể mở rộng thành portal dữ liệu doanh nghiệp và Text-to-SQL/AI Data Assistant.
- Có lộ trình rõ ràng từ local test đến TEST/POC và Production.

---

## 2. Kiến trúc mục tiêu

```text
                           USERS
                             │
                      Microsoft Entra ID
                             │
                         Keycloak
                             │
                    ┌────────┴────────┐
                    │   Data Portal   │
                    └────────┬────────┘
                             │
       ┌─────────────────────┼─────────────────────┐
       │                     │                     │
       ▼                     ▼                     ▼
    Airbyte                Airflow              Superset
   Ingestion            Orchestration             BI
       │                     │                     │
       └──────────┐          │                     │
                  ▼          ▼                     │
                        dbt                        │
                  Transformation                  │
                       │                          │
                       ▼                          │
          ┌────────────┴────────────┐             │
          │                         │             │
          ▼                         ▼             │
    PostgreSQL DWH             Object Storage     │
                             + Iceberg            │
          │                         │             │
          └────────────┬────────────┘             │
                       ▼                          │
                     Trino ◄──────────────────────┘
                       │
          ┌────────────┼────────────┐
          ▼            ▼            ▼
       Superset      Jupyter     Text-to-Data

OpenMetadata ───────────────── Data Catalog / Lineage
Grafana + Prometheus + Loki ── Monitoring
OPA/OPAL ───────────────────── Policy / Authorization
```

Nguồn dữ liệu dự kiến:

```text
SAP
Maximo
PI System
PostgreSQL
SQL Server
REST APIs
Excel / CSV
Application DB
```

---

## 3. Nguyên tắc triển khai

Không nên triển khai toàn bộ hệ sinh thái ngay từ đầu.

Lộ trình nên chia theo các giai đoạn:

```text
Phase 0   Local Lab
Phase 1   Data Warehouse MVP
Phase 2   ETL/ELT + Orchestration
Phase 3   BI + Monitoring
Phase 4   Lakehouse + Trino
Phase 5   Governance + SSO + Security
Phase 6   Portal + AI/Text-to-SQL
Phase 7   Production HA
```

Mỗi phase phải tạo ra một vertical slice sử dụng được trước khi chuyển sang phase tiếp theo.

---

# PHASE 0 — LOCAL LAB

## 4. Mục tiêu Local Lab

Dựng pipeline tối thiểu trên máy cá nhân:

```text
CSV / API / PostgreSQL
          ↓
       Airbyte
          ↓
     PostgreSQL
          ↓
         dbt
          ↓
      Superset
```

Sau khi pipeline trên chạy ổn mới thêm Airflow.

## 5. Cấu hình máy local

### Tối thiểu

```text
CPU: 8 core
RAM: 16 GB
Disk trống: 100 GB
```

### Khuyến nghị

```text
CPU: 12–16 core
RAM: 32 GB
SSD trống: 200 GB+
```

### Nếu dùng Windows

Khuyến nghị:

```text
Windows
  ↓
WSL2 Ubuntu
  ↓
Docker Desktop hoặc Docker Engine
```

Nên lưu source code bên trong filesystem của WSL để tránh I/O chậm do bind mount từ Windows.

---

## 6. Cấu trúc repository

```text
bsr-data-platform/
│
├── docker/
│   ├── postgres/
│   ├── airflow/
│   ├── superset/
│   ├── grafana/
│   └── ...
│
├── airflow/
│   └── dags/
│
├── dbt/
│   └── bsr_analytics/
│
├── ingestion/
│   ├── maximo/
│   ├── sap/
│   └── pi/
│
├── superset/
├── grafana/
│
├── sql/
│   ├── init/
│   └── migrations/
│
├── infra/
│   ├── docker-compose/
│   └── kubernetes/
│
├── docs/
│
├── .env.example
└── README.md
```

Không commit các file sau:

```text
.env
secrets/
certificates/
private keys
password files
```

---

# PHASE 1 — DATA WAREHOUSE MVP

## 7. Triển khai PostgreSQL

Local chỉ cần một PostgreSQL container.

Nên tách database/schema:

```text
platform_metadata
airflow
superset

dwh
├── raw
├── staging
├── core
└── mart
```

Luồng dữ liệu chuẩn:

```text
raw
 ↓
staging
 ↓
core
 ↓
mart
```

Ví dụ:

```text
raw.maximo_workorder
raw.sap_purchase_order

        ↓ dbt

staging.stg_maximo_workorder
staging.stg_sap_purchase_order

        ↓

core.fact_work_order
core.dim_equipment
core.dim_department

        ↓

mart.maintenance_kpi
mart.procurement_kpi
```

Không nên để Superset query trực tiếp bảng raw.

---

## 8. Use case đầu tiên

Nên chọn một use case đơn giản nhưng có giá trị thực tế, ví dụ Maximo Work Order.

```text
Maximo API
    ↓
Airbyte / custom connector
    ↓
raw.maximo_workorder
    ↓
dbt
    ↓
core.fact_work_order
    ↓
mart.workorder_summary
    ↓
Superset
```

Dashboard đầu tiên:

- Total Work Orders
- Completed
- In Progress
- Overdue
- WO theo Area
- WO theo Equipment
- WO theo Department
- WO Trend theo thời gian

---

## 9. Triển khai dbt

Cấu trúc:

```text
dbt/bsr_analytics/

models/
├── staging/
│   ├── maximo/
│   ├── sap/
│   └── pi/
│
├── core/
│   ├── dim_equipment.sql
│   ├── dim_department.sql
│   └── fact_work_order.sql
│
└── marts/
    ├── maintenance/
    ├── procurement/
    └── management/
```

Pipeline cơ bản:

```bash
dbt deps
dbt seed
dbt run
dbt test
```

Mỗi model quan trọng nên có test:

```text
not_null
unique
relationships
accepted_values
```

Ví dụ:

```text
fact_work_order.wo_number

not_null = true
unique   = true
```

---

# PHASE 2 — DATA INGESTION VÀ ORCHESTRATION

## 10. Triển khai Airbyte

Airbyte đảm nhiệm data ingestion:

```text
Source
   ↓
Connector
   ↓
Destination
```

Ví dụ:

```text
Maximo REST API
        ↓
     Airbyte
        ↓
raw.maximo_workorder
```

Nguồn DB phổ biến có thể gồm:

```text
PostgreSQL
SQL Server
MySQL
Oracle
REST API
```

SAP, PI và Maximo có thể cần custom connector tùy API thực tế.

---

## 11. Triển khai Airflow

Sau khi Airbyte và dbt hoạt động độc lập, dùng Airflow để điều phối.

Ví dụ DAG:

```text
             DAG_MAXIMO_DAILY

                    START
                      │
                      ▼
               Trigger Airbyte
                      │
                      ▼
                Check Sync
                      │
                      ▼
                   dbt run
                      │
                      ▼
                  dbt test
                      │
              ┌───────┴───────┐
              ▼               ▼
           Success          Failed
              │               │
              ▼               ▼
        Update audit      Send alert
```

Ví dụ lịch chạy:

```text
Maximo        mỗi 15 phút
SAP master    mỗi 1 giờ
SAP finance   mỗi đêm
PI            tùy use case
```

---

## 12. Local Full Stack

Sau Phase 2, local có thể gồm:

```text
Docker
│
├── PostgreSQL
│
├── Redis
│
├── Airflow
│   ├── web/api server
│   ├── scheduler
│   └── worker
│
├── Airbyte
│
├── Superset
│
├── Grafana
│
└── Prometheus
```

Chưa cần bật cùng lúc:

```text
Trino
Object Storage
OpenMetadata
OPA
Keycloak
```

nếu laptop không đủ RAM.

---

# PHASE 3 — BI VÀ MONITORING

## 13. Apache Superset

Superset là nền tảng BI chính.

Use case:

```text
Management BI
Business Analysis
Ad-hoc Query
Dashboard
Drill-down
Filter
```

MVP kết nối trực tiếp:

```text
Superset
    ↓
PostgreSQL DWH
```

Dashboard đề xuất:

```text
01 Executive Overview
02 Maintenance
03 Turnaround
04 Procurement
05 Operation
```

---

## 14. Grafana

Grafana dùng cho observability và operational monitoring.

Stack:

```text
Grafana
Prometheus
Loki
```

Theo dõi:

```text
Airflow
Airbyte
PostgreSQL
Superset
VM
Docker
API
```

Dashboard gợi ý:

### Infrastructure

- CPU
- RAM
- Disk
- Network
- Container health

### Airflow

- DAG success rate
- DAG duration
- Failed task
- Retry count

### PostgreSQL

- Connections
- Query latency
- Locks
- Database size

### Applications

- HTTP request
- Error rate
- HTTP 5xx
- Latency
- Logs

---

# PHASE 4 — TEST / POC

## 15. Số lượng VM cho TEST

Khuyến nghị 3 VM.

### VM01 — DATA-APP

```text
8–12 vCPU
32 GB RAM
200 GB disk
```

Chạy:

```text
Airflow
Airbyte
Superset
Grafana
Prometheus
Loki
Keycloak sau này
```

### VM02 — DATA-DB

```text
8 vCPU
32 GB RAM
500 GB+ SSD
```

Chạy:

```text
PostgreSQL

platform metadata
Airflow metadata
Superset metadata
DWH
```

Ưu tiên IOPS cho VM này.

### VM03 — DATA-LAKE

```text
12–16 vCPU
64 GB RAM
2–4 TB storage
```

Chạy:

```text
S3-compatible Object Storage
Trino
Iceberg catalog/lakehouse components
```

VM03 có thể chưa cần ở giai đoạn POC đầu.

POC tối thiểu có thể bắt đầu bằng 2 VM:

```text
VM01 Application
VM02 Database
```

---

## 16. Sơ đồ TEST

```text
                        Users
                          │
                       HTTPS
                          │
                     Reverse Proxy
                          │
            ┌─────────────┴────────────┐
            │                          │
         VM01                        VM02
       DATA-APP                     DATA-DB
            │                          │
 Airflow                           PostgreSQL
 Airbyte                              │
 Superset                             │
 Grafana ─────────────────────────────┘
 Prometheus
            │
            │
            ▼
           VM03
        DATA-LAKE

      Object Storage
          Trino
```

---

## 17. Reverse Proxy và TLS

Không expose trực tiếp nhiều port cho user:

```text
:3000 Grafana
:8080 Airflow
:8088 Superset
...
```

Nên dùng:

```text
https://data-test.company.vn/
https://bi-test.company.vn/
https://airflow-test.company.vn/
https://grafana-test.company.vn/
```

Nginx hoặc Ingress chịu trách nhiệm TLS termination.

Không expose ra user network:

```text
PostgreSQL
Redis
Object Storage internal API
internal service ports
```

---

# PHASE 5 — LAKEHOUSE VÀ TRINO

## 18. Khi nào cần Lakehouse

Chỉ nên thêm khi xuất hiện:

```text
PI historical data
Logs
Parquet
CSV lớn
Time-series
Hàng trăm GB đến TB dữ liệu
```

Kiến trúc:

```text
Object Storage
       +
Apache Iceberg
       +
Trino
```

Không nên chỉ lưu các file Parquet rời rạc nếu muốn xây lakehouse enterprise.

---

## 19. Cấu trúc Object Storage

```text
s3://data-platform/

raw/
├── sap/
├── maximo/
├── pi/
└── apps/

bronze/
silver/
gold/
```

Có thể dùng convention:

```text
raw      = dữ liệu gốc
bronze   = dữ liệu chuẩn hóa sơ bộ
silver   = dữ liệu clean/integrated
gold     = dữ liệu business-ready
```

---

## 20. Trino

Kiến trúc:

```text
Superset
    │
    ▼
   Trino
    │
 ┌──┴────────────┐
 ↓               ↓
PostgreSQL     Iceberg
                  │
            Object Storage
```

POC:

```text
1 coordinator
1 worker
```

Production:

```text
1 coordinator
3+ workers
```

---

# PHASE 6 — GOVERNANCE, SSO, SECURITY

## 21. OpenMetadata

Triển khai khi số lượng data source và pipeline bắt đầu tăng.

Ví dụ ngưỡng tham khảo:

```text
10+ nguồn dữ liệu
100+ tables
20+ pipeline
```

Ingest metadata từ:

```text
PostgreSQL
Airflow
dbt
Superset
Trino
```

Mục tiêu lineage:

```text
Maximo
 ↓
Airbyte
 ↓
raw.workorder
 ↓
dbt
 ↓
fact_work_order
 ↓
mart_maintenance
 ↓
Superset
 ↓
Maintenance Dashboard
```

OpenMetadata dùng cho:

- Data catalog
- Owner
- Description
- Tag
- Classification
- Lineage
- Data quality
- Discovery

---

## 22. Authentication

Khuyến nghị tận dụng Microsoft Entra ID.

Luồng:

```text
Microsoft Entra ID
        │
       OIDC
        ▼
     Keycloak
        │
  ┌─────┼─────┐
  ▼     ▼     ▼
Airflow Superset Grafana
```

Một số ứng dụng có thể tích hợp Entra ID trực tiếp nếu phù hợp.

Không dùng cấu hình development của Keycloak trong production.

---

## 23. Phân quyền dữ liệu

Hierarchy:

```text
User
 ↓
Entra Group
 ↓
Platform Role
 ↓
Data Domain
 ↓
Plant
 ↓
Area
```

Ví dụ:

```text
User A

role:
analyst

domain:
maintenance

plant:
DQ

areas:
A
B
```

Phân quyền phải có hai tầng:

```text
Application Permission
+
Data Permission
```

Không chỉ giới hạn quyền mở dashboard mà phải enforce dữ liệu được phép đọc.

Ví dụ:

```text
User Maintenance Area A
      ↓
chỉ được đọc
      ↓
Maintenance + Area A
```

Có thể dùng:

- Superset RLS
- PostgreSQL RLS
- Trino access control
- OPA/OPAL nếu cần policy tập trung

---

# PHASE 7 — PORTAL

## 24. Data Platform Portal

Portal nên triển khai sau khi các component phía dưới ổn định.

Stack có thể:

```text
React
+
Go
```

Giao diện:

```text
┌──────────────────────────────────────────┐
│              DATA PLATFORM               │
│                                          │
│ [Ingestion]     [Storage]                │
│ Airbyte         Object Storage           │
│                                          │
│ [Transform]     [Orchestrator]           │
│ dbt             Airflow                  │
│                                          │
│ [Query]         [Governance]             │
│ Trino           OpenMetadata             │
│                                          │
│ [BI]            [Monitoring]             │
│ Superset        Grafana                  │
│                                          │
│ [SQL Studio]    [AI Data Assistant]      │
└──────────────────────────────────────────┘
```

### Portal V1

Chỉ cần:

```text
SSO
Role filtering
App launcher
Health status
```

### Portal V2

Có thể tích hợp:

```text
Airflow API
Airbyte API
Superset API
OpenMetadata API
Trino API
Grafana API
```

Không nên rewrite toàn bộ UI của các sản phẩm ở giai đoạn đầu.

---

# PHASE 8 — TEXT-TO-SQL / AI DATA ASSISTANT

## 25. Kiến trúc AI

```text
User
 ↓
"Cho tôi top 10 thiết bị có maintenance cost
 cao nhất trong TA gần nhất"
 ↓
LLM
 ↓
Semantic Metadata
 ↓
Generate SQL
 ↓
Authorization
 ↓
Trino
 ↓
Query
 ↓
Result + Chart
```

Nguyên tắc quan trọng:

```text
LLM KHÔNG quyết định quyền truy cập dữ liệu.
```

Data permission phải được enforce ở database/query/policy layer.

---

# 26. CI/CD

Tất cả configuration phải được quản lý bằng Git.

```text
Azure DevOps
      │
      ├── validate
      ├── test
      ├── build
      ├── image scan
      ├── push registry
      │
      ▼
     TEST
      │
    approve
      ▼
     PROD
```

Airflow DAG:

```text
Git
 ↓
CI/CD
 ↓
Server
```

dbt:

```text
Git
 ↓
dbt test
 ↓
deploy
```

Không chỉnh sửa trực tiếp DAG hoặc source bằng `nano` trên production server.

---

## 27. Container Registry

Trong môi trường hạn chế Internet:

```text
Internet-enabled build environment
             │
             ▼
             ACR
             │
             ▼
       Internal Servers
```

Mirror toàn bộ image:

```text
Airflow
Airbyte
Superset
Trino
Grafana
PostgreSQL
Redis
OpenMetadata
Keycloak
```

Không sử dụng tag:

```text
latest
```

Production phải pin version cụ thể.

---

# 28. Backup và Disaster Recovery

## PostgreSQL

```text
daily backup
retention 30 days
off-host copy
restore test định kỳ
```

## Object Storage

```text
versioning
replication
off-site backup nếu cần
```

## Configuration

```text
Git repository
```

## Airflow DAG

```text
Git repository
```

## dbt

```text
Git repository
```

Nguyên tắc:

> Backup chưa đủ. Phải kiểm tra restore định kỳ.

---

# 29. Production Sizing

## Mức A — POC / nội bộ nhỏ: 2 VM

### VM01 — Application

```text
16 CPU
64 GB RAM
```

### VM02 — Database

```text
8 CPU
32 GB RAM
```

Phù hợp:

```text
5–20 users
vài nguồn dữ liệu
dưới vài trăm GB
```

Không HA.

---

## Mức B — Production ban đầu: 5 VM

### VM01 — Platform

```text
8–16 CPU
32 GB RAM

Airflow
Airbyte
Keycloak
Portal
```

### VM02 — BI / Governance

```text
8–16 CPU
32 GB RAM

Superset
Grafana
OpenMetadata
```

### VM03 — Database

```text
8–16 CPU
64 GB RAM

PostgreSQL
```

### VM04 — Query

```text
16 CPU
64 GB RAM

Trino Coordinator
Trino Worker
```

### VM05 — Storage

```text
8 CPU
32 GB RAM
large storage

Object Storage
```

Đây là mô hình separation tốt nhưng chưa phải full HA.

---

## Mức C — Production HA

```text
                  Load Balancer
                       │
                Kubernetes Cluster

      Node01        Node02        Node03
     Control/       Control/      Control/
      Worker         Worker        Worker
        │              │             │
        └──────────────┼─────────────┘
                       │
              Application Workloads
```

Có thể cần:

```text
3 Kubernetes nodes
2 PostgreSQL nodes + witness
3 Object Storage nodes hoặc external storage
```

Tổng quy mô:

```text
6–8 VM/server
```

---

# 30. Không nên dùng Kubernetes ngay từ đầu

Lộ trình khuyến nghị:

```text
LOCAL
Docker Compose
    │
    ▼
TEST
Docker Compose / Containers
2–3 VM
    │
    ▼
PROD V1
Containers
5 VM
    │
    ▼
PROD V2
Kubernetes
6–8 nodes/VM
```

Lợi ích:

Team tập trung học và vận hành tốt:

```text
Airbyte
Airflow
dbt
Trino
Superset
OpenMetadata
```

trước khi thêm độ phức tạp của:

```text
Kubernetes
Helm
Ingress
PV/PVC
CSI
Operators
Secrets
NetworkPolicy
```

---

# 31. Kế hoạch triển khai theo tuần

## Week 1

```text
Git repository
Docker environment
PostgreSQL
raw/staging/core/mart
```

## Week 2

```text
Maximo ingestion
raw tables
validation
```

## Week 3

```text
dbt
fact/dimension
dbt tests
```

## Week 4

```text
Superset
Maintenance Dashboard
```

## Week 5

```text
Airflow
Scheduling
Retry
Notification
```

## Week 6

```text
Grafana
Prometheus
Loki
```

## Week 7

```text
Move to TEST VM
Reverse Proxy
TLS
CI/CD
```

## Week 8

```text
SAP source
Second Data Mart
```

## Week 9

```text
Object Storage
Iceberg
Trino
```

## Week 10

```text
PI historical data
Query through Trino
```

## Week 11

```text
OpenMetadata
Lineage
Catalog
```

## Week 12

```text
Entra ID
Keycloak
RBAC
```

## Week 13+

```text
RLS
Policy
Portal
Text-to-SQL
AI Data Assistant
```

---

# 32. Acceptance Criteria cho MVP

Không đánh giá MVP theo tiêu chí:

```text
Airflow đã cài xong
Superset đã chạy
Airbyte mở được UI
```

Mà phải kiểm tra end-to-end:

```text
① Maximo có Work Order mới

        ↓

② Airbyte lấy dữ liệu về

        ↓

③ Airflow schedule pipeline

        ↓

④ raw data lưu thành công

        ↓

⑤ dbt transform

        ↓

⑥ dbt tests pass

        ↓

⑦ Dashboard Superset cập nhật

        ↓

⑧ Grafana giám sát pipeline

        ↓

⑨ User đăng nhập bằng SSO

        ↓

⑩ User chỉ xem được dữ liệu được phân quyền
```

Đạt đủ vertical slice này mới nên mở rộng.

---

# 33. Kiến trúc giai đoạn đầu nên chốt

```text
                    TEST PLATFORM

SAP ───────┐
Maximo ────┼─────→ Airbyte
App DB ────┘          │
                      ▼
                   Airflow
                      │
                      ▼
                  PostgreSQL
                raw / staging
                      │
                      ▼
                     dbt
                      │
                      ▼
                  core / mart
                      │
             ┌────────┴─────────┐
             ▼                  ▼
         Superset             Grafana
             │                  │
            BI              Monitoring
```

Chỉ cần 2 VM để chứng minh concept:

```text
VM01 Application
VM02 Database
```

Sau đó bổ sung:

```text
VM03
Object Storage
Iceberg
Trino
```

Khi platform mở rộng:

```text
OpenMetadata
Keycloak
OPA/OPAL
Portal
Text-to-SQL
Kubernetes
```

---

# 34. Kết luận

Không nên cố triển khai một platform có đầy đủ logo ngay từ ngày đầu.

Thứ tự ưu tiên nên là:

```text
1. Data source thật
2. Pipeline thật
3. Data model thật
4. Dashboard thật
5. Monitoring
6. Security
7. Governance
8. Lakehouse
9. Portal
10. AI
```

Platform chỉ thực sự có giá trị khi một luồng dữ liệu nghiệp vụ có thể chạy end-to-end một cách ổn định, kiểm soát được, có phân quyền, có lineage và có dashboard sử dụng thực tế.
