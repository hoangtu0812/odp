# Kubernetes local cho LDL

Xem [hướng dẫn triển khai Kubernetes](../../infra/kubernetes/README.md) để
biết điều kiện cần, version matrix, bootstrap và teardown. Kubernetes là mode
độc lập với Docker Compose và sử dụng data journey Maximo:

```text
Maximo → raw.maximo_workorder → Airflow → dbt maintenance marts
       → Trino / Superset / OpenMetadata / AI Assistant
```

Dùng `scripts/k8s-up.ps1`, `scripts/k8s-status.ps1`,
`scripts/k8s-smoke-test.ps1` và `scripts/k8s-down.ps1`; không script nào gọi
Docker Compose hoặc tạo cluster Airbyte thứ hai.
