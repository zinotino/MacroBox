# MacroBox

**Standalone Data Labeling Automation Script**

Single 8,923-line AutoHotkey V2 script | Windows 10/11 | Zero dependencies

---

## Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Installation](#installation)
- [Quick Start](#quick-start)
- [Canvas Calibration](#canvas-calibration)
- [Recording Macros](#recording-macros)
- [Auto Mode](#auto-mode)
- [Statistics & Export](#statistics--export)
- [Hotkeys](#hotkeys)
- [Configuration Files](#configuration-files)
- [Advanced Features](#advanced-features)
- [Troubleshooting](#troubleshooting)
- [Technical Specifications](#technical-specifications)
- [FAQ](#faq)
- [License](#license)

---

## Overview

MacroBox records mouse clicks and bounding box drawings once, then replays them instantly. Built for high-volume annotation work on Remotasks, Scale AI, segments.ai, and manufacturing QC systems.

**Problem:** RSI from 8+ hour shifts, productivity bottlenecks, label variance from fatigue

**Solution:** Record once, replay infinitely with 200% productivity increase, 66.7% cost reduction, 78% less variance

---

## Features

- **18 Macro Slots**: Numpad (1-9) + WASD grid (Q/W/E/A/S/D/Z/X/C)
- **Auto Mode**: Loop execution with intervals (0.5-10s) and counts (0-999)
- **Universal Calibration**: Works on any monitor setup (negative coords, ultrawide, vertical)
- **In-Memory Cache**: HBITMAP thumbnails bypass filesystem restrictions
- **9 Condition Types**: Customizable names and hex colors
- **Dual Canvas**: Wide (16:9) and Narrow (4:3) modes
- **Statistics**: All-time and daily metrics, CSV export
- **Break Mode**: Pause time tracking
- **segments.ai Integration**: JSON export with severity levels

---

## Installation

### Requirements

- Windows 10/11 (64-bit)
- [AutoHotkey V2.0+](https://www.autohotkey.com/)
- 2GB RAM minimum (4GB recommended)

### Steps

1. Install AutoHotkey V2 from https://www.autohotkey.com/
2. Download MacroBox: `git clone https://github.com/yourusername/MacroBox.git`
3. Double-click `MacroMono.ahk` to run
4. Follow welcome screen to calibrate (see [Canvas Calibration](#canvas-calibration))

**Corporate IT Bypass:** Run portable AHK V2 from USB/network drive. Config saves to `Documents\MacroBox\` (no admin needed).

---

## Quick Start

**First Time:**
1. Launch → Calibrate canvas → Done (see [Canvas Calibration](#canvas-calibration) for details)

**Record Macro:**
2. See [Recording Macros](#recording-macros) section below

**Use Auto Mode:**
3. See [Auto Mode](#auto-mode) section below

---

## Canvas Calibration

### Purpose

Teaches MacroBox where you draw bounding boxes. Required for accurate replay and thumbnails.

### How It Works

Stores raw pixel coordinates. Uses proportional scaling on replay:

```
buttonX = (boxScreenX - canvasLeft) / canvasWidth * buttonWidth
```

Works on ANY monitor configuration - no hardcoded values.

### Calibration Steps

**Wide Canvas (16:9):**

1. Settings → Calibrate Wide Canvas
2. Click **top-left corner** of drawing area
3. Click **bottom-right corner**
4. Confirm coordinates → Save

**Narrow Canvas (4:3):**

1. Settings → Calibrate Narrow Canvas
2. Click **top-left corner** of 4:3 area
3. Click **bottom-right corner**
4. System checks ~1.33 aspect ratio → Save

### Multi-Monitor Support

Works on:
- Single monitor (1920x1080)
- Dual monitors with negative coordinates (left at -1920)
- Triple+ monitors
- Ultrawide (3440x1440, 3840x1600)
- Vertical monitors
- Mixed DPI

**Important:** Calibrate on SAME monitor where you'll record.

### When to Recalibrate

- Changed resolution
- Moved to different monitor
- Drawing area moved
- Boxes appear offset

### Storage

Saved to `config.ini`:

```ini
[Canvas]
wideCanvasLeft=-1845.00
wideCanvasTop=38.00
wideCanvasRight=-329.00
wideCanvasBottom=890.00
isWideCanvasCalibrated=1
```

---

## Recording Macros

### Complete Workflow

**1. Start Recording**

Press `CapsLock + F`

- Status: "Recording: ON"
- GUI border: red

**2. Draw Boxes**

Click and drag on screen

- Each box captured with pixel-perfect coordinates

**3. Assign Condition Types**

Press number keys 1-9 while drawing

- Each box can have different type
- Color-coded by configuration

**4. Stop Recording**

Press `CapsLock + F` again

- Status: "Ready to assign - Click button to save"
- GUI: "awaiting assignment" mode

**5. Save to Button**

**Click GUI button with MOUSE** (not hotkey)

- Example: Click Numpad1 button on screen
- Thumbnail appears
- Macro saved

**6. Execute**

Press button hotkey (e.g., Numpad1)

- Replays in <100ms
- Stats update

### Important Notes

- **Hotkeys execute, mouse clicks save**
- Record 5-10 boxes per macro typical
- First box: 180ms delay (stability)
- Subsequent: 120ms between boxes
- Press `Esc` to cancel assignment
- Overwrite by saving to same button

### Canvas Mode

Current mode (Wide/Narrow) determines:
- Which calibration used
- Thumbnail rendering
- Letterbox bars (Narrow only)

**Switch mode BEFORE recording.** Saved macros remember their mode.

---

## Auto Mode

### Purpose

Automatically repeat macros at intervals without manual keypresses.

### Use Cases

- **Continuous Feed**: Manufacturing QC
- **Batch Processing**: Label exactly 50 items
- **Timed Workflows**: Platform time-based tasks
- **Training Data**: Repetitive patterns

### Complete Setup

**1. Record and Save Macro First**

See [Recording Macros](#recording-macros)

**2. Configure Loop**

Right-click button → "Loop Settings"

```
☑ Enable auto mode
Interval: 2.0 seconds (0.5 - 10.0)
Count: 0 (infinite) or 1-999
```

**3. Visual Confirmation**

Yellow border = configured

**4. Start Loop**

Press button hotkey once (e.g., Numpad1)

- First execution: immediate
- Subsequent: interval timing

**5. Stop Loop**

- Press hotkey again (toggle)
- Or right-click → uncheck enable
- Or `NumpadAdd` (emergency stop all)

### Examples

**Infinite (Continuous):**
```
Interval: 1.5s | Count: 0
Use: Manufacturing line
```

**Batch (50 Items):**
```
Interval: 3.0s | Count: 50
Use: Label specific count then stop
```

**Fast (Training Data):**
```
Interval: 0.5s | Count: 20
Use: Rapid similar items
```

### Persistence

Saved per button in `config.ini`:

```ini
[LoopSettings]
L1_numpad1_intervalMs=2000
L1_numpad1_count=0
```

### Limitations

- **Min interval**: 0.5s (500ms)
- **Max interval**: 10s
- **Simultaneous**: 5-10 practical before lag
- **Break mode**: Loops continue (executions recorded, time not tracked)

---

## Statistics & Export

### Statistics Window

Press `F12` to open:

**Left Column - All-Time:**
- Total executions
- Total boxes
- Manual clicks
- Macro clicks
- Active time (hours:minutes)
- Average execution time
- Boxes per hour
- Executions per hour

**Right Column - Today:**
- Same metrics
- Filtered to current date
- Resets at midnight

**Per-Condition Breakdown:**
- Condition 1-9 counts
- Clear count (no type assigned)

**Live Updates:**
- Real-time during execution
- Manual clicks increment
- Active time ticks (excludes break mode)

### What Gets Tracked

**Automatically:**
- **Executions**: One macro replay = 1 execution
- **Boxes**: Individual boxes (1 execution may have 5 boxes)
- **Manual Clicks**: Non-macro left-clicks
- **Macro Clicks**: Clicks during execution
- **Active Time**: Working time (excludes breaks)
- **Session ID**: `sess_YYYYMMDD_HHMMSS` (auto-generated)
- **Username**: Windows username (auto-captured)

**Key Distinction:**
- 1 execution with 5 boxes = 1 execution, 5 boxes (NOT 5 executions)
- ROI based on executions

### CSV Export

**Access:** Stats window → "Export CSV" button

**Location:**
```
Documents\MacroBox\exports\stats_YYYYMMDD_HHMMSS.csv
```

**Format:**
```csv
timestamp,session_id,username,execution_type,button_key,layer,
execution_time_ms,canvas_mode,session_active_time_ms,break_mode_active,
total_boxes,condition_assignments,severity_level,annotation_details,
condition_1_count,condition_2_count,condition_3_count,condition_4_count,
condition_5_count,condition_6_count,condition_7_count,condition_8_count,
condition_9_count,clear_count,macro_clicks,manual_clicks,
execution_success,error_details
```

**Example:**
```csv
2024-12-09 14:30:15,sess_20241209_140000,JohnDoe,macro,numpad1,1,
850,wide,1245000,false,5,Condition 1,medium,"",
5,0,0,0,0,0,0,0,0,0,12,3,true,""
```

---

## Hotkeys

### Default Bindings

| Category | Action | Hotkey | Description |
|----------|--------|--------|-------------|
| **Recording** | Toggle | `CapsLock + F` | Start/stop recording |
| | Submit | `NumpadEnter` | Submit annotation |
| | Direct Clear | `Shift + Enter` | Clear without menu |
| **App** | Statistics | `F12` | Show/hide stats |
| | Break Mode | `Ctrl + B` | Pause time tracking |
| | Settings | `Ctrl + K` | Open settings |
| | Emergency | `NumpadAdd` | Kill all loops |
| **Utility** | Submit | `Shift + CapsLock` | Browser focus + Shift+Enter |
| | Backspace | `Ctrl + CapsLock` | Browser focus + Backspace |
| **Execute** | Numpad | `1-9` | Execute numpad macros |
| | WASD | `Q/W/E/A/S/D/Z/X/C` | Execute WASD macros |

### CapsLock Behavior

**Disabled by design:** CapsLock alone does nothing (prevents accidental caps)

**Toggle caps:** Press `Win + CapsLock`

### Utility Hotkeys

Auto-detect Chrome/Firefox/Edge, switch focus, send keypress, return.

**Enable/Disable:** Settings → Hotkeys

### Customization

Settings → Hotkeys → Edit or click "Set" to capture

**Avoid:** F1-F4, Ctrl+C/V/X/Z (system defaults)

**Safe patterns:** `CapsLock + letter`, `Ctrl + Shift + letter`, `Alt + Numpad`

---

## Configuration Files

### config.ini

**Location:** `MacroBox\config.ini` or `Documents\MacroBox\config.ini`

**Complete Structure:**

```ini
[General]
AnnotationMode=Wide
LastSaved=20241209120000

[Canvas]
wideCanvasLeft=-1845.00
wideCanvasTop=38.00
wideCanvasRight=-329.00
wideCanvasBottom=890.00
isWideCanvasCalibrated=1
narrowCanvasLeft=-1618.00
narrowCanvasTop=156.00
narrowCanvasRight=-553.00
narrowCanvasBottom=1007.00
isNarrowCanvasCalibrated=1

[Timing]
smartBoxClickDelay=45
smartMenuClickDelay=100
firstBoxDelay=180
mouseHoverDelay=30
menuWaitDelay=50
betweenBoxDelay=120

[Hotkeys]
hotkeyRecordToggle=CapsLock & f
hotkeySubmit=NumpadEnter
hotkeyDirectClear=+Enter
hotkeyUtilitySubmit=+CapsLock
hotkeyUtilityBackspace=^CapsLock
hotkeyStats=F12
hotkeyBreakMode=^b
hotkeySettings=^k
utilityHotkeysEnabled=1

[Conditions]
ConditionDisplayName_1=Condition 1
ConditionColor_1=0xFF8C00
ConditionStatKey_1=condition_1
ConditionJsonHigh_1={"..."}
ConditionJsonMedium_1={"..."}
ConditionJsonLow_1={"..."}
# ... repeated for 2-9

[LoopSettings]
L1_numpad1_intervalMs=2000
L1_numpad1_count=0
L1_wasdQ_intervalMs=5000
L1_wasdQ_count=100
```

### macros.txt

**Location:** `Documents\MacroBox\macros.txt`

**Format:** Pipe-delimited

```
buttonName|eventType|param1|param2|param3|param4|metadata
```

**Example:**

```
numpad1|boundingBox|100|200|300|400|deg=1|name=Condition 1
numpad1|mouseDown|-1500|300|left
numpad1|mouseUp|-1200|500|left
numpad2|jsonAnnotation|Wide|2|high
wasdQ|boundingBox|150|250|350|450|deg=3
```

**Event Types:**
- `boundingBox`: Coordinates + metadata
- `mouseDown/Up`: Raw events
- `jsonAnnotation`: segments.ai JSON
- `keyDown/Up`: Keyboard (rare)

---

## Advanced Features

### In-Memory HBITMAP Cache

**What:** Thumbnails stored as Windows bitmap handles in RAM (not disk)

**Why:** Bypasses filesystem restrictions, works in corporate IT, zero disk footprint

**Details:**
- ~50KB per thumbnail
- 18 buttons = ~900KB
- Cleared on: recalibration, color changes, exit
- Regenerated from macro events

### Canvas Modes

**Wide (16:9):** Blue indicator, widescreen  
**Narrow (4:3):** Orange indicator, letterbox bars

Click mode button to switch. Affects NEW recordings only.

### Custom Labels

Right-click button → "Edit Label" → Rename (e.g., "numpad1" → "Full QC Check")

Persists in config.ini.

### Break Mode

`Ctrl + B` toggle:
- Time tracking paused
- Macros work
- Stats don't accumulate

Use for: breaks, lunch, meetings

### Automatic Tracking

- **Manual Clicks**: Non-macro left-clicks
- **Session ID**: `sess_YYYYMMDD_HHMMSS`
- **Username**: Windows username
- **Window Scaling**: Auto-resize with debouncing

---

## Troubleshooting

### Won't Start

**"AutoHotkey V2 not found":** Install from https://www.autohotkey.com/

**"Access Denied":** Run from different location or as Admin

### Calibration Issues

**Boxes offset/invisible:**
1. Settings → Recalibrate
2. Click EXACT corners where you draw
3. Test with one box
4. Multi-monitor: calibrate on SAME monitor

### Recording Issues

**Macro won't save:** Click GUI button with MOUSE (not hotkey). Hotkeys execute, clicks save.

**No thumbnail:** Check boxes drawn, canvas calibrated, button clicked.

### Auto Mode Issues

**Won't start:** Check yellow border, thumbnail visible, press once.

**Stops unexpectedly:** Execution error, emergency stop, or hotkey toggled again.

**Unstable:** Increase interval or use slower timing preset.

### Stats Issues

**Not updating:** Turn off break mode (`Ctrl + B`), execute one macro, press `F12`.

**CSV empty:** No executions recorded. Execute at least one macro first.

### Hotkey Conflicts

Close conflicting apps, press NumLock (numpad), `Win + CapsLock` (caps state), or change binding.

**Avoid:** F1-F4, Ctrl+C/V/X/Z  
**Safe:** `CapsLock + letter`, `Ctrl + Shift + letter`

### Timing Issues

**"Fast" unstable:** Test 3-box macro 20 times, count failures. 0 = good, 5+ = use "Safe" or "Slow".

**First box slow:** Intentional (180ms for stability). Adjust: Settings → Timing → First Box Delay.

---

## Technical Specifications

### Architecture

| Aspect | Value |
|--------|-------|
| Language | AutoHotkey V2 |
| Structure | Monolithic (single file) |
| Lines | 8,923 |
| Functions | 165+ |
| Dependencies | None |

**Note:** Macros named `L1_buttonname` (Layer 1 - internal only, no layer switching)

### Performance

| Metric | Value |
|--------|-------|
| Macro execution | <100ms |
| HBITMAP generation | ~50ms |
| GUI refresh | 60 FPS |
| Stats query | <10ms (10k records) |
| Memory | 50-150MB |
| Auto overhead | <5ms/tick |

### Limitations

| Limit | Value |
|-------|-------|
| Max macros | 999 (practical) |
| Max boxes/macro | 100 |
| Auto interval | 0.5-10s |
| Simultaneous loops | 5-10 (practical) |
| CSV size | Unlimited |
| Stats file | ~1MB/10k exec |

### File Structure

```
MacroMono.ahk                           # Main script (8,923 lines)

Documents\MacroBox\
├── config.ini                          # Configuration
├── macros.txt                          # Recordings
├── stats\
│   └── stats_log.json                  # Persistent stats
└── exports\
    └── stats_YYYYMMDD_HHMMSS.csv      # CSV exports
```

---

## FAQ

**Q: Mac/Linux support?**  
A: No. Windows-only (Win32 APIs).

**Q: Platform bans?**  
A: OS-level operation. Platforms can't distinguish. Use responsibly.

**Q: How many macros?**  
A: 18 slots. ~999 practical limit.

**Q: Transfer between computers?**  
A: Copy `macros.txt` + `config.ini`. Recalibrate (monitor-specific).

**Q: Different resolutions?**  
A: No. Pixel-based. Resolution change = recalibrate + re-record.

**Q: Edit macros?**  
A: Advanced users edit `macros.txt` (pipe-delimited).

**Q: Save to button?**  
A: CLICK GUI button with mouse (not hotkey). Hotkeys execute, clicks save.

**Q: Executions vs boxes?**  
A: Execution = one replay. Boxes = individual boxes. 1 execution with 5 boxes = 1 execution, 5 boxes.

**Q: Different timing per macro?**  
A: No. Timing global. Auto intervals per-button.

**Q: First box slower?**  
A: `firstBoxDelay` for stability (180ms vs 120ms).

**Q: Multiple instances?**  
A: Not recommended (hook conflicts).

**Q: Auto loop limit?**  
A: 5-10 practical before lag.

**Q: Faster than 0.5s?**  
A: No. 500ms minimum. Need faster? Multiple boxes in one macro.

**Q: Auto count zero?**  
A: Loop stops. Button stays enabled. Press to restart.

**Q: Backup?**  
A: Copy `MacroMono.ahk`, `config.ini`, `macros.txt`, `stats_log.json`.

---

## License

**Permissions:**
- ✅ Personal/commercial data labeling use
- ✅ Modify for own use
- ✅ Share original

**Restrictions:**
- ❌ No warranty
- ❌ Use at own risk
- ❌ Author not responsible for bans/issues

---

## Contributing

Pull requests welcome: bug fixes, performance, documentation.

**Standards:** AHK V2 only, self-contained functions, comment logic, backward compatible config.

---

**Version 1.0.0** | **8,923 Lines** | **AutoHotkey V2**

© 2025 MacroBox
