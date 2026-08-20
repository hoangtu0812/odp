"""Local orchestration for the first Maximo Work Order vertical slice."""

from datetime import datetime, timedelta

from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import DAG


with DAG(
    dag_id="maximo_dbt_pipeline",
    description="Ingest Maximo Work Orders, then build and test DWH models.",
    schedule="*/15 * * * *",
    start_date=datetime(2026, 8, 18),
    catchup=False,
    max_active_runs=1,
    default_args={"retries": 2, "retry_delay": timedelta(minutes=5)},
    tags=["maximo", "dbt", "maintenance"],
) as dag:
    maximo_ingest = BashOperator(
        task_id="ingest_maximo_workorders",
        bash_command=(
            'if [ "${MAXIMO_INGEST_ENABLED:-false}" != "true" ]; then '
            'echo "Maximo ingestion disabled; set MAXIMO_INGEST_ENABLED=true after validating HTTPS access."; '
            "exit 0; fi "
            "&& python /opt/ingestion/maximo_ingest.py"
        ),
    )

    dbt_build = BashOperator(
        task_id="dbt_build_and_test",
        bash_command=(
            "mkdir -p /opt/airflow/logs/dbt /opt/airflow/logs/dbt-target "
            "&& cd /opt/dbt "
            "&& dbt run --profiles-dir /opt/dbt "
            "--log-path /opt/airflow/logs/dbt "
            "--target-path /opt/airflow/logs/dbt-target "
            "&& dbt test --profiles-dir /opt/dbt "
            "--log-path /opt/airflow/logs/dbt "
            "--target-path /opt/airflow/logs/dbt-target"
        ),
    )

    maximo_ingest >> dbt_build
