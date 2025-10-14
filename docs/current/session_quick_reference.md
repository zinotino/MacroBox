# Tonight's Coding Session - Quick Reference Card

## 🎯 PRIMARY GOALS
1. **Fix stats freeze** (max 3 executions before freeze)
2. **Fix config persistence** (macros stop after boxes)
3. **Remove legacy code** (layers, Python, competing systems)

---

## ⚡ CRITICAL FILES TO MODIFY

### High Priority:
- `StatsData.ahk` - Queue size 10→50, add timeout
- `Config.ahk` - Remove layers, add currentDegradation
- `ConfigIO.ahk` - Save/load degradationType in events
- `MacroRecording.ahk` - Add 50ms delay, debounce clicks
- `VisualizationCore.ahk` - HBITMAP only (from commit 9a93a12)

### Medium Priority:
- `Core.ahk` - Remove layer init, simplify
- `GUI.ahk` - Remove layer UI

---

## 🔴 ISSUE #1: STATS FREEZE (30 min)

**File:** `StatsData.ahk`

**Changes:**
```ahk
// Line ~15: Change queue size
global statsQueueMaxSize := 50  // Was 10

// Add to FlushStatsQueue() - line ~45:
flushStartTime := A_TickCount

// Inside flush loop:
if (A_TickCount - flushStartTime > 100) {
    break  // Timeout after 100ms
}

// Add to AppendToCSV() - line ~25:
if (statsWriteQueue.Length >= statsQueueMaxSize) {
    statsWriteQueue.RemoveAt(1)  // Drop oldest
}
```

**Test:** Execute 20 macros rapidly → NO FREEZE

---

## 🔴 ISSUE #2: CONFIG NOT PERSISTING (40 min)

**Files:** `Config.ahk`, `ConfigIO.ahk`

**Config.ahk - Add:**
```ahk
// Line ~80:
global currentDegradation := 1  // Single global state
```

**ConfigIO.ahk - SaveConfig():**
```ahk
// Add to [Settings] section:
configContent .= "currentDegradation=" . currentDegradation . "`n"

