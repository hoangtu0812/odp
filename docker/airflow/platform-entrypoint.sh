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

# Airflow 3's development-only SimpleAuthManager keeps passwords in a JSON file.
# Materialise the single local administrator on every container start so this is
# deterministic after a container is recreated, while the value remains in .env.
if [ "${AIRFLOW__CORE__SIMPLE_AUTH_MANAGER_ALL_ADMINS:-false}" != "true" ]; then
  python - <<'PY'
import json
import os

path = os.environ["AIRFLOW__CORE__SIMPLE_AUTH_MANAGER_PASSWORDS_FILE"]
username = os.environ["AIRFLOW_ADMIN_USERNAME"]
password = os.environ["AIRFLOW_ADMIN_PASSWORD"]
if not username or not password:
    raise RuntimeError("AIRFLOW_ADMIN_USERNAME and AIRFLOW_ADMIN_PASSWORD must be set")
with open(path, "w", encoding="utf-8") as handle:
    json.dump({username: password}, handle)
os.chmod(path, 0o600)
PY
fi

exec /entrypoint "$@"
