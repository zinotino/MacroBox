# API Reference - MacroMonoo
**Version:** Stable Build (2025-11-11)
**Language:** AutoHotkey v2.0

---

## Table of Contents
- [Core Functions](#core-functions)
  - [Visualization API](#visualization-api)
  - [Stats API](#stats-api)
  - [Execution API](#execution-api)
- [Data Structures](#data-structures)
- [Configuration API](#configuration-api)
- [Constants and Enums](#constants-and-enums)

---

## Core Functions

### Visualization API

#### `InitializeGDIPlus()`
Initialize Windows GDI+ graphics library.

**Returns:** `Integer` - GDI+ startup token (used for shutdown)

**Usage:**
```ahk
global gdiplusToken := InitializeGDIPlus()

; On exit:
DllCall("gdiplus\GdiplusShutdown", "Ptr", gdiplusToken)
```

**Side Effects:**
- Loads GDI+ DLL
- Initializes graphics subsystem
- Required before any GDI+ operations

**Error Handling:**
- Returns 0 on failure
- Check token validity before use

---

#### `CreateHBITMAPVisualization(events, buttonWidth, buttonHeight, canvasObj)`
Convert macro events into a visual thumbnail HBITMAP.

**Parameters:**
- `events` (Array) - Macro event array (from macroEvents map)
- `buttonWidth` (Integer) - Target thumbnail width in pixels
- `buttonHeight` (Integer) - Target thumbnail height in pixels
- `canvasObj` (Object) - Canvas bounds object (see [Canvas Object](#canvas-object))

**Returns:** `Ptr` - HBITMAP handle (Windows bitmap)

**Algorithm:**
1. Extract boundingBox events with degradation types
2. Generate cache key: `"{boxes}|{width}x{height}_{mode}"`
3. Check cache → return if hit (with ref count++)
4. On cache miss:
   - Create GDI+ bitmap (buttonWidth × buttonHeight)
   - Fill white background
   - Draw boxes with degradation colors
   - Convert to HBITMAP
   - Store in cache (ref count = 1)
5. Return HBITMAP

**Usage:**
```ahk
events := macroEvents["L1_Num7"]
canvas := {left: 428, top: 196, right: 1363, bottom: 998, mode: "Narrow"}
hbitmap := CreateHBITMAPVisualization(events, 392, 153, canvas)

; Display in GUI
pictureControl.Value := hbitmap

; When done
RemoveHBITMAPReference(hbitmap)
```

**Cache Key Example:**
```
"559,289,634,457|760,315,829,539|392x153_Narrow"
```

**Notes:**
- Pure in-memory operation (zero file I/O)
- Thread-safe via cache key uniqueness
- Automatically handles letterboxing for Narrow mode

---

#### `DrawMacroBoxesOnButton(graphics, events, buttonWidth, buttonHeight, canvasObj)`
Render bounding boxes on a GDI+ graphics object.

**Parameters:**
- `graphics` (Ptr) - GDI+ graphics object handle
- `events` (Array) - Macro event array
- `buttonWidth` (Integer) - Thumbnail width
- `buttonHeight` (Integer) - Thumbnail height
- `canvasObj` (Object) - Canvas bounds object

**Returns:** `None` (modifies graphics object in place)

**Algorithm:**
1. Extract boundingBox events
2. Calculate canvas dimensions
3. If Narrow mode:
   - Calculate 16:9 viewport within 4:3 canvas
   - Draw gray letterbox bars
4. For each box:
   - Normalize coordinates to canvas space
   - Clip to [0, 1] range
   - Scale to button dimensions
   - Draw colored rectangle (degradation color)

**Usage:**
```ahk
graphics := CreateGdipGraphics(hbitmap)
DrawMacroBoxesOnButton(graphics, events, 392, 153, canvas)
DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
```

**Coordinate Transformation:**
```
Screen Coords → Canvas Coords → Normalized Coords → Button Coords

Box: (559, 289, 634, 457)
Canvas: (428, 196, 1363, 998)

Normalized:
  x1 = (559 - 428) / (1363 - 428) = 0.140
  y1 = (289 - 196) / (998 - 196) = 0.116

Button (392x153):
  x1 = 0.140 * 392 = 54.88
  y1 = 0.116 * 153 = 17.75
```

---

#### `CreateJsonAnnotationVisual(categoryId, buttonWidth, buttonHeight, canvasMode)`
Create visual indicator for JSON profile annotation.

**Parameters:**
- `categoryId` (Integer) - Degradation type (1-9)
- `buttonWidth` (Integer) - Thumbnail width
- `buttonHeight` (Integer) - Thumbnail height
- `canvasMode` (String) - "Wide" or "Narrow"

**Returns:** `Ptr` - HBITMAP handle

**Visual Design:**
- Solid colored rectangle (degradation color)
- Letterboxing in Narrow mode (gray bars)
- Category name as centered text

**Usage:**
```ahk
; Glare annotation in Narrow mode
hbitmap := CreateJsonAnnotationVisual(2, 392, 153, "Narrow")
pictureControl.Value := hbitmap
```

---

#### `ExtractBoxEvents(events)`
Filter macro events to extract only boundingBox events.

**Parameters:**
- `events` (Array) - Full macro event array

**Returns:** `Array` - Filtered array containing only boundingBox events

**Usage:**
```ahk
allEvents := macroEvents["L1_Num7"]
boxes := ExtractBoxEvents(allEvents)

for box in boxes {
    MsgBox("Box: " box.left "," box.top " → " box.right "," box.bottom)
}
```

---

#### `GetDegradationColor(degradationType)`
Get ARGB color value for degradation type.

**Parameters:**
- `degradationType` (Integer) - Degradation type (0-9)

**Returns:** `Integer` - ARGB color value (0xAARRGGBB)

**Color Mapping:**
```ahk
1 → 0xFFFFD700  ; Smudge (Gold)
2 → 0xFF87CEEB  ; Glare (Sky Blue)
3 → 0xFF90EE90  ; Splashes (Light Green)
4 → 0xFFFFA500  ; Partial Blockage (Orange)
5 → 0xFFFF4500  ; Full Blockage (Red-Orange)
6 → 0xFFFFFF00  ; Light Flare (Yellow)
7 → 0xFF4682B4  ; Rain (Steel Blue)
8 → 0xFFD3D3D3  ; Haze (Light Gray)
9 → 0xFFF0F8FF  ; Snow (Alice Blue)
0 → 0xFF808080  ; Clear (Gray, default)
```

**Usage:**
```ahk
glareColor := GetDegradationColor(2)  ; 0xFF87CEEB
```

---

#### `AddHBITMAPReference(hbitmap)`
Increment reference count for HBITMAP.

**Parameters:**
- `hbitmap` (Ptr) - HBITMAP handle

**Returns:** `None`

**Side Effects:**
- Increments hbitmapRefCounts[hbitmap]
- Prevents premature deletion

**Usage:**
```ahk
hbitmap := CreateHBITMAPVisualization(...)
AddHBITMAPReference(hbitmap)  ; refCount = 1

; Use in multiple places
pictureControl1.Value := hbitmap
AddHBITMAPReference(hbitmap)  ; refCount = 2
```

---

#### `RemoveHBITMAPReference(hbitmap)`
Decrement reference count and free if zero.

**Parameters:**
- `hbitmap` (Ptr) - HBITMAP handle

**Returns:** `None`

**Side Effects:**
- Decrements hbitmapRefCounts[hbitmap]
- If refCount reaches 0:
  - Calls DeleteObject to free Windows resource
  - Removes from hbitmapRefCounts map

**Usage:**
```ahk
RemoveHBITMAPReference(hbitmap)  ; refCount = 1
RemoveHBITMAPReference(hbitmap)  ; refCount = 0 → freed
```

---

#### `IsHBITMAPValid(hbitmap)`
Validate HBITMAP handle.

**Parameters:**
- `hbitmap` (Ptr) - HBITMAP handle

**Returns:** `Boolean` - True if valid, false otherwise

**Validation:**
```ahk
if (!hbitmap) return false

result := DllCall("GetObject", "Ptr", hbitmap, "Int", 0, "Ptr", 0)
return (result > 0)
```

**Usage:**
```ahk
if (IsHBITMAPValid(hbitmap)) {
    pictureControl.Value := hbitmap
} else {
    MsgBox("Invalid HBITMAP")
}
```

---

#### `InvalidateVisualizationCache(buttonName := "")`
Clear cached HBITMAPs for a button or all buttons.

**Parameters:**
- `buttonName` (String, optional) - Button to invalidate (e.g., "Num7"). If empty, clears all.

**Returns:** `None`

**Side Effects:**
- Removes cache entries from hbitmapCache
- Calls RemoveHBITMAPReference for each HBITMAP
- Forces re-rendering on next display

**Usage:**
```ahk
; Invalidate single button
InvalidateVisualizationCache("Num7")

; Invalidate all
InvalidateVisualizationCache()
```

---

### Stats API

#### `RecordExecutionStatsAsync(params)`
Record execution statistics asynchronously (non-blocking).

**Parameters:**
- `params` (Object) - Parameter map containing:
  - `events` (Array) - Macro event array
  - `buttonKey` (String) - Button name (e.g., "Num7")
  - `layer` (Integer) - Layer number (1-3)
  - `execType` (String) - "macro" | "json_profile" | "clear"
  - `executionTimeMs` (Integer) - Playback duration in milliseconds

**Returns:** `None`

**Algorithm:**
1. Quick validation (break mode, recording state)
2. Schedule delayed execution via SetTimer (50ms)
3. Returns immediately (non-blocking)

**Usage:**
```ahk
startTime := A_TickCount
PlayEventsOptimized(events)
executionTimeMs := A_TickCount - startTime

RecordExecutionStatsAsync({
    events: events,
    buttonKey: "Num7",
    layer: 1,
    execType: "macro",
    executionTimeMs: executionTimeMs
})
```

**Notes:**
- Non-blocking design prevents UI lag
- Actual I/O happens in DoRecordExecutionStatsBlocking via timer

---

#### `RecordExecutionStats(events, buttonKey, layer, execType)`
Core stats recording function (blocking I/O).

**Parameters:**
- `events` (Array) - Macro event array
- `buttonKey` (String) - Button name
- `layer` (Integer) - Layer number
- `execType` (String) - Execution type

**Returns:** `None`

**Side Effects:**
- Appends row to display CSV (macro_execution_stats.csv)
- Appends row to permanent CSV (master_stats_permanent.csv)
- Updates in-memory log (macroExecutionLog array)
- Invalidates today stats cache
- Saves stats_log.json

**Algorithm:**
1. Count degradations from boundingBox events
2. Build execution data map (see [Execution Data Map](#execution-data-map))
3. Convert to CSV row
4. Append to both CSV files
5. Add to macroExecutionLog
6. Invalidate cache
7. Save JSON backup

**Usage:**
```ahk
; Usually called via RecordExecutionStatsAsync
RecordExecutionStats(events, "Num7", 1, "macro")
```

---

#### `GetUnifiedStats(filter := "all")`
Query statistics with flexible filtering.

**Parameters:**
- `filter` (String) - Filter mode:
  - `"all"` - All time statistics
  - `"today"` - Today's date only (uses cache)
  - `"session"` - Current session ID only

**Returns:** `Object` - Stats object (see [Stats Object](#stats-object))

**Algorithm:**
1. If filter = "today" AND cache valid:
   - Return cached stats + live session delta
2. Else load from macroExecutionLog:
   - Filter by date/session
   - Aggregate metrics
   - Calculate derived values
3. Return stats object

**Usage:**
```ahk
; All time stats
allTime := GetUnifiedStats("all")
MsgBox("Total executions: " allTime.totalExecutions)

; Today only (cached)
today := GetUnifiedStats("today")
MsgBox("Today's boxes: " today.totalBoxes)

; Current session
session := GetUnifiedStats("session")
MsgBox("Session time: " session.activeTimeMs " ms")
```

---

#### `InvalidateTodayStatsCache()`
Mark today's stats cache as invalid.

**Returns:** `None`

**Side Effects:**
- Sets global flag: `todayStatsCacheInvalidated := true`
- Forces cache rebuild on next GetUnifiedStats("today")

**Usage:**
```ahk
; After recording new execution
RecordExecutionStats(...)
InvalidateTodayStatsCache()

; After date change
if (currentDate != lastDate) {
    InvalidateTodayStatsCache()
}
```

---

#### `FormatTimeHMS(milliseconds)`
Convert milliseconds to human-readable time format.

**Parameters:**
- `milliseconds` (Integer) - Time in milliseconds

**Returns:** `String` - Formatted time (e.g., "2h 15m 30s")

**Format:**
- Hours (if >= 1 hour)
- Minutes (if >= 1 minute)
- Seconds (always shown)

**Usage:**
```ahk
activeTimeMs := 8130000  ; 2h 15m 30s
formatted := FormatTimeHMS(activeTimeMs)
MsgBox(formatted)  ; "2h 15m 30s"
```

**Examples:**
```
45000 ms → "45s"
125000 ms → "2m 5s"
3725000 ms → "1h 2m 5s"
```

---

#### `ResetDisplayStats()`
Clear display statistics (macro_execution_stats.csv).

**Returns:** `None`

**Side Effects:**
- Deletes macro_execution_stats.csv
- Reinitializes CSV with header
- Clears macroExecutionLog array
- Invalidates today cache
- **Does NOT affect master_stats_permanent.csv**

**Usage:**
```ahk
; Reset display stats button clicked
ResetDisplayStats()
MsgBox("Display stats cleared. Permanent archive unchanged.")
```

---

#### `ExportStats(outputPath, filter := "all")`
Export statistics to CSV file.

**Parameters:**
- `outputPath` (String) - Destination file path
- `filter` (String) - "all" | "today" | "session"

**Returns:** `Boolean` - True on success, false on failure

**Usage:**
```ahk
; Export all time stats
success := ExportStats("C:\Exports\stats_export.csv", "all")

; Export today only
success := ExportStats("C:\Exports\stats_today.csv", "today")
```

**Output Format:**
- CSV with full schema (26 columns)
- Filtered by specified criteria
- Includes header row

---

### Execution API

#### `ExecuteMacro(buttonName)`
Execute macro assigned to a button.

**Parameters:**
- `buttonName` (String) - Button key (e.g., "Num7", "Num8")

**Returns:** `None`

**Algorithm:**
1. Check if awaiting assignment → call AssignToButton if true
2. Load macro events from macroEvents[L{layer}_{buttonName}]
3. Validate events exist
4. Detect execution type (macro vs JSON)
5. Call appropriate playback function
6. Record stats asynchronously

**Usage:**
```ahk
; User pressed Num7 button
ExecuteMacro("Num7")
```

**Flow:**
```
ExecuteMacro("Num7")
  ↓
Load macroEvents["L1_Num7"]
  ↓
if (firstEvent.type = "jsonAnnotation"):
  ExecuteJsonAnnotation(events)
else:
  PlayEventsOptimized(events)
  ↓
RecordExecutionStatsAsync(...)
```

---

#### `PlayEventsOptimized(events)`
Execute macro by simulating mouse/keyboard input.

**Parameters:**
- `events` (Array) - Macro event array

**Returns:** `None`

**Algorithm:**
1. Set playback flag
2. Focus browser window
3. Extract boundingBox events
4. For each box:
   - Move cursor to start position (speed 2)
   - Press left mouse button
   - Drag to end position (speed 8)
   - Release left mouse button
   - Wait (firstBoxDelay or betweenBoxDelay)
5. Clear playback flag

**Usage:**
```ahk
events := macroEvents["L1_Num7"]
PlayEventsOptimized(events)
```

**Timing:**
- First box: `firstBoxDelay` (180ms)
- Subsequent boxes: `betweenBoxDelay` (120ms)
- Mouse speeds: 2 (move to start), 8 (drag)

---

#### `ExecuteJsonAnnotation(events)`
Execute JSON profile annotation.

**Parameters:**
- `events` (Array) - Event array with jsonAnnotation event

**Returns:** `None`

**Algorithm:**
1. Extract JSON event properties:
   - categoryId (degradation type)
   - severity ("high" | "medium" | "low")
   - annotation (text comment)
2. Focus browser
3. Copy annotation to clipboard
4. Paste (Ctrl+V)
5. Submit (Shift+Enter)

**Usage:**
```ahk
events := macroEvents["L1_Num1"]  ; JSON profile
ExecuteJsonAnnotation(events)
```

---

#### `F9_RecordingOnly()`
Toggle macro recording on/off.

**Returns:** `None`

**Algorithm:**
1. If not recording:
   - Create temp macro key
   - Capture canvas mode and coords
   - Initialize event array
   - Install mouse and keyboard hooks
   - Update GUI
2. If recording:
   - Unhook mouse and keyboard
   - Analyze recorded macro (degradation pattern)
   - Enter assignment mode
   - Update GUI

**Usage:**
```ahk
; Hotkey: CapsLock & f
CapsLock & f::F9_RecordingOnly()
```

**Hotkey:** Configurable via config.ini [Hotkeys] hotkeyRecordToggle

---

#### `AnalyzeDegradationPattern(events)`
Match keypresses to bounding boxes and assign degradation types.

**Parameters:**
- `events` (Array) - Recorded event array

**Returns:** `None` (modifies events in place)

**Algorithm:**
1. Extract boundingBox and keyDown events
2. For each box:
   - Find next box time (or infinity if last)
   - Search for keypress in window [box.time, nextBoxTime)
   - If found:
     - Assign degradationType = keypress.key
     - Set assignmentMethod = "user_selection"
   - Else:
     - Inherit from previous box (or default to 0)
     - Set assignmentMethod = "auto_default"
3. Generate degradation summary
4. Log to vizlog_debug.txt

**Usage:**
```ahk
; Called automatically after recording stops
AnalyzeDegradationPattern(events)

; Now all boxes have degradationType assigned
for box in ExtractBoxEvents(events) {
    MsgBox("Box deg: " box.degradationType)
}
```

---

#### `AssignToButton(buttonName)`
Assign recorded macro to a button.

**Parameters:**
- `buttonName` (String) - Target button (e.g., "Num7")

**Returns:** `None`

**Side Effects:**
- Copies events from temp_recording to button macro
- Copies recordedMode and recordedCanvas
- Updates button appearance (thumbnail)
- Saves config_simple.txt
- Clears awaitingAssignment flag

**Usage:**
```ahk
; Called automatically when user presses button after recording
AssignToButton("Num7")
```

---

#### `FocusBrowser()`
Focus browser window (Chrome, Firefox, or Edge).

**Returns:** `Boolean` - True if browser found and focused, false otherwise

**Algorithm:**
1. Search for Chrome window
2. If not found, search for Firefox
3. If not found, search for Edge
4. If found:
   - WinActivate the window
   - Sleep(focusDelay)
   - Return true
5. If not found:
   - Return false

**Usage:**
```ahk
if (FocusBrowser()) {
    ; Browser focused, proceed with execution
    PlayEventsOptimized(events)
} else {
    MsgBox("No browser window found")
}
```

---

#### `SafeExecuteMacroByKey(hotkeyName)`
Execute macro with safety checks.

**Parameters:**
- `hotkeyName` (String) - Hotkey that triggered execution

**Returns:** `None`

**Blocked States:**
- Recording active
- Playback active
- Awaiting assignment
- Break mode active
- Hotkey is CapsLock, f, or Space

**Usage:**
```ahk
; Hotkey binding
Numpad7::SafeExecuteMacroByKey("Num7")
```

---

### Configuration API

#### `LoadConfig()`
Load configuration from config.ini and config_simple.txt.

**Returns:** `None`

**Side Effects:**
- Populates global variables:
  - currentLayer
  - annotationMode
  - wideCanvas, narrowCanvas
  - All timing values
  - All hotkey bindings
- Loads macroEvents map from config_simple.txt

**Usage:**
```ahk
; On app start
LoadConfig()

; Now globals populated
MsgBox("Current layer: " currentLayer)
MsgBox("Canvas mode: " annotationMode)
```

---

#### `SaveConfig()`
Save configuration to config.ini.

**Returns:** `None`

**Saved Sections:**
- [General]: Layer, mode, last saved timestamp
- [Canvas]: Wide/Narrow calibration values
- [Timing]: All delay values
- [Hotkeys]: All hotkey bindings

**Usage:**
```ahk
; After changing settings
annotationMode := "Narrow"
SaveConfig()

; Changes written to config.ini
```

**Note:** Macros saved separately via SaveMacros()

---

#### `SaveMacros()`
Save all macros to config_simple.txt.

**Returns:** `None`

**Format:**
```
L1_Num7=recordedMode,Narrow
L1_Num7=recordedCanvas,428.00,196.00,1363.00,998.00,mode=Narrow
L1_Num7=boundingBox,559,289,634,457,time=86085125,deg=1,isFirstBox=1
L1_Num7=keyDown,1,time=86085296
```

**Usage:**
```ahk
; After assigning macro to button
AssignToButton("Num7")
SaveMacros()  ; Persisted to config_simple.txt
```

---

#### `CalibrateCanvas(mode)`
Calibrate canvas bounds for specified mode.

**Parameters:**
- `mode` (String) - "Wide" or "Narrow"

**Returns:** `None`

**Algorithm:**
1. Display instructions: "Click top-left corner"
2. Wait for click → capture coordinates
3. Display instructions: "Click bottom-right corner"
4. Wait for click → capture coordinates
5. Save to appropriate canvas object
6. Save to config.ini
7. Set calibration flag

**Usage:**
```ahk
; User clicks "Calibrate Wide Canvas" button
CalibrateCanvas("Wide")

; User clicks two corners
; Canvas bounds saved to config.ini
```

---

#### `ToggleAnnotationMode()`
Switch between Wide and Narrow canvas modes.

**Returns:** `None`

**Algorithm:**
1. Toggle annotationMode: "Wide" ↔ "Narrow"
2. Update mode button text
3. Save to config.ini
4. Log to vizlog_debug.txt

**Usage:**
```ahk
; User clicks mode toggle button
ToggleAnnotationMode()

; Mode switched, config saved
```

**Effect:**
- Future recordings use new mode
- Existing macros retain their original mode
- No re-rendering of existing thumbnails

---

## Data Structures

### Event Object

Base structure for all macro events.

#### Bounding Box Event
```ahk
{
    type: "boundingBox",
    left: Integer,              ; Screen X coordinate (top-left)
    top: Integer,               ; Screen Y coordinate (top-left)
    right: Integer,             ; Screen X coordinate (bottom-right)
    bottom: Integer,            ; Screen Y coordinate (bottom-right)
    time: Integer,              ; A_TickCount timestamp
    isFirstBox: Boolean,        ; True if first box in macro
    timeSincePrevious: Integer, ; Milliseconds since previous box (0 if first)
    degradationType: Integer,   ; 0-9 (assigned by AnalyzeDegradationPattern)
    assignmentMethod: String    ; "user_selection" | "auto_default"
}
```

**Example:**
```ahk
{
    type: "boundingBox",
    left: 559,
    top: 289,
    right: 634,
    bottom: 457,
    time: 86085125,
    isFirstBox: true,
    timeSincePrevious: 0,
    degradationType: 1,
    assignmentMethod: "user_selection"
}
```

---

#### Key Down Event
```ahk
{
    type: "keyDown",
    key: Integer,    ; 1-9 (degradation type)
    time: Integer    ; A_TickCount timestamp
}
```

**Example:**
```ahk
{
    type: "keyDown",
    key: 1,
    time: 86085296
}
```

---

#### Key Up Event
```ahk
{
    type: "keyUp",
    key: Integer,    ; 1-9 (degradation type)
    time: Integer    ; A_TickCount timestamp
}
```

---

#### JSON Annotation Event
```ahk
{
    type: "jsonAnnotation",
    categoryId: Integer,     ; 1-9 (degradation type)
    severity: String,        ; "high" | "medium" | "low"
    annotation: String,      ; Text comment
    mode: String,            ; "Wide" | "Narrow"
    time: Integer            ; A_TickCount timestamp
}
```

**Example:**
```ahk
{
    type: "jsonAnnotation",
    categoryId: 2,
    severity: "high",
    annotation: "Severe glare on windshield affecting visibility",
    mode: "Narrow",
    time: 86100000
}
```

---

#### Recorded Mode Metadata
```ahk
{
    type: "recordedMode",
    mode: String    ; "Wide" | "Narrow"
}
```

---

#### Recorded Canvas Metadata
```ahk
{
    type: "recordedCanvas",
    left: Float,
    top: Float,
    right: Float,
    bottom: Float,
    mode: String    ; "Wide" | "Narrow"
}
```

---

### Canvas Object

Defines annotation viewport boundaries.

```ahk
{
    left: Float,     ; Left edge screen coordinate
    top: Float,      ; Top edge screen coordinate
    right: Float,    ; Right edge screen coordinate
    bottom: Float,   ; Bottom edge screen coordinate
    mode: String     ; "Wide" | "Narrow"
}
```

**Example:**
```ahk
; Wide canvas (16:9)
wideCanvas := {
    left: 26.00,
    top: 193.00,
    right: 1652.00,
    bottom: 999.00,
    mode: "Wide"
}

; Narrow canvas (4:3)
narrowCanvas := {
    left: 428.00,
    top: 196.00,
    right: 1363.00,
    bottom: 998.00,
    mode: "Narrow"
}
```

---

### Execution Data Map

Structure for recording execution statistics.

```ahk
{
    timestamp: String,              ; "yyyy-MM-dd HH:mm:ss"
    session_id: String,             ; "sess_yyyyMMdd_HHmmss"
    username: String,               ; Windows username
    execution_type: String,         ; "macro" | "json_profile" | "clear"
    button_key: String,             ; "Num1" - "Num9"
    layer: Integer,                 ; 1-3
    execution_time_ms: Integer,     ; Playback duration
    total_boxes: Integer,           ; Count of boundingBox events
    degradation_assignments: String, ; "smudge,glare,splashes"
    severity_level: String,         ; "high" | "medium" | "low" | ""
    canvas_mode: String,            ; "wide" | "narrow"
    session_active_time_ms: Integer, ; Cumulative active time
    break_mode_active: Boolean,     ; True if in break mode
    smudge_count: Integer,          ; Count of smudge boxes
    glare_count: Integer,           ; Count of glare boxes
    splashes_count: Integer,        ; Count of splashes boxes
    partial_blockage_count: Integer,
    full_blockage_count: Integer,
    light_flare_count: Integer,
    rain_count: Integer,
    haze_count: Integer,
    snow_count: Integer,
    clear_count: Integer,
    annotation_details: String,     ; JSON annotation text
    execution_success: String,      ; "true" | "false"
    error_details: String           ; Error message if failed
}
```

**Example:**
```ahk
{
    timestamp: "2025-11-11 18:14:16",
    session_id: "sess_20251111_181300",
    username: "ajnef",
    execution_type: "macro",
    button_key: "Num7",
    layer: 1,
    execution_time_ms: 2359,
    total_boxes: 4,
    degradation_assignments: "glare,splashes,partial_blockage,full_blockage",
    severity_level: "",
    canvas_mode: "narrow",
    session_active_time_ms: 76453,
    break_mode_active: false,
    smudge_count: 0,
    glare_count: 1,
    splashes_count: 1,
    partial_blockage_count: 1,
    full_blockage_count: 1,
    light_flare_count: 0,
    rain_count: 0,
    haze_count: 0,
    snow_count: 0,
    clear_count: 0,
    annotation_details: "",
    execution_success: "true",
    error_details: ""
}
```

---

### Stats Object

Result structure from GetUnifiedStats().

```ahk
{
    totalExecutions: Integer,       ; Total execution count
    totalBoxes: Integer,            ; Total boxes annotated
    activeTimeMs: Integer,          ; Total active time
    avgExecutionTimeMs: Float,      ; Average execution time
    boxesPerHour: Float,            ; Boxes per hour rate
    executionsPerHour: Float,       ; Executions per hour rate

    ; Degradation breakdown (macros)
    macroDegradations: {
        smudge: Integer,
        glare: Integer,
        splashes: Integer,
        partial_blockage: Integer,
        full_blockage: Integer,
        light_flare: Integer,
        rain: Integer,
        haze: Integer,
        snow: Integer,
        clear: Integer
    },

    ; JSON degradations
    jsonDegradations: {
        smudge: Integer,
        glare: Integer,
        splashes: Integer,
        partial_blockage: Integer,
        full_blockage: Integer,
        light_flare: Integer,
        rain: Integer,
        haze: Integer,
        snow: Integer,
        clear: Integer
    },

    ; Severity levels (JSON only)
    severityLevels: {
        high: Integer,
        medium: Integer,
        low: Integer
    },

    ; User analytics
    mostUsedButton: String,         ; "Num7"
    mostActiveLayer: Integer,       ; 1-3
    distinctUserCount: Integer,     ; Number of unique users

    ; Session breakdown
    sessionStats: Map               ; sessionId → session stats object
}
```

**Example:**
```ahk
{
    totalExecutions: 156,
    totalBoxes: 624,
    activeTimeMs: 8130000,
    avgExecutionTimeMs: 1200,
    boxesPerHour: 276,
    executionsPerHour: 69,
    macroDegradations: {
        smudge: 45,
        glare: 78,
        splashes: 32,
        partial_blockage: 12,
        full_blockage: 8,
        light_flare: 15,
        rain: 5,
        haze: 3,
        snow: 1,
        clear: 425
    },
    jsonDegradations: {
        smudge: 12,
        glare: 18,
        splashes: 7,
        partial_blockage: 3,
        full_blockage: 2,
        light_flare: 1,
        rain: 0,
        haze: 0,
        snow: 0,
        clear: 0
    },
    severityLevels: {
        high: 15,
        medium: 10,
        low: 12
    },
    mostUsedButton: "Num7",
    mostActiveLayer: 1,
    distinctUserCount: 1
}
```

---

## Constants and Enums

### Degradation Types

```ahk
DEGRADATION_SMUDGE := 1
DEGRADATION_GLARE := 2
DEGRADATION_SPLASHES := 3
DEGRADATION_PARTIAL_BLOCKAGE := 4
DEGRADATION_FULL_BLOCKAGE := 5
DEGRADATION_LIGHT_FLARE := 6
DEGRADATION_RAIN := 7
DEGRADATION_HAZE := 8
DEGRADATION_SNOW := 9
DEGRADATION_CLEAR := 0
```

**Name Mapping:**
```ahk
GetDegradationName(type) {
    static names := Map(
        1, "smudge",
        2, "glare",
        3, "splashes",
        4, "partial_blockage",
        5, "full_blockage",
        6, "light_flare",
        7, "rain",
        8, "haze",
        9, "snow",
        0, "clear"
    )
    return names.Has(type) ? names[type] : "unknown"
}
```

---

### Canvas Modes

```ahk
CANVAS_MODE_WIDE := "Wide"
CANVAS_MODE_NARROW := "Narrow"
```

---

### Execution Types

```ahk
EXEC_TYPE_MACRO := "macro"
EXEC_TYPE_JSON := "json_profile"
EXEC_TYPE_CLEAR := "clear"
```

---

### Severity Levels

```ahk
SEVERITY_HIGH := "high"
SEVERITY_MEDIUM := "medium"
SEVERITY_LOW := "low"
```

---

### Assignment Methods

```ahk
ASSIGNMENT_USER_SELECTION := "user_selection"
ASSIGNMENT_AUTO_DEFAULT := "auto_default"
```

---

### Timing Constants (Default Values)

```ahk
; Mouse timing
BOX_DRAW_DELAY := 50
MOUSE_CLICK_DELAY := 75
MOUSE_DRAG_DELAY := 50
MOUSE_RELEASE_DELAY := 75
BETWEEN_BOX_DELAY := 120
FIRST_BOX_DELAY := 180
MOUSE_HOVER_DELAY := 30

; Keyboard timing
KEY_PRESS_DELAY := 12

; UI timing
FOCUS_DELAY := 60
MENU_WAIT_DELAY := 50
SMART_BOX_CLICK_DELAY := 45
SMART_MENU_CLICK_DELAY := 100

; Thresholds
BOX_DRAG_MIN_DISTANCE := 10  ; pixels
```

---

### Mouse Speeds

```ahk
MOUSE_SPEED_MOVE_TO_START := 2  ; Slow, precise
MOUSE_SPEED_DRAG := 8           ; Fast drag
```

---

## Global Variables

### Visualization System Globals

```ahk
global gdiplusToken := 0               ; GDI+ startup token
global hbitmapCache := Map()           ; Cache: cacheKey → HBITMAP
global hbitmapRefCounts := Map()       ; Reference counts
global annotationMode := "Wide"        ; Current canvas mode
global wideCanvas := {...}             ; Wide canvas object
global narrowCanvas := {...}           ; Narrow canvas object
global isWideCanvasCalibrated := false
global isNarrowCanvasCalibrated := false
```

---

### Stats System Globals

```ahk
global macroExecutionLog := []         ; In-memory execution log
global todayStatsCache := {...}        ; Today stats cache
global todayStatsCacheInvalidated := true
global currentSessionId := ""          ; Current session ID
global sessionStartTime := 0           ; A_TickCount at session start
global totalBreakTime := 0             ; Total break time in ms
global breakMode := false              ; Break mode flag
global breakStartTime := 0             ; A_TickCount when break started
```

---

### Execution System Globals

```ahk
global macroEvents := Map()            ; Button → event array
global recording := false              ; Recording state
global playback := false               ; Playback state
global awaitingAssignment := false     ; Assignment mode state
global currentLayer := 1               ; Current layer (1-3)
global mouseHook := 0                  ; Mouse hook handle
global keyboardHook := 0               ; Keyboard hook handle
```

---

## Usage Examples

### Example 1: Create and Display Visualization

```ahk
; Load macro events
events := macroEvents["L1_Num7"]

; Get canvas
canvas := (annotationMode = "Wide") ? wideCanvas : narrowCanvas

; Create HBITMAP
hbitmap := CreateHBITMAPVisualization(events, 392, 153, canvas)

; Display in GUI
pictureControl.Value := hbitmap
AddHBITMAPReference(hbitmap)

; Later, when done
RemoveHBITMAPReference(hbitmap)
```

---

### Example 2: Record and Execute Macro

```ahk
; User presses CapsLock+f to start recording
F9_RecordingOnly()

; ... user draws boxes and presses number keys ...

; User presses CapsLock+f again to stop
F9_RecordingOnly()

; User presses Num7 to assign
SafeExecuteMacroByKey("Num7")  ; Calls AssignToButton("Num7")

; User presses Num7 again to execute
SafeExecuteMacroByKey("Num7")  ; Calls ExecuteMacro("Num7")
```

---

### Example 3: Query and Display Stats

```ahk
; Get today's stats
stats := GetUnifiedStats("today")

; Format time
timeStr := FormatTimeHMS(stats.activeTimeMs)

; Display summary
summary := "Executions: " stats.totalExecutions "`n"
summary .= "Boxes: " stats.totalBoxes "`n"
summary .= "Active Time: " timeStr "`n"
summary .= "Boxes/hour: " Round(stats.boxesPerHour, 1)

MsgBox(summary)
```

---

### Example 4: Custom Degradation Analysis

```ahk
; Load events
events := macroEvents["L1_Num7"]

; Count each degradation type
counts := Map()
for event in events {
    if (event.type = "boundingBox") {
        degName := GetDegradationName(event.degradationType)
        counts[degName] := (counts.Has(degName) ? counts[degName] : 0) + 1
    }
}

; Display results
for degName, count in counts {
    MsgBox(degName ": " count)
}
```

---

**END OF API REFERENCE**
