"""Validate the Maximo raw landing table after an ingestion run."""

from __future__ import annotations

import os
import psycopg2


def main() -> None:
    with psycopg2.connect(
        host=os.getenv("DBT_HOST", "postgres"), port=os.getenv("DBT_PORT", "5432"),
        dbname=os.getenv("DBT_DATABASE", "dwh"), user=os.environ["DBT_USER"], password=os.environ["DBT_PASSWORD"],
    ) as connection, connection.cursor() as cursor:
        cursor.execute("SELECT count(*), count(*) FILTER (WHERE source_updated_at IS NOT NULL) FROM raw.maximo_workorder")
        total, incremental = cursor.fetchone()
        if total < 1:
            raise RuntimeError("raw.maximo_workorder is empty after Maximo ingestion")
        print(f"raw.maximo_workorder: {total} records ({incremental} with source watermark)")


if __name__ == "__main__":
    main()
