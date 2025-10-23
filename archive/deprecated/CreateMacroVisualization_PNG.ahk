; ===== LEGACY PNG-BASED VISUALIZATION =====
; Archived from VisualizationCore.ahk (2025-10-17)
; Superseded by CreateHBITMAPVisualization() (in-memory, faster, corporate-friendly)

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
