FROM python:3.12-slim

WORKDIR /app
RUN pip install --no-cache-dir psycopg2-binary==2.9.10
COPY app.py /app/app.py
EXPOSE 8010
CMD ["python", "/app/app.py"]
