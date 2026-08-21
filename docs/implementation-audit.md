# LDL Commerce implementation audit

Date: 2026-08-21

## Scope and baseline

The repository is a Docker Compose-first local platform. Its existing
maintenance (Maximo) vertical slice is the LDL demo domain and is extended
without replacing its existing source contract.

| Area | Current implementation | Reuse for LDL Commerce / Kubernetes |
| --- | --- | --- |
| Warehouse | PostgreSQL 16, migrations, raw/staging/core/mart schemas | Reuse the database and extend the existing `raw.maximo_workorder` contract. |
| Orchestration | Airflow 3 image with dbt 1.9, DAGs mounted read-only | Extend the existing Maximo DAG with explicit validation and publishing steps. |
| Transformation | dbt-postgres project `dbt/bsr_analytics` | Reuse the maintenance staging/core/mart model tree and add tests. |
| Lakehouse | MinIO, Iceberg REST catalog and Trino | Reuse images/catalog configuration for a Maximo telemetry or attachment demonstration. |
| Analytics | Superset container and initialization script | Add versioned Maximo dashboard provisioning assets; keep mart-only access. |
| Governance | Keycloak, OPA, OpenMetadata helper scripts | Reuse policies/realm; Kubernetes uses in-cluster services. |
| Observability | Prometheus, Grafana, Loki, Alloy | Reuse dashboard provisioning patterns and add platform/pipeline signals. |
| Portal and AI | Static portal with real endpoint probes; Python semantic-query service | Extend with data-product and demo views, and allow only Commerce marts. |

## Service inventory

The primary Compose file pins PostgreSQL, Airflow, dbt, Superset, MinIO,
Iceberg REST, Trino, Keycloak, OPA, Prometheus, Grafana, Loki, Alloy, the
portal and the AI service. PostgreSQL, MinIO, Grafana, Prometheus, Loki,
Alloy and Keycloak already have named-volume persistence. Custom health
endpoints currently exist for the AI service and several Compose services.

Airbyte is currently launched through `abctl` and OpenMetadata through an
upstream Compose runtime. These are valid only for the legacy Compose mode.
They must not be called from Kubernetes scripts or pods.

## Shared configuration boundaries

* SQL migrations, dbt models, Airflow DAG source, OPA policies, Keycloak
  realm, Grafana assets, portal assets and AI service are source-of-truth
  files shared by both modes.
* Docker Compose retains localhost endpoints for browser access. Kubernetes
  values and manifests must use service DNS for pod-to-pod traffic.
* Credentials stay in ignored `.env` files for Compose and are generated from
  `.env.k8s.example` into Kubernetes Secrets for Kubernetes.

## Decisions needed before chart installation

The repository will use Kind as the default local cluster because it has a
well-documented local-image loading flow. Third-party chart versions are
pinned in Kubernetes values/scripts instead of resolving `latest` at runtime.
The initial local profile will support optional `--skip-*` components, while
the default remains the complete topology described in the requirements.

## Delivery risks

* Airbyte and OpenMetadata chart APIs vary by release; their exact pinned
  versions and supported PostgreSQL topology must be validated by `helm lint`
  and `helm template` before a cluster is considered deployable.
* A full stack is resource-intensive. The documented baseline is 8 CPU, 16 GB
  available RAM and 50 GB free disk; lightweight flags only reduce components,
  never substitute mocked services.
* The Iceberg REST fixture is suitable for a local demo, not a production
  catalog. Its health and Trino compatibility are smoke-tested explicitly.

## Maximo data journey

The existing Maximo connector lands normalized work orders in
`raw.maximo_workorder` with an auditable watermark. In a local demo it can run
against the versioned JSON fixture; in an integrated environment Airbyte and
the Maximo source connector must use the validated source API. dbt produces
the maintenance dimensions, fact and `mart.workorder_summary`; Superset,
Trino and the AI service consume those curated datasets only. A future
lakehouse slice uses telemetry or attachment events, not an unrelated commerce
domain.
