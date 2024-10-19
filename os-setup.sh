#!/bin/bash

# =============================================================================
# Linux Mint Developer Optimization Script
# =============================================================================
# This script optimizes Linux Mint for development by enhancing security,
# improving performance, and removing unnecessary applications.
# =============================================================================

# Exit immediately if a command exits with a non-zero status
set -e

# ------------------------------
# Helper Functions for Messaging
# ------------------------------
echo_info() {
    echo -e "\e[34m[INFO]\e[0m $1"
}

echo_success() {
    echo -e "\e[32m[SUCCESS]\e[0m $1"
}

echo_warning() {
    echo -e "\e[33m[WARNING]\e[0m $1"
}

echo_error() {
    echo -e "\e[31m[ERROR]\e[0m $1"
}

# ------------------------------
# Function to Prompt for Confirmation
# ------------------------------
prompt_confirmation() {
    read -p "$1 [y/N]: " response
    case "$response" in
        [yY][eE][sS]|[yY]) 
            true
            ;;
        *)
            false
            ;;
    esac
}

# ------------------------------
# Function to Install Packages if Not Installed
# ------------------------------
install_package() {
    PACKAGE=$1
    if ! dpkg -l | grep -q "^ii  $PACKAGE "; then
        sudo apt install -y "$PACKAGE"
        echo_success "Installed $PACKAGE."
    else
        echo_info "$PACKAGE is already installed."
    fi
}

# ------------------------------
# Begin Optimization Process
# ------------------------------

echo_info "Starting Linux Mint optimization script for development purposes."

# 1. Install Proprietary Drivers
echo_info "Installing proprietary drivers..."
sudo ubuntu-drivers autoinstall
echo_success "Proprietary drivers installed."

# 2. Update and Upgrade the System
echo_info "Updating package lists..."
sudo apt update
echo_success "Package lists updated."

echo_info "Upgrading existing packages..."
sudo apt upgrade -y
echo_success "Packages upgraded."

# 3. Remove Unnecessary Applications
echo_info "Removing unnecessary applications..."

APPS_TO_REMOVE=(
    "blueman"           # Bluetooth manager
    "rhythmbox"         # Music player
    "remmina"           # Remote desktop client
    "transmission"      # BitTorrent client
    "mintwelcome"       # Welcome screen
    "gnome-mahjongg"    # Mahjong game
    "gnome-mines"       # Mines game
    "gnome-sudoku"      # Sudoku game
    "cheese"            # Webcam application
    "pix"               # Image viewer
    "gnome-weather"     # Weather application
    "gnome-calendar"    # Calendar application
    "libreoffice*"      # LibreOffice suite
    "gnome-games"       # Additional GNOME games
    # Add more applications as needed
)

for app in "${APPS_TO_REMOVE[@]}"; do
    if dpkg -l | grep -q "^ii  $app"; then
        sudo apt purge -y "$app"
        echo_success "Removed $app."
    else
        echo_info "$app is not installed, skipping."
    fi
done

# 4. Autoremove and Autoclean
echo_info "Autoremoving unused dependencies..."
sudo apt autoremove -y
echo_success "Unused dependencies removed."

echo_info "Autocleaning package cache..."
sudo apt autoclean -y
echo_success "Package cache cleaned."

