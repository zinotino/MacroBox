# MacroMaster V2.0 - Code Cleanup Plan

**Generated**: 2025-10-17
**Scope**: Remove redundancies, legacy code, and excessive whitespace
**Estimated Impact**: ~2,434 lines removed, improved maintainability
**Risk Level**: LOW (mostly whitespace/comments, some safe refactoring)

---

## Executive Summary

This cleanup plan addresses code bloat and technical debt accumulated during development:

- **70% of StatsData.ahk** is unnecessary whitespace
- **Multiple functions** duplicated 2-3 times (stats init, browser focus, degradation mapping)
- **Legacy code** from removed features (performance grades, old JSON format, commented Sleeps)
- **Potential deprecated systems** (PNG visualization, legacy canvas variables)

**Total Savings**: ~2,434 lines across 4 core files
**Estimated Time**: 2-4 hours (automated + manual review)
**Testing Required**: Medium (verify stats calculation, macro execution, visualization)

---

## Phase 1: CRITICAL - Whitespace & Formatting (SAFE)

### Task 1.1: Remove Excessive Blank Lines in StatsData.ahk

**Impact**: 2,000+ lines removed
**Risk**: NONE (formatting only)
**Time**: 5 minutes (automated)

#### Current State (Lines 5-45):
```ahk
Stats_GetCsvHeader() {

    return "timestamp,session_id,username..."

}



Stats_EnsureStatsFile(filePath, encoding := "") {



    if (!FileExist(filePath)) {



        header := Stats_GetCsvHeader()



        if (encoding != "")



            FileAppend(header, filePath, encoding)



        else



            FileAppend(header, filePath)



    }

}
```

#### After Cleanup:
```ahk
Stats_GetCsvHeader() {
    return "timestamp,session_id,username..."
}

Stats_EnsureStatsFile(filePath, encoding := "") {
    if (!FileExist(filePath)) {
        header := Stats_GetCsvHeader()

        if (encoding != "")
            FileAppend(header, filePath, encoding)
        else
            FileAppend(header, filePath)
    }
}
```

#### Implementation:
```ahk
; Automated regex replacement:
1. Replace multiple consecutive blank lines (3+) with single blank line
2. Remove trailing whitespace on empty lines
3. Ensure max 1 blank line between functions
```

**Files Affected**:
- `src/StatsData.ahk` (primary target)

**Verification**:
- File size reduction: ~2,840 lines → ~850 lines
- No functional changes
- Syntax validation: Run script, verify no errors

---

## Phase 2: HIGH PRIORITY - Duplicate Code Elimination

### Task 2.1: Extract Duplicate Stats Initialization

**Impact**: 80+ lines removed
**Risk**: LOW (pure refactoring)
**Time**: 15 minutes

#### Current State (Lines 340-460 & 1288-1475):

**ReadStatsFromCSV()** has:
```ahk
stats := Map()
stats["current_username"] := currentUsername
stats["total_executions"] := 0
stats["macro_executions_count"] := 0
stats["json_profile_executions_count"] := 0
stats["clear_executions_count"] := 0
stats["total_boxes"] := 0
stats["total_execution_time"] := 0
stats["average_execution_time"] := 0
stats["session_active_time"] := totalActiveTime
stats["boxes_per_hour"] := 0
stats["user_summary"] := Map()
stats["distinct_user_count"] := 0
stats["executions_per_hour"] := 0
stats["most_used_button"] := ""
stats["most_active_layer"] := ""
stats["degradation_totals"] := Map()
stats["smudge_total"] := 0
stats["glare_total"] := 0
stats["splashes_total"] := 0
stats["partial_blockage_total"] := 0
stats["full_blockage_total"] := 0
stats["light_flare_total"] := 0
stats["rain_total"] := 0
stats["haze_total"] := 0
stats["snow_total"] := 0
stats["clear_total"] := 0
stats["macro_smudge"] := 0
stats["macro_glare"] := 0
stats["macro_splashes"] := 0
stats["macro_partial"] := 0
stats["macro_full"] := 0
stats["macro_flare"] := 0
stats["macro_rain"] := 0
stats["macro_haze"] := 0
stats["macro_snow"] := 0
stats["macro_clear"] := 0
stats["json_smudge"] := 0
stats["json_glare"] := 0
stats["json_splashes"] := 0
stats["json_partial"] := 0
stats["json_full"] := 0
stats["json_flare"] := 0
stats["json_rain"] := 0
stats["json_haze"] := 0
stats["json_snow"] := 0
stats["json_clear"] := 0
stats["severity_low"] := 0
stats["severity_medium"] := 0
stats["severity_high"] := 0
```

