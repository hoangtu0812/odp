#!/bin/sh
set -eu

realm="open-source-data-platform"
server="http://keycloak:8080"
client_id="platform-portal"

until /opt/keycloak/bin/kcadm.sh config credentials \
  --server "$server" --realm master \
  --user "$KEYCLOAK_ADMIN_USER" --password "$KEYCLOAK_ADMIN_PASSWORD" >/dev/null 2>&1; do
  sleep 3
done

client_uuid="$(/opt/keycloak/bin/kcadm.sh get clients -r "$realm" -q clientId="$client_id" \
  | sed -n 's/.*"id" : "\([^"]*\)".*/\1/p' | head -1)"

if [ -z "$client_uuid" ]; then
  /opt/keycloak/bin/kcadm.sh create clients -r "$realm" \
    -s clientId="$client_id" \
    -s name="Open Source Data Platform Portal" \
    -s enabled=true \
    -s protocol=openid-connect \
    -s publicClient=false \
    -s standardFlowEnabled=true \
    -s directAccessGrantsEnabled=false >/dev/null
  client_uuid="$(/opt/keycloak/bin/kcadm.sh get clients -r "$realm" -q clientId="$client_id" \
    | sed -n 's/.*"id" : "\([^"]*\)".*/\1/p' | head -1)"
fi

/opt/keycloak/bin/kcadm.sh update "clients/$client_uuid" -r "$realm" \
  -s publicClient=false \
  -s standardFlowEnabled=true \
  -s directAccessGrantsEnabled=false \
  -s 'redirectUris=["http://localhost:3000/oauth2/callback"]' \
  -s 'webOrigins=["http://localhost:3000"]' \
  -s "secret=$PORTAL_OIDC_CLIENT_SECRET" >/dev/null

mapper_id="$(/opt/keycloak/bin/kcadm.sh get "clients/$client_uuid/protocol-mappers/models" -r "$realm" \
  | sed -n '/"id" : "/ { s/.*"id" : "\([^"]*\)".*/\1/; h; }; /"name" : "portal-audience"/ { x; p; q; }')"
if [ -n "$mapper_id" ]; then
  /opt/keycloak/bin/kcadm.sh delete "clients/$client_uuid/protocol-mappers/models/$mapper_id" -r "$realm" >/dev/null
fi
/opt/keycloak/bin/kcadm.sh create "clients/$client_uuid/protocol-mappers/models" -r "$realm" \
  -s name=portal-audience \
  -s protocol=openid-connect \
  -s protocolMapper=oidc-audience-mapper \
  -s 'config."included.client.audience"=platform-portal' \
  -s 'config."access.token.claim"=true' \
  -s 'config."id.token.claim"=true' >/dev/null

echo "Portal OIDC client configured."
