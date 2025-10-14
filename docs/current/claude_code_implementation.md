# Claude Code Implementation Guide
## Technical Specifications for System Cleanup & Stabilization

---

## 🎯 BASELINE REFERENCE

**Working Commit:** `9a93a12`
- ✅ Visualization system verified working (HBITMAP)
- ✅ Stats system verified working (async queue)
- **Branch:** `expanded`
- **Date:** 2025-10-08

**Use this commit as reference for working implementations**

---

## 📋 PHASE 1: LEGACY CODE REMOVAL

### **1A: Remove Multi-Layer System**

#### Files to Modify:
- `src/Config.ahk`
- `src/Core.ahk`
- `src/GUI.ahk`
- `src/ConfigIO.ahk`
- `src/MacroRecording.ahk`
- `src/MacroExecution.ahk`

#### Changes Required:

**Config.ahk:**
```ahk
// REMOVE these globals:
global currentLayer := 1
global totalLayers := 5
global layerNames := ["Layer 1", "Layer 2", "Layer 3", "Layer 4", "Layer 5"]
global layerBorderColors := [...]

// KEEP simplified:
global buttonNames := ["Num7", "Num8", "Num9", "Num4", "Num5", "Num6", 
                       "Num1", "Num2", "Num3", "Num0", "NumDot", "NumMult"]

// ADD for intelligent system:
global currentDegradation := 1  // Global state, no per-layer
```

**Core.ahk:**
```ahk
// REMOVE all references to:
- currentLayer variable
- SwitchToLayer() function
- Layer UI refresh logic
- Per-layer state management

// UPDATE InitializeVariables():
InitializeVariables() {
    // REMOVE layer initialization
    // KEEP button initialization
    for buttonName in buttonNames {
        buttonCustomLabels[buttonName] := buttonName
    }
    
    // ADD intelligent system state
    global currentDegradation := 1
}
```

**MacroRecording.ahk & MacroExecution.ahk:**
```ahk
// REPLACE all instances of:
layerMacroName := "L" . currentLayer . "_" . buttonName

// WITH:
macroName := buttonName  // Just the button name

// Example:
// OLD: macroEvents["L1_Num7"]
// NEW: macroEvents["Num7"]
```

**ConfigIO.ahk - SaveConfig():**
```ahk
// UPDATE macro saving loop:
// OLD:
for layer in 1..totalLayers {
    for buttonName in buttonNames {
        layerMacroName := "L" . layer . "_" . buttonName
        // ...
    }
}

// NEW:
for buttonName in buttonNames {
    if (macroEvents.Has(buttonName) && macroEvents[buttonName].Length > 0) {
        // Save macro with simple key
        configContent .= buttonName . "_events=" . SerializeEvents(macroEvents[buttonName]) . "`n"
        configContent .= buttonName . "_mode=" . mode . "`n"
        configContent .= buttonName . "_label=" . label . "`n"
    }
}
```

**GUI.ahk:**
```ahk
// REMOVE:
- Layer switching buttons (Layer 1-5 buttons)
- Layer indicator text
- UpdateLayerDisplay() function
- Layer border color logic

// KEEP:
- 12 button grid (3x4)
- Button labels
- Break mode toggle
```

---

### **1B: Remove Plotly/Python/SQL Systems**

#### Files to Remove:
- Delete ALL `.py` files in project
- Delete any SQL database files
- Delete Plotly-related scripts

#### Files to Modify:
- `src/StatsData.ahk`

#### Changes Required:

**StatsData.ahk:**
```ahk
// REMOVE these entire sections:
- ingestionServiceUrl variable
- realtimeEnabled variable
- Any HTTP request code
- SendDataToIngestion() function
- InitializeRealtimeSession() function
- All Python/SQL integration code

// REMOVE these globals:
global ingestionServiceUrl := "http://localhost:5001"
global currentSessionId := "sess_" . FormatTime(A_Now, "yyyyMMdd_HHmmss")
global realtimeEnabled := true

