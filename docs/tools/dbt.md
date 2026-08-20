# dbt

## Role

dbt turns landed data into tested, documented warehouse models. The project lives in `dbt/bsr_analytics`; its model layering is raw → staging → core → mart.

## Run

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile tools run --rm dbt debug
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile tools run --rm dbt run
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile tools run --rm dbt test
```

## Development workflow

1. Create or revise a model in `models/` and declare its tests in YAML.
2. Run `dbt build --select <model>+` before merging.
3. Keep test failures as delivery blockers unless the data owner explicitly accepts an exception.
4. Build documentation locally with `dbt docs generate` when model metadata changes.

Seeds are disabled by default so development samples cannot accidentally enter a real pipeline.
