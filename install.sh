#!/bin/bash
# =============================================================================
#  install.sh — Bootstrapper de Instalação Remota
# =============================================================================

set -e

# Verificação de root
if [[ $EUID -ne 0 ]]; then
    echo "❌ Erro: Este script precisa ser executado como root."
    echo "Por favor, utilize: curl -sSL https://raw.githubusercontent.com/eajdias/ubuntu-VPS-init/main/install.sh | sudo bash"
    exit 1
fi

REPO_URL="https://github.com/eajdias/ubuntu-VPS-init.git"
REPO_NAME="vps-stack"

echo "📂 Preparando para instalar a Stack VPS..."

if ! command -v git &> /dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y git -qq
fi

if [ ! -d "$REPO_NAME" ]; then
    git clone "$REPO_URL" "$REPO_NAME"
else
    echo "🔄 Atualizando repositório existente..."
    cd "$REPO_NAME"
    git stash &> /dev/null || true
    git pull
    git stash pop &> /dev/null || true
    cd ..
fi

cd "$REPO_NAME"
chmod +x scripts/*.sh

# Inicia o orquestrador interativo garantindo acesso ao terminal (TTY)
bash scripts/run-all.sh </dev/tty
