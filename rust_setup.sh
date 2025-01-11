#!/bin/bash

# Exit immediately if a command exits with a non-zero status
set -e

# Function to display messages
echo_info() {
    echo -e "\e[32m[INFO]\e[0m $1"
}

echo_warning() {
    echo -e "\e[33m[WARNING]\e[0m $1"
}

echo_error() {
    echo -e "\e[31m[ERROR]\e[0m $1"
}

# Update and upgrade the system
echo_info "Updating and upgrading the system packages..."
sudo apt update && sudo apt upgrade -y

# Install prerequisites
echo_info "Installing build-essential and curl..."
sudo apt install build-essential curl -y

# Check if rustup is already installed
if command -v rustup &> /dev/null
then
    echo_warning "rustup is already installed. Skipping installation."
else
    # Install Rust using rustup
    echo_info "Installing Rust and Cargo using rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
fi

# Source the cargo environment
echo_info "Configuring environment variables..."
source $HOME/.cargo/env

# Add cargo bin to PATH if not already present
if [[ ":$PATH:" != *":$HOME/.cargo/bin:"* ]]; then
    echo_info "Adding Cargo to PATH..."
    echo 'export PATH="$HOME/.cargo/bin:$PATH"' >> ~/.bashrc
    source ~/.bashrc
fi

# Verify installation
echo_info "Verifying Rust installation..."
rustc --version
cargo --version

echo_info "Rust and Cargo have been successfully installed and configured!"
