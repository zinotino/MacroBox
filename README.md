# Foolproof Multi-Monitor Calibration System

## Overview

This system works on ANY monitor setup (single, dual, ultrawide, vertical, negative coordinates, etc.) because it uses **universal proportional scaling** with no setup-specific logic.

Each user calibrates once for their setup. Everything else is automatic.

---

## What to Ship

### config.ini (Uncalibrated Defaults)

```ini
[Canvas]
wideCanvasLeft=0
wideCanvasTop=0
wideCanvasRight=1920
wideCanvasBottom=1080
isWideCanvasCalibrated=0

narrowCanvasLeft=0
narrowCanvasTop=0
narrowCanvasRight=1440
narrowCanvasBottom=1080
isNarrowCanvasCalibrated=0
```

**Key:** `isWideCanvasCalibrated=0` and `isNarrowCanvasCalibrated=0`

Ship with both UNCALIBRATED. Users will calibrate on first run.

---

## System Architecture

### 1. CALIBRATION (User Runs Once Per Setup)

```ahk
CalibrateWideCanvas() {
    global wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom, isWideCanvasCalibrated
    global configFile
    
    CoordMode("Mouse", "Screen")
    
    MsgBox("CALIBRATE WIDE CANVAS`n`n1. Click the TOP-LEFT corner of where you draw`n2. Click the BOTTOM-RIGHT corner of where you draw`n`n(Works with any monitor layout: left, right, negative coords, etc.)")
    
    UpdateStatus("Waiting for top-left click...")
    KeyWait("LButton", "D")
    MouseGetPos(&x1, &y1)
    Sleep(200)
    
    UpdateStatus("Waiting for bottom-right click...")
    KeyWait("LButton", "D")
    MouseGetPos(&x2, &y2)
    
    ; Store raw screen pixels (negatives OK)
    wideCanvasLeft := Min(x1, x2)
    wideCanvasTop := Min(y1, y2)
    wideCanvasRight := Max(x1, x2)
    wideCanvasBottom := Max(y1, y2)
    isWideCanvasCalibrated := 1
    
    SaveCanvasToConfig()
    
    canvasW := wideCanvasRight - wideCanvasLeft
    canvasH := wideCanvasBottom - wideCanvasTop
    UpdateStatus("✓ Wide calibrated: " . canvasW . "x" . canvasH . " (L=" . wideCanvasLeft . " R=" . wideCanvasRight . ")")
}

