# Open Policy Agent (OPA)

[English](../opa.md)

## Dùng để làm gì?

OPA tách luật phân quyền ra khỏi ứng dụng. Rules ở `opa/policies/platform.rego` nhận role, action và data area để trả về quyết định allow/deny.

## Chạy và ví dụ

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile governance up -d opa
Invoke-RestMethod -Method Post -ContentType 'application/json' -Uri http://localhost:8182/v1/data/platform/authz/allow -Body '{"input":{"role":"maintenance_analyst","action":"read","area":"A"}}'
```

Ứng dụng/gateway phải truyền claim đã xác thực cho OPA, thực thi kết quả trả về và log lần từ chối. Không tin role do browser tự gửi.
