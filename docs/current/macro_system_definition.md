# Macro Labeling System - Complete Specification & Cleanup Plan
## Critical: System Stabilization & Legacy Code Removal

---

## 🎯 CORE PROBLEM SUMMARY

**Current State:** Scattered system with legacy code causing freezes, incomplete persistence, and competing subsystems

**Desired State:** Clean, fast, reliable labeling system with 1-3 second execution times and zero freezing

---

## 🔴 CRITICAL ISSUES (In Priority Order)

### 1. **STATS SYSTEM FREEZE** - HIGHEST PRIORITY
**Symptom:** Freezes after 3 rapid macro executions, long freeze times, eventually recovers
**Root Cause:** Synchronous stats writing blocking execution thread
**Location:** `StatsData.ahk` - CSV writing operations

**Impact:** Complete workflow disruption - cannot execute macros rapidly

**Solution Requirements:**
```
✅ Stats must write FULLY ASYNC (no blocking)
✅ Queue must handle 20+ rapid executions without blocking
✅ Failed writes should be dropped, not queued forever
✅ Max write time: 100ms per batch, then abort
✅ Zero impact on execution performance
```

**Working Version Reference:** Stats system from commit `9a93a12` (alongside visualization snapshot)

---

### 2. **CONFIG NOT SAVING INTELLIGENT TIMING ATTRIBUTES**
**Symptom:** Macros stop after bounding boxes draw, don't reach intelligent timing system
**Root Cause:** New macro attributes not persisted in config

**Missing from Config:**
- `event.degradationType` on each boundingBox event
- `event.assignedBy` ("user_selection" or "auto_default")
- Intelligent system state (last used degradation per layer)
- `recordedMode` ("Wide" or "Narrow")

**Solution Requirements:**
```ahk
// Config must save:
[Macros]
Num7_events=[...] // Full event array with ALL properties
Num7_mode=Wide
Num7_intelligentState=3  // Last degradation used

[IntelligentSystem]
lastDegradation=3  // Global state (single layer system)
```

---

### 3. **VISUALIZATIONS NOT SHOWING ON REOPEN**
**Symptom:** Button thumbnails blank after close/reopen, macros still work
**Root Cause:** Visualization system not regenerating on load, or HBITMAP handles lost

**Solution Requirements:**
```
✅ On LoadConfig(), regenerate ALL visualizations
✅ Use HBITMAP method ONLY (from snapshot commit 9a93a12)
✅ Cache invalidation on config load
✅ Verify GDI+ initialization before viz generation
```

---

### 4. **FIRST CLICK 20% FAILURE RATE**
**Symptom:** Mouse click doesn't register, proceeds with movements only
**Occurs:** Randomly, ~80% success rate

**Solution Requirements:**
```
✅ Mouse state initialization BEFORE hook install
✅ Click validation (ensure mouseDown before moves)
✅ 50ms debounce on first click
✅ Hook reliability check on recording start
```

---

### 5. **MULTIPLE COMPETING SYSTEMS (Legacy Code)**
**Problems Identified:**
- Text/PNG/HBITMAP visualizations competing
- Multiple stats recording systems
- Background timers causing performance issues
- Duplicate functions/legacy code paths

**Solution:** **REMOVE ALL LEGACY - Single clean path for each system**

---

## 📋 DESIRED SYSTEM ARCHITECTURE

### **Simplified Single-Layer System**

```
┌─────────────────────────────────────────────────┐
│           SINGLE LAYER - 12 BUTTONS             │
├─────────────────────────────────────────────────┤
│  Num7   Num8   Num9   (Row 1)                   │
│  Num4   Num5   Num6   (Row 2)                   │
│  Num1   Num2   Num3   (Row 3)                   │
│  Num0   NumDot NumMult (Row 4)                  │
└─────────────────────────────────────────────────┘

✅ REMOVE: Layer system entirely (Layers 1-5)
✅ REMOVE: Layer switching UI
✅ REMOVE: Per-layer state management complexity
✅ KEEP: 12 macro slots (sufficient for workflow)
```

**Benefits:**
- 80% reduction in state management complexity
- Simpler config structure
- Easier debugging
- Faster execution

---

### **Clean State Machine**

```
IDLE STATE
  │
  ├→ F9 Press → RECORDING
  │               │
  │               └→ Draw boxes with intelligent degradation assignment
  │                   │
  │                   └→ F9 Press → SAVE TO CONFIG → IDLE
  │
  └→ Button Press → EXECUTE (NO CLEANUP DELAY)
                      │
                      └→ Stats written ASYNC → IMMEDIATE IDLE
```

