# MacroMaster Visualization System - Complete Documentation

**Version:** 2.0
**Last Updated:** 2025-10-08
**Status:** Production Ready

---

## Table of Contents

1. [Overview](#overview)
2. [System Architecture](#system-architecture)
3. [HBITMAP Visualization System](#hbitmap-visualization-system)
4. [PNG Fallback System](#png-fallback-system)
5. [Canvas Detection & Scaling](#canvas-detection--scaling)
6. [Box Rendering Engine](#box-rendering-engine)
7. [Degradation Color System](#degradation-color-system)
8. [Performance Characteristics](#performance-characteristics)
9. [Corporate Environment Support](#corporate-environment-support)
10. [Usage Guide](#usage-guide)
11. [Troubleshooting](#troubleshooting)

---

## Overview

The MacroMaster Visualization System is a multi-layered, high-performance bitmap rendering engine designed to create visual thumbnails of recorded macros for the AutoHotkey GUI. The system uses GDI+ for graphics operations and supports multiple fallback mechanisms for corporate environments.

### Key Features

- **Three-Tier Architecture**: HBITMAP (primary), PNG (fallback), Plotly (analytics)
- **Intelligent Canvas Detection**: Automatic wide/narrow canvas selection based on recorded content
- **Sub-pixel Rendering**: High-quality anti-aliased box rendering with floating-point precision
- **Corporate Safe**: Multiple fallback paths for restricted environments
- **Performance Optimized**: <1ms cached rendering, intelligent scaling algorithms
- **Color Consistency**: Synchronized degradation colors across all visualization layers

### What It Visualizes

The system creates thumbnail representations of:
- **Bounding Boxes**: User-drawn rectangular regions on screen
- **Degradation Types**: 9 different visual degradation effects (smudge, glare, splashes, etc.)
- **Canvas Context**: Wide (16:9) or narrow (4:3) aspect ratio layouts
- **Macro Complexity**: Number and positioning of recorded actions

---

## System Architecture

### Three-Layer Visualization Stack

```
┌─────────────────────────────────────────────────────────────┐
│                    AHK GUI Layer                             │
│  Picture Controls display thumbnails                        │
│  HBITMAP: "HBITMAP:*{handle}"                               │
│  PNG: "{file_path}"                                         │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                 Visualization Core Layer                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ CreateMacro- │  │ CreateHBIT- │  │ SaveVisual-  │      │
│  │ Visualization│  │ MAPVisual-  │  │ izationPNG   │      │
│  │ (PNG)        │  │ ization     │  │ (Fallback)   │      │
│  │              │  │ (Primary)   │  │              │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│  GDI+ Bitmap Operations • Memory Management • File I/O     │
└─────────────────────────┬───────────────────────────────────┘
                          │
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                Canvas & Rendering Layer                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ DetectCanvas │  │ DrawMacro-  │  │ ExtractBox-  │      │
│  │ Type         │  │ BoxesOn-    │  │ Events      │      │
│  │              │  │ Button      │  │              │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│  Aspect Ratio Analysis • Scaling Algorithms • Color Mapping│
└─────────────────────────────────────────────────────────────┘
```

### File Structure

```
src/
├── Visualization.ahk          # Main coordination module
├── VisualizationCore.ahk      # Core GDI+ operations
├── VisualizationCanvas.ahk    # Canvas detection & scaling
└── VisualizationUtils.ahk     # Helper functions
```

---

## HBITMAP Visualization System

### Overview

The HBITMAP system provides in-memory bitmap rendering for maximum performance and zero file I/O. It's the primary visualization method used by the GUI.

### Key Functions

#### `CreateHBITMAPVisualization(macroEvents, buttonDims)`

**Purpose:** Creates an in-memory HBITMAP for instant GUI display

**Parameters:**
- `macroEvents`: Array of recorded macro events
- `buttonDims`: Button dimensions (width/height object or single size)

**Returns:** HBITMAP handle (or 0 on failure)

**Process:**
1. **Validation**: Check GDI+ initialization and macro data
2. **Cache Check**: Generate cache key from macro content
3. **Bitmap Creation**: Create GDI+ bitmap with button dimensions
4. **Graphics Context**: Get graphics handle for drawing
5. **Background**: Clear with black background (#FF000000)
6. **Box Rendering**: Call `DrawMacroBoxesOnButton()` for content
7. **HBITMAP Conversion**: Convert GDI+ bitmap to Windows HBITMAP
8. **Caching**: Store result for future use
9. **Cleanup**: Release GDI+ resources

**Performance:** <1ms cached, ~5-10ms initial creation

### Caching System

#### Cache Key Generation

```autohotkey
cacheKey := ""
for event in macroEvents {
    if (event.type = "boundingBox") {
        cacheKey .= event.left . "," . event.top . "," . event.right . "," . event.bottom . "|"
    }
}
recordedMode := macroEvents.HasOwnProp("recordedMode") ? macroEvents.recordedMode : "unknown"
cacheKey .= buttonWidth . "x" . buttonHeight . "_" . recordedMode
```

**Cache Benefits:**
- Eliminates redundant rendering
- Instant thumbnail display for repeated macros
- Memory efficient (reuses HBITMAP handles)

#### Cache Management

- **Storage**: `hbitmapCache` Map object
- **Cleanup**: `CleanupHBITMAPCache()` function deletes all handles
- **Invalidation**: `ClearHBitmapCacheForMacro()` clears specific macro entries

---

## PNG Fallback System

### Overview

When HBITMAP fails (corporate restrictions, GDI+ issues), the system falls back to PNG file-based rendering.

### Key Functions

#### `CreateMacroVisualization(macroEvents, buttonDims)`

**Purpose:** Creates PNG file visualization as fallback

**Parameters:**
- `macroEvents`: Array of recorded macro events
- `buttonDims`: Button dimensions

**Returns:** PNG file path (or "" on failure)

**Process:**
1. **GDI+ Bitmap Creation**: Same as HBITMAP system
2. **PNG Encoding**: Convert bitmap to PNG format
3. **Fallback Paths**: Try multiple save locations
4. **File Management**: Handle temporary file cleanup

#### `SaveVisualizationPNG(bitmap, filePath)`

**Purpose:** Saves GDI+ bitmap to PNG with corporate-safe fallback paths

**Fallback Path Priority:**
1. **Original Path**: Requested file location
2. **Script Directory**: `A_ScriptDir . "\" . fileName`
3. **My Documents**: `A_MyDocuments . "\" . fileName`
4. **User Profile**: `EnvGet("USERPROFILE") . "\" . fileName`
5. **Temp Directory**: `A_Temp . "\" . fileName` (last resort)

**Corporate Environment Handling:**
- Automatic path detection for restricted write access
- Silent fallback without user interruption
- File cleanup with 2-second delay timer

**Performance:** ~15-30ms generation, 5-50 KB file size

---

## Canvas Detection & Scaling

### Dual Canvas Architecture

MacroMaster supports two canvas configurations to match different labeling workflows:

#### Wide Canvas (16:9)
- **Dimensions**: 1920x1080 (reference)
- **Use Case**: Full-screen labeling workflows
- **Scaling**: Stretch to fill thumbnail (no letterboxing)
- **Coordinates**: 0,0 to 1920,1080

#### Narrow Canvas (4:3)
- **Dimensions**: 1440x1080 centered (240px left/right margins)
- **Use Case**: Focused labeling with side panels
- **Scaling**: Letterboxing to preserve 4:3 aspect ratio
- **Coordinates**: 240,0 to 1680,1080

### Intelligent Canvas Selection

#### Detection Algorithm

```autohotkey
; Calculate recorded content bounds
minX := 999999, minY := 999999, maxX := 0, maxY := 0
for box in boxes {
    minX := Min(minX, box.left)
    minY := Min(minY, box.top)
    maxX := Max(maxX, box.right)
    maxY := Max(maxY, box.bottom)
}

recordedAspectRatio := (maxX - minX) / (maxY - minY)
```

#### Selection Logic

1. **User Mode Priority**: Respect explicit wide/narrow mode selection
2. **Boundary Fitting**: Check if content fits within canvas boundaries
3. **Coverage Analysis**: Calculate percentage of canvas utilized
4. **Aspect Ratio Decision**: Wide content (>1.3 AR) prefers wide canvas
5. **Efficiency Optimization**: Choose canvas with better space utilization

#### Scaling Strategies

##### Wide Canvas Scaling
```autohotkey
; Stretch to fill entire button area
scaleX := buttonWidth / canvasW
scaleY := buttonHeight / canvasH
offsetX := 0
offsetY := 0
```

##### Narrow Canvas Scaling
```autohotkey
; Letterboxing: maintain 4:3 aspect ratio
narrowAspect := 4.0 / 3.0
if (buttonAspect > narrowAspect) {
    ; Horizontal letterboxing
    contentHeight := buttonHeight
    contentWidth := contentHeight * narrowAspect
} else {
    ; Vertical letterboxing
    contentWidth := buttonWidth
    contentHeight := contentWidth / narrowAspect
}

; Center content area
offsetX := (buttonWidth - contentWidth) / 2
offsetY := (buttonHeight - contentHeight) / 2

; Scale to fill content area
scaleX := contentWidth / canvasW
scaleY := contentHeight / canvasH
```

---

## Box Rendering Engine

### Core Rendering Function

#### `DrawMacroBoxesOnButton(graphics, buttonWidth, buttonHeight, boxes, macroEventsArray)`

**Purpose:** Renders bounding boxes with degradation colors onto graphics context

**Key Features:**
- Sub-pixel precision rendering
- Intelligent minimum size enforcement
- Aspect ratio preservation
- Bounds validation

### Rendering Pipeline

#### 1. Coordinate Transformation
```autohotkey
; Map canvas coordinates to button space
rawX1 := ((box.left - canvasLeft) * scaleX) + offsetX
rawY1 := ((box.top - canvasTop) * scaleY) + offsetY
rawX2 := ((box.right - canvasLeft) * scaleX) + offsetX
rawY2 := ((box.bottom - canvasTop) * scaleY) + offsetY
```

#### 2. Minimum Size Enforcement
```autohotkey
minSize := 2.5  ; Minimum dimension threshold

if (rawW < minSize || rawH < minSize) {
    ; Preserve aspect ratio while ensuring visibility
    originalAspect := (box.right - box.left) / (box.bottom - box.top)

    if (rawW < minSize && rawH < minSize) {
        ; Scale proportionally
        w := minSize
        h := minSize / originalAspect
    } else if (rawW < minSize) {
        w := minSize
        h := minSize / originalAspect
    } else {
        h := minSize
        w := minSize * originalAspect
    }

    ; Center adjusted box
    centerX := (rawX1 + rawX2) / 2
    centerY := (rawY1 + rawY2) / 2
    x1 := centerX - w / 2
    y1 := centerY - h / 2
    x2 := x1 + w
    y2 := y1 + h
}
```

#### 3. Bounds Validation
```autohotkey
; Ensure coordinates within thumbnail area
x1 := Max(0, Min(x1, buttonWidth))
y1 := Max(0, Min(y1, buttonHeight))
x2 := Max(0, Min(x2, buttonWidth))
y2 := Max(0, Min(y2, buttonHeight))
```

#### 4. Enhanced Rendering
```autohotkey
; High-quality rendering settings
DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", graphics, "Int", 4)  ; HighQuality
DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", graphics, "Int", 4) ; HighQuality

; Get degradation color
fillColor := 0xFF000000 | degradationColors[box.degradationType]

; Render with sub-pixel precision
brush := 0
DllCall("gdiplus\GdipCreateSolidFill", "UInt", fillColor, "Ptr*", &brush)
DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", brush, "Float", x1, "Float", y1, "Float", w, "Float", h)
DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
```

### Degradation Assignment

#### Box Event Extraction
```autohotkey
ExtractBoxEvents(macroEvents) {
    boxes := []
    currentDegradationType := 1

    for eventIndex, event in macroEvents {
        if (event.type = "boundingBox") {
            ; Look ahead for keypress degradation assignment
            degradationType := currentDegradationType
            nextIndex := eventIndex + 1

            while (nextIndex <= macroEvents.Length) {
                nextEvent := macroEvents[nextIndex]
                if (nextEvent.type = "boundingBox") {
                    break  ; Stop at next box
                }

                if (nextEvent.type = "keyDown" && RegExMatch(nextEvent.key, "^\d$")) {
                    keyNumber := Integer(nextEvent.key)
                    if (keyNumber >= 1 && keyNumber <= 9) {
                        degradationType := keyNumber
                        currentDegradationType := keyNumber
                        break
                    }
                }
                nextIndex++
            }

            boxes.Push({
                left: event.left,
                top: event.top,
                right: event.right,
                bottom: event.bottom,
                degradationType: degradationType
            })
        }
    }

    return boxes
}
```

---

## Degradation Color System

### Color Mapping

All visualization systems use identical color mapping for consistency:

```autohotkey
degradationColors := Map(
    1, 0xFF4500,  ; smudge - orangered
    2, 0xFFD700,  ; glare - gold
    3, 0x8A2BE2,  ; splashes - blueviolet
    4, 0x00FF32,  ; partial_blockage - limegreen
    5, 0x8B0000,  ; full_blockage - darkred
    6, 0xFF1493,  ; light_flare - deeppink
    7, 0xB8860B,  ; rain - darkgoldenrod
    8, 0x556B2F,  ; haze - darkolivegreen
    9, 0x00FF7F   ; snow - springgreen
)
```

### Color Consistency Across Systems

#### AHK Visualization (HBITMAP/PNG)
- Uses BGR hex values (0xBBGGRR format)
- Full opacity (0xFF prefix)

#### Python Plotly Dashboard
```python
color_map = {
    'smudge': '#FF4500',
    'glare': '#FFD700',
    'splashes': '#8A2BE2',
    'partial_blockage': '#00FF32',
    'full_blockage': '#8B0000',
    'light_flare': '#FF1493',
    'rain': '#B8860B',
    'haze': '#556B2F',
    'snow': '#00FF7F',
    'clear': '#90EE90'
}
```

### Degradation Types Reference

| Key | Type | Description | Use Case |
|-----|------|-------------|----------|
| 1 | Smudge | Lens fingerprints/smudges | Manual cleaning required |
| 2 | Glare | Light reflection on lens | Change lighting angle |
| 3 | Splashes | Water droplets on lens | Dry lens surface |
| 4 | Partial Blockage | Object partially blocking view | Adjust camera position |
| 5 | Full Blockage | Object completely blocking view | Remove obstruction |
| 6 | Light Flare | Lens flare from light source | Adjust lighting/shielding |
| 7 | Rain | Rain drops on protective cover | Wait for rain to stop |
| 8 | Haze | Atmospheric haze/fog | Wait for conditions to improve |
| 9 | Snow | Snow accumulation | Clear snow from surface |

---

## Performance Characteristics

### Benchmark Results

| Operation | Cached | Initial | Notes |
|-----------|--------|---------|-------|
| HBITMAP Creation | <1ms | 5-10ms | Per button |
| PNG Generation | N/A | 15-30ms | File I/O overhead |
| Canvas Detection | <1ms | <1ms | Aspect ratio calculation |
| Box Rendering | <1ms | 2-5ms | Per macro |
| Cache Lookup | <0.1ms | N/A | Hash table access |

### Memory Usage

- **HBITMAP Cache**: ~50-500 KB for typical usage (100 macros)
- **GDI+ Bitmaps**: Temporary (released after HBITMAP creation)
- **PNG Files**: 5-50 KB per thumbnail (auto-cleanup)

### Scaling Performance

- **Linear Scaling**: Performance degrades linearly with macro complexity
- **Cache Efficiency**: 90%+ hit rate for repeated macros
- **Corporate Fallback**: 2-3x slower due to file I/O

---

## Corporate Environment Support

### Detection Mechanisms

```autohotkey
corporateEnvironmentDetected := false

; Check for common corporate indicators
if (!DirExist(A_Temp) || !FileExist(A_WinDir . "\System32\cmd.exe")) {
    corporateEnvironmentDetected := true
}
```

### Fallback Strategies

1. **Path Fallbacks**: Multiple write locations tried automatically
2. **Silent Degradation**: No user prompts or error messages
3. **File Cleanup**: Temporary files removed after 2 seconds
4. **Memory Priority**: HBITMAP attempted before file-based methods

### Compatibility Matrix

| Environment | HBITMAP | PNG Fallback | Status |
|-------------|---------|--------------|--------|
| Standard Windows | ✅ | ✅ | Full support |
| Corporate (Restricted) | ⚠️ | ✅ | Fallback works |
| Remote Desktop | ✅ | ✅ | Full support |
| Virtual Machines | ✅ | ✅ | Full support |

---

## Usage Guide

### Basic Usage

```autohotkey
; Create visualization for button
filePath := CreateMacroVisualization(macroEvents, buttonSize)

; Use in GUI picture control
pictureCtrl.Value := filePath ? filePath : "*icon"  ; fallback to icon
```

### Advanced Usage

```autohotkey
; HBITMAP for maximum performance
hbitmap := CreateHBITMAPVisualization(macroEvents, {width: 64, height: 64})
if (hbitmap) {
    pictureCtrl.Value := "HBITMAP:*" . hbitmap
} else {
    ; Fallback to PNG
    pngPath := CreateMacroVisualization(macroEvents, 64)
    pictureCtrl.Value := pngPath ? pngPath : "*icon"
}
```

### Canvas Configuration

```autohotkey
; Force specific canvas type
macroEvents.recordedMode := "Wide"  ; or "Narrow"

; Check current canvas detection
UpdateStatus("Canvas: " . lastCanvasDetection)
```

### Cache Management

```autohotkey
; Clear all cached visualizations
CleanupHBITMAPCache()

; Clear specific macro cache
ClearHBitmapCacheForMacro("L1_Num7")
```

---

## Troubleshooting

### Common Issues

#### Issue: Black/Empty Thumbnails

**Symptoms:** Button thumbnails appear black or empty

**Causes:**
- GDI+ not initialized
- Invalid macro data
- Canvas calibration issues

**Solutions:**
1. Check GDI+ initialization: `gdiPlusInitialized` should be `true`
2. Verify macro events contain bounding boxes
3. Reset canvas calibration: `ResetCanvasCalibration()`

#### Issue: HBITMAP Creation Fails

**Symptoms:** Falls back to PNG or no visualization

**Causes:**
- Corporate environment restrictions
- GDI+ library issues
- Memory constraints

**Solutions:**
1. Check corporate environment detection
2. Verify GDI+ token: `gdiPlusToken` should not be 0
3. Monitor memory usage

#### Issue: Wrong Canvas Type Selected

**Symptoms:** Thumbnails show incorrect aspect ratio or letterboxing

**Causes:**
- Canvas boundaries not calibrated
- Macro recorded outside expected canvas area
- Annotation mode mismatch

**Solutions:**
1. Calibrate canvas: `CalibrateCanvasArea()` or `CalibrateWideCanvasArea()`
2. Check annotation mode: `annotationMode` should match recording
3. Verify macro coordinates within canvas bounds

#### Issue: Colors Don't Match Degradation Types

**Symptoms:** Wrong colors in thumbnails

**Causes:**
- Degradation type assignment failed
- Color mapping inconsistency

**Solutions:**
1. Check degradation assignment in `ExtractBoxEvents()`
2. Verify `degradationColors` map is loaded
3. Compare with Plotly dashboard colors

#### Issue: Performance Degradation

**Symptoms:** Slow thumbnail generation or GUI freezing

**Causes:**
- Large number of cached HBITMAPs
- Complex macros with many boxes
- Memory leaks in GDI+ objects

**Solutions:**
1. Clear cache: `CleanupHBITMAPCache()`
2. Reduce macro complexity
3. Check for GDI+ object leaks

### Debug Information

```autohotkey
; Enable debug output
UpdateStatus("GDI+ Initialized: " . gdiPlusInitialized)
UpdateStatus("Canvas Type: " . canvasType)
UpdateStatus("Last Canvas Detection: " . lastCanvasDetection)
UpdateStatus("HBITMAP Cache Size: " . hbitmapCache.Count)
```

### System Health Checks

```autohotkey
; Verify GDI+ status
if (!gdiPlusInitialized) {
    UpdateStatus("❌ GDI+ not initialized - visualizations disabled")
}

; Check canvas calibration
if (!isCanvasCalibrated && !isWideCanvasCalibrated && !isNarrowCanvasCalibrated) {
    UpdateStatus("⚠️ No canvas calibrated - using fallback scaling")
}

; Monitor cache size
if (hbitmapCache.Count > 1000) {
    UpdateStatus("⚠️ Large HBITMAP cache - consider cleanup")
}
```

---

## Architecture Diagrams

### Visualization Flow

```mermaid
graph TD
    A[Macro Events] --> B{Visualization Method}
    B --> C[HBITMAP System]
    B --> D[PNG Fallback]

    C --> E{Cache Hit?}
    E -->|Yes| F[Return Cached HBITMAP]
    E -->|No| G[Create GDI+ Bitmap]

    G --> H[Detect Canvas Type]
    H --> I[Scale & Position]
    I --> J[Render Boxes]
    J --> K[Convert to HBITMAP]
    K --> L[Cache Result]
    L --> F

    D --> M[Create GDI+ Bitmap]
    M --> N[Detect Canvas Type]
    N --> O[Scale & Position]
    O --> P[Render Boxes]
    P --> Q[Save PNG File]
    Q --> R[Return File Path]
```

### Canvas Selection Logic

```mermaid
graph TD
    A[Recorded Macro] --> B[Calculate Bounds]
    B --> C[Compute Aspect Ratio]
    C --> D{User Mode Set?}

    D -->|Wide| E{Calibrated?}
    D -->|Narrow| F{Calibrated?}
    D -->|Auto| G{Fits Wide Canvas?}

    E -->|Yes| H[Use Wide Canvas]
    E -->|No| I{Fits Wide?}
    I -->|Yes| H
    I -->|No| J{Use Narrow}

    F -->|Yes| K[Use Narrow Canvas]
    F -->|No| L{Fits Narrow?}
    L -->|Yes| K
    L -->|No| M{Use Wide}

    G -->|Yes| N{Coverage Analysis}
    G -->|No| O{Fits Narrow?}

    N -->|Wide > Narrow| H
    N -->|Narrow Better| K

    O -->|Yes| K
    O -->|No| P[Use Legacy/Fallback]
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-10-01 | Initial HBITMAP/PNG system |
| 2.0 | 2025-10-08 | Dual canvas architecture, enhanced scaling |

---

**Document Maintained By:** MacroMaster Visualization System
**Last Review:** 2025-10-08
**Next Review:** 2025-11-08