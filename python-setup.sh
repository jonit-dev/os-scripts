#!/bin/bash

# This script updates the package lists, installs Python 3 and pip on a WSL Ubuntu environment.

# Exit immediately if a command exits with a non-zero status.
set -e

# Update package list
echo "Updating package lists..."
sudo apt-get update

# Upgrade installed packages (optional)
echo "Upgrading installed packages..."
sudo apt-get upgrade -y

# Install Python 3 and pip
echo "Installing Python 3 and pip..."
sudo apt-get install -y python3 python3-pip

# Verify installations
echo "Verifying Python 3 installation:"
python3 --version

echo "Verifying pip installation:"
pip3 --version

echo "Python 3 and pip have been successfully installed on your WSL environment."