// KEEP ONLY:
- CSV file paths (masterStatsCSV, permanentStatsFile)
- Async queue system (statsWriteQueue, FlushStatsQueue)
- AppendToCSV() function
- ReadStatsFromCSV() function
```

---

### **1C: Simplify Visualization System**

#### Files to Modify:
- `src/VisualizationCore.ahk`

#### Changes Required:

**VisualizationCore.ahk:**
```ahk
// KEEP ONLY:
1. CreateHBITMAPVisualization() function (lines 162-265 in commit 9a93a12)
2. InitializeVisualizationSystem() function
3. CleanupHBITMAPCache() function

// REMOVE:
- Text rendering methods
- Multiple PNG fallback paths (keep one emergency path only)

// SIMPLIFY SaveVisualizationPNG():
SaveVisualizationPNG(bitmap, uniqueId) {
    // SINGLE fallback path only:
    filePath := workDir . "\macro_viz_" . uniqueId . ".png"
    
    // Try to save, return path or empty string
    // NO multiple fallback attempts
    // NO complex path resolution
}

// PNG should ONLY be used if HBITMAP fails
// Primary visualization: HBITMAP only
```

**Priority:** Use HBITMAP system from commit `9a93a12` as-is. Don't modify it unless necessary.

---

### **1D: Consolidate Stats System**

#### Audit Required:

**Search for duplicate functions:**
```bash
# Search for multiple implementations:
grep -r "RecordExecutionStats" src/
grep -r "AppendToCSV" src/
grep -r "FlushStats" src/
```

**Keep ONLY:**
- Single RecordExecutionStats() function
- Single AppendToCSV() function
- Single FlushStatsQueue() function
- Single CSV schema (streamlined from snapshot)

**Verify CSV Schema:**
```
Headers (from commit 9a93a12):
timestamp, session_id, username, execution_type, button_key, layer, 
execution_time_ms, total_boxes, degradation_assignments, severity_level, 
canvas_mode, session_active_time_ms, break_mode_active, 
smudge_count, glare_count, splashes_count, partial_blockage_count, 
full_blockage_count, light_flare_count, rain_count, haze_count, 
snow_count, clear_count, annotation_details, execution_success, error_details
```

**Update schema to remove "layer" column** (since single layer now)

---

## 📋 PHASE 2: FIX CRITICAL ISSUES

### **2A: Fix Stats System Freeze**

**Problem:** Freezes after 3 rapid executions during stats write

**Location:** `src/StatsData.ahk`

#### Code Changes:

**Increase Queue Size:**
```ahk
// OLD:
global statsQueueMaxSize := 10

// NEW:
global statsQueueMaxSize := 50  // Handle 50 rapid executions
```

**Add Write Timeout:**
```ahk
FlushStatsQueue() {
    global statsWriteQueue, statsWriteTimer, statsFlushInProgress
    
    if (statsFlushInProgress || statsWriteQueue.Length = 0) {
        return
    }
    
    statsFlushInProgress := true
    flushStartTime := A_TickCount  // ADD THIS
    
    try {
        queueCopy := statsWriteQueue.Clone()
        statsWriteQueue := []
        
        SetTimer(FlushStatsQueue, 0)
        statsWriteTimer := false
        
        // ADD TIMEOUT CHECK:
        for data in queueCopy {
            // Check if we've exceeded 100ms
            if (A_TickCount - flushStartTime > 100) {
                // Drop remaining items and exit
                break
            }
            
            // Write single row
            WriteSingleCSVRow(data)
        }
        
    } catch Error as e {
        // Silent fail - don't break execution
    } finally {
        statsFlushInProgress := false
    }
}
```

**Add Overflow Protection:**
```ahk
AppendToCSV(executionData) {
    global statsWriteQueue, statsQueueMaxSize
    
    // ADD: Drop oldest if queue full
    if (statsWriteQueue.Length >= statsQueueMaxSize) {
        statsWriteQueue.RemoveAt(1)  // Drop oldest
    }
    
    statsWriteQueue.Push(executionData)
    
    // Rest of function unchanged
}
```

**Verify Async Behavior:**
```ahk
// Ensure RecordExecutionStats() does NOT call FlushStatsQueue() directly
// It should only call AppendToCSV(), which adds to queue
// Timer flushes queue asynchronously

