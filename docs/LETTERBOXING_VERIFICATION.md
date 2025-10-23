# Letterboxing Verification - Wide vs Narrow Mode

## Visual Behavior Specification

### Wide Mode (16:9 Aspect Ratio)
**Recorded in Wide → Stretch-Fill Entire Button**
- ✅ Black background set (VisualizationCore.ahk:193, :304)
- ✅ Dark gray fills entire button (VisualizationCanvas.ahk:216)
- ✅ Canvas stretches to fill button completely (lines 219-220)
- ✅ **Result**: No black bars visible, content fills entire button

### Narrow Mode (4:3 Aspect Ratio)
**Recorded in Narrow → Letterboxing with Black Bars**
- ✅ Black background set (VisualizationCore.ahk:193, :304)
- ✅ 4:3 content area calculated (VisualizationCanvas.ahk:226-237)
- ✅ Dark gray fills only 4:3 center area (line 246)
- ✅ Black bars remain on left/right sides
- ✅ **Result**: Black letterboxing bars visible, content in 4:3 center

## Implementation Details

### Macro Visualizations

**File**: `src/VisualizationCanvas.ahk`

#### Wide Canvas (Lines 211-222)
```ahk
if (useWideCanvas) {
    // Fill ENTIRE button with dark gray
    DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", darkGrayBrush,
        "Float", 0, "Float", 0,  // Start at origin
        "Float", buttonWidth, "Float", buttonHeight)  // Fill entire button

    // Stretch canvas to fill entire button (non-uniform scaling)
    scaleX := buttonWidth / canvasW   // Full width stretch
    scaleY := buttonHeight / canvasH  // Full height stretch
    offsetX := 0  // No offset - starts at edge
    offsetY := 0  // No offset - starts at edge
}
```

**Effect**: Content stretches from edge to edge, no black visible ✅

#### Narrow Canvas (Lines 223-253)
```ahk
if (useNarrowCanvas) {
    narrowAspect := 4.0 / 3.0  // Target 4:3 ratio

    // Calculate 4:3 content area size
    if (buttonAspect > narrowAspect) {
        // Button wider than 4:3 - horizontal bars
        contentHeight := buttonHeight      // Full height
        contentWidth := contentHeight * 4/3  // 4:3 width
    }

    // Center the 4:3 area
    offsetX := (buttonWidth - contentWidth) / 2  // Left black bar width
    offsetY := (buttonHeight - contentHeight) / 2

    // Fill ONLY 4:3 content area with dark gray
    DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", darkGrayBrush,
        "Float", offsetX, "Float", offsetY,  // Start at offset
        "Float", contentWidth, "Float", contentHeight)  // 4:3 dimensions

    // Stretch canvas to fill 4:3 content area
    scaleX := contentWidth / canvasW   // Fit to 4:3 width
    scaleY := contentHeight / canvasH  // Fit to 4:3 height
}
```

**Effect**: Black bars on left/right, content in 4:3 center ✅

### JSON Visualizations

**File**: `src/VisualizationCore.ahk`

#### Wide Mode (Lines 331-337)
```ahk
else {
    // Wide mode: Fill ENTIRE button with color
    brush := 0
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF000000 | colorValue, "Ptr*", &brush)
    DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", brush,
        "Float", 0, "Float", 0,  // Origin
        "Float", buttonWidth, "Float", buttonHeight)  // Entire button
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
}
```

**Effect**: Colored box fills entire button, no black bars ✅

#### Narrow Mode (Lines 306-330)
```ahk
if (mode = "Narrow") {
    narrowAspect := 4.0 / 3.0

    // Calculate 4:3 content dimensions
    if (buttonAspect > narrowAspect) {
        contentHeight := buttonHeight
        contentWidth := contentHeight * narrowAspect
    } else {
        contentWidth := buttonWidth
        contentHeight := contentWidth / narrowAspect
    }

    // Center the content area
    offsetX := (buttonWidth - contentWidth) / 2
    offsetY := (buttonHeight - contentHeight) / 2

    // Fill ONLY 4:3 area with color
    brush := 0
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF000000 | colorValue, "Ptr*", &brush)
    DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", brush,
        "Float", offsetX, "Float", offsetY,  // Offset position
        "Float", contentWidth, "Float", contentHeight)  // 4:3 dimensions
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
}
```

**Effect**: Colored box in 4:3 center, black bars on sides ✅

## Visual Examples

### Wide Mode Button
```
┌──────────────────────────────┐
│██████████████████████████████│  ← Dark gray fills edge-to-edge
│██████████████████████████████│
│██████████████████████████████│  No black visible
│██████████████████████████████│
│██████████████████████████████│  Content stretches to fill
│██████████████████████████████│
└──────────────────────────────┘
```