**Key Requirements:**
- Zero delay between macro completion and next execution
- Stats write in background (never blocks)
- Config saves are fast (<50ms) or async

---

### **Intelligent Degradation System (Simplified)**

```
GLOBAL STATE (Single Layer):
- currentDegradation = 1 (Smudge default)

DURING RECORDING:
1. Box drawn → Wait 200ms
2. IF numpad pressed → currentDegradation = that number
3. ELSE → Use currentDegradation
4. Assign to box event

PERSISTENCE:
- currentDegradation saved in config
- Each box event has degradationType property
- On reload, restore currentDegradation state
```

**Simplified from multi-layer system:**
- Single global state instead of 5 layer states
- Easier to debug and maintain
- Still maintains user workflow

---

## 🗑️ LEGACY CODE TO REMOVE

### **Complete Removal List:**

#### 1. **Multi-Layer System**
```
REMOVE FROM:
- Config.ahk: Layer 1-5 variables, layerNames, layerBorderColors
- GUI: Layer switching buttons/UI
- All functions with "Layer" in name
- currentLayer global variable

REPLACE WITH:
- Single button namespace (just "Num7", not "L1_Num7")
- Simplified config structure
```

#### 2. **Plotly/Python/SQL Systems**
```
REMOVE FILES:
- Any .py Python scripts
- Plotly dashboard code
- SQL database connections
- Real-time dashboard ingestion

REMOVE FROM:
- StatsData.ahk: All Python/SQL references
- Config.ahk: Dashboard URL settings
- Any HTTP/API calls

KEEP ONLY:
- CSV stats writing (master_stats_permanent.csv)
- CSV stats reading for display
```

#### 3. **Competing Visualization Systems**
```
REMOVE:
- Text-based visualization code
- PNG visualization (except as emergency fallback)
- All visualization methods except HBITMAP

KEEP ONLY:
- HBITMAP in-memory system (from commit 9a93a12)
- Emergency PNG fallback IF HBITMAP fails
- GDI+ initialization

FROM VisualizationCore.ahk:
- Remove text rendering methods
- Simplify to HBITMAP primary + PNG emergency only
```

#### 4. **Redundant Stats Systems**
```
AUDIT AND CONSOLIDATE:
- Multiple RecordExecutionStats() functions?
- Duplicate CSV writing logic?
- Old stats persistence methods?

KEEP ONLY:
- Single async queue system
- One CSV format (streamlined schema)
- Master permanent file + daily file
```

#### 5. **Unused Features**
```
REMOVE IF NOT USED:
- Auto-execution mode (if unused)
- Complex timing preset systems (keep simple defaults)
- Diagnostic/debug GUI panels (use logging instead)
- Old canvas calibration methods (keep current only)
```

---

## 🏗️ CLEAN SYSTEM STRUCTURE

### **Config File Structure (Simplified)**

```ini
[Settings]
annotationMode=Wide
currentDegradation=1
# ... other settings ...

[Canvas]
wideCanvas=100,50,1820,1030
narrowCanvas=200,100,1720,980

[Macros]
Num7_events=[{"type":"mouseDown",...},{"type":"boundingBox","degradationType":3,...}]
Num7_mode=Wide
Num7_label=Custom Label

Num8_events=[...]
Num8_mode=Narrow
Num8_label=Another Label

# ... all 12 buttons ...

[Stats]
# No stats in config - read from CSV only
```

**Key Changes:**
- No layer prefixes (L1_, L2_, etc.)
- Simplified structure
- Intelligent state at root level
- All event properties included

---

### **Stats System (CSV Only)**

```
SINGLE FILE: master_stats_permanent.csv
SCHEMA: timestamp, session_id, username, button_key, execution_time_ms, 
        total_boxes, smudge_count, glare_count, splashes_count, 
        partial_blockage_count, full_blockage_count, light_flare_count,
        rain_count, haze_count, snow_count, clear_count, 
        canvas_mode, annotation_details

ASYNC QUEUE SYSTEM:
- Queue size: 50 (up from 10)
- Flush interval: 500ms
- Max write time: 100ms (then abort)
- Overflow strategy: Drop oldest

DISPLAY:
- Daily stats: Filter by today's date
- Lifetime stats: All rows
- Read on demand (not in memory)
```

**NO Python, NO SQL, NO HTTP - Pure CSV**

---

