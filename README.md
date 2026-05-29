# Stack VPS — Automação e Atendimento Omnichannel

[![Python Version](https://img.shields.io/badge/python-3.14%2B-blue?logo=python&logoColor=white)](https://www.python.org/)
[![uv](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/astral-sh/uv/main/assets/badge/v0.json)](https://github.com/astral-sh/uv)
[![Project Version](https://img.shields.io/badge/version-1.0.0-green)](https://github.com/eajdias/ubuntu-VPS-init)
[![License](https://img.shields.io/badge/license-Proprietary-red.svg)](LICENSE)

Uma stack completa, leve e resiliente para provisionar uma central de atendimento e automação em sua VPS. Projetada para eficiência máxima em recursos, ideal para servidores com 1–2GB de RAM.

## O que esta stack oferece?

- 🤖 **Automação Sem Código:** n8n para fluxos de trabalho visuais.
- 💬 **Atendimento Humano:** Chatwoot para gerenciar conversas omnichannel.
- 📱 **WhatsApp API:** Evolution API para integração profissional com WhatsApp.
- 📊 **Monitoramento:** Netdata e Uptime Kuma para visibilidade total.
- 🔒 **Segurança:** Cloudflare Tunnel (sem portas abertas no firewall) e Fail2Ban.
- 🛠️ **Gestão Facilitada:** Filebrowser (arquivos) e Dozzle (logs) via web.

## Arquitetura Inteligente

Diferente de instalações padrão, esta stack foi otimizada para economizar até **500MB de RAM**:
- **Bancos Unificados:** Instâncias centrais de Postgres e Redis compartilhadas entre serviços.
- **Tuning de Kernel:** Ajustes específicos para alta concorrência e baixo consumo.
- **Auto-manutenção:** Watchtower para atualizações e scripts de limpeza automática de Docker.

## Início Rápido

Para começar agora mesmo, escolha um dos métodos abaixo:

### 🚀 Método Rápido (Instalação via One-liner)

Execute este comando para clonar e configurar tudo automaticamente:

```bash
curl -sSL https://raw.githubusercontent.com/eajdias/ubuntu-VPS-init/main/install.sh | sudo bash
```

### ⚡ Otimização de Recursos (Performance)

Se você mudou o plano da sua VPS ou quer ajustar a performance para o hardware atual (ECO, BALANCED ou PERFORMANCE):

```bash
curl -sSL https://raw.githubusercontent.com/eajdias/ubuntu-VPS-init/main/optimize.sh | sudo bash
```

### 🧹 Desinstalação Rápida (Limpeza Total)

Caso algo dê errado ou você queira limpar a VPS para começar do zero, execute o comando abaixo (AVISO: apaga todos os containers, volumes e pastas criadas, mantendo apenas as imagens e backups):

```bash
curl -sSL https://raw.githubusercontent.com/eajdias/ubuntu-VPS-init/main/scripts/uninstall.sh | sudo bash
```

### 🛠️ Método Manual

Se preferir fazer passo a passo:

```bash
git clone https://github.com/eajdias/ubuntu-VPS-init.git vps-stack
cd vps-stack
# Edite suas credenciais
nano 00-config.env
# Execute o instalador interativo
sudo bash scripts/run-all.sh
```

## Documentação

Para manter o fluxo de leitura, dividimos o conhecimento em guias especializados:

1.  **[Guia Rápido de Instalação](docs/quick_guide.md)** — Como subir a stack do zero em minutos.
2.  **[Detalhes dos Componentes](docs/components.md)** — Especificações técnicas de cada container, portas e configurações.
3.  **[Estratégia de Backup](scripts/08-backup.sh)** — Como garantimos a persistência dos seus dados.


## 🤝 Contribuições

Este é um projeto de código aberto. Sinta-se à vontade para abrir issues ou enviar pull requests para melhorar a stack!

## 📄 Licença

Este projeto está sob a licença MIT. Veja o arquivo [LICENSE](LICENSE) para mais detalhes.

---
*Desenvolvido com foco em performance e simplicidade.*
