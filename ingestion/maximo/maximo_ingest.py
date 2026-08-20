"""Incrementally load Maximo work orders into the platform raw layer.

The program is intentionally dependency-light: urllib handles Maximo OSLc
requests and psycopg is used only for PostgreSQL writes. It can also use a
JSON fixture, allowing a complete local validation without contacting Maximo.
"""

from __future__ import annotations

import argparse
import base64
import hashlib
import json
import os
import ssl
import sys
import uuid
from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from typing import Any
from urllib.parse import urlencode, urlparse
from urllib.request import Request, urlopen

import psycopg2
import psycopg2.extras


PIPELINE_NAME = "maximo_workorder_ingest"
SELECT_FIELDS = (
    "wonum,description,status,location,assetnum,department,siteid,reportdate,"
    "targcompdate,actfinish,esttotalcost,changedate"
)


def env_bool(name: str, default: bool) -> bool:
    return os.getenv(name, str(default)).strip().lower() in {"1", "true", "yes", "on"}


def parse_datetime(value: Any) -> datetime | None:
    if value in (None, ""):
        return None
    if isinstance(value, datetime):
        parsed = value
    else:
        text = str(value).strip().replace("Z", "+00:00")
        try:
            parsed = datetime.fromisoformat(text)
        except ValueError:
            return None
    return parsed.replace(tzinfo=timezone.utc) if parsed.tzinfo is None else parsed.astimezone(timezone.utc)


def parse_decimal(value: Any) -> Decimal | None:
    if value in (None, ""):
        return None
    try:
        return Decimal(str(value).replace(",", ""))
    except (InvalidOperation, ValueError):
        return None


def unwrap_maximo_value(value: Any) -> Any:
    """Return the scalar carried by a REST MBO attribute when present.

    REST MBO responses serialise most attributes as ``{"content": value}``
    objects (rather than scalar JSON values).  Keeping this conversion at the
    boundary makes the downstream normaliser work for both REST MBO and OSLc.
    """
    if isinstance(value, dict):
        for key in ("content", "value"):
            if key in value:
                return unwrap_maximo_value(value[key])
    return value


def pick(record: dict[str, Any], *names: str) -> Any:
    normalized = {str(key).split(".")[-1].lower(): value for key, value in record.items()}
    for name in names:
        value = unwrap_maximo_value(normalized.get(name.lower()))
        if value not in (None, ""):
            return value
    return None


def normalized_text(value: Any, upper: bool = False) -> str | None:
    if value is None:
        return None
    result = str(value).strip()
    if not result:
        return None
    return result.upper() if upper else result


def normalize_workorder(record: dict[str, Any]) -> dict[str, Any] | None:
    wo_number = normalized_text(pick(record, "wonum", "wo_number", "workordernum"))
    if not wo_number:
        return None
    site_id = normalized_text(pick(record, "siteid", "site_id", "orgid"), upper=True) or "UNKNOWN"
    canonical_payload = json.dumps(record, sort_keys=True, default=str, separators=(",", ":"))
    return {
        "source_key": f"{site_id}|{wo_number}",
        "wo_number": wo_number,
        "description": normalized_text(pick(record, "description")),
        "status": normalized_text(pick(record, "status"), upper=True),
        "area": normalized_text(pick(record, "area", "location", "worklocation"), upper=True),
        "equipment_code": normalized_text(pick(record, "assetnum", "equipment_code", "asset"), upper=True),
        "department_code": normalized_text(pick(record, "department", "dept", "lead", "supervisor"), upper=True),
        "site_id": site_id,
        "reported_at": parse_datetime(pick(record, "reportdate", "reported_at", "report_date", "statusdate")),
        "target_finish_at": parse_datetime(pick(record, "targcompdate", "target_finish_at", "schedfinish")),
        "actual_finish_at": parse_datetime(pick(record, "actfinish", "actual_finish_at", "actualfinish")),
        "estimated_cost": parse_decimal(pick(record, "esttotalcost", "estimated_cost", "estlabcost")),
        "source_updated_at": parse_datetime(pick(record, "changedate", "source_updated_at", "lastupdate")),
        "source_hash": hashlib.sha256(canonical_payload.encode("utf-8")).hexdigest(),
        "source_payload": record,
    }


def database_connection(database: str):
    return psycopg2.connect(
        host=os.getenv("POSTGRES_HOST", os.getenv("DBT_HOST", "postgres")),
        port=os.getenv("POSTGRES_PORT_INTERNAL", os.getenv("DBT_PORT", "5432")),
        user=os.environ["POSTGRES_USER"],
        password=os.environ["POSTGRES_PASSWORD"],
        dbname=database,
        connect_timeout=15,
    )


