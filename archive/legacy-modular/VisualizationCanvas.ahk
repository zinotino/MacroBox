/*
==============================================================================
VISUALIZATION CANVAS MODULE - Canvas detection and scaling logic
==============================================================================
Handles canvas selection, scaling calculations, and box rendering
*/

; MANUAL CANVAS SCALING SYSTEM:
; Uses only manually calibrated canvas configurations for consistent percentage-based scaling
; - Wide mode: Uses wide canvas calibration, stretches to fill button area
; - Narrow mode: Uses narrow canvas calibration, letterboxes to 4:3 aspect ratio
; - No automatic detection or fallbacks - requires manual canvas calibration
DrawMacroBoxesOnButton(graphics, buttonWidth, buttonHeight, boxes, macroEventsArray := "") {
    global degradationColors, annotationMode, userCanvasLeft, userCanvasTop, userCanvasRight, userCanvasBottom, isCanvasCalibrated
    global wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom, isWideCanvasCalibrated
    global narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom, isNarrowCanvasCalibrated
    global buttonLetterboxingStates

    if (boxes.Length = 0) {
        return
    }

    ; Get stored recording mode from macro events (takes priority)
    storedMode := ""
    if (macroEventsArray != "" && IsObject(macroEventsArray)) {
        ; Handle both Map and Object types
        if (Type(macroEventsArray) = "Map") {
            storedMode := macroEventsArray.Has("recordedMode") ? macroEventsArray["recordedMode"] : ""
        } else if (macroEventsArray.HasOwnProp("recordedMode")) {
            storedMode := macroEventsArray.recordedMode
        }
    }

    ; Use stored mode if available, otherwise use current annotation mode
    effectiveMode := storedMode != "" ? storedMode : annotationMode

    ; MANUAL CANVAS SELECTION: Only use manually calibrated canvases
    if (effectiveMode = "Wide" && isWideCanvasCalibrated) {
        ; Wide mode - use manually calibrated wide canvas
        canvasLeft := wideCanvasLeft
        canvasTop := wideCanvasTop
        canvasRight := wideCanvasRight
        canvasBottom := wideCanvasBottom
        canvasW := canvasRight - canvasLeft
        canvasH := canvasBottom - canvasTop

        ; Wide mode: Stretch to fill entire button area (percentage-based scaling)
        darkGrayBrush := 0
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF2A2A2A, "Ptr*", &darkGrayBrush)
        DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", darkGrayBrush, "Float", 0, "Float", 0, "Float", buttonWidth, "Float", buttonHeight)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", darkGrayBrush)

        scaleX := buttonWidth / canvasW
        scaleY := buttonHeight / canvasH
        offsetX := 0
        offsetY := 0

    } else if (effectiveMode = "Narrow" && isNarrowCanvasCalibrated) {
        ; Narrow mode - use manually calibrated narrow canvas
        canvasLeft := narrowCanvasLeft
        canvasTop := narrowCanvasTop
        canvasRight := narrowCanvasRight
        canvasBottom := narrowCanvasBottom
        canvasW := canvasRight - canvasLeft
        canvasH := canvasBottom - canvasTop

        ; Narrow mode: Letterbox to preserve 4:3 aspect ratio
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

        ; Scale canvas to fill the entire 4:3 content area (percentage-based)
        scaleX := contentWidth / canvasW
        scaleY := contentHeight / canvasH

    } else if (isCanvasCalibrated) {
        ; Fallback to user canvas if available (for legacy compatibility)
        canvasLeft := userCanvasLeft
        canvasTop := userCanvasTop
        canvasRight := userCanvasRight
        canvasBottom := userCanvasBottom
        canvasW := canvasRight - canvasLeft
        canvasH := canvasBottom - canvasTop

        ; User canvas: Stretch to fill entire button area
        darkGrayBrush := 0
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF2A2A2A, "Ptr*", &darkGrayBrush)
        DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", darkGrayBrush, "Float", 0, "Float", 0, "Float", buttonWidth, "Float", buttonHeight)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", darkGrayBrush)

        scaleX := buttonWidth / canvasW
        scaleY := buttonHeight / canvasH
        offsetX := 0
        offsetY := 0

    } else {
        ; No manual calibration available - skip drawing
        return
    }

    ; Validate canvas dimensions
    if (canvasW <= 0 || canvasH <= 0) {
        return
    }

    ; Draw boxes with consistent percentage-based scaling
    for box in boxes {
        ; Map box coordinates from canvas to button space using percentage scaling
        rawX1 := ((box.left - canvasLeft) * scaleX) + offsetX
        rawY1 := ((box.top - canvasTop) * scaleY) + offsetY
        rawX2 := ((box.right - canvasLeft) * scaleX) + offsetX
        rawY2 := ((box.bottom - canvasTop) * scaleY) + offsetY

        ; Calculate dimensions with floating-point precision
        rawW := rawX2 - rawX1
        rawH := rawY2 - rawY1

        ; INTELLIGENT MINIMUM SIZE: Preserve aspect ratio while ensuring visibility
        minSize := 2.5

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
            ; Use precise floating-point coordinates
            x1 := rawX1
            y1 := rawY1
            x2 := rawX2
            y2 := rawY2
            w := rawW
            h := rawH
        }

        ; BOUNDS VALIDATION: Ensure coordinates are within button area
        x1 := Max(0, Min(x1, buttonWidth))
        y1 := Max(0, Min(y1, buttonHeight))
        x2 := Max(0, Min(x2, buttonWidth))
        y2 := Max(0, Min(y2, buttonHeight))
        w := x2 - x1
        h := y2 - y1

        ; Skip boxes that are too small to see
        if (w < 1.5 || h < 1.5) {
            continue
        }

        ; Ensure minimum visible size
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

        ; Draw with sub-pixel precision
        fillColor := 0xFF000000 | color

        ; Enable high-quality rendering
        DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", graphics, "Int", 4)
        DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", graphics, "Int", 4)

        ; Draw the box
        brush := 0
        result := DllCall("gdiplus\GdipCreateSolidFill", "UInt", fillColor, "Ptr*", &brush)
        if (result = 0) {
            DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", brush, "Float", x1, "Float", y1, "Float", w, "Float", h)
            DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
        }

        ; Reset rendering mode
        DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", graphics, "Int", 0)
        DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", graphics, "Int", 0)
    }
}
