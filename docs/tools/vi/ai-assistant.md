# AI Data Assistant

[English](../ai-assistant.md)

## Dùng để làm gì?

AI Data Assistant Local Lab là semantic-query proof of concept an toàn. Nó map ý định đã cho phép sang câu SQL read-only cố định trên dữ liệu mart; không chạy SQL tự do.

## Khởi động và ví dụ

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile ai up -d --build ai-service
Invoke-RestMethod http://localhost:8010/v1/semantic-model
```

Gọi `GET /health` để health check và `GET /v1/semantic-model` để xem các câu hỏi/intent được hỗ trợ.

## Guardrail

- Chỉ SELECT được allow-list.
- Chỉ đọc curated mart, không đọc raw.
- Mở rộng cần giới hạn role, cột, số dòng, audit và bộ đánh giá trước khi đưa LLM text-to-SQL tổng quát vào.