RecordExecutionStats(buttonName, startTime, executionType, events, analysis := "") {
    // ... build executionData ...
    
    // ONLY this line should interact with stats:
    AppendToCSV(executionData)  // Non-blocking
    
    // NO direct file writes here
    // NO FlushStatsQueue() call here
}
```

---

### **2B: Fix Config Persistence (Intelligent System State)**

**Problem:** Macros stop after boxes, don't reach intelligent timing system

**Root Cause:** Event properties not saved/loaded

#### Required Changes:

**ConfigIO.ahk - SaveConfig():**
```ahk
// ADD to config file output:

[Settings]
// ... existing settings ...
currentDegradation=<current value>  // ADD THIS

[Macros]
// For each button with macro:
Num7_events=<JSON with ALL event properties>  // Must include degradationType
Num7_mode=Wide
Num7_label=Custom Label

// Example event structure:
{
    "type": "boundingBox",
    "left": 100,
    "top": 50,
    "right": 200,
    "bottom": 150,
    "time": 12345,
    "degradationType": 3,           // MUST INCLUDE
    "degradationName": "Splashes",  // MUST INCLUDE
    "assignedBy": "user_selection"  // MUST INCLUDE
}
```

**Verify SerializeEvents() includes all properties:**
```ahk
SerializeEvents(events) {
    jsonArray := "["
    
    for index, event in events {
        if (index > 1) {
            jsonArray .= ","
        }
        
        // Build JSON object with ALL properties
        jsonObj := "{"
        jsonObj .= '"type":"' . event.type . '"'
        jsonObj .= ',"time":' . event.time
        
        // Add coordinates if present
        if (event.HasOwnProp("left")) {
            jsonObj .= ',"left":' . event.left
            jsonObj .= ',"top":' . event.top
            jsonObj .= ',"right":' . event.right
            jsonObj .= ',"bottom":' . event.bottom
        }
        
        // CRITICAL: Add degradation properties if present
        if (event.HasOwnProp("degradationType")) {
            jsonObj .= ',"degradationType":' . event.degradationType
        }
        if (event.HasOwnProp("degradationName")) {
            jsonObj .= ',"degradationName":"' . event.degradationName . '"'
        }
        if (event.HasOwnProp("assignedBy")) {
            jsonObj .= ',"assignedBy":"' . event.assignedBy . '"'
        }
        
        // ... other properties ...
        
        jsonObj .= "}"
        jsonArray .= jsonObj
    }
    
    jsonArray .= "]"
    return jsonArray
}
```

**ConfigIO.ahk - LoadConfig():**
```ahk
LoadConfig() {
    // ... read config file ...
    
    // RESTORE intelligent system state:
    if (InStr(content, "currentDegradation=")) {
        RegExMatch(content, "currentDegradation=(\d+)", &match)
        if (match) {
            global currentDegradation := Integer(match[1])
        }
    }
    
    // For each macro loaded:
    // Parse events JSON and restore ALL properties
    events := ParseEventsJSON(eventsString)
    
    // Verify each boundingBox event has degradationType
    for event in events {
        if (event.type = "boundingBox" && !event.HasOwnProp("degradationType")) {
            // Default to Smudge if missing (backward compatibility)
            event.degradationType := 1
            event.degradationName := "Smudge"
            event.assignedBy := "auto_default"
        }
    }
    
    macroEvents[buttonName] := events
    
    // REGENERATE VISUALIZATIONS after loading:
    RefreshAllButtonAppearances()
}
```

---

### **2C: Fix Visualization Restoration**

**Problem:** No thumbnails show after reopen

**Location:** `src/Core.ahk` and `src/ConfigIO.ahk`

#### Changes Required:

**Add to LoadConfig() completion:**
```ahk
LoadConfig() {
    // ... load all macros ...
    
    // CRITICAL: Regenerate all visualizations
    RefreshAllButtonAppearances()
    
    return loadedCount
}
```

**Verify RefreshAllButtonAppearances():**
```ahk
RefreshAllButtonAppearances() {
    global mainGui, buttonNames
    
    // MUST verify GDI+ initialized first
    if (!gdiPlusInitialized) {
        InitializeVisualizationSystem()
    }
    
    // Clear HBITMAP cache to force regeneration
    CleanupHBITMAPCache()
    global hbitmapCache := Map()  // Reset cache
    
    for buttonName in buttonNames {
        if (macroEvents.Has(buttonName) && macroEvents[buttonName].Length > 0) {
            // Regenerate visualization
            UpdateButtonAppearance(buttonName)
        }
    }
}
```

**UpdateButtonAppearance() must use HBITMAP:**
```ahk
UpdateButtonAppearance(buttonName) {
    global mainGui, macroEvents
    
    if (!macroEvents.Has(buttonName)) {
        return
    }
    
    events := macroEvents[buttonName]
    if (events.Length = 0) {
        return
    }
    
    // Get button control
    pictureControl := mainGui["picture_" . buttonName]
    if (!pictureControl) {
        return
    }
    
    // Generate HBITMAP visualization
    buttonDims := {width: 100, height: 100}  // Or actual button size
    hbitmap := CreateHBITMAPVisualization(events, buttonDims)
    
    if (hbitmap) {
        pictureControl.Value := "HBITMAP:*" . hbitmap
    } else {
        // Emergency PNG fallback only if HBITMAP fails
        pngPath := CreateMacroVisualization(events, buttonDims)
        if (pngPath && FileExist(pngPath)) {
            pictureControl.Value := pngPath
        }
    }
}
```

---

### **2D: Fix First Click Reliability**

**Problem:** First click doesn't register ~20% of the time

**Location:** `src/MacroRecording.ahk`

#### Changes Required:

**Add Mouse State Initialization:**
```ahk
ForceStartRecording() {
    global recording, currentMacro, macroEvents, pendingBoxForTagging
    
    // Clean state
    recording := false
    SafeUninstallMouseHook()
    SafeUninstallKeyboardHook()
    
    // CRITICAL: Initialize mouse state
    CoordMode("Mouse", "Screen")  // Ensure screen coordinates
    
    // ADD: Get current mouse position to initialize tracking
    MouseGetPos(&initX, &initY)
    
    // ADD: Small delay to ensure hooks are ready
    Sleep(50)  // 50ms delay before recording starts
    
    // Start recording
    recording := true
    currentMacro := "temp_recording_" . A_TickCount
    macroEvents[currentMacro] := []
    pendingBoxForTagging := ""
    
    InstallMouseHook()
    InstallKeyboardHook()
    
    // ADD: Verify hooks installed successfully
    if (!mouseHook || !keyboardHook) {
        throw Error("Failed to install hooks")
    }
    
    UpdateStatus("🎥 RECORDING ACTIVE - Draw boxes, F9 to stop")
}
```

**Add Click Debouncing in MouseProc:**
```ahk
MouseProc(nCode, wParam, lParam) {
    global recording, currentMacro, macroEvents
    
    if (nCode < 0 || !recording || currentMacro = "") {
        return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "UInt", wParam, "Ptr", lParam)
    }
    
    static WM_LBUTTONDOWN := 0x0201, WM_LBUTTONUP := 0x0202
    static lastClickTime := 0  // ADD for debouncing
    static isDrawingBox := false, boxStartX := 0, boxStartY := 0
    
    local x := NumGet(lParam, 0, "Int")
    local y := NumGet(lParam, 4, "Int")
    local timestamp := A_TickCount
    
    if (!macroEvents.Has(currentMacro))
        macroEvents[currentMacro] := []
    
    local events := macroEvents[currentMacro]
    
    if (wParam = WM_LBUTTONDOWN) {
        // ADD: Debounce clicks (min 50ms between downs)
        if (timestamp - lastClickTime < 50) {
            return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "UInt", wParam, "Ptr", lParam)
        }
        lastClickTime := timestamp
        
        isDrawingBox := true
        boxStartX := x
        boxStartY := y
        events.Push({type: "mouseDown", button: "left", x: x, y: y, time: timestamp})
        
        // ADD: Log first click for debugging
        if (events.Length = 1) {
            FileAppend("First click registered: " . x . "," . y . "`n", A_ScriptDir . "\click_debug.log")
        }
    }
    
    // ... rest of function unchanged ...
    
    return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "UInt", wParam, "Ptr", lParam)
}
```

---

## 📋 PHASE 3: TESTING & VALIDATION

### **Test 1: Stats Freeze Test**

```ahk
// Create test macro with 5 boxes
// Execute rapidly 20 times:

