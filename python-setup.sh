#!/bin/bash

# This script updates the package lists and installs Python 3, pip, and python3.12-venv
# on a WSL Ubuntu environment.

# Exit immediately if a command exits with a non-zero status.
set -e

# Update package list
echo "Updating package lists..."
sudo apt-get update

# Upgrade installed packages (optional)
echo "Upgrading installed packages..."
sudo apt-get upgrade -y

# Install Python 3, pip, and python3.12-venv
echo "Installing Python 3, pip, and python3.12-venv..."
sudo apt-get install -y python3 python3-pip python3.12-venv

# Verify installations
echo "Verifying Python 3 installation:"
python3 --version

echo "Verifying pip installation:"
pip3 --version

# Test if venv module is available by creating a temporary virtual environment
echo "Testing Python venv support..."
python3 -m venv test_env
if [ -d test_env ]; then
    echo "venv module is working correctly."
    # Remove the temporary virtual environment
    rm -rf test_env
else
    echo "Failed to create virtual environment using venv. Please check the installation."
fi

echo "Python 3, pip, and python3.12-venv have been successfully installed on your WSL environment."
