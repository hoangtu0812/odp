# PostgreSQL warehouse

## Role

PostgreSQL is the transactional warehouse store for platform metadata and modeled data. The `dwh` database contains layered schemas, while versioned SQL files in `sql/migrations/` make changes repeatable.

## Start and verify

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml up -d postgres postgres-migrations
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml exec postgres `
  psql -U platform_admin -d dwh -c "select current_database(), now();"
```

## Daily use

- Add schema or role changes as a new, ordered file under `sql/migrations/`; do not edit an applied migration.
- Use `raw`, `staging`, `core`, and `mart` as data layers. Publish consumption-ready datasets from `mart`.
- Use dedicated least-privilege roles for tools. The BI role is restricted to the mart layer and row-level access policy.

## Troubleshooting

If `dwh` does not exist after an interrupted first initialization, run `bash /docker-entrypoint-initdb.d/01-create-databases.sh` inside the `postgres` container, then restart `postgres-migrations`. Do not remove the volume as a first response.
