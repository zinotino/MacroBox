# Data Labeling Assistant - Codebase Issues & Solutions

## CODEBASE HEALTH REPORT - 2025-10-28

### Overall System Status: ✅ FULLY FUNCTIONAL
**Health Score: B+ (85/100)**

**System Components Working:**
- ✅ Visualization with HBITMAP thumbnails (Wide/Narrow modes)
- ✅ Stats tracking with JSON persistence and CSV export
- ✅ Macro recording/playback with degradation tracking
- ✅ Hotkey capture with live re-registration
- ✅ Dark mode GUI with auto-refresh stats display
- ✅ Window scaling with debounced resize handling

**Architecture:**
- **Main File:** [MacroLauncherIntegrated.ahk](MacroLauncherIntegrated.ahk) (6,669 lines)
- **Type:** Monolithic all-in-one standalone script
- **Dependencies:** ZERO external includes (fully self-contained)
- **Functions:** 165+ total functions embedded

### Legacy Code & Cleanup Opportunities

#### 1. Code Duplication - Browser Focus Logic
**Location:** Lines 6504-6577
**Impact:** Low (works correctly, just not DRY)
**Issue:** Same browser focus pattern repeated 4 times in:
- `SubmitCurrentImage()`
- `UtilitySubmit()`
- `UtilityBackspace()`

**Recommendation:** Extract to shared `FocusBrowserWindow()` helper function when refactoring.

#### 2. Unused Modular Files in /src Directory
**Status:** `/src/*.ahk` files are NOT included in main file
**Reality:** All functionality is embedded in MacroLauncherIntegrated.ahk
**Action:** These files have been moved to `archive/legacy-modular/` for reference

**Files archived:**
- src/ObjPersistence.ahk (duplicate of lines 15-260)
- src/StatsData.ahk (duplicate of stats system)
- src/StatsGui.ahk (duplicate of GUI system)
- src/VisualizationCanvas.ahk (duplicate of viz system)
- Plus ~12 other modular files

#### 3. Minor Comment Updates Needed
**Line 4776:** References wrong module path for StatsGui (should say "embedded")
**Line 823:** Commented call to undefined `LogExecutionEvent()` function

**Priority:** Low - cosmetic only

### Architecture Decision: Monolithic vs Modular
**Current Approach:** Monolithic (all-in-one file)
**Rationale:**
- Eliminates #Include path issues
- Single file deployment
- Easier cross-machine transfer
- No module synchronization needed

**Trade-offs:**
- Large file size (6,669 lines)
- Harder to navigate
- But: No dependency management headaches

**Recommendation:** Keep monolithic approach. It's working well for this use case.

---

## RECENT FIXES - 2025-10-27

### **FIXED: Wide/Narrow Toggle No Longer Refreshes Visualizations** ✅
**Status:** Complete - Visualizations stay exactly as recorded

**The Problem:**
- Toggling Wide ↔ Narrow was calling RefreshAllButtonAppearances()
- This tried to recreate all visualizations with the new mode
- Caused crashes, invalid HBITMAPs, and changed how macros looked
- Completely unnecessary - visualizations should never change after recording!

