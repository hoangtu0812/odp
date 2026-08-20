# Loop Data Lab (LDL) roadmap

This is the single implementation roadmap. It is separate from the README so the README remains an operational entry point.

## Target capabilities

| Workstream | Building blocks | Outcome |
| --- | --- | --- |
| Ingestion | Connector framework, Airbyte, incremental patterns | Repeatable, auditable source landing |
| Orchestration | Apache Airflow | Scheduled, observable workflows |
| Warehouse and modeling | PostgreSQL, dbt | Tested raw, core, and mart data products |
| BI | Apache Superset | Governed self-service analytics |
| Observability | Prometheus, Grafana, Loki, Alloy | Metrics, logs, dashboards, and alerts |
| Lakehouse | MinIO, Apache Iceberg, Trino | Open table storage and federated SQL |
| Governance | OpenMetadata, Keycloak, Microsoft Entra, OPA | Catalog, lineage, SSO, RBAC, and policy decisions |
| Experience | Portal, AI Data Assistant | One entry point and guarded data discovery |

## Delivery sequence

1. **Foundation** — Compose structure, PostgreSQL, versioned migrations, configuration management, and CI validation.
2. **Data product path** — source connectors, durable ingestion audit, dbt modeling/tests, Airflow orchestration, and Superset datasets.
3. **Operational visibility** — Prometheus exporters, Grafana dashboards, Loki/Alloy log collection, and alerts.
4. **Lakehouse access** — MinIO buckets, Iceberg REST catalog, and Trino federation.
5. **Governance and access** — Keycloak realm/roles, Entra broker, OPA policies, row-level access controls, and OpenMetadata integration.
6. **Experience and intelligence** — portal catalogue, ownership links, semantic query guardrails, and approved AI capabilities.

## Local Lab completion criteria

- Every enabled container has a documented startup command, readiness check, and operator workflow.
- Database changes are versioned migrations; transformations have dbt tests.
- Access follows least privilege and secrets remain in `.env` or a managed secret store.
- The portal exposes application links and distinguishes available services from documentation-only capabilities.
- A contributor can start the lab and operate each tool with no prior project knowledge.

## Shared-environment evolution

The Local Lab is a single-host reference implementation. Before a shared deployment, introduce private networking, TLS termination, managed identity/secrets, application-specific SSO enforcement, retention, ownership, capacity controls, and a support model.

High availability, backup, and disaster recovery are deliberately outside the current requested scope and must be designed separately for the chosen target environment.