### **Visualization System (HBITMAP Only)**

```
PRIMARY: HBITMAP in-memory (from commit 9a93a12)
FALLBACK: PNG to workDir ONLY if HBITMAP fails

LOCATIONS (In Order):
1. workDir (Documents/MacroMaster/data) - ONLY location

CACHE:
- HBITMAP handles cached in Map
- Cache key: events + dimensions + mode
- Regenerate on config load

ON LOAD:
1. LoadConfig()
2. For each button with events:
   - CreateHBITMAPVisualization()
   - Set button.picture.Value
3. Verify GDI+ initialized first
```

**NO text rendering, NO multiple fallback paths - One clean approach**

---

## 🔧 IMPLEMENTATION PLAN

### **Phase 1: Remove Legacy Code (60 min)**

```
STEP 1: Layer System Removal
□ Remove all Layer 1-5 variables from Config.ahk
□ Remove layer UI from GUI creation
□ Update all macroEvents Map keys (remove "L1_" prefix)
□ Update SaveConfig/LoadConfig to remove layer logic
□ Test: Record macro, save, reload - should work with simple keys

STEP 2: Remove Plotly/Python/SQL
□ Delete all .py files
□ Remove dashboard code from StatsData.ahk
□ Remove HTTP/API calls
□ Remove SQL references
□ Test: Stats still write to CSV

STEP 3: Simplify Visualization
□ Keep only HBITMAP code in VisualizationCore.ahk
□ Remove text rendering methods
□ Simplify PNG fallback to single path (workDir)
□ Test: Visualizations still generate

STEP 4: Consolidate Stats
□ Find duplicate RecordExecutionStats() calls
□ Remove old stats persistence methods
□ Keep only async queue system
□ Test: Stats write without freezing
```

### **Phase 2: Fix Critical Issues (90 min)**

```
STEP 1: Stats Freeze Fix
□ Verify async queue from commit 9a93a12
□ Increase queue size to 50
□ Add write timeout (100ms max)
□ Add overflow protection (drop oldest)
□ Remove any blocking file operations
□ Test: Execute 20 macros rapidly - no freeze

STEP 2: Config Persistence Fix
□ Add degradationType to event serialization
□ Add currentDegradation to config root
□ Add recordedMode to each macro
□ Verify LoadConfig() restores all properties
□ Test: Save → Close → Reopen → Execute → Should work completely

STEP 3: Visualization Restoration
□ Add viz regeneration to LoadConfig()
□ Verify GDI+ initialization before viz
□ Clear HBITMAP cache on load
□ Regenerate all button thumbnails
□ Test: Close → Reopen → All thumbnails show

STEP 4: First Click Reliability
□ Initialize mouse state before hook install
□ Add click validation (mouseDown before moves)
□ Add 50ms debounce on recording start
□ Add first-event logging for debugging
□ Test: Rapid F9 starts - all clicks register
```

### **Phase 3: Testing & Validation (30 min)**

```
TEST SUITE:
1. Rapid Execution Test
   - Record macro with 5 boxes
   - Execute 20 times rapidly
   - NO FREEZING - stats write async
   - All stats accurate in CSV

2. Persistence Test
   - Record macro with intelligent system
   - Save and close
   - Reopen application
   - Thumbnails show correctly
   - Execute works completely
   - Stats accurate

3. First Click Test
   - Press F9
   - Immediately click (10 times)
   - All clicks register correctly
   - Box drawing starts properly

4. Performance Test
   - 10-box macro execution time: 1-3 seconds
   - Total workflow time: ~5 seconds
   - Zero delay between executions
```

---

## 📊 SUCCESS CRITERIA

### **Must Work Perfectly:**
1. ✅ Execute 20 macros rapidly with ZERO freezing
2. ✅ Execution time: 1-3 seconds per macro
3. ✅ Zero delay between macro completion and next execution
4. ✅ Stats accurate in CSV (verified manually)
5. ✅ Config persists ALL data across sessions
6. ✅ Visualizations show on reopen
7. ✅ First click registers 95%+ of the time
8. ✅ Intelligent system state persists

### **Performance Targets:**
- Macro execution: 1-3 seconds (10 boxes)
- Config save: <50ms
- Stats write: Async, zero blocking
- Visualization generation: <10ms cached, <100ms fresh
- Total workflow: ~5 seconds per image labeled

### **Reliability Targets:**
- Zero freezes during normal operation
- 95%+ first click success rate
- Config corruption: Auto-rebuild, no data loss
- Offline operation: 100% (no network required)

