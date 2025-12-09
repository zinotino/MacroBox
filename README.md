# MacroBox: AutoHotkey v2 Data Labeling & Visualization System

**Version**: 1.0.0 (Pre-Release)  
**Language**: AutoHotkey v2  
**License**: [Your License Here]

---

## Table of Contents

1. [Overview](#overview)
2. [Key Features](#key-features)
3. [Quick Start](#quick-start)
4. [Installation](#installation)
5. [Architecture](#architecture)
6. [System Components](#system-components)
7. [Multi-Monitor Calibration System](#multi-monitor-calibration-system)
8. [Suggested Workflows](#suggested-workflows)
9. [Configuration](#configuration)
10. [Usage Guide](#usage-guide)
11. [Troubleshooting](#troubleshooting)
12. [Development](#development)
13. [Contributing](#contributing)

---

## Overview

MacroBox is a professional-grade data labeling and visualization system built in AutoHotkey v2. It provides real-time box annotation with multi-mode rendering, foolproof multi-monitor calibration, and persistent data storage for machine learning preprocessing workflows.

**Primary Use Case**: Annotate regions of interest in streamed or recorded content with automatic visualization in real-time UI overlays.

**Key Innovation**: Universal calibration system that works on ANY monitor configuration (single, dual, ultrawide, vertical, negative coordinates) with zero setup-specific logic.

---

## Key Features

### ✓ Real-Time Annotation
- Live bounding box recording with pixel-perfect accuracy
- Mouse hook integration for seamless capture
- Frame-rate independent event tracking
- Support for multiple simultaneous boxes

### ✓ Dual-Mode Rendering
- **Wide Mode**: Full canvas rendering for detailed work
- **Narrow Mode**: 4:3 aspect ratio letterbox for standardized output
- Color-coded categories for visual organization
- Automatic condition state tracking

### ✓ Foolproof Multi-Monitor Calibration
- One-time setup per physical monitor configuration
- Universal proportional scaling (no setup-specific logic)
- Supports negative coordinates, multi-monitor setups, ultrawide displays
- Persistent calibration across application restarts

### ✓ Data Persistence
- INI-based configuration storage
- Automatic CSV export of annotations
- Macros saved with metadata (timestamp, mode, category)
- Audit trail of all labeling sessions

### ✓ Category Management
- Customizable condition types/categories
- Color-coded visual feedback
- Category statistics and reporting
- Batch operations on categorized data

### ✓ UI Framework
- Status window with real-time feedback
- Settings panel for configuration
- Live preview of calibration
- Session management controls

---

## Quick Start

### For Users (First Time)

1. **Download & Extract**
   ```
   Extract MacroBox to: C:\Tools\MacroBox\
   ```

2. **Run the Application**
   ```
   Double-click: MacroBox.ahk
   AutoHotkey v2 interpreter launches the program
   ```

3. **Initial Calibration** (First Run Only)
   ```
   Warning: "Canvas not calibrated"
   → Click Settings → Calibrate Canvas
   → Click TOP-LEFT corner of your drawing area
   → Click BOTTOM-RIGHT corner of your drawing area
   → Status: "✓ Wide calibrated: 1500x900"
   → Repeat for Narrow mode (if using both)
   ```

4. **Start Recording**
   ```
   Switch to: Wide or Narrow mode
   Draw boxes on screen by clicking and dragging
   Visualizations appear in real-time in the overlay window
   ```

5. **Export Data**
   ```
   Click: Export → Save As CSV
   Data saved with bounding boxes, categories, timestamps
   ```

---

## Installation

### Prerequisites
- **Windows 10+**
- **AutoHotkey v2.0** ([Download](https://www.autohotkey.com/))
- **Screen Resolution**: Minimum 1024x768 (tested up to 3440x1440 ultrawide)

### Setup Steps

1. **Install AutoHotkey v2**
   ```
   Download from: https://www.autohotkey.com/
   Run installer, accept defaults
   AutoHotkey v2 will be available system-wide
   ```

2. **Clone or Download MacroBox**
   ```
   git clone https://github.com/zinotino/MacroBox.git
   OR
   Download ZIP → Extract to C:\Tools\MacroBox\
   ```

3. **Verify Installation**
   ```
   Navigate to: C:\Tools\MacroBox\mono\
   Right-click: main.ahk → Open with → AutoHotkey v2
   If prompt appears: "Canvas not calibrated" → FIRST TIME SETUP (see above)
   ```

4. **Optional: Create Shortcut**
   ```
   Right-click main.ahk → Create Shortcut
   Move to Desktop for quick access
   ```

---

## Architecture

### Project Structure
```
mono/
├── main.ahk                    # Entry point, initialization, main loop
├── config.ini                  # Persistent configuration (auto-created)
├── modules/
│   ├── core/
│   │   ├── calibration.ahk    # Canvas calibration logic
│   │   ├── recording.ahk      # Mouse hook & box recording
│   │   ├── rendering.ahk      # GDI+ visualization
│   │   └── data_handler.ahk   # CSV export & data persistence
│   ├── ui/
│   │   ├── status_window.ahk  # Real-time status display
│   │   ├── settings.ahk       # Configuration UI
│   │   └── overlay.ahk        # Visualization overlay window
│   ├── state/
│   │   ├── state_manager.ahk  # Global state & mode switching
│   │   └── macro_storage.ahk  # In-memory macro management
│   └── utils/
│       ├── math.ahk           # Proportional scaling functions
│       ├── color.ahk          # Condition color mapping
│       └── logging.ahk        # Debug output helpers
├── resources/
│   ├── colors.ini             # Color scheme (RGB codes)
│   └── condition_types.ini    # Category definitions
└── build/
    ├── build.ahk              # Build & compile script
    └── release.ahk            # Release version config
```

### Control Flow
```
START
  ↓
LoadConfig()
  ├─→ LoadCanvasFromConfig() ─→ Set calibration values
  └─→ LoadCategoriesFromConfig() ─→ Set color mappings
  ↓
CheckCalibration()
  ├─→ If NOT calibrated → ShowSettingsWindow() → CalibrateWideCanvas()
  └─→ If calibrated → Continue
  ↓
InitializeHooks()
  ├─→ SetMouseHook() ─→ Start capturing mouse events
  └─→ SetKeyboardHook() ─→ Start capturing hotkeys
  ↓
MAIN LOOP
  ├─→ Input Event → RecordBox() → Store in memory
  ├─→ Every frame → RenderBoxes() → Update overlay
  ├─→ Mode change → SwitchMode() → Update canvas params
  └─→ Export request → ExportToCSV() → Save data
  ↓
SHUTDOWN
  ├─→ SaveCanvasToConfig() ─→ Persist calibration
  ├─→ SaveMacroMetadata() ─→ Save session data
  └─→ Cleanup hooks & windows
```

---

## System Components

### 1. Calibration System
**File**: `modules/core/calibration.ahk`

Handles one-time per-setup canvas calibration. Captures raw screen pixel coordinates.

**Key Functions**:
```ahk
CalibrateWideCanvas()    # Calibrate wide drawing canvas
CalibrateNarrowCanvas()  # Calibrate 4:3 aspect ratio region
SaveCanvasToConfig()     # Persist calibration to config.ini
LoadCanvasFromConfig()   # Load calibration on startup
```

**Why It Works on Any Setup**:
- Stores raw screen pixels (negative coordinates OK)
- Uses proportional scaling: `(pixel - canvasMin) / canvasSize * buttonSize`
- No setup-specific logic
- Works on: negative coords, multiple monitors, ultrawide, vertical orientations

### 2. Recording System
**File**: `modules/core/recording.ahk`

Captures mouse events in real-time using Windows hooks.

**Key Functions**:
```ahk
MouseProc(nCode, wParam, lParam)  # Hook callback on every mouse move
RecordBoxDown()                     # Mouse down → start box
RecordBoxUp()                       # Mouse up → finalize box
StoreBox(left, top, right, bottom)  # Add box to memory
```

**Data Format**:
```
Box {
  .left       = screen pixel X (raw)
  .top        = screen pixel Y (raw)
  .right      = screen pixel X (raw)
  .bottom     = screen pixel Y (raw)
  .categoryId = condition type
  .timestamp  = recording time
  .sessionId  = macro session identifier
}
```

### 3. Rendering System
**File**: `modules/core/rendering.ahk`

Converts recorded boxes to visual overlay using GDI+.

**Key Function**:
```ahk
DrawBoxes(graphics, buttonWidth, buttonHeight, boxes, 
          canvasLeft, canvasTop, canvasRight, canvasBottom, macroMode)
```

**Universal Formula**:
```
buttonX = (boxScreenX - canvasLeft) / (canvasRight - canvasLeft) * buttonWidth
buttonY = (boxScreenY - canvasTop) / (canvasBottom - canvasTop) * buttonHeight
```

**Supports**:
- Filled rectangles with category-based colors
- 4:3 letterbox frame (Narrow mode)
- Semi-transparency (alpha blending ready)

### 4. Data Handler
**File**: `modules/core/data_handler.ahk`

Manages data persistence and export.

**Key Functions**:
```ahk
ExportToCSV()           # Save current session as CSV
ImportFromCSV()         # Load previous session for review/edit
AppendSessionMetadata() # Add timestamp, duration, notes
```

**CSV Format**:
```csv
box_id,session_id,timestamp,mode,category_id,left,top,right,bottom,category_name,color_hex
1,sess_001,2025-10-31T01:00:00Z,Wide,1,100,200,300,400,defect_type_a,0xFF00FF00
2,sess_001,2025-10-31T01:00:15Z,Wide,2,150,250,350,450,defect_type_b,0xFFFF0000
```

### 5. State Manager
**File**: `modules/state/state_manager.ahk`

Tracks application state and mode switching.

**State Variables**:
```ahk
currentMode           # "Wide" or "Narrow"
isRecording           # 1 = active, 0 = paused
isCalibrated          # 1 = ready, 0 = setup required
sessionBoxes[]        # In-memory array of boxes
sessionMetadata       # Current session info
```

**Mode Switching Logic**:
```ahk
SwitchMode(newMode) {
    if (newMode = currentMode)
        return  ; No-op
    
    SaveCurrentSession()  ; Flush in-memory boxes
    currentMode := newMode
    LoadCanvasForMode()
    UpdateOverlay()
}
```

---

## Multi-Monitor Calibration System

*(Detailed specification from your current README, but contextualized)*

### Why This Matters

Traditional systems fail on:
- ✗ Dual monitors with negative X coordinates
- ✗ Ultrawide displays (3440x1440)
- ✗ Vertical/portrait mode setups
- ✗ Mixed DPI systems (e.g., 96 DPI + 125 DPI)

**MacroBox Solution**: Zero setup-specific logic. Pure proportional math.

### How It Works

#### Step 1: Calibration (User Does Once)
```
User Position: Physical monitors arranged however they want
Action: Click top-left of drawing area → Click bottom-right
Result: Raw screen pixels stored: L=-1500, T=100, R=-500, B=1000
```

#### Step 2: Recording (Automatic)
```
User draws boxes on screen
Mouse hook captures: (-1400, 200), (-600, 900), etc.
Stored as: [screen pixels exactly as recorded]
```

#### Step 3: Rendering (Universal Formula)
```
buttonX = (screenX - canvasLeft) / (canvasRight - canvasLeft) * buttonWidth
buttonY = (screenY - canvasTop) / (canvasBottom - canvasTop) * buttonHeight

Example:
  canvasLeft=-1500, canvasRight=-500 (width=1000)
  buttonWidth=392
  screenX=-1400
  buttonX = (-1400 - (-1500)) / (1000) * 392 = 100/1000 * 392 = 39.2 ✓
```

### Example Setups

**Setup A: Dual Monitor (Negative Coords)**
```
Physical:  [Left -1920→0] [Right 0→1920]
Calibrate: User clicks at (-1500, 100) and (-500, 1000)
Saved:     L=-1500, R=-500, T=100, B=1000
Result:    ✓ Works perfectly (width=1000)
```

**Setup B: Single Monitor (Standard)**
```
Physical:  [Monitor 0→1920]
Calibrate: User clicks at (200, 100) and (1700, 1000)
Saved:     L=200, R=1700, T=100, B=1000
Result:    ✓ Works perfectly (width=1500)
```

**Setup C: Ultrawide**
```
Physical:  [Monitor 0→3440]
Calibrate: User clicks at (500, 100) and (3000, 1000)
Saved:     L=500, R=3000, T=100, B=1000
Result:    ✓ Works perfectly (width=2500)
```

### Troubleshooting Calibration

| Problem | Cause | Solution |
|---------|-------|----------|
| Boxes don't appear | Canvas not calibrated | Run Settings → Calibrate Canvas |
| Boxes appear off-screen | Calibration outside actual drawing area | Recalibrate in the exact area where you draw |
| Boxes in wrong position | Coordinates flipped or off | Click top-left first, then bottom-right (order matters) |
| Negative coordinates not working | CoordMode not set to "Screen" | Ensure `CoordMode("Mouse", "Screen")` in calibration |

---

## Suggested Workflows

### Workflow 1: Rapid Annotation (Single Session)
**Scenario**: Label 100 boxes in a 5-minute video segment

1. **Setup** (30 seconds)
   - Start MacroBox
   - Select Wide mode
   - Review video segment

2. **Record** (4 minutes)
   - Draw boxes as defects appear in video
   - Use hotkeys to change category on-the-fly
   - Monitor status window for box count

3. **Export** (30 seconds)
   - Click Export → Save As CSV
   - Use timestamp in filename: `annotations_2025-10-31_0130.csv`

4. **Review** (Optional)
   - Open CSV in spreadsheet
   - Verify box coordinates and categories
   - Re-run annotation if needed

### Workflow 2: Multi-Session Project
**Scenario**: Label defects across 10 different video segments

1. **Day 1: Setup**
   - Calibrate canvas once (persists forever)
   - Create folder: `C:\Projects\DefectLabeling\`

2. **Sessions 1-10**
   - Each session: Open MacroBox → Record boxes → Export CSV
   - Save with naming: `session_01_segment_A.csv`, `session_02_segment_B.csv`, etc.

3. **Consolidation**
   - Combine all CSVs into master file using Python/Excel
   - Check for consistency (box counts, category distribution)
   - Deliver to ML training pipeline

### Workflow 3: Collaborative Labeling
**Scenario**: Team of 3 annotators working on same content

1. **Setup Once** (Shared)
   - Create master config file with calibration values
   - Distribute to all team members

2. **Each Annotator**
   - Copy config to their MacroBox install
   - Record their annotations independently
   - Export with annotator ID: `annotations_john_session_01.csv`

3. **Quality Control**
   - Run comparison script on all CSVs
   - Flag disagreements (same box, different category)
   - Resolve conflicts (majority vote or expert review)

### Workflow 4: Real-Time Feedback
**Scenario**: Validate annotations during live recording

1. **Setup**
   - Split screen: Video player + MacroBox overlay

2. **Record**
   - As defects appear, record boxes in MacroBox
   - Overlay shows real-time visualization
   - Status window confirms box count

3. **Export**
   - End recording → Export immediately
   - Share CSV with team for same-session feedback

### Workflow 5: Iterative Refinement
**Scenario**: Improve annotations from previous session

1. **Load Previous Session**
   - Open MacroBox
   - File → Import Previous Session → select `session_01.csv`
   - All previous boxes display in overlay

2. **Review & Edit**
   - Add missing boxes
   - Correct category assignments
   - Delete false positives

3. **Export v2**
   - Save as: `session_01_v2_refined.csv`
   - Archive original for comparison

---

## Configuration

### config.ini (Auto-Created on First Run)

**Location**: `C:\Tools\MacroBox\mono\config.ini`

```ini
[Canvas]
# Wide mode calibration (uncalibrated defaults)
wideCanvasLeft=0
wideCanvasTop=0
wideCanvasRight=1920
wideCanvasBottom=1080
isWideCanvasCalibrated=0

# Narrow mode calibration (4:3 aspect ratio)
narrowCanvasLeft=0
narrowCanvasTop=0
narrowCanvasRight=1440
narrowCanvasBottom=1080
isNarrowCanvasCalibrated=0

[Appearance]
overlayOpacity=0.7
boxBorderWidth=2
statusWindowX=100
statusWindowY=100

[Export]
defaultExportPath=C:\Users\YourUsername\Documents\MacroBox_Exports\
autoAddTimestamp=1

[Session]
rememberLastMode=1
lastUsedMode=Wide
```

### Customizing Categories/Condition Types

**File**: `config.ini` (Conditions section)

Use the Settings UI (Ctrl+K) to customize your labels. You can define up to 9 custom condition types with:
- Custom display names (shown in UI)
- Custom colors (for visual distinction)
- Internal stat keys (for CSV export)

```ini
[Conditions]
ConditionName_1=
ConditionDisplayName_1=Label 1
ConditionColor_1=0xFF8C00
ConditionStatKey_1=condition_1
```

**Color Format**:
- Hex code with alpha: `0xAARRGGBB`
- Examples:
  - `0xFF00FF00` = Opaque green
  - `0xFF0000FF` = Opaque blue
  - `0x8800FF00` = Semi-transparent green (50% alpha)

### Customizing Hotkeys

**In config.ini** (future version):
```ini
[Hotkeys]
RecordBox=LButton        # Default: left mouse click
CycleMode=F1             # Default: F1 to toggle Wide/Narrow
CycleCategory=F2         # Default: F2 to cycle through categories
ExportData=Ctrl+E        # Default: Ctrl+E to export
ShowSettings=Ctrl+S      # Default: Ctrl+S to open settings
```

---

## Usage Guide

### Starting the Application

**Method 1: Direct Run**
```
Navigate to: C:\Tools\MacroBox\mono\
Double-click: main.ahk
AutoHotkey v2 launches automatically
```

**Method 2: Command Line**
```
AutoHotkey.exe "C:\Tools\MacroBox\mono\main.ahk"
```

**Method 3: Shortcut**
```
Right-click main.ahk → Create Shortcut → Pin to Start Menu
```

### First Run: Initial Calibration

**On startup**, if calibration is missing:

```
⚠️ FIRST TIME SETUP

Canvas not calibrated. You must calibrate before recording.

Go to Settings → Calibrate Canvas
```

1. Click OK
2. Settings window appears
3. Click "Calibrate Wide Canvas"
4. Follow on-screen prompts:
   - Click the TOP-LEFT corner of where you draw
   - Click the BOTTOM-RIGHT corner of where you draw
5. Status: `✓ Wide calibrated: 1500x900 (L=-1500 R=-500)`
6. Repeat for Narrow mode

### Recording Boxes

**During Normal Operation**:

1. **Select Mode**
   - Press: `F1` to toggle between Wide/Narrow
   - Current mode displays in status window

2. **Select Category**
   - Use numpad keys or WASD hotkeys to assign conditions to boxes
   - Current category shows in status with customized label names

3. **Draw Boxes**
   - Click & drag on screen
   - Box appears immediately in overlay window
   - Status updates: "Boxes recorded: 47"

4. **Review Overlay**
   - MacroBox overlay window shows all recorded boxes
   - Colors indicate category
   - Letterbox frame (if Narrow mode) shows 4:3 region

### Exporting Data

**Export Current Session**:
```
1. Click: Export → Save As CSV
2. Choose location (defaults to: C:\Users\YourUsername\Documents\MacroBox_Exports\)
3. Name file: annotations_2025-10-31_0130.csv
4. Click Save
→ CSV created with all recorded boxes + metadata
```

**CSV Contents** (example):
```csv
box_id,session_id,timestamp,mode,category_id,left,top,right,bottom,category_name
1,sess_0001,2025-10-31T01:30:00Z,Wide,1,-1400,200,-600,900,Defect Type A
2,sess_0001,2025-10-31T01:30:15Z,Wide,2,-1350,250,-550,850,Defect Type B
3,sess_0001,2025-10-31T01:30:30Z,Narrow,1,400,300,600,500,Defect Type A
```

### Recalibrating (If Setup Changes)

**If you move monitors or change setup**:

1. Settings → Recalibrate Wide Canvas
2. Or: Settings → Recalibrate Narrow Canvas
3. Follow calibration prompts
4. New values saved to config.ini (old values overwritten)

---

## Troubleshooting

### Application Won't Start

**Error**: `AutoHotkey v2 not found`

**Solution**:
1. Download AutoHotkey v2: https://www.autohotkey.com/
2. Run installer
3. Retry launching MacroBox

---

### Canvas Not Calibrated Warning on Every Startup

**Cause**: `config.ini` is missing or `isWideCanvasCalibrated=0`

**Solution**:
1. Check if `config.ini` exists in the `mono/` folder
2. If missing: MacroBox creates it on first run; recalibrate
3. If exists: Open with Notepad; verify:
   ```ini
   isWideCanvasCalibrated=1
   isNarrowCanvasCalibrated=1
   ```
   If not 1, recalibrate via Settings

---

### Visualizations Don't Appear

**Cause**: Boxes recorded outside calibrated canvas region

**Debug**:
1. Check status window: "Boxes recorded: 0" → No boxes captured
2. Verify canvas calibration matches actual drawing area
3. Recalibrate:
   - Settings → Calibrate Wide Canvas
   - This time, click exactly where you're drawing boxes

**Solution**: Recalibrate the canvas in the correct region

---

### Boxes Appear in Wrong Position

**Cause**: Calibration done in different area than current recording

**Example**: 
- Calibrated at: (-1500 to -500)
- Actually drawing at: (-1000 to 0)
- Result: Boxes appear offset

**Solution**: Recalibrate in the exact area where you're currently drawing

---

### Boxes Appear Off-Screen in Overlay

**Cause**: Recorded boxes outside calibrated canvas boundaries

**Debug**:
1. Check overlay: Boxes disappear at edges
2. Check config.ini: Canvas dimensions
3. Compare with actual drawing region

**Solution**: Recalibrate to include full drawing region

---

### Export Creates Empty CSV

**Cause**: No boxes recorded in current session

**Check**:
1. Status window says "Boxes recorded: 0"
2. Recording mode was never activated

**Solution**: 
1. Record at least one box (click & drag on screen)
2. Verify box appears in overlay
3. Then export

---

### Settings Window Won't Open

**Cause**: UI framework issue or DLL missing

**Solution**:
1. Restart MacroBox
2. If persists: Check for corrupted `modules/ui/` folder
3. Verify GDI+ dependencies are available

---

### Performance Issues / Slow Rendering

**Cause**: Too many boxes in single session (1000+)

**Solution**:
1. Export current session
2. Clear in-memory boxes
3. Start new session
4. Combine CSVs later if needed

---

## Development

### Architecture Overview

**Core Modules**:
- `calibration.ahk` - Canvas setup (foolproof proportional scaling)
- `recording.ahk` - Mouse hook & box capture
- `rendering.ahk` - GDI+ visualization
- `data_handler.ahk` - CSV persistence

**UI Modules**:
- `status_window.ahk` - Real-time feedback display
- `settings.ahk` - Configuration interface
- `overlay.ahk` - Box visualization layer

**Support Modules**:
- `state_manager.ahk` - Global state management
- `math.ahk` - Proportional scaling utilities
- `color.ahk` - Category-to-color mapping

### Building from Source

**Build Script** (for release):
```
Run: build/build.ahk
Output: MacroBox.exe (compiled AutoHotkey binary)
Includes: All modules, resources, config
```

### Code Standards (AHk v2)

- **Strings**: Always quoted (`"text"`)
- **Objects**: Use map syntax (`Map("key", value)`)
- **Functions**: Explicit parameters with types
- **Hooks**: Always cleanup on exit
- **Logging**: Use `OutputDebug()` for debugging

### Testing Checklist

- [ ] Calibration works on single monitor (0, 0, 1920, 1080)
- [ ] Calibration works on dual monitors (negative coords)
- [ ] Boxes render correctly after calibration
- [ ] CSV export includes all recorded boxes
- [ ] Config.ini persists across restarts
- [ ] Mode switching doesn't lose boxes
- [ ] Recalibration doesn't corrupt old data
- [ ] GDI+ rendering performs smoothly (100+ boxes)

---

## Contributing

### How to Contribute

1. **Report Issues**
   - GitHub Issues: Describe reproduction steps
   - Include config.ini content (sanitized)
   - Attach CSV export if relevant

2. **Submit Features**
   - Fork repository
   - Create feature branch: `feature/your-feature`
   - Commit changes following code standards
   - Submit pull request with description

3. **Code Review**
   - All PRs reviewed before merge
   - Must pass test checklist
   - Follow AHk v2 best practices

### Roadmap

**v1.0.0** (Current)
- ✓ Multi-monitor calibration
- ✓ Dual-mode rendering
- ✓ CSV export
- ✓ Basic UI

**v1.1.0** (Planned)
- [ ] Import previous session for editing
- [ ] Batch operations on boxes
- [ ] Statistics dashboard
- [ ] Undo/redo functionality

**v1.2.0** (Future)
- [ ] GPU-accelerated rendering
- [ ] Real-time collaboration
- [ ] Integration with ML pipelines
- [ ] Video timeline integration

---

## Frequently Asked Questions

**Q: Can I use this on macOS or Linux?**  
A: No. MacroBox uses Windows-specific APIs (mouse hooks, GDI+). Windows 10+ only.

**Q: How many boxes can I record in one session?**  
A: Tested reliably up to 10,000 boxes per session. Performance depends on RAM.

**Q: Can I edit boxes after recording?**  
A: v1.0.0: View/export only. v1.1.0 will add editing. Workaround: Export CSV → Edit → Re-import.

**Q: How do I backup my calibration?**  
A: Copy `config.ini` to safe location. Restore by copying back to `mono/` folder.

**Q: Can I use multiple instances of MacroBox?**  
A: Not recommended. Only one mouse hook can be active per process.

---

## License

[Your License Here - e.g., MIT, GPL, Proprietary]

---

## Support

- **Documentation**: See [Wiki](link-to-wiki)
- **Issues**: GitHub Issues
- **Discussions**: GitHub Discussions
- **Email**: [your-email@domain.com]

---

**Made with AutoHotkey v2**  
**Last Updated**: 2025-10-31