def read_watermark(connection, pipeline_name: str) -> datetime | None:
    with connection.cursor() as cursor:
        cursor.execute("SELECT watermark FROM public.ingestion_watermark WHERE pipeline_name = %s", (pipeline_name,))
        row = cursor.fetchone()
    return row[0] if row else None


def update_audit(connection, pipeline_name: str, run_id: uuid.UUID, **values: Any) -> None:
    assignments = ", ".join(f"{key} = %s" for key in values)
    parameters = list(values.values()) + [pipeline_name, str(run_id)]
    with connection.cursor() as cursor:
        cursor.execute(
            f"UPDATE public.ingestion_audit SET {assignments} WHERE pipeline_name = %s AND run_id = %s",
            parameters,
        )
    connection.commit()


def request_maximo(url: str, base_url: str, auth_headers: dict[str, str], context: ssl.SSLContext) -> dict[str, Any]:
    parsed = urlparse(url)
    base = urlparse(base_url)
    if parsed.scheme != base.scheme or parsed.hostname != base.hostname:
        raise RuntimeError("Maximo pagination URL is not on the configured scheme and host")
    request = Request(url, headers={"Accept": "application/json", **auth_headers})
    with urlopen(request, timeout=int(os.getenv("MAXIMO_TIMEOUT_SECONDS", "60")), context=context) as response:
        return json.loads(response.read().decode("utf-8"))


def maximo_client_configuration() -> tuple[str, dict[str, str], ssl.SSLContext]:
    base_url = os.environ["MAXIMO_BASE_URL"].rstrip("/")
    parsed = urlparse(base_url)
    allow_insecure_http = env_bool("MAXIMO_ALLOW_INSECURE_HTTP", False)
    if parsed.scheme != "https" and not allow_insecure_http:
        raise RuntimeError("MAXIMO_BASE_URL must use HTTPS (or explicitly set MAXIMO_ALLOW_INSECURE_HTTP=true for local testing)")
    if parsed.scheme not in {"https", "http"}:
        raise RuntimeError("MAXIMO_BASE_URL must use HTTP or HTTPS")
    if parsed.scheme == "http":
        print("WARNING: Maximo auth is using approved internal HTTP transport.", file=sys.stderr)

    auth_mode = os.getenv("MAXIMO_AUTH_MODE", "maxauth").strip().lower()
    encoded_pair = base64.b64encode(f"{os.environ['MAXIMO_USER']}:{os.environ['MAXIMO_PASS']}".encode("utf-8")).decode("ascii")
    if auth_mode == "maxauth":
        # Maximo REST installations commonly use the Maximo-specific maxauth
        # header instead of the standard Authorization: Basic header.
        auth_headers = {"maxauth": os.getenv("MAXIMO_MAXAUTH", encoded_pair)}
    elif auth_mode == "basic":
        auth_headers = {"Authorization": f"Basic {encoded_pair}"}
    elif auth_mode == "apikey":
        api_key = os.environ.get("MAXIMO_API_KEY")
        if not api_key:
            raise RuntimeError("MAXIMO_API_KEY is required when MAXIMO_AUTH_MODE=apikey")
        auth_headers = {"apikey": api_key}
    else:
        raise RuntimeError("MAXIMO_AUTH_MODE must be maxauth, basic, or apikey")
    context = ssl.create_default_context()
    if not env_bool("MAXIMO_VERIFY_TLS", True):
        context.check_hostname = False
        context.verify_mode = ssl.CERT_NONE
    return base_url, auth_headers, context


def rest_mbo_records(page: dict[str, Any]) -> list[dict[str, Any]]:
    """Unwrap the JSON envelope returned by Maximo REST MBO endpoints."""
    mbo_set = page.get("WORKORDERMboSet") or page.get("workorderMboSet")
    if isinstance(mbo_set, list):
        mbo_set = mbo_set[0] if mbo_set else {}
    if not isinstance(mbo_set, dict):
        return []
    workorders = mbo_set.get("WORKORDER") or mbo_set.get("workorder") or []
    if isinstance(workorders, dict):
        workorders = [workorders]
    records: list[dict[str, Any]] = []
    for workorder in workorders:
        if isinstance(workorder, dict):
            attributes = workorder.get("Attributes") or workorder.get("attributes") or workorder
            if isinstance(attributes, dict):
                records.append(attributes)
    return records


