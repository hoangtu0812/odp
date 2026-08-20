"""Minimal, environment-backed configuration for the local Superset service."""

import os
from urllib.parse import quote_plus


def database_uri(database: str, user: str, password: str) -> str:
    return f"postgresql+psycopg2://{quote_plus(user)}:{quote_plus(password)}@postgres:5432/{database}"


SECRET_KEY = os.getenv("SUPERSET_SECRET_KEY", "local-development-only-change-me")
SQLALCHEMY_DATABASE_URI = database_uri(
    "superset",
    os.getenv("POSTGRES_USER", "platform_admin"),
    os.getenv("POSTGRES_PASSWORD", "change-me"),
)
WTF_CSRF_ENABLED = True
TALISMAN_ENABLED = False  # TLS terminates at the reverse proxy outside local development.
ROW_LIMIT = 10000
SUPERSET_WEBSERVER_TIMEOUT = 60
