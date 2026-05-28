#!/bin/bash
# =============================================================================
#  06-n8n.sh — Automação (n8n)
#  Pré-requisito: databases-central rodando com banco 'n8n' criado (05-databases.sh)
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/../00-config.env"

# --- Cores ---
RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
log_ok()   { echo -e "${GREEN}✔  $*${NC}"; }
log_info() { echo -e "${CYAN}ℹ  $*${NC}"; }
die()      { echo -e "${RED}✘  $*${NC}" >&2; exit 1; }

if [[ -n "${SUDO_USER:-}" ]]; then
    HOME_DIR="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
else
    HOME_DIR="$HOME"
fi

# Verifica pré-requisito
if ! docker inspect databases-central &>/dev/null; then
    die "databases-central não encontrado. Execute 04-databases-central.sh e 05-databases.sh primeiro."
fi

# ── n8n ───────────────────────────────────────────────────────────────
log_info "Configurando n8n..."
N8N_DIR="${HOME_DIR}/n8n"
mkdir -p "$N8N_DIR"

# Preserva chave de criptografia entre re-execuções
if [[ -f "${N8N_DIR}/.env" ]]; then
    N8N_ENCRYPTION_KEY=$(grep "^N8N_ENCRYPTION_KEY=" "${N8N_DIR}/.env" | cut -d= -f2-)
fi
[[ -z "${N8N_ENCRYPTION_KEY:-}" ]] && N8N_ENCRYPTION_KEY=$(openssl rand -hex 32)

cat > "${N8N_DIR}/.env" << EOF
N8N_HOST=${N8N_DOMAIN}
N8N_PORT=5678
N8N_PROTOCOL=https
NODE_ENV=production
WEBHOOK_URL=https://${N8N_DOMAIN}/
GENERIC_TIMEZONE=${N8N_TIMEZONE}
N8N_SECURE_COOKIE=${N8N_SECURE_COOKIE}
DB_TYPE=postgresdb
DB_POSTGRESDB_HOST=databases-central
DB_POSTGRESDB_PORT=5432
DB_POSTGRESDB_DATABASE=n8n
DB_POSTGRESDB_USER=${PG_USER}
DB_POSTGRESDB_PASSWORD=${PG_PASSWORD}
N8N_ENCRYPTION_KEY=${N8N_ENCRYPTION_KEY}
EOF
chmod 600 "${N8N_DIR}/.env"

USER_UID=$(id -u "${SUDO_USER:-$USER}")
USER_GID=$(id -g "${SUDO_USER:-$USER}")

mkdir -p "${N8N_DIR}/data"
chown -R "${USER_UID}:${USER_GID}" "${N8N_DIR}/data"

cat > "${N8N_DIR}/docker-compose.yml" << EOF
services:
  n8n:
    image: ${N8N_IMAGE}
    container_name: n8n
    user: "${USER_UID}:${USER_GID}"
    restart: unless-stopped
    env_file: .env
    ${DOCKER_LOG_CONFIG}
    ports:
      - "${PORT_N8N}:5678"
    deploy:
      resources:
        limits:
          memory: 700M
    volumes:
      - ./data:/home/node/.n8n
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
    networks:
      - ${DOCKER_NETWORK}

networks:
  ${DOCKER_NETWORK}:
    external: true
EOF

cd "$N8N_DIR" && docker compose up -d --remove-orphans
log_ok "n8n rodando na porta ${PORT_N8N}"
log_ok "Passo 06 concluído!"
