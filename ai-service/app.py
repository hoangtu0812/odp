"""Safe, semantic Text-to-Data assistant for the Local Lab."""

from __future__ import annotations

import json
import os
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

import psycopg2
import psycopg2.extras


SEMANTIC_QUERIES = {
    "overdue": (
        "Work orders quá hạn theo khu vực",
        """SELECT site_id, area, SUM(overdue_count)::bigint AS overdue_work_orders
           FROM mart.workorder_summary
           GROUP BY site_id, area ORDER BY overdue_work_orders DESC, site_id, area LIMIT 100""",
    ),
    "cost": (
        "Tổng chi phí ước tính theo khu vực",
        """SELECT site_id, area, SUM(estimated_cost_total)::numeric(18,2) AS estimated_cost_total
           FROM mart.workorder_summary
           GROUP BY site_id, area ORDER BY estimated_cost_total DESC NULLS LAST, site_id, area LIMIT 100""",
    ),
    "status": (
        "Work orders theo trạng thái",
        """SELECT status, SUM(work_order_count)::bigint AS work_order_count
           FROM mart.workorder_summary
           GROUP BY status ORDER BY work_order_count DESC, status LIMIT 100""",
    ),
}


def select_intent(question: str) -> str:
    normalized = question.lower()
    if any(word in normalized for word in ("quá hạn", "qua han", "overdue")):
        return "overdue"
    if any(word in normalized for word in ("chi phí", "chi phi", "cost", "giá trị", "gia tri")):
        return "cost"
    return "status"


def connection():
    return psycopg2.connect(
        host=os.getenv("POSTGRES_HOST", "postgres"),
        port=os.getenv("POSTGRES_PORT_INTERNAL", "5432"),
        user=os.environ["POSTGRES_USER"],
        password=os.environ["POSTGRES_PASSWORD"],
        dbname=os.getenv("DBT_DATABASE", "dwh"),
        connect_timeout=10,
    )


class Handler(BaseHTTPRequestHandler):
    def respond(self, status: int, payload: dict):
        body = json.dumps(payload, ensure_ascii=False, default=str).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/health":
            try:
                with connection() as db, db.cursor() as cursor:
                    cursor.execute("SELECT 1")
                self.respond(HTTPStatus.OK, {"status": "ok"})
            except Exception as error:
                self.respond(HTTPStatus.SERVICE_UNAVAILABLE, {"status": "error", "message": str(error)})
        elif self.path == "/v1/semantic-model":
            self.respond(HTTPStatus.OK, {"source": "mart.workorder_summary", "intents": [value[0] for value in SEMANTIC_QUERIES.values()]})
        else:
            self.respond(HTTPStatus.NOT_FOUND, {"error": "not found"})

    def do_POST(self):
        if self.path != "/v1/query":
            self.respond(HTTPStatus.NOT_FOUND, {"error": "not found"})
            return
        try:
            length = int(self.headers.get("Content-Length", "0"))
            request = json.loads(self.rfile.read(length) or b"{}")
            question = str(request.get("question", "")).strip()
            if not question:
                self.respond(HTTPStatus.BAD_REQUEST, {"error": "question is required"})
                return
            intent = select_intent(question)
            title, query = SEMANTIC_QUERIES[intent]
            with connection() as db, db.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cursor:
                cursor.execute(query)
                rows = cursor.fetchall()
            self.respond(HTTPStatus.OK, {
                "intent": intent,
                "answer": title,
                "source_dataset": "mart.workorder_summary",
                "generated_sql": query,
                "execution_status": "succeeded",
                "rows": rows,
                "guardrail": "Only pre-approved mart queries are executable.",
            })
        except Exception as error:
            self.respond(HTTPStatus.INTERNAL_SERVER_ERROR, {"error": str(error)})

    def log_message(self, *_):
        return


if __name__ == "__main__":
    ThreadingHTTPServer(("0.0.0.0", 8010), Handler).serve_forever()
