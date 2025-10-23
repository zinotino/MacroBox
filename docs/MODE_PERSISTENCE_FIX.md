# Mode Persistence Fix - Recorded Mode Letterboxing

## Issue

Visualizations were not maintaining their recorded Wide/Narrow mode letterboxing:
- **Problem**: Visualizations displayed with current mode letterboxing instead of recorded mode
- **Impact**: Wide macros shown with Narrow letterboxing (or vice versa) when mode changed
- **Expected**: Visualizations should be static and preserve their recorded appearance

## Core Principle

**Visualizations must be immutable** - they should display exactly as they were recorded, regardless of the current annotation mode setting.

## How Recording Mode is Stored

### Macro Events (Array)
```ahk
; When macro is saved (MacroRecording.ahk:338)
macroEvents[buttonName].recordedMode := annotationMode  // "Wide" or "Narrow"
```

### JSON Events (Single Event)
```ahk
; When JSON annotation is created
jsonEvent := {
    type: "jsonAnnotation",
    mode: "Wide",  // or "Narrow" - stored in event
    categoryId: 1,
    severity: "high"
}
```

## Files Modified

### 1. `src/GUIControls.ahk` - Button Appearance

**JSON Mode Extraction** (Lines 72-77):
```ahk
; OLD (broken):
jsonMode := (jsonEvent.HasOwnProp("mode") && jsonEvent.mode != "") ?
    jsonEvent.mode : annotationMode  // ❌ Falls back to current mode

; NEW (fixed):
if (Type(jsonEvent) = "Map") {
    jsonMode := jsonEvent.Has("mode") && jsonEvent["mode"] != "" ?
        jsonEvent["mode"] : annotationMode
} else {
    jsonMode := (jsonEvent.HasOwnProp("mode") && jsonEvent.mode != "") ?
        jsonEvent.mode : annotationMode
}
```

**JSON Visualization Call** (Line 128):
```ahk
; OLD (broken):
hbitmap := CreateJsonHBITMAPVisualization(jsonColor, buttonSize, annotationMode, jsonInfo)
//                                                                  ^^^^^^^^^^^^^^^ Wrong!

; NEW (fixed):
hbitmap := CreateJsonHBITMAPVisualization(jsonColor, buttonSize, jsonMode, jsonInfo)
//                                                                ^^^^^^^^ Correct!
```

### 2. `src/VisualizationCanvas.ahk` - Macro Letterboxing

**Recorded Mode Extraction** (Lines 78-87):
```ahk
; OLD (broken):
if (macroEventsArray != "" && IsObject(macroEventsArray) &&
    macroEventsArray.HasOwnProp("recordedMode")) {
    storedMode := macroEventsArray.recordedMode  // ❌ Doesn't handle Map type
}

; NEW (fixed):
if (macroEventsArray != "" && IsObject(macroEventsArray)) {
    if (Type(macroEventsArray) = "Map") {
        storedMode := macroEventsArray.Has("recordedMode") ?
            macroEventsArray["recordedMode"] : ""
    } else if (macroEventsArray.HasOwnProp("recordedMode")) {
        storedMode := macroEventsArray.recordedMode
    }
}
```

**Effective Mode Usage** (Line 90):
```ahk
; Use stored mode if available, otherwise current mode
effectiveMode := storedMode != "" ? storedMode : annotationMode
```

## Data Flow

### Recording Phase
```
User records in Wide mode
    ↓
Macro saved with recordedMode = "Wide"
    ↓
JSON annotation saved with mode = "Wide"
```

### Display Phase (Current Mode = Narrow)
```
Load macro events
    ↓
Extract recordedMode = "Wide"  // From storage
    ↓
Use "Wide" for visualization  // NOT current "Narrow" mode
    ↓
Display with Wide letterboxing ✅
```

## Behavior by Type

### Macro Visualizations

**Recording**:
- User in Wide mode
- Records macro with bounding boxes
- `macroEvents[buttonName].recordedMode = "Wide"`

**Display**:
- Load config → `recordedMode` extracted
- Pass to `DrawMacroBoxesOnButton()`
- Uses Wide canvas configuration
- Applies Wide letterboxing (if needed)
- **Result**: Wide macro displays with Wide letterboxing ✅

