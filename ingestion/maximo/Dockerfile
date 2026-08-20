FROM python:3.12-slim

RUN pip install --no-cache-dir psycopg2-binary==2.9.10

WORKDIR /app
COPY maximo_ingest.py /app/maximo_ingest.py
COPY sample_workorders.json /app/sample_workorders.json

ENTRYPOINT ["python", "/app/maximo_ingest.py"]
