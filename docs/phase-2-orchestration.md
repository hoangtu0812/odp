# Phase 2 — Airflow orchestration

## Thành phần đã thêm

- `airflow-api-server`: UI/API tại `http://localhost:8080`.
- `airflow-scheduler`: tạo DAG run theo lịch.
- `airflow-dag-processor`: parse và đăng ký DAG.
- `airflow-init`: chạy migration cho metadata database `airflow` trước khi các service chính khởi động.
- `maximo_dbt_pipeline`: chạy `dbt build` mỗi 15 phút, retry hai lần với khoảng cách năm phút.

Airflow dùng `LocalExecutor`, phù hợp cho Local Lab. TEST/Production cần thay bằng executor và mô hình vận hành phù hợp với tải thực tế.

Khi chạy lệnh Airflow bằng `docker compose exec`, luôn gọi `bash /opt/airflow/platform-entrypoint.sh` trước subcommand Airflow. Wrapper này tạo URL kết nối metadata database từ biến PostgreSQL và xử lý đúng mật khẩu có ký tự đặc biệt.

## Ranh giới ingestion

Airflow hiện chỉ điều phối `dbt run` rồi `dbt test`. Không chạy `dbt seed` trong DAG vì seed chỉ là dữ liệu mẫu cho local. Khi có kết nối Maximo thật, ingestion phải upsert/replace có kiểm soát vào `raw.maximo_workorder`, sau đó trigger DAG này.

Khi chạy dưới Airflow, dbt ghi log và compiled artifacts vào `airflow/logs/dbt*` thay vì thư mục source dbt. Nhờ đó việc chạy trực tiếp bằng container dbt và chạy từ Airflow không tranh chấp quyền ghi trên Windows bind mount.

## Bảo mật

`SIMPLE_AUTH_MANAGER_ALL_ADMINS=true` chỉ nhằm giảm ma sát cho localhost. Trước khi chạy trên mạng dùng chung, thay bằng SSO/RBAC theo Phase 5 và thiết lập `AIRFLOW_FERNET_KEY`, `AIRFLOW_API_SECRET_KEY`, `AIRFLOW_JWT_SECRET` là các giá trị ngẫu nhiên duy nhất.