Loop 20 {
    ; Execute macro
    ExecuteMacro("Num7")
    Sleep(10)  // Minimal delay to simulate rapid execution
}

// EXPECTED:
// - No freezing
// - All 20 executions complete
// - Stats written to CSV (verify manually)
// - UI remains responsive
```

**Verification:**
- Check `master_stats_permanent.csv` has 20 new rows
- Count degradation totals match expected
- Application didn't freeze or hang

---

### **Test 2: Config Persistence Test**

```ahk
// Test workflow:
1. Record macro: Box1 (no key) → Box2 (press 3) → Box3 (no key)
2. Verify during recording that currentDegradation updates to 3
3. Save config (should happen automatically)
4. Close application completely
5. Reopen application
6. Check button thumbnail shows correctly
7. Execute macro
8. Verify all boxes execute with correct degradations
9. Check stats CSV has correct counts

// EXPECTED:
// - Thumbnail shows on reopen
// - Execution completes fully (doesn't stop after boxes)
// - Stats show: Box1=Smudge(1), Box2=Splashes(3), Box3=Splashes(3)
```

**Verification:**
- Button picture control has HBITMAP handle
- Macro executes all events including intelligent timing
- Stats CSV shows correct degradation counts

---

### **Test 3: First Click Test**

```ahk
// Test workflow:
Loop 10 {
    1. Press F9 to start recording
    2. Immediately click and drag box (within 100ms of F9)
    3. Release
    4. Press F9 to stop
    5. Check if box was recorded
    6. Clear macro
}

