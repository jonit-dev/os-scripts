#!/bin/bash

# Docker Cleanup Script
# This script removes unused Docker containers, images, networks, and build cache.
# It does NOT remove Docker volumes to preserve player data.

# Exit immediately if a command exits with a non-zero status
set -e

# Log file location
LOG_FILE="/var/log/docker_cleanup.log"

# Function to log messages with timestamp
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Start Cleanup
log "Starting Docker cleanup..."

# Prune stopped containers
log "Pruning stopped containers..."
docker container prune -f >> "$LOG_FILE" 2>&1

# Prune unused images
log "Pruning unused images..."
docker image prune -af >> "$LOG_FILE" 2>&1

# Prune unused networks
log "Pruning unused networks..."
docker network prune -f >> "$LOG_FILE" 2>&1

# Prune build cache
log "Pruning build cache..."
docker builder prune -af >> "$LOG_FILE" 2>&1

# Optional: Prune unused volumes (COMMENTED OUT to ensure volumes are not touched)
# log "Pruning unused volumes (skipped to protect player data)..."
# docker volume prune -f >> "$LOG_FILE" 2>&1

# Optional: Prune dangling volumes (if you are sure)
# log "Pruning dangling volumes (skipped to protect player data)..."
# docker volume ls -qf dangling=true | xargs -r docker volume rm >> "$LOG_FILE" 2>&1

# Remove unused Docker images not referenced by any container
log "Removing dangling images..."
docker image prune -af --filter "dangling=true" >> "$LOG_FILE" 2>&1

# Remove all unused images (not just dangling ones)
log "Removing all unused images..."
docker image prune -af >> "$LOG_FILE" 2>&1

# Summary of disk usage after cleanup
log "Disk usage after cleanup:"
df -h /var/lib/docker >> "$LOG_FILE" 2>&1

log "Docker cleanup completed successfully."

# End of Script
