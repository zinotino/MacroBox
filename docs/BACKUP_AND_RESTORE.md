# Backup and Restore Guide - MacroMonoo
**Version:** Stable Build (2025-11-11)
**Last Updated:** 2025-11-11 18:16:00

---

## Table of Contents
- [Critical Files Overview](#critical-files-overview)
- [Backup Procedures](#backup-procedures)
- [Restore Procedures](#restore-procedures)
- [Current Configuration Snapshot](#current-configuration-snapshot)
- [Automated Backup Scripts](#automated-backup-scripts)
- [Recovery Scenarios](#recovery-scenarios)

---

## Critical Files Overview

### Essential Files (Required for Full Restore)

These files are **absolutely critical** for restoring the application to its current state:

| File | Size | Purpose | Restore Priority |
|------|------|---------|------------------|
| `config.ini` | 930 bytes | Settings, canvas calibration, timing | **CRITICAL** |
| `config_simple.txt` | 1,451 bytes | All recorded macros | **CRITICAL** |
| `data/master_stats_permanent.csv` | 630 bytes | Historical statistics | **HIGH** |
| `data/stats_log.backup.json` | 1,243 bytes | Stats backup | **MEDIUM** |

### Optional Files (Can Be Regenerated)

These files can be recreated from essential files or are temporary:

| File | Size | Purpose | Can Regenerate? |
|------|------|---------|-----------------|
| `data/macro_execution_stats.csv` | 630 bytes | Display stats | Yes (from permanent CSV) |
| `data/stats_log.json` | 92 bytes | Runtime stats | Yes (from CSV) |
| `vizlog_debug.txt` | 13,840 bytes | Debug log | Yes (auto-generated) |

### Application File

| File | Size | Purpose |
|------|------|---------|
| `MacroMonoo.ahk` | 6,627 lines | Main application |

**Note:** Always backup the main application file to preserve the exact version you're using.

---

## Backup Procedures

### Method 1: Full Directory Backup (Recommended)

**When to Use:**
- Before major changes
- Weekly scheduled backups
- Before testing new features
- Before updating application

**Procedure:**
```
1. Close MacroMonoo.ahk (important!)
2. Copy entire "Mono10 - Copy" folder
3. Name backup with timestamp:
   Example: "Mono10_Backup_20251111_1816"
4. Store in safe location (external drive, cloud storage)
```

**Directory Structure to Backup:**
```
Mono10 - Copy/
├── MacroMonoo.ahk
├── config.ini
├── config_simple.txt
├── vizlog_debug.txt
├── data/
│   ├── macro_execution_stats.csv
│   ├── master_stats_permanent.csv
│   ├── stats_log.json
│   └── stats_log.backup.json
└── thumbnails/
```

**Storage Recommendations:**
- Local: Different drive than system drive
- External: USB drive, external HDD
- Cloud: Google Drive, Dropbox, OneDrive
- Network: NAS, network share

---

### Method 2: Selective File Backup

**When to Use:**
- Quick daily backups
- Before each annotation session
- Low storage space situations

**Procedure:**
```
1. Create backup folder with timestamp:
   backup_20251111_1816/

2. Copy critical files:
   - config.ini
   - config_simple.txt
   - data/master_stats_permanent.csv
   - data/stats_log.backup.json (optional)

3. Optionally copy MacroMonoo.ahk for version tracking
```

**Command Line Backup (Windows):**
```batch
@echo off
set TIMESTAMP=%date:~10,4%%date:~4,2%%date:~7,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set TIMESTAMP=%TIMESTAMP: =0%
set BACKUP_DIR=backups\backup_%TIMESTAMP%

mkdir "%BACKUP_DIR%"
mkdir "%BACKUP_DIR%\data"

copy config.ini "%BACKUP_DIR%\"
copy config_simple.txt "%BACKUP_DIR%\"
copy MacroMonoo.ahk "%BACKUP_DIR%\"
copy data\master_stats_permanent.csv "%BACKUP_DIR%\data\"
copy data\stats_log.backup.json "%BACKUP_DIR%\data\"

echo Backup completed: %BACKUP_DIR%
pause
```

**Save as:** `create_backup.bat`

---

### Method 3: Git Version Control

**When to Use:**
- Development/testing environment
- Track changes over time
- Collaborate with team

**Initial Setup:**
```bash
# Initialize git repository
cd "Mono10 - Copy"
git init

# Create .gitignore
echo "vizlog_debug.txt" > .gitignore
echo "data/stats_log.json" >> .gitignore

# Initial commit
git add .
git commit -m "Initial commit - Stable build 2025-11-11"
git tag -a v1.0_stable_20251111 -m "MAJOR RESTORE POINT"
```

**Daily Backups:**
```bash
# Commit changes
git add config.ini config_simple.txt data/
git commit -m "Daily backup - $(date +%Y%m%d)"

# Push to remote (optional)
git push origin main
```

---

### Backup Schedule Recommendations

| Frequency | Method | Purpose |
|-----------|--------|---------|
| **Before each session** | Selective (5 min) | Protect recent work |
| **Daily** | Selective (5 min) | Ongoing protection |
| **Weekly** | Full Directory (10 min) | Complete snapshot |
| **Before updates** | Full Directory | Version safety |
| **Monthly** | Full Directory + External | Long-term archive |

---

## Restore Procedures

### Restore Scenario 1: Full System Restore

**When to Use:**
- Complete system failure
- Corrupted application
- Moving to new computer

**Procedure:**
```
1. Close MacroMonoo.ahk (if running)

2. Delete current directory (or rename to "Mono10_OLD")

3. Copy backup folder to working location
   Example: Copy "Mono10_Backup_20251111_1816" to "Mono10 - Copy"

4. Launch MacroMonoo.ahk

5. Verify:
   ✓ Canvas calibration intact
   ✓ All macros present and functional
   ✓ Stats load correctly
   ✓ Execution works as expected

6. Test each system:
   - Record new macro → verify visualization
   - Execute existing macro → verify playback
   - Check stats GUI → verify data display
```

**Expected Result:**
- Application identical to backup state
- All macros functional
- All statistics preserved
- Canvas calibration intact

---

### Restore Scenario 2: Config-Only Restore

**When to Use:**
- Lost canvas calibration
- Corrupted config.ini
- Need to restore settings only

**Procedure:**
```
1. Close MacroMonoo.ahk

2. Backup current config (just in case):
   Copy config.ini to config.ini.old

3. Copy config.ini from backup folder

4. Launch MacroMonoo.ahk

5. Verify:
   ✓ Canvas calibration values correct
   ✓ Timing settings as expected
   ✓ Hotkeys working
   ✓ Current layer preserved

6. Test visualization:
   - Toggle canvas mode
   - View existing macro thumbnails
   - Verify boxes align correctly
```

---

### Restore Scenario 3: Macros-Only Restore

**When to Use:**
- Lost macros (config_simple.txt deleted)
- Corrupted macro file
- Need to recover recorded macros

**Procedure:**
```
1. Close MacroMonoo.ahk

2. Backup current macros (if any):
   Copy config_simple.txt to config_simple.txt.old

3. Copy config_simple.txt from backup folder

4. Launch MacroMonoo.ahk

5. Verify:
   ✓ All buttons show correct thumbnails
   ✓ Macros execute correctly
   ✓ Degradation colors correct

6. Test execution:
   - Execute each macro on Layer 1
   - Check Layer 2, Layer 3 macros
   - Verify canvas mode respected
```

---

### Restore Scenario 4: Stats-Only Restore

**When to Use:**
- Stats corrupted or lost
- Need historical data recovery
- Accidental stats reset

**Procedure:**
```
1. Close MacroMonoo.ahk

2. Navigate to data/ folder

3. Copy from backup:
   - master_stats_permanent.csv → data/
   - (optional) stats_log.backup.json → data/

4. Copy permanent CSV to display CSV:
   Copy data/master_stats_permanent.csv to data/macro_execution_stats.csv

5. Delete stats_log.json (will be regenerated)

6. Launch MacroMonoo.ahk

7. Verify:
   ✓ Stats GUI shows historical data
   ✓ Today's stats calculate correctly
   ✓ Degradation breakdowns accurate

8. Open Stats GUI (F12):
   - Check all-time stats
   - Check today's stats
   - Verify degradation counts
```

---

### Restore Scenario 5: Partial Restore (Mixed Sources)

**When to Use:**
- Need macros from one backup, config from another
- Cherry-picking specific data

**Procedure:**
```
1. Close MacroMonoo.ahk

2. Identify needed files:
   Backup A: config.ini (canvas calibration)
   Backup B: config_simple.txt (macros)
   Backup C: master_stats_permanent.csv (stats)

3. Copy files from respective backups:
   Copy config.ini from Backup A
   Copy config_simple.txt from Backup B
   Copy data/master_stats_permanent.csv from Backup C

4. Launch MacroMonoo.ahk

5. Comprehensive verification:
   ✓ Canvas calibration correct (from Backup A)
   ✓ Macros functional (from Backup B)
   ✓ Stats accurate (from Backup C)

6. Save current state as new baseline
```

---

## Current Configuration Snapshot

### System Information
- **Application Version:** Stable Build
- **Snapshot Date:** 2025-11-11 18:16:00
- **Total Code Lines:** 6,627
- **Status:** All Three Systems Working Almost Flawlessly

---

### Canvas Configuration

#### Wide Canvas (16:9 Aspect Ratio)
```ini
wideCanvasLeft=26.00
wideCanvasTop=193.00
wideCanvasRight=1652.00
wideCanvasBottom=999.00
isWideCanvasCalibrated=1
```

**Dimensions:**
- Width: 1626 pixels (1652 - 26)
- Height: 806 pixels (999 - 193)
- Aspect Ratio: 2.02:1 (approximately 16:9)

**Use Case:** General widescreen annotations, landscape-oriented content

---

#### Narrow Canvas (4:3 Aspect Ratio)
```ini
narrowCanvasLeft=428.00
narrowCanvasTop=196.00
narrowCanvasRight=1363.00
narrowCanvasBottom=998.00
isNarrowCanvasCalibrated=1
```

**Dimensions:**
- Width: 935 pixels (1363 - 428)
- Height: 802 pixels (998 - 196)
- Aspect Ratio: 1.17:1 (approximately 4:3)

**Use Case:** Mobile/portrait content, narrow viewports

---

#### User Canvas (Unused)
```ini
userCanvasLeft=0.00
userCanvasTop=0.00
userCanvasRight=3840.00
userCanvasBottom=1080.00
isCanvasCalibrated=0
```

**Status:** Not calibrated (flag = 0)
**Note:** Reserved for custom canvas mode

---

### Timing Configuration

All timing values in milliseconds:

| Timing Variable | Current Value | Purpose |
|----------------|---------------|---------|
| `boxDrawDelay` | 50 | Box drawing operation |
| `mouseClickDelay` | 75 | Mouse button press |
| `mouseDragDelay` | 50 | During drag |
| `mouseReleaseDelay` | 75 | After release |
| `betweenBoxDelay` | 120 | Between subsequent boxes |
| `keyPressDelay` | 12 | Keyboard input |
| `focusDelay` | 60 | Window activation |
| `smartBoxClickDelay` | 45 | Cursor positioning |
| `smartMenuClickDelay` | 100 | Menu interaction |
| `firstBoxDelay` | 180 | First box UI stabilization |
| `menuWaitDelay` | 50 | Menu popup |
| `mouseHoverDelay` | 30 | Hover detection |

**Tuning Notes:**
- Current values optimized for average system
- First box delay (180ms) critical for UI stabilization
- Between box delay (120ms) balances speed and reliability

---

### Hotkey Configuration

```ini
hotkeyRecordToggle=CapsLock & f
hotkeySubmit=NumpadEnter
hotkeyDirectClear=+Enter
hotkeyUtilitySubmit=+CapsLock
hotkeyUtilityBackspace=^CapsLock
hotkeyStats=F12
hotkeyBreakMode=^b
hotkeySettings=^k
utilityHotkeysEnabled=1
```

**Hotkey Mapping:**
- **Record Toggle:** `CapsLock + f` - Start/stop macro recording
- **Submit:** `NumpadEnter` - Submit annotation (JSON profiles)
- **Direct Clear:** `Shift + Enter` - Clear annotation
- **Utility Submit:** `Shift + CapsLock` - Utility submit action
- **Utility Backspace:** `Ctrl + CapsLock` - Utility backspace
- **Stats Dashboard:** `F12` - Open statistics GUI
- **Break Mode:** `Ctrl + b` - Toggle break mode (pause time tracking)
- **Settings:** `Ctrl + k` - Open settings GUI
- **Utility Hotkeys:** Enabled

---

### General Settings

```ini
CurrentLayer=1
AnnotationMode=Wide
LastSaved=20251111181600
```

**Current State:**
- **Active Layer:** Layer 1 (of 3 available)
- **Canvas Mode:** Wide (16:9)
- **Last Saved:** 2025-11-11 18:16:00

---

### Macro Storage Format

Macros stored in `config_simple.txt` with format:
```
L{layer}_{button}=recordedMode,{mode}
L{layer}_{button}=recordedCanvas,{left},{top},{right},{bottom},mode={mode}
L{layer}_{button}=boundingBox,{left},{top},{right},{bottom},time={timestamp},deg={type},isFirstBox={bool}
L{layer}_{button}=keyDown,{key},time={timestamp}
L{layer}_{button}=keyUp,{key},time={timestamp}
```

**Example:**
```
L1_Num7=recordedMode,Narrow
L1_Num7=recordedCanvas,428.00,196.00,1363.00,998.00,mode=Narrow
L1_Num7=boundingBox,559,289,634,457,time=86085125,deg=1,isFirstBox=1
L1_Num7=keyDown,1,time=86085296
L1_Num7=keyUp,1,time=86085400
```

---

### Statistics Storage

#### Display Stats CSV Schema
File: `data/macro_execution_stats.csv`

**Columns (26 total):**
```
timestamp,session_id,username,execution_type,button_key,layer,
execution_time_ms,total_boxes,degradation_assignments,severity_level,
canvas_mode,session_active_time_ms,break_mode_active,
smudge_count,glare_count,splashes_count,partial_blockage_count,
full_blockage_count,light_flare_count,rain_count,haze_count,
snow_count,clear_count,annotation_details,execution_success,error_details
```

#### Permanent Stats CSV
File: `data/master_stats_permanent.csv`

**Same schema as display CSV**
**Purpose:** Never reset, historical record

---

## Automated Backup Scripts

### Windows Batch Script: Daily Backup

**Filename:** `daily_backup.bat`

```batch
@echo off
REM Daily Backup Script for MacroMonoo
REM Saves to timestamped folder in backups\ directory

setlocal enabledelayedexpansion

REM Create timestamp (format: YYYYMMDD_HHMMSS)
set TIMESTAMP=%date:~10,4%%date:~4,2%%date:~7,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set TIMESTAMP=%TIMESTAMP: =0%

REM Set paths
set BACKUP_ROOT=backups
set BACKUP_DIR=%BACKUP_ROOT%\backup_%TIMESTAMP%
set DATA_DIR=%BACKUP_DIR%\data

REM Create directories
if not exist "%BACKUP_ROOT%" mkdir "%BACKUP_ROOT%"
mkdir "%BACKUP_DIR%"
mkdir "%DATA_DIR%"

REM Copy critical files
echo Backing up critical files...
copy config.ini "%BACKUP_DIR%\" >nul
copy config_simple.txt "%BACKUP_DIR%\" >nul
copy MacroMonoo.ahk "%BACKUP_DIR%\" >nul
copy data\master_stats_permanent.csv "%DATA_DIR%\" >nul
copy data\stats_log.backup.json "%DATA_DIR%\" >nul

REM Verify backup
if exist "%BACKUP_DIR%\config.ini" (
    echo.
    echo ===================================
    echo Backup completed successfully!
    echo ===================================
    echo Location: %BACKUP_DIR%
    echo.
    dir "%BACKUP_DIR%" /B
    echo.
) else (
    echo.
    echo ERROR: Backup failed!
    echo.
)

REM Clean up old backups (keep last 14 days)
echo Cleaning up old backups...
forfiles /P "%BACKUP_ROOT%" /M backup_* /D -14 /C "cmd /c if @isdir==TRUE rmdir /S /Q @path" 2>nul

echo.
echo Press any key to exit...
pause >nul
```

**Usage:**
1. Save as `daily_backup.bat` in application directory
2. Double-click to run
3. Creates timestamped backup in `backups\` folder
4. Automatically cleans backups older than 14 days

---

### Windows Task Scheduler: Automated Daily Backup

**Setup Instructions:**

1. **Open Task Scheduler:**
   - Press `Win + R`
   - Type `taskschd.msc`
   - Press Enter

2. **Create Task:**
   - Click "Create Basic Task"
   - Name: "MacroMonoo Daily Backup"
   - Description: "Automatic backup of MacroMonoo configuration and data"

3. **Set Trigger:**
   - Trigger: Daily
   - Time: 11:59 PM (or your preferred time)
   - Recur every: 1 day

4. **Set Action:**
   - Action: Start a program
   - Program/script: `C:\Users\ajnef\my-coding-projects\Mono10 - Copy\daily_backup.bat`
   - Start in: `C:\Users\ajnef\my-coding-projects\Mono10 - Copy`

5. **Additional Settings:**
   - Check "Run whether user is logged on or not"
   - Check "Run with highest privileges"

6. **Save and Test:**
   - Enter password if prompted
   - Right-click task → Run
   - Verify backup created in `backups\` folder

---

### PowerShell Script: Cloud Backup

**Filename:** `cloud_backup.ps1`

```powershell
# Cloud Backup Script for MacroMonoo
# Backs up to OneDrive (modify path for Dropbox/Google Drive)

param(
    [string]$CloudPath = "$env:USERPROFILE\OneDrive\MacroMonoo_Backups"
)

# Create timestamp
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$backupName = "backup_$timestamp"
$backupPath = Join-Path $CloudPath $backupName

# Create directories
New-Item -ItemType Directory -Path $backupPath -Force | Out-Null
New-Item -ItemType Directory -Path "$backupPath\data" -Force | Out-Null

# Copy critical files
Write-Host "Backing up to cloud: $backupPath" -ForegroundColor Cyan

Copy-Item "config.ini" -Destination $backupPath
Copy-Item "config_simple.txt" -Destination $backupPath
Copy-Item "MacroMonoo.ahk" -Destination $backupPath
Copy-Item "data\master_stats_permanent.csv" -Destination "$backupPath\data"
Copy-Item "data\stats_log.backup.json" -Destination "$backupPath\data"

# Verify backup
if (Test-Path "$backupPath\config.ini") {
    Write-Host "`nBackup completed successfully!" -ForegroundColor Green
    Write-Host "Location: $backupPath" -ForegroundColor Yellow

    # Create backup manifest
    $manifest = @{
        BackupDate = Get-Date
        BackupLocation = $backupPath
        Files = Get-ChildItem $backupPath -Recurse | Select-Object Name, Length
    }
    $manifest | ConvertTo-Json | Out-File "$backupPath\manifest.json"

    # List files
    Get-ChildItem $backupPath -Recurse | Format-Table Name, Length -AutoSize
} else {
    Write-Host "`nERROR: Backup failed!" -ForegroundColor Red
}

# Clean up old backups (keep last 30)
$oldBackups = Get-ChildItem $CloudPath -Directory |
              Where-Object { $_.Name -match '^backup_\d{8}_\d{6}$' } |
              Sort-Object Name -Descending |
              Select-Object -Skip 30

if ($oldBackups) {
    Write-Host "`nCleaning up old backups..." -ForegroundColor Yellow
    $oldBackups | ForEach-Object {
        Write-Host "Deleting: $($_.Name)" -ForegroundColor DarkGray
        Remove-Item $_.FullName -Recurse -Force
    }
}

Write-Host "`nPress any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
```

**Usage:**
```powershell
# Run with default OneDrive path
.\cloud_backup.ps1

# Run with custom path (Dropbox)
.\cloud_backup.ps1 -CloudPath "C:\Users\ajnef\Dropbox\MacroMonoo_Backups"

# Run with Google Drive path
.\cloud_backup.ps1 -CloudPath "G:\My Drive\MacroMonoo_Backups"
```

---

## Recovery Scenarios

### Scenario 1: Accidental Deletion of Config

**Problem:** Deleted `config.ini` by mistake

**Solution:**
1. Don't panic - macros still intact in `config_simple.txt`
2. Restore `config.ini` from most recent backup
3. Launch application
4. Verify canvas calibration
5. If canvas wrong, recalibrate: `CalibrateCanvas("Wide")`, `CalibrateCanvas("Narrow")`

**Alternative (No Backup):**
1. Launch application (creates default config.ini)
2. Recalibrate both canvas modes
3. Adjust timing values if needed
4. Test with existing macros

---

### Scenario 2: Corrupted Stats Files

**Problem:** Stats CSV has duplicate headers or malformed rows

**Solution:**
1. Close application
2. Copy `master_stats_permanent.csv` to `master_stats_permanent_backup.csv`
3. Open `master_stats_permanent.csv` in text editor
4. Remove duplicate header rows (keep only first)
5. Remove any malformed rows
6. Save file
7. Copy to `macro_execution_stats.csv`
8. Delete `stats_log.json` (will regenerate)
9. Launch application
10. Verify stats in GUI (F12)

**If Severely Corrupted:**
- Restore from backup
- If no backup, reset: delete all CSV files, restart app

---

### Scenario 3: Lost All Macros

**Problem:** `config_simple.txt` deleted or corrupted

**Solution (With Backup):**
1. Restore `config_simple.txt` from backup
2. Launch application
3. Verify all buttons show thumbnails
4. Test each macro

**Solution (No Backup):**
- Macros must be re-recorded
- Use this as lesson to implement daily backups
- Consider git version control going forward

---

### Scenario 4: Application Won't Start

**Problem:** Double-click `MacroMonoo.ahk`, nothing happens

**Diagnostics:**
1. Check if already running (Task Manager)
2. Check AutoHotkey v2.0 installed
3. Check file permissions
4. Check for syntax errors (unlikely in stable build)

**Solution:**
1. Kill any existing `MacroMonoo.ahk` processes
2. Rename current directory to `Mono10_Broken`
3. Restore full directory from backup
4. Launch application
5. If works, compare broken vs working to identify issue

---

### Scenario 5: Moved to New Computer

**Procedure:**
1. Install AutoHotkey v2.0 on new computer
2. Copy entire application directory to new computer
3. Launch `MacroMonoo.ahk`
4. Verify systems:
   ✓ Canvas calibration (may need adjustment for different monitor)
   ✓ Macros load and display thumbnails
   ✓ Stats display correctly
5. If monitor different resolution/DPI:
   - Recalibrate canvas: `CalibrateCanvas("Wide")`, `CalibrateCanvas("Narrow")`
   - Test macro execution
6. Open browser (Chrome/Firefox/Edge)
7. Test macro playback

---

## Best Practices

### Before Major Changes
1. Create full backup
2. Test changes
3. If successful, create new baseline backup
4. If failed, restore from pre-change backup

### Daily Workflow
1. Start session: Check last backup date
2. If > 1 day old, create backup
3. Annotation session
4. End session: Create backup if significant work done

### Weekly Maintenance
1. Create full directory backup
2. Verify backup integrity
3. Copy to external drive or cloud
4. Test restore from backup (occasionally)

### Monthly Archive
1. Create full backup with month/year label
2. Store on external drive
3. Keep indefinitely as long-term archive
4. Document any major changes in backup notes

---

## Backup Verification Checklist

After creating backup, verify:

- [ ] `config.ini` present and > 0 bytes
- [ ] `config_simple.txt` present and > 0 bytes
- [ ] `MacroMonoo.ahk` present and matches source
- [ ] `data/master_stats_permanent.csv` present
- [ ] Backup folder has timestamp in name
- [ ] Backup stored in safe location
- [ ] Can access backup location
- [ ] (Optional) Test restore in separate directory

---

## Emergency Recovery Kit

Keep these items accessible for emergency recovery:

1. **Latest Full Backup** (external drive)
2. **AutoHotkey v2.0 Installer** (in case need to reinstall)
3. **This Document** (printed or on separate device)
4. **Canvas Calibration Values** (written down):
   - Wide: 26, 193 → 1652, 999
   - Narrow: 428, 196 → 1363, 998
5. **Contact Info** (if team environment):
   - IT support
   - Backup server access
   - Cloud storage credentials

---

**END OF BACKUP AND RESTORE GUIDE**