CalibrateNarrowCanvas() {
    ; Same as above, but for narrowCanvasLeft/Right/Top/Bottom
    ; User calibrates the narrow 4:3 region
}
```

**What happens:**
- User clicks where they actually draw
- Raw screen pixel coordinates are captured (negative X allowed)
- Saved to config.ini
- Program uses these exact coordinates for all future rendering on this setup

---

### 2. RECORDING (Already Working Correctly)

```ahk
MouseProc(nCode, wParam, lParam) {
    ; When user draws a box on screen:
    ; LEFT mouse down at screen position (-1768, 271)
    ; LEFT mouse up at screen position (-1542, 507)
    
    ; Stored as:
    ; boundingBox,-1768,271,-1542,507
    
    ; This is RAW SCREEN PIXELS. No conversion. No normalization.
}
```

**Key:** Events store exactly what MouseGetPos() returns. Nothing else.

---

### 3. RENDERING (Universal Math)

```ahk
DrawBoxes(graphics, buttonWidth, buttonHeight, boxes, canvasLeft, canvasTop, canvasRight, canvasBottom, macroMode) {
    global degradationColors
    
    canvasW := canvasRight - canvasLeft
    canvasH := canvasBottom - canvasTop
    
    if (canvasW <= 0 || canvasH <= 0) {
        OutputDebug("ERROR: Canvas has zero/negative dimensions")
        return 0
    }
    
    ; Visual letterbox setup for Narrow mode (not in math, just visual)
    offsetX := 0
    offsetY := 0
    
    if (macroMode = "Narrow") {
        narrowAspect := 4.0 / 3.0
        buttonAspect := buttonWidth / buttonHeight
        
        if (buttonAspect > narrowAspect) {
            contentHeight := buttonHeight
            contentWidth := contentHeight * narrowAspect
        } else {
            contentWidth := buttonWidth
            contentHeight := contentWidth / narrowAspect
        }
        
        offsetX := (buttonWidth - contentWidth) / 2
        offsetY := (buttonHeight - contentHeight) / 2
    }
    
    drawnCount := 0
    
    for box in boxes {
        ; THE UNIVERSAL FORMULA
        ; No setup-specific logic. Works on any coordinate system.
        boxLeft   := (box.left - canvasLeft) / canvasW * buttonWidth
        boxTop    := (box.top - canvasTop) / canvasH * buttonHeight
        boxRight  := (box.right - canvasLeft) / canvasW * buttonWidth
        boxBottom := (box.bottom - canvasTop) / canvasH * buttonHeight
        
        ; Get box color (degradation type)
        boxColor := 0xFF00FF00  ; Green default
        if (IsObject(box) && box.HasOwnProp("categoryId") && degradationColors.Has(box.categoryId))
            boxColor := degradationColors[box.categoryId]
        
        ; Draw filled rectangle
        brush := 0
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", boxColor, "Ptr*", &brush)
        DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", brush,
                "Float", boxLeft, "Float", boxTop, "Float", boxRight - boxLeft, "Float", boxBottom - boxTop)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
        
        drawnCount++
    }
    
    ; Draw letterbox frame for Narrow (visual identification only)
    if (macroMode = "Narrow" && drawnCount > 0) {
        penHandle := 0
        DllCall("gdiplus\GdipCreatePen1", "UInt", 0xFF555555, "Float", 2.0, "Int", 2, "Ptr*", &penHandle)
        DllCall("gdiplus\GdipDrawRectangle", "Ptr", graphics, "Ptr", penHandle, 
                "Float", offsetX, "Float", offsetY, "Float", contentWidth, "Float", contentHeight)
        DllCall("gdiplus\GdipDeletePen", "Ptr", penHandle)
    }
    
    return drawnCount
}
```

**Call it:**
```ahk
if (macroMode = "Wide") {
    DrawBoxes(graphics, buttonWidth, buttonHeight, boxes, 
              wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom, "Wide")
} else if (macroMode = "Narrow") {
    DrawBoxes(graphics, buttonWidth, buttonHeight, boxes,
              narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom, "Narrow")
}
```

---

### 4. CONFIG SAVE/LOAD (Persistent Across Restarts)

```ahk
SaveCanvasToConfig() {
    global wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom, isWideCanvasCalibrated
    global narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom, isNarrowCanvasCalibrated
    global configFile
    
    IniWrite(wideCanvasLeft, configFile, "Canvas", "wideCanvasLeft")
    IniWrite(wideCanvasTop, configFile, "Canvas", "wideCanvasTop")
    IniWrite(wideCanvasRight, configFile, "Canvas", "wideCanvasRight")
    IniWrite(wideCanvasBottom, configFile, "Canvas", "wideCanvasBottom")
    IniWrite(isWideCanvasCalibrated ? 1 : 0, configFile, "Canvas", "isWideCanvasCalibrated")
    
    IniWrite(narrowCanvasLeft, configFile, "Canvas", "narrowCanvasLeft")
    IniWrite(narrowCanvasTop, configFile, "Canvas", "narrowCanvasTop")
    IniWrite(narrowCanvasRight, configFile, "Canvas", "narrowCanvasRight")
    IniWrite(narrowCanvasBottom, configFile, "Canvas", "narrowCanvasBottom")
    IniWrite(isNarrowCanvasCalibrated ? 1 : 0, configFile, "Canvas", "isNarrowCanvasCalibrated")
}

LoadCanvasFromConfig() {
    global wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom, isWideCanvasCalibrated
    global narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom, isNarrowCanvasCalibrated
    global configFile
    
    if (!FileExist(configFile))
        return
    
    wideCanvasLeft := IniRead(configFile, "Canvas", "wideCanvasLeft", 0)
    wideCanvasTop := IniRead(configFile, "Canvas", "wideCanvasTop", 0)
    wideCanvasRight := IniRead(configFile, "Canvas", "wideCanvasRight", 1920)
    wideCanvasBottom := IniRead(configFile, "Canvas", "wideCanvasBottom", 1080)
    isWideCanvasCalibrated := IniRead(configFile, "Canvas", "isWideCanvasCalibrated", 0)
    
    narrowCanvasLeft := IniRead(configFile, "Canvas", "narrowCanvasLeft", 0)
    narrowCanvasTop := IniRead(configFile, "Canvas", "narrowCanvasTop", 0)
    narrowCanvasRight := IniRead(configFile, "Canvas", "narrowCanvasRight", 1440)
    narrowCanvasBottom := IniRead(configFile, "Canvas", "narrowCanvasBottom", 1080)
    isNarrowCanvasCalibrated := IniRead(configFile, "Canvas", "isNarrowCanvasCalibrated", 0)
}
```

---

### 5. STARTUP CHECK (Prevent Errors)

```ahk
Main() {
    LoadCanvasFromConfig()
    
    ; Check if calibrated
    if (!isWideCanvasCalibrated || !isNarrowCanvasCalibrated) {
        MsgBox("⚠️ FIRST TIME SETUP`n`nCanvas not calibrated. You must calibrate before recording.`n`nGo to Settings → Calibrate Canvas")
        ShowSettingsWindow()  ; Show calibration UI
        return
    }
    
    ; Continue with normal startup
}
```

---

## Why This Works on Any Setup

### Example 1: Work (Dual Monitor, Left Negative)

```
Physical Setup:
  Left Monitor: X = -1920 to 0
  Right Laptop: X = 0 to 1920

