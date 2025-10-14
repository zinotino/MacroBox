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

        ; IMPROVED: Try corporate-safe fallback paths first (not just A_Temp)
        ; This ensures visualization works even if temp folder is restricted
        tempFile := SaveVisualizationPNG(bitmap, A_TickCount)

        ; Cleanup
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", bitmap)

        return tempFile  ; Returns actual working path (not empty string)

    } catch Error as e {
        return ""
    }
}

; ===== PNG SAVING WITH CORPORATE-SAFE FALLBACK PATHS =====
SaveVisualizationPNG(bitmap, uniqueId) {
    ; IMPROVED: Try fallback paths FIRST (corporate-safe approach)
    ; Returns actual working file path (not just boolean)

    global documentsDir, workDir

    clsid := Buffer(16)
    NumPut("UInt", 0x557CF406, clsid, 0)
    NumPut("UInt", 0x11D31A04, clsid, 4)
    NumPut("UInt", 0x0000739A, clsid, 8)
    NumPut("UInt", 0x2EF31EF8, clsid, 12)

    fileName := "macro_viz_" . uniqueId . ".png"

    ; CORPORATE-SAFE: Try data directories first (NOT src folder)
    fallbackPaths := [
        workDir . "\" . fileName,               ; Best: Data directory (Documents/MacroMaster/data)
        documentsDir . "\" . fileName,          ; Good: MacroMaster root (Documents/MacroMaster)
        A_MyDocuments . "\" . fileName,         ; Fallback: Documents root
        EnvGet("USERPROFILE") . "\" . fileName, ; Fallback: User profile root
        A_Temp . "\" . fileName                 ; Last resort: Temp folder
    ]

    for testPath in fallbackPaths {
        try {
            result := DllCall("gdiplus\GdipSaveImageToFile", "Ptr", bitmap, "WStr", testPath, "Ptr", clsid, "Ptr", 0)
            if (result = 0 && FileExist(testPath)) {
                ; SUCCESS: Return the working path
                return testPath
            }
        } catch {
            continue
        }
    }

    ; FAILURE: No paths worked
    return ""
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
CreateHBITMAPVisualization(macroEvents, buttonDims) {
    ; Memory-only visualization using HBITMAP with caching for performance
    global gdiPlusInitialized, degradationColors, hbitmapCache

    ; Early validation
    if (!gdiPlusInitialized) {
        ; Attempt to initialize if not already done
        InitializeVisualizationSystem()
        if (!gdiPlusInitialized) {
            return 0
        }
    }

    if (!macroEvents || macroEvents.Length = 0) {
        return 0
    }

    ; Handle both old (single size) and new (width/height object) format
    if (IsObject(buttonDims)) {
        buttonWidth := buttonDims.width
        buttonHeight := buttonDims.height
    } else {
        buttonWidth := buttonDims
        buttonHeight := buttonDims
    }

    ; PERFORMANCE: Generate cache key based on macro events content
    cacheKey := ""
    for event in macroEvents {
        if (event.type = "boundingBox") {
            cacheKey .= event.left . "," . event.top . "," . event.right . "," . event.bottom . "|"
        }
    }
    ; Include recordedMode in cache key if available
    recordedMode := macroEvents.HasOwnProp("recordedMode") ? macroEvents.recordedMode : "unknown"
    cacheKey .= buttonWidth . "x" . buttonHeight . "_" . recordedMode

    ; Check cache first
    if (hbitmapCache.Has(cacheKey)) {
        return hbitmapCache[cacheKey]
    }

    ; Extract box drawing events
    boxes := ExtractBoxEvents(macroEvents)
    if (boxes.Length = 0) {
        return 0
    }

    ; Create HBITMAP using GDI+
    bitmap := 0
    graphics := 0
    hbitmap := 0

    try {
        ; Validate dimensions
        if (buttonWidth <= 0 || buttonHeight <= 0 || buttonWidth > 4096 || buttonHeight > 4096) {
            return 0
        }

        ; Create GDI+ bitmap
        result := DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", buttonWidth, "Int", buttonHeight, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bitmap)
        if (result != 0 || !bitmap) {
            return 0
        }

        ; Create graphics context from bitmap
        result := DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bitmap, "Ptr*", &graphics)
        if (result != 0 || !graphics) {
            DllCall("gdiplus\GdipDisposeImage", "Ptr", bitmap)
            return 0
        }

        ; Black background for letterboxing contrast
        DllCall("gdiplus\GdipGraphicsClear", "Ptr", graphics, "UInt", 0xFF000000)

        ; Draw macro boxes optimized for button dimensions (pass entire macroEvents for mode detection)
        DrawMacroBoxesOnButton(graphics, buttonWidth, buttonHeight, boxes, macroEvents)

        ; Convert GDI+ bitmap to HBITMAP
        result := DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", bitmap, "Ptr*", &hbitmap, "UInt", 0x00000000)

        ; Clean up GDI+ objects
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", bitmap)

        if (result = 0 && hbitmap) {
            ; PERFORMANCE: Cache the HBITMAP for future use
            hbitmapCache[cacheKey] := hbitmap
            return hbitmap
        } else {
            return 0
        }

    } catch Error as e {
        ; Clean up on error
        if (graphics) {
            DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
        }
        if (bitmap) {
            DllCall("gdiplus\GdipDisposeImage", "Ptr", bitmap)
        }
        return 0
    }
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

; ===== JSON PROFILE COLORED BOX VISUALIZATION =====
CreateJsonVisualization(colorHex, buttonDims, mode, labelText := "") {
    ; Create colored box visualization with letterboxing for Narrow mode
    global gdiPlusInitialized

    if (!gdiPlusInitialized) {
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

    ; Convert hex color string to integer
    colorValue := Integer(colorHex)

    try {
        bitmap := 0
        DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", buttonWidth, "Int", buttonHeight, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bitmap)

        graphics := 0
        DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bitmap, "Ptr*", &graphics)

        ; Black background
        DllCall("gdiplus\GdipGraphicsClear", "Ptr", graphics, "UInt", 0xFF000000)

        ; Apply letterboxing for Narrow mode
        if (mode = "Narrow") {
            ; Narrow mode: 4:3 aspect ratio letterboxing
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

            ; Draw colored box in 4:3 content area
            brush := 0
            DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF000000 | colorValue, "Ptr*", &brush)
            DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", brush, "Float", offsetX, "Float", offsetY, "Float", contentWidth, "Float", contentHeight)
            DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
        } else {
            ; Wide mode: Stretch to fill entire button
            brush := 0
            DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF000000 | colorValue, "Ptr*", &brush)
            DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", brush, "Float", 0, "Float", 0, "Float", buttonWidth, "Float", buttonHeight)
            DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
        }

        ; Draw text label in center if provided
        if (labelText != "") {
            ; Create font family and font (match normal button labels)
            fontFamily := 0
            DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", "Segoe UI", "Ptr", 0, "Ptr*", &fontFamily)

            ; If Segoe UI fails, fallback to Arial
            if (!fontFamily) {
                DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", "Arial", "Ptr", 0, "Ptr*", &fontFamily)
            }

            font := 0
            fontSize := 12  ; Larger font for visibility
            DllCall("gdiplus\GdipCreateFont", "Ptr", fontFamily, "Float", fontSize, "Int", 1, "Int", 2, "Ptr*", &font)  ; Bold

            ; Create black brush for text
            textBrush := 0
            DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF000000, "Ptr*", &textBrush)

            ; Set text rendering quality
            DllCall("gdiplus\GdipSetTextRenderingHint", "Ptr", graphics, "Int", 4)  ; AntiAlias

            ; Create StringFormat for center alignment with word wrapping
            stringFormat := 0
            DllCall("gdiplus\GdipCreateStringFormat", "Int", 0, "Int", 0, "Ptr*", &stringFormat)
            DllCall("gdiplus\GdipSetStringFormatAlign", "Ptr", stringFormat, "Int", 1)  ; Center
            DllCall("gdiplus\GdipSetStringFormatLineAlign", "Ptr", stringFormat, "Int", 1)  ; Center vertically

            ; Define text area with padding to avoid letterboxing cutoff
            padding := buttonWidth * 0.1  ; 10% padding on each side
            textX := padding
            textY := padding
            textWidth := buttonWidth - (padding * 2)
            textHeight := buttonHeight - (padding * 2)

            ; Draw text in center with padding
            rect := Buffer(16, 0)
            NumPut("Float", textX, rect, 0)
            NumPut("Float", textY, rect, 4)
            NumPut("Float", textWidth, rect, 8)
            NumPut("Float", textHeight, rect, 12)

            DllCall("gdiplus\GdipDrawString", "Ptr", graphics, "WStr", labelText, "Int", -1, "Ptr", font, "Ptr", rect, "Ptr", stringFormat, "Ptr", textBrush)

            ; Cleanup text resources
            DllCall("gdiplus\GdipDeleteStringFormat", "Ptr", stringFormat)
            DllCall("gdiplus\GdipDeleteBrush", "Ptr", textBrush)
            DllCall("gdiplus\GdipDeleteFont", "Ptr", font)
            DllCall("gdiplus\GdipDeleteFontFamily", "Ptr", fontFamily)
        }

        ; IMPROVED: Use corporate-safe fallback paths (same as macro viz)
        tempFile := SaveVisualizationPNG(bitmap, A_TickCount)

        ; Cleanup
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", bitmap)

        return tempFile  ; Returns actual working path

    } catch Error as e {
        return ""
    }
}
