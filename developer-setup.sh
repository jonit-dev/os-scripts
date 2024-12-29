#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# -------------------------------
# Variables
# -------------------------------
OH_MY_ZSH_URL="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh"
NVM_INSTALL_URL="https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.5/install.sh"
POWERLINE_FONTS="fonts-powerline"
ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
ZSH_AUTOSUGGESTIONS_DIR="$ZSH_CUSTOM/plugins/zsh-autosuggestions"
ZSH_SYNTAX_HIGHLIGHTING_DIR="$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
SSH_KEY="$HOME/.ssh/id_rsa"
ZSHRC_FILE="$HOME/.zshrc"

# Docker Variables
DOCKER_GPG_KEY_URL="https://download.docker.com/linux/ubuntu/gpg"
# We'll set DOCKER_REPO after determining the correct codename
DOCKER_COMPOSE_VERSION="2.21.0" # Updated to the latest version

# Brave Browser Variables
BRAVE_GPG_KEY_URL="https://brave-browser-apt-release.s3.brave.com/brave-core.asc"
BRAVE_REPO="deb [arch=amd64 signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main"

# Get system architecture and Ubuntu codename
ARCH=$(dpkg --print-architecture)
CODENAME=$(lsb_release -cs)

# Validate Architecture
if [ "$ARCH" != "amd64" ]; then
    echo "Unsupported architecture: $ARCH. This script supports only amd64."
    exit 1
fi

# Validate Ubuntu Codename
# List of supported Ubuntu codenames by Docker
SUPPORTED_CODENAMES=("focal" "jammy" "bionic" "xenial" "hirsute" "impish" "kinetic" "jammy" "lunar")

if [[ ! " ${SUPPORTED_CODENAMES[@]} " =~ " ${CODENAME} " ]]; then
    echo "Ubuntu codename '$CODENAME' is not officially supported by Docker repositories."
    echo "Attempting to use 'jammy' as a fallback. Please verify compatibility."
    CODENAME="jammy"
fi

# Set Docker repository with validated codename
DOCKER_REPO="deb [arch=$ARCH signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $CODENAME stable"

# -------------------------------
# Functions
# -------------------------------

# Function to print messages with formatting
print_message() {
    echo -e "\n========================================"
    echo -e "$1"
    echo -e "========================================\n"
}

# Function to update and upgrade system packages
update_system() {
    print_message "Updating package list and upgrading existing packages..."
    sudo apt update && sudo apt upgrade -y
}

# Function to install basic dependencies
install_basic_dependencies() {
    print_message "Installing basic dependencies..."
    sudo apt-get install -y git build-essential curl wget vim zsh libssl-dev cmake "$POWERLINE_FONTS" gnupg lsb-release software-properties-common
}

# Function to install Visual Studio Code
install_vscode() {
    print_message "Installing Visual Studio Code..."
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /usr/share/keyrings/packages.microsoft.gpg > /dev/null
    echo "deb [arch=$ARCH signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" | sudo tee /etc/apt/sources.list.d/vscode.list
    sudo apt update -y
    sudo apt install -y code
}

# Function to install Brave Browser
install_brave() {
    print_message "Installing Brave Browser..."
    sudo apt install -y curl
    curl -fsSL "$BRAVE_GPG_KEY_URL" | sudo gpg --dearmor -o /usr/share/keyrings/brave-browser-archive-keyring.gpg
    echo "$BRAVE_REPO" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list
    sudo apt update -y
    sudo apt install -y brave-browser
}

# Function to install Zsh
install_zsh() {
    print_message "Installing Zsh..."
    sudo apt install -y zsh

    if command -v zsh >/dev/null 2>&1; then
        echo "Zsh installed successfully."
    else
        echo "Zsh installation failed."
        exit 1
    fi
}

# Function to change the default shell to Zsh
change_default_shell() {
    print_message "Changing the default shell to Zsh for user $(whoami)..."
    if [ "$(basename "$SHELL")" != "zsh" ]; then
        chsh -s "$(which zsh)"
        echo "Default shell changed to Zsh. Please log out and log back in to apply changes."
    else
        echo "Zsh is already the default shell."
    fi
}

# Function to install Oh My Zsh
install_oh_my_zsh() {
    if [ ! -d "$HOME/.oh-my-zsh" ]; then
        print_message "Installing Oh My Zsh..."
        RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL $OH_MY_ZSH_URL)"
    else
        echo "Oh My Zsh is already installed."
    fi
}

