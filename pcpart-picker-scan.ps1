<#
.SYNOPSIS
    Gathers hardware and system information from the local Windows computer.

.DESCRIPTION
    This script uses WMI/CIM queries to retrieve details about various hardware
    components like CPU, Motherboard, Memory, Storage, GPU, OS, Monitors,
    Network Adapters, and some Peripherals. It attempts to mirror the categories
    found on PC part building websites, but notes limitations where information
    is not typically available programmatically.

.NOTES
    Author: AI Assistant
    Date:   2025-04-27
    Requires: PowerShell 3.0 or later. Run as Administrator for best results.

    Limitations:
    - Cannot detect specific CPU Cooler, Case, Power Supply (PSU) models.
    - Cannot detect Case Accessories, Fans, Fan Controllers, Thermal Compound, UPS Systems.
    - Peripheral detection might be generic depending on drivers.
#>

# --- Clear Screen (Optional) ---
# Clear-Host

Write-Host "=============================================" -ForegroundColor Green
Write-Host "      System Hardware Information"
Write-Host "=============================================" -ForegroundColor Green
Write-Host "Generated: $(Get-Date)"
Write-Host ""

# --- CPU ---
Write-Host "--- CPU ---" -ForegroundColor Yellow
try {
    Get-CimInstance -ClassName Win32_Processor | Select-Object -Property @{Name='Component'; Expression={'CPU'}}, Name, Manufacturer, NumberOfCores, NumberOfLogicalProcessors, MaxClockSpeed | Format-List
} catch {
    Write-Warning "Could not retrieve CPU information. Error: $($_.Exception.Message)"
}
Write-Host ""

# --- CPU Cooler ---
Write-Host "--- CPU Cooler ---" -ForegroundColor Yellow
Write-Host "Component: CPU Cooler"
Write-Host "Status: Information not typically available via standard OS queries."
Write-Host "Note: Check system physically or via BIOS/UEFI if needed."
Write-Host ""

# --- Motherboard ---
Write-Host "--- Motherboard ---" -ForegroundColor Yellow
try {
    Get-CimInstance -ClassName Win32_BaseBoard | Select-Object -Property @{Name='Component'; Expression={'Motherboard'}}, Manufacturer, Product, SerialNumber, Version | Format-List
} catch {
    Write-Warning "Could not retrieve Motherboard information. Error: $($_.Exception.Message)"
}
Write-Host ""

# --- Memory (RAM) ---
Write-Host "--- Memory (RAM) ---" -ForegroundColor Yellow
try {
    $memoryModules = Get-CimInstance -ClassName Win32_PhysicalMemory
    $totalMemoryGB = ($memoryModules | Measure-Object -Property Capacity -Sum).Sum / 1GB
    Write-Host "Component          : Memory"
    Write-Host "Total Installed    : $($totalMemoryGB.ToString('F2')) GB"
    Write-Host "Individual Modules :"
    $memoryModules | Select-Object -Property DeviceLocator, Manufacturer, PartNumber, Speed, @{Name='Capacity(GB)';Expression={$_.Capacity / 1GB}} | Format-Table -AutoSize
} catch {
    Write-Warning "Could not retrieve Memory information. Error: $($_.Exception.Message)"
}
Write-Host ""

# --- Storage ---
Write-Host "--- Storage ---" -ForegroundColor Yellow
Write-Host "Component: Storage (Physical Drives)"
try {
    Get-CimInstance -ClassName Win32_DiskDrive | Select-Object -Property Model, InterfaceType, MediaType, @{Name='Size(GB)';Expression={[math]::Round($_.Size / 1GB, 2)}} | Format-List
} catch {
    Write-Warning "Could not retrieve physical Disk Drive information. Error: $($_.Exception.Message)"
}
Write-Host "Component: Storage (Logical Volumes/Partitions - Fixed Disks)"
try {
    Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object {$_.DriveType -eq 3} | Select-Object DeviceID, VolumeName, @{Name='Size(GB)';Expression={[math]::Round($_.Size / 1GB, 2)}}, @{Name='FreeSpace(GB)';Expression={[math]::Round($_.FreeSpace / 1GB, 2)}} | Format-Table -AutoSize
} catch {
    Write-Warning "Could not retrieve Logical Disk information. Error: $($_.Exception.Message)"
}
Write-Host ""

