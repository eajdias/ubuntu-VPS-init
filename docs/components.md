# Componentes da Stack — Detalhes Técnicos

Este documento detalha a configuração técnica de cada container e serviço utilizado na stack.

## Banco de Dados e Cache

### Redis Central
**Imagem:** `redis:7-alpine` | **Porta:** `6379`

Redis compartilhado entre Chatwoot (database 0) e Evolution API (database 1). Usar uma instância única economiza ~50MB de RAM e simplifica a stack sem perda de isolamento.

- **Persistência:** Configurado com `--appendonly yes`.
- **Gestão de Memória:** `--maxmemory 128mb --maxmemory-policy allkeys-lru` para evitar crescimento ilimitado.

### Postgres Central (`sub_dominio-postgres:18.3`)
**Porta:** interna apenas

Banco único compartilhado por Chatwoot, Evolution API e n8n, cada um em seu próprio database (`chatwoot`, `evolution`, `n8n`). Economiza ~400MB de RAM comparado a instâncias separadas.

- **Extensões inclusas:**
    - `pgvector`: Busca semântica para IA.
    - `pg_cron`: Agendamento de tarefas internas.
    - `pgcrypto`: Necessário para criptografia de dados.
- **Configuração:** `pg_cron` é pré-carregado via `shared_preload_libraries`.

---

## Aplicações Core

### n8n
**Porta:** `5678`

Plataforma de automação de workflows "low-code".
- **Backend:** Postgres (para alta performance e segurança).
- **Integração:** Conecta Chatwoot, Evolution e APIs externas em fluxos visuais.

### Evolution API
**Porta:** `8080`

API para integração com WhatsApp.
- **Recursos:** Gerenciamento de sessões, envio/recebimento de mídia e webhooks.
- **Dependências:** Postgres (sessões) e Redis (filas).

### Chatwoot
**Porta:** `3000`

Plataforma de atendimento omnichannel.
- **Processos:** `chatwoot-app` (Rails/API) e `chatwoot-worker` (Sidekiq).
- **IA:** Utiliza `pgvector` para busca em base de conhecimento.

---

## Observabilidade e Utilidades

### Netdata
**Porta:** `19999`

Monitoramento em tempo real do host e containers.
- **Modo:** `network_mode: host` com acesso a `/proc` e `/sys`.
- **Foco:** Métricas de kernel e performance individual de containers.

### Uptime Kuma
**Porta:** `3001`

Monitor de disponibilidade. Verifica periodicamente o status dos serviços (HTTP, TCP, DNS) e envia alertas (Telegram, Email, etc).

### Dozzle
**Porta:** `8083`

Visualizador de logs Docker em tempo real via browser. Acesso `read-only` ao `docker.sock`.

### Filebrowser
**Porta:** `8081`

Gerenciador de arquivos web. Mapeia a HOME do usuário para edição rápida de arquivos `.env` e acesso a backups sem necessidade de terminal.

### Watchtower
**Sem porta exposta**

Gerencia atualizações automáticas de imagens Docker.
- **Política:** Só atualiza containers com a label `com.centurylinklabs.watchtower.enable=true`.
- **Segurança:** Bancos de dados têm atualização automática desabilitada por padrão para evitar quebras de versão major.

---

## Políticas e Redes

### Portas de Acesso

| Serviço      | Porta  | Acesso externo via Cloudflare |
|--------------|--------|-------------------------------|
| Chatwoot     | 3000   | `sub_dominio-chatwoot.dominio.com` |
| Evolution    | 8080   | `sub_dominio-evolution.dominio.com` |
| n8n          | 5678   | `sub_dominio-n8n.dominio.com` |
| Filebrowser  | 8081   | `sub_dominio-files.dominio.com` |
| Netdata      | 19999  | `sub_dominio-netdata.dominio.com` |
| Uptime Kuma  | 3001   | `sub_dominio-uptime.dominio.com` |
| Dozzle       | 8083   | `sub_dominio-dozzle.dominio.com` |

### Política de Auto-atualização (Watchtower)

| Container | Auto-atualiza? | Motivo |
|-----------|---------------|--------|
| n8n | ✅ | Atualizações frequentes de nós |
| Chatwoot | ✅ | Patches de segurança regulares |
| Evolution API | ✅ | Mudanças no protocolo WhatsApp |
| Netdata | ✅ | Melhorias contínuas |
| Postgres/Redis | ❌ | Exige migração manual de dados |