// Change macro loop from:
for layer in 1..5 {
    for buttonName in buttonNames {
        layerKey := "L" . layer . "_" . buttonName
        
// To:
for buttonName in buttonNames {
    if (macroEvents.Has(buttonName)) {
        // Save with simple key (no "L1_")
```

**Verify SerializeEvents() includes:**
- `degradationType`
- `degradationName`  
- `assignedBy`

**Test:** Record → Save → Close → Reopen → Execute → Should complete fully

---

## 🔴 ISSUE #3: REMOVE LAYERS (60 min)

**Search and Replace:**
```bash
# Find all instances:
grep -r "currentLayer" src/
grep -r '"L" . currentLayer' src/
grep -r "layerMacroName" src/

# Replace with single-layer keys:
# "L1_Num7" → "Num7"
```

**Remove from Config.ahk:**
- `currentLayer`
- `totalLayers`
- `layerNames`
- `layerBorderColors`

**Remove from GUI.ahk:**
- Layer switching buttons
- Layer display text

**Update all macroEvents Map keys:**
```ahk
// OLD: macroEvents["L1_Num7"]
// NEW: macroEvents["Num7"]
```

**Test:** Record on Num7, save, reload, execute → Should work

---

## 🔴 ISSUE #4: VISUALIZATIONS NOT SHOWING (20 min)

**File:** `Core.ahk` / `ConfigIO.ahk`

**Add to LoadConfig():**
```ahk
// After loading all macros:
RefreshAllButtonAppearances()
```

**Verify RefreshAllButtonAppearances():**
```ahk
RefreshAllButtonAppearances() {
    if (!gdiPlusInitialized) {
        InitializeVisualizationSystem()
    }
    
    // Clear cache to force regeneration
    CleanupHBITMAPCache()
    global hbitmapCache := Map()
    
    for buttonName in buttonNames {
        UpdateButtonAppearance(buttonName)
    }
}
```

**Test:** Save → Close → Reopen → Thumbnails should show

---

## 🔴 ISSUE #5: FIRST CLICK RELIABILITY (30 min)

**File:** `MacroRecording.ahk`

**ForceStartRecording():**
```ahk
// Add before InstallMouseHook():
CoordMode("Mouse", "Screen")
MouseGetPos(&initX, &initY)
Sleep(50)  // 50ms delay
```

**MouseProc() - Add debouncing:**
```ahk
static lastClickTime := 0

if (wParam = WM_LBUTTONDOWN) {
    // Debounce
    if (timestamp - lastClickTime < 50) {
        return DllCall("CallNextHookEx", ...)
    }
    lastClickTime := timestamp
    // ... rest of code
}
```

**Test:** Press F9, immediately click 10 times → 9/10 should register

---

## 🗑️ REMOVE COMPLETELY

### Files to Delete:
- All `.py` files
- SQL database files
- Plotly scripts

### Code to Remove:
```ahk
// From StatsData.ahk:
- ingestionServiceUrl
- realtimeEnabled
- SendDataToIngestion()
- HTTP/API calls

// From VisualizationCore.ahk:
- Text rendering methods
- Multiple PNG fallback paths (keep one emergency)

// From everywhere:
- Layer switching logic
- Per-layer state tracking
```

---

## ✅ TESTING CHECKLIST

After each change, run these tests:

### Test 1: Stats Freeze
```
1. Execute macro 20 times rapidly
2. Check for freezing
3. Verify CSV has 20 rows
4. Check UI responsive
```

### Test 2: Config Persistence
```
1. Record macro with intelligent system
2. Save and close app
3. Reopen app
4. Check thumbnail shows
5. Execute macro - should complete fully
6. Verify stats accurate
```

### Test 3: First Click
```
1. Press F9
2. Click immediately 10 times
3. Check success rate (aim for 9/10)
```

### Test 4: Performance
```
1. Time 10-box macro execution
2. Should be 1-3 seconds
3. No freeze after
4. Ready immediately for next execution
```

---

## 📊 SUCCESS METRICS

Must achieve tonight:
- ✅ 20 rapid executions, no freeze
- ✅ Config persists all data
- ✅ Thumbnails show on reopen
- ✅ Execution time 1-3 seconds
- ✅ First click 90%+ success
- ✅ Layers removed
- ✅ Python/SQL removed

---

## 🐛 DEBUGGING QUICK CHECKS

**If stats freeze:**
```ahk
// Check queue size:
FileAppend("Queue: " . statsWriteQueue.Length . "`n", "debug.log")

// Time flush:
FileAppend("Flush start: " . A_TickCount . "`n", "debug.log")
```

**If config not persisting:**
```ahk
// Check events saved:
FileAppend(SerializeEvents(events), "events_debug.txt")

// Check loaded events:
for event in events {
    FileAppend("Type: " . event.type . ", degType: " . event.degradationType . "`n", "load_debug.log")
}
```

**If viz not showing:**
```ahk
// Check GDI+:
FileAppend("GDI: " . gdiPlusInitialized . "`n", "viz_debug.log")

// Check HBITMAP:
FileAppend("Handle: " . hbitmap . "`n", "viz_debug.log")
```

---

## 📋 IMPLEMENTATION ORDER

Execute in this order, test after each:

1. ✅ Stats freeze fix (30 min)
2. ✅ Remove Python/SQL (20 min)  
3. ✅ Remove layers (60 min)
4. ✅ Config persistence (40 min)
5. ✅ Visualization restoration (20 min)
6. ✅ First click fix (30 min)
7. ✅ Full integration test (30 min)

**Total: ~3.5 hours**

---

## 🔍 BASELINE REFERENCE

**Working Commit:** `9a93a12`
- Visualization verified working
- Stats verified working
- Use as reference for working code

**Stable Files (Don't Modify Unless Necessary):**
- `VisualizationCore.ahk` (lines 162-265)
- `VisualizationCanvas.ahk`
- `VisualizationUtils.ahk`

---

## 🚨 CRITICAL REMINDERS

1. **Test after each change** - Don't compound problems
2. **Use commit 9a93a12 as reference** - It works
3. **Remove, don't disable** - Delete legacy code completely
4. **Single layer only** - Massive simplification
5. **HBITMAP only** - Don't complicate visualizations
6. **Async stats** - Never block execution thread

---

## 💾 COMMIT AFTER EACH PHASE

```bash
git add -A
git commit -m "FIX: Stats freeze - queue size and timeout"
# Test...

git add -A  
git commit -m "REMOVE: Multi-layer system"
# Test...
```

**Final tag:**
```bash
git tag -a v3.0-stable -m "Clean single-layer system"
```

---

## 🎉 EXPECTED OUTCOME

After tonight:
- ✅ Fast, reliable execution (1-3s)
- ✅ No freezing (20+ executions)
- ✅ Perfect persistence
- ✅ Working visualizations
- ✅ Accurate stats
- ✅ 40% less code
- ✅ Ready for production use

**Good luck! 🚀**
