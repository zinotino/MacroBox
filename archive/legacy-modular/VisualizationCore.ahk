/*
==============================================================================
VISUALIZATION CORE MODULE - Core bitmap and GDI+ operations
==============================================================================
Handles GDI+ initialization, bitmap creation, and PNG saving
*/



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
        cachedHBITMAP := hbitmapCache[cacheKey]
        ; Validate cached HBITMAP before returning
        if (IsHBITMAPValid(cachedHBITMAP)) {
            ; DEBUG: Log cache hit
            FileAppend("=== CreateHBITMAPVisualization: CACHE HIT for key: " . cacheKey . " ===`n", "mono/visualization_test_log.txt")
            ; Add reference when returning cached HBITMAP
            AddHBITMAPReference(cachedHBITMAP)
            return cachedHBITMAP
        } else {
            ; Invalid cached HBITMAP - remove from cache
            FileAppend("=== CreateHBITMAPVisualization: INVALID CACHED HBITMAP for key: " . cacheKey . " - removing from cache ===`n", "mono/visualization_test_log.txt")
            hbitmapCache.Delete(cacheKey)
        }
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

        ; DEBUG: Log bitmap creation start
        FileAppend("=== CreateHBITMAPVisualization: Creating GDI+ bitmap " . buttonWidth . "x" . buttonHeight . " ===`n", "mono/visualization_test_log.txt")
        FileAppend("=== CreateHBITMAPVisualization: GDI+ initialized: " . gdiPlusInitialized . ", token: " . gdiPlusToken . " ===`n", "mono/visualization_test_log.txt")

        ; Create GDI+ bitmap (PixelFormat32bppPARGB = 0x26200A for premultiplied alpha)
        bitmap := 0
        result := DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", buttonWidth, "Int", buttonHeight, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bitmap)
        FileAppend("=== CreateHBITMAPVisualization: GdipCreateBitmapFromScan0 result=" . result . ", bitmap=" . bitmap . " ===`n", "mono/visualization_test_log.txt")
        if (result != 0 || !bitmap) {
            FileAppend("=== CreateHBITMAPVisualization: GdipCreateBitmapFromScan0 FAILED, result=" . result . " ===`n", "mono/visualization_test_log.txt")
            return 0
        }

        ; Create graphics context from bitmap
        graphics := 0
        result := DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bitmap, "Ptr*", &graphics)
        FileAppend("=== CreateHBITMAPVisualization: GdipGetImageGraphicsContext result=" . result . ", graphics=" . graphics . " ===`n", "mono/visualization_test_log.txt")
        if (result != 0 || !graphics) {
            FileAppend("=== CreateHBITMAPVisualization: GdipGetImageGraphicsContext FAILED, result=" . result . " ===`n", "mono/visualization_test_log.txt")
            DllCall("gdiplus\GdipDisposeImage", "Ptr", bitmap)
            return 0
        }

        ; Black background for letterboxing contrast
        DllCall("gdiplus\GdipGraphicsClear", "Ptr", graphics, "UInt", 0xFF000000)

        ; Draw macro boxes optimized for button dimensions (pass entire macroEvents for mode detection)
        FileAppend("=== CreateHBITMAPVisualization: About to call DrawMacroBoxesOnButton ===`n", "mono/visualization_test_log.txt")
        DrawMacroBoxesOnButton(graphics, buttonWidth, buttonHeight, boxes, macroEvents)
        FileAppend("=== CreateHBITMAPVisualization: DrawMacroBoxesOnButton completed ===`n", "mono/visualization_test_log.txt")

        ; CRITICAL FIX: Flush graphics to ensure all drawing is committed to bitmap
        FileAppend("=== CreateHBITMAPVisualization: Flushing graphics ===`n", "mono/visualization_test_log.txt")
        DllCall("gdiplus\GdipFlush", "Ptr", graphics, "Int", 1)  ; FlushIntentionSync

        ; Convert GDI+ bitmap to HBITMAP
        FileAppend("=== CreateHBITMAPVisualization: Converting to HBITMAP ===`n", "mono/visualization_test_log.txt")
        ; Use proper calling convention - background color for transparent pixels
        hbitmap := 0
        result := DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", bitmap, "Ptr*", &hbitmap, "UInt", 0xFF000000)
        FileAppend("=== CreateHBITMAPVisualization: GdipCreateHBITMAPFromBitmap result=" . result . ", hbitmap=" . hbitmap . " ===`n", "mono/visualization_test_log.txt")

        ; Clean up GDI+ objects
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", bitmap)

        if (result = 0 && hbitmap) {
            ; Validate HBITMAP immediately after creation
            hbitmapType := DllCall("GetObjectType", "Ptr", hbitmap)
            FileAppend("=== CreateHBITMAPVisualization: HBITMAP created, type=" . hbitmapType . " ===`n", "mono/visualization_test_log.txt")

            if (hbitmapType == 7) {  ; OBJ_BITMAP = 7
                ; PERFORMANCE: Cache the HBITMAP for future use and add reference
                hbitmapCache[cacheKey] := hbitmap
                AddHBITMAPReference(hbitmap)
                FileAppend("=== CreateHBITMAPVisualization: SUCCESS - HBITMAP cached and returned ===`n", "mono/visualization_test_log.txt")
                return hbitmap
            } else {
                ; Invalid HBITMAP type - clean up
                FileAppend("=== CreateHBITMAPVisualization: INVALID HBITMAP TYPE " . hbitmapType . " - cleaning up ===`n", "mono/visualization_test_log.txt")
                DllCall("DeleteObject", "Ptr", hbitmap)
                return 0
            }
        } else {
            FileAppend("=== CreateHBITMAPVisualization: GdipCreateHBITMAPFromBitmap FAILED, result=" . result . " ===`n", "mono/visualization_test_log.txt")
            return 0
        }

    } catch Error as e {
        ; Clean up on error
        FileAppend("=== CreateHBITMAPVisualization: EXCEPTION - " . e.Message . " ===`n", "mono/visualization_test_log.txt")
        if (graphics) {
            DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
        }
        if (bitmap) {
            DllCall("gdiplus\GdipDisposeImage", "Ptr", bitmap)
        }
        if (hbitmap) {
            DllCall("DeleteObject", "Ptr", hbitmap)
        }
        return 0
    }
}
; ===== HBITMAP REFERENCE COUNTING SYSTEM =====
; Global reference counting for HBITMAP handles to prevent premature deletion
global hbitmapRefCounts := Map()

