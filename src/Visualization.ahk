; ===== VISUALIZATION.AHK - GDI+ Macro Visualization System =====
; This module contains all visualization-related functionality


CreateMacroVisualization(macroEvents, buttonDims) {
    global gdiPlusInitialized, degradationColors, canvasType

    if (!gdiPlusInitialized || !macroEvents || macroEvents.Length = 0) {
        return ""
    }

    ; Extract box drawing events
    boxes := ExtractBoxEvents(macroEvents)
    if (boxes.Length = 0) {
        return ""
    }

    ; Handle both old (single size) and new (width/height object) format
    if (IsObject(buttonDims)) {
        buttonWidth := buttonDims.width
        buttonHeight := buttonDims.height
    } else {
        buttonWidth := buttonDims
        buttonHeight := buttonDims
    }

    ; Create visualization bitmap with proper dimensions
    try {
        bitmap := 0
        DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", buttonWidth, "Int", buttonHeight, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bitmap)

        graphics := 0
        DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bitmap, "Ptr*", &graphics)

        ; Clean white background for better clarity
        DllCall("gdiplus\GdipGraphicsClear", "Ptr", graphics, "UInt", 0xFFFFFFFF)

        ; Skip canvas type indicator - not needed for button view

        ; Draw macro boxes optimized for button dimensions
        DrawMacroBoxesOnButton(graphics, buttonWidth, buttonHeight, boxes)

        ; Save to temporary file
        tempFile := A_Temp . "\macro_viz_" . A_TickCount . ".png"
        SaveVisualizationPNG(bitmap, tempFile)

        ; Cleanup
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", bitmap)

        return FileExist(tempFile) ? tempFile : ""

    } catch Error as e {
        return ""
    }
}

ExtractBoxEvents(macroEvents) {
    boxes := []
    currentDegradationType := 1  ; Default degradation type

    ; DEBUG: Log what we're looking for
    ; UpdateStatus("🔍 DEBUG: ExtractBoxEvents called with " . macroEvents.Length . " events")

    ; Look for boundingBox events and keypress assignments in MacroLauncherX44 format
    for eventIndex, event in macroEvents {
        ; DEBUG: Check event types
        ; if (eventIndex <= 5) {
        ;     UpdateStatus("🔍 DEBUG: Event " . eventIndex . ": type=" . event.type)
        ; }

        if (event.type = "boundingBox" && event.HasOwnProp("left") && event.HasOwnProp("top") && event.HasOwnProp("right") && event.HasOwnProp("bottom")) {
            ; Calculate box dimensions
            left := event.left
            top := event.top
            right := event.right
            bottom := event.bottom

            ; Only include boxes that are reasonably sized
            if ((right - left) >= 5 && (bottom - top) >= 5) {
                ; Look for a keypress AFTER this box to determine degradation type
                degradationType := currentDegradationType

                ; Look ahead for keypress events that assign degradation type
                nextIndex := eventIndex + 1
                while (nextIndex <= macroEvents.Length) {
                    nextEvent := macroEvents[nextIndex]

                    ; Stop at next bounding box - keypress should be immediately after current box
                    if (nextEvent.type = "boundingBox")
                        break

                    ; Found a keypress after this box - this assigns the degradation type
                    if (nextEvent.type = "keyDown" && RegExMatch(nextEvent.key, "^\d$")) {
                        keyNumber := Integer(nextEvent.key)
                        if (keyNumber >= 1 && keyNumber <= 9) {
                            degradationType := keyNumber
                            currentDegradationType := keyNumber  ; Update current degradation for subsequent boxes
                            break
                        }
                    }

                    nextIndex++
                }

                box := {
                    left: left,
                    top: top,
                    right: right,
                    bottom: bottom,
                    degradationType: degradationType
                }
                boxes.Push(box)
                ; DEBUG: Log found box
                ; UpdateStatus("🔍 DEBUG: Found box: " . left . "," . top . " to " . right . "," . bottom . " (type: " . degradationType . ")")
            }
        }
    }

    ; DEBUG: Log result
    ; UpdateStatus("🔍 DEBUG: ExtractBoxEvents returning " . boxes.Length . " boxes")

    return boxes
}

GetVisualizationBackground(canvasType) {
    ; Return background colors that distinguish canvas types
    switch canvasType {
        case "wide":
            return 0xFFF0F8FF  ; Alice blue tint - indicates wide macro
        case "narrow":
            return 0xFFF5F5DC  ; Beige tint - indicates narrow macro
        default:
            return 0xFFF8F8FF  ; Ghost white - indicates custom macro
    }
}

