#!/usr/bin/env bash
set -euo pipefail
# -----------------------------------------------------------------------------
# install_playwright_deps.sh
#
# Installs Playwright on WSL (Ubuntu/Debian), including:
#  - system libraries
#  - Node.js/npm check
#  - automatic MongoDB 7.0 repo fix for Ubuntu "noble"
#  - Playwright npm package and browsers
# -----------------------------------------------------------------------------

# 1. Ensure we're running under WSL
if ! grep -qiE "(microsoft|wsl)" /proc/version &>/dev/null; then
  echo "⚠️  This script is intended for WSL (Ubuntu/Debian). Exiting."
  exit 1
fi
echo "✅ Detected WSL environment."

# 2. Check for Node.js & npm
if ! command -v node >/dev/null; then
  echo "❌ Node.js not found. Please install Node.js before running this script."
  exit 1
fi
if ! command -v npm >/dev/null; then
  echo "❌ npm not found. Please install npm before running this script."
  exit 1
fi
echo "✅ Found Node.js v$(node --version) and npm v$(npm --version)."

# 3. Handle MongoDB 7.0 repo issues for Ubuntu 24.04 "noble"
CODENAME=$(lsb_release -cs)
MONGO_LIST="/etc/apt/sources.list.d/mongodb-org-7.0.list"

if [[ "$CODENAME" == "noble" && -f "$MONGO_LIST" ]]; then
  echo "⇒ Found MongoDB 7.0 repo that doesn't support Ubuntu $CODENAME..."
  echo "⇒ Temporarily disabling MongoDB repo to prevent apt update errors..."
  
  # Create backup and disable the repo
  sudo cp "$MONGO_LIST" "${MONGO_LIST}.bak"
  sudo mv "$MONGO_LIST" "${MONGO_LIST}.disabled"
  
  echo "✅ MongoDB repo temporarily disabled (backup created)."
  echo "ℹ️  You can re-enable it later when MongoDB supports Ubuntu 24.04."
fi

# 4. Update apt cache
echo "⇒ Updating package lists…"
sudo apt-get update -qq

# 5. Install Playwright's Linux dependencies
echo "⇒ Installing Playwright system libraries..."

# Use different package lists based on Ubuntu version
if [[ "$CODENAME" == "noble" ]]; then
  # Ubuntu 24.04 package names (with t64 transition)
  sudo apt-get install -y \
    libnss3 libatk1.0-0t64 libatk-bridge2.0-0t64 libcups2t64 libdbus-1-3 libdrm2 \
    libxkbcommon0 libxcomposite1 libxdamage1 libxrandr2 libgbm1 libasound2t64 \
    libatspi2.0-0t64 libwayland-client0 libwayland-cursor0 libwayland-egl1 \
    libxshmfence1 libxtst6 libpangocairo-1.0-0 libgtk-3-0t64 fonts-liberation \
    ca-certificates wget
else
  # Older Ubuntu versions
  sudo apt-get install -y \
    libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libdbus-1-3 libdrm2 \
    libxkbcommon0 libxcomposite1 libxdamage1 libxrandr2 libgbm1 libasound2 \
    libatspi2.0-0 libwayland-client0 libwayland-cursor0 libwayland-egl1-mesa \
    libxshmfence1 libxtst6 libpangocairo-1.0-0 libgtk-3-0 fonts-liberation \
    ca-certificates wget
fi

echo "✅ System libraries installed."

# 6. Install Playwright via npm and download browsers
echo "⇒ Installing Playwright npm package globally (without browsers)…"
PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 npm install -g playwright

echo "⇒ Ensuring any missing OS deps (via Playwright)…"
playwright install-deps

echo "⇒ Downloading Playwright browsers with timeout protection…"
echo "   This may take several minutes for large downloads..."

# Function to clean cache and retry on failure
clean_cache_and_retry() {
  local browser=$1
  echo "⚠️  Browser download failed. Cleaning cache and retrying..."
  rm -rf ~/.cache/ms-playwright
  timeout 600 playwright install $browser || {
    echo "❌ Failed to install $browser even after cache cleanup."
    echo "   You can install it later with: playwright install $browser"
    return 1
  }
  echo "✅ $browser installed successfully after cache cleanup"
  return 0
}

# Install browsers one at a time with timeout and retry logic
for browser in chromium firefox webkit; do
  echo "⇒ Installing $browser browser..."
  timeout 300 playwright install $browser || {
    echo "⚠️  $browser download timed out, retrying once..."
    timeout 600 playwright install $browser || {
      echo "⚠️  $browser download failed again, trying cache cleanup..."
      clean_cache_and_retry $browser || continue
    }
  }
  echo "✅ $browser installed successfully"
done

echo "🎉 Playwright is fully installed and ready to use in WSL!"

# 7. Show info about MongoDB repo if it was disabled
if [[ "$CODENAME" == "noble" && -f "${MONGO_LIST}.disabled" ]]; then
  echo ""
  echo "📝 Note: MongoDB 7.0 repo was disabled due to Ubuntu 24.04 compatibility."
  echo "   To re-enable later: sudo mv ${MONGO_LIST}.disabled ${MONGO_LIST}"
  echo "   Backup available at: ${MONGO_LIST}.bak"
fi