def fetch_oslc_records(base_url: str, auth_headers: dict[str, str], context: ssl.SSLContext, watermark: datetime | None) -> list[dict[str, Any]]:
    endpoint = f"{base_url}/{os.getenv('MAXIMO_WORKORDER_PATH', '/oslc/os/mxwo').lstrip('/')}"
    query: dict[str, str] = {"lean": "1", "oslc.pageSize": os.getenv("MAXIMO_PAGE_SIZE", "100"), "oslc.select": SELECT_FIELDS}
    clauses: list[str] = []
    if watermark:
        field = os.getenv("MAXIMO_INCREMENTAL_FIELD", "changedate")
        clauses.append(f'{field} > "{watermark.isoformat()}"')
    if os.getenv("MAXIMO_SITE_ID"):
        clauses.append(f'siteid = "{os.environ["MAXIMO_SITE_ID"]}"')
    if clauses:
        query["oslc.where"] = " and ".join(clauses)

    next_url = f"{endpoint}?{urlencode(query)}"
    records: list[dict[str, Any]] = []
    max_pages = int(os.getenv("MAXIMO_MAX_PAGES", "1000"))
    for _ in range(max_pages):
        page = request_maximo(next_url, base_url, auth_headers, context)
        records.extend(item for item in page.get("member", []) if isinstance(item, dict))
        info = page.get("responseInfo") or {}
        next_page = info.get("nextPage") or info.get("nextpage")
        if isinstance(next_page, dict):
            next_url = next_page.get("href") or next_page.get("uri")
        elif isinstance(next_page, str):
            next_url = next_page
        else:
            return records
        if not next_url:
            return records
    raise RuntimeError(f"Maximo pagination exceeded MAXIMO_MAX_PAGES={max_pages}")


def fetch_rest_mbo_records(base_url: str, auth_headers: dict[str, str], context: ssl.SSLContext, watermark: datetime | None) -> list[dict[str, Any]]:
    endpoint = f"{base_url}/{os.getenv('MAXIMO_WORKORDER_PATH', '/rest/mbo/workorder/').lstrip('/')}"
    page_size = int(os.getenv("MAXIMO_PAGE_SIZE", "100"))
    max_pages = int(os.getenv("MAXIMO_MAX_PAGES", "1000"))
    records: list[dict[str, Any]] = []
    lower_bound = watermark or parse_datetime(os.getenv("MAXIMO_INITIAL_SYNC_SINCE"))
    if not lower_bound and not env_bool("MAXIMO_ALLOW_FULL_SNAPSHOT", False):
        raise RuntimeError("REST MBO initial sync requires MAXIMO_INITIAL_SYNC_SINCE or MAXIMO_ALLOW_FULL_SNAPSHOT=true")
    for page_number in range(max_pages):
        query = {"_format": "json", "_rsStart": str(page_number * page_size), "_maxItems": str(page_size)}
        if os.getenv("MAXIMO_SITE_ID"):
            query["siteid"] = os.environ["MAXIMO_SITE_ID"]
        if lower_bound:
            query[os.getenv("MAXIMO_INCREMENTAL_FIELD", "changedate")] = f"~gt~{lower_bound.isoformat()}"
        page = request_maximo(f"{endpoint}?{urlencode(query)}", base_url, auth_headers, context)
        batch = rest_mbo_records(page)
        records.extend(batch)
        if len(batch) < page_size:
            break
    else:
        raise RuntimeError(f"Maximo REST pagination exceeded MAXIMO_MAX_PAGES={max_pages}")

    # REST MBO deployments differ in server-side incremental filter syntax. The
    # connector stays correct by retaining only records newer than the stored
    # watermark after paging; configure a lower MAXIMO_MAX_PAGES for a guarded
    # initial run and introduce a server-side filter only after it is validated.
    if lower_bound:
        records = [record for record in records if (changed := parse_datetime(pick(record, "changedate"))) and changed > lower_bound]
    return records


def fetch_live_records(watermark: datetime | None) -> list[dict[str, Any]]:
    base_url, auth_headers, context = maximo_client_configuration()
    api_style = os.getenv("MAXIMO_API_STYLE", "oslc").strip().lower()
    if api_style == "rest_mbo":
        return fetch_rest_mbo_records(base_url, auth_headers, context, watermark)
    if api_style == "oslc":
        return fetch_oslc_records(base_url, auth_headers, context, watermark)
    raise RuntimeError("MAXIMO_API_STYLE must be oslc or rest_mbo")