; ===== HBITMAP REFERENCE MANAGEMENT =====
AddHBITMAPReference(hbitmap) {
    global hbitmapRefCounts

    if (!hbitmap || hbitmap = 0) {
        return
    }

    if (hbitmapRefCounts.Has(hbitmap)) {
        hbitmapRefCounts[hbitmap]++
        FileAppend("=== AddHBITMAPReference: INCREMENTED ref count for " . hbitmap . " to " . hbitmapRefCounts[hbitmap] . " ===`n", "mono/visualization_test_log.txt")
    } else {
        hbitmapRefCounts[hbitmap] := 1
        FileAppend("=== AddHBITMAPReference: NEW ref count for " . hbitmap . " set to 1 ===`n", "mono/visualization_test_log.txt")
    }
}

RemoveHBITMAPReference(hbitmap) {
    global hbitmapRefCounts

    if (!hbitmap || hbitmap = 0 || !hbitmapRefCounts.Has(hbitmap)) {
        FileAppend("=== RemoveHBITMAPReference: INVALID CALL - hbitmap=" . hbitmap . " not in refCounts ===`n", "mono/visualization_test_log.txt")
        return
    }

    hbitmapRefCounts[hbitmap]--
    FileAppend("=== RemoveHBITMAPReference: DECREMENTED ref count for " . hbitmap . " to " . hbitmapRefCounts[hbitmap] . " ===`n", "mono/visualization_test_log.txt")

    if (hbitmapRefCounts[hbitmap] <= 0) {
        ; No more references - safe to delete
        FileAppend("=== RemoveHBITMAPReference: NO MORE REFERENCES - deleting " . hbitmap . " ===`n", "mono/visualization_test_log.txt")
        hbitmapRefCounts.Delete(hbitmap)
        try {
            ; Validate before deleting
            result := DllCall("GetObject", "Ptr", hbitmap, "Int", 0, "Ptr", 0)
            if (result != 0) {
                DllCall("DeleteObject", "Ptr", hbitmap)
                FileAppend("=== RemoveHBITMAPReference: HBITMAP " . hbitmap . " successfully deleted ===`n", "mono/visualization_test_log.txt")
            } else {
                FileAppend("=== RemoveHBITMAPReference: HBITMAP " . hbitmap . " already invalid, skipped deletion ===`n", "mono/visualization_test_log.txt")
            }
        } catch {
            ; Handle already deleted
            FileAppend("=== RemoveHBITMAPReference: Exception during deletion of " . hbitmap . " ===`n", "mono/visualization_test_log.txt")
        }
    }
}

