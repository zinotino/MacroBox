/*
==============================================================================
VISUALIZATION CANVAS MODULE - Canvas detection and scaling logic
==============================================================================
Handles canvas selection, scaling calculations, and box rendering
*/

; DUAL CANVAS CONFIGURATION SYSTEM:
; Analyzes recorded macro aspect ratio to choose appropriate canvas configuration
; - Wide recorded macros (aspect ratio > 1.5) → Use WIDE canvas config → STRETCH to fill thumbnail (no black bars)
; - Narrow recorded macros (aspect ratio <= 1.5) → Use NARROW canvas config → Black bars based on configured narrow aspect ratio
; - Canvas choice based on RECORDED CONTENT characteristics, not button size
; - Clean visualization without indicators for maximum aesthetic appeal
DrawMacroBoxesOnButton(graphics, buttonWidth, buttonHeight, boxes, macroEventsArray := "") {
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

    ; Check if macro has a stored recording mode (takes priority)
    storedMode := ""
    if (macroEventsArray != "" && IsObject(macroEventsArray) && macroEventsArray.HasOwnProp("recordedMode")) {
        storedMode := macroEventsArray.recordedMode
    }

    ; RESPECT ANNOTATION MODE: Use stored mode if available, otherwise current mode
    effectiveMode := storedMode != "" ? storedMode : annotationMode

    if (effectiveMode = "Wide") {
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
    } else if (effectiveMode = "Narrow") {
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

    ; Store diagnostic info globally for testing
    debugInfo := "Canvas: " . effectiveMode
    if (useWideCanvas) {
        debugInfo .= " (Wide)"
    } else if (useNarrowCanvas) {
        debugInfo .= " (Narrow)"
    } else {
        debugInfo .= " (Legacy)"
    }
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

    ; VISUAL DIFFERENTIATION: Wide = stretch to fill, Narrow = letterboxing
    ; Background is already set by caller - we draw a colored overlay for the content area

    ; Apply different scaling strategies based on canvas type
    if (useWideCanvas) {
        ; WIDE CANVAS: Stretch to fill entire button (non-uniform scaling)
        ; Fill entire area with dark gray background (no letterboxing)
        darkGrayBrush := 0
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF2A2A2A, "Ptr*", &darkGrayBrush)
        DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", darkGrayBrush, "Float", 0, "Float", 0, "Float", buttonWidth, "Float", buttonHeight)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", darkGrayBrush)

        scaleX := buttonWidth / canvasW
        scaleY := buttonHeight / canvasH
        offsetX := 0
        offsetY := 0
    } else if (useNarrowCanvas) {
        ; NARROW CANVAS: Letterboxing to preserve 4:3 aspect ratio
        ; Calculate 4:3 content area centered in button
        narrowAspect := 4.0 / 3.0
        buttonAspect := buttonWidth / buttonHeight

        if (buttonAspect > narrowAspect) {
            ; Button is wider than 4:3 - add horizontal letterboxing
            contentHeight := buttonHeight
            contentWidth := contentHeight * narrowAspect
        } else {
            ; Button is taller than 4:3 - add vertical letterboxing
            contentWidth := buttonWidth
            contentHeight := contentWidth / narrowAspect
        }

        ; Center the 4:3 content area
        offsetX := (buttonWidth - contentWidth) / 2
        offsetY := (buttonHeight - contentHeight) / 2

        ; Fill 4:3 content area with dark gray, leaving black letterbox bars
        darkGrayBrush := 0
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF2A2A2A, "Ptr*", &darkGrayBrush)
        DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", darkGrayBrush, "Float", offsetX, "Float", offsetY, "Float", contentWidth, "Float", contentHeight)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", darkGrayBrush)

        ; STRETCH canvas to fill the entire 4:3 content area (like wide mode)
        ; This ensures boxes in corners reach the edges of the letterboxed area
        scaleX := contentWidth / canvasW
        scaleY := contentHeight / canvasH
        ; No need to adjust offset - canvas fills the entire 4:3 area
    } else {
        ; LEGACY/FALLBACK: Stretch to fill
        darkGrayBrush := 0
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF2A2A2A, "Ptr*", &darkGrayBrush)
        DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", darkGrayBrush, "Float", 0, "Float", 0, "Float", buttonWidth, "Float", buttonHeight)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", darkGrayBrush)

        scaleX := buttonWidth / canvasW
        scaleY := buttonHeight / canvasH
        offsetX := 0
        offsetY := 0
    }

    ; Draw the boxes with enhanced precision and accuracy
    for box in boxes {
        ; Map box coordinates from canvas to button space
        rawX1 := ((box.left - canvasLeft) * scaleX) + offsetX
        rawY1 := ((box.top - canvasTop) * scaleY) + offsetY
        rawX2 := ((box.right - canvasLeft) * scaleX) + offsetX
        rawY2 := ((box.bottom - canvasTop) * scaleY) + offsetY

        ; Calculate raw dimensions with floating-point precision
        rawW := rawX2 - rawX1
        rawH := rawY2 - rawY1

        ; INTELLIGENT MINIMUM SIZE: Preserve aspect ratio while ensuring visibility
        minSize := 2.5  ; Slightly smaller minimum for better area utilization

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

        ; Skip boxes that are completely outside the thumbnail area or too small to see
        if (w < 1.5 || h < 1.5) {
            continue
        }

        ; Ensure minimum visible size for better display while allowing smaller valid boxes
        if (w < 2) {
            w := 2
            x2 := x1 + w
        }
        if (h < 2) {
            h := 2
            y2 := y1 + h
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
