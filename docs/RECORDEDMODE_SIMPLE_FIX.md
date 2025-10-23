# RecordedMode Simple Implementation

## Overview
Simple, clean implementation to persist wide/narrow visualization mode per macro.

## How It Works

### 1. Assignment (MacroRecording.ahk:338)
When a macro is assigned to a button:
```ahk
macroEvents[buttonName].recordedMode := annotationMode
```
Sets the recordedMode property to current annotation mode ("Wide" or "Narrow").

### 2. Saving (ConfigIO.ahk:159-161)
When config is saved:
```ahk
if (events.HasOwnProp("recordedMode") && events.recordedMode != "") {
    content .= buttonName . "_RecordedMode=" . events.recordedMode . "`n"
}
```
Writes a line like: `Num7_RecordedMode=Wide`

### 3. Loading (ConfigIO.ahk:301-307)
When config is loaded:
```ahk
if (InStr(key, "_RecordedMode")) {
    macroName := StrReplace(key, "_RecordedMode", "")
    if (macroEvents.Has(macroName)) {
        macroEvents[macroName].recordedMode := value
    }
}
```
Reads the `_RecordedMode` line and sets the property on the array.

### 4. Visualization (VisualizationCanvas.ahk:84-90)
When drawing visualization:
```ahk
if (macroEventsArray.HasOwnProp("recordedMode")) {
    storedMode := macroEventsArray.recordedMode
}
effectiveMode := storedMode != "" ? storedMode : annotationMode
```
Uses stored mode if available, otherwise falls back to current global mode.

### 5. Canvas Selection (VisualizationCanvas.ahk:92-101)
```ahk
if (effectiveMode = "Wide") {
    useWideCanvas := true   // Stretch to fill, no letterboxing
} else if (effectiveMode = "Narrow") {
    useNarrowCanvas := true  // Letterboxed 4:3
}
```
Simple absolute logic - no complex boundary checking.

## File Format Example
```ini
[Macros]
Num7=boundingBox,100,100,200,200|boundingBox,300,300,400,400
Num7_RecordedMode=Wide
Num8=boundingBox,240,100,1680,900
Num8_RecordedMode=Narrow
```

## Key Points
- No complex logic or fallbacks
- recordedMode is ABSOLUTE - if set to Wide, always use wide rendering
- Property persists across sessions
- If no recordedMode saved, uses current global annotationMode
