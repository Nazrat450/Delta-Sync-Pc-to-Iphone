# Delta Sync Tray

Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# Ensure script runs as administrator
If (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Restarting script as administrator...'
    Start-Process powershell -Verb runAs -ArgumentList ('-File "' + $MyInvocation.MyCommand.Path + '"')
    exit
}

# Define script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logFile = Join-Path $scriptDir 'DeltaSync-backup.log'

# Load tray icon from relative path
$iconPath = Join-Path $scriptDir 'img\icon_rV9_icon.ico'
$fs = [System.IO.File]::OpenRead($iconPath)
$icon = New-Object System.Drawing.Icon $fs
$clonedIcon = $icon.Clone()
$fs.Close()

# Create NotifyIcon
$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon = $clonedIcon
$notify.Text = 'Delta Save Sync'
$menu = New-Object System.Windows.Forms.ContextMenu
$exitItem = New-Object System.Windows.Forms.MenuItem 'Exit'
$exitItem.add_Click({
    $notify.Visible = $false
    $notify.Dispose()
    Write-Log 'Exiting script.'
    exit
})
$menu.MenuItems.Add($exitItem)
$notify.ContextMenu = $menu
$notify.Visible = $true

function Write-Log($msg) {
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    Write-Host "$ts - $msg"
    Add-Content -Path $logFile -Value "$ts - $msg"
}

Write-Log 'Started Delta Save Sync monitor.'

# === Configuration ===
$games = @(
    @{ Name = 'PokemonSapphire'; DeltaSave = 'GameSave-89b45fb172e6b55d51fc0e61989775187f6fe63c-gameSave'; Rom = 'PokemonSapphire.gba' },
    @{ Name = 'PokemonSeaGlass'; DeltaSave = 'GameSave-62db1951c3e4ca2cf9cd16b20254baa6ebc04a25-gameSave'; Rom = 'PokemonSeaGlass.gba' }
)

$dropboxDeltaPath = 'C:\Users\matth\Dropbox\Delta Emulator'
$backupFolder = 'C:\Users\matth\Dropbox\PcSaves'
$romFolder = 'E:\Emulation\Gameboy'

if (-not (Test-Path $backupFolder)) {
    New-Item -ItemType Directory -Path $backupFolder | Out-Null
}

$running = $false
$lastModified = @{}

# Ensure symlinks exist for each game
foreach ($game in $games) {
    $deltaPath = Join-Path $dropboxDeltaPath $game.DeltaSave
    $symlinkPath = Join-Path $romFolder ([System.IO.Path]::GetFileNameWithoutExtension($game.Rom) + '.sav')

    if ((Test-Path $deltaPath) -and (-not (Test-Path $symlinkPath))) {
        try {
            New-Item -ItemType SymbolicLink -Path $symlinkPath -Target $deltaPath -Force | Out-Null
            Write-Log "Created symlink: $symlinkPath -> $deltaPath"
        } catch {
            Write-Log "ERROR: Failed to create symlink for $($game.Name): $_"
        }
    }
}

while ($true) {
    Start-Sleep -Seconds 5
    try {
        $proc = Get-Process -Name visualboyadvance-m -ErrorAction SilentlyContinue
    } catch {
        $proc = $null
    }

    if ($proc) {
        if (-not $running) {
            $running = $true
            Write-Log "Emulator started (PID $($proc.Id))."
            $notify.BalloonTipTitle = 'Emulator Started'
            $notify.BalloonTipText = 'VisualBoyAdvance-M has launched.'
            $notify.ShowBalloonTip(3000)

            foreach ($game in $games) {
                $deltaSavePath = Join-Path $dropboxDeltaPath $game.DeltaSave
                if (Test-Path $deltaSavePath) {
                    $lastModified[$game.Name] = (Get-Item $deltaSavePath).LastWriteTime
                    Write-Log "Tracking $($game.Name): $($game.DeltaSave), LastWrite: $($lastModified[$game.Name])"
                }
            }
        }
    } else {
        if ($running) {
            $running = $false
            Write-Log 'Emulator exited; checking for save updates.'
            $notify.BalloonTipTitle = 'Emulator Closed'
            $notify.BalloonTipText = 'Checking for updated saves...'
            $notify.ShowBalloonTip(3000)

            foreach ($game in $games) {
                $deltaSavePath = Join-Path $dropboxDeltaPath $game.DeltaSave
                if (Test-Path $deltaSavePath) {
                    $currentModified = (Get-Item $deltaSavePath).LastWriteTime
                    if ($lastModified.ContainsKey($game.Name) -and $currentModified -eq $lastModified[$game.Name]) {
                        Write-Log "No changes in $($game.Name); skipping backup."
                    } else {
                        $timestamp = Get-Date -Format 'dd-MM-yyyy_h-mmtt'
                        $destName = "$($game.Name)_$timestamp.sav"
                        $destPath = Join-Path $backupFolder $destName
                        try {
                            Copy-Item -Path $deltaSavePath -Destination $destPath -ErrorAction Stop
                            Write-Log "Backed up $($game.DeltaSave) to $destName."
                        } catch {
                            Write-Log "ERROR: Failed to backup $($game.DeltaSave): $_"
                        }
                    }
                }
            }

            # Clean up older backups for each game, keeping only the most recent one
            foreach ($game in $games) {
                $gameBackups = Get-ChildItem -Path $backupFolder -Filter "$($game.Name)_*.sav" |
                    Sort-Object LastWriteTime -Descending

                if ($gameBackups.Count -gt 1) {
                    $backupsToDelete = $gameBackups | Select-Object -Skip 1
                    foreach ($oldBackup in $backupsToDelete) {
                        try {
                            Remove-Item $oldBackup.FullName -ErrorAction Stop
                            Write-Log "Deleted old backup $($oldBackup.Name) for game $($game.Name)."
                        } catch {
                            Write-Log "ERROR: Could not delete $($oldBackup.Name): $_"
                        }
                    }
                }
            }
        }
    }
}