**GetTodayStats()** has **IDENTICAL COPY** of above 48 lines.

#### After Cleanup:

**New Helper Function** (add at top of StatsData.ahk):
```ahk
; ===== STATS INITIALIZATION HELPER =====
Stats_CreateEmptyStatsMap() {
    global currentUsername, totalActiveTime

    stats := Map()

    ; Core metrics
    stats["current_username"] := currentUsername
    stats["total_executions"] := 0
    stats["macro_executions_count"] := 0
    stats["json_profile_executions_count"] := 0
    stats["clear_executions_count"] := 0
    stats["total_boxes"] := 0
    stats["total_execution_time"] := 0
    stats["average_execution_time"] := 0
    stats["session_active_time"] := totalActiveTime
    stats["boxes_per_hour"] := 0
    stats["user_summary"] := Map()
    stats["distinct_user_count"] := 0
    stats["executions_per_hour"] := 0
    stats["most_used_button"] := ""
    stats["most_active_layer"] := ""
    stats["degradation_totals"] := Map()

    ; Degradation totals (all execution types)
    stats["smudge_total"] := 0
    stats["glare_total"] := 0
    stats["splashes_total"] := 0
    stats["partial_blockage_total"] := 0
    stats["full_blockage_total"] := 0
    stats["light_flare_total"] := 0
    stats["rain_total"] := 0
    stats["haze_total"] := 0
    stats["snow_total"] := 0
    stats["clear_total"] := 0

    ; Macro degradations (box count per type)
    stats["macro_smudge"] := 0
    stats["macro_glare"] := 0
    stats["macro_splashes"] := 0
    stats["macro_partial"] := 0
    stats["macro_full"] := 0
    stats["macro_flare"] := 0
    stats["macro_rain"] := 0
    stats["macro_haze"] := 0
    stats["macro_snow"] := 0
    stats["macro_clear"] := 0

    ; JSON degradations (1 selection per execution)
    stats["json_smudge"] := 0
    stats["json_glare"] := 0
    stats["json_splashes"] := 0
    stats["json_partial"] := 0
    stats["json_full"] := 0
    stats["json_flare"] := 0
    stats["json_rain"] := 0
    stats["json_haze"] := 0
    stats["json_snow"] := 0
    stats["json_clear"] := 0

    ; Severity levels
    stats["severity_low"] := 0
    stats["severity_medium"] := 0
    stats["severity_high"] := 0

    return stats
}
```

