# --- DATABASE STAGE (VPS CUSTOM) ---
# Usamos PostgreSQL 18.3 + pgvector + pg_cron
FROM postgres:18.3

LABEL maintainer="EAJDias"
LABEL description="PostgreSQL 18.3 com extensões pg_cron e pgvector para VPS"

# Instala pg_cron, pgvector e limpa caches
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    postgresql-18-cron \
    postgresql-18-pgvector && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
