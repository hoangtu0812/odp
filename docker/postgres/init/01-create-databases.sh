#!/usr/bin/env bash
set -euo pipefail

create_database() {
  local database_name="$1"
  if ! psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" --tuples-only --no-align \
    --command "SELECT 1 FROM pg_database WHERE datname = '${database_name}'" | grep -q 1; then
    psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" --command "CREATE DATABASE ${database_name}"
  fi
}

create_database platform_metadata
create_database airflow
create_database superset
create_database dwh

psql --username "$POSTGRES_USER" --dbname dwh <<'SQL'
CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS mart;

COMMENT ON SCHEMA raw IS 'Immutable landing area for source-system data.';
COMMENT ON SCHEMA staging IS 'Cleaned and typed source-aligned models.';
COMMENT ON SCHEMA core IS 'Conformed business entities and facts.';
COMMENT ON SCHEMA mart IS 'Business-ready analytics models for BI tools.';
SQL
