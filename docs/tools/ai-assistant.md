# AI Data Assistant

## Role

The Local Lab AI service is a guarded semantic-query proof of concept. It maps approved question intents to a fixed, read-only query set over curated mart data; it does not execute arbitrary SQL or expose raw credentials to users.

## Start and test

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile ai up -d --build ai-service
Invoke-WebRequest http://localhost:8010/health -UseBasicParsing
```

Review the semantic model:

```powershell
Invoke-RestMethod http://localhost:8010/v1/semantic-model
```

## Guardrails

- Queries are allow-listed and read-only.
- Data comes from curated marts rather than raw source tables.
- Add intent, column, row-count, and role constraints before expanding functionality.
- A general LLM text-to-SQL capability requires separate model, privacy, approval, evaluation, and audit design; it is not enabled by this Local Lab service.
