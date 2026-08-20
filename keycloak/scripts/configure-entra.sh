#!/bin/sh
set -eu

realm="open-source-data-platform"
server="http://keycloak:8080"

until /opt/keycloak/bin/kcadm.sh config credentials \
  --server "$server" --realm master \
  --user "$KEYCLOAK_ADMIN_USER" --password "$KEYCLOAK_ADMIN_PASSWORD" >/dev/null 2>&1; do
  sleep 3
done

/opt/keycloak/bin/kcadm.sh delete "identity-provider/instances/azure-entra" -r "$realm" >/dev/null 2>&1 || true

/opt/keycloak/bin/kcadm.sh create "identity-provider/instances" -r "$realm" \
  -s alias=azure-entra \
  -s displayName="Microsoft Entra ID" \
  -s providerId=oidc \
  -s enabled=true \
  -s trustEmail=true \
  -s storeToken=false \
  -s addReadTokenRoleOnCreate=false \
  -s 'config.clientAuthMethod=client_secret_post' \
  -s "config.clientId=$AZURE_CLIENT_ID" \
  -s "config.clientSecret=$AZURE_CLIENT_SECRET" \
  -s "config.authorizationUrl=https://login.microsoftonline.com/$AZURE_TENANT_ID/oauth2/v2.0/authorize" \
  -s "config.tokenUrl=https://login.microsoftonline.com/$AZURE_TENANT_ID/oauth2/v2.0/token" \
  -s "config.userInfoUrl=https://graph.microsoft.com/oidc/userinfo" \
  -s "config.issuer=https://login.microsoftonline.com/$AZURE_TENANT_ID/v2.0" \
  -s 'config.defaultScope=openid profile email' \
  >/dev/null

echo "Microsoft Entra identity provider configured for $realm."