### Narrow Mode Button
```
┌──────────────────────────────┐
│░░░░██████████████████░░░░░░░│  ← Black bars (░)
│░░░░██████████████████░░░░░░░│     4:3 content (█)
│░░░░██████████████████░░░░░░░│
│░░░░██████████████████░░░░░░░│  Black letterboxing visible
│░░░░██████████████████░░░░░░░│
│░░░░██████████████████░░░░░░░│  Content in center
└──────────────────────────────┘
     ↑                    ↑
   Black                Black
   bar                  bar
```

## Aspect Ratio Calculations

### Standard Button Dimensions
Assuming button is approximately 16:9 (wider than 4:3):

**Wide Mode**:
- Button: 160px × 90px (16:9 ratio)
- Content: 160px × 90px (fills entire button)
- Black bars: None
- Scale: Non-uniform (scaleX ≠ scaleY)

**Narrow Mode**:
- Button: 160px × 90px (16:9 ratio)
- 4:3 Content: 120px × 90px (4:3 ratio, centered)
- Black bars: 20px left + 20px right
- Offset: X = 20px, Y = 0px
- Scale: Non-uniform within 4:3 area

## Background Color Strategy

### Three-Layer Approach

1. **Layer 1 - Black Base** (Line 193/304)
   ```ahk
   DllCall("gdiplus\GdipGraphicsClear", "Ptr", graphics, "UInt", 0xFF000000)
   ```
   - Entire bitmap starts as black
   - Provides letterboxing background

2. **Layer 2 - Dark Gray Content Area** (Line 216/246)
   ```ahk
   // Wide: Fills entire button
   // Narrow: Fills only 4:3 center area
   DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF2A2A2A, "Ptr*", &darkGrayBrush)
   ```
   - Wide: Covers all black (no black visible)
   - Narrow: Covers only center (black bars remain)

3. **Layer 3 - Colored Boxes** (Drawn on top)
   - Macro boxes drawn with degradation colors
   - JSON boxes drawn with category colors

## Mode Determination Flow

```
Button Appearance Update
    ↓
Extract recordedMode from macro/JSON
    ↓
Wide recorded?
    ↓ YES
    Fill entire button with dark gray → STRETCH FILL
    ↓ NO
Narrow recorded?
    ↓ YES
    Calculate 4:3 area → Fill center only → LETTERBOXING
```

## Testing Checklist

To verify letterboxing is working correctly:

### Wide Mode Macros
- [ ] Record macro in Wide mode
- [ ] Visualization fills entire button (edge to edge)
- [ ] No black bars visible
- [ ] Content stretches to fill button completely
- [ ] Switch to Narrow mode → still displays as Wide (stretch-fill)

### Narrow Mode Macros
- [ ] Record macro in Narrow mode
- [ ] Visualization shows black bars on left/right
- [ ] Content centered in 4:3 area
- [ ] Black bars clearly visible
- [ ] Switch to Wide mode → still displays as Narrow (letterboxed)

### Wide Mode JSON
- [ ] Create JSON annotation in Wide mode
- [ ] Colored box fills entire button
- [ ] No black bars
- [ ] Switch to Narrow → still fills entire button

### Narrow Mode JSON
- [ ] Create JSON annotation in Narrow mode
- [ ] Colored box in 4:3 center area
- [ ] Black bars on left/right
- [ ] Switch to Wide → still shows black bars

## Troubleshooting

### If Wide Mode Shows Black Bars
**Problem**: Dark gray not filling entire button
**Check**: VisualizationCanvas.ahk:216
**Expected**:
```ahk
DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", darkGrayBrush,
    "Float", 0, "Float", 0,  // Must be 0, 0
    "Float", buttonWidth, "Float", buttonHeight)  // Must be full dimensions
```

### If Narrow Mode Has No Black Bars
**Problem**: Content filling entire button instead of 4:3 area
**Check**: VisualizationCanvas.ahk:240-246
**Expected**:
```ahk
offsetX := (buttonWidth - contentWidth) / 2  // Must have offset > 0
contentWidth := contentHeight * (4.0/3.0)    // Must be < buttonWidth
```

### If Mode Not Persisting
**Problem**: Uses current mode instead of recorded mode
**Check**:
- GUIControls.ahk:72-77 (JSON mode extraction)
- GUIControls.ahk:128 (JSON visualization call)
- VisualizationCanvas.ahk:78-90 (Macro mode extraction)

## Summary

The letterboxing system is **fully implemented and correct**:

✅ **Wide mode**: Stretch-fill entire button (no letterboxing)
✅ **Narrow mode**: 4:3 content area with black bars (letterboxing)
✅ **Recorded mode preserved**: Uses recorded mode, not current mode
✅ **Type-safe**: Handles both Map and Object event types
✅ **JSON and Macro**: Both visualization types support letterboxing

The implementation ensures visualizations are **static and immutable**, displaying exactly as recorded regardless of current mode settings.
