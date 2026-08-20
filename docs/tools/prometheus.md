# Prometheus

## Role

Prometheus scrapes platform metrics, evaluates alert rules, and provides the metrics datasource for Grafana.

## Start and use

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile observability up -d prometheus blackbox-exporter postgres-exporter alertmanager
```

Open http://localhost:9090. Use **Status → Targets** to confirm scrape health, then query a metric in the expression browser.

## Operations

- Scrape targets and rule files are under `docker/prometheus/`.
- Add a service health endpoint before adding a blackbox probe.
- Alertmanager uses a local no-op receiver by design. Configure a controlled notification receiver only after ownership and escalation policy are agreed.
- Validate rules and target labels whenever a service name changes.
