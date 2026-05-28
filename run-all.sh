#!/bin/bash
# =============================================================================
#  run-all.sh — Orquestrador Interativo da Stack VPS
# =============================================================================

set -euo pipefail

# Garante que o stdin está conectado ao terminal para interatividade
if [ ! -t 0 ]; then
    exec < /dev/tty
fi

# --- Diretórios ---
ROOT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
SCRIPT_DIR="${ROOT_DIR}/scripts"
cd "$ROOT_DIR"

# --- Cores e Estilo ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; MAGENTA='\033[0;35m'; CYAN='\033[0;36m'
BOLD='\033[1m'; NC='\033[0m'

header() {
    clear
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}             🚀 STACK VPS — INSTALAÇÃO E SETUP             ${NC}"
    echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

log_step()    { echo -e "${MAGENTA}${BOLD}➜${NC} ${BOLD}$*${NC}"; }
log_section() {
  echo -e "\n${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}${BOLD}  $*${NC}"
  echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

ask() {
    echo -ne "${BOLD}${CYAN}❓ $* [s/N]${NC} "
    read -r _ans
    [[ "$_ans" =~ ^([sS][iI]?|[sS])$ ]]
}

edit_env() {
    local var_name=$1
    local prompt_text=$2
    local current_val=$(grep "^${var_name}=" 00-config.env 2>/dev/null | cut -d'"' -f2 || echo "")
    
    echo -ne "${CYAN}${prompt_text}${NC} [${YELLOW}${current_val}${NC}]: "
    read -r new_val
    
    if [ -n "$new_val" ]; then
        if grep -q "^${var_name}=" 00-config.env; then
            sed -i "s|^${var_name}=.*|${var_name}=\"${new_val}\"|" 00-config.env
        else
            echo "${var_name}=\"${new_val}\"" >> 00-config.env
        fi
    fi
}

# ── 1. Configuração Interativa ────────────────────────────────────────
header
if [ ! -f "00-config.env" ]; then
    echo -e "${RED}❌ Erro: Arquivo 00-config.env não encontrado.${NC}"
    exit 1
fi

log_step "Definição do Ambiente"
echo -e "Selecione o ambiente para esta instalação:"
echo -e "1) ${CYAN}Teste${NC}"
echo -e "2) ${CYAN}Produção${NC}"
echo -e "3) ${CYAN}Padrão${NC}"
echo -ne "\nEscolha (1-3): "
read -r env_choice || env_choice="3"

BASE_DOMAIN=""
case "${env_choice:-3}" in
    1)
        echo -ne "Digite o domínio base (ex: eajdias.com): "
        read -r domain_base || domain_base="exemplo.com"
        BASE_DOMAIN="teste-beszel.${domain_base}"
        ;;
    2)
        echo -ne "Deseja adicionar um sub-nome ao domínio? (ex: zscan): "
        read -r subname || subname=""
        echo -ne "Digite o domínio base (ex: eajdias.com): "
        read -r domain_base || domain_base="exemplo.com"
        if [ -n "$subname" ]; then
            BASE_DOMAIN="${subname}-beszel.${domain_base}"
        else
            BASE_DOMAIN="beszel.${domain_base}"
        fi
        ;;
    *)
        echo -ne "Digite o domínio base (ex: exemplo.com): "
        read -r BASE_DOMAIN || BASE_DOMAIN="exemplo.com"
        ;;
esac

if [ -n "$BASE_DOMAIN" ]; then
    if grep -q "^BASE_DOMAIN=" 00-config.env; then
        sed -i "s|^BASE_DOMAIN=.*|BASE_DOMAIN=\"${BASE_DOMAIN}\"|" 00-config.env
    else
        echo "BASE_DOMAIN=\"${BASE_DOMAIN}\"" >> 00-config.env
    fi
    echo -e "${GREEN}✅ Domínio configurado como: ${BASE_DOMAIN}${NC}"
fi

log_step "Configuração de Variáveis (00-config.env)"
echo -e "Pressione ${BOLD}ENTER${NC} para manter o valor padrão entre colchetes.\n"

edit_env "PG_PASSWORD" "Senha do Banco de Dados (Postgres)"
edit_env "EVO_API_KEY" "Chave da API Evolution"
edit_env "FB_PASSWORD" "Senha do FileBrowser"

echo -e "\n${GREEN}✅ Configurações básicas salvas!${NC}"
if ask "Deseja abrir o arquivo completo para revisão manual (nano)?"; then
    nano 00-config.env
fi

# ── 2. Perguntas Upfront ──────────────────────────────────────────────
header
log_step "Seleção de Componentes Opcionais"

WANT_N8N=false
WANT_COMM=false
WANT_BACKUP=false
WANT_DB=false

if ask "Instalar n8n (Automação de Workflows)?"; then
    WANT_N8N=true
