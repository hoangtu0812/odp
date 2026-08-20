# Keycloak and Microsoft Entra SSO

## Role

Keycloak is the platform identity provider. It imports the `open-source-data-platform` realm, defines platform roles, and brokers sign-in to Microsoft Entra ID. OAuth2 Proxy uses Keycloak as the confidential OIDC provider in front of the Portal.

## Start

```powershell
docker compose --env-file .env -f infra/docker-compose/docker-compose.local.yml --profile portal up -d keycloak keycloak-entra-config keycloak-portal-client-config oauth2-proxy
```

Open http://localhost:8180. Local administration uses `KEYCLOAK_ADMIN_USER` and `KEYCLOAK_ADMIN_PASSWORD` from `.env`.

## Entra configuration already automated

The one-time `keycloak-entra-config` job creates the `azure-entra` OIDC identity provider using the three Azure variables in `.env`. It never writes or prints client secrets. The `keycloak-portal-client-config` job configures the confidential `platform-portal` client, its local callback, secret, and token audience mapper.

Before a user can sign in, add this callback to the Microsoft Entra application registration:

```text
http://localhost:8180/realms/open-source-data-platform/broker/azure-entra/endpoint
```

Use the public DNS name in both Keycloak and Entra if the portal is not accessed from the same machine.

## Roles and application integration

Realm roles include `platform_admin`, `data_engineer`, `maintenance_analyst`, and `viewer`. Opening `/portal/` starts the authorization request with `kc_idp_hint=azure-entra`, so the user goes directly to Microsoft Entra rather than selecting an identity provider manually.

For another application, create a separate confidential OIDC client, register its exact redirect URI, map the required Entra groups/roles, and enforce authorization in that application. Portal SSO does not automatically create sessions in other products.

The local lab deliberately uses HTTP and `localhost`; change to HTTPS and public DNS before shared or production use.
