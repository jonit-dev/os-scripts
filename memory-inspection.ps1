<# 
RAM-Diagnose.ps1 (fixed)
#>

function To-GB([UInt64]$bytes){ [Math]::Round($bytes / 1GB, 2) }
function Map-FormFactor($n){ switch ($n) { 8{"DIMM"}12{"SODIMM"}0{"Unknown"}9{"RIMM"}10{"LRIMM"}11{"FB-DIMM"} default{"$n"} } }
function Map-MemoryType($n){
  switch ($n) {
    0{"Unknown"}20{"DDR"}21{"DDR2"}22{"DDR2 FB-DIMM"}24{"DDR3"}26{"DDR4"}27{"LPDDR"}28{"LPDDR2"}
    29{"LPDDR3"}30{"LPDDR4"}34{"DDR5"}35{"LPDDR5"} default{"$n"}
  }
}
function Guess-CL([string]$s){
  if ($s -match 'C(?:L)?(?<cl>\d{2})'){ return [int]$Matches.cl }
  if ($s -match 'HC(?<cl>\d{2})'){ return [int]$Matches.cl }
  return $null
}

$cs        = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
$bios      = Get-CimInstance Win32_BIOS -ErrorAction SilentlyContinue
$board     = Get-CimInstance Win32_ComputerSystemProduct -ErrorAction SilentlyContinue
$memArrays = Get-CimInstance Win32_PhysicalMemoryArray -ErrorAction SilentlyContinue
$mods      = Get-CimInstance Win32_PhysicalMemory -ErrorAction SilentlyContinue
if (-not $mods) { Write-Error "Could not read RAM modules (Win32_PhysicalMemory). Try PowerShell as Administrator."; exit 1 }

$totalSlots = 0; $maxCapacityBytes = [UInt64]0
foreach($a in $memArrays){
  $totalSlots += [int]$a.MemoryDevices
  if ($a.MaxCapacityEx -and $a.MaxCapacityEx -gt 0) { $maxCapacityBytes += [UInt64]$a.MaxCapacityEx }
  elseif ($a.MaxCapacity -and $a.MaxCapacity -gt 0) { $maxCapacityBytes += ([UInt64]$a.MaxCapacity * 1KB) }
}
if ($totalSlots -le 0) { $totalSlots = $mods.Count }

$installedBytes = ($mods | Measure-Object Capacity -Sum).Sum
$installedGB    = To-GB $installedBytes
$populated      = $mods.Count
$emptySlots     = [Math]::Max(0, $totalSlots - $populated)

$fwMaxGB = if ($maxCapacityBytes -gt 0) { To-GB $maxCapacityBytes } else { 0 }
$fwBogus = ($fwMaxGB -lt 8) -or ($fwMaxGB -lt $installedGB)

$ddrGen = Map-MemoryType (($mods | Select-Object -First 1 -ExpandProperty SMBIOSMemoryType))
$maxCfg = ($mods | Select-Object -ExpandProperty ConfiguredClockSpeed | Measure-Object -Maximum).Maximum
$xmpLikely = $false
if ($ddrGen -eq "DDR4" -and $maxCfg -gt 3200) { $xmpLikely = $true }
elseif ($ddrGen -eq "DDR5" -and $maxCfg -gt 5600) { $xmpLikely = $true }

$chanLetters = @()
foreach($m in $mods){
  $bl = $m.BankLabel
  if ($bl -and ($bl -match 'CHANNEL\s+([A-D])')){ $chanLetters += $Matches[1].ToUpper() }
}
$distinctCh = ($chanLetters | Select-Object -Unique)
$dualChannelLikely = ($distinctCh.Count -ge 2)

# --- FIXED lines below (no stray spaces) ---
$byPN   = $mods | ForEach-Object { ($_.PartNumber -replace '\s+$','') } | Group-Object | Sort-Object Count -Descending
$byMfgr = $mods | ForEach-Object { $_.Manufacturer } | Group-Object | Sort-Object Count -Descending
$byCap  = $mods | ForEach-Object { To-GB $_.Capacity } | Group-Object | Sort-Object Count -Descending

$uniformPN   = ($byPN.Count -eq 1)
$uniformMfgr = ($byMfgr.Count -eq 1)
$uniformSize = ($byCap.Count -eq 1)

$sticks = @()
foreach($m in $mods){
  $pn = ($m.PartNumber -replace '\s+$','')
  $sn = $m.SerialNumber
  $snTail = if ($sn) { $s = $sn.ToString(); if ($s.Length -ge 4) { $s.Substring($s.Length-4) } else { $s } } else { $null }
  $sticks += [pscustomobject]@{
    BankLabel          = $m.BankLabel
    DeviceLocator      = $m.DeviceLocator
    CapacityGB         = To-GB $m.Capacity
    ConfiguredClockMHz = $m.ConfiguredClockSpeed
    MaxSPD_MHz         = $m.Speed
    FormFactor         = Map-FormFactor $m.FormFactor
    MemoryType         = Map-MemoryType $m.SMBIOSMemoryType
    Manufacturer       = $m.Manufacturer
    PartNumber         = $pn
    CL_Guess           = Guess-CL $pn
    SerialSuffix       = $snTail
  }
}