**Mode Change** (User switches to Narrow):
- `annotationMode = "Narrow"` (current mode)
- `recordedMode = "Wide"` (from macro)
- `effectiveMode = "Wide"` (prioritizes recorded)
- **Result**: Still displays with Wide letterboxing ✅

### JSON Visualizations

**Recording**:
- User in Narrow mode
- Creates JSON annotation
- `jsonEvent.mode = "Narrow"`

**Display**:
- Extract `jsonEvent.mode = "Narrow"`
- Pass to `CreateJsonHBITMAPVisualization()`
- Applies 4:3 Narrow letterboxing
- **Result**: Colored box with Narrow letterboxing ✅

**Mode Change** (User switches to Wide):
- `annotationMode = "Wide"` (current mode)
- `jsonMode = "Narrow"` (from event)
- Uses `jsonMode` for visualization
- **Result**: Still displays with Narrow letterboxing ✅

## Type Safety

Both functions now handle Map and Object types:

```ahk
; Safe property access pattern
if (Type(data) = "Map") {
    value := data.Has("property") ? data["property"] : defaultValue
} else if (IsObject(data)) {
    value := data.HasOwnProp("property") ? data.property : defaultValue
}
```

## Letterboxing Logic

### Wide Mode
- **Canvas**: Full 16:9 aspect ratio
- **Letterboxing**: None (stretches to fill)
- **Visual**: No black bars

### Narrow Mode
- **Canvas**: 4:3 aspect ratio (centered in 16:9)
- **Letterboxing**: Horizontal black bars
- **Visual**: Content in center, black bars on sides

## Testing Scenarios

### Scenario 1: Record Wide, Switch to Narrow
1. Record macro in Wide mode
2. Switch to Narrow mode
3. **Expected**: Macro displays with Wide letterboxing (stretch)
4. **Actual**: ✅ Displays correctly with Wide letterboxing

### Scenario 2: Record Narrow, Switch to Wide
1. Record macro in Narrow mode
2. Switch to Wide mode
3. **Expected**: Macro displays with Narrow letterboxing (black bars)
4. **Actual**: ✅ Displays correctly with Narrow letterboxing

### Scenario 3: JSON Wide in Narrow Mode
1. Create JSON annotation in Wide mode
2. Switch to Narrow mode
3. **Expected**: JSON displays full width (Wide)
4. **Actual**: ✅ Displays correctly full width

### Scenario 4: JSON Narrow in Wide Mode
1. Create JSON annotation in Narrow mode
2. Switch to Wide mode
3. **Expected**: JSON displays with black bars (Narrow 4:3)
4. **Actual**: ✅ Displays correctly with black bars

## Cache Key Updates

The HBITMAP cache includes mode in the key to prevent conflicts:

```ahk
// VisualizationCore.ahk:155
recordedMode := macroEvents.HasOwnProp("recordedMode") ?
    macroEvents.recordedMode : "unknown"
cacheKey .= buttonWidth . "x" . buttonHeight . "_" . recordedMode
```

This ensures:
- Wide visualizations cached separately from Narrow
- Mode changes trigger new visualizations
- No cross-contamination between modes

## Fallback Behavior

If `recordedMode` is not found:
- **Macros**: Falls back to current `annotationMode`
- **JSON**: Falls back to current `annotationMode`
- **Reason**: Backward compatibility with old macros
- **Impact**: Old macros may change appearance on mode switch

## Prevention

To ensure mode persistence:

1. **Always save mode with macro**: `macroEvents[name].recordedMode = mode`
2. **Always save mode with JSON event**: `event.mode = mode`
3. **Extract recorded mode on display**: Check for stored mode first
4. **Use recorded mode for visualization**: Never use current mode
5. **Handle both Map and Object types**: Type-safe property access

## Related Files

- `src/MacroRecording.ahk:338` - Saves `recordedMode` with macro
- `src/ConfigIO.ahk:131` - Saves/loads JSON event mode
- `src/VisualizationCore.ahk:153-155` - Cache key includes mode
- `src/GUIControls.ahk:72-77, 128` - Extracts and uses recorded mode

## Summary

Visualizations are now **truly static** and **mode-immutable**:

✅ Recorded mode stored with macro/JSON
✅ Recorded mode extracted on display
✅ Recorded mode used for letterboxing
✅ Type-safe for both Map and Object
✅ Cache separates modes
✅ Fallback for backward compatibility

**Result**: Visualizations maintain their recorded appearance regardless of current annotation mode setting.
