#!/bin/bash

# Privacy-Oriented Setup Script for Linux Mint
# This script installs essential privacy tools and configures system settings for enhanced privacy.

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

# Update and Upgrade System
echo_info "Updating and upgrading the system..."
sudo apt update && sudo apt upgrade -y

# Install Essential Packages
echo_info "Installing essential packages..."
sudo apt install -y curl wget gnupg2 software-properties-common ufw git

# ---------------------------
# Install Tor Browser
# ---------------------------
echo_info "Installing Tor Browser..."

# Install Tor
sudo apt install -y tor

# Install Tor Browser Launcher
sudo apt install -y torbrowser-launcher

echo_success "Tor Browser installed successfully."

# ---------------------------
# Install Brave Browser
# ---------------------------
echo_info "Installing Brave Browser..."

# Add Brave repository
sudo curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" | sudo tee /etc/apt/sources.list.d/brave-browser-release.list

# Update package list
sudo apt update

# Install Brave
sudo apt install -y brave-browser

echo_success "Brave Browser installed successfully."

# ---------------------------
# Install KeePassXC (Password Manager)
# ---------------------------
echo_info "Installing KeePassXC..."

sudo apt install -y keepassxc

echo_success "KeePassXC installed successfully."


# ---------------------------
# Install GnuPG (Encryption Tool)
# ---------------------------
echo_info "Installing GnuPG..."

sudo apt install -y gnupg

echo_success "GnuPG installed successfully."


# ---------------------------
# Configure UFW Firewall
# ---------------------------
echo_info "Configuring UFW Firewall..."

# Enable UFW
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow SSH if applicable
read -p "Do you want to allow SSH connections? (y/N): " allow_ssh
if [[ "$allow_ssh" =~ ^[Yy]$ ]]; then
    sudo ufw allow ssh
    echo_info "SSH connections allowed."
fi

# Enable UFW
sudo ufw enable

echo_success "UFW Firewall configured and enabled."

# ---------------------------
# System Hardening (Optional)
# ---------------------------
echo_info "Applying system hardening configurations..."

# Disable IPv6 (optional, can affect some services)
read -p "Do you want to disable IPv6? (y/N): " disable_ipv6
if [[ "$disable_ipv6" =~ ^[Yy]$ ]]; then
    echo "net.ipv6.conf.all.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
    echo "net.ipv6.conf.default.disable_ipv6 = 1" | sudo tee -a /etc/sysctl.conf
    sudo sysctl -p
    echo_info "IPv6 disabled."
fi

# Enable AppArmor (usually enabled by default)
sudo systemctl enable apparmor
sudo systemctl start apparmor

echo_info "AppArmor enabled."

echo_success "System hardening configurations applied."

# ---------------------------
# Install and Configure FirewallD (Alternative Firewall)
# Optional: If you prefer FirewallD over UFW
# ---------------------------
# Uncomment below if you prefer FirewallD
# echo_info "Installing FirewallD..."
# sudo apt install -y firewalld
# sudo systemctl enable firewalld
# sudo systemctl start firewalld
# echo_success "FirewallD installed and started."

# ---------------------------
# Final Instructions
# ---------------------------
echo_info "Privacy-oriented setup is complete!"

echo "---------------------------------------------"
echo "Next Steps:"
echo "1. Launch Tor Browser from your applications menu."
echo "2. Launch Brave Browser and install uBlock Origin extension for enhanced privacy."
echo "3. Initialize ProtonVPN by running 'protonvpn init' and follow the prompts."
echo "4. Configure and use Firejail to sandbox your applications as needed."
echo "5. Regularly update your system and installed applications to maintain security."
echo "---------------------------------------------"

echo_success "All done! Your system is now more privacy-oriented."
