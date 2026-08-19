# Baseline Phase 0–1

## Mục tiêu hoàn thành

1. PostgreSQL chạy trong Docker với các database `platform_metadata`, `airflow`, `superset` và `dwh`.
2. DWH có bốn schema: `raw`, `staging`, `core`, `mart`.
3. dbt build thành công với dữ liệu Work Order mẫu.
4. `mart.workorder_summary` sẵn sàng làm dataset đầu tiên cho Superset.

## Quy ước dữ liệu

| Lớp | Mục đích | Quyền BI |
| --- | --- | --- |
| `raw` | Dữ liệu landing, giữ gần nguồn nhất có thể | Không cấp |
| `staging` | Làm sạch và ép kiểu, giữ cấu trúc nguồn | Không cấp |
| `core` | Dimension/fact dùng chung | Hạn chế |
| `mart` | KPI/dataset phục vụ nghiệp vụ | Đọc |

## Bước tiếp theo

Thay seed `maximo_workorder.csv` bằng một ingestion thật vào `raw.maximo_workorder`; giữ nguyên hợp đồng cột để các mô hình dbt không phải thay đổi.