# Function to install Zsh plugins
install_zsh_plugins() {
    # Install zsh-autosuggestions
    if [ ! -d "$ZSH_AUTOSUGGESTIONS_DIR" ]; then
        print_message "Installing zsh-autosuggestions plugin..."
        git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_AUTOSUGGESTIONS_DIR"
    else
        echo "zsh-autosuggestions is already installed."
    fi

    # Install zsh-syntax-highlighting
    if [ ! -d "$ZSH_SYNTAX_HIGHLIGHTING_DIR" ]; then
        print_message "Installing zsh-syntax-highlighting plugin..."
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_SYNTAX_HIGHLIGHTING_DIR"
    else
        echo "zsh-syntax-highlighting is already installed."
    fi
}

# Function to install NVM
install_nvm() {
    if [ ! -d "$HOME/.nvm" ]; then
        print_message "Installing NVM (Node Version Manager)..."
        curl -o- "$NVM_INSTALL_URL" | bash
    else
        echo "NVM is already installed."
    fi
}

# Function to configure NVM in .zshrc
configure_nvm() {
    if ! grep -q 'export NVM_DIR="$HOME/.nvm"' "$ZSHRC_FILE"; then
        print_message "Configuring NVM in .zshrc..."
        {
            echo ""
            echo "# NVM Configuration"
            echo 'export NVM_DIR="$HOME/.nvm"'
            echo '[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm'
            echo '[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion'
        } >> "$ZSHRC_FILE"
    else
        echo "NVM is already configured in .zshrc."
    fi
}

# Function to install the latest stable Node.js using NVM
install_node() {
    # Load NVM
    export NVM_DIR="$HOME/.nvm"
    # shellcheck source=/dev/null
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"

    print_message "Installing the latest stable version of Node.js..."
    nvm install --lts
    nvm use --lts
    nvm alias default 'lts/*'

    echo "Node.js $(node -v) and npm $(npm -v) have been installed."
}

# Function to install Yarn using NVM-managed npm
install_yarn() {
    print_message "Installing Yarn globally using npm..."
    npm install --global yarn
    echo "Yarn $(yarn -v) has been installed."
}

# Function to configure Oh My Zsh plugins in .zshrc
configure_oh_my_zsh() {
    # Backup existing .zshrc if not already backed up
    if [ ! -f "$HOME/.zshrc.pre-oh-my-zsh" ]; then
        cp "$ZSHRC_FILE" "$HOME/.zshrc.pre-oh-my-zsh"
        echo "Backed up the original .zshrc to .zshrc.pre-oh-my-zsh"
    fi

    print_message "Configuring Oh My Zsh plugins in .zshrc..."

    # Ensure plugins line exists and is properly configured
    if grep -q "^plugins=" "$ZSHRC_FILE"; then
        sed -i "s/^plugins=(.*)$/plugins=(git zsh-autosuggestions zsh-syntax-highlighting)/" "$ZSHRC_FILE"
    else
        echo 'plugins=(git zsh-autosuggestions zsh-syntax-highlighting)' >> "$ZSHRC_FILE"
    fi
}

# Function to generate SSH key
configure_ssh() {
    print_message "Configuring SSH key..."

    if [ -f "$SSH_KEY" ]; then
        echo "An SSH key already exists at $SSH_KEY."
    else
        read -p "No SSH key found. Would you like to generate one? (y/N): " generate_key
        generate_key=${generate_key:-N}
        if [[ "$generate_key" =~ ^[Yy]$ ]]; then
            ssh-keygen -t rsa -b 4096 -C "$(whoami)@$(hostname)" -f "$SSH_KEY" -N ""
            eval "$(ssh-agent -s)"
            ssh-add "$SSH_KEY"
            echo "SSH key generated and added to the SSH agent."
            echo "Add the following public key to your GitHub/GitLab account:"
            echo "------------------------------------------------------------"
            cat "${SSH_KEY}.pub"
            echo "------------------------------------------------------------"
        else
            echo "Skipping SSH key generation."
        fi
    fi
}

