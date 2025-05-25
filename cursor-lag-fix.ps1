#───────────────────────────────────────────────────────────────────────────────
# Fix-CursorPerformance.ps1
#───────────────────────────────────────────────────────────────────────────────
<#
.SYNOPSIS
  Fully resets Cursor’s data, clears caches, and restarts it cleanly.

.DESCRIPTION
  1. Stops any running Cursor (and VSCode) processes.
  2. Deletes the local chat history workspace to reset context.
  3. Clears VSCode & Cursor cache layers (Cache, GPUCache, IndexedDB, blob_storage).
  4. Updates settings.json to disable past-chat referencing and other heavy tools (mem0, browser-tools)
     while leaving Supabase integration enabled.
  5. Launches Cursor with all extensions disabled.
#>

# 1. Kill running Cursor and VS Code processes
Write-Host "Stopping Cursor and VSCode processes..."
Get-Process -Name cursor, Code -ErrorAction SilentlyContinue |
    Stop-Process -Force -ErrorAction SilentlyContinue

# 2. Clear out chat history
$workspace = Join-Path $env:APPDATA "Cursor\User\workspaceStorage"
if (Test-Path $workspace) {
    Write-Host "Deleting chat history at: $workspace"
    Remove-Item -Path $workspace -Recurse -Force
}

# 3. Clear VS Code & Cursor cache directories
Write-Host "Clearing VS Code and Cursor cache directories..."
$cachePaths = @(
    "$env:LOCALAPPDATA\Cursor\Cache",
    "$env:LOCALAPPDATA\Cursor\GPUCache",
    "$env:LOCALAPPDATA\Cursor\IndexedDB",
    "$env:LOCALAPPDATA\Cursor\blob_storage",
    "$env:APPDATA\Code\Cache",
    "$env:APPDATA\Code\CachedData",
    "$env:APPDATA\Code\User\workspaceStorage"
)
foreach ($path in $cachePaths) {
    if (Test-Path $path) {
        Write-Host " - Removing $path"
        Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# 4. Tweak settings to disable past-chat & heavy tools (except Supabase)
$settingsFile = Join-Path $env:APPDATA "Cursor\User\settings.json"
if (Test-Path $settingsFile) {
    Write-Host "Updating settings in settings.json..."
    $settingsJson = Get-Content $settingsFile -Raw
    $settings = $settingsJson | ConvertFrom-Json

    # Helper to add or update a flat setting key
    function Set-FlatSetting([pscustomobject]$obj, [string]$key, $value) {
        if ($obj.PSObject.Properties.Name -contains $key) {
            $obj.$key = $value
        } else {
            $obj | Add-Member -NotePropertyName $key -NotePropertyValue $value -Force
        }
    }

    # Turn off automatic chat-history referencing on startup
    Set-FlatSetting $settings 'cursor.chat.showHistoryWhenStartingNewChat' $false

    # Disable known heavyweight integrations (but keep Supabase enabled)
    Set-FlatSetting $settings 'cursor.tools.mem0.enabled' $false
    Set-FlatSetting $settings 'cursor.tools.browser-tools.enabled' $false

    # Serialize back with sufficient depth
    $settings | ConvertTo-Json -Depth 10 | Set-Content $settingsFile
}

# 5. Launch Cursor without extensions
Write-Host "Launching Cursor with extensions disabled..."
Start-Process -FilePath "cursor" -ArgumentList "--disable-extensions"