**Updated ReadStatsFromCSV()**:
```ahk
ReadStatsFromCSV(filterBySession := false) {
    global masterStatsCSV, sessionId, totalActiveTime, currentUsername

    ; Initialize stats using helper function
    stats := Stats_CreateEmptyStatsMap()

    try {
        if (!FileExist(masterStatsCSV)) {
            return stats
        }

        csvContent := FileRead(masterStatsCSV, "UTF-8")
        lines := StrSplit(csvContent, "`n")

        if (lines.Length <= 1) {
            return stats ; No data rows
        }

        ; ... rest of parsing logic unchanged ...
    }

    return stats
}
```

**Updated GetTodayStats()**:
```ahk
GetTodayStats() {
    global masterStatsCSV, sessionId, currentUsername

    ; Initialize stats using helper function
    stats := Stats_CreateEmptyStatsMap()
    sessionActiveMap := Map()

    try {
        if (!FileExist(masterStatsCSV)) {
            return stats
        }

        csvContent := FileRead(masterStatsCSV, "UTF-8")
        lines := StrSplit(csvContent, "`n")

        if (lines.Length <= 1) {
            return stats
        }

        ; Get today's date in YYYY-MM-DD format
        today := FormatTime(A_Now, "yyyy-MM-dd")

        ; ... rest of parsing logic unchanged ...
    }

    return stats
}
```

**Files Affected**:
- `src/StatsData.ahk`

**Verification**:
1. Run stats display (all-time stats)
2. Run stats display (today stats)
3. Compare before/after values - should be identical
4. Check all degradation counts
5. Verify user summary data

---

### Task 2.2: Extract Duplicate Degradation Mapping Switch

**Impact**: 160+ lines removed
**Risk**: LOW (pure refactoring)
**Time**: 20 minutes

#### Current State (Lines 972-1056, 1786-1870, 2070-2154):

**Three identical switch statements**:

**Location 1 - ReadStatsFromCSV() JSON processing**:
```ahk
switch StrLower(degradation_name) {
    case "smudge", "1":
        stats["json_smudge"]++
    case "glare", "2":
        stats["json_glare"]++
    case "splashes", "3":
        stats["json_splashes"]++
    case "partial_blockage", "4":
        stats["json_partial"]++
    case "full_blockage", "5":
        stats["json_full"]++
    case "light_flare", "6":
        stats["json_flare"]++
    case "rain", "7":
        stats["json_rain"]++
    case "haze", "8":
        stats["json_haze"]++
    case "snow", "9":
        stats["json_snow"]++
    case "clear", "none":
        stats["json_clear"]++
}
```

**Location 2 - GetTodayStats() JSON processing**: IDENTICAL
**Location 3 - ProcessDegradationCounts()**: IDENTICAL

#### After Cleanup:

**New Helper Function** (add to StatsData.ahk):
```ahk
; ===== DEGRADATION STAT INCREMENT HELPER =====
Stats_IncrementDegradationCount(stats, degradation_name, prefix := "json_") {
    ; Increment the appropriate degradation counter in stats map
    ; prefix: "json_" for JSON executions, "macro_" for macro executions

    switch StrLower(degradation_name) {
        case "smudge", "1":
            stats[prefix . "smudge"]++
        case "glare", "2":
            stats[prefix . "glare"]++
        case "splashes", "3":
            stats[prefix . "splashes"]++
        case "partial_blockage", "4":
            stats[prefix . "partial"]++
        case "full_blockage", "5":
            stats[prefix . "full"]++
        case "light_flare", "6":
            stats[prefix . "flare"]++
        case "rain", "7":
            stats[prefix . "rain"]++
        case "haze", "8":
            stats[prefix . "haze"]++
        case "snow", "9":
            stats[prefix . "snow"]++
        case "clear", "none":
            stats[prefix . "clear"]++
    }
}
```

**Updated ReadStatsFromCSV()** (replace switch at line 972):
```ahk
; Old code:
switch StrLower(degradation_name) {
    case "smudge", "1":
        stats["json_smudge"]++
    // ... 80 lines ...
}

; New code:
Stats_IncrementDegradationCount(stats, degradation_name, "json_")
```

**Updated GetTodayStats()** (replace switch at line 1786):
```ahk
; Old code:
switch StrLower(degradation_name) {
    // ... 80 lines ...
}

