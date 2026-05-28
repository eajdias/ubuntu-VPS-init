#!/bin/bash
# =============================================================================
#  05-databases.sh — Provisionamento de Bancos (Postgres + Redis)
#  Uso: sudo bash 05-databases.sh <serviço> [serviço2 ...]
#  Serviços disponíveis: n8n, chatwoot, evolution
#
#  Para cada serviço, provisiona:
#    - Postgres: cria o banco e instala extensões necessárias
#    - Redis: verifica/ativa o logical database correspondente (se aplicável)
#
#  Idempotente: pode ser re-executado sem efeitos colaterais.
#  Se databases-central ou redis-central não existirem, são criados automaticamente.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/../00-config.env"

# --- Cores ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
log_ok()   { echo -e "${GREEN}✔  $*${NC}"; }
log_info() { echo -e "${CYAN}ℹ  $*${NC}"; }
log_warn() { echo -e "${YELLOW}⚠  $*${NC}"; }
die()      { echo -e "${RED}✘  $*${NC}" >&2; exit 1; }

if [[ -n "${SUDO_USER:-}" ]]; then
    HOME_DIR="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
else
    HOME_DIR="$HOME"
fi

# ── Mapeamento: serviço → postgres db ────────────────────────────────
pg_db_for() {
    case "$1" in
        n8n|chatwoot|evolution) echo "$1" ;;
        *) echo "" ;;
    esac
}

# ── Mapeamento: serviço → redis logical db (vazio = não usa Redis) ────
redis_db_for() {
    case "$1" in
        chatwoot)  echo "${REDIS_DB_CHATWOOT}" ;;
        evolution) echo "${REDIS_DB_EVOLUTION}" ;;
        *)         echo "" ;;
    esac
}

# ── Garante databases-central rodando ────────────────────────────────
_pg_ready=false
ensure_databases_central() {
    [[ "$_pg_ready" == true ]] && return

    local status
    status=$(docker inspect --format '{{.State.Status}}' databases-central 2>/dev/null || echo "ausente")

    if [[ "$status" == "ausente" ]]; then
        log_warn "databases-central não encontrado. Executando 04-databases-central.sh..."
        bash "${SCRIPT_DIR}/04-databases-central.sh"
        _pg_ready=true
        return
    fi

    if [[ "$status" != "running" ]]; then
        log_warn "databases-central está '${status}'. Iniciando..."
        docker start databases-central
    fi

    log_info "Aguardando databases-central..."
    until docker exec databases-central pg_isready -U "$PG_USER" &>/dev/null; do
        printf '.'; sleep 2
    done
    echo ""
    log_ok "databases-central operacional."

    # Sincroniza a senha do Postgres (caso o volume seja antigo e a senha no .env tenha mudado)
    docker exec databases-central psql -U "$PG_USER" -c "ALTER USER \"$PG_USER\" WITH PASSWORD \$\$${PG_PASSWORD}\$\$;" > /dev/null
    
    _pg_ready=true
}

# ── Garante redis-central rodando ─────────────────────────────────────
_redis_ready=false
ensure_redis_central() {
    [[ "$_redis_ready" == true ]] && return

    local status
    status=$(docker inspect --format '{{.State.Status}}' redis-central 2>/dev/null || echo "ausente")

    if [[ "$status" == "ausente" ]]; then
        log_warn "redis-central não encontrado. Executando 04-databases-central.sh..."
        bash "${SCRIPT_DIR}/04-databases-central.sh"
        _redis_ready=true
        return
    fi

    if [[ "$status" != "running" ]]; then
        log_warn "redis-central está '${status}'. Iniciando..."
        docker start redis-central
    fi

    log_info "Aguardando redis-central..."
    until docker exec redis-central redis-cli ping &>/dev/null; do
        printf '.'; sleep 2
    done
    echo ""
    log_ok "redis-central operacional."
    _redis_ready=true
}

# ── Cria banco Postgres se não existir ───────────────────────────────
create_pg_db() {
    local db="$1"
    if docker exec databases-central psql -U "$PG_USER" -tc \
        "SELECT 1 FROM pg_database WHERE datname='${db}'" | grep -q 1; then
        log_info "  Postgres: banco '${db}' já existe."
    else
        docker exec databases-central psql -U "$PG_USER" -c "CREATE DATABASE ${db}" > /dev/null
        log_ok "  Postgres: banco '${db}' criado."
    fi
}

# ── Instala extensões Postgres por serviço ────────────────────────────
setup_pg_extensions() {
    local service="$1" db="$2"
    case "$service" in
        chatwoot)
            docker exec databases-central psql -U "$PG_USER" -d "$db" \
                -c "CREATE EXTENSION IF NOT EXISTS vector; CREATE EXTENSION IF NOT EXISTS pgcrypto;" > /dev/null
            log_ok "  Postgres: extensões 'vector' e 'pgcrypto' ativas em '${db}'."
            ;;
        evolution)
            docker exec databases-central psql -U "$PG_USER" -d "$db" \
                -c "CREATE EXTENSION IF NOT EXISTS pgcrypto;" > /dev/null
            log_ok "  Postgres: extensão 'pgcrypto' ativa em '${db}'."
            ;;
    esac
}

# ── Verifica/ativa logical database Redis ────────────────────────────
provision_redis_db() {
    local service="$1" db_num="$2"
    if docker exec redis-central redis-cli -n "$db_num" ping 2>/dev/null | grep -q "PONG"; then
        log_ok "  Redis: logical db ${db_num} (${service}) acessível."
    else
        log_warn "  Redis: falha ao verificar db ${db_num} (${service})."
    fi
}

# ── Provisiona um serviço completo ────────────────────────────────────
provision_service() {
    local service="$1"
    echo ""
    log_info "Provisionando: ${service}"

    local pg_db redis_db
    pg_db=$(pg_db_for "$service")
    redis_db=$(redis_db_for "$service")

    if [[ -z "$pg_db" && -z "$redis_db" ]]; then
        die "Serviço desconhecido: '${service}'. Disponíveis: n8n, chatwoot, evolution"
    fi

    if [[ -n "$pg_db" ]]; then
        ensure_databases_central
        create_pg_db "$pg_db"
        setup_pg_extensions "$service" "$pg_db"
    fi

    if [[ -n "$redis_db" ]]; then
        ensure_redis_central
        provision_redis_db "$service" "$redis_db"
    fi

    log_ok "Serviço '${service}' provisionado."
}

# ── Execução ──────────────────────────────────────────────────────────
if [[ $# -eq 0 ]]; then
    die "Uso: $(basename "$0") <serviço> [serviço2 ...]\nDisponíveis: n8n, chatwoot, evolution"
fi

for service in "$@"; do
    provision_service "$service"
done

echo ""
log_ok "Passo 05 concluído! Serviços provisionados: $*"
