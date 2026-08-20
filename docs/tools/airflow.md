# Apache Airflow

## Role

Airflow orchestrates platform workflows: dependency order, retries, schedules, run history, and task logs. DAG source files are in `airflow/dags/`.

## Start and use

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile orchestration up -d --build
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml exec airflow-api-server `
  bash /opt/airflow/platform-entrypoint.sh dags list
```

Open http://localhost:8080 to inspect DAGs, trigger a run, view task logs, or mark an approved remediation task.

## Operations

- Keep source-side scheduled ingestion disabled until a source owner approves the credentials, transport, schedule, and load window.
- Make every task idempotent; reruns must not silently duplicate facts.
- Put connection settings in environment variables or a secret manager, not DAG code.
- Check import errors first when a DAG is missing:

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml exec airflow-api-server `
  bash /opt/airflow/platform-entrypoint.sh dags list-import-errors
```
