"""Validated Maximo work-order data-product orchestration."""

from datetime import datetime, timedelta

from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import DAG


with DAG(
    dag_id="maximo_dbt_pipeline",
    description="Ingest Maximo work orders, validate the raw contract and publish tested maintenance marts.",
    schedule="*/15 * * * *",
    start_date=datetime(2026, 8, 18),
    catchup=False,
    max_active_runs=1,
    default_args={"retries": 2, "retry_delay": timedelta(minutes=5)},
    tags=["maximo", "dbt", "maintenance"],
) as dag:
    check_source = BashOperator(
        task_id="check_source",
        bash_command=(
            'if [ -n "${MAXIMO_FIXTURE_PATH:-}" ]; then test -r "$MAXIMO_FIXTURE_PATH"; '
            'elif [ "${MAXIMO_INGEST_ENABLED:-false}" = "true" ]; then test -n "${MAXIMO_BASE_URL:-}"; '
            'else echo "Set MAXIMO_FIXTURE_PATH for local demo or MAXIMO_INGEST_ENABLED=true for live Maximo."; exit 1; fi'
        ),
    )
    maximo_ingest = BashOperator(
        task_id="ingest_maximo_workorders",
        bash_command=(
            'if [ -n "${MAXIMO_FIXTURE_PATH:-}" ]; then '
            'python /opt/ingestion/maximo_ingest.py --fixture "$MAXIMO_FIXTURE_PATH"; '
            'elif [ "${MAXIMO_INGEST_ENABLED:-false}" = "true" ]; then '
            'python /opt/ingestion/maximo_ingest.py; '
            'else echo "No Maximo source configured"; exit 1; fi'
        ),
    )

    validate_raw_data = BashOperator(
        task_id="validate_raw_data",
        bash_command="/opt/dbt-venv/bin/python /opt/ingestion/maximo-demo/airflow/validate_raw.py",
    )

    dbt_run_staging_core = BashOperator(
        task_id="dbt_run_staging_core",
        bash_command=(
            "mkdir -p /opt/airflow/logs/dbt /opt/airflow/logs/dbt-target "
            "&& cd /opt/dbt "
            "&& dbt run --select staging.maximo core --profiles-dir /opt/dbt "
            "--log-path /opt/airflow/logs/dbt "
            "--target-path /opt/airflow/logs/dbt-target"
        ),
    )
    dbt_test_staging_core = BashOperator(
        task_id="dbt_test_staging_core",
        bash_command=(
            "mkdir -p /opt/airflow/logs/dbt /opt/airflow/logs/dbt-target && cd /opt/dbt "
            "&& dbt test --select staging.maximo core --profiles-dir /opt/dbt "
            "--log-path /opt/airflow/logs/dbt "
            "--target-path /opt/airflow/logs/dbt-target"
        ),
    )
    dbt_run_marts = BashOperator(
        task_id="dbt_run_marts",
        bash_command=(
            "mkdir -p /opt/airflow/logs/dbt /opt/airflow/logs/dbt-target && cd /opt/dbt "
            "&& dbt run --select marts.maintenance --profiles-dir /opt/dbt "
            "--log-path /opt/airflow/logs/dbt "
            "--target-path /opt/airflow/logs/dbt-target"
        ),
    )
    dbt_test_marts = BashOperator(
        task_id="dbt_test_marts",
        bash_command=(
            "mkdir -p /opt/airflow/logs/dbt /opt/airflow/logs/dbt-target && cd /opt/dbt "
            "&& dbt test --select marts.maintenance --profiles-dir /opt/dbt "
            "--log-path /opt/airflow/logs/dbt "
            "--target-path /opt/airflow/logs/dbt-target"
        ),
    )
    refresh_metadata = BashOperator(
        task_id="refresh_metadata",
        bash_command="if [ -z \"${OPENMETADATA_INGESTION_TRIGGER_URL:-}\" ]; then echo 'OpenMetadata refresh is not configured for this environment.'; else curl --fail --silent --show-error -X POST \"$OPENMETADATA_INGESTION_TRIGGER_URL\"; fi",
    )
    publish_metrics = BashOperator(
        task_id="publish_metrics",
        bash_command="echo 'Maximo ingestion audit and Airflow task metrics are available to Prometheus/Grafana.'",
    )

    check_source >> maximo_ingest >> validate_raw_data >> dbt_run_staging_core >> dbt_test_staging_core >> dbt_run_marts >> dbt_test_marts >> refresh_metadata >> publish_metrics
