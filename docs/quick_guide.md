# Guia Rápido de Configuração — Stack VPS

Este guia detalha como executar os scripts de provisionamento e o que cada componente da stack faz.

## Execução

```bash
# Instalação completa (interativo)
sudo bash run-all.sh

# Ou passo a passo (via pasta scripts)
sudo bash scripts/01-vps-config.sh
sudo bash scripts/02-vps-essentials.sh
sudo bash scripts/03-containers-core.sh
sudo bash scripts/04-databases-central.sh
sudo bash scripts/05-databases.sh n8n              # sempre necessário
sudo bash scripts/05-databases.sh chatwoot evolution  # se for instalar comunicação
sudo bash scripts/06-n8n.sh
sudo bash scripts/07-communication.sh             # opcional
sudo bash scripts/08-backup.sh                    # opcional
```

> **Importante:** Edite `00-config.env` antes de executar. Todos os scripts lêem esse arquivo para obter domínios, senhas e configurações.

---

## Detalhes dos Scripts

### `00-config.env` — Configuração Central
Único arquivo a ser editado. Define domínios, senhas, portas e imagens Docker usadas por todos os scripts. Centralizar aqui evita inconsistências entre passos.

### `01-vps-config.sh` — Base do Sistema
Prepara o SO para rodar uma stack de produção em VPS de baixo recurso (1–2GB RAM):

- **Atualização e pacotes essenciais** — ferramentas de diagnóstico e segurança (`htop`, `fail2ban`, `jq`, `git`, etc.)
- **Swap de 4GB** — crítico para VPS de 1GB RAM.
- **Parâmetros de kernel** — otimizações de rede e memória.
- **Timezone** — define `America/Sao_Paulo`.
- **Ulimits** — eleva o limite de file descriptors para 65536.
- **Journald** — limita logs do sistema a 100MB.
- **Debloat** — remove serviços desnecessários.
- **fail2ban** — proteção contra brute force SSH.

### `02-vps-essentials.sh` — Docker e Cloudflare
- **Docker** — instalado via repositório oficial.
- **daemon.json** — configura `live-restore` e log rotation.
- **Cloudflare Tunnel** (`cloudflared`) — expõe os serviços sem abrir portas no firewall.
- **Cron de limpeza Docker** — `docker system prune` diário.

### `03-containers-core.sh` — Infraestrutura Base
Containers de utilidade como Netdata, Filebrowser, Watchtower, Uptime Kuma e Dozzle.

### `04-databases-central.sh` — Bancos de Dados
Sobe as instâncias centrais de Postgres e Redis.

### `05-databases.sh` — Provisionamento de Bancos
Cria os databases específicos para cada serviço (n8n, chatwoot, evolution).

### `06-n8n.sh` — Automação (n8n)
Instalação e configuração do n8n.

### `07-communication.sh` — Comunicação
Instalação do Chatwoot e Evolution API.

### `08-backup.sh` — Backup
Configuração de backups automáticos dos bancos de dados.

---

## Informações Adicionais

Para detalhes sobre os containers, portas de acesso e políticas de atualização, consulte o [README.md](../README.md).