# Function to add custom aliases and functions to .zshrc
configure_custom_aliases() {
    print_message "Adding custom aliases and functions to .zshrc..."

    # Define an array of aliases to add
    declare -A aliases=(
        ["dlsapi"]="docker-compose logs -f --tail=100 startup-api"
        ["dlapi"]="docker-compose logs -f --tail=100 rpg-api"
        ["dlstop"]="docker-compose stop rpg-api"
        ["dlre"]="docker-compose restart rpg-api"
        ["dcup"]="docker-compose up -d"
        ["dcre"]="docker-compose restart"
        ["dcstop"]="docker-compose stop"
        ["dcb"]="docker-compose build"
        ["dcrm"]="docker-compose rm -f"
        ["dcd"]="docker-compose down"
        # Docker Aliases
        ["dps"]="docker ps"
        ["dimages"]="docker images"
        ["drm"]="docker rm"
        ["dim"]="docker images"
        ["dstopall"]="docker stop \$(docker ps -aq)"
        ["drmall"]="docker rm \$(docker ps -aq)"
        ["dclean"]="docker system prune -af"
    )

    # Iterate and add aliases if they don't exist
    for alias_name in "${!aliases[@]}"; do
        if ! grep -q "^alias $alias_name=" "$ZSHRC_FILE"; then
            echo "alias $alias_name=\"${aliases[$alias_name]}\"" >> "$ZSHRC_FILE"
            echo "Added alias '$alias_name' to .zshrc."
        else
            echo "Alias '$alias_name' already exists in .zshrc."
        fi
    done

    # Add generic dl function if it doesn't exist
    if ! grep -q '^dl()' "$ZSHRC_FILE"; then
        cat << 'EOF' >> "$ZSHRC_FILE"

# Generic function to view logs of any container
dl() {
    if [ -z "$1" ]; then
        echo "Usage: dl <container_name>"
        return 1
    fi
    docker-compose logs -f --tail=100 "$1"
}
EOF
        echo "Added function 'dl' to .zshrc."
    else
        echo "Function 'dl' already exists in .zshrc."
    fi

    # Add git push shortcut function if it doesn't exist
    if ! grep -q '^gtpush()' "$ZSHRC_FILE"; then
        cat << 'EOF' >> "$ZSHRC_FILE"

# Git shortcut function - Usage: gtpush "commit message"
gtpush() {
    git add .
    git commit -m "$1"
    git push
}
EOF
        echo "Added function 'gp' to .zshrc."
    else
        echo "Function 'gp' already exists in .zshrc."
    fi
}

# Function to install Docker
install_docker() {
    print_message "Installing Docker Engine..."

    # Remove older versions if any
    sudo apt-get remove -y docker docker-engine docker.io containerd runc || true

    # Add Docker's official GPG key
    curl -fsSL "$DOCKER_GPG_KEY_URL" | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg

    # Set up the stable repository
    echo "$DOCKER_REPO" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

    # Update package index
    sudo apt update -y

    # Install Docker Engine, CLI, and Containerd
    sudo apt install -y docker-ce docker-ce-cli containerd.io

    # Verify Docker installation
    if sudo docker run hello-world >/dev/null 2>&1; then
        echo "Docker installed successfully."
    else
        echo "Docker installation failed."
        exit 1
    fi
}

# Function to install Docker Compose
install_docker_compose() {
    print_message "Installing Docker Compose..."

    # Download the specified version of Docker Compose
    sudo curl -L "https://github.com/docker/compose/releases/download/v${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose

    # Apply executable permissions
    sudo chmod +x /usr/local/bin/docker-compose

    # Create a symbolic link to make docker-compose accessible
    sudo ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose || true

    # Verify Docker Compose installation
    if docker-compose --version >/dev/null 2>&1; then
        echo "Docker Compose $(docker-compose --version | awk '{print $3}') installed successfully."
    else
        echo "Docker Compose installation failed."
        exit 1
    fi
}

# Function to configure Docker permissions
configure_docker_permissions() {
    print_message "Configuring Docker permissions..."

    # Add current user to the docker group
    sudo usermod -aG docker "$USER"

    echo "Added user '$USER' to the 'docker' group."
    echo "To apply the new group membership, please log out and log back in."
}

# Function to clean up
cleanup() {
    print_message "Cleaning up..."
    sudo apt autoremove -y
    sudo apt clean
}

# -------------------------------
# Main Execution Flow
# -------------------------------
main() {
    update_system
    install_basic_dependencies
    install_vscode
    install_brave
    install_zsh
    change_default_shell
    install_oh_my_zsh
    install_zsh_plugins
    install_docker
    install_docker_compose
    configure_docker_permissions
    install_nvm
    configure_nvm
    install_node
    install_yarn
    configure_oh_my_zsh
    configure_custom_aliases
    configure_ssh
    cleanup

    print_message "Setup complete! Please restart your terminal or log out and log back in to apply the changes."

    echo "To verify:
1. Zsh is set as the default shell.
2. Oh My Zsh is installed.
3. Plugins (zsh-autosuggestions and zsh-syntax-highlighting) are active.
4. NVM is installed and configured.
5. Node.js $(node -v) and Yarn $(yarn -v) are installed.
6. Docker is installed and running. Verify with 'docker --version' and 'docker-compose --version'.
7. Brave Browser is installed. Verify with 'brave-browser --version'.
8. Your user is added to the 'docker' group.

You can now manage Docker containers and Node.js versions using NVM, e.g., 'nvm install <version>'."
}

# Execute main function
main

echo "Proceeding to git setup..."

./git-setup.sh
