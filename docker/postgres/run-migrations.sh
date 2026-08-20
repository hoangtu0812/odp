#!/usr/bin/env bash
set -euo pipefail

export PGPASSWORD="${POSTGRES_PASSWORD}"
export PGHOST="${PGHOST:-postgres}"
export PGPORT="${PGPORT:-5432}"
export PGUSER="${POSTGRES_USER}"
superset_password="${SUPERSET_DWH_PASSWORD:-${POSTGRES_PASSWORD}}"

for migration in /migrations/*.sql; do
  [ -e "$migration" ] || continue
  case "$(basename "$migration")" in
    001_dwh_*) export PGDATABASE=dwh ;;
    002_platform_*) export PGDATABASE=platform_metadata ;;
    003_data_access_*) export PGDATABASE=dwh ;;
    *) echo "No target database configured for $(basename "$migration")" >&2; exit 1 ;;
  esac
  echo "Applying $(basename "$migration")"
  psql --set ON_ERROR_STOP=1 --set "superset_password=${superset_password}" --file "$migration"
done
