#!/bin/bash

# =============================================================================
# Linux Mint Maintenance Cron Setup Script with Email Notifications
# =============================================================================
# This script sets up cron jobs for ongoing maintenance tasks on Linux Mint,
# including system updates, cleaning caches, managing logs, rootkit scans,
# antivirus scans, and more. It also configures email notifications for
# detected harmful issues while avoiding duplicate alerts.
# =============================================================================

# ------------------------------
# Helper Functions for Messaging
# ------------------------------
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

# ------------------------------
# Ensure Script is Run with Root Privileges
# ------------------------------
if [ "$EUID" -ne 0 ]; then
    echo_warning "This script requires root privileges. Please enter your password."
    sudo "$0" "$@"
    exit
fi

# ------------------------------
# Variables
# ------------------------------
MAINTENANCE_DIR="/usr/local/bin/maintenance_scripts"
CRON_D_FILE="/etc/cron.d/linux_mint_maintenance"
LOG_FILE="/var/log/linux_mint_maintenance.log"
ALERT_STATE_DIR="/var/log/maintenance_alerts"

# Prompt user for their email address
read -p "Enter the email address to receive alerts: " USER_EMAIL

# Validate email format (basic validation)
if [[ ! "$USER_EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$ ]]; then
    echo_error "Invalid email format. Please run the script again and enter a valid email address."
    exit 1
fi

# Create Maintenance Directory
if [ ! -d "$MAINTENANCE_DIR" ]; then
    mkdir -p "$MAINTENANCE_DIR"
    echo_success "Created maintenance scripts directory at $MAINTENANCE_DIR."
else
    echo_info "Maintenance scripts directory already exists at $MAINTENANCE_DIR."
fi

# Create Log File if it doesn't exist
if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    echo_success "Created log file at $LOG_FILE."
else
    echo_info "Log file already exists at $LOG_FILE."
fi

# Create Alert State Directory
if [ ! -d "$ALERT_STATE_DIR" ]; then
    mkdir -p "$ALERT_STATE_DIR"
    echo_success "Created alert state directory at $ALERT_STATE_DIR."
else
    echo_info "Alert state directory already exists at $ALERT_STATE_DIR."
fi

# ------------------------------
# Install Necessary Packages
# ------------------------------
echo_info "Installing necessary packages..."

PACKAGES=(
    "rkhunter"             # Rootkit Hunter for rootkit scanning
    "clamav"               # ClamAV antivirus
    "clamav-daemon"        # ClamAV daemon for scheduled scans
    "unattended-upgrades"  # For automatic security updates
    "mailutils"            # For sending email alerts (used in scan scripts)
)

for pkg in "${PACKAGES[@]}"; do
    if dpkg -l | grep -qw "^ii  $pkg "; then
        echo_info "$pkg is already installed."
    else
        apt-get install -y "$pkg"
        if [ $? -eq 0 ]; then
            echo_success "Installed $pkg."
        else
            echo_error "Failed to install $pkg. Please check your network connection and package repositories."
            exit 1
        fi
    fi
done

# Update ClamAV database
echo_info "Updating ClamAV virus database..."
freshclam
if [ $? -eq 0 ]; then
    echo_success "ClamAV virus database updated."
else
    echo_error "Failed to update ClamAV virus database."
    exit 1
fi

# ------------------------------
# Create Maintenance Scripts
# ------------------------------

# 1. System Update and Upgrade Script
UPDATE_SCRIPT="$MAINTENANCE_DIR/system_update.sh"
cat > "$UPDATE_SCRIPT" << EOF
#!/bin/bash
# Script to update and upgrade the system

LOG_FILE="$LOG_FILE"

echo "\$(date '+%Y-%m-%d %H:%M:%S') - Starting system update and upgrade." >> "\$LOG_FILE"
apt-get update >> "\$LOG_FILE" 2>&1
apt-get upgrade -y >> "\$LOG_FILE" 2>&1
echo "\$(date '+%Y-%m-%d %H:%M:%S') - System update and upgrade completed." >> "\$LOG_FILE"
EOF
chmod +x "$UPDATE_SCRIPT"
echo_success "Created system update script."

# 2. Autoremove and Autoclean Script
CLEANUP_SCRIPT="$MAINTENANCE_DIR/cleanup.sh"
cat > "$CLEANUP_SCRIPT" << EOF
#!/bin/bash
# Script to autoremove and autoclean packages

LOG_FILE="$LOG_FILE"

echo "\$(date '+%Y-%m-%d %H:%M:%S') - Starting autoremove and autoclean." >> "\$LOG_FILE"
apt-get autoremove -y >> "\$LOG_FILE" 2>&1
apt-get autoclean -y >> "\$LOG_FILE" 2>&1
echo "\$(date '+%Y-%m-%d %H:%M:%S') - Autoremove and autoclean completed." >> "\$LOG_FILE"
EOF
chmod +x "$CLEANUP_SCRIPT"
echo_success "Created autoremove and autoclean script."

# 3. Clear Thumbnail Cache Script
THUMBNAIL_SCRIPT="$MAINTENANCE_DIR/clear_thumbnail_cache.sh"
cat > "$THUMBNAIL_SCRIPT" << EOF
#!/bin/bash
# Script to clear thumbnail cache for the primary user

LOG_FILE="$LOG_FILE"
CURRENT_USER=\$(logname)

echo "\$(date '+%Y-%m-%d %H:%M:%S') - Starting thumbnail cache cleanup." >> "\$LOG_FILE"
rm -rf "/home/\$CURRENT_USER/.cache/thumbnails/"* >> "\$LOG_FILE" 2>&1
echo "\$(date '+%Y-%m-%d %H:%M:%S') - Thumbnail cache cleanup completed." >> "\$LOG_FILE"
EOF
chmod +x "$THUMBNAIL_SCRIPT"
echo_success "Created thumbnail cache cleanup script."

# 4. Clear Systemd Journal Logs Script
JOURNAL_SCRIPT="$MAINTENANCE_DIR/clear_journal_logs.sh"
cat > "$JOURNAL_SCRIPT" << EOF
#!/bin/bash
# Script to clear systemd journal logs older than 2 days

LOG_FILE="$LOG_FILE"

echo "\$(date '+%Y-%m-%d %H:%M:%S') - Starting systemd journal logs cleanup." >> "\$LOG_FILE"
journalctl --vacuum-time=2d >> "\$LOG_FILE" 2>&1
echo "\$(date '+%Y-%m-%d %H:%M:%S') - Systemd journal logs cleanup completed." >> "\$LOG_FILE"
EOF
chmod +x "$JOURNAL_SCRIPT"
echo_success "Created systemd journal logs cleanup script."

# 5. Rootkit Scan Script with Email Notifications
RKHUNTER_SCRIPT="$MAINTENANCE_DIR/rkhunter_scan.sh"
cat > "$RKHUNTER_SCRIPT" << EOF
#!/bin/bash
# Script to perform rootkit scan using rkhunter and send email alerts on new issues

LOG_FILE="$LOG_FILE"
ALERT_STATE_DIR="$ALERT_STATE_DIR"
STATE_FILE="\$ALERT_STATE_DIR/rkhunter_last_alert.txt"
EMAIL="$USER_EMAIL"

echo "\$(date '+%Y-%m-%d %H:%M:%S') - Starting rkhunter scan." >> "\$LOG_FILE"

# Update rkhunter data files
rkhunter --update >> "\$LOG_FILE" 2>&1

# Run rkhunter scan and capture output
SCAN_OUTPUT=\$(rkhunter --check --sk)

# Append scan output to log
echo "\$SCAN_OUTPUT" >> "\$LOG_FILE"

# Extract warnings or infections
ISSUES=\echo "\$SCAN_OUTPUT" | grep -E "Warning|Infected"

if [ ! -z "\$ISSUES" ]; then
    # Create state file if it doesn't exist
    if [ ! -f "\$STATE_FILE" ]; then
        touch "\$STATE_FILE"
    fi

    # Compare current issues with previous alerts
    NEW_ISSUES=\echo "\$ISSUES" | grep -v -F -f "\$STATE_FILE"

    if [ ! -z "\$NEW_ISSUES" ]; then
        # Send email with new issues
        echo -e "Subject:rkhunter Alert on \$(hostname)\n\nThe following issues were detected by rkhunter:\n\n\$NEW_ISSUES" | sendmail "\$EMAIL"
        
        # Log the alert
        echo "\$(date '+%Y-%m-%d %H:%M:%S') - rkhunter detected new issues. Alert sent to \$EMAIL." >> "\$LOG_FILE"
        
        # Update the state file with new issues
        echo "\$NEW_ISSUES" >> "\$STATE_FILE"
    else
        echo "\$(date '+%Y-%m-%d %H:%M:%S') - rkhunter scan completed with no new issues." >> "\$LOG_FILE"
    fi
else
    echo "\$(date '+%Y-%m-%d %H:%M:%S') - rkhunter scan completed with no issues." >> "\$LOG_FILE"
fi
EOF
chmod +x "$RKHUNTER_SCRIPT"
echo_success "Created rootkit scan script with email notifications."

# 6. Antivirus Scan Script with Email Notifications
CLAMAV_SCRIPT="$MAINTENANCE_DIR/clamav_scan.sh"
cat > "$CLAMAV_SCRIPT" << EOF
#!/bin/bash
# Script to perform antivirus scan using ClamAV and send email alerts on new infections

LOG_FILE="$LOG_FILE"
ALERT_STATE_DIR="$ALERT_STATE_DIR"
STATE_FILE="\$ALERT_STATE_DIR/clamav_last_alert.txt"
EMAIL="$USER_EMAIL"

echo "\$(date '+%Y-%m-%d %H:%M:%S') - Starting ClamAV scan." >> "\$LOG_FILE"

# Run ClamAV scan and capture output
SCAN_OUTPUT=\$(clamscan -r /home/\$(logname) --infected --remove)

# Append scan output to log
echo "\$SCAN_OUTPUT" >> "\$LOG_FILE"

# Extract infected files
INFECTED=\echo "\$SCAN_OUTPUT" | grep "^/"

if [ ! -z "\$INFECTED" ]; then
    # Create state file if it doesn't exist
    if [ ! -f "\$STATE_FILE" ]; then
        touch "\$STATE_FILE"
    fi

    # Compare current infections with previous alerts
    NEW_INFECTED=\echo "\$INFECTED" | grep -v -F -f "\$STATE_FILE"

    if [ ! -z "\$NEW_INFECTED" ]; then
        # Send email with new infections
        echo -e "Subject:ClamAV Alert on \$(hostname)\n\nThe following infections were detected and removed by ClamAV:\n\n\$NEW_INFECTED" | sendmail "\$EMAIL"
        
        # Log the alert
        echo "\$(date '+%Y-%m-%d %H:%M:%S') - ClamAV detected new infections. Alert sent to \$EMAIL." >> "\$LOG_FILE"
        
        # Update the state file with new infections
        echo "\$NEW_INFECTED" >> "\$STATE_FILE"
    else
        echo "\$(date '+%Y-%m-%d %H:%M:%S') - ClamAV scan completed with no new infections." >> "\$LOG_FILE"
    fi
else
    echo "\$(date '+%Y-%m-%d %H:%M:%S') - ClamAV scan completed with no infections." >> "\$LOG_FILE"
fi
EOF
chmod +x "$CLAMAV_SCRIPT"
echo_success "Created antivirus scan script with email notifications."

# 7. Optional: Backup Configuration Files Script
# Uncomment the following section if you want to enable configuration backups

BACKUP_SCRIPT="$MAINTENANCE_DIR/backup_configs.sh"
cat > "$BACKUP_SCRIPT" << EOF
#!/bin/bash
# Script to backup important configuration files

LOG_FILE="$LOG_FILE"
BACKUP_DIR="/var/backups/configs"

echo "\$(date '+%Y-%m-%d %H:%M:%S') - Starting configuration files backup." >> "\$LOG_FILE"
mkdir -p "\$BACKUP_DIR"
cp -r /etc "\$BACKUP_DIR" >> "\$LOG_FILE" 2>&1
echo "\$(date '+%Y-%m-%d %H:%M:%S') - Configuration files backup completed." >> "\$LOG_FILE"
EOF
chmod +x "$BACKUP_SCRIPT"
echo_success "Created configuration files backup script."

# 8. Optional: Monitor Disk Usage Script
# Uncomment the following section if you want to enable disk usage monitoring

DISK_MONITOR_SCRIPT="$MAINTENANCE_DIR/monitor_disk_usage.sh"
cat > "$DISK_MONITOR_SCRIPT" << EOF
#!/bin/bash
# Script to monitor disk usage and send alert if threshold is exceeded

THRESHOLD=80
EMAIL="$USER_EMAIL"

USAGE=\$(df / | grep / | awk '{ print \$5}' | sed 's/%//g')

if [ "\$USAGE" -gt "\$THRESHOLD" ]; then
    echo "Disk usage is above \${THRESHOLD}%. Current usage: \${USAGE}%." | sendmail -s "Disk Usage Alert on \$(hostname)" "\$EMAIL"
fi
EOF
chmod +x "$DISK_MONITOR_SCRIPT"
echo_success "Created disk usage monitoring script."

# ------------------------------
# Set Up Cron Jobs
# ------------------------------
echo_info "Setting up cron jobs..."

# Create Cron.d File
cat > "$CRON_D_FILE" << EOF
# Linux Mint Maintenance Cron Jobs

# m h dom mon dow user command

# System Update and Upgrade - Weekly on Sunday at 2:00 AM
0 2 * * 0 root $MAINTENANCE_DIR/system_update.sh

# Autoremove and Autoclean - Weekly on Sunday at 3:00 AM
0 3 * * 0 root $MAINTENANCE_DIR/cleanup.sh

# Clear Thumbnail Cache - Daily at 4:00 AM
0 4 * * * root $MAINTENANCE_DIR/clear_thumbnail_cache.sh

# Clear Systemd Journal Logs - Weekly on Monday at 5:00 AM
0 5 * * 1 root $MAINTENANCE_DIR/clear_journal_logs.sh

# Rootkit Scan - Weekly on Wednesday at 6:00 AM
0 6 * * 3 root $MAINTENANCE_DIR/rkhunter_scan.sh

# Antivirus Scan - Weekly on Saturday at 7:00 AM
0 7 * * 6 root $MAINTENANCE_DIR/clamav_scan.sh

# Optional: Backup Configuration Files - Monthly on the 1st at 8:00 AM
0 8 1 * * root $MAINTENANCE_DIR/backup_configs.sh

# Optional: Monitor Disk Usage - Daily at 9:00 AM
0 9 * * * root $MAINTENANCE_DIR/monitor_disk_usage.sh

EOF

echo_success "Cron jobs have been set up in $CRON_D_FILE."

# Set permissions for Cron.d File
chmod 644 "$CRON_D_FILE"

# ------------------------------
# Enable and Start Services
# ------------------------------
echo_info "Ensuring necessary services are enabled and running..."

# Enable and Start ClamAV Daemon
systemctl enable clamav-daemon
systemctl start clamav-daemon
if [ $? -eq 0 ]; then
    echo_success "ClamAV daemon enabled and started."
else
    echo_error "Failed to enable/start ClamAV daemon."
    exit 1
fi

# Update rkhunter data files
rkhunter --update
if [ $? -eq 0 ]; then
    echo_success "rkhunter data files updated."
else
    echo_error "Failed to update rkhunter data files."
    exit 1
fi

echo_success "Maintenance setup completed successfully."

# ------------------------------
# Final Instructions
# ------------------------------
echo_info "Please verify the cron jobs by running 'cat /etc/cron.d/linux_mint_maintenance'."
echo_info "All maintenance tasks are scheduled and will run automatically."
echo_info "You can check the log file at $LOG_FILE for maintenance task logs."

# Optional: Prompt for Reboot
read -p "Do you want to reboot now to ensure all changes take effect? (y/n): " choice
if [[ "$choice" =~ ^[Yy]$ ]]; then
    echo_info "Rebooting the system..."
    reboot
else
    echo_info "Please remember to reboot your system later to apply all changes."
fi

# =============================================================================
# End of Script
# =============================================================================