def load_records(dwh_connection, records: list[dict[str, Any]]) -> int:
    query = """
        INSERT INTO raw.maximo_workorder (
            source_key, wo_number, description, status, area, equipment_code,
            department_code, site_id, reported_at, target_finish_at, actual_finish_at,
            estimated_cost, source_updated_at, source_hash, source_payload
        ) VALUES (
            %(source_key)s, %(wo_number)s, %(description)s, %(status)s, %(area)s, %(equipment_code)s,
            %(department_code)s, %(site_id)s, %(reported_at)s, %(target_finish_at)s, %(actual_finish_at)s,
            %(estimated_cost)s, %(source_updated_at)s, %(source_hash)s, %(source_payload)s
        ) ON CONFLICT (source_key) DO UPDATE SET
            wo_number = EXCLUDED.wo_number,
            description = EXCLUDED.description,
            status = EXCLUDED.status,
            area = EXCLUDED.area,
            equipment_code = EXCLUDED.equipment_code,
            department_code = EXCLUDED.department_code,
            site_id = EXCLUDED.site_id,
            reported_at = EXCLUDED.reported_at,
            target_finish_at = EXCLUDED.target_finish_at,
            actual_finish_at = EXCLUDED.actual_finish_at,
            estimated_cost = EXCLUDED.estimated_cost,
            source_updated_at = EXCLUDED.source_updated_at,
            source_hash = EXCLUDED.source_hash,
            source_payload = EXCLUDED.source_payload,
            ingested_at = now()
        WHERE raw.maximo_workorder.source_hash IS DISTINCT FROM EXCLUDED.source_hash
    """
    values = [{**record, "source_payload": psycopg2.extras.Json(record["source_payload"])} for record in records]
    with dwh_connection.cursor() as cursor:
        psycopg2.extras.execute_batch(cursor, query, values, page_size=200)
    dwh_connection.commit()
    return len(values)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--fixture", help="JSON file with a Maximo member array for local validation")
    args = parser.parse_args()

    metadata = database_connection("platform_metadata")
    dwh = database_connection(os.getenv("DBT_DATABASE", "dwh"))
    run_id = uuid.uuid4()
    pipeline_name = f"{PIPELINE_NAME}_fixture" if args.fixture else PIPELINE_NAME
    watermark = read_watermark(metadata, pipeline_name)
    with metadata.cursor() as cursor:
        cursor.execute(
            "INSERT INTO public.ingestion_audit (pipeline_name, run_id, status, watermark_from, details) VALUES (%s, %s, 'running', %s, %s)",
            (pipeline_name, str(run_id), watermark, psycopg2.extras.Json({"mode": "fixture" if args.fixture else "live"})),
        )
    metadata.commit()

    try:
        if args.fixture:
            with open(args.fixture, encoding="utf-8") as handle:
                payload = json.load(handle)
            source_records = payload.get("member", payload) if isinstance(payload, dict) else payload
            if not isinstance(source_records, list):
                raise ValueError("Fixture must be a JSON array or object containing member array")
        else:
            source_records = fetch_live_records(watermark)

        records = [normalized for item in source_records if isinstance(item, dict) if (normalized := normalize_workorder(item))]
        loaded = load_records(dwh, records)
        latest = max((record["source_updated_at"] for record in records if record["source_updated_at"]), default=watermark)
        if latest:
            with metadata.cursor() as cursor:
                cursor.execute(
                    """INSERT INTO public.ingestion_watermark (pipeline_name, watermark)
                       VALUES (%s, %s)
                       ON CONFLICT (pipeline_name) DO UPDATE SET watermark = GREATEST(public.ingestion_watermark.watermark, EXCLUDED.watermark), updated_at = now()""",
                    (pipeline_name, latest),
                )
            metadata.commit()
        update_audit(metadata, pipeline_name, run_id, status="success", finished_at=datetime.now(timezone.utc), records_read=len(source_records), records_loaded=loaded, watermark_to=latest)
        print(json.dumps({"status": "success", "records_read": len(source_records), "records_loaded": loaded, "watermark_to": latest.isoformat() if latest else None}))
        return 0
    except Exception as error:
        metadata.rollback()
        update_audit(metadata, pipeline_name, run_id, status="failed", finished_at=datetime.now(timezone.utc), error_message=str(error)[:4000])
        print(f"Maximo ingestion failed: {error}", file=sys.stderr)
        return 1
    finally:
        dwh.close()
        metadata.close()


if __name__ == "__main__":
    raise SystemExit(main())