---

## 🎯 SIMPLIFIED FEATURE SET

### **KEEP:**
- ✅ Single layer (12 buttons)
- ✅ Intelligent degradation system (simplified)
- ✅ Canvas calibration (both Wide + Narrow)
- ✅ Break mode (for stat accuracy)
- ✅ WASD labels (macro activation)
- ✅ CSV stats (daily + lifetime)
- ✅ HBITMAP visualization
- ✅ Fast execution with smart timing
- ✅ Config persistence

### **REMOVE:**
- ❌ Multi-layer system (Layers 1-5)
- ❌ Plotly/Python/SQL dashboards
- ❌ Text/PNG visualization fallbacks (except emergency)
- ❌ Auto-execution mode (if unused)
- ❌ Complex timing presets (use simple defaults)
- ❌ Real-time data ingestion
- ❌ HTTP/API calls
- ❌ Legacy stats systems

---

## 🔍 KEY FILES TO MODIFY

### **High Priority:**
1. `StatsData.ahk` - Fix async queue, remove legacy
2. `Config.ahk` - Simplify to single layer, add intelligent state
3. `ConfigIO.ahk` - Fix serialization, add all event properties
4. `VisualizationCore.ahk` - HBITMAP only, remove text/PNG
5. `MacroRecording.ahk` - Fix first click reliability
6. `Core.ahk` - Remove layer system, simplify initialization

### **Medium Priority:**
7. `MacroExecution.ahk` - Ensure intelligent timing attributes used
8. `VisualizationCanvas.ahk` - Simplify, ensure regeneration on load
9. `GUI.ahk` - Remove layer UI, simplify to 12 buttons

### **Low Priority:**
10. Remove any Python/SQL files
11. Clean up unused functions
12. Remove diagnostic/debug GUIs

---

## 💡 DEBUGGING STRATEGY

### **Enable Minimal Logging:**
```ahk
// Add to critical points only:
FileAppend(A_Now . " - " . message . "`n", A_ScriptDir . "\debug.log")

// Log locations:
1. Stats queue flush start/end
2. Config save/load complete
3. Macro execution start/end
4. Visualization generation
5. First mouse click in recording
```

### **Performance Monitoring:**
```ahk
// Wrap critical sections:
startTime := A_TickCount
// ... operation ...
elapsed := A_TickCount - startTime
if (elapsed > 100) {
    FileAppend("SLOW: " . functionName . " took " . elapsed . "ms`n", "perf.log")
}
```

---

## 🚀 POST-CLEANUP SYSTEM

### **Final Architecture:**
```
┌─────────────────────────────────────────────────┐
│              CLEAN SYSTEM                       │
├─────────────────────────────────────────────────┤
│  12 Buttons (Single Layer)                      │
│  HBITMAP Visualization Only                     │
│  Async CSV Stats (No Freeze)                    │
│  Intelligent Degradation (Simplified)           │
│  Fast Config Persistence                        │
│  Zero Inter-Execution Delay                     │
└─────────────────────────────────────────────────┘

EXECUTION FLOW:
Button Press → Execute (1-3s) → Async Stats Write → IMMEDIATE READY

NO LAYERS | NO PYTHON | NO SQL | NO DELAYS
```

### **Code Cleanliness:**
- Single clear path for each system
- No competing implementations
- No legacy code paths
- Minimal background processes
- Fast and reliable

---

## 📌 CRITICAL REMINDERS FOR IMPLEMENTATION

1. **Commit 9a93a12 is your baseline** - Stats + Viz both worked
2. **Test after EACH phase** - Don't compound problems
3. **Manual testing workflow** - Record → Save → Close → Reopen → Execute
4. **Focus on speed** - Zero delays, async everything
5. **Remove don't disable** - Delete legacy code, don't comment it out
6. **Simplify ruthlessly** - If it's not essential, remove it
7. **One layer only** - Massive simplification, don't overthink it

---

## 🎉 EXPECTED OUTCOME

After cleanup, you should have:
- ✅ Clean, maintainable codebase
- ✅ 20+ rapid executions without freezing
- ✅ 1-3 second execution times
- ✅ Perfect config persistence
- ✅ Working visualizations on reopen
- ✅ 95%+ first click success
- ✅ Accurate stats tracking
- ✅ Zero inter-execution delays
- ✅ Simplified single-layer system
- ✅ Offline operation

**Total reduction:** ~40% less code, 80% less complexity, 100% more reliable