DrawCanvasTypeIndicator(graphics, size, canvasType) {
    ; Draw canvas type indicator in top-right corner
    indicatorSize := size / 8
    x := size - indicatorSize - 2
    y := 2

    ; Choose indicator color and style based on canvas type
    if (canvasType = "wide") {
        indicatorColor := 0xFF4169E1  ; Royal blue
        ; Draw rectangle for wide
        brush := 0
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", indicatorColor, "Ptr*", &brush)
        DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", brush, "Float", x, "Float", y + indicatorSize/4, "Float", indicatorSize, "Float", indicatorSize/2)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
    } else if (canvasType = "narrow") {
        indicatorColor := 0xFF32CD32  ; Lime green
        ; Draw vertical rectangle for narrow
        brush := 0
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", indicatorColor, "Ptr*", &brush)
        DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", brush, "Float", x + indicatorSize/4, "Float", y, "Float", indicatorSize/2, "Float", indicatorSize)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
    } else {
        indicatorColor := 0xFFFF6347  ; Tomato (custom)
        ; Draw circle for custom
        brush := 0
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", indicatorColor, "Ptr*", &brush)
        DllCall("gdiplus\GdipFillEllipse", "Ptr", graphics, "Ptr", brush, "Float", x, "Float", y, "Float", indicatorSize, "Float", indicatorSize)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
    }
}

