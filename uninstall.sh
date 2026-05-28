#!/bin/bash
# =============================================================================
#  uninstall.sh — Script para remover tudo e limpar a VPS
#  AVISO: ISSO APAGARÁ TODOS OS DADOS, CONTAINERS E CONFIGURAÇÕES DA STACK!
# =============================================================================

set -euo pipefail

# --- Cores ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log_info() { echo -e "${CYAN}ℹ  $*${NC}"; }
log_warn() { echo -e "${YELLOW}⚠  $*${NC}"; }
log_ok()   { echo -e "${GREEN}✔  $*${NC}"; }

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Este script precisa ser executado como root (sudo).${NC}" 
   exit 1
fi

if [[ -n "${SUDO_USER:-}" ]]; then
    HOME_DIR="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
else
    HOME_DIR="$HOME"
fi

echo -e "${RED}====================================================================${NC}"
echo -e "${RED} AVISO: VOCÊ ESTÁ PRESTES A EXCLUIR TODOS OS DADOS E CONTAINERS!${NC}"
echo -e "${RED} Isso inclui bancos de dados (Postgres, Redis), N8N, Chatwoot, etc.${NC}"
echo -e "${RED} (Os backups na pasta ~/backups NÃO serão excluídos por padrão)${NC}"
echo -e "${RED}====================================================================${NC}"
read -rp "Tem certeza absoluta que deseja continuar? (digite 'SIM' para confirmar): " CONFIRM </dev/tty
if [[ "$CONFIRM" != "SIM" ]]; then
    echo "Operação cancelada."
    exit 0
fi

# Tenta carregar a configuração para obter o nome da rede, se existir
SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
if [[ -f "${SCRIPT_DIR}/00-config.env" ]]; then
    source "${SCRIPT_DIR}/00-config.env"
fi
DOCKER_NETWORK="${DOCKER_NETWORK:-proxy-network}"

# Lista de diretórios das aplicações (criados na home do usuário)
DIRS=(
    "databases-central"
    "redis-central"
    "netdata"
    "filebrowser"
    "watchtower"
    "uptime-kuma"
    "dozzle"
    "evolution"
    "chatwoot"
    "n8n"
)

log_info "Parando containers e removendo volumes associados..."
for dir in "${DIRS[@]}"; do
    TARGET_DIR="${HOME_DIR}/${dir}"
    if [[ -d "$TARGET_DIR" && -f "${TARGET_DIR}/docker-compose.yml" ]]; then
        log_info "Desmontando stack em ${TARGET_DIR}..."
        (cd "$TARGET_DIR" && docker compose down -v --remove-orphans 2>/dev/null || true)
    fi
done

# Parando de forma global caso algum não estivesse na pasta (fallback)
log_info "Parando e removendo quaisquer containers restantes da stack..."
docker ps -a --format '{{.Names}}' | grep -E '^(databases-central|redis-central|evolution-api|chatwoot-app|chatwoot-worker|n8n|filebrowser|netdata|uptime-kuma|dozzle|watchtower)$' | xargs -r docker rm -f -v 2>/dev/null || true

log_info "Removendo arquivos e pastas das aplicações..."
for dir in "${DIRS[@]}"; do
    TARGET_DIR="${HOME_DIR}/${dir}"
    if [[ -d "$TARGET_DIR" ]]; then
        rm -rf "$TARGET_DIR"
        log_ok "Diretório ${TARGET_DIR} removido."
    fi
done

log_info "Removendo rede Docker (${DOCKER_NETWORK})..."
docker network rm "$DOCKER_NETWORK" 2>/dev/null || log_warn "Rede ${DOCKER_NETWORK} não encontrada ou já removida."

log_info "Limpando volumes órfãos do Docker..."
docker volume prune -f

log_ok "Desinstalação e limpeza concluídas com sucesso!"
echo -e "${CYAN}Nota: As imagens Docker não foram excluídas para que uma reinstalação seja mais rápida.${NC}"
echo -e "Você pode rodar ${GREEN}sudo bash run-all.sh${NC} novamente para reinstalar do zero."