FROM apache/superset:6.0.0

USER root
RUN pip install --no-cache-dir --target=/app/.venv/lib/python3.10/site-packages psycopg2-binary==2.9.10
USER superset
