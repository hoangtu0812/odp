# Loop Data Lab Portal

## Role

The public root page is a Loop Data Lab (LDL) landing page. It introduces the platform with a technical-lab visual language, animated instrumentation, and a **Continue with Azure Entra** button. The protected portal uses the same interface language, application logos, direct links, and backend health probes so operators can see whether core services are ready.

`/` is public; `/portal/` requires a successful Azure Entra sign-in through Keycloak and OAuth2 Proxy. The browser receives a secure, HTTP-only local session cookie after the callback. Signing out from the Portal removes this Portal session.

## Start

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile portal up -d --build
```

Open http://localhost:3000. Select **Continue with Azure Entra**; after Azure completes, the browser returns to `http://localhost:3000/portal/`.

The landing UI is in `frontend/portal/index.html` and `landing.css`; the protected Portal is in `frontend/portal/portal/`. The OIDC gateway and public health routes are in `docker/portal/default.conf`.

## Local access boundary

The Azure session currently protects the Portal itself. Each linked product retains its own local login until its native OIDC configuration is enabled. This avoids presenting a visual launcher as if it were a full cross-application SSO boundary.

## Extend it

1. Add a card with a product logo, accessible alt text, link, and concise purpose.
2. Add a health route only when the target has a stable local readiness endpoint.
3. Rebuild the `portal` service and check that an unavailable service is visibly marked unavailable.
4. For another web product, configure its native OIDC integration with Keycloak before claiming it participates in SSO.
5. Health probes are operational convenience, not an authorization boundary.
