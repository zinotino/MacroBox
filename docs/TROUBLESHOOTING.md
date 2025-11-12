# Troubleshooting Guide - MacroMonoo
**Version:** Stable Build (2025-11-11)

---

## Table of Contents
- [Visualization Issues](#visualization-issues)
- [Stats Issues](#stats-issues)
- [Execution Issues](#execution-issues)
- [Configuration Issues](#configuration-issues)
- [Performance Issues](#performance-issues)
- [Common Fixes](#common-fixes)

---

## Visualization Issues

### Issue: Boxes Not Displaying on Buttons

**Symptoms:**
- Button shows no thumbnail after macro assignment
- Picture control remains empty/white

**Possible Causes:**

1. **HBITMAP Creation Failed**
   - Check vizlog_debug.txt for errors
   - Verify GDI+ initialization: `gdiplusToken != 0`

2. **No Bounding Box Events**
   - Macro contains only keypresses, no boxes
   - Drag distance below threshold (boxDragMinDistance)

3. **Invalid HBITMAP Handle**
   - HBITMAP was deleted prematurely
   - Reference counting issue

**Solutions:**

```ahk
; Debug: Check HBITMAP validity
if (!IsHBITMAPValid(hbitmap)) {
    MsgBox("Invalid HBITMAP - regenerating...")
    InvalidateVisualizationCache("Num7")
    UpdateButtonAppearance("Num7")
}

; Check for box events
boxes := ExtractBoxEvents(macroEvents["L1_Num7"])
if (boxes.Length = 0) {
    MsgBox("No boxes found in macro")
}

; Verify GDI+ initialized
if (gdiplusToken = 0) {
    MsgBox("GDI+ not initialized")
    gdiplusToken := InitializeGDIPlus()
}
```

---

### Issue: Boxes Misaligned on Thumbnail

**Symptoms:**
- Boxes appear in wrong positions
- Boxes extend beyond thumbnail boundaries
- Coordinates don't match recorded positions

**Possible Causes:**

1. **Canvas Not Calibrated**
   - Canvas bounds incorrect (0,0,0,0)
   - Wrong canvas mode used

2. **DPI Scaling Issue**
   - High-DPI display (150%, 200%)
   - Coordinates not converted to logical units

3. **Canvas Mode Mismatch**
   - Recorded in Wide, displayed in Narrow (or vice versa)
   - recordedCanvas not copied during assignment

**Solutions:**

**Recalibrate Canvas:**
```ahk
; Check calibration status
if (!isWideCanvasCalibrated) {
    MsgBox("Wide canvas not calibrated - please calibrate")
    CalibrateCanvas("Wide")
}

; Verify canvas values
MsgBox("Canvas: " wideCanvas.left "," wideCanvas.top " → "
       wideCanvas.right "," wideCanvas.bottom)
```

**Check DPI Scaling:**
```ahk
screenScale := A_ScreenDPI / 96.0
MsgBox("DPI Scale: " screenScale)

; If scale != 1.0, ensure coordinates are divided by scale
canvasLeftLogical := canvasLeft / screenScale
```

**Verify Canvas Mode:**
```ahk
; Check if macro has recordedCanvas
events := macroEvents["L1_Num7"]
hasRecordedCanvas := false

for event in events {
    if (event.type = "recordedCanvas") {
        hasRecordedCanvas := true
        MsgBox("Recorded canvas: " event.left "," event.top " → "
               event.right "," event.bottom " mode=" event.mode)
        break
    }
}

if (!hasRecordedCanvas) {
    MsgBox("ERROR: Macro missing recordedCanvas metadata")
}
```

---

### Issue: Letterboxing Not Applied (Narrow Mode)

**Symptoms:**
- Narrow mode thumbnails lack gray letterbox bars
- Boxes appear stretched horizontally

**Possible Causes:**

1. **Canvas Mode Detection Failed**
   - canvasObj.mode not set to "Narrow"
   - Mode string comparison case-sensitive

2. **Letterbox Calculation Error**
   - usableWidth/offsetX calculation incorrect
   - Aspect ratio mismatch

**Solutions:**

```ahk
; Verify mode string
canvas := narrowCanvas
MsgBox("Canvas mode: '" canvas.mode "'")  ; Should be "Narrow"

; Check letterbox calculation
canvasWidth := canvas.right - canvas.left
canvasHeight := canvas.bottom - canvas.top
targetAspect := 16/9
canvasAspect := canvasWidth / canvasHeight

if (canvas.mode = "Narrow") {
    if (canvasAspect > targetAspect) {
        usableWidth := canvasHeight * targetAspect
        offsetX := (canvasWidth - usableWidth) / 2
        MsgBox("Letterbox offset: " offsetX " px")
    }
}
```

---

### Issue: Wrong Degradation Colors

**Symptoms:**
- All boxes same color
- Colors don't match degradation type
- Expected Gold (smudge), got Gray

**Possible Causes:**

1. **Degradation Type Not Assigned**
   - AnalyzeDegradationPattern() not called
   - degradationType = 0 (default gray)

2. **Analysis Failed**
   - No keypresses recorded
   - Timestamp matching failed

**Solutions:**

```ahk
; Check degradation types
events := macroEvents["L1_Num7"]
boxes := ExtractBoxEvents(events)

for i, box in boxes {
    MsgBox("Box " i ": degradationType = " box.degradationType)
}

; Re-analyze if needed
AnalyzeDegradationPattern(events)

; Check for keypresses
keypresses := []
for event in events {
    if (event.type = "keyDown") {
        keypresses.Push(event)
    }
}
MsgBox("Found " keypresses.Length " keypresses")
```

---

### Issue: Cache Corruption

**Symptoms:**
- Old thumbnails displayed after macro change
- Thumbnail doesn't update after re-recording

**Solutions:**

```ahk
; Clear cache for specific button
InvalidateVisualizationCache("Num7")

; Clear entire cache
InvalidateVisualizationCache()

; Force re-render
UpdateButtonAppearance("Num7")

; Nuclear option: Restart app
Reload
```

---

## Stats Issues

### Issue: Missing Executions in Stats

**Symptoms:**
- Executed macro, but not recorded in stats
- Stats count doesn't increment

**Possible Causes:**

1. **Break Mode Active**
   - Stats not recorded during break mode
   - Check breakMode flag

2. **Recording/Playback State**
   - Stats blocked during recording
   - RecordExecutionStatsAsync validation failed

3. **Async Timer Failed**
   - Timer not triggered
   - DoRecordExecutionStatsBlocking not called

**Solutions:**

```ahk
; Check break mode
if (breakMode) {
    MsgBox("Break mode active - stats recording disabled")
    ToggleBreakMode()  ; Disable break mode
}

; Check recording/playback state
MsgBox("Recording: " recording "`nPlayback: " playback)

; Force synchronous recording (debug)
RecordExecutionStats(events, "Num7", 1, "macro")

; Check CSV files
if (!FileExist("data/macro_execution_stats.csv")) {
    MsgBox("Stats CSV missing - reinitializing")
    InitializeStatsFiles()
}
```

---

### Issue: Incorrect Degradation Counts

**Symptoms:**
- Degradation counts don't match boxes drawn
- All counts show 0
- Wrong degradation incremented

**Possible Causes:**

1. **Event Missing degradationType**
   - AnalyzeDegradationPattern not called before stats recording
   - degradationType property absent

2. **Name Mapping Error**
   - GetDegradationName() returns wrong name
   - Map key mismatch

**Solutions:**

```ahk
; Verify degradation types assigned
events := macroEvents["L1_Num7"]
boxes := ExtractBoxEvents(events)

for box in boxes {
    if (!box.Has("degradationType")) {
        MsgBox("ERROR: Box missing degradationType")
        AnalyzeDegradationPattern(events)
        break
    }
}

; Test name mapping
for i in [1, 2, 3, 4, 5, 6, 7, 8, 9, 0] {
    name := GetDegradationName(i)
    MsgBox(i " → " name)
}

; Manual count verification
smudgeCount := 0
for box in boxes {
    if (box.degradationType = 1) {
        smudgeCount++
    }
}
MsgBox("Manual smudge count: " smudgeCount)
```

---

### Issue: Time Tracking Incorrect

**Symptoms:**
- Active time not incrementing
- Time jumps unexpectedly
- Negative time values

**Possible Causes:**

1. **Session Timer Not Started**
   - sessionStartTime = 0
   - Timer not initialized on session start

2. **Break Time Calculation Error**
   - totalBreakTime miscalculated
   - Break start/stop not paired correctly

3. **Tickcount Wraparound**
   - A_TickCount wrapped around (49.7 days uptime)

**Solutions:**

```ahk
; Check session timer
if (sessionStartTime = 0) {
    MsgBox("Session timer not started")
    sessionStartTime := A_TickCount
}

; Verify break time
MsgBox("Session start: " sessionStartTime
       "`nTotal break time: " totalBreakTime
       "`nCurrent tick: " A_TickCount)

; Calculate active time
activeTime := A_TickCount - sessionStartTime - totalBreakTime
MsgBox("Active time: " activeTime " ms = " FormatTimeHMS(activeTime))

; Check for negative values
if (activeTime < 0) {
    MsgBox("ERROR: Negative active time detected - resetting session")
    sessionStartTime := A_TickCount
    totalBreakTime := 0
}
```

---

### Issue: Today Stats Cache Stale

**Symptoms:**
- Today's stats don't update after execution
- Old data displayed in GUI
- Live time not incrementing

**Solutions:**

```ahk
; Manually invalidate cache
InvalidateTodayStatsCache()

; Force GUI refresh
UpdateStatsDisplay()

; Check cache date
currentDate := FormatTime(A_Now, "yyyy-MM-dd")
MsgBox("Current date: " currentDate
       "`nCache date: " todayStatsCache.date
       "`nCache invalidated: " todayStatsCacheInvalidated)

; Rebuild cache
todayStats := GetUnifiedStats("today")
```

---

### Issue: CSV File Corruption

**Symptoms:**
- Stats fail to load
- Parsing errors in CSV
- Missing or duplicate headers

**Solutions:**

**Backup and Repair:**
```ahk
; Create backup
FileCopy("data/macro_execution_stats.csv",
         "data/macro_execution_stats_backup.csv", 1)

; Check for duplicate headers
content := FileRead("data/macro_execution_stats.csv")
headerCount := StrSplit(content, "timestamp,session_id").Length - 1
MsgBox("Header count: " headerCount)  ; Should be 1

; If corrupted, restore from permanent archive
if (headerCount > 1) {
    FileDelete("data/macro_execution_stats.csv")
    FileCopy("data/master_stats_permanent.csv",
             "data/macro_execution_stats.csv")
}
```

---

## Execution Issues

### Issue: Macro Not Playing

**Symptoms:**
- Pressed button, nothing happens
- No mouse movement or clicks
- Playback flag not set

**Possible Causes:**

1. **Safety Checks Blocking**
   - Break mode active
   - Recording/playback already in progress
   - Awaiting assignment

2. **No Events Loaded**
   - macroEvents[buttonKey] is empty
   - Button not assigned

3. **Browser Not Found**
   - FocusBrowser() returns false
   - No Chrome/Firefox/Edge window

**Solutions:**

```ahk
; Check button assignment
buttonKey := "L" . currentLayer . "_Num7"
if (!macroEvents.Has(buttonKey)) {
    MsgBox("No macro assigned to button")
}

events := macroEvents[buttonKey]
MsgBox("Event count: " events.Length)

; Check safety flags
MsgBox("Break mode: " breakMode
       "`nRecording: " recording
       "`nPlayback: " playback
       "`nAwaiting assignment: " awaitingAssignment)

; Test browser focus
if (!FocusBrowser()) {
    MsgBox("No browser window found - please open Chrome/Firefox/Edge")
}

; Force execution (bypass safety)
playback := false
recording := false
breakMode := false
awaitingAssignment := false
ExecuteMacro("Num7")
```

---

### Issue: Timing Too Fast/Slow

**Symptoms:**
- Boxes drawn too quickly, UI doesn't respond
- Playback too slow, inefficient annotation
- First box fails, subsequent boxes succeed

**Solutions:**

**Adjust Timing Values:**
```ahk
; Increase delays if too fast
firstBoxDelay := 250       ; Default: 180
betweenBoxDelay := 150     ; Default: 120
mouseReleaseDelay := 100   ; Default: 75

; Decrease if too slow (but may cause failures)
firstBoxDelay := 120
betweenBoxDelay := 80

; Save to config
SaveConfig()

; Test with single box macro
```

**System-Specific Tuning:**
```
Fast System (Gaming PC):
  firstBoxDelay: 120-150
  betweenBoxDelay: 80-100

Average System:
  firstBoxDelay: 180 (default)
  betweenBoxDelay: 120 (default)

Slow System / High Network Latency:
  firstBoxDelay: 250-300
  betweenBoxDelay: 150-180
```

---

### Issue: Focus Problems

**Symptoms:**
- Browser doesn't focus before playback
- Boxes drawn on wrong window
- Alt-Tab doesn't happen

**Solutions:**

```ahk
; Check browser window title
if (WinExist("ahk_exe chrome.exe")) {
    WinGetTitle(&title, "ahk_exe chrome.exe")
    MsgBox("Chrome title: " title)
}

; Increase focus delay
focusDelay := 100  ; Default: 60
SaveConfig()

; Manual focus test
WinActivate("ahk_exe chrome.exe")
Sleep(100)
WinWaitActive("ahk_exe chrome.exe", , 2)

; Check if window is minimized
WinGet(&minMax, "MinMax", "ahk_exe chrome.exe")
if (minMax = -1) {
    MsgBox("Browser window minimized - restoring")
    WinRestore("ahk_exe chrome.exe")
}
```

---

### Issue: Recording Not Capturing Boxes

**Symptoms:**
- Drew boxes during recording, but event array empty
- Only keypresses captured, no boundingBox events
- Drag detected but no box created

**Possible Causes:**

1. **Drag Distance Below Threshold**
   - boxDragMinDistance too high
   - Small boxes not detected

2. **Mouse Hook Failed**
   - Hook not installed
   - mouseHook = 0

3. **Coordinates Outside Canvas**
   - Boxes drawn outside calibrated area
   - Clipping removes all boxes

**Solutions:**

```ahk
; Lower drag threshold
boxDragMinDistance := 5  ; Default: 10

; Check hook installation
if (mouseHook = 0) {
    MsgBox("Mouse hook not installed")
    ; Restart recording
}

; Log drag distances (debug)
; In MouseProc, add:
dragDistX := Abs(cursorX - dragStartX)
dragDistY := Abs(cursorY - dragStartY)
FileAppend("Drag dist: " dragDistX "x" dragDistY "`n", "drag_log.txt")

; Check canvas bounds
MsgBox("Canvas: " wideCanvas.left "," wideCanvas.top " → "
       wideCanvas.right "," wideCanvas.bottom)
```

---

### Issue: Degradation Assignment Wrong

**Symptoms:**
- All boxes assigned same degradation
- Keypresses not matched to boxes
- Auto-default always used

**Possible Causes:**

1. **Keypress Timing Issue**
   - Keypress too late, outside time window
   - nextBoxTime calculation wrong

2. **Multiple Keypresses**
   - Multiple keys pressed, only first matched
   - Keypress before first box

**Solutions:**

**Review vizlog_debug.txt:**
```
Box #1: time=86085125 nextBoxTime=86085671
  Searching for keyPress in window [86085125, 86085671)
  MATCHED keyPress deg=1 at time=86085296
  ASSIGNED deg=1 (user_selection)

Box #2: time=86085671 nextBoxTime=86086093
  Searching for keyPress in window [86085671, 86086093)
  No keyPress found
  ASSIGNED deg=1 (auto_default, inherited from previous)
```

**Adjust Keypress Timing:**
```ahk
; Press number key IMMEDIATELY after releasing mouse button
; Window is from box.time to nextBox.time
; If you press key before next box draw, it will be matched

; Recommended workflow:
; 1. Draw box (drag + release)
; 2. IMMEDIATELY press number key (within 500ms)
; 3. Draw next box
```

---

## Configuration Issues

### Issue: Config Not Persisting

**Symptoms:**
- Changed settings, but reset after restart
- Canvas calibration lost
- Timing values revert to defaults

**Possible Causes:**

1. **config.ini Not Writable**
   - File permissions issue
   - File locked by another process

2. **SaveConfig() Not Called**
   - Auto-save timer not set
   - Manual save required

**Solutions:**

```ahk
; Test file write
try {
    IniWrite("test", "config.ini", "Test", "value")
    result := IniRead("config.ini", "Test", "value")
    MsgBox("Write test: " result)
} catch as e {
    MsgBox("ERROR: Cannot write to config.ini`n" e.Message)
}

; Force save
SaveConfig()
SaveMacros()

; Check file timestamp
FileGetTime(&modTime, "config.ini", "M")
MsgBox("Config last modified: " modTime)
```

---

### Issue: Macros Disappear After Restart

**Symptoms:**
- Assigned macros, but gone after app restart
- config_simple.txt empty or missing

**Solutions:**

```ahk
; Check if config_simple.txt exists
if (!FileExist("config_simple.txt")) {
    MsgBox("config_simple.txt missing - creating empty file")
    FileAppend("", "config_simple.txt")
}

; Verify macros saved
content := FileRead("config_simple.txt")
MsgBox("Config content (first 500 chars):`n" SubStr(content, 1, 500))

; Manual save
SaveMacros()

; Check save timer
if (autoSaveTimer) {
    MsgBox("Auto-save timer active")
} else {
    MsgBox("Auto-save timer NOT active - setting up")
    SetTimer(() => SaveMacros(), 5000)
}
```

---

## Performance Issues

### Issue: High Memory Usage

**Symptoms:**
- Memory usage grows over time
- Application slow after many executions
- System lag during visualization

**Possible Causes:**

1. **HBITMAP Leaks**
   - Reference counting broken
   - HBITMAPs not freed

2. **Cache Unbounded**
   - Too many cached HBITMAPs
   - No cache eviction policy

**Solutions:**

```ahk
; Check cache size
MsgBox("Cached HBITMAPs: " hbitmapCache.Count)

; Check reference counts
totalRefs := 0
for hbitmap, refCount in hbitmapRefCounts {
    totalRefs += refCount
}
MsgBox("Total references: " totalRefs)

; Clear cache
InvalidateVisualizationCache()

; Restart app if memory still high
Reload
```

---

### Issue: UI Lag During Execution

**Symptoms:**
- GUI freezes when executing macro
- Stats recording blocks UI
- Delayed button click response

**Solutions:**

```ahk
; Ensure async recording used
; Check that RecordExecutionStatsAsync is called, not RecordExecutionStats

; Increase timer delay if needed
; In RecordExecutionStatsAsync:
SetTimer(() => DoRecordExecutionStatsBlocking(params), -100)  ; 100ms instead of 50ms

; Disable stats temporarily (debug)
; Comment out RecordExecutionStatsAsync call in ExecuteMacro
```

---

## Common Fixes

### Fix 1: Nuclear Reset (Preserve Macros)

**When to Use:** Major issues, but want to keep recorded macros

```ahk
; 1. Backup macros
FileCopy("config_simple.txt", "config_simple_backup.txt", 1)
FileCopy("data/master_stats_permanent.csv", "data/master_stats_permanent_backup.csv", 1)

; 2. Delete config.ini
FileDelete("config.ini")

; 3. Restart app
Reload

; 4. Recalibrate canvas
CalibrateCanvas("Wide")
CalibrateCanvas("Narrow")

; 5. Macros restored automatically from config_simple.txt
```

---

### Fix 2: Clean Stats Reset

**When to Use:** Stats corrupted, need fresh start

```ahk
; 1. Backup permanent archive
FileCopy("data/master_stats_permanent.csv",
         "data/master_stats_permanent_backup.csv", 1)

; 2. Delete all stats files
FileDelete("data/macro_execution_stats.csv")
FileDelete("data/stats_log.json")
FileDelete("data/stats_log.backup.json")

; 3. Restart app
Reload

; 4. Stats files recreated with headers
```

---

### Fix 3: Visualization Cache Clear

**When to Use:** Thumbnails not updating, old visuals displayed

```ahk
; Method 1: Programmatic
InvalidateVisualizationCache()
for buttonName in ["Num1", "Num2", "Num3", "Num4", "Num5", "Num6", "Num7", "Num8", "Num9"] {
    UpdateButtonAppearance(buttonName)
}

; Method 2: Restart app
Reload
```

---

### Fix 4: Force Canvas Recalibration

**When to Use:** Boxes consistently misaligned

```ahk
; 1. Reset calibration flags
isWideCanvasCalibrated := false
isNarrowCanvasCalibrated := false
SaveConfig()

; 2. Restart app
Reload

; 3. Recalibrate both modes
CalibrateCanvas("Wide")
CalibrateCanvas("Narrow")

; 4. Test with new recording
```

---

### Fix 5: Repair Stats CSV

**When to Use:** CSV corrupted with duplicate headers or malformed rows

```ahk
; 1. Load permanent archive
content := FileRead("data/master_stats_permanent.csv")
lines := StrSplit(content, "`n")

; 2. Find first header
headerLine := ""
dataLines := []
for line in lines {
    if (InStr(line, "timestamp,session_id")) {
        if (headerLine = "") {
            headerLine := line
        }
    } else if (line != "") {
        dataLines.Push(line)
    }
}

; 3. Rebuild file
FileDelete("data/master_stats_permanent.csv")
FileAppend(headerLine "`n", "data/master_stats_permanent.csv")
for line in dataLines {
    FileAppend(line "`n", "data/master_stats_permanent.csv")
}

; 4. Copy to display CSV
FileCopy("data/master_stats_permanent.csv",
         "data/macro_execution_stats.csv", 1)

; 5. Reload in-memory log
LoadStatsFromCSV()
```

---

### Fix 6: Debug Mode Enable

**When to Use:** Need detailed logs for troubleshooting

```ahk
; Add to top of script
global debugMode := true

; Add debug logging throughout code
if (debugMode) {
    FileAppend("ExecuteMacro called: " buttonName "`n", "debug_log.txt")
}

; Check logs
MsgBox(FileRead("debug_log.txt"))
```

---

### Fix 7: Hotkey Conflict Resolution

**When to Use:** Hotkeys not working, conflicts with other apps

```ahk
; List all registered hotkeys
Hotkey("List")

; Change conflicting hotkeys in config.ini
[Hotkeys]
hotkeyRecordToggle=CapsLock & r  ; Changed from CapsLock & f
hotkeyBreakMode=^+b               ; Changed from ^b

; Reload config
LoadConfig()
```

---

### Fix 8: Fresh Install (Preserve Nothing)

**When to Use:** Complete system failure, start from scratch

```ahk
; 1. Backup entire directory (optional)
; Copy "Mono10 - Copy" folder to "Mono10_Backup"

; 2. Delete all config and data files
FileDelete("config.ini")
FileDelete("config_simple.txt")
FileDelete("data/*.csv")
FileDelete("data/*.json")
FileDelete("vizlog_debug.txt")

; 3. Restart app
Reload

; 4. Fresh initialization
; - Calibrate canvas
; - Test recording
; - Verify stats
```

---

## Error Messages Reference

### "GDI+ Initialization Failed"
**Cause:** GDI+ DLL not loaded or startup failed
**Fix:** Restart app, check Windows updates

### "Invalid HBITMAP Handle"
**Cause:** HBITMAP deleted or never created
**Fix:** Invalidate cache, regenerate visualization

### "No Browser Window Found"
**Cause:** Chrome/Firefox/Edge not running
**Fix:** Open browser before executing macro

### "Stats CSV Corrupted"
**Cause:** Duplicate headers or malformed rows
**Fix:** Use Fix 5 (Repair Stats CSV)

### "Canvas Not Calibrated"
**Cause:** Canvas bounds not set (0,0,0,0)
**Fix:** Run CalibrateCanvas() for appropriate mode

### "Macro Event Array Empty"
**Cause:** Recording captured no events
**Fix:** Check hooks, lower drag threshold, try again

---

## Diagnostic Commands

### Check System Health
```ahk
; Run these commands to diagnose issues

; 1. Check GDI+
MsgBox("GDI+ Token: " gdiplusToken)

; 2. Check Canvas
MsgBox("Wide: " wideCanvas.left "," wideCanvas.top " → " wideCanvas.right "," wideCanvas.bottom
       "`nNarrow: " narrowCanvas.left "," narrowCanvas.top " → " narrowCanvas.right "," narrowCanvas.bottom)

; 3. Check Stats
MsgBox("Executions logged: " macroExecutionLog.Length)

; 4. Check Macros
MsgBox("Macros assigned: " macroEvents.Count)

; 5. Check Flags
MsgBox("Recording: " recording
       "`nPlayback: " playback
       "`nBreak mode: " breakMode
       "`nAwaiting assignment: " awaitingAssignment)
```

---

**END OF TROUBLESHOOTING GUIDE**
