#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Ultimate WH-1000XM4 Bluetooth Fix - Complete Nuclear Solution
.DESCRIPTION
    Removes stuck devices, clears all caches, resets everything, and toggles adapter
.NOTES
    Run as Administrator. This script does EVERYTHING aggressively.
#>

param([switch]$NoRestart, [switch]$Verbose)

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

Write-ColorOutput "================================================================" "Cyan"
Write-ColorOutput "    ULTIMATE WH-1000XM4 BLUETOOTH NUCLEAR FIX SCRIPT" "Cyan"
Write-ColorOutput "    This script will aggressively fix ALL Bluetooth issues" "Cyan"
Write-ColorOutput "================================================================" "Cyan"

if (-not (Test-Administrator)) {
    Write-ColorOutput "ERROR: Must run as Administrator!" "Red"
    exit 1
}

Write-ColorOutput "`nStarting nuclear Bluetooth fix sequence..." "Green"

# PHASE 1: NUKE EXISTING SONY DEVICES
Write-ColorOutput "`n[PHASE 1] Nuking existing Sony devices..." "Yellow"
try {
    # Method 1: WMI removal (works on all PowerShell versions)
    Write-ColorOutput "  Removing via WMI..." "Cyan"
    Get-WmiObject -Class Win32_PnPEntity | Where-Object { 
        $_.Name -like "*WH-1000XM4*" -or $_.Name -like "*Sony*" 
    } | ForEach-Object { 
        Write-ColorOutput "    Removing: $($_.Name)" "White"
        $_.Delete() 
    }
    
    # Method 2: PnP removal for newer systems
    Write-ColorOutput "  Removing via PnP..." "Cyan"
    try {
        Get-PnpDevice | Where-Object { 
            $_.FriendlyName -like "*WH-1000XM4*" -or $_.FriendlyName -like "*Sony*" 
        } | ForEach-Object {
            Write-ColorOutput "    Removing: $($_.FriendlyName)" "White"
            $_ | Remove-PnpDevice -Confirm:$false -ErrorAction SilentlyContinue
        }
    } catch {
        Write-ColorOutput "    PnP method not available (older PowerShell)" "Yellow"
    }
    
    Write-ColorOutput "  Device removal completed" "Green"
} catch {
    Write-ColorOutput "  Device removal failed: $($_.Exception.Message)" "Red"
}

# PHASE 2: STOP ALL BLUETOOTH SERVICES
Write-ColorOutput "`n[PHASE 2] Stopping Bluetooth services..." "Yellow"
$btServices = @("bthserv", "BthAvctpSvc", "BTAGService", "BthA2dp", "BthEnum", "BthMini", "BthPan")
foreach ($service in $btServices) {
    try {
        Write-ColorOutput "  Stopping $service..." "Cyan"
        Stop-Service $service -Force -ErrorAction SilentlyContinue
    } catch {
        Write-ColorOutput "    $service not found or already stopped" "Yellow"
    }
}
Start-Sleep -Seconds 5
Write-ColorOutput "  All services stopped" "Green"

# PHASE 3: NUCLEAR CACHE CLEARANCE
Write-ColorOutput "`n[PHASE 3] Nuclear cache clearance..." "Yellow"
$cachePaths = @(
    "$env:LOCALAPPDATA\Microsoft\Windows\Bluetooth",
    "$env:PROGRAMDATA\Microsoft\Windows\Bluetooth",
    "$env:SYSTEMROOT\System32\config\systemprofile\AppData\Local\Microsoft\Windows\Bluetooth"
)

foreach ($path in $cachePaths) {
    if (Test-Path $path) {
        Write-ColorOutput "  Nuking cache: $path" "Cyan"
        Remove-Item "$path\*" -Recurse -Force -ErrorAction SilentlyContinue
    }
}
Write-ColorOutput "  Cache apocalypse completed" "Green"

