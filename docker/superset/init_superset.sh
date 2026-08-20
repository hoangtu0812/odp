#!/usr/bin/env bash
set -euo pipefail

superset db upgrade

admin_username="${SUPERSET_ADMIN_USERNAME:-admin}"
if ! superset fab list-users | awk '{print $2}' | grep -Fxq "$admin_username"; then
  superset fab create-admin \
    --username "$admin_username" \
    --firstname "Platform" \
    --lastname "Administrator" \
    --email "${SUPERSET_ADMIN_EMAIL:-platform-admin@localhost}" \
    --password "${SUPERSET_ADMIN_PASSWORD:?Set SUPERSET_ADMIN_PASSWORD in .env}"
fi

superset fab reset-password \
  --username "$admin_username" \
  --password "${SUPERSET_ADMIN_PASSWORD:?Set SUPERSET_ADMIN_PASSWORD in .env}"

superset init