; ===== HBITMAP VALIDATION =====
IsHBITMAPValid(hbitmap) {
    if (!hbitmap || hbitmap = 0) {
        FileAppend("=== IsHBITMAPValid: INVALID - null or zero handle ===`n", "mono/visualization_test_log.txt")
        return false
    }

    try {
        result := DllCall("GetObject", "Ptr", hbitmap, "Int", 0, "Ptr", 0)
        valid := (result != 0)
        FileAppend("=== IsHBITMAPValid: HBITMAP " . hbitmap . " is " . (valid ? "VALID" : "INVALID") . " (GetObject result: " . result . ") ===`n", "mono/visualization_test_log.txt")
        return valid
    } catch {
        FileAppend("=== IsHBITMAPValid: EXCEPTION validating " . hbitmap . " ===`n", "mono/visualization_test_log.txt")
        return false
    }
}


; ===== HBITMAP CACHE CLEANUP =====
CleanupHBITMAPCache() {
    global hbitmapCache, buttonDisplayedHBITMAPs

    ; Delete all displayed HBITMAP handles
    for buttonName, hbitmap in buttonDisplayedHBITMAPs {
        if (hbitmap && hbitmap != 0) {
            try {
                result := DllCall("GetObject", "Ptr", hbitmap, "Int", 0, "Ptr", 0)
                if (result != 0) {
                    DllCall("DeleteObject", "Ptr", hbitmap)
                }
            } catch {
                ; Handle already deleted
            }
        }
    }

    ; Clear both maps
    buttonDisplayedHBITMAPs := Map()
    hbitmapCache := Map()

}

; ===== JSON PROFILE HBITMAP VISUALIZATION =====
CreateJsonHBITMAPVisualization(colorHex, buttonDims, mode, labelText := "") {
    ; Create colored box HBITMAP visualization (in-memory, no file I/O)
    global gdiPlusInitialized, hbitmapCache

    if (!gdiPlusInitialized) {
        InitializeVisualizationSystem()
        if (!gdiPlusInitialized) {
            return 0
        }
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

    ; Generate cache key for JSON visualizations
    cacheKey := "json_" . colorHex . "_" . mode . "_" . buttonWidth . "x" . buttonHeight . "_" . labelText

    ; Check cache first
    if (hbitmapCache.Has(cacheKey)) {
        return hbitmapCache[cacheKey]
    }

    bitmap := 0
    graphics := 0
    hbitmap := 0

    try {
        ; Validate dimensions
        if (buttonWidth <= 0 || buttonHeight <= 0 || buttonWidth > 4096 || buttonHeight > 4096) {
            return 0
        }

        ; Create GDI+ bitmap
        result := DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", buttonWidth, "Int", buttonHeight, "Int", 0, "Int", 0x22009, "Ptr", 0, "Ptr*", &bitmap)
        if (result != 0 || !bitmap) {
            return 0
        }

        ; Create graphics context
        result := DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bitmap, "Ptr*", &graphics)
        if (result != 0 || !graphics) {
            DllCall("gdiplus\GdipDisposeImage", "Ptr", bitmap)
            return 0
        }

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

        ; Flush graphics to commit all drawing
        DllCall("gdiplus\GdipFlush", "Ptr", graphics, "Int", 1)

        ; Convert GDI+ bitmap to HBITMAP
        hbitmap := 0
        result := DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", bitmap, "Ptr*", &hbitmap, "UInt", 0xFF000000)

        ; Clean up GDI+ objects
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", bitmap)

        if (result = 0 && hbitmap) {
            ; Cache the HBITMAP for future use and add reference
            hbitmapCache[cacheKey] := hbitmap
            AddHBITMAPReference(hbitmap)
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
        if (hbitmap) {
            DllCall("DeleteObject", "Ptr", hbitmap)
        }
        return 0
    }
}

