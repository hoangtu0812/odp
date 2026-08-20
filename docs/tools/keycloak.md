# Keycloak and Microsoft Entra SSO

## Role

Keycloak is the platform identity provider. It imports the `open-source-data-platform` realm, defines platform roles, and brokers sign-in to Microsoft Entra ID.

## Start

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile governance up -d keycloak keycloak-entra-config
```

Open http://localhost:8180. Local administration uses `KEYCLOAK_ADMIN_USER` and `KEYCLOAK_ADMIN_PASSWORD` from `.env`.

## Entra configuration already automated

The one-time `keycloak-entra-config` job creates the `azure-entra` OIDC identity provider using the three Azure variables in `.env`. It never writes or prints client secrets.

Before a user can sign in, add this callback to the Microsoft Entra application registration:

```text
http://localhost:8180/realms/open-source-data-platform/broker/azure-entra/endpoint
```

Use the public DNS name in both Keycloak and Entra if the portal is not accessed from the same machine.

## Roles and application integration

Realm roles include `platform_admin`, `data_engineer`, `maintenance_analyst`, and `viewer`. For an application, create a confidential OIDC client, register its redirect URI, map the required Entra groups/roles, and enforce authorization in that application. The static Local Lab portal is a launcher, not an authentication gate.
