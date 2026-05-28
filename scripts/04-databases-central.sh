#!/bin/bash
# =============================================================================
#  04-databases-central.sh — Containers de Banco de Dados Centrais
#  Objetivo: databases-central (Postgres) e redis-central
#  Sem criação de bancos/logical-dbs de aplicação — responsabilidade do 05-databases.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/../00-config.env"

# --- Cores ---
GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
log_ok()   { echo -e "${GREEN}✔  $*${NC}"; }
log_info() { echo -e "${CYAN}ℹ  $*${NC}"; }

if [[ -n "${SUDO_USER:-}" ]]; then
    HOME_DIR="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
else
    HOME_DIR="$HOME"
fi

# ── 1. databases-central (Postgres) ──────────────────────────────────
log_info "Configurando databases-central (Postgres)..."
PG_DIR="${HOME_DIR}/databases-central"
mkdir -p "$PG_DIR"

cat > "${PG_DIR}/.env" << EOF
POSTGRES_USER=${PG_USER}
POSTGRES_PASSWORD=${PG_PASSWORD}
POSTGRES_DB=postgres
EOF
chmod 600 "${PG_DIR}/.env"

cat > "${PG_DIR}/docker-compose.yml" << EOF
services:
  databases-central:
    build: ${SCRIPT_DIR}/..
    image: ${PG_IMAGE}
    container_name: databases-central
    restart: unless-stopped
    env_file: .env
    ${DOCKER_LOG_CONFIG}
    command: ["postgres", "-c", "shared_preload_libraries=pg_cron", "-c", "cron.database_name=postgres"]
    environment:
      - PGDATA=/var/lib/postgresql/data
    volumes:
      - databases_central_data:/var/lib/postgresql/data
    networks:
      - ${DOCKER_NETWORK}
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${PG_USER}"]
      interval: 5s
      timeout: 5s
      retries: 10
    deploy:
      resources:
        limits:
          memory: 512M
    labels:
      - "com.centurylinklabs.watchtower.enable=false"

volumes:
  databases_central_data:
networks:
  ${DOCKER_NETWORK}:
    external: true
EOF

cd "$PG_DIR" && docker compose up -d
log_info "Aguardando databases-central ficar pronto..."
until docker exec databases-central pg_isready -U "$PG_USER" &>/dev/null; do
    printf '.'; sleep 2
done
echo ""
log_ok "databases-central pronto!"

# Sincroniza a senha do Postgres (caso o volume seja antigo e a senha no .env tenha mudado)
docker exec databases-central psql -U "$PG_USER" -c "ALTER USER \"$PG_USER\" WITH PASSWORD '${PG_PASSWORD}';" > /dev/null

log_info "Instalando extensão pg_cron no banco postgres..."
docker exec databases-central psql -U "$PG_USER" -d postgres -c "CREATE EXTENSION IF NOT EXISTS pg_cron;" > /dev/null
log_ok "Extensão pg_cron ativa."

# ── 2. redis-central ─────────────────────────────────────────────────
log_info "Configurando redis-central..."
REDIS_DIR="${HOME_DIR}/redis-central"
mkdir -p "$REDIS_DIR"

cat > "${REDIS_DIR}/docker-compose.yml" << EOF
services:
  redis-central:
    image: ${REDIS_IMAGE}
    container_name: redis-central
    restart: unless-stopped
    ${DOCKER_LOG_CONFIG}
    command: redis-server --appendonly yes --maxmemory 128mb --maxmemory-policy allkeys-lru
    ports:
      - "${PORT_REDIS}:6379"
    volumes:
      - redis_central_data:/data
    deploy:
      resources:
        limits:
          memory: 150M
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 5s
      timeout: 3s
      retries: 5
    labels:
      - "com.centurylinklabs.watchtower.enable=false"
    networks:
      - ${DOCKER_NETWORK}

volumes:
  redis_central_data:
networks:
  ${DOCKER_NETWORK}:
    external: true
EOF

cd "$REDIS_DIR" && docker compose up -d --remove-orphans
log_info "Aguardando redis-central ficar pronto..."
until docker exec redis-central redis-cli ping &>/dev/null; do
    printf '.'; sleep 2
done
echo ""
log_ok "redis-central pronto!"

log_ok "Passo 04 concluído!"
