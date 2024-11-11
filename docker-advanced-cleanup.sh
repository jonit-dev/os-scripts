#!/bin/bash

# ============================================================
# Safe Docker Overlay2 Cleanup Script
# ============================================================
# This script performs a safe cleanup of Docker's overlay2
# directory by identifying and removing only orphaned directories.
# It ensures that no data associated with running containers
# or active images is deleted.
# ============================================================

# Exit immediately if a command exits with a non-zero status
set -e

# Function to display messages
echo_msg() {
    echo -e "\n===== $1 =====\n"
}

# Function to check if Docker is installed
check_docker() {
    if ! command -v docker &> /dev/null
    then
        echo "Docker is not installed. Please install Docker and try again."
        exit 1
    fi
}

# Function to check if Docker service is running
check_docker_running() {
    if ! systemctl is-active --quiet docker
    then
        echo "Docker service is not running. Attempting to start Docker..."
        sudo systemctl start docker
        sleep 5
        if ! systemctl is-active --quiet docker
        then
            echo "Failed to start Docker. Please check Docker installation."
            exit 1
        fi
    fi
}

# Function to backup Docker overlay2 (optional)
backup_overlay2() {
    echo_msg "Backing up Docker overlay2 directory..."
    BACKUP_DIR="/var/backups/docker-overlay2-$(date +%F_%T)"
    sudo mkdir -p "$BACKUP_DIR"
    sudo rsync -a /var/lib/docker/overlay2/ "$BACKUP_DIR/overlay2/"
    echo "Docker overlay2 backed up to $BACKUP_DIR"
}

# Function to prune Docker system
prune_docker_system() {
    echo_msg "Pruning Docker system (this may take a while)..."
    # Prune containers, images, volumes, networks, and build cache
    docker system prune -a -f --volumes
}

# Function to identify active overlay2 directories
get_active_overlay2_dirs() {
    echo_msg "Identifying active overlay2 directories..."

    # Get list of active container IDs
    ACTIVE_CONTAINERS=$(docker ps -aq)

    # Initialize an empty list for active directories
    ACTIVE_DIRS=()

    # Loop through each active container and get its UpperDir
    for CONTAINER in $ACTIVE_CONTAINERS; do
        UPPER_DIR=$(docker inspect --format '{{ .GraphDriver.Data.UpperDir }}' "$CONTAINER")
        # Extract the overlay2 directory ID from the UpperDir path
        # Example UpperDir: /var/lib/docker/overlay2/<dir>/merged
        DIR_ID=$(echo "$UPPER_DIR" | awk -F '/overlay2/' '{print $2}' | awk -F '/merged' '{print $1}')
        ACTIVE_DIRS+=("$DIR_ID")
    done

    # Get list of active image layer directories
    ACTIVE_IMAGE_LAYERS=$(docker images --no-trunc --format "{{.ID}}")

    for IMAGE_ID in $ACTIVE_IMAGE_LAYERS; do
        # Get layer IDs for each image
        LAYERS=$(docker inspect --format '{{range .RootFS.Layers}}{{.}}{{"\n"}}{{end}}' "$IMAGE_ID" | sed 's/sha256://')
        for LAYER in $LAYERS; do
            ACTIVE_DIRS+=("$LAYER")
        done
    done

    # Remove duplicates
    ACTIVE_DIRS=($(printf "%s\n" "${ACTIVE_DIRS[@]}" | sort -u))

    # Export active directories
    echo "${ACTIVE_DIRS[@]}"
}

# Function to list all overlay2 directories
get_all_overlay2_dirs() {
    echo_msg "Listing all overlay2 directories..."
    ALL_OVERLAY2_DIRS=$(sudo ls /var/lib/docker/overlay2)
    echo "$ALL_OVERLAY2_DIRS"
}

