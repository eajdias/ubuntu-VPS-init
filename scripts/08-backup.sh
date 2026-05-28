#!/bin/bash
# =============================================================================
#  08-backup.sh — Backup Automático do Postgres Central
#  Execução única: cria o script de dump e agenda cron diário às 02:00
#  Faz backup apenas dos bancos que existem no momento da execução.
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"
source "${SCRIPT_DIR}/../00-config.env"

# --- Cores ---
GREEN='\033[0;32m'; CYAN='\033[0;36m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'
log_ok()      { echo -e "${GREEN}✔  $*${NC}"; }
log_info()    { echo -e "${CYAN}ℹ  $*${NC}"; }
log_section() {
  echo -e "\n${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${BLUE}${BOLD}  $*${NC}"
  echo -e "${BLUE}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

if [[ -n "${SUDO_USER:-}" ]]; then
    HOME_DIR="$(getent passwd "$SUDO_USER" | cut -d: -f6)"
else
    HOME_DIR="$HOME"
fi

BACKUP_BASE="${HOME_DIR}/backups"
BACKUP_DIR="${BACKUP_BASE}/postgres"
BACKUP_SCRIPT="${BACKUP_BASE}/do-backup.sh"
LOG_FILE="${BACKUP_BASE}/backup.log"
RETENTION_DAYS=7

log_section "Configurando Backup Automático do Postgres"
mkdir -p "$BACKUP_DIR"

# Descobre bancos existentes (exclui bancos internos do Postgres)
DATABASES=($(docker exec databases-central psql -U "$PG_USER" -tc \
    "SELECT datname FROM pg_database WHERE datistemplate = false AND datname != 'postgres'" \
    | tr -d ' ' | grep -v '^$'))

log_info "Bancos encontrados para backup: ${DATABASES[*]}"

# ── 1. Cria o script de backup (executado pelo cron) ──────────────────
cat > "$BACKUP_SCRIPT" << BACKUP_SCRIPT_EOF
#!/bin/bash
# Backup automático do Postgres — gerado por 08-backup.sh
set -euo pipefail

BACKUP_DIR="${BACKUP_DIR}"
RETENTION_DAYS=${RETENTION_DAYS}
PG_USER="${PG_USER}"
DATABASES=(${DATABASES[*]})
DATE=\$(date +%Y%m%d_%H%M%S)
LOG_PREFIX="[\$(date '+%Y-%m-%d %H:%M:%S')]"

if ! docker inspect databases-central &>/dev/null; then
    echo "\$LOG_PREFIX ERRO: container databases-central não encontrado." >&2
    exit 1
fi

mkdir -p "\$BACKUP_DIR"

for DB in "\${DATABASES[@]}"; do
    # Pula bancos que não existem mais
    if ! docker exec databases-central psql -U "\$PG_USER" -tc \
        "SELECT 1 FROM pg_database WHERE datname='\$DB'" | grep -q 1; then
        echo "\$LOG_PREFIX AVISO: banco '\$DB' não encontrado, pulando."
        continue
    fi

    OUT="\${BACKUP_DIR}/\${DB}_\${DATE}.sql.gz"
    TEMP_OUT="\${OUT}.tmp"
    if docker exec databases-central pg_dump -U "\$PG_USER" -d "\$DB" 2>/dev/null | gzip > "\$TEMP_OUT"; then
        if gzip -t "\$TEMP_OUT" 2>/dev/null; then
            mv "\$TEMP_OUT" "\$OUT"
            SIZE=\$(du -sh "\$OUT" | cut -f1)
            echo "\$LOG_PREFIX OK  \$DB → \$(basename "\$OUT") (\$SIZE)"
        else
            rm -f "\$TEMP_OUT"
            echo "\$LOG_PREFIX ERRO: dump de '\$DB' corrompido (arquivo removido)" >&2
        fi
    else
        rm -f "\$TEMP_OUT"
        echo "\$LOG_PREFIX ERRO ao fazer backup de '\$DB'" >&2
    fi
done

# Remove backups mais antigos que RETENTION_DAYS
REMOVED=\$(find "\$BACKUP_DIR" -name "*.sql.gz" -mtime +\${RETENTION_DAYS} -print -delete | wc -l)
[[ "\$REMOVED" -gt 0 ]] && echo "\$LOG_PREFIX Limpeza: \$REMOVED arquivo(s) expirado(s) removido(s)."
BACKUP_SCRIPT_EOF

chmod 700 "$BACKUP_SCRIPT"
log_ok "Script de backup criado: $BACKUP_SCRIPT"

# ── 2. Agenda cron diário às 02:00 ────────────────────────────────────
CRON_JOB="0 2 * * * $BACKUP_SCRIPT >> $LOG_FILE 2>&1"
(crontab -l 2>/dev/null | grep -v "do-backup.sh"; echo "$CRON_JOB") | crontab -
log_ok "Cron agendado: diariamente às 02:00 → log em $LOG_FILE"
log_info "Retenção: ${RETENTION_DAYS} dias | Bancos: ${DATABASES[*]}"

# ── 3. Executa o primeiro backup imediatamente ─────────────────────────
log_info "Executando primeiro backup agora..."
bash "$BACKUP_SCRIPT" | tee -a "$LOG_FILE"
log_ok "Passo 08 concluído! Backups em: $BACKUP_DIR"