; New code:
Stats_IncrementDegradationCount(stats, degradation_name, "json_")
```

**Updated ProcessDegradationCounts()** (replace switch at line 2070):
```ahk
ProcessDegradationCounts(executionData, degradationString) {
    if (degradationString = "" || degradationString = "none") {
        return
    }

    ; Split by comma and process each degradation type
    degradationTypes := StrSplit(degradationString, ",")

    for degradationType in degradationTypes {
        degradationType := Trim(StrReplace(StrReplace(degradationType, Chr(34), ""), Chr(39), ""))

        ; Use helper function instead of switch
        Stats_IncrementDegradationCount(executionData, degradationType, "")
        ; Note: empty prefix because executionData uses direct field names
    }
}
```

**Note**: ProcessDegradationCounts uses field names without prefix (e.g., "smudge_count" not "json_smudge"), so we need a second variant:

```ahk
; ===== DEGRADATION COUNT INCREMENT (for executionData maps) =====
Stats_IncrementDegradationCountDirect(executionData, degradation_name) {
    ; For use with executionData maps that use "_count" suffix

    switch StrLower(degradation_name) {
        case "smudge", "1":
            executionData["smudge_count"]++
        case "glare", "2":
            executionData["glare_count"]++
        case "splashes", "3":
            executionData["splashes_count"]++
        case "partial_blockage", "4":
            executionData["partial_blockage_count"]++
        case "full_blockage", "5":
            executionData["full_blockage_count"]++
        case "light_flare", "6":
            executionData["light_flare_count"]++
        case "rain", "7":
            executionData["rain_count"]++
        case "haze", "8":
            executionData["haze_count"]++
        case "snow", "9":
            executionData["snow_count"]++
        case "clear", "none":
            executionData["clear_count"]++
    }
}
```

**Then ProcessDegradationCounts becomes**:
```ahk
ProcessDegradationCounts(executionData, degradationString) {
    if (degradationString = "" || degradationString = "none") {
        return
    }

    degradationTypes := StrSplit(degradationString, ",")
    for degradationType in degradationTypes {
        degradationType := Trim(StrReplace(StrReplace(degradationType, Chr(34), ""), Chr(39), ""))
        Stats_IncrementDegradationCountDirect(executionData, degradationType)
    }
}
```

**Files Affected**:
- `src/StatsData.ahk`

**Verification**:
1. Record macro with degradations 1,2,3
2. Execute macro multiple times
3. Check stats display - verify degradation counts accurate
4. Record JSON profile (single degradation)
5. Execute JSON profile
6. Verify JSON degradation counts separate from macro counts
7. Test "clear" degradation assignment

---

### Task 2.3: Consolidate Browser Focus Functions

**Impact**: 50+ lines removed
**Risk**: LOW (tested refactoring)
**Time**: 15 minutes

#### Current State (Core.ahk Lines 537-627):

**Three nearly identical functions**:

**Function 1 - SubmitCurrentImage()**:
```ahk
SubmitCurrentImage() {
    global focusDelay
    browserFocused := false

    if (WinExist("ahk_exe chrome.exe")) {
        WinActivate("ahk_exe chrome.exe")
        browserFocused := true
    } else if (WinExist("ahk_exe firefox.exe")) {
        WinActivate("ahk_exe firefox.exe")
        browserFocused := true
    } else if (WinExist("ahk_exe msedge.exe")) {
        WinActivate("ahk_exe msedge.exe")
        browserFocused := true
    }

    if (browserFocused) {
        startTime := A_TickCount
        Send("+{Enter}")
        UpdateStatus("📤 Submitted")
        RecordExecutionStats("NumpadEnter", startTime, "clear", [], "")
    } else {
        UpdateStatus("⚠️ No browser")
    }
}
```

**Function 2 - ShiftNumpadClearExecution(buttonName)**: 90% identical
**Function 3 - DirectClearExecution()**: 95% identical

#### After Cleanup:

**New Consolidated Function**:
```ahk
; ===== UNIFIED BROWSER FOCUS & SUBMIT =====
FocusBrowserAndSubmit(buttonName := "NumpadEnter", statusLabel := "Submitted") {
    global focusDelay

    startTime := A_TickCount

    ; Try browsers in priority order
    browsers := ["chrome.exe", "firefox.exe", "msedge.exe"]
    browserFocused := false

    for browser in browsers {
        if (WinExist("ahk_exe " . browser)) {
            WinActivate("ahk_exe " . browser)
            browserFocused := true
            break
        }
    }

    if (browserFocused) {
        Send("+{Enter}")
        UpdateStatus("📤 " . statusLabel)
        RecordExecutionStats(buttonName, startTime, "clear", [], "")
        return true
    } else {
        UpdateStatus("⚠️ No browser: " . buttonName)
        return false
    }
}

; ===== WRAPPER FUNCTIONS (maintain API compatibility) =====
SubmitCurrentImage() {
    FocusBrowserAndSubmit("NumpadEnter", "Submitted")
}

ShiftNumpadClearExecution(buttonName) {
    FocusBrowserAndSubmit("Shift" . buttonName, "Clear: Shift+" . buttonName)
}

