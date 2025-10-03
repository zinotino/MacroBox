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
