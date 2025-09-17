#!/bin/bash
# name: LSW AMD GPU Support
# version: 1.2
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

# Instala as dependências do script (como o pciutils)
sudo_rq
_packages=(pciutils)
_install_

# Verifica se há uma GPU AMD
if ! lspci | grep -Ei 'vga|3d' | grep -Ei 'amd|ati|radeon|amdgpu'; then
    nonfatal "Nenhuma GPU AMD encontrada no seu sistema."
    exit 1
fi

# Adiciona o repositório ROCm, se necessário
if [ "$distro" == "ubuntu" ] || [ "$distro" == "debian" ]; then
    sudo mkdir -p /etc/apt/keyrings
    sudo apt-get update
    sudo apt-get install -y gpg
    wget -qO - https://repo.radeon.com/rocm/rocm.gpg.key | \
    gpg --dearmor | sudo tee /etc/apt/keyrings/rocm.gpg > /dev/null
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/rocm.gpg] https://repo.radeon.com/rocm/apt/6.0.2 $(grep "VERSION_CODENAME=" /etc/os-release | cut -d'=' -f2) main" | \
    sudo tee /etc/apt/sources.list.d/rocm.list
    sudo apt-get update
elif [ "$distro" == "fedora" ]; then
    sudo dnf install -y 'dnf-command(config-manager)'
    sudo dnf config-manager --add-repo https://repo.radeon.com/rocm/yum/6.0.2/rocm.repo
    sudo dnf update
elif [ "$distro" == "suse" ]; then
    sudo zypper addrepo --gpgcheck --refresh https://repo.radeon.com/rocm/zyp/6.0.2/rocm.repo
    sudo zypper refresh
elif [ "$distro" == "arch" ] || [ "$distro" == "cachy" ]; then
    # Para distros baseadas em Arch, os pacotes ROCm estão nos repositórios oficiais.
    # Não é necessário adicionar um novo repositório.
    :
fi

# Instala os drivers ROCm
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