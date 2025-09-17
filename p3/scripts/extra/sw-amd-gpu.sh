#!/bin/bash
# name: LSW AMD GPU Support
# version: 1.0
# description: Habilita o suporte para placas de vídeo AMD nos contêineres LSW.
# icon: amd.png
# compat: ubuntu, debian, fedora, arch, cachy, suse
# noconfirm: yes
# nocontainer

# --- Início do código do script ---
SCRIPT_DIR="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$SCRIPT_DIR/../../libs/linuxtoys.lib"
# language
_lang_
source "$SCRIPT_DIR/../../libs/lang/${langfile}.lib"
source "$SCRIPT_DIR/../../libs/helpers.lib"

# Verifica se há uma GPU AMD
if ! lspci | grep -Ei 'vga|3d' | grep -Ei 'amd|ati|radeon|amdgpu'; then
    nonfatal "Nenhuma GPU AMD encontrada no seu sistema."
    exit 1
fi

# Instala os drivers ROCm no sistema hospedeiro
sudo_rq
_packages=(rocm-hip rocm-opencl clinfo)
_install_
sudo usermod -aG render,video $USER

# Modifica o compose.yaml para adicionar suporte à GPU
COMPOSE_FILE="$HOME/.config/winapps/compose.yaml"
if [ -f "$COMPOSE_FILE" ]; then
    # Adiciona o mapeamento de dispositivo para /dev/dri
    if ! grep -q "/dev/dri" "$COMPOSE_FILE"; then
        sed -i '/devices:/a \ \ \ \ \ \ - /dev/dri:/dev/dri' "$COMPOSE_FILE"
    fi
    # Adiciona a variável de ambiente para o Vulkan ICD
    if ! grep -q "VK_ICD_FILENAMES" "$COMPOSE_FILE"; then
        sed -i '/environment:/a \ \ \ \ \ \ - VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/radeon_icd.x86_64.json' "$COMPOSE_FILE"
    fi
    zeninf "Configuração do LSW atualizada para suporte a GPU AMD. Por favor, reinicie o contêiner LSW para que as alterações tenham efeito."
else
    nonfatal "O LSW não está configurado. Por favor, execute a instalação do LSW primeiro."
    exit 1
fi