DirectClearExecution() {
    FocusBrowserAndSubmit("ShiftEnter", "Direct Clear Submitted")
}
```

**Alternative (if wrapper functions not needed)**:
```ahk
; Replace all calls to old functions with direct calls:
; SubmitCurrentImage() → FocusBrowserAndSubmit("NumpadEnter", "Submitted")
; ShiftNumpadClearExecution(name) → FocusBrowserAndSubmit("Shift" . name, "Clear: Shift+" . name)
; DirectClearExecution() → FocusBrowserAndSubmit("ShiftEnter", "Direct Clear")
```

**Files Affected**:
- `src/Core.ahk`
- Search project for calls to these functions and update if removing wrappers

**Verification**:
1. Test NumpadEnter clear submission
2. Test Shift+Numpad clear submission (multiple buttons)
3. Test direct Shift+Enter clear
4. Verify stats recording for each
5. Test with no browser open (error message)
6. Test with Chrome, Firefox, Edge separately

---

### Task 2.4: Remove Duplicate F9 Protection

**Impact**: 5 lines + reduced code complexity
**Risk**: NONE (redundant check)
**Time**: 2 minutes

#### Current State (MacroExecution.ahk):

**Location 1** - SafeExecuteMacroByKey() Lines 29-32:
```ahk
; CRITICAL: Absolutely prevent F9 from reaching macro execution (silent block)
if (buttonName = "F9" || InStr(buttonName, "F9")) {
    return
}
```

**Location 2** - ExecuteMacro() Lines 44-47:
```ahk
; Double-check F9 protection (silent block)
if (buttonName = "F9" || InStr(buttonName, "F9")) {
    return
}
```

#### After Cleanup:

**Keep ONLY in SafeExecuteMacroByKey()** (entry point):
```ahk
SafeExecuteMacroByKey(buttonName) {
    global breakMode, playback, lastExecutionTime

    ; CRITICAL: Block ALL execution during break mode
    if (breakMode) {
        return
    }

    ; CRITICAL: Prevent rapid execution race conditions (minimum 50ms between executions)
    currentTime := A_TickCount
    if (lastExecutionTime && (currentTime - lastExecutionTime) < 50) {
        return
    }
    lastExecutionTime := currentTime

    ; CRITICAL: Double-check playback state before proceeding
    if (playback) {
        return
    }

    ; CRITICAL: Absolutely prevent F9 from reaching macro execution (silent block)
    if (buttonName = "F9" || InStr(buttonName, "F9")) {
        return
    }

    ; Regular macro execution - silent
    ExecuteMacro(buttonName)
}
```

**Remove from ExecuteMacro()** (Lines 44-47):
```ahk
ExecuteMacro(buttonName) {
    global awaitingAssignment, macroEvents, playback, focusDelay, degradationTypes

    ; PERFORMANCE MONITORING - Start timing execution
    executionStartTime := A_TickCount

    ; DELETE THESE LINES (already checked in SafeExecuteMacroByKey):
    ; if (buttonName = "F9" || InStr(buttonName, "F9")) {
    ;     return
    ; }

    if (awaitingAssignment) {
        SetTimer(CheckForAssignment, 0)
        AssignToButton(buttonName)
        return
    }

    ; ... rest of function unchanged ...
}
```

**Rationale**: ExecuteMacro() is ONLY called from SafeExecuteMacroByKey(), which already blocks F9. The duplicate check is unreachable dead code.

**Files Affected**:
- `src/MacroExecution.ahk`

**Verification**:
1. Press F9 - should start recording (not execute)
2. Execute normal macros (Numpad0-9) - should work
3. Verify F9 never triggers macro execution
4. No functional change expected

---

## Phase 3: MEDIUM PRIORITY - Legacy Code Removal

### Task 3.1: Remove Commented-Out Sleep() Calls

**Impact**: 20+ comment lines removed
**Risk**: NONE (comments only)
**Time**: 5 minutes

#### Current State:

**MacroExecution.ahk**:
```ahk
Line 375: ; Sleep(200) - REMOVED: Between-execution delay, not internal macro timing
Line 431: ; Sleep(25) - REMOVED for rapid labeling performance
Line 434: ; Sleep(50) - REMOVED for rapid labeling performance
Line 438: ; Sleep(50) - REMOVED for rapid labeling performance
Line 467: ; Sleep(retryDelay) - REMOVED for rapid labeling performance
Line 471: ; Sleep(focusDelay) - REMOVED for rapid labeling performance
Line 479: ; Sleep(50) - REMOVED for rapid labeling performance
Line 483: ; Sleep(focusDelay) - REMOVED for rapid labeling performance
Line 493: ; Sleep(retryDelay * A_Index) - REMOVED for rapid labeling performance
```

**Core.ahk**:
```ahk
Line 556: ; Sleep(focusDelay) - REMOVED for rapid labeling performance
Line 587: ; Sleep(focusDelay) - REMOVED for rapid labeling performance
Line 618: ; Sleep(focusDelay) - REMOVED for rapid labeling performance
```

#### After Cleanup:

**Delete all lines** - these are historical comments documenting removed timing.

If context is needed for future reference, add a single comment at the top of ExecuteJsonAnnotation():

```ahk
ExecuteJsonAnnotation(jsonEvent) {
    global annotationMode

    ; NOTE: All Sleep() timing removed for maximum labeling performance
    ; Original delays (75-200ms) caused slow macro execution

    try {
        ; Use current annotation mode instead of stored mode for execution
        currentMode := annotationMode

        ; ... rest of function ...
```

**Files Affected**:
- `src/MacroExecution.ahk`
- `src/Core.ahk`

**Verification**:
- Code review only
- No functional changes

---

### Task 3.2: Remove Performance Grade Remnants

**Impact**: 10+ lines removed
**Risk**: NONE (dead code)
**Time**: 3 minutes

#### Current State (StatsData.ahk):

**Unused variable** (Line 624):
```ahk
gradeCount := Map()
```

**Scattered comments**:
```ahk
Line 413: ; Performance grades removed - using raw data only
Line 812: ; Performance grade tracking removed
Line 1264: ; Performance grades removed
```

#### After Cleanup:

**Delete gradeCount variable** (Line 624):
```ahk
; OLD:
executionTimes := []
buttonCount := Map()
layerCount := Map()
gradeCount := Map()  // DELETE THIS LINE
sessionActiveMap := Map()

; NEW:
executionTimes := []
buttonCount := Map()
layerCount := Map()
sessionActiveMap := Map()
```

**Delete all "performance grades removed" comments** - feature is gone, no need to mention it.

**Files Affected**:
- `src/StatsData.ahk`

**Verification**:
- Search codebase for "grade" (case-insensitive)
- Ensure no remaining references
- Run stats display - no errors

---

### Task 3.3: Remove Legacy Canvas Variables (Verify First)

**Impact**: 5 lines + cognitive load reduction
**Risk**: LOW (need to verify no usage)
**Time**: 10 minutes (includes verification)

#### Current State (Core.ahk Lines 103-107):

```ahk
; Legacy canvas (for backwards compatibility)
global userCanvasLeft := 0
global userCanvasTop := 0
global userCanvasRight := 1920
global userCanvasBottom := 1080
```

#### Investigation Required:

**Search for usage**:
```
userCanvasLeft
userCanvasTop
userCanvasRight
userCanvasBottom
```

**Expected findings**:
- Wide/Narrow system should have replaced these
- Main() function (Lines 264-278) syncs these with wide/narrow values
- May still be used in visualization scaling

#### After Cleanup (IF SAFE):

**Option 1 - Keep sync logic if used in visualization**:
```ahk
; Current canvas coordinates (synced with annotation mode)
global userCanvasLeft := 0
global userCanvasTop := 0
global userCanvasRight := 1920
global userCanvasBottom := 1080
```

**Option 2 - Remove entirely if unused**:
```ahk
; DELETE Lines 103-107
; DELETE sync logic in Main() (Lines 264-278)
```

**Files Affected**:
- `src/Core.ahk`
- Potentially `src/VisualizationCanvas.ahk` or `src/VisualizationUtils.ahk`

**Verification Steps**:
1. Search entire project for "userCanvas" references
2. If found, trace usage to see if replaceable with wideCanvas/narrowCanvas
3. If not found or easily replaceable, proceed with removal
4. Test macro recording in both Wide and Narrow modes
5. Verify visualization scaling correct
6. Test canvas calibration

---

## Phase 4: LOW PRIORITY - Optional Cleanup (Verify Need First)

### Task 4.1: Remove Old JSON Format Parsing (Verify First)

**Impact**: 15 lines removed
**Risk**: MEDIUM (may break compatibility with old macros)
**Time**: 5 minutes (if safe) or skip

#### Current State (MacroExecution.ahk Lines 400-415):

```ahk
if (!categoryId || !severity) {
    storedJson := jsonEvent.annotation
    if (InStr(storedJson, '"category_id":') && InStr(storedJson, '"severity":"')) {
        ; Parse from new format
        RegExMatch(storedJson, '"category_id":(\d+)', &catMatch)
        RegExMatch(storedJson, '"severity":"([^"]+)"', &sevMatch)
        if (catMatch && sevMatch) {
            categoryId := Integer(catMatch[1])
            severity := sevMatch[1]
        }
    } else if (InStr(storedJson, '"degradation":"') && InStr(storedJson, '"severity":"')) {
        ; Parse from old format  <-- THIS BRANCH
        RegExMatch(storedJson, '"degradation":"([^"]+)"', &degMatch)
        RegExMatch(storedJson, '"severity":"([^"]+)"', &sevMatch)
        if (degMatch && sevMatch) {
            degradation := degMatch[1]
            severity := sevMatch[1]
            ; Find category ID from degradation name
            for id, name in degradationTypes {
                if (name = degradation) {
                    categoryId := id
                    break
                }
            }
        }
    }
}
```

#### Investigation Required:

**Questions**:
1. When was "old format" used? Before what version/date?
2. Are there any existing config.ini files with old format macros?
3. Can users still have old format in saved state?

**Check config.ini**:
```ahk
; Look for JSON annotations with old format:
; OLD: "degradation":"smudge"
; NEW: "category_id":1
```

#### After Cleanup (IF SAFE):

**If no old format exists in wild**:
```ahk
if (!categoryId || !severity) {
    storedJson := jsonEvent.annotation
    if (InStr(storedJson, '"category_id":') && InStr(storedJson, '"severity":"')) {
        ; Parse from JSON format
        RegExMatch(storedJson, '"category_id":(\d+)', &catMatch)
        RegExMatch(storedJson, '"severity":"([^"]+)"', &sevMatch)
        if (catMatch && sevMatch) {
            categoryId := Integer(catMatch[1])
            severity := sevMatch[1]
        }
    }
}
```

**If unsure, SKIP THIS TASK** - backwards compatibility is valuable.

**Files Affected**:
- `src/MacroExecution.ahk`

**Verification** (if removed):
1. Test all JSON profile macros
2. Verify old macros still execute (if any exist)
3. Check degradation name parsing

---

### Task 4.2: Remove PNG Visualization System (Verify First)

**Impact**: 59 lines removed
**Risk**: HIGH (may be used as fallback)
**Time**: 10 minutes (if safe) or skip

#### Current State (VisualizationCore.ahk Lines 10-68):

```ahk
SaveVisualizationPNG(bitmap, uniqueId) {
    ; USER-CONTROLLED: Respect user's visualization save path preference
    ; Returns actual working file path (not just boolean)

    global documentsDir, workDir, visualizationSavePath

    clsid := Buffer(16)
    NumPut("UInt", 0x557CF406, clsid, 0)
    NumPut("UInt", 0x11D31A04, clsid, 4)
    NumPut("UInt", 0x0000739A, clsid, 8)
    NumPut("UInt", 0x2EF31EF8, clsid, 12)

    fileName := "macro_viz_" . uniqueId . ".png"

    ; ... 50 lines of fallback path logic ...
}
```

#### Investigation Required:

**Search for calls to SaveVisualizationPNG**:
```
SaveVisualizationPNG(
```

**Expected findings**:
- Should return 0 results if HBITMAP-only system is active
- May be called as fallback if HBITMAP fails
- May be exposed in GUI settings for user preference

**Check**:
- Is `visualizationSavePath` still used?
- Are there any GUI controls for PNG export?
- Does thumbnail directory get populated with PNGs?

#### After Cleanup (IF SAFE):

**If truly unused**:
```ahk
; DELETE SaveVisualizationPNG() function entirely (Lines 10-68)
```

**If used as fallback, keep but add comment**:
```ahk
; ===== PNG SAVING (LEGACY FALLBACK) =====
; Used only when HBITMAP visualization fails in corporate environments
SaveVisualizationPNG(bitmap, uniqueId) {
    ; ... existing code ...
}
```

**If unsure, SKIP THIS TASK** - PNG export may be valuable for debugging or future features.

**Files Affected**:
- `src/VisualizationCore.ahk`
- Potentially config/settings files

**Verification** (if removed):
1. Search for all visualization-related function calls
2. Verify no PNG files created in thumbnail directory
3. Test macro visualization on all buttons
4. Check for any "visualization failed" errors

---

## Implementation Strategy

### Recommended Order:

1. **Phase 1 (5 min)** - Whitespace cleanup → SAFE, massive visual improvement
2. **Phase 2, Task 2.1 (15 min)** - Stats initialization → SAFE refactoring
3. **Phase 2, Task 2.2 (20 min)** - Degradation mapping → SAFE refactoring
4. **Phase 2, Task 2.3 (15 min)** - Browser focus → SAFE refactoring
5. **Phase 2, Task 2.4 (2 min)** - Duplicate F9 check → SAFE removal
6. **Phase 3, Task 3.1 (5 min)** - Commented Sleeps → SAFE removal
7. **Phase 3, Task 3.2 (3 min)** - Performance grades → SAFE removal
8. **Phase 3, Task 3.3 (10 min)** - Legacy canvas → VERIFY FIRST
9. **Phase 4, Task 4.1 (5 min)** - Old JSON format → VERIFY FIRST
10. **Phase 4, Task 4.2 (10 min)** - PNG system → VERIFY FIRST

**Total Time**:
- Phases 1-2: ~60 minutes (guaranteed safe)
- Phase 3: ~20 minutes (low risk)
- Phase 4: ~20 minutes (needs verification)

**Total**: 1.5-2 hours for full cleanup

---

## Testing Checklist

After each phase, verify:

### Core Functionality
- [ ] Macro recording (F9) works
- [ ] Macro playback (Numpad 0-9) works
- [ ] Degradation assignment (1-9) works
- [ ] JSON profile execution works
- [ ] Clear execution (Shift+Enter, Numpad) works
- [ ] Break mode (Ctrl+B) works
- [ ] Emergency stop (RCtrl) works

### Stats System
- [ ] Stats display shows all-time data
- [ ] Stats display shows today data
- [ ] Degradation counts accurate
- [ ] Execution counts accurate
- [ ] Active time tracking works
- [ ] User summary correct
- [ ] CSV files written correctly

### Visualization System
- [ ] Button thumbnails appear
- [ ] HBITMAP visualization works
- [ ] Wide mode scaling correct
- [ ] Narrow mode scaling correct
- [ ] Degradation colors correct
- [ ] No memory leaks (check Task Manager)

### Configuration
- [ ] Config saves on exit
- [ ] Config loads on startup
- [ ] Macros persist
- [ ] Settings persist
- [ ] Canvas calibration persists

---

## Rollback Plan

**Before starting**:
1. Create backup: `BackroadStable_backup_2025-10-17.zip`
2. Commit to git (if using version control)
3. Document current state

**If issues arise**:
1. Restore from backup
2. Apply changes incrementally (one task at a time)
3. Test thoroughly after each change
4. Skip problematic tasks

---

## Expected Results

### Before Cleanup:
- **Total Lines**: ~9,140 across 20 files
- **StatsData.ahk**: 2,840 lines
- **Code Duplication**: High (multiple 80+ line duplicates)
- **Legacy Code**: Present (commented code, dead variables)

### After Cleanup:
- **Total Lines**: ~6,700 across 20 files (-2,440 lines)
- **StatsData.ahk**: ~850 lines (-1,990 lines)
- **Code Duplication**: Minimal (extracted to helpers)
- **Legacy Code**: Removed or documented

### Maintainability Improvements:
- ✅ DRY principle applied (no duplicate stats init, degradation mapping, browser focus)
- ✅ Single source of truth for common operations
- ✅ Cleaner file structure (no excessive whitespace)
- ✅ Removed dead code and obsolete comments
- ✅ Easier to understand and modify

---

## Notes

- **Backup first** - always maintain a working copy
- **Test incrementally** - don't apply all changes at once
- **Verify assumptions** - Phase 4 tasks require confirmation before removal
- **Document changes** - update CHANGELOG.md with cleanup notes
- **Consider git** - version control recommended for tracking changes

---

**Questions?** Review this plan with the user before proceeding.