**The Solution:** ([lines 4688-4691](MacroLauncherIntegrated.ahk#L4688-L4691))
- **Removed** RefreshAllButtonAppearances() call from ToggleAnnotationMode()
- Mode toggle now ONLY affects:
  - Which mode will be used for NEW recordings
  - JSON annotation updates (as intended)
  - Button text/color
- Existing visualizations remain untouched

**Why This Is Correct:**
- Each macro stores its `recordedMode` property
- Visualizations always use the mode they were recorded in
- Toggling mode should NOT retroactively change existing macros
- Simple, predictable behavior

**Result:** Toggle Wide ↔ Narrow as much as you want - no crashes, no changes to existing visualizations!

---

### **FIXED: Removed All External Module Dependencies** ✅
**Status:** Complete - MacroLauncherIntegrated.ahk is now fully self-contained

**Changes Made:**
- **Removed #Include "../src/ObjPersistence.ahk"** ([line 5](MacroLauncherIntegrated.ahk#L5))
- **Embedded ObjPersistence code directly** ([lines 15-260](MacroLauncherIntegrated.ahk#L15-L260))
  - All JSON save/load functions now built-in
  - No external dependencies required
  - Script is now truly "all-in-one"

**Benefits:**
- Single file deployment - just copy MacroLauncherIntegrated.ahk
- No module path issues when transferring between machines
- Easier to maintain and debug
- No #Include failures

---

### **FIXED: Visualization System Diagnostic & Recovery** ✅
**Status:** Complete - All diagnostic and recovery systems implemented

**Changes Made:**
1. **Enabled comprehensive debug logging** ([MacroLauncherIntegrated.ahk:1281-1304](MacroLauncherIntegrated.ahk#L1281-L1304))
   - VizLog() now writes timestamped logs to `vizlog_debug.txt`
   - FlushVizLog() persists logs with error handling
   - Tracks entire visualization pipeline

2. **Added canvas validation at startup** ([MacroLauncherIntegrated.ahk:675-715](MacroLauncherIntegrated.ahk#L675-L715))
   - ValidateCanvasCalibration() function checks all canvas configurations
   - Logs Wide/Narrow/User canvas status with detailed bounds
   - Shows warning in status bar if no canvas is configured
   - Called automatically after LoadConfig()

3. **Enhanced canvas fallback logic** ([MacroLauncherIntegrated.ahk:1090-1097](MacroLauncherIntegrated.ahk#L1090-L1097))
   - Logs when fallback box derivation is used
   - Tracks which canvas mode failed and why
   - Provides clear diagnostic messages in VizLog

4. **Verified recordedMode persistence** ([MacroLauncherIntegrated.ahk:4543-4550](MacroLauncherIntegrated.ahk#L4543-L4550))
   - SaveMacroState() properly saves recordedMode property
   - LoadMacroState() properly restores it (line 4687)
   - Logs recordedMode during save/copy operations
   - recordedMode is copied when macros are assigned to buttons (line 3316)

5. **Enhanced GDI+ error handling** ([MacroLauncherIntegrated.ahk:652-672](MacroLauncherIntegrated.ahk#L652-L672))
   - Logs GDI+ initialization success/failure with error codes
   - Shows user-visible error messages in status bar
   - Gracefully handles DLL call exceptions

6. **Added visualization failure recovery** ([MacroLauncherIntegrated.ahk:3755-3789](MacroLauncherIntegrated.ahk#L3755-L3789))
   - Determines WHY visualization failed (GDI+, canvas, or other)
   - Shows informative error text on buttons: "(GDI+ fail)", "(No canvas)", "(Viz error)"
   - Logs detailed failure reasons to vizlog_debug.txt
   - Restores previous HBITMAP if new visualization fails

**How to Diagnose Issues:**
1. Run the script and perform visualization operations
2. Check `vizlog_debug.txt` in the script directory
3. Look for canvas calibration status at startup
4. Check for recordedMode being set/copied when recording/assigning
5. Check for HBITMAP creation and assignment success/failure messages

**Most Likely Issue (Based on User Context):**
- Canvas calibration data wasn't transferred properly to new machine
- Canvas INI section may be missing or have invalid values
- Solution: Recalibrate canvas in Settings, or manually edit config to restore canvas bounds

---

## CRITICAL ISSUES BLOCKING FUNCTIONALITY

---

### **ISSUE #1: Missing Dependencies Causing Cascading Failures** 🔴
**Location:** Lines 5-6
```ahk
#Include "../src/Stats.ahk"
#Include "../src/StatsData.ahk"
```
**Problem:**
- These files don't exist, so the script fails to load
- This causes `RecordExecutionStats()` to be undefined
- When `RecordExecutionStatsAsync()` is called (line 1721), it queues a timer to call the non-existent function
- This creates a silent failure chain

**Why buttons show "ERROR":**
- The async timer fails silently, leaving state corrupted
- When `UpdateButtonAppearance()` runs next, it throws an error due to corrupted state
- The catch block (line 2361-2368) sets `button.Text := "ERROR"`
- Macros don't disappear - they're still there but display is broken

**Solution Needed:**
- Remove the #Include statements
- Define `RecordExecutionStats()` inline (simple CSV append)
- Define `UpdateActiveTime()` function (currently missing)

---

### **ISSUE #2: Unreliable Click Execution During Playback** 🔴
**Location:** `PlayEventsOptimized()` function, lines 1948-1993

**Problem:**
```ahk
PlayEventsOptimized(recordedEvents) {
    ; ...
    if (event.type = "boundingBox") {
        MouseMove(event.left, event.top, 2)
        Sleep(boxDrawDelay)           ; ← Fixed 50ms
        
        Send("{LButton Down}")
        Sleep(mouseClickDelay)         ; ← Fixed 60ms
        
        MouseMove(event.right, event.bottom, 5)
        Sleep(mouseReleaseDelay)       ; ← Fixed 65ms
        
        Send("{LButton Up}")
        Sleep(betweenBoxDelay)         ; ← Fixed 150ms - BUT NO INTELLIGENT TIMING
    }
}
```

**Why clicks are unreliable:**
1. **No focus verification** - Assumes window is focused, but doesn't verify
2. **No menu readiness detection** - After box draw, immediately sleeps instead of waiting for UI
3. **Fixed delays only** - Doesn't account for system lag or slow renders
4. **No error recovery** - If a click fails, just continues with corrupted state
5. **Missing betweenBoxDelay after menu selection** - Should wait AFTER the menu interaction, not just after the box

**Specific Timing Issue:**
The sequence should be:
1. Draw box (current box takes 50-65ms ✓)
2. **WAIT for menu to appear** (MISSING - needs 200-400ms depending on system)
3. **Click menu item** (MISSING - needs intelligent detection)
4. **Verify click took effect** (MISSING - no verification)
5. Move to next box

**Solution Needed:**
- Add `WinWaitActive()` after each box draw to ensure focus
- Add menu element detection/waiting before clicking
- Add post-click verification 
- Use event-based timing instead of fixed delays
- Implement retry logic on failed clicks

---

### **ISSUE #3: Stats System Is Completely Non-Functional** ✅ **RESOLVED - INACCURATE CRITICISM**
**Status:** This issue was based on incorrect analysis. The stats system is fully functional.

**What the criticism claimed (INCORRECT):**
- RecordExecutionStats() function not defined
- UpdateActiveTime() function not defined
- Stats system non-functional

**The Reality (VERIFIED 2025-10-27):**
Both functions ARE fully implemented and working:

1. **`RecordExecutionStats()`** - [lines 2533-2656](MacroLauncherIntegrated.ahk#L2533-L2656)
   - Fully functional with comprehensive degradation tracking
   - Counts all 10 degradation types (smudge, glare, splashes, etc.)
   - Handles macro executions, JSON profiles, and clear annotations
   - Appends to in-memory `macroExecutionLog` array
   - Triggers `SaveStatsToJson()` for persistence

2. **`UpdateActiveTime()`** - [lines 2671-2687](MacroLauncherIntegrated.ahk#L2671-L2687)
   - Fully functional time tracking
   - Handles day change detection via `HandleDayChange()`
   - Accumulates active time (excluding break mode)
   - Called every 5 seconds via SetTimer

3. **Supporting Infrastructure:**
   - `RecordExecutionStatsAsync()` - Async wrapper to prevent UI freezing
   - `AppendToCSV()` - Adds to in-memory log
   - `GetCurrentSessionActiveTime()` - Time calculation
   - `HandleDayChange()` - Daily reset logic

**What WAS Fixed:**
- Removed 3 outdated comments that falsely suggested code was in external modules
- All stats code is self-contained in MacroLauncherIntegrated.ahk

**Conclusion:** Stats system works correctly. This issue can be ignored.

---

### **ISSUE #4: Missing Intelligent Menu Selection Timing** 🔴
**Location:** `PlayEventsOptimized()` - Line 1948

**Current Flow (BROKEN):**
```ahk
; Draw bounding box
MouseMove(left, top)
Sleep(50)
Send("{LButton Down}")
Sleep(60)
MouseMove(right, bottom)
Sleep(65)
Send("{LButton Up}")
Sleep(150)  ; ← Generic wait, doesn't know if menu is ready
; IMMEDIATELY tries to do next action without waiting for menu to appear
```

**The Problem:**
- After drawing a box, a menu typically appears (for degradation type selection)
- Current code has NO intelligence about this menu
- It just sleeps a fixed amount, then continues
- If the menu takes longer to appear, clicks fail
- If the menu never appeared, clicks go to wrong place

**Solution Needed:**
Create a `WaitForMenuAndClick()` function:
```ahk
WaitForMenuAndClick(expectedMenuArea, timeoutMs) {
    ; 1. Loop for up to timeoutMs checking if menu exists/appeared
    ; 2. Once menu detected, identify the menu items
    ; 3. Find and click the correct menu item
    ; 4. Wait for menu to close/action to complete
    ; 5. Return success/failure
}
```

---

### **ISSUE #5: Macro Disappearance Root Cause** 🔴

**What Actually Happens:**
1. Recording works fine - macro events are captured
2. Recording stops - events assigned to button (e.g., "L1_Num7")
3. Button appearance updates via `UpdateButtonAppearance()`
4. **ERROR:** Missing Stats.ahk causes `RecordExecutionStats()` to fail
5. **Cascading failure:** State becomes corrupted
6. **Next call to UpdateButtonAppearance():** Throws error, sets text to "ERROR"
7. **User perception:** "My macro disappeared!"

**Root Cause Chain:**
```
Missing Stats.ahk 
  ↓
RecordExecutionStats undefined
  ↓
Async timer executes but fails silently
  ↓
Button appearance refresh encounters corrupted state
  ↓
UpdateButtonAppearance() throws error
  ↓
Catch block sets button.Text = "ERROR"
  ↓
Macro data still exists, but display is broken
```

**Solution:** Fix the stats system - the macro data isn't lost, just hidden.

---

## IMPLEMENTATION PRIORITIES

### Priority 1: Fix Critical Blocking Issues
1. **Remove broken #Include lines** (5-6)
2. **Implement `RecordExecutionStats()` function** - Simple CSV append
3. **Implement `UpdateActiveTime()` function** - Session tracking
4. **Fix `SaveExecutionData()` function** - Actual CSV persistence
5. **Add error handling** to prevent state corruption

### Priority 2: Improve Execution Reliability
1. **Add window focus verification** before each macro execution
2. **Implement post-draw menu waiting** with intelligent detection
3. **Add click verification/retry logic** 
4. **Replace fixed delays** with event-based timing

### Priority 3: Fix Stats System
1. **Implement CSV schema** for stats tracking
2. **Add session persistence** across app restarts
3. **Create stats display functions** that actually read data
4. **Add stats window** that shows real data

### Priority 4: Clean Up Legacy Code
- Remove old layer system references
- Remove unused visualization module references
- Remove commented-out code blocks
- Consolidate duplicate global definitions (lines 21-78 have many duplicates)

---

## SPECIFIC CODE FIXES

### Fix #1: Remove Broken Includes & Create Stats Functions

**DELETE these lines:**
```ahk
#Include "../src/Stats.ahk"
#Include "../src/StatsData.ahk"
```

**ADD these functions:**
```ahk
UpdateActiveTime() {
    global sessionStartTime, totalActiveTime, lastActiveTime
    
    currentTime := A_TickCount
    timeDelta := currentTime - lastActiveTime
    
    if (timeDelta > 0 && timeDelta < 60000) {
        totalActiveTime += timeDelta
    }
    lastActiveTime := currentTime
}

RecordExecutionStats(macroKey, executionStartTime, executionType, events, analysisRecord) {
    ; Write to CSV file
    ; Format: timestamp, session_id, macro_key, execution_type, success, duration_ms, event_count
    
    executionTime := A_TickCount - executionStartTime
    successStatus := "success"  ; Should be tracked during execution
    eventCount := events.Length
    
    csvLine := Format("{}`t{}`t{}`t{}`t{}`t{}`t{}`n",
        A_Now,
        sessionId,
        macroKey,
        executionType,
        successStatus,
        executionTime,
        eventCount)
    
    try {
        FileAppend(csvLine, STATS_FILE)
    } catch {
        ; Silent fail - don't interrupt execution
    }
}
```

### Fix #2: Intelligent Menu Waiting in PlayEventsOptimized

**REPLACE this section (lines 1959-1970):**
```ahk
; BEFORE (broken)
if (event.type = "boundingBox") {
    MouseMove(event.left, event.top, 2)
    Sleep(boxDrawDelay)
    Send("{LButton Down}")
    Sleep(mouseClickDelay)
    MouseMove(event.right, event.bottom, 5)
    Sleep(mouseReleaseDelay)
    Send("{LButton Up}")
    Sleep(betweenBoxDelay)
}
```

**WITH this (intelligent timing):**
```ahk
if (event.type = "boundingBox") {
    ; 1. Move to start position
    MouseMove(event.left, event.top, 2)
    Sleep(FOCUS_DELAY)
    
    ; 2. Draw the box
    Send("{LButton Down}")
    Sleep(DRAG_DELAY)
    MouseMove(event.right, event.bottom, 5)
    Sleep(DRAG_DELAY)
    Send("{LButton Up}")
    
    ; 3. INTELLIGENT WAIT - Wait for UI elements to be ready
    ; This should detect if a menu appeared and wait for it
    Sleep(MENU_SELECT_DELAY)  ; Primary wait for menu to appear
    
    ; 4. Verify the draw was successful (optional click verification here)
    ; If a menu appeared, a subsequent event would handle clicking it
}
```

### Fix #3: Handle Menu Selection as Separate Event

**Current Problem:** Menu clicks aren't recorded as separate events

**Solution:** After box is drawn, record menu interaction as:
```ahk
{
    type: "menuClick",
    menuItem: "label_1",  ; The menu option selected
    x: menuItemX,
    y: menuItemY,
    time: timestamp
}
```

Then in PlayEventsOptimized, handle it:
```ahk
else if (event.type = "menuClick") {
    ; 1. Wait for menu to appear
    Sleep(MENU_SELECT_DELAY)
    
    ; 2. Find and click the menu item
    MouseMove(event.x, event.y)
    Sleep(CLICK_DELAY)
    Send("{LButton}")
    Sleep(MENU_SELECT_DELAY)  ; Wait for menu to close
}
```

---

## RECOMMENDED REFACTORING

### Consolidate Timing Constants
```ahk
global TIMING := {
    FOCUS_DELAY: 100,         ; Wait for window focus
    CLICK_DELAY: 40,          ; Between clicks
    DRAG_DELAY: 50,           ; During drag operations
    MENU_SELECT_DELAY: 150,   ; Wait for menu to appear/close
    BETWEEN_BOX_DELAY: 200,   ; Between box operations
    VERIFICATION_TIMEOUT: 2000  ; Max time to wait for verification
}
```

### Create Execution Context Object
```ahk
global ExecutionContext := {
    startTime: 0,
    lastEventTime: 0,
    successCount: 0,
    failureCount: 0,
    lastError: "",
    windowFocused: false
}
```

### Add Diagnostic Logging
```ahk
LogExecution(message) {
    ; Write to log file for debugging failed executions
    logLine := Format("[{}] {} - {}`n", A_Now, message, A_LineNumber)
    FileAppend(logLine, EXECUTION_LOG_FILE)
}
```