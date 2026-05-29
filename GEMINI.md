# Workspace Instructions

## Project Overview

**Stack VPS — Automação e Atendimento Omnichannel** is a lightweight, resilient stack designed to provision an omnichannel customer service and automation center on a VPS. It is specifically optimized for efficiency and low resource consumption, making it ideal for servers with 1–2GB of RAM.

**Key Components:**
- **Automation:** n8n for visual, no-code workflows.
- **Omnichannel Support:** Chatwoot for managing conversations.
- **WhatsApp API:** Evolution API for professional WhatsApp integration.
- **Monitoring:** Netdata and Uptime Kuma.
- **Security:** Cloudflare Tunnel (no open firewall ports) and Fail2Ban.
- **Management:** Filebrowser (files) and Dozzle (logs) via a web interface.
- **Core Infrastructure:** Unified central instances of Postgres and Redis shared among services to save memory (up to 500MB).

## Building and Running

The project relies on Docker and shell scripts to automate the deployment process.

### Quick Installation (One-liner)

```bash
curl -sSL https://raw.githubusercontent.com/eajdias/ubuntu-VPS-init/main/install.sh | sudo bash
```

### Manual Installation and Configuration

1. Clone the repository and navigate into it.
2. Edit the environment configuration file:
   ```bash
   nano 00-config.env
   ```
   *Note: This file contains crucial settings like domains, database passwords, API keys, and Docker image versions.*
3. Execute the interactive orchestrator script:
   ```bash
   sudo bash scripts/run-all.sh
   ```

## Development Conventions

- **Modular Orchestration:** Deployment steps are divided into specialized, numbered shell scripts located in the `scripts/` directory (e.g., `01-vps-config.sh`, `02-vps-essentials.sh`, `06-n8n.sh`).
- **Centralized Configuration:** All shared environment variables, domain mappings, and credentials are kept in `00-config.env`.
- **Resource Optimization:** The architecture explicitly avoids standalone databases for each service; instead, it uses a central Postgres and Redis instance (`04-databases-central.sh`) to minimize RAM usage.
- **Interactive Prompts:** The `scripts/run-all.sh` script is designed to be interactive, prompting the user for environment type, domain names, and optional component selection (like n8n or Chatwoot) before executing the modular scripts.
- **Docker-centric:** All services are deployed as Docker containers, with logging configurations standardized globally via environment variables.
