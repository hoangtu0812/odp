# LDL Maximo maintenance demo

This is the LDL reference data journey. It uses the repository's existing
Maximo work-order connector, dbt maintenance models and Airflow deployment;
it does not introduce an unrelated sample business domain.

## Deterministic fixture

```powershell
python .\examples\maximo\generate_fixture.py --workorders 10000 --seed 42
```

The generator produces `examples/maximo/generated/workorders.json`, which is
ignored by Git. It is consumed by the same normalizer used for the live Maximo
OSLc/REST MBO APIs, so a local test exercises actual ingestion logic.

## Data products

| Product | Dataset | Consumer |
| --- | --- | --- |
| Maintenance operations | `mart.workorder_summary` | Superset, AI Assistant |
| Work-order facts | `core.fact_work_order` | Trino and governed SQL users |
| Equipment and department dimensions | `core.dim_equipment`, `core.dim_department` | dbt and governed SQL users |

The live source remains Maximo. Configure `MAXIMO_*` variables for a
validated HTTPS endpoint. The fixture mode is local-demo-only and remains
visible in `platform_metadata.ingestion_audit`.
