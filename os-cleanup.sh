#!/bin/bash

# system_cleanup.sh
# Comprehensive system cleanup script for Linux VPS
# Cleans Docker resources, log files, package caches, old kernels, application caches, temporary files, and crash reports.
# Logs all actions to /var/log/system_cleanup.log

# Exit immediately if a command exits with a non-zero status
set -e

# Variables
LOG_FILE="/var/log/system_cleanup.log"

# Function to log messages with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Start of Script
log "========== Starting System Cleanup =========="

# 1. Docker Cleanup
log "Starting Docker cleanup..."

# Prune stopped containers, unused images, networks, and build cache without removing volumes
docker system prune -af >> "$LOG_FILE" 2>&1
docker builder prune -af >> "$LOG_FILE" 2>&1

log "Docker cleanup completed."

# 2. Clean Log Files in /var/log

log "Cleaning log files in /var/log..."

# Truncate specific large log files safely
declare -a LOG_FILES=(
    "/var/log/syslog"
    "/var/log/auth.log"
    "/var/log/kern.log"
    "/var/log/daemon.log"
    "/var/log/messages"
    "/var/log/user.log"
    "/var/log/boot.log"
    "/var/log/dpkg.log"
    "/var/log/apt/history.log"
    "/var/log/apt/term.log"
)

for LOG_FILE_PATH in "${LOG_FILES[@]}"; do
    if [ -f "$LOG_FILE_PATH" ]; then
        log "Truncating $LOG_FILE_PATH"
        sudo truncate -s 0 "$LOG_FILE_PATH"
    else
        log "Log file $LOG_FILE_PATH does not exist. Skipping."
    fi
done

# Remove old compressed log files (*.gz)
log "Removing old compressed log files (*.gz) in /var/log..."
sudo find /var/log -type f -name "*.gz" -delete >> "$LOG_FILE" 2>&1

log "Log file cleanup completed."

# 3. Clean Package Manager Caches

log "Cleaning package manager caches..."

# For Debian/Ubuntu systems
if [ -x "$(command -v apt-get)" ]; then
    log "Running apt-get clean..."
    sudo apt-get clean >> "$LOG_FILE" 2>&1

    log "Running apt-get autoclean..."
    sudo apt-get autoclean >> "$LOG_FILE" 2>&1

    log "Running apt-get autoremove..."
    sudo apt-get autoremove --purge -y >> "$LOG_FILE" 2>&1
fi

log "Package manager cache cleanup completed."

# 4. Remove Old Kernels

log "Removing old kernels..."

# Get current kernel version
CURRENT_KERNEL=$(uname -r)

# List all installed kernels except current
OLD_KERNELS=$(dpkg --list 'linux-image*' | grep ^ii | awk '{print $2}' | grep -v "$CURRENT_KERNEL")

if [ -n "$OLD_KERNELS" ]; then
    for KERNEL in $OLD_KERNELS; do
        log "Removing kernel: $KERNEL"
        sudo apt-get remove --purge -y "$KERNEL" >> "$LOG_FILE" 2>&1
    done
else
    log "No old kernels to remove."
fi

log "Old kernel removal completed."

# 5. Clean Application Caches in /var/cache

log "Cleaning application caches in /var/cache..."

# Clean APT cache (already cleaned above, but ensure)
sudo apt-get clean >> "$LOG_FILE" 2>&1

# Example: Clean npm cache (if Node.js is installed)
if [ -x "$(command -v npm)" ]; then
    log "Cleaning npm cache..."
    npm cache clean --force >> "$LOG_FILE" 2>&1
fi

# Example: Clean yarn cache (if Yarn is installed)
if [ -x "$(command -v yarn)" ]; then
    log "Cleaning yarn cache..."
    yarn cache clean >> "$LOG_FILE" 2>&1
fi

# Remove thumbnail cache (common in desktop environments, safe to remove)
log "Removing thumbnail cache..."
sudo rm -rf /home/*/.cache/thumbnails/* >> "$LOG_FILE" 2>&1 || true

# Add more application-specific cache cleanups as needed

log "Application cache cleanup completed."

# 6. Remove Temporary Files

log "Removing temporary files..."

# Clean /tmp and /var/tmp
sudo rm -rf /tmp/* >> "$LOG_FILE" 2>&1 || true
sudo rm -rf /var/tmp/* >> "$LOG_FILE" 2>&1 || true

log "Temporary files cleanup completed."

# 7. Delete Old Crash Reports

log "Deleting old crash reports in /var/crash..."

sudo rm -f /var/crash/* >> "$LOG_FILE" 2>&1 || true

log "Crash reports cleanup completed."

# 8. Additional Docker Cleanup (Optional)

# If you want to ensure that no dangling Docker volumes are removed, keep them untouched.

# Example: Remove dangling Docker volumes (commented out to preserve data)
# log "Removing dangling Docker volumes..."
# docker volume ls -qf dangling=true | xargs -r docker volume rm >> "$LOG_FILE" 2>&1

# End of Script
log "========== System Cleanup Completed =========="
echo "" >> "$LOG_FILE"
