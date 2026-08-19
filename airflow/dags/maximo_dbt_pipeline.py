"""Local orchestration for the first Maximo Work Order vertical slice."""

from datetime import datetime, timedelta

from airflow.providers.standard.operators.bash import BashOperator
from airflow.sdk import DAG


with DAG(
    dag_id="maximo_dbt_pipeline",
    description="Build and test the Maximo Work Order DWH models.",
    schedule="*/15 * * * *",
    start_date=datetime(2026, 8, 18),
    catchup=False,
    max_active_runs=1,
    default_args={"retries": 2, "retry_delay": timedelta(minutes=5)},
    tags=["maximo", "dbt", "maintenance"],
) as dag:
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

    dbt_build
