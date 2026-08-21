# ADR-002: Keep the Maximo warehouse and event lakehouse paths explicit

## Context

Maximo work orders need a relational raw and curated path. Telemetry or
attachment events are a suitable future Iceberg lakehouse slice and enable a
Trino federation query without introducing an unrelated business domain.

## Decision

The Maximo connector lands work orders in `raw.maximo_workorder`; dbt builds
the maintenance staging/core/mart models. When telemetry is available, it is
loaded to a partitioned Iceberg table in MinIO. Trino federates the curated
PostgreSQL maintenance mart with that real telemetry table.

## Alternatives

Replicating every Maximo table into Iceberg adds cost and obscures the demo
purpose. Inventing commerce web events would not demonstrate the LDL domain.

## Consequences

The demo documents two real storage roles. The telemetry loader is a separate,
verifiable integration and reports its own status.