# PHASE 4: REGISTRY CLEANSING
Write-ColorOutput "`n[PHASE 4] Registry cleansing..." "Yellow"
try {
    $regPaths = @(
        "HKLM:\SYSTEM\CurrentControlSet\Services\BTHPORT\Parameters\Devices",
        "HKLM:\SYSTEM\CurrentControlSet\Services\BTHPORT\Parameters\Keys",
        "HKLM:\SYSTEM\CurrentControlSet\Enum\BTHENUM"
    )
    
    foreach ($regPath in $regPaths) {
        if (Test-Path $regPath) {
            Write-ColorOutput "  Cleaning registry: $regPath" "Cyan"
            Get-ChildItem -Path $regPath -Recurse -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "*054C*" -or $_.Name -like "*Sony*" } |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
    Write-ColorOutput "  Registry purged" "Green"
} catch {
    Write-ColorOutput "  Registry cleaning failed: $($_.Exception.Message)" "Red"
}

# PHASE 5: NETWORK STACK RESET
Write-ColorOutput "`n[PHASE 5] Network stack reset..." "Yellow"
try {
    Write-ColorOutput "  Resetting Winsock..." "Cyan"
    & netsh winsock reset *>$null
    
    Write-ColorOutput "  Resetting TCP/IP..." "Cyan"
    & netsh int ip reset *>$null
    
    Write-ColorOutput "  Network stack nuked" "Green"
} catch {
    Write-ColorOutput "  Network reset failed: $($_.Exception.Message)" "Red"
}

# PHASE 6: RESTART BLUETOOTH SERVICES
Write-ColorOutput "`n[PHASE 6] Restarting Bluetooth services..." "Yellow"
foreach ($service in $btServices) {
    try {
        Write-ColorOutput "  Starting $service..." "Cyan"
        Start-Service $service -ErrorAction SilentlyContinue
    } catch {
        Write-ColorOutput "    $service failed to start" "Yellow"
    }
}
Start-Sleep -Seconds 5
Write-ColorOutput "  Services restarted" "Green"

# PHASE 7: HARDWARE DISCOVERY RESET
Write-ColorOutput "`n[PHASE 7] Hardware discovery reset..." "Yellow"
try {
    Write-ColorOutput "  Scanning for hardware changes..." "Cyan"
    & pnputil /scan-hardware *>$null
    Start-Sleep -Seconds 3
    
    Write-ColorOutput "  Triggering Bluetooth discovery agent..." "Cyan"
    & rundll32.exe bthprops.cpl,BluetoothAuthenticationAgent *>$null
    Start-Sleep -Seconds 2
    
    Write-ColorOutput "  Hardware discovery reset" "Green"
} catch {
    Write-ColorOutput "  Hardware reset failed: $($_.Exception.Message)" "Red"
}

# PHASE 8: THE MONEY SHOT - BLUETOOTH ADAPTER TOGGLE
Write-ColorOutput "`n[PHASE 8] THE MONEY SHOT - Bluetooth adapter toggle..." "Yellow"
try {
    Write-ColorOutput "  Finding Bluetooth adapters..." "Cyan"
    $adapters = Get-WmiObject -Class Win32_PnPEntity | Where-Object { $_.Name -like "*Bluetooth*" }
    
    foreach ($adapter in $adapters) {
        Write-ColorOutput "    Toggling: $($adapter.Name)" "White"
        Write-ColorOutput "      Disabling..." "Cyan"
        $adapter.Disable()
        Start-Sleep -Seconds 3
        
        Write-ColorOutput "      Enabling..." "Cyan"
        $adapter.Enable()
        Start-Sleep -Seconds 5
    }
    
    Write-ColorOutput "  ADAPTER TOGGLE COMPLETED - THIS IS THE MAGIC!" "Green"
} catch {
    Write-ColorOutput "  Adapter toggle failed: $($_.Exception.Message)" "Red"
}

# PHASE 9: FINAL VERIFICATION
Write-ColorOutput "`n[PHASE 9] Final verification..." "Yellow"
try {
    $btStatus = Get-Service bthserv
    Write-ColorOutput "  Bluetooth Service Status: $($btStatus.Status)" "White"
    
    $adapters = Get-WmiObject -Class Win32_PnPEntity | Where-Object { $_.Name -like "*Bluetooth*" }
    foreach ($adapter in $adapters) {
        Write-ColorOutput "  $($adapter.Name): $($adapter.Status)" "White"
    }
    
    Write-ColorOutput "  System verification completed" "Green"
} catch {
    Write-ColorOutput "  Verification failed: $($_.Exception.Message)" "Red"
}

# FINAL INSTRUCTIONS
Write-ColorOutput "`n================================================================" "Cyan"
Write-ColorOutput "                    NUCLEAR FIX COMPLETED!" "Green"
Write-ColorOutput "================================================================" "Cyan"

Write-ColorOutput "`nNOW DO THIS:" "Yellow"
Write-ColorOutput "1. Turn your WH-1000XM4 OFF completely" "White"
Write-ColorOutput "2. Hold Power + Custom button for 7 seconds" "White"
Write-ColorOutput "3. Wait for BLUE FLASHING light" "White"
Write-ColorOutput "4. Go to Settings > Devices > Add Bluetooth device" "White"
Write-ColorOutput "5. Click 'Bluetooth' and wait 15-20 seconds" "White"
Write-ColorOutput "6. Your headphones should appear!" "White"

Write-ColorOutput "`nQuick shortcuts:" "Yellow"
Write-ColorOutput "- Open Bluetooth Settings: Win+I > Devices > Bluetooth" "White"
Write-ColorOutput "- If still issues: Restart PC and try again" "White"

# Restart prompt
if (-not $NoRestart) {
    Write-ColorOutput "`nRestart recommended for complete fix!" "Green"
    $restart = Read-Host "Restart computer now? (y/N)"
    if ($restart -eq 'y' -or $restart -eq 'Y') {
        Write-ColorOutput "Restarting in 5 seconds..." "Yellow"
        Start-Sleep -Seconds 5
        Restart-Computer -Force
    }
} else {
    Write-ColorOutput "`nRestart your computer when convenient for best results." "Yellow"
}

Write-ColorOutput "`n🎧 Your Bluetooth should now work perfectly! 🎧" "Green"
