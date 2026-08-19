#!/usr/bin/env bash
set -euo pipefail

# Build the SQLAlchemy URL here rather than in Compose, so a PostgreSQL password
# containing characters such as @, :, /, or # is escaped correctly.
export AIRFLOW__DATABASE__SQL_ALCHEMY_CONN="$({
  python - <<'PY'
import os
from urllib.parse import quote_plus

user = quote_plus(os.environ["POSTGRES_USER"])
password = quote_plus(os.environ["POSTGRES_PASSWORD"])
host = os.environ.get("POSTGRES_HOST", "postgres")
port = os.environ.get("POSTGRES_PORT_INTERNAL", "5432")
database = os.environ.get("AIRFLOW_METADATA_DATABASE", "airflow")
print(f"postgresql+psycopg2://{user}:{password}@{host}:{port}/{database}")
PY
} )"

exec /entrypoint "$@"
