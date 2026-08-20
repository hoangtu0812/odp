# Apache Superset

## Role

Superset provides governed exploration, semantic datasets, charts, and dashboards on curated warehouse data.

## Start

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile analytics up -d --build
```

Open http://localhost:8088 and sign in using the local administrator values in `.env`.

## Create a dataset

1. Add a PostgreSQL connection with host `postgres`, database `dwh`, and a dedicated BI role.
2. Register a table or view from the `mart` schema.
3. Define metric names and descriptions; prefer certified datasets for shared dashboards.
4. Build charts, arrange them on a dashboard, and apply Superset roles.

Avoid connecting dashboards directly to raw layers. Changes to Superset metadata are persisted in PostgreSQL.
