#!/bin/bash
# =============================================================================
#  99-optimize-performance.sh — Otimizador Dinâmico de Recursos
#  Objetivo: Ajustar limites de RAM e performance com base na VPS atual
#  Uso: sudo bash 99-optimize-performance.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/../00-config.env"

# --- Cores ---
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'
log_ok()   { echo -e "${GREEN}✔  $*${NC}"; }
log_info() { echo -e "${CYAN}ℹ  $*${NC}"; }
log_warn() { echo -e "${YELLOW}⚠  $*${NC}"; }

# --- Detecção de Memória ---
TOTAL_RAM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_RAM_GB=$(( (TOTAL_RAM_KB / 1024 / 1024) + 1 )) # Arredonda pra cima

log_info "Detectada VPS com aproximadamente ${TOTAL_RAM_GB}GB de RAM."

# --- Lógica de Tuning ---
if [ "$TOTAL_RAM_GB" -le 2 ]; then
    MODE="ECO"
    PG_BUFFERS="128MB"
    CW_CONCURRENCY=0
    CW_MAX_THREADS=5
    CW_MEM_LIMIT="1G"
    N8N_MEM_LIMIT="700M"
    N8N_PRUNE="true"
elif [ "$TOTAL_RAM_GB" -le 4 ]; then
    MODE="BALANCED"
    PG_BUFFERS="512MB"
    CW_CONCURRENCY=1
    CW_MAX_THREADS=10
    CW_MEM_LIMIT="1.5G"
    N8N_MEM_LIMIT="1G"
    N8N_PRUNE="true"
else
    MODE="PERFORMANCE"
    PG_BUFFERS="1GB"
    CW_CONCURRENCY=2
    CW_MAX_THREADS=15
    CW_MEM_LIMIT="3G"
    N8N_MEM_LIMIT="2G"
    N8N_PRUNE="false"
fi

log_ok "Aplicando perfil: ${BOLD}${MODE}${NC}"

# 1. Ajuste Postgres (shared_buffers)
if docker inspect databases-central &>/dev/null; then
    log_info "Ajustando Postgres para shared_buffers=${PG_BUFFERS}..."
    # Atualiza o comando no docker-compose do Postgres
    PG_COMPOSE="${HOME}/databases-central/docker-compose.yml"
    if [ -f "$PG_COMPOSE" ]; then
        sed -i "s|command:.*|command: [\"postgres\", \"-c\", \"shared_preload_libraries=pg_cron\", \"-c\", \"cron.database_name=postgres\", \"-c\", \"shared_buffers=${PG_BUFFERS}\"]|" "$PG_COMPOSE"
        cd "$(dirname "$PG_COMPOSE")" && docker compose up -d
    fi
fi

# 2. Ajuste Chatwoot (Concurrency & Threads)
CW_ENV="${HOME}/chatwoot/.env"
CW_COMPOSE="${HOME}/chatwoot/docker-compose.yml"
if [ -f "$CW_ENV" ]; then
    log_info "Ajustando Chatwoot: Concurrency=${CW_CONCURRENCY}, Threads=${CW_MAX_THREADS}..."
    sed -i "/^WEB_CONCURRENCY=/d" "$CW_ENV"
    sed -i "/^RAILS_MAX_THREADS=/d" "$CW_ENV"
    echo "WEB_CONCURRENCY=${CW_CONCURRENCY}" >> "$CW_ENV"
    echo "RAILS_MAX_THREADS=${CW_MAX_THREADS}" >> "$CW_ENV"
    
    if [ -f "$CW_COMPOSE" ]; then
        sed -i "/container_name: chatwoot-app/,/memory:/ s/memory: .*/memory: ${CW_MEM_LIMIT}/" "$CW_COMPOSE"
    fi
    cd "$(dirname "$CW_ENV")" && docker compose up -d
fi

# 3. Ajuste n8n (Pruning & Memory)
N8N_ENV="${HOME}/n8n/.env"
N8N_COMPOSE="${HOME}/n8n/docker-compose.yml"
if [ -f "$N8N_ENV" ]; then
    log_info "Ajustando n8n: Pruning=${N8N_PRUNE}..."
    sed -i "/^EXECUTIONS_DATA_PRUNE=/d" "$N8N_ENV"
    echo "EXECUTIONS_DATA_PRUNE=${N8N_PRUNE}" >> "$N8N_ENV"
    
    if [ -f "$N8N_COMPOSE" ]; then
        sed -i "s/memory: .*/memory: ${N8N_MEM_LIMIT}/" "$N8N_COMPOSE"
    fi
    cd "$(dirname "$N8N_ENV")" && docker compose up -d
fi

log_ok "Otimização concluída com sucesso para o perfil ${MODE}!"
