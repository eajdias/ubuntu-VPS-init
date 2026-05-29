#!/bin/bash
# =============================================================================
#  optimize.sh — Bootstrapper de Otimização Remota
#  Objetivo: Baixar/Atualizar o repo e rodar o script de otimização
# =============================================================================

set -e

# Verificação de root
if [[ $EUID -ne 0 ]]; then
    echo "❌ Erro: Este script precisa ser executado como root."
    echo "Por favor, utilize: curl -sSL https://raw.githubusercontent.com/eajdias/ubuntu-VPS-init/main/optimize.sh | sudo bash"
    exit 1
fi

REPO_NAME="vps-stack"

# Se o diretório não existir, avisa que precisa instalar primeiro
if [ ! -d "$REPO_NAME" ]; then
    echo "❌ Erro: A stack não parece estar instalada no diretório '$REPO_NAME'."
    echo "Por favor, instale primeiro usando o install.sh."
    exit 1
fi

cd "$REPO_NAME"
echo "🔄 Atualizando scripts de otimização..."
git pull &> /dev/null || true

if [ -f "scripts/99-optimize-performance.sh" ]; then
    chmod +x scripts/99-optimize-performance.sh
    bash scripts/99-optimize-performance.sh
else
    echo "❌ Erro: Script de otimização não encontrado em scripts/99-optimize-performance.sh"
    exit 1
fi
