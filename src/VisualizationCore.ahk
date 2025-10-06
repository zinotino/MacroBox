/*
==============================================================================
VISUALIZATION CORE MODULE - Core bitmap and GDI+ operations
==============================================================================
Handles GDI+ initialization, bitmap creation, and PNG saving
*/

; ===== MAIN VISUALIZATION ENTRY POINT =====
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

        ; Black background for letterboxing contrast
        DllCall("gdiplus\GdipGraphicsClear", "Ptr", graphics, "UInt", 0xFF000000)

        ; Skip canvas type indicator - not needed for button view

        ; Draw macro boxes optimized for button dimensions (pass entire macroEvents for mode detection)
        DrawMacroBoxesOnButton(graphics, buttonWidth, buttonHeight, boxes, macroEvents)

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

; ===== PNG SAVING WITH FALLBACK PATHS =====
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

; ===== VISUALIZATION SYSTEM INITIALIZATION =====
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
            } else {
                UpdateStatus("⚠️ GDI+ initialization failed")
                gdiPlusInitialized := false
            }
        } catch Error as e {
            UpdateStatus("⚠️ GDI+ startup failed")
            gdiPlusInitialized := false
        }
    }

    ; Detect initial canvas type
    DetectCanvasType()
}

; ===== CANVAS TYPE DETECTION =====
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

; ===== HBITMAP IN-MEMORY VISUALIZATION (CORPORATE FALLBACK) =====

; ===== DRAW JSON BUTTON WITH LETTERBOX BARS =====
DrawJsonWithLetterboxBars(jsonColor, buttonDims, mode, displayText := "") {
    global gdiPlusInitialized, scaleFactor

    if (!gdiPlusInitialized) {
        return 0
    }

    ; Parse button dimensions
    if (IsObject(buttonDims)) {
        buttonWidth := buttonDims.width
        buttonHeight := buttonDims.height
    } else {
        buttonWidth := buttonDims
        buttonHeight := buttonDims
    }

    ; Create bitmap with alpha channel
    bitmap := 0
    DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", buttonWidth, "Int", buttonHeight, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bitmap)

    if (!bitmap) {
        return 0
    }

    ; Create graphics object
    graphics := 0
    DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bitmap, "Ptr*", &graphics)

    ; Set text rendering quality to match AHK controls
    DllCall("gdiplus\GdipSetTextRenderingHint", "Ptr", graphics, "Int", 4)  ; TextRenderingHintClearTypeGridFit

    ; Fill entire button with the JSON color
    ; Ensure full alpha channel is set
    colorValue := Integer(jsonColor)
    if (colorValue < 0xFF000000) {
        colorValue := colorValue | 0xFF000000  ; Add full opacity
    }
    colorBrush := 0
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", colorValue, "Ptr*", &colorBrush)
    DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", colorBrush, "Float", 0, "Float", 0, "Float", buttonWidth, "Float", buttonHeight)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", colorBrush)

    ; Draw letterbox bars only in Narrow mode
    if (mode = "Narrow") {
        ; Calculate 4:3 letterbox content area
        narrowAspect := 4.0 / 3.0
        buttonAspect := buttonWidth / buttonHeight

        ; Draw ONLY the black letterbox bars
        blackBrush := 0
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF000000, "Ptr*", &blackBrush)

        if (buttonAspect > narrowAspect) {
            ; Button is wider than 4:3 - draw left/right bars
            contentHeight := buttonHeight
            contentWidth := contentHeight * narrowAspect
            offsetX := (buttonWidth - contentWidth) / 2

            ; Left bar
            DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", blackBrush, "Float", 0, "Float", 0, "Float", offsetX, "Float", buttonHeight)
            ; Right bar
            DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", blackBrush, "Float", offsetX + contentWidth, "Float", 0, "Float", offsetX, "Float", buttonHeight)
        } else {
            ; Button is taller than 4:3 - draw top/bottom bars
            contentWidth := buttonWidth
            contentHeight := contentWidth / narrowAspect
            offsetY := (buttonHeight - contentHeight) / 2

            ; Top bar
            DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", blackBrush, "Float", 0, "Float", 0, "Float", buttonWidth, "Float", offsetY)
            ; Bottom bar
            DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", blackBrush, "Float", 0, "Float", offsetY + contentHeight, "Float", buttonWidth, "Float", offsetY)
        }

        DllCall("gdiplus\GdipDeleteBrush", "Ptr", blackBrush)
    }

    ; Draw text on top
    if (displayText != "") {
        ; Create font - match AHK button font exactly
        fontFamily := 0
        DllCall("gdiplus\GdipCreateFontFamilyFromName", "Str", "Segoe UI", "Ptr", 0, "Ptr*", &fontFamily)

        font := 0
        ; FontStyle: 1 = Bold, Unit: 0 = World
        ; Larger size for better visibility on buttons
        fontSize := Round(12 * scaleFactor)
        DllCall("gdiplus\GdipCreateFont", "Ptr", fontFamily, "Float", fontSize, "Int", 1, "Int", 0, "Ptr*", &font)

        ; Create text brush
        textBrush := 0
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF000000, "Ptr*", &textBrush)

        ; Create string format for centered text
        stringFormat := 0
        DllCall("gdiplus\GdipStringFormatGetGenericDefault", "Ptr*", &stringFormat)
        DllCall("gdiplus\GdipSetStringFormatAlign", "Ptr", stringFormat, "Int", 1)
        DllCall("gdiplus\GdipSetStringFormatLineAlign", "Ptr", stringFormat, "Int", 1)

        ; Draw text
        layoutRect := Buffer(16, 0)
        NumPut("Float", 0, layoutRect, 0)
        NumPut("Float", 0, layoutRect, 4)
        NumPut("Float", buttonWidth, layoutRect, 8)
        NumPut("Float", buttonHeight, layoutRect, 12)

        DllCall("gdiplus\GdipDrawString", "Ptr", graphics, "Str", displayText, "Int", -1, "Ptr", font, "Ptr", layoutRect, "Ptr", stringFormat, "Ptr", textBrush)

        ; Cleanup
        DllCall("gdiplus\GdipDeleteStringFormat", "Ptr", stringFormat)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", textBrush)
        DllCall("gdiplus\GdipDeleteFont", "Ptr", font)
        DllCall("gdiplus\GdipDeleteFontFamily", "Ptr", fontFamily)
    }

    ; Convert to HBITMAP using the JSON color as background
    hbitmap := 0
    DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", bitmap, "Ptr*", &hbitmap, "UInt", colorValue)

    ; Cleanup
    DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
    DllCall("gdiplus\GdipDisposeImage", "Ptr", bitmap)

    return hbitmap
}

; ===== HBITMAP CACHE CLEANUP =====
CleanupHBITMAPCache() {
    global hbitmapCache

    ; Delete all HBITMAP handles
    for cacheKey, hbitmap in hbitmapCache {
        if (hbitmap) {
            DllCall("DeleteObject", "Ptr", hbitmap)
        }
    }

    ; Clear the cache Map
    hbitmapCache := Map()
}
