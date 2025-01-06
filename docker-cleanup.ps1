# Optimize-WSL-Docker.ps1

<#
.SYNOPSIS
    A master script to clean up WSL swap.vhdx files and compact the main WSL virtual disk.

.DESCRIPTION
    This script performs the following actions:
    1. Stops Docker Desktop and WSL.
    2. Locates and deletes all swap.vhdx files in specified temporary directories.
    3. Backs up the main WSL virtual disk (ext4.vhdx).
    4. Compacts the main WSL virtual disk to reclaim unused space.
    5. Restarts Docker Desktop.

.NOTES
    - Ensure you run this script as an Administrator.
    - It's recommended to back up important data before running the script.
#>

# ---------------------- Configuration Section ----------------------

# Path to the main WSL VHDX file
$MainVHDXPath = "C:\Users\joao\AppData\Local\Docker\wsl\data\ext4.vhdx"

# Backup directory for the main VHDX
$BackupDir = "C:\Users\joao\Backups"

# Path to Docker Desktop executable
$DockerDesktopPath = "C:\Program Files\Docker\Docker\Docker Desktop.exe"

# Root temporary directory to search for swap.vhdx files
$TempRoot = "C:\Users\joao\AppData\Local\Temp"

# ---------------------- Function Definitions ----------------------

# Function to check if a module is installed
function Is-ModuleInstalled($moduleName) {
    return Get-Module -ListAvailable -Name $moduleName -ErrorAction SilentlyContinue
}

# Function to ensure the script is run as Administrator
function Ensure-Administrator {
    $currentUser = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)) {
        Write-Error "This script must be run as an Administrator. Please restart PowerShell with elevated privileges."
        exit 1
    }
}

# Function to stop Docker Desktop
function Stop-DockerDesktop {
    Write-Output "Stopping Docker Desktop..."
    $dockerProcesses = Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue
    if ($dockerProcesses) {
        Stop-Process -Name "Docker Desktop" -Force
        Write-Output "Docker Desktop has been stopped."
    } else {
        Write-Output "Docker Desktop is not currently running."
    }
}

# Function to stop WSL
function Stop-WSL {
    Write-Output "Shutting down WSL..."
    try {
        wsl --shutdown
        Write-Output "WSL has been shut down."
    } catch {
        Write-Warning "Failed to shut down WSL: $_"
    }
}

# Function to start Docker Desktop
function Start-DockerDesktop {
    Write-Output "Starting Docker Desktop..."
    try {
        Start-Process -FilePath $DockerDesktopPath
        Write-Output "Docker Desktop has been started."
    } catch {
        Write-Warning "Failed to start Docker Desktop: $_"
    }
}

# Function to find and delete all swap.vhdx files
function Cleanup-SwapVHDX {
    Write-Output "Searching for all swap.vhdx files in $TempRoot and its subdirectories..."
    $swapFiles = Get-ChildItem -Path $TempRoot -Recurse -Filter "swap.vhdx" -ErrorAction SilentlyContinue

    if ($swapFiles.Count -eq 0) {
        Write-Output "No swap.vhdx files found."
        return
    }

    Write-Output "Found $($swapFiles.Count) swap.vhdx file(s):"
    $swapFiles | ForEach-Object { Write-Output $_.FullName }

    # Confirm deletion
    $confirmation = Read-Host "Do you want to delete these swap.vhdx files? (Y/N)"
    if ($confirmation -notin @('Y', 'y')) {
        Write-Output "Deletion of swap.vhdx files canceled by user."
        return
    }

    # Attempt to delete each swap.vhdx file
    foreach ($file in $swapFiles) {
        try {
            Remove-Item -Path $file.FullName -Force -ErrorAction Stop
            Write-Output "Deleted: $($file.FullName)"
        } catch {
            Write-Warning "Failed to delete $($file.FullName): $_"
        }
    }

    Write-Output "Cleanup of swap.vhdx files completed."
}

# Function to back up the main WSL VHDX
function Backup-MainWSLVHDX {
    if (!(Test-Path $MainVHDXPath)) {
        Write-Warning "Main WSL VHDX file not found at path: $MainVHDXPath"
        return
    }

    # Create backup directory if it doesn't exist
    if (-not (Test-Path $BackupDir)) {
        try {
            New-Item -Path $BackupDir -ItemType Directory -Force | Out-Null
            Write-Output "Created backup directory at $BackupDir."
        } catch {
            Write-Warning "Failed to create backup directory: $_"
            return
        }
    }

    $backupPath = Join-Path -Path $BackupDir -ChildPath ("ext4_backup_{0}.vhdx" -f (Get-Date -Format 'yyyyMMddHHmmss'))

    Write-Output "Backing up main WSL VHDX file to $backupPath..."
    try {
        Copy-Item -Path $MainVHDXPath -Destination $backupPath -Force -ErrorAction Stop
        Write-Output "Backup completed successfully."
    } catch {
        Write-Warning "Failed to back up main WSL VHDX: $_"
    }
}

# Function to compact the main WSL VHDX
function Compact-MainWSLVHDX {
    if (!(Test-Path $MainVHDXPath)) {
        Write-Warning "Main WSL VHDX file not found at path: $MainVHDXPath"
        return
    }

    Write-Output "Compacting the main WSL VHDX file located at $MainVHDXPath..."
    try {
        Optimize-VHD -Path $MainVHDXPath -Mode Full
        Write-Output "Main WSL VHDX compacted successfully."
    } catch {
        Write-Warning "An error occurred while compacting the main VHDX: $_"
    }
}

# ---------------------- Main Execution Flow ----------------------

# Ensure the script is run as Administrator
Ensure-Administrator

# Stop Docker Desktop and WSL
Stop-DockerDesktop
Stop-WSL

# Cleanup swap.vhdx files
Cleanup-SwapVHDX

# Backup the main WSL VHDX
Backup-MainWSLVHDX

# Compact the main WSL VHDX
Compact-MainWSLVHDX

# Restart Docker Desktop
Start-DockerDesktop

Write-Output "WSL and Docker optimization completed successfully."

# ---------------------- End of Script ----------------------