fi
if ask "Instalar Stack de Comunicação (Chatwoot & Evolution)?"; then
    WANT_COMM=true
fi
if ask "Configurar backup automático diário do Postgres?"; then
    WANT_BACKUP=true
fi

# Regra de dependência: se quer 6, 7 ou 8, obrigatoriamente precisa de 4 e 5
if [[ "$WANT_N8N" == true || "$WANT_COMM" == true || "$WANT_BACKUP" == true ]]; then
    WANT_DB=true
    echo -e "${YELLOW}ℹ  Componentes selecionados dependem dos Bancos de Dados (scripts 04 e 05).${NC}"
    echo -e "${YELLOW}   Eles serão instalados automaticamente.${NC}"
else
    if ask "Instalar Bancos de Dados Centrais (Postgres/Redis)? [Scripts 04 e 05]"; then
        WANT_DB=true
    fi
fi

echo -e "\n${GREEN}Iniciando a instalação em 3 segundos...${NC}"
sleep 3

# ── 3. Execução dos Scripts ───────────────────────────────────────────
chmod +x "${SCRIPT_DIR}"/*.sh

# Scripts Obrigatórios (01, 02, 03)
for script in 01-vps-config.sh 02-vps-essentials.sh 03-containers-core.sh; do
    log_section "Executando: ${script}"
    "${SCRIPT_DIR}/${script}"
done

# Scripts Opcionais: Bancos de Dados (04 e 05)
if [[ "$WANT_DB" == true ]]; then
    log_section "Executando: 04-databases-central.sh"
    "${SCRIPT_DIR}/04-databases-central.sh"

    DBS=()
    [[ "$WANT_N8N" == true ]] && DBS+=(n8n)
    [[ "$WANT_COMM" == true ]] && DBS+=(chatwoot evolution)
    
    log_section "Executando: 05-databases.sh"
    if [[ ${#DBS[@]} -gt 0 ]]; then
        "${SCRIPT_DIR}/05-databases.sh" "${DBS[@]}"
    else
        echo -e "${YELLOW}⏩ Nenhum banco de dados específico para provisionar no momento.${NC}"
    fi
else
    echo -e "${YELLOW}⏩ Pulando Bancos de Dados (Scripts 04 e 05).${NC}"
fi

# n8n (06)
if [[ "$WANT_N8N" == true ]]; then
    log_section "Executando: 06-n8n.sh"
    "${SCRIPT_DIR}/06-n8n.sh"
else
    echo -e "${YELLOW}⏩ Pulando n8n (Script 06).${NC}"
fi

# Comunicação (07)
if [[ "$WANT_COMM" == true ]]; then
    log_section "Executando: 07-communication.sh"
    "${SCRIPT_DIR}/07-communication.sh"
else
    echo -e "${YELLOW}⏩ Pulando Comunicação (Script 07).${NC}"
fi

# Backup (08)
if [[ "$WANT_BACKUP" == true ]]; then
    log_section "Executando: 08-backup.sh"
    "${SCRIPT_DIR}/08-backup.sh"
else
    echo -e "${YELLOW}⏩ Pulando Backup (Script 08).${NC}"
fi

# ── 4. Verificação Final ──────────────────────────────────────────────
log_section "Verificação da Stack"

pass=0; fail=0
check_container() {
    local name="$1"
    local status=$(docker inspect --format '{{.State.Status}}' "$name" 2>/dev/null || echo "ausente")
    if [[ "$status" == "running" ]]; then
        echo -e "  ${GREEN}✔${NC}  $name"
        ((pass++)) || true
    else
        # Não conta como falha se o container não deveria estar lá
        if [[ "$status" == "ausente" ]]; then
            return
        fi
        echo -e "  ${RED}✘${NC}  $name  ${YELLOW}(${status})${NC}"
        ((fail++)) || true
    fi
}

echo -e "\n  ${BOLD}Base (Core)${NC}"
for c in netdata filebrowser watchtower uptime-kuma dozzle; do
    check_container "$c"
done

if [[ "$WANT_DB" == true ]]; then
    echo -e "\n  ${BOLD}Bancos de Dados${NC}"
    for c in databases-central redis-central; do
        check_container "$c"
    done
fi

if [[ "$WANT_N8N" == true ]]; then
    echo -e "\n  ${BOLD}Automação${NC}"
    check_container "n8n"
fi

if [[ "$WANT_COMM" == true ]]; then
    echo -e "\n  ${BOLD}Comunicação${NC}"
    for c in evolution-api chatwoot-app chatwoot-worker; do
        check_container "$c"
    done
fi

echo ""
if [[ $fail -eq 0 ]]; then
    echo -e "${BOLD}${GREEN}✅ Instalação concluída! Todos os ${pass} containers estão rodando.${NC}"
else
    echo -e "${BOLD}${YELLOW}⚠  ${pass} OK · ${fail} com problema. Verifique com: docker ps -a${NC}"
fi
