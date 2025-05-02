<#
.SYNOPSIS
    Collects GPU health and status metrics on Windows and provides health diagnosis.
.DESCRIPTION
    This script gathers GPU metrics from NVIDIA-SMI, Performance Counters, and WMI,
    then analyzes the results to provide a health diagnosis and recommendations.
#>
param(
    [int]$WarnTempC = 85,         # Warning threshold for GPU temperature (Celsius)
    [int]$WarnUtilPct = 95,       # Warning threshold for GPU utilization (%)
    [int]$WarnMemPct = 90,        # Warning threshold for memory utilization (%)
    [double]$WarnPowerPct = 90,   # Warning threshold for power usage (% of max)
    [int]$WarnFanPct = 80         # Warning threshold for fan speed (%)
)

function Get-NvidiaSMI {
    if (-not (Get-Command nvidia-smi -ErrorAction SilentlyContinue)) {
        Write-Verbose "nvidia-smi not found"
        return $null
    }
    
    $fields = @(
        'timestamp','name','pci.bus_id','driver_version','pstate',
        'temperature.gpu','utilization.gpu','utilization.memory',
        'memory.total','memory.used','power.draw','fan.speed'
    )
    $query = $fields -join ','
    $raw   = nvidia-smi --query-gpu=$query --format=csv,noheader,nounits
    $lines = $raw -split "`n" | Where-Object { $_.Trim() -ne '' }
    
    return $lines | ForEach-Object {
        $vals = $_ -split ',\s*'
        [PSCustomObject]@{
            Timestamp        = $vals[0]
            Name             = $vals[1]
            PCI_Bus          = $vals[2]
            DriverVersion    = $vals[3]
            PerformanceState = $vals[4]
            TempC            = [int]$vals[5]
            UtilGPU          = [int]$vals[6]
            UtilMem          = [int]$vals[7]
            MemTotalMB       = [int]$vals[8]
            MemUsedMB        = [int]$vals[9]
            PowerDrawW       = [double]$vals[10]
            FanSpeedPct      = [int]$vals[11]
        }
    }
}

function Get-PerfCounterStats {
    $ctr = Get-Counter `
        "\GPU Engine(*engtype_3D)\Utilization Percentage", `
        "\GPU Process Memory(*)\Local Usage"
    
    $samples = $ctr.CounterSamples
    $gpuUtil  = ($samples | Where-Object Path -like '*engtype_3D*').CookedValue
    $memUsage = ($samples | Where-Object Path -like '*Local Usage*').CookedValue
    
    [PSCustomObject]@{
        TotalGPUUtilPct = [math]::Round( ($gpuUtil  | Measure-Object -Sum).Sum,  2 )
        TotalMemMB      = [math]::Round( (($memUsage | Measure-Object -Sum).Sum /1MB), 2 )
    }
}

