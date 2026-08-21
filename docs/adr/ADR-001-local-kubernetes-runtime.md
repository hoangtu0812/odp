# ADR-001: Use Kind for the local Kubernetes runtime

## Context

LDL needs one reproducible local Kubernetes deployment that can load local
images without publishing them. Airbyte must run in that cluster, and the
legacy `abctl`/Kind runtime cannot be reused in Kubernetes mode.

## Decision

Use Kind as the supported default. Build custom images locally and load them
with `kind load docker-image`. Install third-party components from pinned Helm
charts and retain only LDL values, supplemental manifests and scripts.

## Alternatives

* k3d was not selected as the default to avoid maintaining a second registry
  and bootstrap implementation.
* Docker Compose inside Kubernetes is rejected because it leaves services
  outside Kubernetes lifecycle, readiness and storage controls.

## Consequences

Developers need Docker, Kind, kubectl and Helm. Kubernetes scripts must create
the cluster, namespaces, storage, secrets, releases and smoke-test the same
cluster.