; DUAL CANVAS CONFIGURATION SYSTEM:
; Analyzes recorded macro aspect ratio to choose appropriate canvas configuration
; - Wide recorded macros (aspect ratio > 1.5) → Use WIDE canvas config → STRETCH to fill thumbnail (no black bars)
; - Narrow recorded macros (aspect ratio <= 1.5) → Use NARROW canvas config → Black bars based on configured narrow aspect ratio
; - Canvas choice based on RECORDED CONTENT characteristics, not button size
; - Clean visualization without indicators for maximum aesthetic appeal
DrawMacroBoxesOnButton(graphics, buttonWidth, buttonHeight, boxes) {
    global degradationColors, annotationMode, userCanvasLeft, userCanvasTop, userCanvasRight, userCanvasBottom, isCanvasCalibrated
    global wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom, isWideCanvasCalibrated
    global narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom, isNarrowCanvasCalibrated

    if (boxes.Length = 0) {
        return
    }

    ; Analyze the recorded macro to determine which canvas configuration to use
    ; Calculate bounding box of all recorded content
    minX := 999999, minY := 999999, maxX := 0, maxY := 0
    for box in boxes {
        minX := Min(minX, box.left)
        minY := Min(minY, box.top)
        maxX := Max(maxX, box.right)
        maxY := Max(maxY, box.bottom)
    }

    recordedWidth := maxX - minX
    recordedHeight := maxY - minY
    recordedAspectRatio := recordedWidth / recordedHeight

    ; INTELLIGENT CANVAS DETECTION: Check both aspect ratio and coordinate boundaries
    ; to determine the most appropriate canvas configuration

    ; PRECISION CANVAS DETECTION: Enhanced boundary checking with improved tolerance
    wideCanvasW := wideCanvasRight - wideCanvasLeft
    wideCanvasH := wideCanvasBottom - wideCanvasTop
    narrowCanvasW := narrowCanvasRight - narrowCanvasLeft
    narrowCanvasH := narrowCanvasBottom - narrowCanvasTop

    ; Use more generous tolerance for real-world recording variations (5 pixel tolerance)
    edgeTolerance := 5

    ; More robust boundary checking that accounts for recording variations
    fitsInWideCanvas := (minX >= (wideCanvasLeft - edgeTolerance) &&
                          maxX <= (wideCanvasRight + edgeTolerance) &&
                          minY >= (wideCanvasTop - edgeTolerance) &&
                          maxY <= (wideCanvasBottom + edgeTolerance))

    fitsInNarrowCanvas := (minX >= (narrowCanvasLeft - edgeTolerance) &&
                            maxX <= (narrowCanvasRight + edgeTolerance) &&
                            minY >= (narrowCanvasTop - edgeTolerance) &&
                            maxY <= (narrowCanvasBottom + edgeTolerance))

    ; Calculate coverage percentages for better canvas selection
    wideCoverage := 0
    narrowCoverage := 0

    if (fitsInWideCanvas) {
        ; Calculate what percentage of the wide canvas is actually used
        usedWideW := maxX - minX
        usedWideH := maxY - minY
        wideCoverage := (usedWideW * usedWideH) / (wideCanvasW * wideCanvasH)
    }

    if (fitsInNarrowCanvas) {
        ; Calculate what percentage of the narrow canvas is actually used
        usedNarrowW := maxX - minX
        usedNarrowH := maxY - minY
        narrowCoverage := (usedNarrowW * usedNarrowH) / (narrowCanvasW * narrowCanvasH)
    }

    ; RESPECT ANNOTATION MODE: Override intelligent detection with user preference
    if (annotationMode = "Wide") {
        ; User selected Wide mode - use calibrated wide canvas if available, otherwise detected
        if (isWideCanvasCalibrated) {
            useWideCanvas := true
            useNarrowCanvas := false
            useLegacyCanvas := false
        } else if (fitsInWideCanvas) {
            useWideCanvas := true
            useNarrowCanvas := false
            useLegacyCanvas := false
        } else {
            ; Wide canvas not available - use narrow or fallback
            useWideCanvas := false
            useNarrowCanvas := fitsInNarrowCanvas
            useLegacyCanvas := !fitsInNarrowCanvas
        }
    } else if (annotationMode = "Narrow") {
        ; User selected Narrow mode - use calibrated narrow canvas if available, otherwise detected
        if (isNarrowCanvasCalibrated) {
            useWideCanvas := false
            useNarrowCanvas := true
            useLegacyCanvas := false
        } else if (fitsInNarrowCanvas) {
            useWideCanvas := false
            useNarrowCanvas := true
            useLegacyCanvas := false
        } else {
            ; Narrow canvas not available - use wide or fallback
            useWideCanvas := fitsInWideCanvas
            useNarrowCanvas := false
            useLegacyCanvas := !fitsInWideCanvas
        }
    } else {
        ; No annotation mode set - use intelligent detection
        if (fitsInWideCanvas && fitsInNarrowCanvas) {
            ; Both canvases can accommodate the content - choose based on efficiency and aspect ratio
            if (recordedAspectRatio > 1.3) {
                ; Wide aspect ratio content - prefer wide canvas
                useWideCanvas := true
                useNarrowCanvas := false
            } else if (narrowCoverage > wideCoverage * 1.5) {
                ; Narrow canvas provides significantly better space utilization
                useWideCanvas := false
                useNarrowCanvas := true
            } else {
                ; Default to wide canvas for flexibility
                useWideCanvas := true
                useNarrowCanvas := false
            }
            useLegacyCanvas := false
        } else if (fitsInWideCanvas) {
            ; Only wide canvas fits
            useWideCanvas := true
            useNarrowCanvas := false
            useLegacyCanvas := false
        } else if (fitsInNarrowCanvas) {
            ; Only narrow canvas fits
            useWideCanvas := false
            useNarrowCanvas := true
            useLegacyCanvas := false
        } else {
            ; Neither canvas fits - use legacy fallback
            useWideCanvas := false
            useNarrowCanvas := false
            useLegacyCanvas := true
        }
    }

    ; ENHANCED DIAGNOSTIC: Log detailed canvas detection metrics
    debugInfo := "Canvas Detection: "
    debugInfo .= "Recorded(" . Round(minX) . "," . Round(minY) . " to " . Round(maxX) . "," . Round(maxY) . ") "
    debugInfo .= "Aspect:" . Round(recordedAspectRatio, 2) . " "

    if (fitsInWideCanvas) {
        debugInfo .= "WideOK(" . Round(wideCoverage * 100, 1) . "%) "
    }
    if (fitsInNarrowCanvas) {
        debugInfo .= "NarrowOK(" . Round(narrowCoverage * 100, 1) . "%) "
    }

    if (useWideCanvas) {
        debugInfo .= "→ WIDE canvas selected"
    } else if (useNarrowCanvas) {
        debugInfo .= "→ NARROW canvas selected"
    } else {
        debugInfo .= "→ LEGACY fallback (coordinates exceed canvas bounds)"
    }
    ; Temporarily update status with diagnostic info (comment out in production)
    ; UpdateStatus(debugInfo)

    ; Store diagnostic info globally for testing
    global lastCanvasDetection := debugInfo

    ; Choose appropriate canvas configuration based on recorded macro characteristics
    if (useWideCanvas) {
        ; Use WIDE canvas configuration for wide-aspect recorded macros
        canvasLeft := wideCanvasLeft
        canvasTop := wideCanvasTop
        canvasRight := wideCanvasRight
        canvasBottom := wideCanvasBottom
        canvasW := canvasRight - canvasLeft
        canvasH := canvasBottom - canvasTop
    } else if (useNarrowCanvas) {
        ; Use NARROW canvas configuration for narrow-aspect recorded macros
        canvasLeft := narrowCanvasLeft
        canvasTop := narrowCanvasTop
        canvasRight := narrowCanvasRight
        canvasBottom := narrowCanvasBottom
        canvasW := canvasRight - canvasLeft
        canvasH := canvasBottom - canvasTop
    } else if (isCanvasCalibrated) {
        ; Fall back to legacy single canvas configuration
        canvasLeft := userCanvasLeft
        canvasTop := userCanvasTop
        canvasRight := userCanvasRight
        canvasBottom := userCanvasBottom
        canvasW := canvasRight - canvasLeft
        canvasH := canvasBottom - canvasTop
    } else {
        ; Fallback: Use recorded macro bounds with padding (reuse calculated values)
        padding := Min(recordedWidth, recordedHeight) * 0.02
        canvasLeft := minX - padding
        canvasTop := minY - padding
        canvasRight := maxX + padding
        canvasBottom := maxY + padding
        canvasW := canvasRight - canvasLeft
        canvasH := canvasBottom - canvasTop
    }

    ; PROPORTIONAL SCALING: Preserve aspect ratio and center content like on canvas

    ; Dark grey background fills entire thumbnail
    DllCall("gdiplus\GdipGraphicsClear", "Ptr", graphics, "UInt", 0xFF303030)

    ; Calculate proportional scale to fit content while preserving aspect ratio
    scale := Min(buttonWidth / recordedWidth, buttonHeight / recordedHeight)

    ; Center the scaled recorded area in the button
    offsetX := (buttonWidth - recordedWidth * scale) / 2
    offsetY := (buttonHeight - recordedHeight * scale) / 2

    ; Draw the boxes with enhanced precision and accuracy
    for box in boxes {
        ; PROPORTIONAL COORDINATE TRANSFORMATION: Recorded space → Thumbnail space
        ; Use floating-point arithmetic for sub-pixel accuracy with aspect ratio preservation
        rawX1 := ((box.left - minX) * scale) + offsetX
        rawY1 := ((box.top - minY) * scale) + offsetY
        rawX2 := ((box.right - minX) * scale) + offsetX
        rawY2 := ((box.bottom - minY) * scale) + offsetY

        ; Calculate raw dimensions with floating-point precision
        rawW := rawX2 - rawX1
        rawH := rawY2 - rawY1

        ; INTELLIGENT MINIMUM SIZE: Preserve aspect ratio while ensuring visibility
        minSize := 1.5  ; Minimum dimension in pixels

        if (rawW < minSize || rawH < minSize) {
            ; Calculate original aspect ratio
            originalAspect := (box.right - box.left) / (box.bottom - box.top)

            if (rawW < minSize && rawH < minSize) {
                ; Both dimensions too small - scale proportionally
                if (originalAspect > 1) {
                    ; Wider box - set width to minimum, scale height proportionally
                    w := minSize
                    h := minSize / originalAspect
                } else {
                    ; Taller box - set height to minimum, scale width proportionally
                    h := minSize
                    w := minSize * originalAspect
                }
            } else if (rawW < minSize) {
                ; Width too small - adjust while preserving aspect ratio
                w := minSize
                h := minSize / originalAspect
            } else {
                ; Height too small - adjust while preserving aspect ratio
                h := minSize
                w := minSize * originalAspect
            }

            ; Center the adjusted box on the original position
            centerX := (rawX1 + rawX2) / 2
            centerY := (rawY1 + rawY2) / 2
            x1 := centerX - w / 2
            y1 := centerY - h / 2
            x2 := x1 + w
            y2 := y1 + h
        } else {
            ; Dimensions are adequate - use precise floating-point coordinates
            x1 := rawX1
            y1 := rawY1
            x2 := rawX2
            y2 := rawY2
            w := rawW
            h := rawH
        }

        ; BOUNDS VALIDATION: Ensure coordinates are within thumbnail area
        x1 := Max(0, Min(x1, buttonWidth))
        y1 := Max(0, Min(y1, buttonHeight))
        x2 := Max(0, Min(x2, buttonWidth))
        y2 := Max(0, Min(y2, buttonHeight))
        w := x2 - x1
        h := y2 - y1

        ; Skip boxes that are completely outside the thumbnail area
        if (w <= 0 || h <= 0) {
            continue
        }

        ; Get degradation type color
        if (box.HasOwnProp("degradationType") && degradationColors.Has(box.degradationType)) {
            color := degradationColors[box.degradationType]
        } else {
            color := degradationColors[1]
        }

        ; ENHANCED RENDERING: Pure color with sub-pixel precision
        fillColor := 0xFF000000 | color  ; Full opacity (FF = 255)

        ; Enable high-quality rendering for fractional coordinates
        ; Set graphics to use high-quality smoothing mode for precise rendering
        DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", graphics, "Int", 4)  ; HighQuality
        DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", graphics, "Int", 4) ; HighQuality

        ; Draw with sub-pixel precision using floating-point coordinates
        brush := 0
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", fillColor, "Ptr*", &brush)
        DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", brush, "Float", x1, "Float", y1, "Float", w, "Float", h)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)

        ; Reset to default rendering for other elements
        DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", graphics, "Int", 0)  ; Default
        DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", graphics, "Int", 0) ; Default
    }

}

