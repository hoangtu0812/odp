-- Database-enforced area access baseline. The access mapping is maintained by
-- platform administrators and is evaluated against the current PostgreSQL role.
CREATE SCHEMA IF NOT EXISTS security;

CREATE TABLE IF NOT EXISTS security.user_area_access (
    database_role name NOT NULL,
    area text NOT NULL,
    granted_at timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (database_role, area)
);

GRANT USAGE ON SCHEMA security TO superset_bi;
GRANT SELECT ON security.user_area_access TO superset_bi;

INSERT INTO security.user_area_access (database_role, area)
VALUES ('superset_bi', '*')
ON CONFLICT DO NOTHING;

ALTER TABLE mart.workorder_summary ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS workorder_summary_area_access ON mart.workorder_summary;
CREATE POLICY workorder_summary_area_access ON mart.workorder_summary
    FOR SELECT TO superset_bi
    USING (
        EXISTS (
            SELECT 1
            FROM security.user_area_access AS access
            WHERE access.database_role = current_user
              AND (access.area = '*' OR access.area = mart.workorder_summary.area)
        )
    );
