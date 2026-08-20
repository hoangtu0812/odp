# Grafana

## Role

Grafana is the visual operations console for Prometheus metrics and Loki logs.

## Start and use

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile observability up -d grafana
```

Open http://localhost:3001 and sign in using `GRAFANA_ADMIN_USER` and `GRAFANA_ADMIN_PASSWORD` from `.env`.

Prometheus and Loki are provisioned datasources. Build dashboards with service availability, database health, pipeline latency, and log links. Keep dashboards as files when practical so they can be reviewed with code.
