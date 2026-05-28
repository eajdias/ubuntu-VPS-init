#!/bin/bash
# =============================================================================
#  01-vps-config.sh — Configurações Básicas da VPS
#  Objetivo: Atualização, Swap, Kernel e Segurança Inicial
#  Ideal para instâncias de 1GB RAM
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

export DEBIAN_FRONTEND=noninteractive

if [[ $EUID -ne 0 ]]; then
  log_error "Execute como root ou via: sudo $0"
  exit 1
fi

# ── 1. Atualização do sistema ─────────────────────────────────────────
log_section "🚀 Atualizando sistema"
apt-get update -qq
apt-get upgrade -y -qq
log_ok "Sistema atualizado."

# ── 2. Pacotes essenciais ──────────────────────────────────────────────
log_section "📦 Pacotes essenciais"
ESSENTIAL_PACKAGES=(ca-certificates curl wget gnupg git unzip lsb-release software-properties-common apt-transport-https htop net-tools vim jq logrotate cron fail2ban)
apt-get install -y -qq --no-install-recommends "${ESSENTIAL_PACKAGES[@]}"
log_ok "Pacotes essenciais instalados."

# ── 3. Swap (Garante 4GB - Vital para VPS de 1GB RAM) ──────────────────
log_section "💾 Configurando Swap"
CURRENT_SWAP_KB=$(awk '/SwapTotal/ {print $2}' /proc/meminfo)
REQUIRED_SWAP_KB=$((4 * 1024 * 1024))

if [[ "$CURRENT_SWAP_KB" -lt "$REQUIRED_SWAP_KB" ]]; then
  log_info "Criando swapfile de 4GB..."
  swapoff -a 2>/dev/null || true
  if ! fallocate -l 4G /swapfile 2>/dev/null; then
    dd if=/dev/zero of=/swapfile bs=1M count=4096 status=none
  fi
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  sed -i '/\/swapfile/d' /etc/fstab
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
  log_ok "Swapfile de 4GB criado e ativado."
else
  log_ok "Swap suficiente encontrado ($((CURRENT_SWAP_KB/1024)) MB)."
fi

# ── 4. Parâmetros de kernel (Otimização) ─────────────────────────────
log_section "⚙  Parâmetros de kernel"
apply_sysctl() {
  local key="$1" val="$2"
  sysctl -w "${key}=${val}" > /dev/null
  sed -i "/^${key}=/d" /etc/sysctl.conf
  echo "${key}=${val}" >> /etc/sysctl.conf
}
apply_sysctl vm.swappiness 10
apply_sysctl vm.vfs_cache_pressure 50
apply_sysctl net.core.somaxconn 65535
apply_sysctl net.core.netdev_max_backlog 5000
apply_sysctl net.ipv4.tcp_fin_timeout 15
apply_sysctl net.ipv4.ip_local_port_range "1024 65535"
apply_sysctl fs.file-max 200000
log_ok "Parâmetros de kernel otimizados."

# ── 5. Timezone do Sistema ────────────────────────────────────────────
log_section "🕐 Timezone do Sistema"
timedatectl set-timezone America/Sao_Paulo
log_ok "Timezone: $(timedatectl show --property=Timezone --value)"

# ── 5.5 Limites de File Descriptors ──────────────────────────────────
log_section "📂 Limites de Arquivo (ulimits)"
cat > /etc/security/limits.d/99-production.conf << 'EOF'
* soft nofile 65536
* hard nofile 65536
EOF
log_ok "Limite de file descriptors: 65536"

# ── 6. Limite de Logs do Sistema (Journald) ───────────────────────────
log_section "📝 Limitando Logs do Sistema"
mkdir -p /etc/systemd/journald.conf.d
cat > /etc/systemd/journald.conf.d/limit.conf << EOF
[Journal]
SystemMaxUse=100M
RuntimeMaxUse=50M
EOF
systemctl restart systemd-journald
log_ok "Logs do Journald limitados a 100MB."

# ── 6. Debloat e fail2ban ──────────────────────────────────────────────
log_section "🧹 Debloat & Segurança"
SAFE_REMOVE=(modemmanager rpcbind avahi-daemon cups bluetooth bluez)
for pkg in "${SAFE_REMOVE[@]}"; do
  apt-get purge -y -qq "$pkg" 2>/dev/null || true
done

JAIL_LOCAL="/etc/fail2ban/jail.local"
if [[ ! -f "$JAIL_LOCAL" ]]; then
  cat > "$JAIL_LOCAL" << 'JAIL'
[DEFAULT]
bantime  = 3600
findtime = 600
maxretry = 5

[sshd]
enabled = true

[recidive]
enabled   = true
logpath   = /var/log/fail2ban.log
banaction = iptables-allports
bantime   = 86400
findtime  = 86400
maxretry  = 5
JAIL
  systemctl enable --now fail2ban 2>/dev/null || true
fi
log_ok "Debloat e fail2ban configurados."

# ── Limpeza final ─────────────────────────────────────────────────────
apt-get autoremove -y -qq >/dev/null
apt-get clean
log_ok "Passo 01 concluído com sucesso!"
