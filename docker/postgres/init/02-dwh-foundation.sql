-- See sql/migrations/001_dwh_foundation.sql. This bootstrap version runs for a
-- fresh volume; the migration service applies the same structure to existing
-- volumes and manages the BI role password.
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
