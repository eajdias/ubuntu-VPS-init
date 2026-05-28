#!/bin/bash
# =============================================================================
#  03-containers-core.sh — Containers Essenciais de Infraestrutura
#  Objetivo: Netdata, Filebrowser, Watchtower, Uptime Kuma, Dozzle
#  Nota: databases-central (Postgres) e redis-central são criados no passo 04.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/../00-config.env"

# --- Cores ---
GREEN='\033[0;32m'; CYAN='\033[0;36m'; NC='\033[0m'
log_ok() { echo -e "${GREEN}✔  $*${NC}"; }
log_info() { echo -e "${CYAN}ℹ  $*${NC}"; }

if [[ -n "${SUDO_USER:-}" ]]; then
    REAL_USER="$SUDO_USER"
    HOME_DIR="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
else
    REAL_USER="$USER"
    HOME_DIR="$HOME"
fi

# ── 1. Rede Docker ───────────────────────────────────────────────────
log_info "Configurando rede Docker: ${DOCKER_NETWORK}"
docker network ls --format '{{.Name}}' | grep -qx "$DOCKER_NETWORK" || docker network create "$DOCKER_NETWORK"

# ── 2. Netdata ────────────────────────────────────────────────────────
log_info "Configurando Netdata (métricas VPS + containers)..."
ND_DIR="${HOME_DIR}/netdata"
mkdir -p "$ND_DIR"

cat > "${ND_DIR}/docker-compose.yml" << EOF
services:
  netdata:
    image: ${NETDATA_IMAGE}
    container_name: netdata
    restart: unless-stopped
    pid: host
    network_mode: host
    cap_add:
      - SYS_PTRACE
      - SYS_ADMIN
    security_opt:
      - apparmor:unconfined
    ${DOCKER_LOG_CONFIG}
    deploy:
      resources:
        limits:
          memory: 150M
    volumes:
      - netdata_config:/etc/netdata
      - netdata_lib:/var/lib/netdata
      - netdata_cache:/var/cache/netdata
      - /etc/passwd:/host/etc/passwd:ro
      - /etc/group:/host/etc/group:ro
      - /etc/localtime:/etc/localtime:ro
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /etc/os-release:/host/etc/os-release:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
    labels:
      - "com.centurylinklabs.watchtower.enable=true"

volumes:
  netdata_config:
  netdata_lib:
  netdata_cache:
EOF

cd "$ND_DIR" && docker compose up -d --remove-orphans
log_ok "Netdata rodando na porta ${PORT_NETDATA} (CPU, RAM, disco, rede, containers)"

# ── 3. Filebrowser ───────────────────────────────────────────────────
log_info "Configurando Filebrowser (Mapeando HOME para gestão)..."
FB_DIR="${HOME_DIR}/filebrowser"
mkdir -p "$FB_DIR"

USER_UID=$(id -u "$REAL_USER")
USER_GID=$(id -g "$REAL_USER")

cat > "${FB_DIR}/docker-compose.yml" << EOF
services:
  filebrowser:
    image: ${FB_IMAGE}
    container_name: filebrowser
    user: "${USER_UID}:${USER_GID}"
    restart: unless-stopped
    ${DOCKER_LOG_CONFIG}
    environment:
      - FB_ADDRESS=0.0.0.0
      - FB_PORT=80
      - FB_DATABASE=/database/filebrowser.db
      - FB_ROOT=/srv
    ports:
      - "${PORT_FILEBROWSER}:80"
    deploy:
      resources:
        limits:
          memory: 128M
    volumes:
      - ${HOME_DIR}:/srv
      - ./fb_db:/database
      - ./config:/config
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
    networks:
      - ${DOCKER_NETWORK}

networks:
  ${DOCKER_NETWORK}:
    external: true
EOF

cd "$FB_DIR" && docker compose up -d --remove-orphans
log_ok "Filebrowser rodando na porta ${PORT_FILEBROWSER}. Gerenciando: ${HOME_DIR}"

# ── 4. Watchtower ─────────────────────────────────────────────────────
log_info "Configurando Watchtower (--label-enable: só atualiza containers marcados)..."
WT_DIR="${HOME_DIR}/watchtower"
mkdir -p "$WT_DIR"

cat > "${WT_DIR}/docker-compose.yml" << EOF
services:
  watchtower:
    image: ${WATCHTOWER_IMAGE}
    container_name: watchtower
    restart: unless-stopped
    ${DOCKER_LOG_CONFIG}
    environment:
      - DOCKER_API_VERSION=1.41
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    command: --cleanup --label-enable --interval ${WATCHTOWER_INTERVAL}
    networks:
      - ${DOCKER_NETWORK}
networks:
  ${DOCKER_NETWORK}:
    external: true
EOF

cd "$WT_DIR" && docker compose up -d --remove-orphans
log_ok "Watchtower configurado (--label-enable, verificando a cada ${WATCHTOWER_INTERVAL}s)"

# ── 5. Uptime Kuma ────────────────────────────────────────────────────
log_info "Configurando Uptime Kuma..."
UK_DIR="${HOME_DIR}/uptime-kuma"
mkdir -p "$UK_DIR"

cat > "${UK_DIR}/docker-compose.yml" << EOF
services:
  uptime-kuma:
    image: ${UPTIME_KUMA_IMAGE}
    container_name: uptime-kuma
    restart: unless-stopped
    ${DOCKER_LOG_CONFIG}
    ports:
      - "${PORT_UPTIME_KUMA}:3001"
    volumes:
      - ./data:/app/data
    deploy:
      resources:
        limits:
          memory: 150M
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
    networks:
      - ${DOCKER_NETWORK}

networks:
  ${DOCKER_NETWORK}:
    external: true
EOF

cd "$UK_DIR" && docker compose up -d --remove-orphans
log_ok "Uptime Kuma rodando na porta ${PORT_UPTIME_KUMA}"

# ── 6. Dozzle ─────────────────────────────────────────────────────────
log_info "Configurando Dozzle (log viewer)..."
DZ_DIR="${HOME_DIR}/dozzle"
mkdir -p "$DZ_DIR"

cat > "${DZ_DIR}/docker-compose.yml" << EOF
services:
  dozzle:
    image: ${DOZZLE_IMAGE}
    container_name: dozzle
    restart: unless-stopped
    ${DOCKER_LOG_CONFIG}
    ports:
      - "${PORT_DOZZLE}:8080"
    environment:
      - DOZZLE_LEVEL=info
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
    deploy:
      resources:
        limits:
          memory: 32M
    labels:
      - "com.centurylinklabs.watchtower.enable=true"
    networks:
      - ${DOCKER_NETWORK}

networks:
  ${DOCKER_NETWORK}:
    external: true
EOF

cd "$DZ_DIR" && docker compose up -d --remove-orphans
log_ok "Dozzle rodando na porta ${PORT_DOZZLE}"

log_ok "Passo 03 concluído com sucesso!"
