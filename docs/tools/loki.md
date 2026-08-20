# Loki and Alloy

## Role

Loki stores platform logs, while Grafana Alloy reads local Docker container logs and forwards them to Loki.

## Start and verify

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile observability up -d loki alloy
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml logs --tail=50 alloy
```

In Grafana, select the Loki datasource and use the Explore page. Start with a label query such as `{container=~".+"}` then narrow by service and time range.

Alloy accesses the Docker socket read-only. Treat access to that socket as privileged and restrict it in shared environments.
