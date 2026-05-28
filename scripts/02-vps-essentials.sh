#!/bin/bash
# =============================================================================
#  02-vps-essentials.sh — Instalações Essenciais (Docker & Cloudflared)
#  Objetivo: Preparar o ambiente para containers e túnel
# =============================================================================

set -euo pipefail

# --- Cores ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

log_info()    { echo -e "${CYAN}ℹ  $*${NC}"; }
log_ok()      { echo -e "${GREEN}✔  $*${NC}"; }
log_error()   { echo -e "${RED}✘  $*${NC}" >&2; }
log_section() {
  echo -e "\n${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}${BOLD}  $*${NC}"
  echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

if [[ $EUID -ne 0 ]]; then
  log_error "Execute como root ou via: sudo $0"
  exit 1
fi

REAL_USER="${SUDO_USER:-$USER}"

# ── 1. Docker ─────────────────────────────────────────────────────────
log_section "🐳 Instalando Docker"
if ! command -v docker &>/dev/null; then
  source /etc/os-release
  UBUNTU_CODENAME=$(grep "UBUNTU_CODENAME=" /etc/os-release | cut -d= -f2 || echo "")
  [[ -z "$UBUNTU_CODENAME" ]] && UBUNTU_CODENAME="$VERSION_CODENAME"

  log_info "Detectado codename: $UBUNTU_CODENAME"
  
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL "https://download.docker.com/linux/ubuntu/gpg" | gpg --dearmor --yes -o /etc/apt/keyrings/docker.gpg
  chmod a+r /etc/apt/keyrings/docker.gpg

  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${UBUNTU_CODENAME} stable" \
    | tee /etc/apt/sources.list.d/docker.list > /dev/null

  apt-get update -qq
  apt-get install -y -qq --no-install-recommends docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  log_ok "Docker instalado com sucesso."
else
  log_ok "Docker já está instalado."
fi

log_info "Configurando Docker daemon (live-restore + logs padrão)..."
mkdir -p /etc/docker
cat > /etc/docker/daemon.json << 'EOF'
{
  "live-restore": true,
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
log_ok "daemon.json configurado (live-restore ativo)."

systemctl enable --now docker 2>/dev/null || true
getent group docker &>/dev/null || groupadd docker
usermod -aG docker "$REAL_USER"

# ── 2. Cloudflare Tunnel (cloudflared) ────────────────────────────────
log_section "☁  Instalando Cloudflare Tunnel"
if ! command -v cloudflared &>/dev/null; then
    mkdir -p -m 0755 /usr/share/keyrings
    curl -fsSL https://pkg.cloudflare.com/cloudflare-public-v2.gpg | gpg --dearmor --yes -o /usr/share/keyrings/cloudflare-public-v2.gpg
    echo 'deb [signed-by=/usr/share/keyrings/cloudflare-public-v2.gpg] https://pkg.cloudflare.com/cloudflared any main' | tee /etc/apt/sources.list.d/cloudflared.list
    apt-get update -qq
    apt-get install -y -qq cloudflared
    log_ok "cloudflared instalado: $(cloudflared --version)"
else
    log_ok "cloudflared já está instalado."
fi

# ── 3. Docker Cleanup Cron (Manutenção de Disco) ──────────────────────
log_section "🧹 Configurando Limpeza Automática do Docker"
CRON_JOB="0 3 * * * /usr/bin/docker system prune -af > /dev/null 2>&1"
(crontab -l 2>/dev/null | grep -v "docker system prune" || true; echo "$CRON_JOB") | crontab -
log_ok "Cron de limpeza (daily @ 03:00) configurado."

log_ok "Passo 02 concluído com sucesso!"
log_info "Aviso: Você deve deslogar e logar novamente (ou reiniciar) para que as permissões de grupo do Docker tenham efeito."