User Calibrates:
  Clicks: (-1500, 100) → (-500, 1000)
  Saved: L=-1500, R=-500

Recording Macro:
  Draws boxes: (-1400, 200), (-600, 900), etc.

Rendering Math:
  buttonX = (-1400 - (-1500)) / (-500 - (-1500)) * 392
  buttonX = 100 / 1000 * 392 = 39.2
  ✓ Correct position on button
```

### Example 2: Home (Single Monitor, Positive)

```
Physical Setup:
  Main Monitor: X = 0 to 1920

User Calibrates (fresh install or recalibrate):
  Clicks: (200, 100) → (1700, 1000)
  Saved: L=200, R=1700

Recording Macro:
  Draws boxes: (400, 200), (1200, 900), etc.

Rendering Math:
  buttonX = (400 - 200) / (1700 - 200) * 392
  buttonX = 200 / 1500 * 392 = 52.3
  ✓ Correct position on button
```

### Example 3: Ultrawide Single Monitor

```
Physical Setup:
  Ultrawide: X = 0 to 3440

User Calibrates:
  Clicks: (500, 100) → (3000, 1000)
  Saved: L=500, R=3000

Rendering Math:
  Works the same. Pure proportional scaling.
  ✓ Correct position on button
```

---

## User Experience

### First Run
1. User starts program
2. Gets warning: "Canvas not calibrated"
3. Goes to Settings → Calibrate Wide
4. Clicks top-left of their canvas area
5. Clicks bottom-right of their canvas area
6. Status: "✓ Wide calibrated: 1500x900 (L=-1500 R=-500)"
7. Repeats for Narrow (if using both modes)
8. Records macros, visualizations appear correctly

### Subsequent Runs
1. Program loads config with calibrated values
2. Everything works automatically
3. User records, calibrates, records... no recalibration needed unless they move to a different physical setup

---

## Troubleshooting

### Visualizations Don't Appear

**Check:**
```ahk
; Add to rendering code
if (!isWideCanvasCalibrated) {
    MsgBox("Canvas not calibrated. Please calibrate first.")
    return 0
}

if (wideCanvasRight <= wideCanvasLeft || wideCanvasBottom <= wideCanvasTop) {
    MsgBox("Canvas has invalid dimensions. Please recalibrate.")
    return 0
}
```

**Solution:** Recalibrate. Click in the actual area where boxes are drawn.

### Boxes Appear in Wrong Position

**Cause:** Calibration was done in a different area than where boxes are being drawn.

**Solution:** Recalibrate in the exact area where you're drawing boxes.

### Boxes Appear Off-Screen

**Cause:** Box coordinates are outside calibrated canvas.

**Solution:** Recalibrate to include the full area where you draw.

---

## Code Checklist

- [ ] Ship config.ini with `isWideCanvasCalibrated=0`
- [ ] CalibrateWideCanvas() uses `CoordMode("Mouse", "Screen")`
- [ ] CalibrateWideCanvas() saves raw pixel values (no conversion)
- [ ] CalibrateNarrowCanvas() exists (same structure)
- [ ] DrawBoxes() uses only: `(box.coord - canvas.min) / canvas.size * button.size`
- [ ] No virtual screen math in rendering
- [ ] No normalization in rendering
- [ ] No offsets in scaling (only in letterbox frame)
- [ ] LoadCanvasFromConfig() called at startup
- [ ] Startup checks `isWideCanvasCalibrated` before rendering

---

## Summary

| Aspect | Approach |
|--------|----------|
| **Distribution** | Ship uncalibrated (0,0,1920,1080) |
| **User Setup** | Calibrate once per physical setup |
| **Storage** | Raw screen pixels (negatives OK) |
| **Rendering** | Universal proportional math |
| **Portability** | Works on any monitor arrangement |
| **Complexity** | Minimal (two calibration functions, one render function) |

This system is foolproof because it delegates setup-specific logic to the user (one-time calibration) and uses only universal math (proportional scaling) for everything else.
