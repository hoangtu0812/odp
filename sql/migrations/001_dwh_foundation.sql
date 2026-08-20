-- DWH foundation shared by custom ingestion, dbt and BI. This migration is
-- idempotent so it can be run safely by the local migration service.

CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS mart;

CREATE TABLE IF NOT EXISTS raw.maximo_workorder (
    source_key text PRIMARY KEY,
    wo_number text NOT NULL,
    description text,
    status text,
    area text,
    equipment_code text,
    department_code text,
    site_id text,
    reported_at timestamptz,
    target_finish_at timestamptz,
    actual_finish_at timestamptz,
    estimated_cost numeric(18, 2),
    source_updated_at timestamptz,
    ingested_at timestamptz NOT NULL DEFAULT now(),
    source_hash text NOT NULL,
    source_payload jsonb NOT NULL DEFAULT '{}'::jsonb
);

-- Earlier local demo environments created this table from a CSV seed. Bring
-- that shape forward without requiring users to remove their Docker volume.
ALTER TABLE raw.maximo_workorder ADD COLUMN IF NOT EXISTS source_key text;
ALTER TABLE raw.maximo_workorder ADD COLUMN IF NOT EXISTS site_id text;
ALTER TABLE raw.maximo_workorder ADD COLUMN IF NOT EXISTS source_updated_at timestamptz;
ALTER TABLE raw.maximo_workorder ADD COLUMN IF NOT EXISTS ingested_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE raw.maximo_workorder ADD COLUMN IF NOT EXISTS source_hash text;
ALTER TABLE raw.maximo_workorder ADD COLUMN IF NOT EXISTS source_payload jsonb NOT NULL DEFAULT '{}'::jsonb;

-- Do not coerce legacy seed columns in-place: earlier dbt views may depend on
-- their text type. The staging model performs the compatible casts, while a
-- fresh deployment receives the typed table definition above.

UPDATE raw.maximo_workorder
SET source_key = COALESCE(NULLIF(site_id, ''), 'UNKNOWN') || '|' || wo_number
WHERE source_key IS NULL;

UPDATE raw.maximo_workorder
SET source_hash = md5(COALESCE(source_payload::text, '') || COALESCE(source_key, ''))
WHERE source_hash IS NULL;

ALTER TABLE raw.maximo_workorder ALTER COLUMN source_key SET NOT NULL;
ALTER TABLE raw.maximo_workorder ALTER COLUMN source_hash SET NOT NULL;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_constraint
        WHERE conname = 'maximo_workorder_source_key_key'
          AND conrelid = 'raw.maximo_workorder'::regclass
    ) THEN
        ALTER TABLE raw.maximo_workorder
            ADD CONSTRAINT maximo_workorder_source_key_key UNIQUE (source_key);
    END IF;
END $$;

CREATE INDEX IF NOT EXISTS ix_maximo_workorder_source_updated_at
    ON raw.maximo_workorder (source_updated_at);
CREATE INDEX IF NOT EXISTS ix_maximo_workorder_status
    ON raw.maximo_workorder (status);
CREATE INDEX IF NOT EXISTS ix_maximo_workorder_site_id
    ON raw.maximo_workorder (site_id);

-- Local BI role: only the business-ready mart is visible. The password is
-- supplied by the migration runner as a psql variable, never committed.
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'superset_bi') THEN
        CREATE ROLE superset_bi LOGIN;
    END IF;
END $$;

ALTER ROLE superset_bi PASSWORD :'superset_password';
GRANT CONNECT ON DATABASE dwh TO superset_bi;
GRANT USAGE ON SCHEMA mart TO superset_bi;
GRANT SELECT ON ALL TABLES IN SCHEMA mart TO superset_bi;
ALTER DEFAULT PRIVILEGES FOR ROLE platform_admin IN SCHEMA mart
    GRANT SELECT ON TABLES TO superset_bi;

REVOKE ALL ON SCHEMA raw, staging, core FROM superset_bi;
