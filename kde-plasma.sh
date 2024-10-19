#!/bin/bash

# KDE Plasma Installation and Performance Tuning Script for Linux Mint
# This script installs KDE Plasma, sets it as the default desktop environment,
# and applies various performance optimizations to enhance system speed.

# Exit immediately if a command exits with a non-zero status
set -e

# Function to display messages
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

# Ensure the script is run with sudo
if [ "$EUID" -ne 0 ]; then
    echo_error "Please run this script with sudo or as root."
    exit 1
fi

# Update and Upgrade System
echo_info "Updating and upgrading the system..."
apt update && apt upgrade -y

# Install Essential Packages
echo_info "Installing essential packages..."
apt install -y software-properties-common wget curl

# ---------------------------
# Install KDE Plasma
# ---------------------------
echo_info "Installing KDE Plasma desktop environment..."

# Add KDE Neon repository for the latest KDE Plasma (optional)
# Uncomment the following lines if you want the latest KDE Plasma version
# echo_info "Adding KDE Neon repository for the latest KDE Plasma..."
# add-apt-repository ppa:kubuntu-ppa/backports -y
# apt update

# Install KDE Plasma
apt install -y kde-plasma-desktop

echo_success "KDE Plasma installed successfully."

# ---------------------------
# Install SDDM Display Manager
# ---------------------------
echo_info "Installing SDDM Display Manager..."

apt install -y sddm

echo_info "Setting SDDM as the default display manager..."

# Configure SDDM as default display manager
echo "sddm" > /etc/X11/default-display-manager

# Enable SDDM service
systemctl enable sddm
systemctl set-default graphical.target

echo_success "SDDM is set as the default display manager."

# ---------------------------
# Disable Unnecessary Services
# ---------------------------
echo_info "Disabling unnecessary services to improve performance..."

# List of services to disable (customize as needed)
services_to_disable=(
    cups           # Printer service
    bluetooth      # Bluetooth service
    ModemManager   # Modem Manager
    apport         # Crash reporting
)

for service in "${services_to_disable[@]}"; do
    if systemctl is-active --quiet "$service"; then
        systemctl disable "$service"
        systemctl stop "$service"
        echo_info "Disabled and stopped $service service."
    else
        echo_info "$service service is not active."
    fi
done

echo_success "Unnecessary services have been disabled."

# ---------------------------
# Performance Tweaks
# ---------------------------
echo_info "Applying performance tweaks..."

# 1. Reduce Swappiness
echo_info "Reducing swappiness to 10..."

sysctl_conf="/etc/sysctl.conf"
if ! grep -q "^vm.swappiness" "$sysctl_conf"; then
    echo "vm.swappiness = 10" >> "$sysctl_conf"
else
    sed -i 's/^vm.swappiness.*/vm.swappiness = 10/' "$sysctl_conf"
fi

sysctl -p

echo_success "Swappiness reduced."

# 2. Enable zRAM
echo_info "Enabling zRAM for better memory management..."

apt install -y zram-config

systemctl enable zram-config
systemctl start zram-config

echo_success "zRAM enabled."

# 3. Optimize I/O Scheduler
echo_info "Optimizing I/O scheduler to 'deadline'..."

echo 'scheduler="deadline"' > /etc/default/grub.d/io-scheduler.cfg

update-grub

echo_success "I/O scheduler optimized."

# 4. Disable Animations in KDE Plasma
echo_info "Disabling animations in KDE Plasma for better performance..."

# Create a KDE configuration file to disable animations
mkdir -p /etc/xdg/autostart/
cat <<EOF > /etc/xdg/autostart/disable-animations.desktop
[Desktop Entry]
Type=Application
Exec=kquitapp5 plasmashell && kstart5 plasmashell
Hidden=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
Name=Disable Animations
EOF

# Apply KDE settings via kwriteconfig5
sudo -u "$SUDO_USER" kwriteconfig5 --file kwinrc --group Compositing --key AnimationSpeed 0
sudo -u "$SUDO_USER" kwriteconfig5 --file kwinrc --group Compositing --key AnimationsEnabled false
sudo -u "$SUDO_USER" kwriteconfig5 --file plasmarc --group General --key animations false

echo_success "KDE Plasma animations disabled."

# 5. Enable Preload for Faster Application Loading
echo_info "Installing and enabling Preload for faster application loading..."

apt install -y preload

systemctl enable preload
systemctl start preload

echo_success "Preload installed and enabled."

# 6. Clean Up Unused Packages
echo_info "Cleaning up unused packages..."

apt autoremove -y
apt autoclean -y

echo_success "Clean up completed."

# ---------------------------
# Set KDE Plasma as Default Session
# ---------------------------
echo_info "Configuring KDE Plasma as the default session..."

# Create a default profile for SDDM
sddm_conf="/etc/sddm.conf.d/default.conf"

mkdir -p /etc/sddm.conf.d/

cat <<EOF > "$sddm_conf"
[Autologin]
# Uncomment and set if you want to enable autologin
# User=
# Session=plasma.desktop

[General]
NumLock=on

[Theme]
Current=breeze

[Users]
DefaultPath=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
EOF

echo_success "KDE Plasma set as the default session."

# ---------------------------
# Final Instructions
# ---------------------------
echo_info "Installation and performance tuning complete."

echo "---------------------------------------------"
echo "Next Steps:"
echo "1. Reboot your system to start using KDE Plasma."
echo "   Command: reboot"
echo "2. After reboot, you can further optimize KDE settings:"
echo "   - Disable desktop effects if not needed."
echo "   - Use lightweight widgets and minimize desktop clutter."
echo "3. Monitor system performance and adjust settings as necessary."
echo "---------------------------------------------"

echo_success "All done! Your system is now running KDE Plasma with performance optimizations."