// EXPECTED:
// - 9-10 out of 10 boxes should register (90%+ success)
// - Check click_debug.log for first click coordinates
```

---

### **Test 4: Performance Test**

```ahk
// Create 10-box macro
// Time execution:

startTime := A_TickCount
ExecuteMacro("Num7")
endTime := A_TickCount

executionTime := endTime - startTime

// EXPECTED:
// - Execution time: 1000-3000ms (1-3 seconds)
// - No freezing after completion
// - Immediate readiness for next execution
```

---

## 🔍 DEBUGGING CHECKLIST

### If Stats Still Freeze:

1. Add timing logs to FlushStatsQueue():
```ahk
FileAppend("Flush start: " . A_TickCount . "`n", "stats_debug.log")
// ... flush code ...
FileAppend("Flush end: " . A_TickCount . "`n", "stats_debug.log")
```

2. Check queue size at freeze:
```ahk
FileAppend("Queue size: " . statsWriteQueue.Length . "`n", "stats_debug.log")
```

3. Verify no blocking file operations:
```bash
grep -r "FileAppend.*master_stats" src/
# Should only appear in FlushStatsQueue() or WriteSingleCSVRow()
```

---

### If Config Not Persisting:

1. Verify events serialized correctly:
```ahk
// After SaveConfig():
content := FileRead(configFile)
FileAppend(content, "config_debug.txt")  // Save copy for inspection
```

2. Check event properties on load:
```ahk
// In LoadConfig(), after parsing events:
for event in events {
    if (event.type = "boundingBox") {
        FileAppend("Box loaded: degradationType=" . event.degradationType . "`n", "load_debug.log")
    }
}
```

3. Verify intelligent system state restored:
```ahk
// After LoadConfig():
FileAppend("currentDegradation restored: " . currentDegradation . "`n", "state_debug.log")
```

---

### If Visualizations Not Showing:

1. Check GDI+ initialization:
```ahk
FileAppend("GDI+ initialized: " . gdiPlusInitialized . "`n", "viz_debug.log")
```

2. Verify HBITMAP creation:
```ahk
// In CreateHBITMAPVisualization():
FileAppend("HBITMAP created: " . hbitmap . "`n", "viz_debug.log")
```

3. Check button picture control assignment:
```ahk
// In UpdateButtonAppearance():
FileAppend("Setting picture for " . buttonName . ": " . hbitmap . "`n", "viz_debug.log")
```

---

## 📊 SUCCESS METRICS

### Must Pass:
- ✅ 20 rapid executions without freezing
- ✅ Execution time 1-3 seconds (10-box macro)
- ✅ Stats accurate in CSV (manually verified)
- ✅ Config persists across close/reopen
- ✅ Thumbnails show on reopen
- ✅ First click registers 9/10 times
- ✅ Intelligent system state persists

### Performance Targets:
- Execution: 1-3 seconds
- Config save: <50ms
- Stats write: Async, zero blocking
- Visualization gen: <100ms

---

## 🎯 FINAL CHECKLIST

Before considering work complete:

### Code Cleanup:
- [ ] All layer references removed
- [ ] Python/SQL/Plotly code deleted
- [ ] Single visualization path (HBITMAP + emergency PNG)
- [ ] Single stats recording path
- [ ] No duplicate functions

### Functionality:
- [ ] 20 rapid executions pass test
- [ ] Config persistence test passes
- [ ] First click test passes (90%+)
- [ ] Performance test passes (1-3s)

### File Structure:
- [ ] Config file simplified (no layers)
- [ ] All event properties saved/loaded
- [ ] Intelligent system state in config
- [ ] CSV schema updated (no layer column)

### Verification:
- [ ] Manual test workflow passes
- [ ] Stats CSV accurate
- [ ] Visualizations show on reopen
- [ ] No freezing during normal use

---

## 🚀 IMPLEMENTATION ORDER

Execute phases in this strict order:

1. **Phase 1A** - Remove layers (test after)
2. **Phase 1B** - Remove Python/SQL (test after)
3. **Phase 1C** - Simplify visualization (test after)
4. **Phase 2A** - Fix stats freeze (test extensively)
5. **Phase 2B** - Fix config persistence (test close/reopen)
6. **Phase 2C** - Fix visualization restoration (test after)
7. **Phase 2D** - Fix first click (test repeatedly)
8. **Phase 3** - Full integration testing

**DO NOT** proceed to next phase until current phase tests pass.

---

## 📝 COMMIT STRATEGY

Commit after each phase:

```bash
git add -A
git commit -m "PHASE 1A: Remove multi-layer system"
# Test...

git add -A
git commit -m "PHASE 2A: Fix stats system freeze - async queue improvements"
# Test...

# etc.
```

**Tag final working state:**
```bash
git tag -a v3.0-stable -m "Clean single-layer system with fixed stats/persistence"
```

---

## 🎉 EXPECTED FINAL STATE

After all phases complete:

- Clean codebase (~40% less code)
- Single layer system (12 buttons)
- Fast, reliable execution (1-3s)
- No freezing (tested 20+ rapid executions)
- Perfect persistence (close/reopen works)
- Working visualizations (HBITMAP)
- Accurate stats (CSV verified)
- Offline operation (no network)

**System is production-ready for labeling workflow**