SaveVisualizationPNG(bitmap, filePath) {
    ; Save bitmap as PNG with Method 4 fallback paths for corporate environments
    clsid := Buffer(16)
    NumPut("UInt", 0x557CF406, clsid, 0)
    NumPut("UInt", 0x11D31A04, clsid, 4)
    NumPut("UInt", 0x0000739A, clsid, 8)
    NumPut("UInt", 0x2EF31EF8, clsid, 12)

    ; Try original path first
    result := DllCall("gdiplus\GdipSaveImageToFile", "Ptr", bitmap, "WStr", filePath, "Ptr", clsid, "Ptr", 0)
    if (result = 0 && FileExist(filePath)) {
        return true
    }

    ; Method 4: Try alternative paths for corporate environments
    fileName := "macro_viz_" . A_TickCount . ".png"
    fallbackPaths := [
        A_ScriptDir . "\" . fileName,
        A_MyDocuments . "\" . fileName,
        EnvGet("USERPROFILE") . "\" . fileName,
        A_Desktop . "\" . fileName,
        A_Temp . "\" . fileName  ; Keep original as last resort
    ]

    for testPath in fallbackPaths {
        try {
            result := DllCall("gdiplus\GdipSaveImageToFile", "Ptr", bitmap, "WStr", testPath, "Ptr", clsid, "Ptr", 0)
            if (result = 0 && FileExist(testPath)) {
                ; Copy successful path back to the expected location for compatibility
                if (testPath != filePath) {
                    try {
                        FileCopy(testPath, filePath, 1)
                        ; Clean up temporary file - capture path in variable for lambda
                        pathToDelete := testPath
                        SetTimer(() => DeleteFile(pathToDelete), -2000)
                    } catch {
                        ; If copy fails, just use the working path - but cannot modify filePath here as it's a parameter
                    }
                }
                return true
            }
        } catch {
            continue
        }
    }

    return false
}

