# MacroMaster Visualization System - Critical Design Document

## 🔒 PROTECTION STATUS
**DO NOT MODIFY WITHOUT EXPLICIT USER APPROVAL**

This document defines the core visualization system that has been stabilized after extensive debugging. Any changes to this system must be carefully reviewed to prevent breaking the letterboxing and thumbnail rendering that currently works correctly.

---

## Core Architecture

### Module: `src/Visualization.ahk`
**Purpose**: Isolated GDI+ macro visualization system for rendering degradation box thumbnails

**Critical Dependencies**:
- GDI+ Windows library (gdiplus.dll)
- Canvas calibration coordinates from `src/Config.ahk`
- Degradation color mappings from `src/Core.ahk`

---

## Key Design Principles

### 1. **Black Background Letterboxing** (FIXED)
- **Background Color**: `0xFF000000` (pure black)
- **Content Area**: `0xFF2A2A2A` (dark gray)
- **Purpose**: Maximum contrast for colored degradation boxes
- **Location**: `CreateMacroVisualization()` line 36, `DrawMacroBoxesOnButton()` lines 386-418

**DO NOT CHANGE** these background colors without understanding the letterboxing system.

### 2. **Dual Canvas System** (FIXED)
The system intelligently chooses between two calibrated canvas configurations:

#### Wide Canvas
- **Use Case**: Wide-aspect recorded macros (aspect ratio > 1.3)
- **Rendering**: Stretch to fill entire thumbnail (no letterboxing)
- **Canvas Config**: `wideCanvasLeft/Top/Right/Bottom` from Config.ahk

#### Narrow Canvas
- **Use Case**: Narrow-aspect recorded macros (aspect ratio ≤ 1.3)
- **Rendering**: 4:3 letterboxing with black bars to preserve aspect ratio
- **Canvas Config**: `narrowCanvasLeft/Top/Right/Bottom` from Config.ahk

**Detection Logic**: Lines 184-314 in `DrawMacroBoxesOnButton()`

### 3. **Canvas Selection Priority**
1. **Stored Mode** (highest priority): Uses `macroEvents.recordedMode` property if available
2. **User Annotation Mode**: Uses global `annotationMode` variable ("Wide" or "Narrow")
3. **Intelligent Detection** (fallback): Analyzes aspect ratio and coordinate boundaries

---

## Critical Functions

### `CreateMacroVisualization(macroEvents, buttonDims)`
**Purpose**: Entry point for thumbnail generation
**Returns**: PNG file path or empty string on failure
**Key Operations**:
1. Validates GDI+ initialization
2. Extracts box events from macro
3. Creates bitmap with proper dimensions
4. Sets black background (`0xFF000000`)
5. Calls `DrawMacroBoxesOnButton()` for rendering
6. Saves to temporary PNG file

**DO NOT MODIFY** the background color initialization on line 36.

### `ExtractBoxEvents(macroEvents)`
**Purpose**: Parses macro recording to find bounding box coordinates
**Returns**: Array of box objects with coordinates and degradation types
**Key Logic**:
- Looks for events with `type = "boundingBox"`
- Associates degradation types from subsequent keypresses
- Filters out boxes smaller than 5x5 pixels

### `DrawMacroBoxesOnButton(graphics, buttonWidth, buttonHeight, boxes, macroEventsArray)`
**Purpose**: Core rendering engine - maps canvas coordinates to thumbnail pixels
**Parameters**:
- `graphics`: GDI+ graphics context
- `buttonWidth/Height`: Target thumbnail dimensions
- `boxes`: Array of box coordinates from `ExtractBoxEvents()`
- `macroEventsArray`: Full macro data (optional, used for mode detection)

**Critical Sections**:
1. **Canvas Detection** (lines 184-314): Chooses wide/narrow/legacy canvas
2. **Wide Canvas Rendering** (lines 382-393): Stretch to fill, no letterboxing
3. **Narrow Canvas Rendering** (lines 394-424): 4:3 letterboxing with black bars
4. **Box Drawing** (lines 439-542): Sub-pixel precision rendering

**DO NOT MODIFY** without understanding the entire canvas selection and scaling logic.

---

## Configuration Integration

### Canvas Calibration Variables (from Config.ahk)
```ahk
; Wide canvas (16:9 approximate)
global wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom
global isWideCanvasCalibrated

; Narrow canvas (4:3 approximate)
global narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom
global isNarrowCanvasCalibrated

; Legacy single canvas (fallback)
global userCanvasLeft, userCanvasTop, userCanvasRight, userCanvasBottom
global isCanvasCalibrated
```

These coordinates define the recording area boundaries and must be calibrated through the Settings menu.

### Annotation Mode Variable (from Core.ahk)
```ahk
global annotationMode  ; "Wide" or "Narrow"
```

Set during macro recording to indicate user's chosen canvas type.

---

## Rendering Pipeline

```
Macro Execution
    ↓
Save macro data with boxes + recordedMode
    ↓
Button click/hover triggers visualization
    ↓
CreateMacroVisualization(macroEvents, buttonDims)
    ↓
ExtractBoxEvents(macroEvents) → boxes array
    ↓
Create GDI+ bitmap with black background
    ↓
DrawMacroBoxesOnButton(graphics, w, h, boxes, macroEvents)
    │
    ├─ Detect canvas type (wide/narrow/legacy)
    ├─ Calculate scaling (stretch vs letterbox)
    ├─ Fill content area with dark gray
    └─ Render colored boxes with sub-pixel precision
    ↓
SaveVisualizationPNG(bitmap, tempFile)
    ↓
Return PNG path for display
```