Write-Host "==== RAM Diagnosis ====" -ForegroundColor Cyan
Write-Host ("Machine: {0}  Model: {1}  BIOS: {2}" -f $env:COMPUTERNAME, $cs.Model, $bios.SMBIOSBIOSVersion)
if ($board.Version) { Write-Host ("Board ID: {0}" -f $board.Version) }

Write-Host ("Total Slots: {0}   Populated: {1}   Empty: {2}" -f $totalSlots, $populated, $emptySlots)
Write-Host ("Installed RAM: {0} GB" -f $installedGB)
Write-Host ("DDR Generation: {0}" -f $ddrGen)
Write-Host ("Peak Configured Speed (any stick): {0} MHz" -f $maxCfg)
Write-Host ("Profile Active (XMP/DOCP/EXPO) Likely: {0}" -f ($(if($xmpLikely){"Yes"}else{"No/Unknown"})))
if ($distinctCh.Count -gt 0) {
  Write-Host ("Channel Mapping (best-effort): {0}" -f (($distinctCh | Sort-Object) -join ", "))
  Write-Host ("Dual Channel Likely: {0}" -f ($(if($dualChannelLikely){"Yes"}else{"No/Unknown"})))
} else {
  Write-Host "Channel Mapping: Unknown (firmware doesn't label channels)"
}

if ($fwMaxGB -gt 0) {
  $fwLine = if ($fwBogus) { "Firmware Max RAM: $fwMaxGB GB (looks bogus)" } else { "Firmware Max RAM: $fwMaxGB GB" }
  Write-Host $fwLine
} else {
  Write-Host "Firmware Max RAM: Not reported"
}

Write-Host ""
Write-Host "Configuration health:" -ForegroundColor Yellow
Write-Host ("• Uniform sizes: {0}" -f ($(if($uniformSize){"Yes"}else{"No"})))
Write-Host ("• Uniform manufacturer: {0}" -f ($(if($uniformMfgr){"Yes"}else{"No"})))
Write-Host ("• Uniform part numbers (exact kit match): {0}" -f ($(if($uniformPN){"Yes"}else{"No"})))
if (-not $dualChannelLikely) { Write-Host "• Warning: Dual-channel not clearly detected; verify module placement (usually A2/B2 on MSI)." -ForegroundColor DarkYellow }

Write-Host ""
Write-Host "Per-stick detail:" -ForegroundColor Yellow
$sticks | Sort-Object BankLabel, DeviceLocator | Format-Table BankLabel,DeviceLocator,CapacityGB,ConfiguredClockMHz,MaxSPD_MHz,Manufacturer,PartNumber,CL_Guess,FormFactor,MemoryType -AutoSize

Write-Host ""
Write-Host "Recommendations:" -ForegroundColor Yellow
if ($emptySlots -ge 2) {
  Write-Host "• You have two empty slots — physically ready to add two more sticks (best to match part number)."
} elseif ($emptySlots -eq 1) {
  Write-Host "• Only one empty slot — prefer a matched 2× kit for best stability."
} else {
  Write-Host "• No empty slots — any upgrade requires replacing existing modules."
}
if (-not $uniformPN -or -not $uniformMfgr) {
  Write-Host "• Mixed kits can work but may need lowering speed (e.g., 3600→3466/3200) and a quick MemTest86 run."
}
if ($ddrGen -eq "DDR4" -and $maxCfg -ge 3600 -and $populated -eq 4) {
  Write-Host "• With 4× DDR4 DIMMs at ≥3600 MHz, stability sometimes improves by dropping to 3466/3200 or nudging DRAM/SoC voltages."
}

$result = [pscustomobject]@{
  ComputerName          = $env:COMPUTERNAME
  Model                 = $cs.Model
  BoardId               = $board.Version
  BIOS                  = $bios.SMBIOSBIOSVersion
  TotalSlots            = $totalSlots
  PopulatedSlots        = $populated
  EmptySlots            = $emptySlots
  InstalledRamGB        = [int]$installedGB
  DDR_Generation        = $ddrGen
  PeakConfiguredMHz     = [int]$maxCfg
  XMP_ProfileLikely     = $xmpLikely
  ChannelLetters        = $distinctCh
  DualChannelLikely     = $dualChannelLikely
  FirmwareMaxGB         = if ($fwMaxGB -gt 0) { [int]$fwMaxGB } else { $null }
  FirmwareMaxLooksBogus = $fwBogus
  UniformSize           = $uniformSize
  UniformManufacturer   = $uniformMfgr
  UniformPartNumber     = $uniformPN
  Sticks                = $sticks
}
Write-Host ""
Write-Host "JSON:" -ForegroundColor Yellow
$result | ConvertTo-Json -Depth 5
