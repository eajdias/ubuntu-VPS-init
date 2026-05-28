#!/bin/bash
# =============================================================================
#  07-communication.sh — Comunicação (Chatwoot & Evolution API)
#  Pré-requisito: databases-central e redis-central rodando,
#  bancos 'chatwoot' e 'evolution' criados (05-databases.sh chatwoot evolution)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/../00-config.env"

# --- Cores ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
log_ok()      { echo -e "${GREEN}✔  $*${NC}"; }
log_info()    { echo -e "${CYAN}ℹ  $*${NC}"; }
log_warn()    { echo -e "${YELLOW}⚠  $*${NC}"; }
log_section() {
  echo -e "\n${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}${BOLD}  $*${NC}"
  echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}
die() { echo -e "${RED}✘  $*${NC}" >&2; exit 1; }

if [[ -n "${SUDO_USER:-}" ]]; then
    HOME_DIR="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
else
    HOME_DIR="$HOME"
fi

# Verifica pré-requisitos
for dep in databases-central redis-central; do
    if ! docker inspect "$dep" &>/dev/null; then
        die "'${dep}' não encontrado. Execute os passos 03, 04 e 05 primeiro."
    fi
done

# ── 1. Evolution API ─────────────────────────────────────────────────
log_section "Evolution API"
EVO_DIR="${HOME_DIR}/evolution"
mkdir -p "$EVO_DIR"

cat > "${EVO_DIR}/.env" << EOF
SERVER_URL=https://${EVO_DOMAIN}
AUTHENTICATION_TYPE=apikey
AUTHENTICATION_API_KEY=${EVO_API_KEY}
DATABASE_ENABLED=true
DATABASE_PROVIDER=postgresql
DATABASE_CONNECTION_URI=postgresql://${PG_USER}:${PG_PASSWORD}@databases-central:5432/evolution?sslmode=disable
REDIS_ENABLED=true
REDIS_URI=redis://redis-central:6379/${REDIS_DB_EVOLUTION}
CHATWOOT_ENABLED=true
TYPEBOT_ENABLED=false
OPENAI_ENABLED=true
N8N_ENABLED=true
EOF
chmod 600 "${EVO_DIR}/.env"

cat > "${EVO_DIR}/docker-compose.yml" << EOF
services:
  evolution-api:
    image: ${EVO_IMAGE}
    container_name: evolution-api
    restart: unless-stopped
    ${DOCKER_LOG_CONFIG}
    env_file: .env
    ports:
      - "${PORT_EVOLUTION}:8080"
    deploy:
      resources:
        limits:
          memory: 512M
    volumes:
      - evolution_instances:/evolution/instances
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
    networks:
      - ${DOCKER_NETWORK}

volumes:
  evolution_instances:
networks:
  ${DOCKER_NETWORK}:
    external: true
EOF

cd "$EVO_DIR" && docker compose up -d --remove-orphans
log_ok "Evolution API rodando na porta ${PORT_EVOLUTION} (Redis: db1)"

# ── 2. Chatwoot ──────────────────────────────────────────────────────
log_section "Chatwoot"
CW_DIR="${HOME_DIR}/chatwoot"
mkdir -p "$CW_DIR"

cat > "${CW_DIR}/.env" << EOF
FRONTEND_URL=https://${CW_DOMAIN}
POSTGRES_HOST=databases-central
POSTGRES_DATABASE=chatwoot
POSTGRES_USERNAME=${PG_USER}
POSTGRES_PASSWORD=${PG_PASSWORD}
REDIS_URL=redis://redis-central:6379/${REDIS_DB_CHATWOOT}
SECRET_KEY_BASE=${CW_SECRET_KEY_BASE}
RAILS_ENV=production
NODE_ENV=production
INSTALLATION_ENV=docker
ACTIVE_STORAGE_SERVICE=local
RAILS_LOG_TO_STDOUT=true
EOF
chmod 600 "${CW_DIR}/.env"

cat > "${CW_DIR}/docker-compose.yml" << EOF
services:
  chatwoot-app:
    image: ${CW_IMAGE}
    container_name: chatwoot-app
    restart: unless-stopped
    env_file: .env
    ${DOCKER_LOG_CONFIG}
    ports:
      - "${PORT_CHATWOOT}:3000"
    deploy:
      resources:
        limits:
          memory: 1G
    volumes:
      - chatwoot_storage:/app/storage
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
    networks:
      - ${DOCKER_NETWORK}
    entrypoint: docker/entrypoints/rails.sh
    command: ["bundle", "exec", "rails", "s", "-p", "3000", "-b", "0.0.0.0"]

  chatwoot-worker:
    image: ${CW_IMAGE}
    container_name: chatwoot-worker
    restart: unless-stopped
    env_file: .env
    ${DOCKER_LOG_CONFIG}
    deploy:
      resources:
        limits:
          memory: 512M
    volumes:
      - chatwoot_storage:/app/storage
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
    networks:
      - ${DOCKER_NETWORK}
    command: ["bundle", "exec", "sidekiq", "-C", "config/sidekiq.yml"]

volumes:
  chatwoot_storage:
networks:
  ${DOCKER_NETWORK}:
    external: true
EOF

log_info "Executando migrações do Chatwoot (isso pode demorar alguns minutos)..."
cd "$CW_DIR" && docker compose run --rm chatwoot-app bundle exec rails db:chatwoot_prepare

log_info "Subindo Chatwoot App..."
cd "$CW_DIR" && docker compose up -d chatwoot-app --remove-orphans

log_info "Subindo Chatwoot Worker..."
cd "$CW_DIR" && docker compose up -d chatwoot-worker --remove-orphans
log_ok "Chatwoot rodando na porta ${PORT_CHATWOOT} (Redis: db0)"

log_section "Resumo de Acesso"
echo -e "  Chatwoot      → https://${CW_DOMAIN}  (porta ${PORT_CHATWOOT})"
echo -e "  Evolution     → https://${EVO_DOMAIN}  (porta ${PORT_EVOLUTION})"
echo -e "  n8n           → https://${N8N_DOMAIN}  (porta ${PORT_N8N})"
echo -e "  Filebrowser   → https://${FB_DOMAIN}  (porta ${PORT_FILEBROWSER})"
echo -e "  Netdata       → https://${NETDATA_DOMAIN}  (porta ${PORT_NETDATA})"
echo -e "  Uptime Kuma   → https://${UK_DOMAIN}  (porta ${PORT_UPTIME_KUMA})"
echo -e "  Dozzle        → https://${DZ_DOMAIN}  (porta ${PORT_DOZZLE})"

log_ok "Passo 07 concluído!"