---

## Known Working State

### Git Reference
- **Branch**: `vizfixed` (current) and `configfix` (backup reference)
- **Base Commit**: `677acf0` - "CONFIG: Implement intelligent timing system with smart delays"
- **Status**: Letterboxing and visualization system fully functional

### Verified Features
✅ Black backgrounds with proper contrast
✅ Dual canvas system (wide/narrow)
✅ 4:3 letterboxing for narrow macros
✅ Stretch-to-fill for wide macros
✅ Sub-pixel precision rendering
✅ Canvas calibration persistence
✅ Annotation mode integration

---

## Testing Protocol

Before making ANY changes to visualization:

1. **Backup Current State**: Ensure `configfix` branch is preserved
2. **Test Wide Macros**: Record and verify stretch-to-fill rendering
3. **Test Narrow Macros**: Record and verify 4:3 letterboxing with black bars
4. **Test Canvas Switching**: Verify mode detection with mixed aspect ratios
5. **Test Color Accuracy**: Verify all 9 degradation types render correctly
6. **Test Edge Cases**: Small boxes, corner boxes, overlapping boxes

**If ANY test fails, immediately revert changes.**

---

## Modification Guidelines

### Safe Changes
- Degradation color palette adjustments (in Core.ahk)
- Minimum box size thresholds (line 451)
- Canvas aspect ratio tolerance (lines 207-208)
- Debug status messages

### Dangerous Changes (REQUIRE USER APPROVAL)
- Background colors (lines 36, 386, 416, 428)
- Canvas detection logic (lines 184-314)
- Scaling calculations (lines 382-436)
- Box coordinate mapping (lines 439-542)
- GDI+ initialization sequence
- PNG save fallback paths

### Prohibited Without Explicit Permission
- Removing the dual canvas system
- Changing letterboxing behavior for narrow mode
- Modifying stretch-to-fill behavior for wide mode
- Altering black background scheme
- Refactoring visualization into separate modules

---

## Isolation Strategy

### Module Boundaries
**Visualization.ahk** should have minimal dependencies:
- **Input**: Macro event data (boxes + coordinates)
- **Config**: Canvas calibration coordinates (read-only)
- **Output**: PNG file path

**DO NOT** add these dependencies:
- Stats tracking integration
- Database connections
- Network operations
- File I/O beyond PNG generation
- UI state management (except status updates)

### API Stability
The following function signatures are **FROZEN**:
```ahk
CreateMacroVisualization(macroEvents, buttonDims)
ExtractBoxEvents(macroEvents)
DrawMacroBoxesOnButton(graphics, buttonWidth, buttonHeight, boxes, macroEventsArray := "")
SaveVisualizationPNG(bitmap, filePath)
```

Any changes to these signatures will break integration with GUI.ahk and Macros.ahk.

---

## Historical Context

### Previous Breaking Changes
1. **SQLite Stats Integration** (reverted): Added database dependencies that broke visualization
2. **Dashboard Overhaul** (reverted): Modified rendering pipeline, broke letterboxing
3. **Multiple Background Experiments**: Tried different color schemes, degraded contrast

### Lessons Learned
- Visualization should be isolated from stats tracking
- Background colors are critical for readability
- Canvas detection must respect user annotation mode
- Letterboxing is essential for narrow aspect ratios
- Sub-pixel precision matters for small boxes

---

## Emergency Rollback Procedure

If visualization breaks:

```bash
# Return to known good state
git checkout configfix

# Or create new branch from working commit
git checkout -b visualization-fix 677acf0
```

**Known Good Commit**: `677acf0` contains fully working visualization with letterboxing fixes.

---

## Change Request Template

Before modifying visualization system, answer these questions:

1. **What specific function will change?**
2. **Why is this change necessary?**
3. **Does it affect canvas detection or scaling?**
4. **Does it affect background colors or letterboxing?**
5. **Have you tested with both wide and narrow macros?**
6. **Can you demonstrate that existing macros still render correctly?**
7. **Is there a git commit to rollback to if this breaks?**

**If you cannot answer all 7 questions, DO NOT proceed with changes.**

---

## Dependencies Map

```
Visualization.ahk (ISOLATED)
    ↓ reads
Config.ahk (canvas coordinates only)
    ↓ reads
Core.ahk (degradation colors, gdiPlusToken)
    ↓ reads
GUI.ahk (button dimensions, status updates)
```

**NO reverse dependencies allowed** - other modules should not modify visualization internals.

---

## Status Diagnostic Messages

The system outputs diagnostic messages during canvas detection:
- Lines 317-337: Detailed canvas selection logging
- Global variable: `lastCanvasDetection` stores most recent diagnostic info

**DO NOT REMOVE** these diagnostics - they are critical for debugging canvas selection issues.

---

## Summary

The visualization system is **STABLE** and **WORKING** as of commit `677acf0`. It has been extensively debugged and provides:
- Accurate degradation box rendering
- Intelligent canvas type detection
- Proper letterboxing for narrow content
- High-quality sub-pixel rendering

**Any modifications must preserve these core capabilities or will be rejected.**