# 5. Clean Thumbnail Cache
echo_info "Cleaning thumbnail cache..."
rm -rf ~/.cache/thumbnails/*
echo_success "Thumbnail cache cleaned."

# 6. Disable Unnecessary Startup Applications
echo_info "Disabling unnecessary startup applications..."

STARTUP_APPS=(
    "libreoffice-startcenter.desktop"
    # Add more startup applications to disable as needed
)

for desktop_file in "${STARTUP_APPS[@]}"; do
    AUTOSTART_PATH="$HOME/.config/autostart/$desktop_file"
    if [ -f "$AUTOSTART_PATH" ]; then
        sed -i 's/^Hidden=false/Hidden=true/' "$AUTOSTART_PATH"
        echo_success "Disabled startup application: $desktop_file."
    else
        echo_info "$desktop_file does not exist, skipping."
    fi
done

# 7. Disable Unnecessary Services
echo_info "Disabling unnecessary services..."

SERVICES_TO_DISABLE=(
    "bluetooth.service"
    "cups.service"         # Printing service
    "nmbd.service"         # Samba NetBIOS name server
    "smbd.service"         # Samba file server
    "avahi-daemon.service" # Service discovery
    # Add more services as needed
)

for service in "${SERVICES_TO_DISABLE[@]}"; do
    if systemctl list-unit-files | grep -q "^$service"; then
        sudo systemctl disable "$service"
        sudo systemctl stop "$service" || true
        echo_success "Disabled and stopped $service."
    else
        echo_info "$service does not exist, skipping."
    fi
done

# 8. Optimize Swappiness
echo_info "Optimizing swappiness..."
sudo sysctl vm.swappiness=10
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf > /dev/null
echo_success "Swappiness set to 10."

# 9. Install and Configure Preload
echo_info "Installing Preload to speed up application loading..."
install_package "preload"
sudo systemctl enable preload
sudo systemctl start preload
echo_success "Preload installed and started."

# 10. Optimize I/O Scheduler for SSDs
echo_info "Optimizing I/O scheduler for SSDs..."
if lsblk -d -o rota | grep -qw "0"; then
    for disk in /sys/block/sd? ; do
        if [ -w "$disk/queue/scheduler" ]; then
            echo "noop" | sudo tee "$disk/queue/scheduler" > /dev/null
            echo_success "Set I/O scheduler to noop for $(basename $disk)."
        fi
    done
else
    echo_warning "No SSD detected or unable to set I/O scheduler."
fi

# 11. Clear Systemd Journal Logs
echo_info "Clearing systemd journal logs older than 2 days..."
sudo journalctl --vacuum-time=2d
echo_success "Systemd journal logs cleared."

# 12. Update GRUB for Faster Boot
echo_info "Configuring GRUB for faster boot..."
sudo sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub
sudo update-grub
echo_success "GRUB timeout set to 1 second."

# 13. Install and Configure UFW (Uncomplicated Firewall)
echo_info "Installing UFW firewall..."
install_package "ufw"

echo_info "Setting up UFW rules..."
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH if OpenSSH server is installed
if dpkg -l | grep -q "^ii  openssh-server"; then
    sudo ufw allow ssh
    echo_success "Allowed SSH through UFW."
fi

echo_info "Enabling UFW..."
sudo ufw --force enable
echo_success "UFW is active and configured."

# 14. Disable IPv6 (Optional for Security)
# Uncomment the following lines if you wish to disable IPv6
# echo_info "Disabling IPv6..."
# echo "net.ipv6.conf.all.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
# echo "net.ipv6.conf.default.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
# sudo sysctl -p
# echo_success "IPv6 disabled."

# 15. Enable Automatic Security Updates
echo_info "Installing unattended-upgrades..."
install_package "unattended-upgrades"

echo_info "Configuring automatic security updates..."
sudo dpkg-reconfigure --priority=low unattended-upgrades
echo_success "Automatic security updates configured."

# 16. Enhance SSH Security (Optional)
if prompt_confirmation "Do you want to enhance SSH security (change default port, disable root login)?"; then
    SSH_CONFIG="/etc/ssh/sshd_config"
    
    echo_info "Backing up SSH configuration..."
    sudo cp "$SSH_CONFIG" "${SSH_CONFIG}.backup"
    
    echo_info "Changing SSH default port to 2200..."
    sudo sed -i 's/^#Port 22/Port 2200/' "$SSH_CONFIG"
    
    echo_info "Disabling root login over SSH..."
    sudo sed -i 's/^PermitRootLogin yes/PermitRootLogin no/' "$SSH_CONFIG"
    
    echo_info "Restarting SSH service..."
    sudo systemctl restart sshd
    echo_success "SSH security enhanced. New port: 2200 and root login disabled."
    
    # Allow new SSH port in UFW
    sudo ufw allow 2200/tcp
    echo_success "Allowed SSH on port 2200 through UFW."
fi

# 17. Install and Configure Fail2Ban
echo_info "Installing Fail2Ban..."
install_package "fail2ban"

echo_info "Configuring Fail2Ban..."
sudo bash -c 'cat > /etc/fail2ban/jail.local <<EOF
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5

[sshd]
enabled = true
port = 2200
EOF'

echo_info "Restarting Fail2Ban service..."
sudo systemctl restart fail2ban
echo_success "Fail2Ban is installed and active."

# 18. Optimize System Performance
echo_info "Optimizing system performance..."

# Reduce the number of file watchers (useful for development)
echo 'fs.inotify.max_user_watches=524288' | sudo tee -a /etc/sysctl.conf
sudo sysctl -p
echo_success "Increased inotify watchers."

# Enable zRAM for improved performance
echo_info "Installing zRAM..."
install_package "zram-config"
echo_success "zRAM installed and enabled."

# 19. Final Cleanup
echo_info "Performing final system cleanup..."
sudo apt clean
echo_success "System cleanup completed."

# 20. Prompt for Reboot
if prompt_confirmation "Optimization completed. Do you want to reboot now to apply all changes?"; then
    echo_info "Rebooting the system..."
    sudo reboot
else
    echo_info "Please remember to reboot your system later to apply all changes."
fi

# =============================================================================
# End of Script
# =============================================================================