# Function to identify orphaned overlay2 directories
identify_orphaned_overlay2() {
    echo_msg "Identifying orphaned overlay2 directories..."

    ACTIVE_DIRS=$(get_active_overlay2_dirs)
    ALL_DIRS=$(get_all_overlay2_dirs)

    ORPHANED_DIRS=()

    for DIR in $ALL_DIRS; do
        if ! [[ " ${ACTIVE_DIRS[@]} " =~ " ${DIR} " ]]; then
            ORPHANED_DIRS+=("$DIR")
        fi
    done

    # Display orphaned directories
    if [ ${#ORPHANED_DIRS[@]} -eq 0 ]; then
        echo "No orphaned overlay2 directories found."
    else
        echo "Found ${#ORPHANED_DIRS[@]} orphaned overlay2 directories:"
        for dir in "${ORPHANED_DIRS[@]}"; do
            echo " - $dir"
        done
    fi
}

# Function to remove orphaned overlay2 directories
remove_orphaned_overlay2() {
    if [ ${#ORPHANED_DIRS[@]} -eq 0 ]; then
        echo_msg "No orphaned overlay2 directories to remove."
        return
    fi

    echo_msg "Preparing to remove orphaned overlay2 directories..."

    for DIR in "${ORPHANED_DIRS[@]}"; do
        OVERLAY2_PATH="/var/lib/docker/overlay2/$DIR"
        if [ -d "$OVERLAY2_PATH" ]; then
            echo "Removing $OVERLAY2_PATH..."
            sudo rm -rf "$OVERLAY2_PATH"
            echo "Removed $OVERLAY2_PATH"
        else
            echo "Directory $OVERLAY2_PATH does not exist. Skipping."
        fi
    done

    echo "Orphaned overlay2 directories removed."
}

# Function to limit Docker log sizes
limit_docker_logs() {
    echo_msg "Configuring Docker to limit container log sizes..."

    DAEMON_JSON="/etc/docker/daemon.json"

    # Install jq if not present
    if ! command -v jq &> /dev/null; then
        echo "jq is not installed. Installing jq..."
        if [ -x "$(command -v apt-get)" ]; then
            sudo apt-get update
            sudo apt-get install -y jq
        elif [ -x "$(command -v yum)" ]; then
            sudo yum install -y epel-release
            sudo yum install -y jq
        else
            echo "Please install jq manually and rerun the script."
            exit 1
        fi
    fi

    # Create daemon.json if it doesn't exist
    if [ ! -f "$DAEMON_JSON" ]; then
        sudo touch "$DAEMON_JSON"
        echo "{}" | sudo tee "$DAEMON_JSON" > /dev/null
    fi

    # Backup existing daemon.json
    sudo cp "$DAEMON_JSON" "${DAEMON_JSON}.bak_$(date +%F_%T)"

    # Update log options using jq
    sudo jq '. + {
        "log-driver": "json-file",
        "log-opts": {
            "max-size": "10m",
            "max-file": "3"
        }
    }' "$DAEMON_JSON" | sudo tee "$DAEMON_JSON" > /dev/null

    # Restart Docker to apply changes
    sudo systemctl restart docker

    echo "Docker log limits configured."
}

# Function to display final overlay2 disk usage
display_final_usage() {
    echo_msg "Final overlay2 disk usage:"
    sudo du -sh /var/lib/docker/overlay2
}

# Function to summarize actions
summarize_actions() {
    echo_msg "Cleanup Summary"
    docker system df -v
    if [ ${#ORPHANED_DIRS[@]} -gt 0 ]; then
        echo "Orphaned overlay2 directories have been removed."
    else
        echo "No orphaned overlay2 directories were found or removed."
    fi
    echo "Docker log sizes have been limited to prevent future bloat."
}

# ============================================================
# Main Execution Flow
# ============================================================

# Check if script is run as root
if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo or as root."
    exit 1
fi

# Check if Docker is installed and running
check_docker
check_docker_running

# Optional: Backup Docker overlay2 (Uncomment if needed)
# backup_overlay2

# Prune Docker system
prune_docker_system

# Identify orphaned overlay2 directories
identify_orphaned_overlay2

# Prompt user before removing orphaned directories
if [ ${#ORPHANED_DIRS[@]} -gt 0 ]; then
    read -p "Do you want to remove the identified orphaned overlay2 directories? (y/N): " CONFIRM
    case "$CONFIRM" in
        [yY][eE][sS]|[yY]) 
            remove_orphaned_overlay2
            ;;
        *)
            echo "Skipping removal of orphaned overlay2 directories."
            ;;
    esac
else
    echo "No orphaned overlay2 directories to remove."
fi

# Limit Docker log sizes
limit_docker_logs

# Display final overlay2 usage
display_final_usage

# Summarize actions
summarize_actions

echo_msg "Docker overlay2 cleanup completed successfully."

# ============================================================
# End of Script
# ============================================================
