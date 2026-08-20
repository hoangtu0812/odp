-- Operational metadata is deliberately isolated from analytic data so audits
-- and watermarks remain available even while the DWH is being rebuilt.
CREATE TABLE IF NOT EXISTS public.ingestion_audit (
    audit_id bigserial PRIMARY KEY,
    pipeline_name text NOT NULL,
    run_id uuid NOT NULL,
    status text NOT NULL CHECK (status IN ('running', 'success', 'failed')),
    started_at timestamptz NOT NULL DEFAULT now(),
    finished_at timestamptz,
    records_read integer NOT NULL DEFAULT 0,
    records_loaded integer NOT NULL DEFAULT 0,
    watermark_from timestamptz,
    watermark_to timestamptz,
    error_message text,
    details jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS ix_ingestion_audit_pipeline_started
    ON public.ingestion_audit (pipeline_name, started_at DESC);

CREATE TABLE IF NOT EXISTS public.ingestion_watermark (
    pipeline_name text PRIMARY KEY,
    watermark timestamptz,
    updated_at timestamptz NOT NULL DEFAULT now()
);