# --- Video Card (GPU) ---
Write-Host "--- Video Card (GPU) ---" -ForegroundColor Yellow
try {
    Get-CimInstance -ClassName Win32_VideoController | Select-Object -Property @{Name='Component'; Expression={'Video Card'}}, Name, AdapterCompatibility, VideoProcessor, DriverVersion, @{Name='AdapterRAM(GB)';Expression={[math]::Round($_.AdapterRAM / 1GB, 2)}} | Format-List
} catch {
    Write-Warning "Could not retrieve Video Controller information. Error: $($_.Exception.Message)"
}
Write-Host ""

# --- Case ---
Write-Host "--- Case ---" -ForegroundColor Yellow
Write-Host "Component: Case"
Write-Host "Status: Information not typically available via standard OS queries."
Write-Host "Note: Check system physically."
Write-Host ""

# --- Power Supply (PSU) ---
Write-Host "--- Power Supply (PSU) ---" -ForegroundColor Yellow
Write-Host "Component: Power Supply"
Write-Host "Status: Information not typically available via standard OS queries."
Write-Host "Note: Check system physically."
Write-Host ""

# --- Operating System ---
Write-Host "--- Operating System ---" -ForegroundColor Yellow
try {
    Get-CimInstance -ClassName Win32_OperatingSystem | Select-Object -Property @{Name='Component'; Expression={'Operating System'}}, Caption, Version, BuildNumber, OSArchitecture, InstallDate | Format-List
} catch {
    Write-Warning "Could not retrieve Operating System information. Error: $($_.Exception.Message)"
}
Write-Host ""

# --- Monitor(s) ---
Write-Host "--- Monitor(s) ---" -ForegroundColor Yellow
Write-Host "Component: Monitor"
Write-Host "Note: Information accuracy depends on monitor drivers/EDID data."
try {
    Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID | ForEach-Object {
        $Manufacturer = ($_.ManufacturerName -ne $null) -join '' -replace '[^A-Za-z0-9]+', ''
        $Name = ($_.UserFriendlyName -ne $null) -join '' -replace '[^A-Za-z0-9\s]+', ''
        $Serial = ($_.SerialNumberID -ne $null) -join '' -replace '[^A-Za-z0-9]+', ''
        [PSCustomObject]@{
            Manufacturer = if ($Manufacturer) { $Manufacturer } else { 'N/A' }
            Name         = if ($Name) { $Name } else { 'N/A' }
            Serial       = if ($Serial) { $Serial } else { 'N/A' }
            # InstanceName = $_.InstanceName # Uncomment for more technical identifier
        }
    } | Format-List
    # Fallback or additional info (less specific often)
    # Get-CimInstance -ClassName Win32_DesktopMonitor | Select-Object Name, MonitorManufacturer, ScreenHeight, ScreenWidth | Format-List
} catch {
    Write-Warning "Could not retrieve Monitor information using WmiMonitorID. Error: $($_.Exception.Message)"
    Write-Warning "Attempting fallback Win32_DesktopMonitor..."
    try {
        Get-CimInstance -ClassName Win32_DesktopMonitor | Select-Object Name, MonitorManufacturer, ScreenHeight, ScreenWidth | Format-List
    } catch {
       Write-Warning "Could not retrieve Monitor information using Win32_DesktopMonitor. Error: $($_.Exception.Message)"
    }
}
Write-Host ""


# --- Expansion Cards / Networking ---
Write-Host "--- Sound Cards ---" -ForegroundColor Yellow
Write-Host "Component: Sound Card / Audio Device"
try {
    Get-CimInstance -ClassName Win32_SoundDevice | Where-Object {$_.Status -eq 'OK'} | Select-Object -Property Name, Manufacturer, Status | Format-List
} catch {
    Write-Warning "Could not retrieve Sound Device information. Error: $($_.Exception.Message)"
}
Write-Host ""

Write-Host "--- Network Adapters (Physical Wired/Wireless) ---" -ForegroundColor Yellow
Write-Host "Component: Network Adapter"
try {
    Get-CimInstance -ClassName Win32_NetworkAdapter -Filter "PhysicalAdapter = True" | Select-Object -Property Name, InterfaceDescription, Manufacturer, MACAddress, NetConnectionID, @{Name='Status'; Expression = {($_.NetConnectionStatus | ConvertFrom-NetConnectionStatus)}} | Format-List
} catch {
    Write-Warning "Could not retrieve Network Adapter information. Error: $($_.Exception.Message)"
}
# Helper function for Network Adapter Status (Requires PS 5.1+)
function ConvertFrom-NetConnectionStatus {
    param($StatusNumber)
    switch ($StatusNumber) {
        0 { "Disconnected" }
        1 { "Connecting" }
        2 { "Connected" }
        3 { "Disconnecting" }
        4 { "Hardware Not Present" }
        5 { "Hardware Disabled" }
        6 { "Hardware Malfunction" }
        7 { "Media Disconnected" }
        8 { "Authenticating" }
        9 { "Authentication Succeeded" }
        10 { "Authentication Failed" }
        11 { "Invalid Address" }
        12 { "Credentials Required" }
        default { "Unknown Status ($StatusNumber)" }
    }
}
Write-Host ""


