# Tonight's Claude Code Session - Exact Implementation Steps
## Goal: Functional CSV Stats System in One Session

### Pre-Session Setup (5 minutes)

#### Step 1: Create Safety Net
```bash
# Navigate to your MacroMaster directory
cd "C:\path\to\your\MacroMaster"

# Initialize git and create baseline
git init
git add .
git commit -m "BASELINE: 4565-line working system before stats integration"
git tag v1.0-working-baseline

# Create backup outside git
copy MacroMasterClean.ahk MacroMasterClean_EMERGENCY_BACKUP.ahk

# Create CSV data directory
mkdir data
```

#### Step 2: Add CSV Structure Comment  
**Open MacroMasterClean.ahk and add this comment at the top (after #Requires)**:
```autohotkey
/*
CSV STRUCTURE: data/master_stats.csv
timestamp,session_id,username,execution_type,button_key,layer,execution_time_ms,bbox_count,degradation_assignments,severity_level,canvas_mode,session_active_time_ms,break_mode_active
*/
```

#### Step 3: Note Key Variables (Updated)
**Your actual system variables**:
- `currentUsername` - **doesn't exist, will create new**
- `breakMode` - **will create simple toggle for time tracking and usage control**  
- Session timing: `sessionTimer`, `lastSessionDuration`, `totalSessions`, `totalTime`
- Execution state: `playback`, `recording`

---

## Claude Code Session Implementation

### Phase 1: CSV Infrastructure (15 minutes)

#### Instruction 1: Create Global Variables (With Break Mode)
```
"Add these global variables at the top of MacroMasterClean.ahk (after existing globals):

global sessionId := ""
global masterStatsCSV := A_ScriptDir . "\data\master_stats.csv"  
global currentUsername := EnvGet("USERNAME")
global sessionStartTime := 0
global breakModeActive := false

Note: Use existing session timing variables (sessionTimer, totalTime) where possible.
Initialize sessionId on app start with format: sess_YYYYMMDD_HHMMSS
Initialize sessionStartTime with A_TickCount when app starts

Test: Script compiles and variables are accessible."
```

#### Instruction 2: Create CSV Functions (With Break Mode)
```
"Create these two functions in MacroMasterClean.ahk:

Function 1: InitializeCSVFile()
- Create data directory if doesn't exist  
- Create master_stats.csv with header row if file doesn't exist
- Header: timestamp,session_id,username,execution_type,button_key,layer,execution_time_ms,bbox_count,degradation_assignments,severity_level,canvas_mode,session_active_time_ms,break_mode_active

Function 2: AppendToCSV(timestamp, execution_type, button_key, layer, execution_time_ms, bbox_count, degradation_assignments, severity_level, canvas_mode)
- Calculate session_active_time_ms using existing totalTime variable
- Append row to CSV with all parameters plus sessionId, currentUsername, and breakModeActive
- Handle file access errors gracefully (try/catch)

Test: Call InitializeCSVFile() manually and verify CSV created with proper header including break_mode_active column."
```

### Phase 2: ExecuteMacro Integration (20 minutes)

#### Instruction 3: Find ExecuteMacro Entry Point
```
"Locate ExecuteMacro() function in MacroMasterClean.ahk.

Task: Find the exact location where macro execution completes successfully.
Look for: areas where macro playback finishes, JSON profile execution completes.

Add execution tracking at these completion points:
- Call RecordExecutionStats(macroKey, executionStartTime, executionType, events)
- executionType should be 'macro' or 'json_profile' based on execution path
- Do NOT modify any existing execution logic

Test: ExecuteMacro() still works exactly as before, no functionality broken."
```

#### Instruction 4: Create Execution Tracking Function (With Break Mode)
```
"Create RecordExecutionStats() function in MacroMasterClean.ahk:

Parameters: macroKey, executionStartTime, executionType, events

Function logic:
1. Skip if breakModeActive is true (don't track during break) - return early
2. Skip if currently recording or playback is active (avoid double-tracking)
3. Calculate execution_time_ms = A_TickCount - executionStartTime  
4. Get current layer from existing layer variable
5. For execution_type 'macro': count bounding boxes from events, get degradation assignments
6. For execution_type 'json_profile': bbox_count=0, degradation_assignments="", get severity from current settings
7. Get canvas_mode from existing wide/narrow toggle variable
8. Call AppendToCSV() with all data

Test: Execute one macro and verify CSV gets new row. Toggle breakModeActive=true and verify no CSV row gets added."
```

### Phase 3: Degradation Logic Integration (20 minutes)

#### Instruction 5: Extract Degradation Assignments
```
"Find and modify MacroExecutionAnalysis() function to return degradation assignments string.

Current function analyzes bbox events and detects keypresses 1-9.
Required modification: Return comma-separated degradation string for CSV.

Degradation mapping:
1=smudge, 2=glare, 3=splashes, 4=partial_blockage, 5=full_blockage, 6=light_flare, 7=rain, 8=haze, 9=snow

Logic implementation:
- First box defaults to 'smudge' if no keypress
- Track last assigned degradation type
- New keypress (1-9) changes current degradation for subsequent boxes  
- Return format: 'smudge,partial_blockage,smudge' for 3 boxes

Test: Record macro with 3 boxes, assign keys 2,5,2, verify function returns 'glare,full_blockage,glare'."
```

#### Instruction 6: Integrate Degradation Detection
```
"Modify RecordExecutionStats() to use degradation assignments from MacroExecutionAnalysis().

For execution_type 'macro':
- Call modified MacroExecutionAnalysis(events) to get degradation string
- Pass degradation string to AppendToCSV()

For execution_type 'json_profile':
- degradation_assignments = '' (empty string)
- Get severity_level from current JSON profile settings

Test: Execute macro with degradations → CSV shows degradation assignments
Execute JSON profile → CSV shows severity level."
```

### Phase 4: Stats Display Integration (15 minutes)

#### Instruction 7: Find Stats Display Function
```
"Find current stats display function (search for 'ShowStats', 'Statistics', 'Analytics' in function names).

Identify where stats data is currently read from (likely broken JSON operations).
Note the UI elements that display stats (text controls, listviews, etc.).

Do NOT modify the display function yet - just identify the location and current data source.

Report: Function name and line number of main stats display function."
```

#### Instruction 8: Create CSV Reading Function
```
"Create ReadStatsFromCSV() function that calculates all stats from master_stats.csv:

Calculate for current session (matching sessionId):
- Total executions (count rows)
- Total boxes (sum bbox_count) 
- Boxes per hour = total_boxes / (session_active_time_ms / 3600000)
- Executions per hour = total_executions / (session_active_time_ms / 3600000)
- Average execution time = average of execution_time_ms
- Degradation breakdown = count each type, calculate percentages
- Most used button = mode of button_key
- Most active layer = mode of layer

Return: Map object with all calculated stats

Test: Call function and verify it returns reasonable numbers from CSV data."
```

### Phase 5: Final Integration & Testing (15 minutes)

#### Instruction 9: Replace Stats Data Source
```
"Modify the stats display function identified in step 7.

Replace current data source (broken JSON reading) with ReadStatsFromCSV().
Update all UI elements to display stats from CSV calculations.
Keep exact same display format and UI layout.

Test: Open stats menu and verify it shows accurate data from CSV file."
```

#### Instruction 10: Add Break Mode Toggle Function
```
"Create simple break mode toggle function in MacroMasterClean.ahk:

Function: ToggleBreakMode()
- Toggle breakModeActive between true/false
- Update UI status bar or indicator to show break mode state
- When break starts: show 'BREAK MODE ACTIVE' status
- When break ends: show 'ACTIVE' or normal status
- Optional: Add visual indicator (button color change, status text)

Add hotkey for break mode toggle (suggest Ctrl+B or similar):
Ctrl+B::ToggleBreakMode()

Test: Toggle break mode → UI shows break status → execute macro → verify no CSV tracking → toggle off → execute macro → verify CSV tracking resumes."
```

#### Instruction 11: Final Testing Integration (With Break Mode)
```
"Add session initialization to app startup:

Find the application initialization section (likely near the start of the script).
Add calls to:
- Initialize sessionId with current timestamp  
- Call InitializeCSVFile()
- Set sessionStartTime
- Initialize breakModeActive = false

Verify the complete integration:
1. App starts → sessionId created, CSV initialized, break mode off
2. Macro execution → CSV row written with accurate data
3. Toggle break mode → macro execution blocked from tracking
4. Toggle break mode off → tracking resumes
5. Stats display → reads from CSV and shows current data
6. App restart → data persists and new session begins

Test: Complete workflow including break mode functionality works correctly."
```

---

## Testing Protocol (After Each Phase)

### Quick Validation Commands (Optional)
```autohotkey
; Add these test hotkeys temporarily if helpful for testing
; F10::TestCSVSystem()
; F11::ShowCurrentStats()

TestCSVSystem() {
    ; Quick verification  
    MsgBox("Session ID: " . sessionId . "`nUsername: " . currentUsername . "`nCSV exists: " . FileExist(masterStatsCSV))
}

ShowCurrentStats() {
    ; Display current CSV stats
    stats := ReadStatsFromCSV()
    MsgBox("Total executions: " . stats["total_executions"] . "`nTotal boxes: " . stats["total_boxes"])
}
```

### Full System Test Sequence (With Break Mode)
**Run after all phases complete**:
1. **Record test macro** with 3 bounding boxes on your actual labeling data
2. **Assign degradations** with keys 2, 5, 2 (glare, full_blockage, glare) during recording  
3. **Execute macro** → check CSV for new row with "glare,full_blockage,glare"
4. **Toggle break mode ON** → execute macro → verify NO CSV row added (break mode working)
5. **Toggle break mode OFF** → execute macro → verify CSV row added (tracking resumed)
6. **Execute JSON profile** with severity level (high/medium/low) → check CSV for json_profile row
7. **Open stats menu** → verify accurate boxes per hour, execution stats displayed
8. **Close and reopen program** → verify all stats persist and new session starts
9. **Test break mode visual indicator** → verify UI shows break status clearly

---

## Emergency Recovery Procedures

### If Script Won't Compile
```bash
git status                    # See what files changed
git diff                      # Review specific changes
git checkout -- MacroMasterClean.ahk  # Restore to last working version
```

### If Functionality Breaks
```bash
git reset --hard HEAD~1       # Undo last change
# Test functionality, then continue from previous step
```

### If Everything Fails
```bash
git reset --hard v1.0-working-baseline
# Or: copy MacroMasterClean_EMERGENCY_BACKUP.ahk back to MacroMasterClean.ahk
```

### Partial Success Recovery
**If you get partway through but run out of time**:
```bash
git add .
git commit -m "PARTIAL IMPLEMENTATION: [describe what works]"
git tag v1.1-partial-stats
```

This saves progress for next session.

---

## Session Success Criteria

### Minimum Success (Worth celebrating)
- ✅ CSV file gets created and populated  
- ✅ Macro executions write to CSV with basic data
- ✅ Stats persist across app restart
- ✅ Existing functionality still works

### Complete Success (Full goal achieved)  
- ✅ Both macro and JSON profile executions tracked accurately
- ✅ Degradation assignments captured correctly (glare,full_blockage,glare format)
- ✅ Stats menu shows accurate real-time data from CSV
- ✅ Username tracking included automatically  
- ✅ Session management working (new session on restart)
- ✅ Break mode toggle working (pause/resume tracking and prevent unintended use)
- ✅ System ready for immediate production use and future enhancements

### Super Success (Beyond expectations)
- ✅ Real-time stats updates during labeling sessions
- ✅ Advanced degradation combination analysis working
- ✅ Break mode with clear visual indicators and UI feedback
- ✅ Performance optimized for 1000+ daily executions
- ✅ Robust error handling and file access management

---

## Final Pre-Session Checklist

- [ ] Git repository initialized with baseline commit
- [ ] Emergency backup file created outside git  
- [ ] CSV structure comment added to file (including break_mode_active)
- [ ] Key variables identified: sessionTimer, totalTime, playbook, recording
- [ ] currentUsername variable will be created (doesn't exist)
- [ ] breakModeActive variable will be created for simple toggle functionality
- [ ] Claude Code ready with revised Instructions 1-11
- [ ] Optional testing hotkeys prepared (F10, F11)
- [ ] Recovery procedures understood

**You're ready for success!** The complete approach includes break mode for proper time tracking control and usage prevention. This gives you professional-grade functionality while maintaining system safety.

**Start with Instruction 1 and work through sequentially. Test after each phase. Don't skip the testing - it's what will save you from problems later.**