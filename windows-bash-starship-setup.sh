#!/usr/bin/env bash
set -e

# Define custom bin directory
BIN_DIR="$HOME/.local/bin"

# Create the custom bin directory if it doesn't exist
if [ ! -d "$BIN_DIR" ]; then
  echo "Creating directory: $BIN_DIR"
  mkdir -p "$BIN_DIR"
fi

# Download and install Starship
echo "Downloading Starship installer..."
curl -sS -o install.sh https://starship.rs/install.sh

echo "Installing Starship into: $BIN_DIR"
chmod +x install.sh
./install.sh -b "$BIN_DIR" -y

# Clean up installer script
rm install.sh

# Update ~/.bashrc for PATH if not already set
if ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$HOME/.bashrc"; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
  echo "Added PATH update to ~/.bashrc"
fi

# Update ~/.bashrc for Starship init if not already present
if ! grep -q 'starship init bash' "$HOME/.bashrc"; then
  echo 'eval "$(starship init bash)"' >> "$HOME/.bashrc"
  echo "Added Starship initialization to ~/.bashrc"
fi

# Reload bashrc to apply changes in the current session
source "$HOME/.bashrc"

# Verify installation
echo "Verifying Starship installation..."
starship --version

echo "Starship has been successfully installed and configured."