# --- Peripherals ---
Write-Host "--- Keyboards ---" -ForegroundColor Yellow
Write-Host "Component: Keyboard"
try {
    Get-CimInstance -ClassName Win32_Keyboard | Select-Object -Property Name, Description, Layout | Format-List
} catch {
    Write-Warning "Could not retrieve Keyboard information. Error: $($_.Exception.Message)"
}
Write-Host ""

Write-Host "--- Mice / Pointing Devices ---" -ForegroundColor Yellow
Write-Host "Component: Mouse / Pointing Device"
try {
    Get-CimInstance -ClassName Win32_PointingDevice | Select-Object -Property Name, Manufacturer, Description, HardwareType | Format-List
} catch {
    Write-Warning "Could not retrieve Pointing Device information. Error: $($_.Exception.Message)"
}
Write-Host ""

Write-Host "--- Webcams ---" -ForegroundColor Yellow
Write-Host "Component: Webcam"
Write-Host "Note: Detection can be unreliable; multiple devices might appear."
try {
    # Attempting to find devices classified as Camera or Imaging Device, or common USB video services
    Get-CimInstance -ClassName Win32_PnPEntity | Where-Object {$_.Service -eq 'usbvideo' -or $_.Service -eq 'camera' -or $_.PNPClass -eq 'Camera' -or $_.PNPClass -eq 'Image'} | Select-Object -Property Name, Manufacturer, Description, Service, PNPClass | Format-List
} catch {
    Write-Warning "Could not retrieve Webcam information via PnPEntity. Error: $($_.Exception.Message)"
}
Write-Host ""

Write-Host "--- Speakers / Headphones ---" -ForegroundColor Yellow
Write-Host "Component: Speakers / Headphones"
Write-Host "Note: Often listed under 'Sound Cards / Audio Devices' above. Check physical connections."
Write-Host ""


# --- Accessories / Other ---
Write-Host "--- Optical Drives (CD/DVD/Blu-ray) ---" -ForegroundColor Yellow
Write-Host "Component: Optical Drive"
try {
    Get-CimInstance -ClassName Win32_CDROMDrive | Select-Object -Property Name, Drive, MediaType, Manufacturer | Format-List
} catch {
    # If no drive exists, this might throw an error or return nothing. Gracefully handle.
     if ($_.Exception.Message -like '*No instances found*') {
        Write-Host "No optical drives detected."
     } else {
        Write-Warning "Could not retrieve Optical Drive information. Error: $($_.Exception.Message)"
     }
}
Write-Host ""

Write-Host "--- External Storage (Currently Connected USB Drives) ---" -ForegroundColor Yellow
Write-Host "Component: External Storage (USB)"
try {
    Get-CimInstance -ClassName Win32_DiskDrive -Filter "InterfaceType='USB'" | Select-Object -Property Model, @{Name='Size(GB)';Expression={[math]::Round($_.Size / 1GB, 2)}}, InterfaceType | Format-List
} catch {
     if ($_.Exception.Message -like '*No instances found*') {
        Write-Host "No USB disk drives currently detected."
     } else {
        Write-Warning "Could not retrieve USB Disk Drive information. Error: $($_.Exception.Message)"
     }
}
Write-Host ""

Write-Host "--- Other Accessories (Case Fans, Controllers, UPS, etc.) ---" -ForegroundColor Yellow
Write-Host "Components: Case Accessories, Case Fans, Fan Controllers, Thermal Compound, UPS Systems"
Write-Host "Status: Information not typically available via standard OS queries."
Write-Host ""


# --- Custom Part ---
Write-Host "--- Custom Part ---" -ForegroundColor Yellow
Write-Host "Component: Custom Part"
Write-Host "Status: Add manually if needed."
Write-Host ""

Write-Host "=============================================" -ForegroundColor Green
Write-Host "            Script Finished"
Write-Host "=============================================" -ForegroundColor Green
