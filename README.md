# 🌀 Delta Save Sync

Easily sync your Delta emulator save files between PC and iPhone using Dropbox. This tool ensures your save data is backed up and mirrored across devices without manual hassle on PC.

---

## 📦 Features

- Auto-creates symbolic links from your VisualBoyAdvance save files to Dropbox
- Tracks emulator launch and exit
- Backs up your saves after you play
- Keeps only the most recent save backup
- Designed for `Delta` on iPhone + `VisualBoyAdvance-M` on PC

---

## 🛠 Requirements

- Windows PC
- Dropbox installed on both PC and iPhone
- VisualBoyAdvance-M on PC
- Delta emulator on iPhone (Tested via AltStore or TrollStore)
- PowerShell (included with Windows)
- [Delta Save Sync Tray script](./DeltaSyncTray.ps1)

---

## 🧭 Folder Setup

### 📁 Dropbox Structure Example (on PC)
Dropbox/
├── Delta Emulator/
│ ├── GameSave-xxxxxxx-gameSave
│ └── GameSave-yyyyyyy-gameSave
├── PcSaves/
│ └── [Timestamped backups]


Make sure your Delta saves (from iPhone) are located in:
Dropbox/Delta Emulator/

---

## 🧩 How the Sync Works

1. On PC, the script links `.sav` files in your VBA rom folder to the **Delta saves in Dropbox**
2. When you launch VBA-M, the script watches the process
3. After VBA closes, it checks if the save was updated
4. If it changed, it makes a backup copy in `PcSaves/`

---

## 📲 Step-by-Step Sync Setup (PC ↔ iPhone)

### ✅ On iPhone (Delta)

1. Open **Delta app**
2. Tap the **gear icon (Settings)** → Scroll to **Cloud Sync**
3. Choose **Dropbox** and connect your account
4. Enable **Save Sync**
5. Play your game as normal — this creates or updates `GameSave-xxxxx-gameSave` files

> 📍 These files are stored in: `Dropbox/Delta Emulator/`

---

### ✅ On PC

1. Install [Dropbox](https://www.dropbox.com/install) and sign in with the **same account**
2. Clone or copy `DeltaSyncTray.ps1` to any folder (e.g., `C:\Users\matth\Documents\DeltaSync`)
3. Edit the script to reflect your:
   - `romFolder` path (where your `.gba` files are)
   - Your `dropboxDeltaPath` (usually `C:\Users\matth\Dropbox\Delta Emulator`)
4. Right-click the script and **Run with PowerShell**
5. The tray icon will appear and monitor your emulator
6. When VBA closes, it will:
   - Compare save file timestamps
   - Back up updated saves
   - Clean old backups (keeping only the latest one)

---

### 🔁 Manual Import on iPhone

Delta on iPhone **does not automatically import new saves** from Dropbox.

To manually restore PC saves:
Open Delta Click and Hold on Game You Just Played on Pc
Click Import Save
Naviate To DropBox 
Find clearly Named .SAV




## 🔒 Permissions

The script requires **Administrator privileges** to:
- Create symbolic links (`.lnk` style `.sav` files)
- Monitor processes globally