function Get-WmiVideoInfo {
    Get-CimInstance Win32_VideoController | Select-Object `
        Name, `
        @{Name='AdapterRAM_MB';Expression={[int]($_.AdapterRAM/1MB)}}, `
        DriverVersion, DriverDate
}

function Get-GPUHealthDiagnosis {
    param(
        [Parameter(ValueFromPipeline=$true)]
        [PSCustomObject]$GpuData,
        
        [int]$WarnTempC,
        [int]$WarnUtilPct,
        [int]$WarnMemPct,
        [double]$WarnPowerPct,
        [int]$WarnFanPct
    )
    
    begin {
        $issues = @()
        $recommendations = @()
        $overallStatus = "Healthy"
    }
    
    process {
        # Skip if no GPU data
        if (-not $GpuData) { return }
        
        # Temperature Check
        if ($GpuData.TempC -gt $WarnTempC) {
            $issues += "High temperature ($($GpuData.TempC)°C exceeds $WarnTempC°C threshold)"
            $recommendations += "Check cooling system and airflow"
            $overallStatus = "Warning"
        }
        elseif ($GpuData.TempC -gt ($WarnTempC * 0.9)) {
            $issues += "Temperature approaching warning level ($($GpuData.TempC)°C)"
            $recommendations += "Monitor temperature trends"
        }
        
        # GPU Utilization Check
        if ($GpuData.UtilGPU -gt $WarnUtilPct) {
            $issues += "High GPU utilization ($($GpuData.UtilGPU)% exceeds $WarnUtilPct% threshold)"
            $recommendations += "Check for runaway processes or reduce workload"
            if ($overallStatus -eq "Healthy") { $overallStatus = "Warning" }
        }
        
        # Memory Usage Check
        if ($GpuData.MemTotalMB -gt 0) {
            $memPct = [math]::Round(($GpuData.MemUsedMB / $GpuData.MemTotalMB) * 100, 1)
            if ($memPct -gt $WarnMemPct) {
                $issues += "High memory usage ($memPct% exceeds $WarnMemPct% threshold)"
                $recommendations += "Close unused GPU-intensive applications"
                if ($overallStatus -eq "Healthy") { $overallStatus = "Warning" }
            }
        }
        
        # Fan Speed Check (if available)
        if ($GpuData.FanSpeedPct -gt 0) {
            if ($GpuData.FanSpeedPct -gt $WarnFanPct) {
                $issues += "High fan speed ($($GpuData.FanSpeedPct)% exceeds $WarnFanPct% threshold)"
                $recommendations += "Check for dust buildup and proper ventilation"
                if ($overallStatus -eq "Healthy") { $overallStatus = "Warning" }
            }
        }
        
        # Driver Analysis
        try {
            $wmiInfo = Get-WmiVideoInfo | Where-Object { $_.Name -like "*$($GpuData.Name)*" } | Select-Object -First 1
            if ($wmiInfo) {
                $driverDate = $wmiInfo.DriverDate
                $driverAge = (Get-Date) - $driverDate
                
                if ($driverAge.Days -gt 365) {
                    $issues += "GPU driver is older than 1 year (installed: $($driverDate.ToString('yyyy-MM-dd')))"
                    $recommendations += "Consider updating GPU drivers"
                    if ($overallStatus -eq "Healthy") { $overallStatus = "Notice" }
                }
            }
        }
        catch {
            Write-Verbose "Could not analyze driver date: $_"
        }
    }
    
    end {
        # Return diagnosis object
        [PSCustomObject]@{
            OverallStatus = $overallStatus
            Issues = $issues
            Recommendations = $recommendations
        }
    }
}

# Main
Write-Output "=== GPU Health Check ($(Get-Date)) ===`n"

# NVIDIA-SMI Section
$nvidia = Get-NvidiaSMI
if ($nvidia) {
    Write-Output "-- NVIDIA-SMI Metrics --"
    $nvidia | ForEach-Object {
        Write-Output (
            "{0} ({1}) - Temp: {2}°C, Util: {3}%, Mem: {4}/{5} MB, Power: {6} W, Fan: {7}%" `
            -f $_.Name, $_.PCI_Bus, $_.TempC, $_.UtilGPU, 
               $_.MemUsedMB, $_.MemTotalMB, 
               $_.PowerDrawW, $_.FanSpeedPct
        )
        
        if ($_.TempC -gt $WarnTempC) {
            Write-Warning "  Temperature above threshold ($WarnTempC°C)!"
        }
    }
    Write-Output ""
}

# Performance Counters Section
$perf = Get-PerfCounterStats
Write-Output "-- PerfCounter Summary --"
Write-Output ("Total 3D Engine Utilization: {0}%" -f $perf.TotalGPUUtilPct)
Write-Output ("Total GPU Process Memory: {0} MB"   -f $perf.TotalMemMB)
Write-Output ""

# WMI Video Adapter Info
Write-Output "-- WMI Video Controllers --"
Get-WmiVideoInfo | ForEach-Object {
    Write-Output (
        "{0} - RAM: {1} MB, Driver: {2} (Date: {3})" `
        -f $_.Name, $_.AdapterRAM_MB, $_.DriverVersion, $_.DriverDate
    )
}

# Health Diagnosis Section
Write-Output "-- GPU Health Diagnosis --"
if ($nvidia) {
    $nvidia | ForEach-Object {
        $diagnosis = $_ | Get-GPUHealthDiagnosis -WarnTempC $WarnTempC -WarnUtilPct $WarnUtilPct `
                            -WarnMemPct $WarnMemPct -WarnPowerPct $WarnPowerPct -WarnFanPct $WarnFanPct
        
        # Output diagnosis
        Write-Output "$($_.Name) - Overall Status: $($diagnosis.OverallStatus)"
        
        if ($diagnosis.Issues.Count -gt 0) {
            Write-Output "  Issues detected:"
            foreach ($issue in $diagnosis.Issues) {
                Write-Output "   - $issue"
            }
        }
        else {
            Write-Output "  No issues detected"
        }
        
        if ($diagnosis.Recommendations.Count -gt 0) {
            Write-Output "  Recommendations:"
            foreach ($rec in $diagnosis.Recommendations) {
                Write-Output "   - $rec"
            }
        }
    }
}
else {
    Write-Output "No NVIDIA GPU detected for detailed health analysis"
    
    # Attempt basic diagnosis from WMI
    $wmi = Get-WmiVideoInfo
    if ($wmi) {
        foreach ($adapter in $wmi) {
            Write-Output "$($adapter.Name) - Basic Check:"
            
            # Driver date check
            if ($adapter.DriverDate) {
                $driverAge = (Get-Date) - $adapter.DriverDate
                if ($driverAge.Days -gt 365) {
                    Write-Output "  - Warning: GPU driver is older than 1 year (installed: $($adapter.DriverDate.ToString('yyyy-MM-dd')))"
                    Write-Output "  - Recommendation: Consider updating GPU drivers"
                }
                else {
                    Write-Output "  - GPU driver is relatively recent (installed: $($adapter.DriverDate.ToString('yyyy-MM-dd')))"
                }
            }
            
            # Basic performance from counters if available
            if ($perf -and $perf.TotalGPUUtilPct -gt 0) {
                if ($perf.TotalGPUUtilPct -gt $WarnUtilPct) {
                    Write-Output "  - Warning: High GPU utilization ($($perf.TotalGPUUtilPct)%)"
                    Write-Output "  - Recommendation: Check for resource-intensive applications"
                }
                else {
                    Write-Output "  - GPU utilization is normal ($($perf.TotalGPUUtilPct)%)"
                }
            }
        }
    }
    else {
        Write-Output "No GPU information available for diagnosis"
    }
}

Write-Output "`nDone."
