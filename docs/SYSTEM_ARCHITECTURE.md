# System Architecture - Major Restore Point
**Date:** 2025-11-11
**Application:** MacroMonoo - Data Labeling Assistant
**Version:** Stable Build
**Total Lines:** 6,627 lines of AutoHotkey v2.0 code

---

## Table of Contents
- [Overview](#overview)
- [File Inventory](#file-inventory)
- [System 1: Visualization System](#system-1-visualization-system)
- [System 2: Stats System](#system-2-stats-system)
- [System 3: Execution System](#system-3-execution-system)
- [System Interactions](#system-interactions)
- [Critical Implementation Details](#critical-implementation-details)
- [Recent Refinements](#recent-refinements)

---

## Overview

MacroMonoo is a monolithic AutoHotkey v2.0 application designed for efficient data labeling with visual annotation support. The application consists of three major, interconnected systems that work together to provide a seamless annotation workflow.

### Architecture Principles
- **Monolithic Design**: Single-file architecture for simplicity and portability
- **Event-Driven**: Mouse and keyboard hooks for recording, timers for async operations
- **Memory-Optimized**: HBITMAP caching with reference counting
- **Data Persistence**: Dual-layer storage (runtime + permanent archive)
- **DPI-Aware**: Proper scaling for high-resolution displays

### Core Technologies
- **AutoHotkey v2.0**: Scripting engine
- **Windows GDI+**: Graphics rendering for visualizations
- **JSON**: Runtime data storage (stats_log.json)
- **CSV**: Statistics export and archival (macro_execution_stats.csv, master_stats_permanent.csv)
- **INI**: Configuration persistence (config.ini)
- **Text Format**: Macro event storage (config_simple.txt)

---

## File Inventory

### Core Application Files
| File | Size | Purpose |
|------|------|---------|
| `MacroMonoo.ahk` | 6,627 lines | Main application code |
| `config.ini` | 930 bytes | Configuration and settings |
| `config_simple.txt` | 1,451 bytes | Macro event storage |
| `vizlog_debug.txt` | 13,840 bytes | Visualization debug log |

### Data Files
| File | Size | Purpose |
|------|------|---------|
| `data/stats_log.json` | 92 bytes | Current runtime stats |
| `data/stats_log.backup.json` | 1,243 bytes | Stats backup |
| `data/macro_execution_stats.csv` | 630 bytes | Display statistics |
| `data/master_stats_permanent.csv` | 630 bytes | Permanent stats archive |

### Directories
- `thumbnails/` - Reserved for future thumbnail storage (currently empty)
- `data/` - Statistics and runtime data storage

---

## System 1: Visualization System

**Location:** MacroMonoo.ahk (lines 907-1768)
**Debug Log:** vizlog_debug.txt

### Purpose
The Visualization System creates visual thumbnails of recorded macros, displaying bounding boxes color-coded by degradation type. It supports dual canvas modes (Wide/Narrow) with intelligent caching to minimize memory usage and maximize performance.

---

### Architecture Components

#### 1. GDI+ Initialization Module (lines 1022-1053)
**Purpose:** Initialize Windows GDI+ graphics library for rendering operations.

**Key Functions:**
- `InitializeGDIPlus()` - Starts GDI+ with startup token
- Error handling for initialization failures
- Token management for proper shutdown

**Flow:**
```
Application Start → InitializeGDIPlus() → Store gdiplusToken → Ready for Graphics Operations
Application Exit → GdiplusShutdown(gdiplusToken) → Cleanup
```

---

#### 2. Canvas Calibration System (lines 915-1002)
**Purpose:** Define annotation viewport boundaries for accurate box positioning.

**Canvas Modes:**

##### Wide Mode (16:9 aspect ratio)
- **Use Case:** Full-screen widescreen recordings
- **Default Canvas:** `26,193 → 1652,999` (from config.ini)
- **Target Content:** General annotation tasks, landscape-oriented media
- **Visualization:** Full-width thumbnails, no letterboxing

##### Narrow Mode (4:3 aspect ratio)
- **Use Case:** Mobile/portrait-oriented content
- **Default Canvas:** `428,196 → 1363,998` (from config.ini)
- **Target Content:** Phone screens, narrow viewports
- **Visualization:** Letterboxed thumbnails with gray bars on sides

**Calibration Process:**
1. User presses calibration button
2. Instructions displayed: "Click top-left corner, then bottom-right corner"
3. Two clicks captured → Canvas bounds stored
4. Saved to config.ini with `isWideCanvasCalibrated=1` flag
5. Mode indicator updated on GUI

**Multi-Monitor Support:**
- Virtual screen bounds detection (`SysGet 76, 77, 78, 79`)
- Coordinates relative to primary monitor
- Auto-detection of screen layout

---

#### 3. HBITMAP Visualization Engine (lines 1516-1678)
**Purpose:** Convert macro events into visual thumbnails stored as HBITMAPs (Windows bitmap handles).

**Key Features:**
- **Zero File I/O:** Pure in-memory rendering
- **Smart Caching:** Cache key based on box coordinates + dimensions + mode
- **Reference Counting:** Prevents memory leaks
- **Cache Validation:** Checks HBITMAP validity before use

**Core Function: `CreateHBITMAPVisualization(events, buttonWidth, buttonHeight, canvasObj)`**

**Algorithm:**
```
1. Extract boundingBox events from macro
2. Generate cache key: "{boxes}|{dimensions}_{mode}"
   Example: "559,289,634,457|760,315,829,539|392x153_Narrow"
3. Check cache:
   IF cached HBITMAP exists AND is valid:
     - Increment reference count
     - Return cached HBITMAP
   ELSE:
     - Create new GDI+ bitmap (buttonWidth × buttonHeight)
     - Fill white background
     - Call DrawMacroBoxesOnButton() to draw boxes
     - Convert GDI+ bitmap → HBITMAP
     - Store in cache with reference count = 1
     - Return new HBITMAP
```

**Cache Management:**
```ahk
; Global maps
hbitmapCache := Map()           ; cacheKey → HBITMAP handle
hbitmapRefCounts := Map()       ; HBITMAP handle → reference count

; Adding reference
AddHBITMAPReference(hbitmap) {
    hbitmapRefCounts[hbitmap] := (hbitmapRefCounts.Has(hbitmap) ? hbitmapRefCounts[hbitmap] : 0) + 1
}

; Removing reference
RemoveHBITMAPReference(hbitmap) {
    if (hbitmapRefCounts.Has(hbitmap)) {
        hbitmapRefCounts[hbitmap]--
        if (hbitmapRefCounts[hbitmap] <= 0) {
            DllCall("DeleteObject", "Ptr", hbitmap)  ; Free Windows resource
            hbitmapRefCounts.Delete(hbitmap)
        }
    }
}
```

---

#### 4. Box Drawing Module (lines 1182-1329)
**Purpose:** Render bounding boxes on thumbnails with proper scaling and letterboxing.

**Core Function: `DrawMacroBoxesOnButton(graphics, events, buttonWidth, buttonHeight, canvasObj)`**

**Steps:**
1. **Extract Canvas Info:**
   ```ahk
   canvasWidth := canvasObj.right - canvasObj.left
   canvasHeight := canvasObj.bottom - canvasObj.top
   mode := canvasObj.mode  ; "Wide" or "Narrow"
   ```

2. **Handle Letterboxing (Narrow Mode Only):**
   ```ahk
   if (mode = "Narrow") {
       ; Calculate 16:9 viewport within 4:3 canvas
       targetAspect := 16/9
       canvasAspect := canvasWidth / canvasHeight

       if (canvasAspect > targetAspect) {
           ; Canvas wider than 16:9 → vertical letterbox bars
           usableWidth := canvasHeight * targetAspect
           usableHeight := canvasHeight
           offsetX := (canvasWidth - usableWidth) / 2
           offsetY := 0
       }
   }
   ```

3. **Draw Letterbox Bars (if applicable):**
   ```ahk
   ; Gray bars on left and right sides
   leftBarWidth := (offsetX / canvasWidth) * buttonWidth
   rightBarX := buttonWidth - leftBarWidth

   DllCall("gdiplus\GdipFillRectangle",
       "Ptr", graphics,
       "Ptr", grayBrush,
       "Float", 0,
       "Float", 0,
       "Float", leftBarWidth,
       "Float", buttonHeight)
   ```

4. **Scale and Draw Each Box:**
   ```ahk
   for box in boundingBoxes {
       ; Normalize to canvas space
       normX1 := (box.left - canvasLeft - offsetX) / usableWidth
       normY1 := (box.top - canvasTop - offsetY) / usableHeight
       normX2 := (box.right - canvasLeft - offsetX) / usableWidth
       normY2 := (box.bottom - canvasTop - offsetY) / usableHeight

       ; Clip to valid range [0, 1]
       normX1 := Max(0, Min(1, normX1))
       normY1 := Max(0, Min(1, normY1))
       normX2 := Max(0, Min(1, normX2))
       normY2 := Max(0, Min(1, normY2))

       ; Scale to button dimensions
       btnX1 := leftBarWidth + (normX1 * usableButtonWidth)
       btnY1 := normY1 * buttonHeight
       btnX2 := leftBarWidth + (normX2 * usableButtonWidth)
       btnY2 := normY2 * buttonHeight

       ; Draw rectangle with degradation color
       color := GetDegradationColor(box.degradationType)
       DrawRectangle(graphics, btnX1, btnY1, btnX2, btnY2, color, thickness=2)
   }
   ```

---

#### 5. Degradation Color Coding
**Purpose:** Visual distinction between different degradation types.

**Color Mapping:**
```ahk
GetDegradationColor(degradationType) {
    static colorMap := Map(
        1, 0xFFFFD700,  ; Smudge           → Gold
        2, 0xFF87CEEB,  ; Glare            → Sky Blue
        3, 0xFF90EE90,  ; Splashes         → Light Green
        4, 0xFFFFA500,  ; Partial Blockage → Orange
        5, 0xFFFF4500,  ; Full Blockage    → Red-Orange
        6, 0xFFFFFF00,  ; Light Flare      → Yellow
        7, 0xFF4682B4,  ; Rain             → Steel Blue
        8, 0xFFD3D3D3,  ; Haze             → Light Gray
        9, 0xFFF0F8FF,  ; Snow             → Alice Blue
        0, 0xFF808080   ; Clear (default)  → Gray
    )
    return colorMap.Has(degradationType) ? colorMap[degradationType] : colorMap[0]
}
```

**Visual Examples:**
- **Smudge (Gold):** Finger marks, smears
- **Glare (Sky Blue):** Light reflections
- **Splashes (Light Green):** Water drops, liquid spots
- **Partial Blockage (Orange):** Partial obstruction of content
- **Full Blockage (Red-Orange):** Complete obstruction
- **Light Flare (Yellow):** Lens flare, bright spots
- **Rain (Steel Blue):** Rain drops on lens
- **Haze (Light Gray):** Fog, atmospheric haze
- **Snow (Alice Blue):** Snow on lens

---

#### 6. JSON Annotation Visuals (lines 1381-1515)
**Purpose:** Create visual indicators for JSON profile annotations (non-box-drawing annotations).

**Core Function: `CreateJsonAnnotationVisual(categoryId, buttonWidth, buttonHeight, canvasMode)`**

**Visual Design:**
- Solid colored rectangle with category text
- Letterboxing in Narrow mode (gray bars on sides)
- Color matches degradation type from categoryId

**Algorithm:**
```
1. Create GDI+ bitmap (buttonWidth × buttonHeight)
2. Fill background with degradation color
3. If Narrow mode:
   - Draw gray letterbox bars (16.67% width on each side)
4. Render category name as text (centered)
5. Convert to HBITMAP
6. Return for button display
```

---

### Data Flow

```
╔════════════════════════════════════════════════════════════════╗
║                    VISUALIZATION DATA FLOW                      ║
╚════════════════════════════════════════════════════════════════╝

┌──────────────────┐
│ Macro Recording  │
│ (Execution Sys)  │
└────────┬─────────┘
         │
         ├─ Capture Canvas Mode: annotationMode global variable
         ├─ Capture Canvas Coords: wideCanvas/narrowCanvas objects
         ├─ Store on Event: event.recordedMode, event.recordedCanvas
         │
         ▼
┌──────────────────┐
│ Button Display   │
│ Request          │
└────────┬─────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ ExtractBoxEvents(events)             │
│ - Filters boundingBox events         │
│ - Includes degradationType property  │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ CreateHBITMAPVisualization()         │
│ - Generate cache key                 │
│ - Check hbitmapCache                 │
└────────┬─────────────────────────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
Cache Hit   Cache Miss
    │         │
    │         ▼
    │    ┌────────────────────────────┐
    │    │ Create GDI+ Bitmap         │
    │    │ - Dimensions: buttonW×H    │
    │    │ - White background         │
    │    └────────┬───────────────────┘
    │             │
    │             ▼
    │    ┌────────────────────────────┐
    │    │ DrawMacroBoxesOnButton()   │
    │    │ - Scale coordinates        │
    │    │ - Apply letterboxing       │
    │    │ - Color-code by degType    │
    │    └────────┬───────────────────┘
    │             │
    │             ▼
    │    ┌────────────────────────────┐
    │    │ Convert to HBITMAP         │
    │    │ - GdipCreateHBITMAPFrom... │
    │    │ - Store in cache           │
    │    │ - Set refCount = 1         │
    │    └────────┬───────────────────┘
    │             │
    └─────────────┴─────────────────────┐
                                        │
                                        ▼
                              ┌──────────────────┐
                              │ Return HBITMAP   │
                              │ - Increment ref  │
                              └────────┬─────────┘
                                       │
                                       ▼
                              ┌──────────────────┐
                              │ Display in GUI   │
                              │ (Picture Control)│
                              └──────────────────┘
```

---

### Integration Points

**With Execution System:**
- **Recording:** Captures `recordedMode` and `recordedCanvas` during macro recording
- **Assignment:** Copies canvas properties to button macros
- **Playback:** Uses original canvas for accurate replay

**With Stats System:**
- **Canvas Mode Tracking:** `canvas_mode` field in execution stats
- **Degradation Counting:** Reads `degradationType` from box events

**With Config System:**
- **Calibration Persistence:** Saves canvas bounds to config.ini
- **Mode State:** Saves `AnnotationMode=Wide|Narrow` to config.ini

**With GUI System:**
- **Button Thumbnails:** HBITMAPs displayed in picture controls
- **Mode Toggle Button:** Updates text and saves to config

---

### DPI Awareness

**Problem:** On high-DPI displays (150%, 200% scaling), coordinates appear misaligned.

**Solution:**
```ahk
screenScale := A_ScreenDPI / 96.0

; Convert physical pixels to logical coordinates
canvasLeftLogical := canvasLeft / screenScale
canvasTopLogical := canvasTop / screenScale
canvasRightLogical := canvasRight / screenScale
canvasBottomLogical := canvasBottom / screenScale

; All calculations use logical coordinates
```

**Effect:** Boxes align perfectly regardless of Windows display scaling.

---

### Recent Enhancements

1. **Enhanced Debug Logging (vizlog_debug.txt):**
   ```
   [2025-11-11 18:14:16] MODE: Narrow
   [2025-11-11 18:14:16] Canvas: 428.00,196.00 → 1363.00,998.00
   [2025-11-11 18:14:16] Box #1: 559,289 → 634,457 (deg=1)
   [2025-11-11 18:14:16] HBITMAP Created: 0x12AB3400
   [2025-11-11 18:14:16] Cache Key: 559,289,634,457|392x153_Narrow
   ```

2. **Canvas Persistence:**
   - Each event stores its `recordedCanvas` object
   - Playback always uses original canvas
   - Prevents misalignment when mode changes

3. **Memory Safety:**
   - `IsHBITMAPValid()` checks handle validity
   - Reference counting prevents premature deletion
   - Cache cleanup on invalidation

---

## System 2: Stats System

**Location:** MacroMonoo.ahk (lines 1769-3011)
**Data Files:**
- `stats_log.json` (runtime memory)
- `stats_log.backup.json` (backup)
- `macro_execution_stats.csv` (display stats)
- `master_stats_permanent.csv` (permanent archive)

### Purpose
The Stats System tracks all macro and JSON profile executions, providing detailed analytics on degradation annotations, execution times, active annotation time, and user productivity metrics.

---

### Architecture Components

#### 1. Stats Data Module (lines 1769-1984)
**Purpose:** Manage CSV structure and file I/O.

**CSV Schema:**
```csv
timestamp,session_id,username,execution_type,button_key,layer,execution_time_ms,total_boxes,degradation_assignments,severity_level,canvas_mode,session_active_time_ms,break_mode_active,smudge_count,glare_count,splashes_count,partial_blockage_count,full_blockage_count,light_flare_count,rain_count,haze_count,snow_count,clear_count,annotation_details,execution_success,error_details
```

**Key Functions:**
- `BuildStatsCSVHeader()` - Generates CSV header row
- `BuildExecutionCSVRow(executionDataMap)` - Converts data map to CSV row
- `InitializeStatsFiles()` - Creates CSV files if missing
- `AppendToCSV(filePath, row)` - Atomic append operation

---

#### 2. Unified Query System (lines 1985-2375)
**Purpose:** Flexible data retrieval with filtering and caching.

**Core Function: `GetUnifiedStats(filter := "all")`**

**Filter Options:**
- `"all"` - All time statistics
- `"today"` - Today's date only (cached)
- `"session"` - Current session ID only

**Algorithm:**
```
1. IF filter = "today" AND cache valid:
   - Use todayStatsCache
   - Add LIVE delta from current session
   - Return cached + live data

2. ELSE load from macroExecutionLog (in-memory):
   - Filter by date/session as needed
   - Aggregate metrics:
     * Total executions
     * Total boxes
     * Active time (sum session_active_time_ms)
     * Degradation counts (smudge, glare, splashes, etc.)
     * Severity counts (high, medium, low)
   - Calculate derived metrics:
     * Average execution time
     * Boxes per hour
     * Executions per hour
   - Group by user, button, layer

3. Return aggregated stats object
```

**Today Stats Caching:**
```ahk
; Cache structure
todayStatsCache := {
    date: "2025-11-11",
    totalExecutions: 42,
    totalBoxes: 156,
    activeTimeMs: 3600000,
    degradations: {smudge: 10, glare: 20, ...},
    ...
}

; Invalidation triggers
InvalidateTodayStatsCache() {
    global todayStatsCacheInvalidated := true
}

; Called on:
// - New execution recorded
// - Date change detected
// - Stats reset
```

**Live Time Calculation:**
```ahk
; For current session, add live delta
if (sessionStats.Has(currentSessionId)) {
    liveActiveTimeMs := A_TickCount - sessionStartTime - totalBreakTime
    sessionStats[currentSessionId].activeTimeMs += liveActiveTimeMs
}
```

---

#### 3. Stats Recording (lines 2376-2707)
**Purpose:** Capture execution metadata and persist to storage.

**Entry Point: `RecordExecutionStatsAsync(params)`**

**Async Architecture:**
```ahk
RecordExecutionStatsAsync(params) {
    ; Quick validation
    if (breakMode || recording || playback) {
        return  ; Don't record in these states
    }

    ; Schedule delayed execution (non-blocking)
    SetTimer(() => DoRecordExecutionStatsBlocking(params), -50)
}

DoRecordExecutionStatsBlocking(params) {
    ; Actual I/O operations happen here
    RecordExecutionStats(params.events, params.buttonKey, ...)
}
```

**Core Function: `RecordExecutionStats(events, buttonKey, layer, execType)`**

**Steps:**
1. **Count Degradations:**
   ```ahk
   degradationCounts := Map(
       "smudge", 0, "glare", 0, "splashes", 0,
       "partial_blockage", 0, "full_blockage", 0,
       "light_flare", 0, "rain", 0, "haze", 0, "snow", 0, "clear", 0
   )

   for event in events {
       if (event.type = "boundingBox" && event.Has("degradationType")) {
           degradationName := GetDegradationName(event.degradationType)
           degradationCounts[degradationName]++
       }
   }
   ```

2. **Build Execution Data Map:**
   ```ahk
   executionData := Map(
       "timestamp", FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss"),
       "session_id", currentSessionId,
       "username", A_UserName,
       "execution_type", execType,  ; "macro" | "json_profile" | "clear"
       "button_key", buttonKey,
       "layer", layer,
       "execution_time_ms", executionTimeMs,
       "total_boxes", totalBoxes,
       "degradation_assignments", degradationList,  ; "smudge,glare,splashes"
       "severity_level", severity,  ; "high" | "medium" | "low" | ""
       "canvas_mode", canvasMode,  ; "wide" | "narrow"
       "session_active_time_ms", sessionActiveTimeMs,
       "break_mode_active", breakMode,
       "smudge_count", degradationCounts["smudge"],
       "glare_count", degradationCounts["glare"],
       ; ... all other degradation counts ...
       "execution_success", "true",
       "error_details", ""
   )
   ```

3. **Persist Data:**
   ```ahk
   ; Append to both CSV files
   AppendToCSV("data/macro_execution_stats.csv", row)
   AppendToCSV("data/master_stats_permanent.csv", row)

   ; Add to in-memory log
   macroExecutionLog.Push(executionData)

   ; Invalidate today cache
   InvalidateTodayStatsCache()

   ; Save to JSON (runtime backup)
   SaveStatsToJson("data/stats_log.json")
   ```

---

#### 4. Stats GUI Module (lines 2709-3011)
**Purpose:** Live-updating statistics dashboard.

**GUI Layout:**
```
┌─────────────────────────────────────────┐
│          Statistics Dashboard           │
├─────────────────────────────────────────┤
│                                         │
│  All-Time Stats          Today's Stats  │
│  ───────────────         ──────────────  │
│  Executions: 156         Executions: 42 │
│  Boxes: 624              Boxes: 168     │
│  Active Time: 2h 15m     Active: 45m    │
│  Avg Time: 1.2s          Avg: 1.1s      │
│  Boxes/hour: 276         Boxes/hr: 224  │
│                                         │
│  Degradation Breakdown (Macros)         │
│  ───────────────────────────────────    │
│  Smudge: 45    Glare: 78    Splashes: 32│
│  Partial: 12   Full: 8      Flare: 15   │
│  Rain: 5       Haze: 3      Snow: 1     │
│                                         │
│  JSON Annotations                       │
│  ───────────────────────────────────    │
│  Smudge: 12    Glare: 18    Splashes: 7 │
│  High: 15      Medium: 10   Low: 12     │
│                                         │
│  [ Reset Display Stats ]  [ Export ]    │
└─────────────────────────────────────────┘
```

**Live Updates:**
```ahk
; 500ms refresh timer
SetTimer(() => UpdateStatsDisplay(), 500)

UpdateStatsDisplay() {
    allTimeStats := GetUnifiedStats("all")
    todayStats := GetUnifiedStats("today")  ; Uses cache + live delta

    ; Update GUI controls
    allTimeExecutionsText.Value := allTimeStats.totalExecutions
    todayExecutionsText.Value := todayStats.totalExecutions
    allTimeActiveTimeText.Value := FormatTimeHMS(allTimeStats.activeTimeMs)
    ; ... update all other fields ...
}
```

---

### Degradation Tracking

**10 Degradation Types:**
```ahk
degradationMap := Map(
    1, "smudge",           ; Finger marks, smears
    2, "glare",            ; Light reflections
    3, "splashes",         ; Water drops, liquid spots
    4, "partial_blockage", ; Partial obstruction
    5, "full_blockage",    ; Complete obstruction
    6, "light_flare",      ; Lens flare, bright spots
    7, "rain",             ; Rain drops on lens
    8, "haze",             ; Fog, atmospheric haze
    9, "snow",             ; Snow on lens
    0, "clear"             ; No degradation (default)
)
```

**Tracking Methods:**

**A. Macro Executions:**
- Each `boundingBox` event has `degradationType` property (1-9 or 0)
- Stats system counts occurrences of each type
- Example: 4 boxes with types [1, 2, 3, 4] → smudge:1, glare:1, splashes:1, partial:1

**B. JSON Profile Executions:**
- User selects single degradation type + severity
- Recorded as single annotation in stats
- Example: Glare (High) → glare_count: 1, severity_level: "high"

**C. Auto-Assignment:**
- If no keypress detected after box draw, inherits previous box's degradation type
- Ensures all boxes have a type assigned

---

### Time Tracking

**Session Active Time:**
```ahk
; Session start
sessionStartTime := A_TickCount
totalBreakTime := 0

; During execution
elapsedSinceSessionStart := A_TickCount - sessionStartTime - totalBreakTime

; Break mode
ToggleBreakMode() {
    if (!breakMode) {
        breakMode := true
        breakStartTime := A_TickCount
    } else {
        breakMode := false
        totalBreakTime += A_TickCount - breakStartTime
    }
}

; Active time = elapsed - break time
sessionActiveTimeMs := A_TickCount - sessionStartTime - totalBreakTime
```

**Features:**
- Tracks only active annotation time
- Excludes break mode periods
- Cumulative across sessions (stored in CSV)
- Live calculation for current session

---

### Dual Storage System

**Purpose:** Separate resettable display stats from permanent archive.

**Display Stats (`macro_execution_stats.csv`):**
- Shown in GUI
- Can be reset with "Reset Display Stats" button
- Resets only display CSV, not permanent archive
- Use case: Clean slate for testing or new project phase

**Permanent Archive (`master_stats_permanent.csv`):**
- Never reset automatically
- Historical record preservation
- Backup for data recovery
- Use case: Long-term analytics, audit trail

**Reset Behavior:**
```ahk
ResetDisplayStats() {
    ; Clear display CSV
    FileDelete("data/macro_execution_stats.csv")
    InitializeStatsFiles()

    ; Clear in-memory log
    macroExecutionLog := []

    ; Clear cache
    InvalidateTodayStatsCache()

    ; Permanent archive UNCHANGED
}
```

---

### Data Flow

```
╔════════════════════════════════════════════════════════════════╗
║                      STATS DATA FLOW                            ║
╚════════════════════════════════════════════════════════════════╝

┌──────────────────┐
│ Macro/JSON Exec  │
│ (Execution Sys)  │
└────────┬─────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ RecordExecutionStatsAsync()          │
│ - Quick validation                   │
│ - SetTimer for delayed execution     │
└────────┬─────────────────────────────┘
         │ (50ms delay)
         ▼
┌──────────────────────────────────────┐
│ DoRecordExecutionStatsBlocking()     │
│ - Calls blocking I/O function       │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ RecordExecutionStats()               │
│ - Count degradations                 │
│ - Extract metadata                   │
│ - Build executionData map            │
└────────┬─────────────────────────────┘
         │
         ├───────────────┬──────────────┐
         │               │              │
         ▼               ▼              ▼
┌────────────┐  ┌────────────┐  ┌──────────────┐
│ Display    │  │ Permanent  │  │ In-Memory    │
│ CSV        │  │ CSV        │  │ Log (Array)  │
└─────┬──────┘  └─────┬──────┘  └──────┬───────┘
      │               │                │
      └───────────────┴────────────────┤
                                       │
                                       ▼
                          ┌─────────────────────┐
                          │ InvalidateCache()   │
                          │ - Today stats cache │
                          └──────────┬──────────┘
                                     │
                                     ▼
                          ┌─────────────────────┐
                          │ SaveStatsToJson()   │
                          │ - stats_log.json    │
                          │ - backup created    │
                          └──────────┬──────────┘
                                     │
                                     ▼
                          ┌─────────────────────┐
                          │ GUI Auto-Refresh    │
                          │ - 500ms timer       │
                          │ - Live delta calc   │
                          └─────────────────────┘
```

---

### Integration Points

**With Execution System:**
- **Trigger:** Called after every macro/JSON execution
- **Data Source:** Extracts degradation info from events
- **Timing:** Measures execution time (playback duration)

**With Visualization System:**
- **Canvas Mode:** Captured in `canvas_mode` field
- **Box Counting:** Reads total boundingBox events

**With GUI System:**
- **Display:** Stats GUI window with live updates
- **Break Mode:** Pauses time tracking when active

**With Config System:**
- **Session ID:** Generated on app start, stored in config
- **Username:** Read from `A_UserName`

---

### Recent Enhancements

1. **Live Time Display:**
   - Current session delta calculated on-the-fly
   - Formula: `cachedTime + (A_TickCount - sessionStart - breakTime)`
   - No lag in GUI updates
   - Accurate to-the-second tracking

2. **Cache Optimization:**
   - Today stats cached for performance
   - Smart invalidation on new executions
   - Live recalculation for rates (boxes/hour, exec/hour)

3. **Async Recording:**
   - Non-blocking CSV writes
   - Timer-based delayed execution (50ms)
   - Prevents UI freeze during I/O

4. **Degradation Summary:**
   - `degradation_assignments` field: comma-separated list
   - Example: "smudge,glare,splashes,partial_blockage"
   - Enables quick pattern recognition

---

## System 3: Execution System

**Location:** MacroMonoo.ahk (lines 3314-3785)
**Config:** config_simple.txt (macro event storage)

### Purpose
The Execution System handles macro recording, degradation assignment, and playback of both macro-based annotations (box drawing) and JSON profile annotations (single-selection with severity).

---

### Architecture Components

#### 1. Safe Execution Layer (lines 3314-3323)
**Purpose:** Prevent accidental macro triggers during recording or other sensitive operations.

**Function: `SafeExecuteMacroByKey(hotkeyName)`**

**Blocked Hotkeys:**
- `CapsLock` - Recording toggle key
- `f` - Recording modifier
- `Space` - UI interaction key

**Validation:**
```ahk
SafeExecuteMacroByKey(hotkeyName) {
    ; Block if recording, playing, or awaiting assignment
    if (recording || playback || awaitingAssignment) {
        return
    }

    ; Block if break mode active
    if (breakMode) {
        return
    }

    ; Block specific keys
    if (hotkeyName = "CapsLock" || hotkeyName = "f" || hotkeyName = "Space") {
        return
    }

    ; Safe to execute
    ExecuteMacro(hotkeyName)
}
```

---

#### 2. Macro Execution Engine (lines 3324-3412)
**Purpose:** Route execution requests to appropriate handlers (macro vs JSON).

**Function: `ExecuteMacro(buttonName)`**

**Flow:**
```
1. Check if awaiting assignment:
   IF awaitingAssignment:
     - AssignToButton(buttonName)
     - return

2. Load macro events:
   macroKey := "L" . currentLayer . "_" . buttonName
   events := macroEvents[macroKey]

3. Validate events exist:
   IF !events || events.Length = 0:
     - return (no macro assigned)

4. Detect execution type:
   firstEvent := events[1]
   IF firstEvent.type = "jsonAnnotation":
     - ExecuteJsonAnnotation(events)
   ELSE:
     - PlayEventsOptimized(events)

5. Record stats:
   RecordExecutionStatsAsync(...)
```

---

#### 3. Recording System (lines 3414-3565)
**Purpose:** Capture user input and convert to replayable event streams.

**Hotkey:** `CapsLock & f` (configurable in config.ini)

**Function: `F9_RecordingOnly()`**

**Recording Lifecycle:**

**A. Start Recording:**
```
1. Create temporary macro name:
   tempRecordingKey := "temp_recording_" . A_Now

2. Capture current canvas mode:
   recordedMode := annotationMode  ; "Wide" or "Narrow"
   recordedCanvas := (mode = "Wide") ? wideCanvas : narrowCanvas

3. Initialize event array:
   macroEvents[tempRecordingKey] := []

4. Install hooks:
   MouseHook := SetWindowsHookEx(WH_MOUSE_LL, ...)
   KeyboardHook := SetWindowsHookEx(WH_KEYBOARD_LL, ...)

5. Update GUI:
   recordButton.Text := "⬛ Stop Recording"
   statusText.Value := "Recording..."
```

**B. Event Capture:**

**Mouse Events:**
```ahk
MouseProc(nCode, wParam, lParam) {
    if (nCode < 0) return CallNextHookEx(0, nCode, wParam, lParam)

    mouseData := NumGet(lParam, 0, "Int64")
    cursorX := NumGet(lParam, 0, "Int")
    cursorY := NumGet(lParam, 4, "Int")

    switch wParam {
        case WM_LBUTTONDOWN:
            dragStartX := cursorX
            dragStartY := cursorY
            dragStartTime := A_TickCount
            isDragging := false

        case WM_MOUSEMOVE:
            if (dragStartX != -1) {
                dragDistX := Abs(cursorX - dragStartX)
                dragDistY := Abs(cursorY - dragStartY)

                ; Detect if drag distance exceeds threshold
                if (dragDistX > boxDragMinDistance || dragDistY > boxDragMinDistance) {
                    isDragging := true
                }
            }

        case WM_LBUTTONUP:
            if (isDragging) {
                ; Create bounding box event
                left := Min(dragStartX, cursorX)
                top := Min(dragStartY, cursorY)
                right := Max(dragStartX, cursorX)
                bottom := Max(dragStartY, cursorY)

                boxEvent := {
                    type: "boundingBox",
                    left: left,
                    top: top,
                    right: right,
                    bottom: bottom,
                    time: A_TickCount,
                    isFirstBox: (boxCount = 0),
                    timeSincePrevious: (boxCount > 0) ? (A_TickCount - prevBoxTime) : 0,
                    degradationType: 0  ; Default, assigned later
                }

                events.Push(boxEvent)
                boxCount++
                prevBoxTime := A_TickCount
            }
    }
}
```

**Keyboard Events:**
```ahk
KeyboardProc(nCode, wParam, lParam) {
    if (nCode < 0) return CallNextHookEx(0, nCode, wParam, lParam)

    vkCode := NumGet(lParam, 0, "UInt")

    switch wParam {
        case WM_KEYDOWN:
            ; Detect number keys 1-9 for degradation assignment
            if (vkCode >= 0x31 && vkCode <= 0x39) {
                degradationType := vkCode - 0x30  ; Convert to 1-9

                keyEvent := {
                    type: "keyDown",
                    key: degradationType,
                    time: A_TickCount
                }

                events.Push(keyEvent)
            }

        case WM_KEYUP:
            if (vkCode >= 0x31 && vkCode <= 0x39) {
                degradationType := vkCode - 0x30

                keyEvent := {
                    type: "keyUp",
                    key: degradationType,
                    time: A_TickCount
                }

                events.Push(keyEvent)
            }
    }
}
```

**C. Stop Recording:**
```
1. Unhook mouse and keyboard:
   UnhookWindowsHookEx(MouseHook)
   UnhookWindowsHookEx(KeyboardHook)

2. Analyze recorded macro:
   AnalyzeRecordedMacro()
   - Calls AnalyzeDegradationPattern()
   - Assigns degradationTypes to boxes

3. Enter assignment mode:
   awaitingAssignment := true
   statusText.Value := "Press a button to assign macro..."

4. Update GUI:
   recordButton.Text := "● Record Macro"
```

---

#### 4. Degradation Analysis (lines 6176-6331)
**Purpose:** Match keypresses to bounding boxes and assign degradation types.

**Function: `AnalyzeDegradationPattern(events)`**

**Algorithm:**
```
1. Extract all boundingBox and keyDown events:
   boxes := []
   keypresses := []

   for event in events {
       if (event.type = "boundingBox") {
           boxes.Push(event)
       }
       else if (event.type = "keyDown") {
           keypresses.Push(event)
       }
   }

2. For each box, determine next box time:
   for i, box in boxes {
       nextBoxTime := (i < boxes.Length) ? boxes[i+1].time : 999999999

       ; Find keypress in window [box.time, nextBoxTime)
       matchedKey := 0
       for keyPress in keypresses {
           if (keyPress.time >= box.time && keyPress.time < nextBoxTime) {
               matchedKey := keyPress.key
               break
           }
       }

       if (matchedKey != 0) {
           box.degradationType := matchedKey
           box.assignmentMethod := "user_selection"
       }
       else {
           ; Auto-assign: inherit from previous box
           box.degradationType := (i > 1) ? boxes[i-1].degradationType : 0
           box.assignmentMethod := "auto_default"
       }
   }

3. Generate summary:
   degradationSummary := ""
   for box in boxes {
       degradationSummary .= GetDegradationName(box.degradationType) . ","
   }
   degradationSummary := RTrim(degradationSummary, ",")

4. Log to vizlog_debug.txt:
   "Box #1: time=86085125 nextBoxTime=86085671"
   "  MATCHED keyPress deg=1 at time=86085296"
   "  ASSIGNED deg=1 (user_selection)"
```

**Assignment Methods:**
- **user_selection:** Keypress detected in time window
- **auto_default:** No keypress → inherits previous type

---

#### 5. Playback Engine (lines 3686-3785)
**Purpose:** Execute recorded macros with optimized timing and browser focus.

**Function: `PlayEventsOptimized(events)`**

**Flow:**
```
1. Set playback flag:
   playback := true

2. Focus browser:
   FocusBrowser()  ; Finds Chrome, Firefox, or Edge window

3. Extract bounding boxes:
   boxes := []
   for event in events {
       if (event.type = "boundingBox") {
           boxes.Push(event)
       }
   }

4. Play each box:
   for i, box in boxes {
       ; Move to start position
       MouseMove(box.left, box.top, 2)
       Sleep(smartBoxClickDelay)

       ; Press left button
       Click("down")
       Sleep(mouseClickDelay)

       ; Drag to end position
       MouseMove(box.right, box.bottom, 8)
       Sleep(mouseDragDelay)

       ; Release left button
       Click("up")
       Sleep(mouseReleaseDelay)

       ; Wait before next box
       if (box.isFirstBox) {
           Sleep(firstBoxDelay)  ; 180ms for UI stabilization
       } else {
           Sleep(betweenBoxDelay)  ; 120ms between boxes
       }
   }

5. Clear playback flag:
   playback := false
```

**Timing Values (from config.ini):**
```ini
[Timing]
smartBoxClickDelay=45      ; Cursor positioning
mouseClickDelay=75         ; Button press
mouseDragDelay=50          ; During drag
mouseReleaseDelay=75       ; After release
betweenBoxDelay=120        ; Between boxes
firstBoxDelay=180          ; First box (UI stabilization)
```

**First Box Special Handling:**
- Extra delay (180ms vs 120ms)
- Allows UI to stabilize after focus change
- Detected via `isFirstBox` property

---

#### 6. JSON Annotation Execution
**Purpose:** Execute single-selection annotations with severity levels.

**Function: `ExecuteJsonAnnotation(events)`**

**Flow:**
```
1. Extract JSON event:
   jsonEvent := events[1]  ; First event is jsonAnnotation type

2. Extract properties:
   categoryId := jsonEvent.categoryId       ; 1-9 (degradation type)
   severity := jsonEvent.severity           ; "high" | "medium" | "low"
   annotation := jsonEvent.annotation       ; Text comment

3. Focus browser:
   FocusBrowser()

4. Copy annotation to clipboard:
   A_Clipboard := annotation
   Sleep(50)

5. Paste:
   Send("^v")  ; Ctrl+V
   Sleep(100)

6. Submit:
   Send("+{Enter}")  ; Shift+Enter
   Sleep(100)

7. Record stats:
   RecordExecutionStatsAsync({
       events: events,
       execType: "json_profile",
       degradationType: categoryId,
       severity: severity,
       ...
   })
```

---

### Intelligent Timing System

**Purpose:** Optimized delays for reliable macro playback across different system speeds.

**Unique Timing Values (lines 405-412):**

| Timing Variable | Default (ms) | Purpose |
|----------------|--------------|---------|
| `boxDrawDelay` | 50 | Box drawing operation |
| `mouseClickDelay` | 75 | Mouse button press duration |
| `mouseDragDelay` | 50 | During drag operation |
| `mouseReleaseDelay` | 75 | After mouse release |
| `betweenBoxDelay` | 120 | Between subsequent boxes |
| `keyPressDelay` | 12 | Keyboard input duration |
| `focusDelay` | 60 | Window activation delay |
| `smartBoxClickDelay` | 45 | Cursor positioning delay |
| `smartMenuClickDelay` | 100 | Menu interaction delay |
| `firstBoxDelay` | 180 | First box UI stabilization |
| `menuWaitDelay` | 50 | Menu popup delay |
| `mouseHoverDelay` | 30 | Hover detection delay |

**Tuning Guidelines:**
- **Faster System:** Reduce delays by 10-20%
- **Slower System:** Increase delays by 20-30%
- **Network Latency:** Increase `firstBoxDelay` significantly
- **UI Heavy Apps:** Increase `betweenBoxDelay`

---

### Assignment Mode System

**Purpose:** Allow user to assign recorded macro to any button.

**Flow:**
```
╔════════════════════════════════════════════════════════════════╗
║                    ASSIGNMENT MODE FLOW                         ║
╚════════════════════════════════════════════════════════════════╝

┌──────────────────┐
│ Recording Stops  │
└────────┬─────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ AnalyzeRecordedMacro()               │
│ - Assigns degradationTypes           │
│ - Generates summary                  │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ awaitingAssignment = true            │
│ statusText = "Press button..."       │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ User Presses Button (Num1-Num9)      │
│ - SafeExecuteMacroByKey(buttonName)  │
│ - Detects awaitingAssignment         │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ AssignToButton(buttonName)           │
│ - Copy events to button macro        │
│ - Copy recordedMode & recordedCanvas │
│ - Save to config_simple.txt          │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ UpdateButtonAppearance(buttonName)   │
│ - Create visualization (HBITMAP)     │
│ - Update button thumbnail            │
└────────┬─────────────────────────────┘
         │
         ▼
┌──────────────────────────────────────┐
│ awaitingAssignment = false           │
│ statusText = "Macro assigned!"       │
└──────────────────────────────────────┘
```

---

### Data Flow

```
╔════════════════════════════════════════════════════════════════╗
║                    EXECUTION DATA FLOW                          ║
╚════════════════════════════════════════════════════════════════╝

=== RECORDING ===

User: CapsLock+F
         │
         ▼
F9_RecordingOnly() → Install Hooks (Mouse + Keyboard)
         │
         ▼
User: Draws Boxes + Presses Number Keys
         │
         ▼
MouseProc/KeyboardProc → Event Stream
         │
         ├─ mouseDown → dragStartX, dragStartY
         ├─ mouseMove → Check drag distance
         ├─ mouseUp → Create boundingBox event
         ├─ keyDown → Create keyDown event (degradation type)
         └─ keyUp → Create keyUp event
         │
         ▼
Recording Complete → AnalyzeRecordedMacro()
         │
         ▼
AnalyzeDegradationPattern()
         │
         ├─ Match keypresses to boxes by timestamp
         ├─ Assign degradationType to each box
         └─ Set assignmentMethod (user_selection | auto_default)
         │
         ▼
User: Presses Button (Num1-Num9) → AssignToButton()
         │
         ├─ Copy events to macroEvents[L1_buttonName]
         ├─ Copy recordedMode & recordedCanvas
         └─ Save to config_simple.txt
         │
         ▼
UpdateButtonAppearance()
         │
         ├─ ExtractBoxEvents()
         ├─ CreateHBITMAPVisualization()
         └─ Display thumbnail in button
         │
         ▼
SaveConfig() → config_simple.txt persisted

=== EXECUTION ===

User: Presses Macro Button (Num1-Num9)
         │
         ▼
SafeExecuteMacroByKey(buttonName)
         │
         ├─ Validate: Not recording, not in break mode
         └─ Call ExecuteMacro(buttonName)
         │
         ▼
Load Events: macroEvents[L1_buttonName]
         │
         ▼
Detect Type: events[1].type
    │
    ├──────────────────┬─────────────────┐
    │                  │                 │
    ▼                  ▼                 ▼
"boundingBox"   "jsonAnnotation"    "click"
    │                  │                 │
    ▼                  ▼                 ▼
PlayEventsOptimized  ExecuteJsonAnnotation  (ignored)
    │                  │
    ├─ FocusBrowser()  ├─ FocusBrowser()
    ├─ For each box:   ├─ Copy annotation
    │  • MouseMove     ├─ Paste (Ctrl+V)
    │  • Click down    └─ Submit (Shift+Enter)
    │  • Drag
    │  • Click up
    │  • Sleep (delay)
    │
    └───────────────────┴──────────────────┐
                                           │
                                           ▼
                          RecordExecutionStatsAsync()
                                           │
                                           ├─ SetTimer (50ms delay)
                                           │
                                           ▼
                          DoRecordExecutionStatsBlocking()
                                           │
                                           ▼
                          RecordExecutionStats()
                                           │
                                           ├─ Count degradations
                                           ├─ Build executionData map
                                           ├─ AppendToCSV (display + permanent)
                                           ├─ macroExecutionLog.Push()
                                           ├─ InvalidateTodayStatsCache()
                                           └─ SaveStatsToJson()
                                           │
                                           ▼
                          Stats GUI Auto-Refresh (500ms timer)
```

---

### Integration Points

**With Visualization System:**
- **Recording:** Captures `recordedMode` and `recordedCanvas`
- **Assignment:** Copies canvas properties to button macros
- **Playback:** Uses original canvas for accurate coordinates

**With Stats System:**
- **Trigger:** RecordExecutionStatsAsync() called after execution
- **Data:** Execution time, box count, degradations, canvas mode
- **Timing:** Measured from playback start to finish

**With GUI System:**
- **Button Assignment:** UpdateButtonAppearance() displays thumbnail
- **Status Updates:** Recording state shown in status text
- **Layer Management:** Macros stored per layer (L1, L2, L3...)

**With Config System:**
- **Macro Persistence:** Saved to config_simple.txt
- **Timing Config:** Read from config.ini [Timing] section
- **Hotkey Config:** Recording hotkey from config.ini [Hotkeys]

---

### Recent Enhancements

1. **Degradation Analysis Logging:**
   ```
   [vizlog_debug.txt]
   Box #1: time=86085125 nextBoxTime=86085671
     MATCHED keyPress deg=1 at time=86085296
     ASSIGNED deg=1 (user_selection)

   Box #2: time=86085671 nextBoxTime=86086093
     No keyPress found
     ASSIGNED deg=1 (auto_default, inherited from previous)

   PRE-SAVE CHECK:
   Box 1: degradationType = 1
   Box 2: degradationType = 1
   ```

2. **Canvas Mode Capture:**
   ```
   During Recording:
   - SET recordedMode for temp_recording_20251111181400
   - SET recordedCanvas {left:428, top:196, right:1363, bottom:998, mode:"Narrow"}

   During Assignment:
   - COPIED recordedMode to L1_Num7
   - COPIED recordedCanvas to L1_Num7
   ```

3. **Safety Mechanisms:**
   - Double-check hotkey blocking in SafeExecuteMacroByKey()
   - State validation (breakMode, recording, playback checks)
   - Focus verification before execution

4. **Pre-Save Verification:**
   - Logs all box degradationTypes before saving to config
   - Ensures no data loss during assignment
   - Debug trace for troubleshooting

---

## System Interactions

### Recording → Visualization → Stats Flow

```
┌────────────────────────────────────────────────────────────────┐
│                    INTEGRATED WORKFLOW                          │
└────────────────────────────────────────────────────────────────┘

1. User Records Macro (Execution System)
   ├─ Canvas mode captured: annotationMode = "Narrow"
   ├─ Canvas coords captured: narrowCanvas object
   └─ Events stream: boundingBox + keyDown/keyUp

2. Degradation Analysis (Execution System)
   ├─ Match keypresses to boxes
   ├─ Assign degradationTypes (1-9)
   └─ Generate summary: "smudge,glare,splashes"

3. Button Assignment (Execution System)
   ├─ Copy events to button macro
   ├─ Copy recordedMode & recordedCanvas
   └─ Save to config_simple.txt

4. Button Visualization (Visualization System)
   ├─ ExtractBoxEvents() → reads degradationTypes
   ├─ CreateHBITMAPVisualization() → cache check
   ├─ DrawMacroBoxesOnButton() → color-code boxes
   └─ Display thumbnail in GUI

5. Macro Execution (Execution System)
   ├─ Load events from macroEvents[L1_buttonName]
   ├─ PlayEventsOptimized() → simulate mouse/keyboard
   └─ Measure execution time

6. Stats Recording (Stats System)
   ├─ Count degradations from events
   ├─ Extract canvas mode, box count, timing
   ├─ Append to display & permanent CSVs
   ├─ Update in-memory log
   ├─ Invalidate today cache
   └─ Save to stats_log.json

7. GUI Update (Stats System)
   ├─ 500ms refresh timer
   ├─ GetUnifiedStats("today") → cache + live delta
   ├─ Calculate rates (boxes/hour, exec/hour)
   └─ Update all GUI controls
```

---

### Canvas Mode Change → Visualization Refresh Flow

```
1. User Toggles Mode (Visualization System)
   ├─ ToggleAnnotationMode() called
   ├─ annotationMode: "Wide" ↔ "Narrow"
   ├─ Button text updated
   └─ VizLog records change

2. Mode State Updated (Visualization System)
   ├─ Saved to config.ini [General] AnnotationMode
   └─ Global variable annotationMode updated

3. Future Recordings Affected
   ├─ New recordings use new mode
   ├─ recordedCanvas uses appropriate calibration
   └─ recordedMode stored on events

4. Existing Macros Unchanged
   ├─ Each macro retains its own recordedMode
   ├─ Visualization respects original canvas
   └─ Playback uses original coordinates
```

---

## Critical Implementation Details

### 1. HBITMAP Memory Management

**Problem:** Memory leaks if HBITMAPs not properly deleted.

**Solution:**
```ahk
; Global reference counting maps
hbitmapCache := Map()           ; cacheKey → HBITMAP
hbitmapRefCounts := Map()       ; HBITMAP → refCount

; Adding reference
AddHBITMAPReference(hbitmap) {
    if (!hbitmapRefCounts.Has(hbitmap)) {
        hbitmapRefCounts[hbitmap] := 0
    }
    hbitmapRefCounts[hbitmap]++
}

; Removing reference
RemoveHBITMAPReference(hbitmap) {
    if (!hbitmapRefCounts.Has(hbitmap)) return

    hbitmapRefCounts[hbitmap]--

    if (hbitmapRefCounts[hbitmap] <= 0) {
        ; Last reference gone → free resource
        DllCall("DeleteObject", "Ptr", hbitmap)
        hbitmapRefCounts.Delete(hbitmap)
    }
}

; Validation before use
IsHBITMAPValid(hbitmap) {
    if (!hbitmap) return false

    ; Check if Windows handle is valid
    result := DllCall("GetObject", "Ptr", hbitmap, "Int", 0, "Ptr", 0)
    return (result > 0)
}
```

**Usage Pattern:**
```ahk
; Get or create HBITMAP
hbitmap := CreateHBITMAPVisualization(events, width, height, canvas)
AddHBITMAPReference(hbitmap)

; Display in GUI
pictureControl.Value := hbitmap

; When done
RemoveHBITMAPReference(hbitmap)
```

---

### 2. Async Stats Recording

**Problem:** CSV file I/O blocks UI thread, causing lag during execution.

**Solution:**
```ahk
RecordExecutionStatsAsync(params) {
    ; Quick validation (non-blocking)
    if (breakMode || recording || playback) {
        return
    }

    ; Schedule delayed execution
    SetTimer(() => DoRecordExecutionStatsBlocking(params), -50)
}

DoRecordExecutionStatsBlocking(params) {
    ; Actual I/O happens here (off UI thread via timer)
    RecordExecutionStats(
        params.events,
        params.buttonKey,
        params.layer,
        params.execType
    )
}
```

**Benefits:**
- UI remains responsive during stats recording
- No perceived lag after macro execution
- File I/O happens "in background" (via timer)

---

### 3. Canvas Calibration Persistence

**Problem:** Lose calibration on app restart.

**Solution:**
```ini
[Canvas]
wideCanvasLeft=26.00
wideCanvasTop=193.00
wideCanvasRight=1652.00
wideCanvasBottom=999.00
isWideCanvasCalibrated=1

narrowCanvasLeft=428.00
narrowCanvasTop=196.00
narrowCanvasRight=1363.00
narrowCanvasBottom=998.00
isNarrowCanvasCalibrated=1
```

**Load on Startup:**
```ahk
LoadConfig() {
    wideCanvas := {
        left: IniRead("config.ini", "Canvas", "wideCanvasLeft", 0),
        top: IniRead("config.ini", "Canvas", "wideCanvasTop", 0),
        right: IniRead("config.ini", "Canvas", "wideCanvasRight", 0),
        bottom: IniRead("config.ini", "Canvas", "wideCanvasBottom", 0),
        mode: "Wide"
    }

    ; Same for narrowCanvas...

    isWideCanvasCalibrated := IniRead("config.ini", "Canvas", "isWideCanvasCalibrated", 0)
}
```

---

### 4. Today Stats Cache Invalidation

**Problem:** Stale cache shows old data after new executions.

**Solution:**
```ahk
; Cache structure
todayStatsCache := {
    date: "",
    totalExecutions: 0,
    totalBoxes: 0,
    activeTimeMs: 0,
    degradations: {...},
    ...
}

; Invalidation flag
todayStatsCacheInvalidated := true

; Invalidation function
InvalidateTodayStatsCache() {
    global todayStatsCacheInvalidated := true
}

; Usage in GetUnifiedStats()
GetUnifiedStats(filter := "all") {
    if (filter = "today") {
        currentDate := FormatTime(A_Now, "yyyy-MM-dd")

        if (todayStatsCache.date != currentDate || todayStatsCacheInvalidated) {
            ; Rebuild cache
            todayStatsCache := CalculateTodayStats()
            todayStatsCache.date := currentDate
            todayStatsCacheInvalidated := false
        }

        ; Add live delta for current session
        if (currentSessionId != "") {
            liveActiveTimeMs := A_TickCount - sessionStartTime - totalBreakTime
            todayStatsCache.activeTimeMs += liveActiveTimeMs
        }

        return todayStatsCache
    }
}
```

**Invalidation Triggers:**
- New execution recorded
- Date change detected (midnight rollover)
- Stats reset
- Manual refresh

---

### 5. DPI Scaling Fix

**Problem:** Boxes misaligned on high-DPI displays (150%, 200% scaling).

**Solution:**
```ahk
; Get DPI scale factor
screenScale := A_ScreenDPI / 96.0  ; 96 DPI = 100% scaling

; Convert physical pixels to logical coordinates
canvasLeftLogical := canvasLeft / screenScale
canvasTopLogical := canvasTop / screenScale
canvasRightLogical := canvasRight / screenScale
canvasBottomLogical := canvasBottom / screenScale

; All calculations use logical coordinates
canvasWidth := canvasRightLogical - canvasLeftLogical
canvasHeight := canvasBottomLogical - canvasTopLogical

; Box coordinates also converted
boxLeftLogical := boxLeft / screenScale
boxTopLogical := boxTop / screenScale
boxRightLogical := boxRight / screenScale
boxBottomLogical := boxBottom / screenScale
```

**Effect:** Boxes align perfectly at any DPI setting.

---

### 6. Box Drag Distance Threshold

**Problem:** Small mouse movements create unwanted box events.

**Solution:**
```ahk
boxDragMinDistance := 10  ; pixels

; In MouseProc (WM_MOUSEMOVE)
dragDistX := Abs(cursorX - dragStartX)
dragDistY := Abs(cursorY - dragStartY)

if (dragDistX > boxDragMinDistance || dragDistY > boxDragMinDistance) {
    isDragging := true
}

; In MouseProc (WM_LBUTTONUP)
if (isDragging) {
    ; Create boundingBox event
} else {
    ; Treat as click (ignored)
}
```

**Benefit:** Prevents accidental boxes from tiny drags.

---

### 7. First Box Delay

**Problem:** First box sometimes fails due to UI not fully ready.

**Solution:**
```ahk
; Mark first box during recording
boxEvent := {
    type: "boundingBox",
    isFirstBox: (boxCount = 0),
    ...
}

; During playback
for i, box in boxes {
    ; ... draw box ...

    if (box.isFirstBox) {
        Sleep(firstBoxDelay)  ; 180ms
    } else {
        Sleep(betweenBoxDelay)  ; 120ms
    }
}
```

**Values:**
- `firstBoxDelay`: 180ms (UI stabilization)
- `betweenBoxDelay`: 120ms (subsequent boxes)

---

## Recent Refinements

### Visualization System

1. **Enhanced Debug Logging (vizlog_debug.txt):**
   - Coordinate logging for all boxes
   - Cache hit/miss tracking
   - HBITMAP creation status
   - Canvas mode verification
   - Letterboxing calculations

2. **Canvas Persistence:**
   - `recordedMode` property on events
   - `recordedCanvas` object with {left, top, right, bottom, mode}
   - Ensures playback uses original canvas
   - Prevents misalignment when mode changes

3. **Memory Management:**
   - Reference counting system (hbitmapRefCounts)
   - Proper cleanup on cache invalidation
   - IsHBITMAPValid() validation before use
   - No memory leaks in testing

---

### Stats System

1. **Live Time Display:**
   - Current session delta calculated on-the-fly
   - Formula: `cachedTime + (A_TickCount - sessionStart - breakTime)`
   - No lag in GUI updates
   - Accurate to-the-second tracking

2. **Cache Optimization:**
   - Today stats cached for performance
   - Smart invalidation on new executions
   - Live recalculation for rates (boxes/hour, exec/hour)
   - 500ms refresh timer for GUI

3. **Async Recording:**
   - Non-blocking CSV writes
   - Timer-based delayed execution (50ms)
   - Prevents UI freeze during I/O
   - macroExecutionLog updated immediately

4. **Degradation Summary:**
   - `degradation_assignments` field in CSV
   - Comma-separated list: "smudge,glare,splashes,partial_blockage"
   - Enables quick pattern recognition
   - Used in stats analysis

---

### Execution System

1. **Degradation Analysis Logging:**
   - Detailed vizlog output for debugging
   - Pre-save verification (PRE-SAVE CHECK)
   - Assignment method tracking (user_selection vs auto_default)
   - Timestamp-based keypress matching

2. **Canvas Mode Capture:**
   ```
   During Recording:
   - SET recordedMode for temp_recording
   - SET recordedCanvas with coordinates

   During Assignment:
   - COPIED recordedMode to button macro
   - COPIED recordedCanvas to button macro
   ```

3. **Safety Mechanisms:**
   - Double-check hotkey blocking in SafeExecuteMacroByKey()
   - State validation (breakMode, recording, playback checks)
   - Focus verification before execution
   - Drag distance threshold (boxDragMinDistance)

4. **Pre-Save Verification:**
   - Logs all box degradationTypes before saving
   - Ensures no data loss during assignment
   - Debug trace for troubleshooting
   - Example:
     ```
     PRE-SAVE CHECK:
     Box 1: degradationType = 1
     Box 2: degradationType = 2
     Box 3: degradationType = 3
     ```

---

## Backup and Restore

### Critical Files to Backup

**Essential (Required for full restore):**
1. `config.ini` - All settings and canvas calibration
2. `config_simple.txt` - All recorded macros
3. `data/master_stats_permanent.csv` - Historical stats
4. `data/stats_log.backup.json` - Stats backup

**Optional (Can be regenerated):**
- `data/macro_execution_stats.csv` - Display stats (can reset)
- `data/stats_log.json` - Runtime stats (auto-saved)
- `vizlog_debug.txt` - Debug log (auto-generated)

### Backup Procedure

**Option 1: Full Directory Copy**
```
Copy entire "Mono10 - Copy" folder to backup location
Example: Mono10_Backup_20251111_1814
```

**Option 2: Selective File Backup**
```
Create backup folder with structure:
backup_20251111_1814/
  ├─ config.ini
  ├─ config_simple.txt
  └─ data/
      ├─ master_stats_permanent.csv
      └─ stats_log.backup.json
```

### Restore Procedure

**From Full Directory Copy:**
```
1. Close MacroMonoo.ahk
2. Replace entire working directory with backup folder
3. Restart MacroMonoo.ahk
4. Verify canvas calibration
5. Test macro execution
```

**From Selective File Backup:**
```
1. Close MacroMonoo.ahk
2. Replace config.ini
3. Replace config_simple.txt
4. Replace data/master_stats_permanent.csv
5. Replace data/stats_log.backup.json (optional)
6. Restart MacroMonoo.ahk
7. Stats display will repopulate from permanent CSV
```

---

## Configuration Snapshot

### Current Configuration (config.ini)

```ini
[General]
CurrentLayer=1
AnnotationMode=Narrow
LastSaved=20251111181600

[Labels]
; Custom button labels (currently empty)

[Canvas]
wideCanvasLeft=26.00
wideCanvasTop=193.00
wideCanvasRight=1652.00
wideCanvasBottom=999.00
isWideCanvasCalibrated=1

narrowCanvasLeft=428.00
narrowCanvasTop=196.00
narrowCanvasRight=1363.00
narrowCanvasBottom=998.00
isNarrowCanvasCalibrated=1

[Timing]
boxDrawDelay=50
mouseClickDelay=75
mouseDragDelay=50
mouseReleaseDelay=75
betweenBoxDelay=120
keyPressDelay=12
focusDelay=60
smartBoxClickDelay=45
smartMenuClickDelay=100
firstBoxDelay=180
menuWaitDelay=50
mouseHoverDelay=30

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

[Macros]
; Macros stored in config_simple.txt

[Debug]
; Debug settings (currently empty)
```

### Current Macro Format (config_simple.txt)

```
L1_Num7=recordedMode,Narrow
L1_Num7=recordedCanvas,428.00,196.00,1363.00,998.00,mode=Narrow
L1_Num7=boundingBox,559,289,634,457,time=86085125,deg=1,isFirstBox=1
L1_Num7=keyDown,1,time=86085296
L1_Num7=keyUp,1,time=86085400
L1_Num7=boundingBox,760,315,829,539,time=86085671,deg=2,isFirstBox=0
L1_Num7=keyDown,2,time=86085703
L1_Num7=keyUp,2,time=86085800
```

---

## Restore Point Summary

**Date:** 2025-11-11
**Status:** MAJOR RESTORE POINT
**Stability:** All Three Systems Working Almost Flawlessly

**Verified Working:**
✓ Visualization System - HBITMAP caching, dual canvas modes, degradation color coding
✓ Stats System - Execution tracking, time tracking, live GUI updates, dual CSV storage
✓ Execution System - Recording, degradation analysis, macro/JSON playback, timing optimization

**Recent Fixes:**
✓ Live time calculation with delta
✓ Canvas mode persistence on events
✓ Degradation analysis with auto-assignment
✓ Async stats recording (non-blocking)
✓ HBITMAP reference counting
✓ Today stats caching with invalidation
✓ Pre-save verification logging

**Total Code:** 6,627 lines
**Configuration:** Fully calibrated (Wide + Narrow modes)
**Data Integrity:** Dual CSV system (display + permanent archive)

---

**END OF SYSTEM ARCHITECTURE DOCUMENTATION**
