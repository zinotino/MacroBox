# Stats System and Visualization Fixes

## Issues Resolved

### 1. Map Type Error: "This value of type 'Map' has no property named 'id'"

**Problem:**
The stats recording system (`RecordExecutionStats`) was failing when processing macro events because it assumed all events were Objects with properties accessed via dot notation (e.g., `event.type`). However, some events are stored as Maps requiring bracket notation (e.g., `event["type"]`).

**Location:** `src/StatsData.ahk:1050-1074`

**Fix:**
Updated event processing to handle both Map and Object types:

```ahk
; Before (broken):
for event in events {
    if (event.type = "boundingBox") {
        if (event.HasOwnProp("degradationType")) {
            degType := event.degradationType
        }
    }
}

; After (fixed):
for event in events {
    eventType := ""
    if (Type(event) = "Map") {
        eventType := event.Has("type") ? event["type"] : ""
    } else if (IsObject(event)) {
        eventType := event.HasOwnProp("type") ? event.type : ""
    }

    if (eventType = "boundingBox") {
        degType := 0
        if (Type(event) = "Map") {
            degType := event.Has("degradationType") ? event["degradationType"] : 0
        } else if (event.HasOwnProp("degradationType")) {
            degType := event.degradationType
        }
    }
}
```

**Impact:**
- Stats recording now works with all event types
- No more "failed to save execution data" errors
- Degradation counts properly extracted from bounding box events

### 2. HBITMAP Visualization Error: "HBITMAP object type error: 0"

**Problem:**
The visualization system (`ExtractBoxEvents`) was also using dot notation to access event properties, failing with Map-type events. This caused HBITMAP creation to return 0 (failure), preventing macro visualizations from appearing on buttons.

**Location:** `src/VisualizationUtils.ahk:14-66`

**Fix:**
Updated `ExtractBoxEvents` to handle both Map and Object types:

```ahk
; Before (broken):
for eventIndex, event in macroEvents {
    if (event.type = "boundingBox" && event.HasOwnProp("left") ...) {
        left := event.left
        top := event.top

        if (nextEvent.type = "keyDown" && RegExMatch(nextEvent.key, ...)) {
            keyNumber := Integer(nextEvent.key)
        }
    }
}

; After (fixed):
for eventIndex, event in macroEvents {
    eventType := ""
    hasProps := false
    if (Type(event) = "Map") {
        eventType := event.Has("type") ? event["type"] : ""
        hasProps := event.Has("left") && event.Has("top") && ...
    } else if (IsObject(event)) {
        eventType := event.HasOwnProp("type") ? event.type : ""
        hasProps := event.HasOwnProp("left") && event.HasOwnProp("top") && ...
    }

    if (eventType = "boundingBox" && hasProps) {
        left := (Type(event) = "Map") ? event["left"] : event.left
        top := (Type(event) = "Map") ? event["top"] : event.top

        nextKey := (Type(nextEvent) = "Map") ?
            (nextEvent.Has("key") ? nextEvent["key"] : "") :
            (nextEvent.HasOwnProp("key") ? nextEvent.key : "")
    }
}
```

**Impact:**
- HBITMAP visualizations now generate correctly
- Macro buttons display visual previews of recorded macros
- No more HBITMAP error: 0 messages

## Root Cause Analysis

The issue stemmed from **inconsistent event storage formats** in the codebase:

1. **Recording Phase**: Events are created as Objects with properties
2. **Storage Phase**: Some systems convert Objects to Maps for serialization
3. **Loading Phase**: Config loader creates Maps instead of Objects
4. **Processing Phase**: Code assumed all events were Objects

## Type-Safe Event Access Pattern

To prevent future issues, use this pattern when accessing events:

```ahk
; Get event type safely
GetEventType(event) {
    if (Type(event) = "Map") {
        return event.Has("type") ? event["type"] : ""
    } else if (IsObject(event)) {
        return event.HasOwnProp("type") ? event.type : ""
    }
    return ""
}

; Get event property safely
GetEventProperty(event, propName, defaultValue := "") {
    if (Type(event) = "Map") {
        return event.Has(propName) ? event[propName] : defaultValue
    } else if (IsObject(event)) {
        return event.HasOwnProp(propName) ? event.%propName% : defaultValue
    }
    return defaultValue
}
```

## Files Modified

1. **src/StatsData.ahk**
   - Line 1050-1074: Fixed event type detection in `RecordExecutionStats`
   - Added Map type support for degradation extraction

2. **src/VisualizationUtils.ahk**
   - Line 14-66: Fixed event type detection in `ExtractBoxEvents`
   - Added Map type support for box extraction and keypress detection

## Testing Verification

After these fixes, the system should:

1. ✅ Record execution stats without errors
2. ✅ Display macro visualizations on buttons
3. ✅ Handle both Map and Object event types
4. ✅ Extract degradation data correctly
5. ✅ Show stats in the stats GUI
6. ✅ Export stats to CSV successfully

## Prevention

To prevent similar issues in the future:

1. **Standardize Event Storage**: Consider converting all Maps to Objects on load
2. **Type Checking**: Always check `Type(event)` before property access
3. **Helper Functions**: Use type-safe accessor functions for events
4. **Testing**: Test with both freshly recorded and loaded-from-config macros

## Related Documentation

- See `docs/STATS_SYSTEM_ALIGNMENT.md` for complete stats system architecture
- See `src/VisualizationCore.ahk` for HBITMAP creation details
- See `src/ConfigIO.ahk` for event serialization/deserialization

## Summary

Both errors were caused by the same root issue: **incompatible property access methods for different data types**. The fixes ensure the code works with both Map and Object types, making the system robust regardless of how events are stored internally.

The stats system is now fully functional and integrated with proper type handling throughout the codebase.
