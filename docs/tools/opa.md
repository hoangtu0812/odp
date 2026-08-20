# Open Policy Agent (OPA)

## Role

OPA evaluates policy-as-code decisions separately from applications. Platform rules reside in `opa/policies/platform.rego` and use role, action, and data-area context.

## Start and test

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile governance up -d opa
Invoke-WebRequest http://localhost:8182/health -UseBasicParsing
```

Example decision request:

```powershell
Invoke-RestMethod -Method Post -ContentType 'application/json' -Uri http://localhost:8182/v1/data/platform/authz/allow -Body '{"input":{"role":"maintenance_analyst","action":"read","area":"A"}}'
```

## Operations

- Keep policy files reviewed, versioned, and covered by policy tests before widening access.
- Pass verified identity claims from the application or gateway; never trust a browser-provided role by itself.
- OPA decides; the caller must enforce the returned decision and log denials.
