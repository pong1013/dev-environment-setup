#!/usr/bin/env bash

# chien-dev installation script
# Usage: curl -fsSL https://raw.githubusercontent.com/pong1013/dev-environment-setup/main/install.sh | bash

set -e

# --- Configuration ---
REPO_URL="https://github.com/pong1013/dev-environment-setup.git" # TODO: Update with your actual repo URL if different
INSTALL_DIR="${HOME}/.chien-dev"
BIN_DIR="/usr/local/bin"
BIN_NAME="chien-dev"

# --- Colors ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BLUE}==> Starting chien-dev installation...${NC}"

# --- OS Detection ---
OS="$(uname -s)"
echo -e "${BLUE}==> Detected OS: ${OS}${NC}"

check_command() {
    command -v "$1" >/dev/null 2>&1
}

prompt_install() {
    local missing=("$@")
    echo -e "${YELLOW}==> Missing recommended dependencies: ${missing[*]}${NC}"
    read -p "    Do you want to attempt automatic installation? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        return 0 # Yes
    else
        return 1 # No
    fi
}

# --- Dependency Installation ---
install_deps_mac() {
    if ! check_command brew; then
        echo -e "${YELLOW}==> Homebrew not found. Please install Homebrew manually first: https://brew.sh/${NC}"
        return
    fi
    local missing=()
    if ! check_command docker; then missing+=("docker"); fi
    if ! check_command multipass; then missing+=("multipass"); fi

    if [ ${#missing[@]} -gt 0 ]; then
        if prompt_install "${missing[@]}"; then
            echo -e "${BLUE}==> Installing via Homebrew...${NC}"
            brew install --cask "${missing[@]}"
        else
            echo -e "${YELLOW}==> Skipping dependency installation. Please install them manually later.${NC}"
        fi
    else
        echo -e "${GREEN}==> All dependencies (Docker, Multipass) are installed.${NC}"
    fi
}

install_deps_linux() {
    local missing=()
    if ! check_command docker; then missing+=("docker.io"); fi
    if ! check_command multipass; then missing+=("multipass"); fi

    if [ ${#missing[@]} -gt 0 ]; then
        if prompt_install "${missing[@]}"; then
            echo -e "${BLUE}==> Installing via APT/Snap (may require sudo password)...${NC}"
            if [[ " ${missing[*]} " =~ " docker.io " ]]; then
                sudo apt-get update && sudo apt-get install -y docker.io docker-compose-v2
            fi
            if [[ " ${missing[*]} " =~ " multipass " ]]; then
                sudo snap install multipass
            fi
        else
            echo -e "${YELLOW}==> Skipping dependency installation. Please install them manually later.${NC}"
        fi
    else
        echo -e "${GREEN}==> All dependencies (Docker, Multipass) are installed.${NC}"
    fi
}

if [ "$OS" = "Darwin" ]; then
    install_deps_mac
elif [ "$OS" = "Linux" ]; then
    install_deps_linux
else
    echo -e "${YELLOW}==> Windows detected. chien-dev is designed for WSL2 or Git Bash. Skipping dependency check.${NC}"
fi

# --- Clone or Update Repository ---
if [ -d "$INSTALL_DIR" ]; then
    echo -e "${BLUE}==> Updating existing installation in ${INSTALL_DIR}...${NC}"
    cd "$INSTALL_DIR"
    git fetch origin
    git reset --hard origin/main
else
    echo -e "${BLUE}==> Cloning repository to ${INSTALL_DIR}...${NC}"
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# --- Create Symlink ---
# Try to create symlink in ~/.local/bin first to avoid sudo
LOCAL_BIN_DIR="${HOME}/.local/bin"
mkdir -p "$LOCAL_BIN_DIR"

echo -e "${BLUE}==> Creating symlink...${NC}"
ln -sf "${INSTALL_DIR}/scripts/chien-dev" "${LOCAL_BIN_DIR}/${BIN_NAME}"

# Add to PATH hint if needed
if [[ ":$PATH:" != *":$LOCAL_BIN_DIR:"* ]]; then
    echo -e "${YELLOW}==> IMPORTANT: ${LOCAL_BIN_DIR} is not in your PATH.${NC}"
    
    # Detect shell
    SHELL_RC=""
    if [[ "$SHELL" == *"zsh"* ]]; then
        SHELL_RC="${HOME}/.zshrc"
    elif [[ "$SHELL" == *"bash"* ]]; then
        SHELL_RC="${HOME}/.bashrc"
    fi

    if [[ -n "$SHELL_RC" ]]; then
        read -p "    Do you want to automatically add it to your ${SHELL_RC}? [y/N]: " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "\n# chien-dev path\nexport PATH=\"${LOCAL_BIN_DIR}:\$PATH\"" >> "$SHELL_RC"
            echo -e "${GREEN}==> Added to ${SHELL_RC}. ${BOLD}Please run 'source ${SHELL_RC}' or restart your terminal.${NC}"
        else
            echo -e "    ${BOLD}Please manually add: export PATH=\"${LOCAL_BIN_DIR}:\$PATH\"${NC}"
        fi
    else
        echo -e "    ${BOLD}Please manually add: export PATH=\"${LOCAL_BIN_DIR}:\$PATH\" to your shell configuration.${NC}"
    fi
else
    echo -e "${GREEN}==> Symlink created at ${LOCAL_BIN_DIR}/${BIN_NAME}${NC}"
fi

# Optional: Also try /usr/local/bin if they want a system-wide install, but let's stick to user-local for safety
echo -e "${GREEN}==> Installation complete! 🎉${NC}"
echo -e "    Run '${BIN_NAME}' to start scaffolding your environments."
