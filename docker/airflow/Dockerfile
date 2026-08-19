FROM apache/airflow:3.3.0-python3.12

# dbt runs inside the Airflow task process, so each DAG run is self-contained.
# Keep it in an isolated virtual environment to avoid altering Airflow's pinned
# dependency set.
USER root
RUN python -m venv /opt/dbt-venv \
    && chown -R airflow:root /opt/dbt-venv

USER airflow
RUN /opt/dbt-venv/bin/pip install --no-cache-dir \
    dbt-core==1.9.0 \
    dbt-postgres==1.9.0

ENV PATH="/opt/dbt-venv/bin:${PATH}"
