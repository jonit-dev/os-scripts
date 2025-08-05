<#  
    Diagnose-WSL.ps1  
    ----------------  
    Collects a full snapshot of WSL health, Hyper-V/WSL event logs,  
    VHDX usage, Linux-side logs, and flags obvious resource issues.

    Usage (elevated PowerShell):
      Set-ExecutionPolicy Bypass -Scope Process -Force
      .\Diagnose-WSL.ps1 -OutputPath C:\WSL-Diag   # default: Desktop\WSL-Diag

    Output:
      • Full logs & XML under OutputPath  
      • diagnose.log with summary & “🚨 Potential issues”  
#>

[CmdletBinding()]
param(
    [string]$OutputPath = "$env:USERPROFILE\Desktop\WSL-Diag"
)

function Write-Log {
    param([string]$Message)
    $Message | Tee-Object -FilePath "$OutputPath\diagnose.log" -Append
}

function Ensure-Dir {
    if (-not (Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath | Out-Null
    }
}

# ── Prepare output folder & log header ─────────────────────────────────────────

Ensure-Dir
Write-Log "`n=== WSL DIAGNOSTICS – $(Get-Date -Format o) ==="

# ── 1. Windows & Hardware Snapshot ─────────────────────────────────────────────

$sysInfo = Get-ComputerInfo
$sysInfo | Export-Clixml "$OutputPath\SystemInfo.xml"
Write-Log "Windows build:   $($sysInfo.WindowsProductName) $($sysInfo.WindowsVersion)  (OS build $($sysInfo.OsBuildNumber))"

$os      = Get-CimInstance Win32_OperatingSystem
$ramUsed = [math]::Round((($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize * 100), 2)
$cpuLoad = (Get-CimInstance Win32_Processor).LoadPercentage |
              Measure-Object -Average |
              Select-Object -ExpandProperty Average
Write-Log "CPU load:       $cpuLoad`%   RAM used: $ramUsed`%"

# ── 2. WSL State ───────────────────────────────────────────────────────────────

& wsl.exe --status 2>&1 | Out-File "$OutputPath\wsl_status.txt"
& wsl.exe -l -v    2>&1 | Out-File "$OutputPath\wsl_distros.txt"
Write-Log "Captured WSL status & distro list."
if (Test-Path "$env:USERPROFILE\.wslconfig") {
    Copy-Item "$env:USERPROFILE\.wslconfig" "$OutputPath\wslconfig.txt"
    Write-Log "Found .wslconfig"
}

# ── 3. Enabled Windows Features ─────────────────────────────────────────────────

Get-WindowsOptionalFeature -Online |
    Where-Object { $_.State -eq 'Enabled' -and $_.FeatureName -match 'VirtualMachine|Subsystem' } |
    Select-Object -ExpandProperty FeatureName |
    Out-File "$OutputPath\windows_features.txt"
Write-Log "Saved enabled Hyper-V/WSL features."

# ── 4. Event Log Sniff (last 72h, robust) ───────────────────────────────────────

$providers = 'LxssManager','Microsoft-Windows-Hyper-V-Compute','Microsoft-Windows-Hyper-V-VMMS'
try {
    $events = Get-WinEvent -FilterHashtable @{
        LogName      = 'System'
        ProviderName = $providers
        StartTime    = (Get-Date).AddDays(-3)
    } -ErrorAction Stop
}
catch {
    Write-Log "⚠️  Hashtable filter failed: $_"
    Write-Log "   Falling back to brute-force post-filter"
    $events = Get-WinEvent -LogName System -MaxEvents 2000 -ErrorAction SilentlyContinue |
        Where-Object {
            $_.TimeCreated -ge (Get-Date).AddDays(-3) -and
            $providers -contains $_.ProviderName
        }
}
$events | Export-Clixml "$OutputPath\EventLogs.xml"
Write-Log "Logged $($events.Count) Hyper-V/WSL events (72h)."

# ── 5. VHDX Bloat Check ─────────────────────────────────────────────────────────

$vhdxPaths = @(
    "$env:LOCALAPPDATA\Packages\CanonicalGroupLimited.Ubuntu*",
    "$env:LOCALAPPDATA\Docker\wsl",
    "$env:USERPROFILE\AppData\Local\Docker\wsl"
)
$vhdxFiles = $vhdxPaths |
    ForEach-Object { Get-ChildItem $_ -Recurse -Filter *.vhdx -ErrorAction SilentlyContinue }
$vhdxReport = $vhdxFiles |
    Select-Object FullName, @{Name='SizeGB';Expression={[math]::Round($_.Length/1GB,2)}}
$vhdxReport | Export-Csv "$OutputPath\vhdx_usage.csv" -NoTypeInformation
if ($vhdxReport) {
    $largest = $vhdxReport | Sort-Object SizeGB -Descending | Select-Object -First 1
    Write-Log "Largest VHDX:    $([int]$largest.SizeGB) GB   ($($largest.FullName))"
}
else {
    Write-Log "No VHDX files found."
}

# ── 6. Linux dmesg & journal (last 200 lines per distro) ───────────────────────

$distros = & wsl.exe -l -q |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ }
foreach ($distro in $distros) {
    $safeName = ($distro -replace '[<>:"/\\|?*]', '_')
    Write-Log "Collecting logs for distro '$distro'..."
    try {
        & wsl.exe -d $distro sh -c "dmesg --color=never | tail -n 200" |
            Out-File "$OutputPath\${safeName}_dmesg.txt"
        & wsl.exe -d $distro sh -c "journalctl -xe --no-pager -n 200" |
            Out-File "$OutputPath\${safeName}_journalctl.txt"
    }
    catch {
        # <--- fixed interpolation here with subexpression
        Write-Log "⚠️  Could not read logs for $($distro): $_"
    }
}

# ── 7. Heuristic “What Looks Wrong?” ───────────────────────────────────────────

$issues = @()
if ($ramUsed -gt 90) { $issues += "RAM nearly maxed ($ramUsed`%)." }
if ($cpuLoad -gt 90) { $issues += "CPU pegged at $cpuLoad`%." }
if ($vhdxReport.Where({ $_.SizeGB -gt 30 }).Count) {
    $issues += "One or more WSL disks > 30 GB – consider trimming/compacting."
}
if ($events.Where({ $_.LevelDisplayName -in 'Error','Critical' }).Count) {
    $issues += "Hyper-V/WSL errors found."
}

Write-Log "`n=== SUMMARY ==="
if ($issues.Count) {
    Write-Log "🚨 Potential issues:"
    $issues | ForEach-Object { Write-Log "  • $_" }
}
else {
    Write-Log "No glaring problems found; review detailed logs under $OutputPath."
}

Write-Log "`nDiagnostics complete – logs saved to $OutputPath"