; ===== MACRO VISUALIZATION SYSTEM INITIALIZATION =====
InitializeVisualizationSystem() {
    global gdiPlusInitialized, gdiPlusToken, canvasWidth, canvasHeight, canvasType

    ; Initialize GDI+
    if (!gdiPlusInitialized) {
        try {
            si := Buffer(24, 0)
            NumPut("UInt", 1, si, 0)
            result := DllCall("gdiplus\GdiplusStartup", "Ptr*", &gdiPlusToken, "Ptr", si, "Ptr", 0)
            if (result = 0) {
                gdiPlusInitialized := true
                UpdateStatus("Visualization system initialized")
            } else {
                UpdateStatus("Warning: GDI+ initialization failed (code: " . result . ")")
                gdiPlusInitialized := false
            }
        } catch Error as e {
            UpdateStatus("Error: GDI+ startup failed - " . e.Message)
            gdiPlusInitialized := false
        }
    }

    ; Detect initial canvas type
    DetectCanvasType()
}

; ===== MACRO VISUALIZATION CORE FUNCTIONS =====
DetectCanvasType() {
    global canvasWidth, canvasHeight, canvasAspectRatio, canvasType

    canvasAspectRatio := canvasWidth / canvasHeight

    ; Define aspect ratio ranges for wide/narrow detection
    narrowAspectRatio := 1330 / 1060  ; ≈ 1.25
    wideAspectRatio := 1884 / 1057    ; ≈ 1.78

    tolerance := 0.15  ; 15% tolerance for aspect ratio matching

    if (Abs(canvasAspectRatio - narrowAspectRatio) < tolerance) {
        canvasType := "narrow"
    } else if (Abs(canvasAspectRatio - wideAspectRatio) < tolerance) {
        canvasType := "wide"
    } else {
        canvasType := "custom"
    }

    return canvasType
}
