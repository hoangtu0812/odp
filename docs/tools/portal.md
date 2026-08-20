# Data Platform Portal

## Role

The portal is the visual entry point for Local Lab services. It uses application logos, direct links, and backend health probes so operators can see whether core services are ready.

## Start

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile portal up -d --build portal
```

Open http://localhost:3000. The UI is in `frontend/portal/`; proxy health routes are in `docker/portal/default.conf`.

## Extend it

1. Add a card with a product logo, accessible alt text, link, and concise purpose.
2. Add a health route only when the target has a stable local readiness endpoint.
3. Rebuild the `portal` service and check that an unavailable service is visibly marked unavailable.
4. For shared use, put an OIDC-aware gateway or application session layer in front of the portal; health probes are not authorization.
