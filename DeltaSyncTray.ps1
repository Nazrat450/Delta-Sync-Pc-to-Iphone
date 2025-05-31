# ================================================
#                Delta Sync Tray - Auto Exit
# ================================================

Add-Type -AssemblyName System.Windows.Forms, System.Drawing

# Run as Administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host 'Restarting script as administrator...'
    Start-Process powershell -Verb runAs -ArgumentList ('-File "' + $MyInvocation.MyCommand.Path + '"')
    exit
}

# === Paths ===
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$logFile = Join-Path $scriptDir 'DeltaSync-backup.log'
$dropboxDeltaPath = 'C:\Users\matth\Dropbox\Delta Emulator'
$backupFolder = 'C:\Users\matth\Dropbox\PcSaves'
$romFolder = 'E:\Emulation\Gameboy'

if (-not (Test-Path $backupFolder)) {
    New-Item -ItemType Directory -Path $backupFolder | Out-Null
}

# === Tray Icon Setup ===
$iconPath = Join-Path $scriptDir 'img\icon_rV9_icon.ico'
$fs = [System.IO.File]::OpenRead($iconPath)
$icon = New-Object System.Drawing.Icon $fs
$clonedIcon = $icon.Clone()
$fs.Close()

$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon = $clonedIcon
$notify.Text = 'Delta Save Sync'
$menu = New-Object System.Windows.Forms.ContextMenu
$exitItem = New-Object System.Windows.Forms.MenuItem 'Exit'
$exitItem.add_Click({
    $notify.Visible = $false
    $notify.Dispose()
    Write-Log 'Manual exit via tray menu.'
    exit
})
$menu.MenuItems.Add($exitItem)
$notify.ContextMenu = $menu
$notify.Visible = $true

function Write-Log($msg) {
    $ts = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $full = "$ts - $msg"
    Write-Host $full
    Add-Content -Path $logFile -Value $full
}

function PadOrTrim($str, $length) {
    if ($str.Length -gt $length) {
        return $str.Substring(0, $length - 3) + '...'
    } else {
        return $str.PadRight($length)
    }
}

function Write-TableHeader {
    $divider = '+----------------------+----------------------------------------------+--------------------------------+------------------+------------+'
    $header  = '| Game Name            | Delta File Name                             | Backup Save File               | Action           | Status     |'
    Write-Host "`n$divider"
    Write-Host $header
    Write-Host $divider
    Add-Content -Path $logFile -Value "`n$divider`n$header`n$divider"
}

function Write-TableRow($gameName, $deltaFile, $saveFile, $action, $status) {
    $col1 = PadOrTrim $gameName 20
    $col2 = PadOrTrim $deltaFile 44
    $col3 = PadOrTrim $saveFile 30
    $col4 = PadOrTrim $action 16
    $col5 = PadOrTrim $status 10

    $line = '| {0} | {1} | {2} | {3} | {4} |' -f $col1, $col2, $col3, $col4, $col5
    Write-Host $line
    Add-Content -Path $logFile -Value $line
}

# === Game Setup ===
$games = @(
    @{ Name = 'PokemonSapphire'; DeltaSave = 'GameSave-89b45fb172e6b55d51fc0e61989775187f6fe63c-gameSave'; Rom = 'PokemonSapphire.gba' },
    @{ Name = 'PokemonSeaGlass'; DeltaSave = 'GameSave-62db1951c3e4ca2cf9cd16b20254baa6ebc04a25-gameSave'; Rom = 'PokemonSeaGlass.gba' }
)

$running = $false
$lastModified = @{}

# === Create Symlinks if Missing ===
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

Write-Log 'Started Delta Save Sync monitor.



    @@                                             
        @@@@@             @@@@@@@@@@                      
    .@@   @@          %@@     @@%                        
    .@@     @@@@@@@@@@@@@  (@@                           
        @@@                 (@@                           
    .@@                       @@%                        
    .@@   @@          %@@     @@%                        
    .@@   @@   @@     %@@     @@%                        
    .@@     @@@  @@@          @@%                        
        @@@                 (@@                           
    .@@   @@@@@@@@@@@@@@@     @@%                        
    .@@@@@@@             @@@@@@@% 




'

# === Monitor Loop ===
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

            Write-TableHeader
            foreach ($game in $games) {
                $deltaSavePath = Join-Path $dropboxDeltaPath $game.DeltaSave
                if (Test-Path $deltaSavePath) {
                    $lastModified[$game.Name] = (Get-Item $deltaSavePath).LastWriteTime
                    Write-TableRow $game.Name $game.DeltaSave '' 'Track' 'Watching'
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

            Write-TableHeader
            foreach ($game in $games) {
                $deltaSavePath = Join-Path $dropboxDeltaPath $game.DeltaSave
                if (Test-Path $deltaSavePath) {
                    $currentModified = (Get-Item $deltaSavePath).LastWriteTime
                    if ($lastModified.ContainsKey($game.Name) -and $currentModified -eq $lastModified[$game.Name]) {
                        Write-TableRow $game.Name $game.DeltaSave '' 'Backup' 'No Change'
                    } else {
                        $timestamp = Get-Date -Format 'dd-MM-yyyy_h-mmtt'
                        $destName = "$($game.Name)_$timestamp.sav"
                        $destPath = Join-Path $backupFolder $destName
                        try {
                            Copy-Item -Path $deltaSavePath -Destination $destPath -ErrorAction Stop
                            Write-TableRow $game.Name $game.DeltaSave $destName 'Backup' 'Done'
                        } catch {
                            Write-Log "ERROR: Failed to backup $($game.DeltaSave): $_"
                        }
                    }
                }
            }

            # === Cleanup Old Backups ===
            foreach ($game in $games) {
                $gameBackups = Get-ChildItem -Path $backupFolder -Filter "$($game.Name)_*.sav" | Sort-Object LastWriteTime -Descending
                if ($gameBackups.Count -gt 1) {
                    $toDelete = $gameBackups | Select-Object -Skip 1
                    foreach ($oldBackup in $toDelete) {
                        try {
                            Remove-Item $oldBackup.FullName -ErrorAction Stop
                            Write-TableRow $game.Name $game.DeltaSave $oldBackup.Name 'Cleanup' 'Deleted'
                        } catch {
                            Write-Log "ERROR: Could not delete $($oldBackup.Name): $_"
                        }
                    }
                }
            }

            # === Final Exit ===
            Write-Log 'All tasks complete. Exiting.'
            $notify.BalloonTipTitle = 'Delta Sync Tray'
            $notify.BalloonTipText = 'Backup complete. Tray is exiting...'
            $notify.ShowBalloonTip(3000)

            Start-Sleep -Seconds 3
            $notify.Visible = $false
            $notify.Dispose()
            exit
        }
    }
}





