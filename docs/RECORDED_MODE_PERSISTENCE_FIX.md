# Recorded Mode Persistence Fix

## Issue

All macros were restoring to Narrow visualizations when reopening the program, regardless of which mode they were actually recorded in.

**Root Cause**: The `recordedMode` property was not being saved to or loaded from the config file.

## Solution

Implemented save and load for `recordedMode` property in the config file.

## Implementation

### 1. Save `recordedMode` to Config

**File**: `src/ConfigIO.ahk`

**Location**: Lines 158-161 (after saving macro events)

```ahk
; Save recordedMode if available
if (events.HasOwnProp("recordedMode") && events.recordedMode != "") {
    content .= buttonName . "_RecordedMode=" . events.recordedMode . "`n"
}
```

**Format in config file**:
```ini
[Macros]
Num7=boundingBox,100,200,300,400|...
Num7_RecordedMode=Wide

Num8=boundingBox,50,100,150,200|...
Num8_RecordedMode=Narrow
```

### 2. Load `recordedMode` from Config

**File**: `src/ConfigIO.ahk`

**Changes**:

#### Step 1: Create temporary storage (Line 242)
```ahk
local pendingRecordedModes := Map()  ; Store recordedMode until macros are loaded
```

**Why**: The `_RecordedMode` entries might appear in the config file before or after the actual macro events. We need to store them temporarily.

#### Step 2: Store recordedMode values (Lines 301-309)
```ahk
case "Macros":
    ; Check if this is a recordedMode property
    if (InStr(key, "_RecordedMode")) {
        ; Extract the macro name (remove "_RecordedMode" suffix)
        macroName := StrReplace(key, "_RecordedMode", "")
        ; Store for later - macro might not be loaded yet
        pendingRecordedModes[macroName] := value
    } else {
        ProcessMacroLine(key, value)
    }
```

#### Step 3: Apply recordedModes after loading (Lines 348-353)
```ahk
; Apply pending recordedModes to loaded macros
for macroName, recordedMode in pendingRecordedModes {
    if (macroEvents.Has(macroName)) {
        macroEvents[macroName].recordedMode := recordedMode
    }
}
```

**Why**: This ensures all macro events are loaded first, then we apply the stored `recordedMode` values.

## Data Flow

### Recording
```
User records macro in Wide mode
    ↓
MacroRecording.ahk:338
    macroEvents[buttonName].recordedMode = "Wide"
    ↓
SaveConfig() called
    ↓
ConfigIO.ahk:158-161
    Writes: Num7_RecordedMode=Wide
```

### Loading
```
LoadConfig() called
    ↓
Read config file
    ↓
Line: Num7_RecordedMode=Wide
    ↓
ConfigIO.ahk:306
    pendingRecordedModes["Num7"] = "Wide"
    ↓
Line: Num7=boundingBox,...
    ↓
ProcessMacroLine() creates macroEvents["Num7"]
    ↓
After all lines processed
    ↓
ConfigIO.ahk:348-353
    macroEvents["Num7"].recordedMode = "Wide"
    ↓
Visualization uses Wide mode (stretch-fill)
```

## Config File Example

### Before Fix
```ini
[Macros]
Num7=boundingBox,100,200,300,400,1|keyDown,1
Num8=boundingBox,50,100,150,200,2|keyDown,2
```
**Result**: Both macros default to Narrow (current annotation mode fallback)

### After Fix
```ini
[Macros]
Num7=boundingBox,100,200,300,400,1|keyDown,1
Num7_RecordedMode=Wide
Num8=boundingBox,50,100,150,200,2|keyDown,2
Num8_RecordedMode=Narrow
```
**Result**:
- Num7 displays with Wide letterboxing (stretch-fill)
- Num8 displays with Narrow letterboxing (black bars)

## Testing Verification

### Test Case 1: Wide Macro Persistence
1. Record macro in Wide mode
2. Close program
3. Reopen program
4. **Expected**: Macro displays with stretch-fill (no black bars)
5. **Verify**: Check config file has `ButtonName_RecordedMode=Wide`

### Test Case 2: Narrow Macro Persistence
1. Record macro in Narrow mode
2. Close program
3. Reopen program
4. **Expected**: Macro displays with 4:3 letterboxing (black bars)
5. **Verify**: Check config file has `ButtonName_RecordedMode=Narrow`

### Test Case 3: Mixed Modes
1. Record Num7 in Wide mode
2. Record Num8 in Narrow mode
3. Close program
4. Reopen program
5. **Expected**:
   - Num7: stretch-fill
   - Num8: black bars
6. **Verify**: Each macro maintains its recorded appearance

### Test Case 4: Mode Switch After Load
1. Record macro in Wide mode
2. Close and reopen program
3. Switch current mode to Narrow
4. **Expected**: Macro still displays as Wide (stretch-fill)
5. **Reason**: Recorded mode has priority over current mode

## Backward Compatibility

### Old Config Files (No recordedMode)
If config file doesn't have `_RecordedMode` entries:
- `pendingRecordedModes` will be empty
- `macroEvents[buttonName].recordedMode` will be undefined
- Visualization falls back to current `annotationMode`
- **Impact**: Old macros will update their appearance based on current mode (acceptable fallback)

### Migration Path
Users with existing macros:
1. Open program (macros load without recordedMode)
2. Re-save config (SaveConfig() will save recordedMode based on current mode)
3. Future loads will use saved recordedMode

## Related Files

- `src/MacroRecording.ahk:338` - Sets recordedMode when recording
- `src/ConfigIO.ahk:158-161` - Saves recordedMode to config
- `src/ConfigIO.ahk:242,306,348-353` - Loads recordedMode from config
- `src/GUIControls.ahk:72-77` - Extracts mode for JSON visualizations
- `src/VisualizationCanvas.ahk:78-90` - Extracts mode for macro visualizations

## Summary

The fix ensures `recordedMode` persists across application restarts:

✅ **Save**: `recordedMode` written to config as `ButtonName_RecordedMode=Mode`
✅ **Load**: `recordedMode` read from config and applied to macro events
✅ **Order-independent**: Works regardless of line order in config file
✅ **Backward compatible**: Falls back gracefully for old config files
✅ **Complete flow**: Recording → Save → Load → Visualization all preserve mode

**Result**: Macros now maintain their recorded Wide/Narrow appearance across program restarts.
