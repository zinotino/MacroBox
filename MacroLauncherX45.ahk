#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"
Persistent

/*
===============================================================================
MACROMASTER OFFLINE - Comprehensive macro recording and playback system
===============================================================================
*/

/*
CSV STRUCTURE: data/master_stats.csv
timestamp,session_id,username,execution_type,button_key,layer,execution_time_ms,bbox_count,degradation_assignments,severity_level,canvas_mode,session_active_time_ms,break_mode_active
*/

; ===== CORE VARIABLES & CONFIGURATION =====
global mainGui := 0
global statusBar := 0
global layerIndicator := 0
global modeToggleBtn := 0
global recording := false
global playback := false
global awaitingAssignment := false
global currentMacro := ""
global macroEvents := Map()
global buttonGrid := Map()
global buttonLabels := Map()
global buttonPictures := Map()
global buttonCustomLabels := Map()
global mouseHook := 0
global keyboardHook := 0
global darkMode := true

; ===== FILE SYSTEM PATHS =====
global workDir := A_ScriptDir "\data"
global configFile := A_ScriptDir "\config.ini"
global thumbnailDir := A_ScriptDir "\thumbnails"

; ===== THUMBNAIL SUPPORT =====
global buttonThumbnails := Map()

; ===== MACRO VISUALIZATION SYSTEM =====
global gdiPlusInitialized := false
global gdiPlusToken := 0
global canvasWidth := 1920
global canvasHeight := 1080
global canvasType := "wide"  ; "wide", "narrow", or "custom"
global canvasAspectRatio := 1.78

; ===== DUAL CANVAS SYSTEM FOR ASPECT RATIOS =====
; Wide mode: 16:9 aspect ratio (1920x1080 reference)
global wideCanvasLeft := 0
global wideCanvasTop := 0  
global wideCanvasRight := 1920
global wideCanvasBottom := 1080

; Narrow mode: 4:3 aspect ratio (1440x1080 centered in 1920x1080)
global narrowCanvasLeft := 240
global narrowCanvasTop := 0
global narrowCanvasRight := 1680
global narrowCanvasBottom := 1080

; Legacy canvas (for backwards compatibility)
global userCanvasLeft := 0
global userCanvasTop := 0  
global userCanvasRight := 1920
global userCanvasBottom := 1080

global isCanvasCalibrated := false
global isWideCanvasCalibrated := false
global isNarrowCanvasCalibrated := false

; ===== ENHANCED STATS SYSTEM =====
global macroExecutionLog := []
global macroStats := Map()
global severityBreakdown := Map()
global executionTimeLog := []
global totalExecutionTime := 0
global persistentStatsFile := A_ScriptDir . "\persistent_stats.json"

; ===== DEGRADATION TRACKING =====
global pendingBoxForTagging := ""

; ===== TIME TRACKING & BREAK MODE =====
global applicationStartTime := A_TickCount
global totalActiveTime := 0
global lastActiveTime := A_TickCount
global breakMode := false
global breakStartTime := 0

; ===== CSV STATS SYSTEM =====
global sessionId := ""
global masterStatsCSV := A_ScriptDir . "\data\master_stats.csv"
global currentUsername := EnvGet("USERNAME")
global sessionStartTime := 0
global breakModeActive := false

; ===== UI CONFIGURATION =====
global windowWidth := 1200
global windowHeight := 800
global scaleFactor := 1.0
global minWindowWidth := 900
global minWindowHeight := 600

; ===== LAYER SYSTEM =====
global currentLayer := 1
global totalLayers := 5
global layerNames := ["Base", "Advanced", "Tools", "Custom", "AUTO", "JSON", "Thumbnails", "Settings"]
global layerBorderColors := ["0x2D2D30", "0x505050", "0x6D6D70", "0x8D8D90", "0xA5A5A5"]

; ===== TIMING CONFIGURATION =====
global boxDrawDelay := 50
global mouseClickDelay := 60
global mouseDragDelay := 65
global mouseReleaseDelay := 65
global betweenBoxDelay := 150
global keyPressDelay := 12
global focusDelay := 80

; ===== RECORDING SETTINGS =====
global mouseMoveThreshold := 3
global mouseMoveInterval := 12
global boxDragMinDistance := 5

; ===== BUTTON LAYOUT =====
global buttonNames := ["Num7", "Num8", "Num9", "Num4", "Num5", "Num6", "Num1", "Num2", "Num3", "Num0", "NumDot", "NumMult"]
global gridOutline := 0

; ===== JSON ANNOTATION SYSTEM =====
global jsonAnnotations := Map()
global annotationMode := "Wide"

; ===== DEGRADATION TYPES WITH COLORS =====
global degradationTypes := Map(
    1, "smudge", 2, "glare", 3, "splashes", 4, "partial_blockage", 5, "full_blockage",
    6, "light_flare", 7, "rain", 8, "haze", 9, "snow"
)

global degradationColors := Map(
    1, 0xFF4500,  ; smudge - orangered (more vibrant orange)
    2, 0xFFD700,  ; glare - gold (brighter yellow)  
    3, 0x8A2BE2,  ; splashes - blueviolet (more distinct purple)
    4, 0x00FF32,  ; partial_blockage - limegreen (brighter green)
    5, 0x8B0000,  ; full_blockage - darkred (unchanged - good contrast)
    6, 0xFF1493,  ; light_flare - deeppink (more distinct from red)
    7, 0xB8860B,  ; rain - darkgoldenrod (more distinct dirty yellow)
    8, 0x556B2F,  ; haze - darkolivegreen (more distinct dirty green)
    9, 0x00FF7F   ; snow - springgreen (more distinct neon green)
)

global severityLevels := ["high", "medium", "low"]

; ===== DEGRADATION TRACKING =====
global pendingBoxForTagging := ""

; ===== TIME TRACKING & BREAK MODE =====
global applicationStartTime := A_TickCount
global totalActiveTime := 0
global lastActiveTime := A_TickCount
global breakMode := false
global breakStartTime := 0

; ===== UI CONFIGURATION =====
global windowWidth := 1200
global windowHeight := 800
global scaleFactor := 1.0
global minWindowWidth := 900
global minWindowHeight := 600

; ===== LAYER SYSTEM =====
global currentLayer := 1
global totalLayers := 5
global layerNames := ["Base", "Advanced", "Tools", "Custom", "AUTO", "JSON", "Thumbnails", "Settings"]
global layerBorderColors := ["0x2D2D30", "0x505050", "0x6D6D70", "0x8D8D90", "0xA5A5A5"]

; ===== TIMING CONFIGURATION =====
global boxDrawDelay := 50
global mouseClickDelay := 60
global mouseDragDelay := 65
global mouseReleaseDelay := 65
global betweenBoxDelay := 150
global keyPressDelay := 12
global focusDelay := 80

; ===== RECORDING SETTINGS =====
global mouseMoveThreshold := 3
global mouseMoveInterval := 12
global boxDragMinDistance := 5

; ===== BUTTON LAYOUT =====
global buttonNames := ["Num7", "Num8", "Num9", "Num4", "Num5", "Num6", "Num1", "Num2", "Num3", "Num0", "NumDot", "NumMult"]
global gridOutline := 0

; ===== JSON ANNOTATION SYSTEM =====
global jsonAnnotations := Map()
global annotationMode := "Wide"

; ===== DEGRADATION TYPES WITH COLORS =====
global degradationTypes := Map(
    1, "smudge", 2, "glare", 3, "splashes", 4, "partial_blockage", 5, "full_blockage",
    6, "light_flare", 7, "rain", 8, "haze", 9, "snow"
)

global degradationColors := Map(
    1, 0xFF4500,  ; smudge - orangered (more vibrant orange)
    2, 0xFFD700,  ; glare - gold (brighter yellow)  
    3, 0x8A2BE2,  ; splashes - blueviolet (more distinct purple)
    4, 0x00FF32,  ; partial_blockage - limegreen (brighter green)
    5, 0x8B0000,  ; full_blockage - darkred (unchanged - good contrast)
    6, 0xFF1493,  ; light_flare - deeppink (more distinct from red)
    7, 0xB8860B,  ; rain - darkgoldenrod (more distinct dirty yellow)
    8, 0x556B2F,  ; haze - darkolivegreen (more distinct dirty green)
    9, 0x00FF7F   ; snow - springgreen (more distinct neon green)
)

global severityLevels := ["high", "medium", "low"]

; ===== MAIN INITIALIZATION =====
Main() {
    try {
        ; Initialize core systems
        InitializeDirectories()
        InitializeVariables()
        InitializeCSVFile()
        InitializeStatsSystem()
        InitializeJsonAnnotations()
        InitializeVisualizationSystem()
        
        ; Setup UI and interactions
        InitializeGui()
        SetupHotkeys()
        
        ; Load configuration (after GUI is created so mode toggle button can be updated)
        LoadConfig()
        
        ; Check for canvas configuration and prompt new users
        CheckCanvasConfiguration()
        
        ; Load saved macros
        loadedMacros := LoadMacroState()
        
        ; Status update
        if (loadedMacros > 0) {
            UpdateStatus("📄 Loaded " . loadedMacros . " macros")
        } else {
            UpdateStatus("📄 No saved macros")
        }
        
        ; Refresh all button appearances after loading config
        RefreshAllButtonAppearances()
        
        ; Setup time tracking and auto-save
        SetTimer(UpdateActiveTime, 30000)
        SetTimer(AutoSave, 60000)
        
        ; Setup cleanup
        OnExit((*) => CleanupAndExit())
        
        ; Show welcome message
        UpdateStatus("🚀 Ready - Currently in " . (annotationMode = "Wide" ? "🔦 WIDE MODE" : "📱 NARROW MODE") . " - F9 to record")
        SetTimer(ShowWelcomeMessage, -2000)
        
    } catch Error as e {
        MsgBox("Initialization failed: " e.Message, "Startup Error", "Icon!")
        ExitApp
    }
}

CheckCanvasConfiguration() {
    global isWideCanvasCalibrated, isNarrowCanvasCalibrated
    
    ; Check if neither canvas is configured
    if (!isWideCanvasCalibrated && !isNarrowCanvasCalibrated) {
        result := MsgBox("🖼️ THUMBNAIL CANVAS CONFIGURATION`n`n" .
                        "Would you like to configure your canvas areas for picture-perfect thumbnails?`n`n" .
                        "⚡ RECOMMENDED: Configure both Wide and Narrow canvas areas`n" .
                        "• Wide canvas: For landscape/widescreen recordings`n" .
                        "• Narrow canvas: For portrait/square recordings`n`n" .
                        "⚠️ WITHOUT configuration: Thumbnails will auto-detect but may not be pixel-perfect`n`n" .
                        "Configure now?", "Thumbnail Integration Setup", "YesNo Icon?")
        
        if (result = "Yes") {
            ; Open settings directly to canvas configuration
            ShowSettings()
            UpdateStatus("🖼️ Configure both Wide and Narrow canvas areas in Settings → Configuration tab")
        } else {
            ; User declined, show what they'll miss
            UpdateStatus("⚠️ Thumbnail auto-detection active - Configure canvas areas in Settings for pixel-perfect thumbnails")
        }
    }
}

; ===== VARIABLE INITIALIZATION =====
InitializeVariables() {
    global pendingBoxForTagging
    
    ; Initialize button custom labels
    for buttonName in buttonNames {
        buttonCustomLabels[buttonName] := buttonName
    }
    
    ; Initialize severity breakdown
    for severity in severityLevels {
        severityBreakdown[severity] := {count: 0, percentage: 0}
    }
    
    ; Initialize tracking system
    pendingBoxForTagging := ""
    
    ; Initialize CSV session system
    now := FormatTime(A_Now, "yyyyMMdd_HHmmss")
    sessionId := "sess_" . now
    sessionStartTime := A_TickCount
    breakModeActive := false
}

InitializeDirectories() {
    global workDir, thumbnailDir
    
    if !DirExist(workDir)
        DirCreate(workDir)
    
    if !DirExist(thumbnailDir)
        DirCreate(thumbnailDir)
}

; ===== MACRO VISUALIZATION SYSTEM INITIALIZATION =====
InitializeVisualizationSystem() {
    global gdiPlusInitialized, gdiPlusToken, canvasWidth, canvasHeight, canvasType
    
    ; Initialize GDI+
    if (!gdiPlusInitialized) {
        si := Buffer(24, 0)
        NumPut("UInt", 1, si, 0)
        result := DllCall("gdiplus\GdiplusStartup", "Ptr*", &gdiPlusToken, "Ptr", si, "Ptr", 0)
        if (result = 0) {
            gdiPlusInitialized := true
            UpdateStatus("🎨 Visualization system initialized")
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
    
    ; Look for boundingBox events and keypress assignments in MacroLauncherX44 format
    for eventIndex, event in macroEvents {
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
            }
        }
    }
    
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
    
    ; Determine which canvas configuration to use based on recorded macro characteristics
    ; Wide macros (aspect ratio > 1.5) use wide canvas, narrow macros use narrow canvas
    ; Always fall back to legacy if no canvas is configured
    useWideCanvas := (recordedAspectRatio > 1.5) && isWideCanvasCalibrated
    useNarrowCanvas := (recordedAspectRatio <= 1.5) && isNarrowCanvasCalibrated
    useLegacyCanvas := !useWideCanvas && !useNarrowCanvas
    
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
    
    ; INTELLIGENT SCALING: Wide macros stretch to fit, narrow macros get proportional black bars
    
    ; Dark grey background fills entire thumbnail
    DllCall("gdiplus\GdipGraphicsClear", "Ptr", graphics, "UInt", 0xFF606060)
    
    if (useWideCanvas) {
        ; WIDE MACRO: Stretch to fill entire thumbnail area (no black bars)
        scale := Min(buttonWidth / canvasW, buttonHeight / canvasH)
        scaledCanvasW := buttonWidth
        scaledCanvasH := buttonHeight
        offsetX := 0
        offsetY := 0
        ; Use stretch scaling for wide macros to fill thumbnail
        scaleX := buttonWidth / canvasW
        scaleY := buttonHeight / canvasH
        
    } else if (useNarrowCanvas) {
        ; NARROW MACRO: Use the configured narrow canvas dimensions to create proper aspect ratio visualization
        ; Get the CONFIGURED narrow canvas aspect ratio (not the recorded macro aspect ratio)
        configuredNarrowCanvasW := narrowCanvasRight - narrowCanvasLeft
        configuredNarrowCanvasH := narrowCanvasBottom - narrowCanvasTop
        configuredNarrowAspectRatio := configuredNarrowCanvasW / configuredNarrowCanvasH
        
        ; Calculate button aspect ratio
        buttonAspectRatio := buttonWidth / buttonHeight
        
        ; Scale the configured narrow canvas aspect ratio to fit in the thumbnail
        if (configuredNarrowAspectRatio > buttonAspectRatio) {
            ; Configured canvas is wider than button - fit to button width, add top/bottom black bars
            visualCanvasW := buttonWidth
            visualCanvasH := buttonWidth / configuredNarrowAspectRatio
            visualOffsetX := 0
            visualOffsetY := (buttonHeight - visualCanvasH) / 2
            
            ; Add horizontal black bars (top/bottom)
            if (visualOffsetY > 0) {
                blackBrush := 0
                DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF000000, "Ptr*", &blackBrush)
                DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", blackBrush, "Float", 0, "Float", 0, "Float", buttonWidth, "Float", visualOffsetY)
                DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", blackBrush, "Float", 0, "Float", visualOffsetY + visualCanvasH, "Float", buttonWidth, "Float", visualOffsetY)
                DllCall("gdiplus\GdipDeleteBrush", "Ptr", blackBrush)
            }
        } else {
            ; Configured canvas is taller than button - fit to button height, add left/right black bars
            visualCanvasW := buttonHeight * configuredNarrowAspectRatio
            visualCanvasH := buttonHeight
            visualOffsetX := (buttonWidth - visualCanvasW) / 2
            visualOffsetY := 0
            
            ; Add vertical black bars (left/right)
            if (visualOffsetX > 0) {
                blackBrush := 0
                DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF000000, "Ptr*", &blackBrush)
                DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", blackBrush, "Float", 0, "Float", 0, "Float", visualOffsetX, "Float", buttonHeight)
                DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", blackBrush, "Float", visualOffsetX + visualCanvasW, "Float", 0, "Float", visualOffsetX, "Float", buttonHeight)
                DllCall("gdiplus\GdipDeleteBrush", "Ptr", blackBrush)
            }
        }
        
        ; Now scale the actual recorded canvas to fit within the visual canvas area (grey area)
        scaleX := visualCanvasW / canvasW
        scaleY := visualCanvasH / canvasH
        offsetX := visualOffsetX
        offsetY := visualOffsetY
        
    } else {
        ; LEGACY/FALLBACK: Proportional scaling
        scale := Min(buttonWidth / canvasW, buttonHeight / canvasH)
        scaledCanvasW := canvasW * scale
        scaledCanvasH := canvasH * scale
        offsetX := (buttonWidth - scaledCanvasW) / 2
        offsetY := (buttonHeight - scaledCanvasH) / 2
        scaleX := scale
        scaleY := scale
    }
    
    ; Draw the boxes with proper scaling and enhanced visibility
    for box in boxes {
        ; Scale box coordinates from canvas space to thumbnail space
        x1 := ((box.left - canvasLeft) * scaleX) + offsetX
        y1 := ((box.top - canvasTop) * scaleY) + offsetY
        x2 := ((box.right - canvasLeft) * scaleX) + offsetX
        y2 := ((box.bottom - canvasTop) * scaleY) + offsetY
        
        ; Calculate box dimensions
        w := x2 - x1
        h := y2 - y1
        
        ; Ensure minimum size for visibility (at least 2x2 pixels)
        if (w < 2) {
            centerX := (x1 + x2) / 2
            x1 := centerX - 1
            x2 := centerX + 1
            w := 2
        }
        if (h < 2) {
            centerY := (y1 + y2) / 2
            y1 := centerY - 1
            y2 := centerY + 1
            h := 2
        }
        
        ; Get degradation type color
        if (box.HasOwnProp("degradationType") && degradationColors.Has(box.degradationType)) {
            color := degradationColors[box.degradationType]
        } else {
            color := degradationColors[1]
        }
        
        ; PURE COLOR - No borders, full opacity for clean appearance
        fillColor := 0xFF000000 | color  ; Full opacity (FF = 255)
        
        ; Draw pure color fill only
        brush := 0
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", fillColor, "Ptr*", &brush)
        DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", brush, "Float", x1, "Float", y1, "Float", w, "Float", h)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
    }
    
}

SaveVisualizationPNG(bitmap, filePath) {
    ; Save bitmap as PNG
    clsid := Buffer(16)
    NumPut("UInt", 0x557CF406, clsid, 0)
    NumPut("UInt", 0x11D31A04, clsid, 4)
    NumPut("UInt", 0x0000739A, clsid, 8)
    NumPut("UInt", 0x2EF31EF8, clsid, 12)
    
    return DllCall("gdiplus\GdipSaveImageToFile", "Ptr", bitmap, "WStr", filePath, "Ptr", clsid, "Ptr", 0) = 0
}

; ===== CANVAS CALIBRATION FUNCTIONS =====
CalibrateCanvasArea() {
    global userCanvasLeft, userCanvasTop, userCanvasRight, userCanvasBottom, isCanvasCalibrated
    
    ; Prompt user to define canvas area
    result := MsgBox("Define your canvas area for accurate macro visualization.`n`nClick OK then:`n1. Click TOP-LEFT corner of your canvas`n2. Click BOTTOM-RIGHT corner of your canvas", "Canvas Calibration", "OKCancel")
    
    if (result = "Cancel") {
        return
    }
    
    UpdateStatus("📐 Canvas Calibration: Click TOP-LEFT corner...")
    
    ; Get top-left corner
    KeyWait("LButton", "D")
    MouseGetPos(&x1, &y1)
    Sleep(500)
    
    UpdateStatus("📐 Canvas Calibration: Click BOTTOM-RIGHT corner...")
    
    ; Get bottom-right corner  
    KeyWait("LButton", "D")
    MouseGetPos(&x2, &y2)
    
    ; Set canvas bounds
    userCanvasLeft := Min(x1, x2)
    userCanvasTop := Min(y1, y2)  
    userCanvasRight := Max(x1, x2)
    userCanvasBottom := Max(y1, y2)
    isCanvasCalibrated := true
    
    canvasW := userCanvasRight - userCanvasLeft
    canvasH := userCanvasBottom - userCanvasTop
    canvasAspect := Round(canvasW / canvasH, 2)
    
    UpdateStatus("✅ Canvas calibrated: " . canvasW . "x" . canvasH . " (ratio: " . canvasAspect . ":1)")
    
    ; Refresh all button visualizations with new canvas
    RefreshAllButtonAppearances()
}

ResetCanvasCalibration() {
    global isCanvasCalibrated
    
    result := MsgBox("Reset canvas calibration to automatic detection?", "Reset Canvas", "YesNo")
    if (result = "Yes") {
        isCanvasCalibrated := false
        UpdateStatus("🔄 Canvas calibration reset - using automatic detection")
        RefreshAllButtonAppearances()
    }
}

; ===== HOTKEY SETUP - FIXED F9 SYSTEM =====
SetupHotkeys() {
    try {
        ; CRITICAL: Clear any existing F9 hotkey to prevent conflicts
        try {
            Hotkey("F9", "Off")
        } catch {
        }
        
        Sleep(50)  ; Ensure cleanup
        
        ; F9 RECORDING CONTROL - COMPLETELY ISOLATED
        Hotkey("F9", F9_RecordingOnly, "On")
        
        ; Debug and utility keys
        Hotkey("F11", (*) => ShowRecordingDebug())
        Hotkey("F12", (*) => ShowOfflineStatsScreen())
        
        ; Layer navigation
        Hotkey("NumpadDiv", (*) => SwitchLayer("prev"))
        Hotkey("NumpadSub", (*) => SwitchLayer("next"))
        
        ; Macro execution - EXPLICITLY EXCLUDE F9
        Hotkey("Numpad7", (*) => SafeExecuteMacroByKey("Num7"))
        Hotkey("Numpad8", (*) => SafeExecuteMacroByKey("Num8"))
        Hotkey("Numpad9", (*) => SafeExecuteMacroByKey("Num9"))
        Hotkey("Numpad4", (*) => SafeExecuteMacroByKey("Num4"))
        Hotkey("Numpad5", (*) => SafeExecuteMacroByKey("Num5"))
        Hotkey("Numpad6", (*) => SafeExecuteMacroByKey("Num6"))
        Hotkey("Numpad1", (*) => SafeExecuteMacroByKey("Num1"))
        Hotkey("Numpad2", (*) => SafeExecuteMacroByKey("Num2"))
        Hotkey("Numpad3", (*) => SafeExecuteMacroByKey("Num3"))
        Hotkey("Numpad0", (*) => SafeExecuteMacroByKey("Num0"))
        Hotkey("NumpadDot", (*) => SafeExecuteMacroByKey("NumDot"))
        Hotkey("NumpadMult", (*) => SafeExecuteMacroByKey("NumMult"))
        
        ; Utility
        Hotkey("NumpadEnter", (*) => SubmitCurrentImage())
        Hotkey("RCtrl", (*) => EmergencyStop())
        
        UpdateStatus("✅ Hotkeys configured - F9 isolated for recording only")
    } catch Error as e {
        UpdateStatus("⚠️ Hotkey setup failed: " . e.Message)
        MsgBox("Hotkey error: " . e.Message, "Setup Error", "Icon!")
    }
}

; ===== F9 RECORDING HANDLER - COMPLETELY ISOLATED =====
F9_RecordingOnly(*) {
    global recording, awaitingAssignment, breakMode, playback, annotationMode
    
    ; Comprehensive state checking with detailed logging
    UpdateStatus("🔧 F9 PRESSED (" . annotationMode . " mode) - Checking states...")
    
    ; Block in problematic states
    if (breakMode && !recording) {
        UpdateStatus("☕ F9 BLOCKED: Break mode active")
        return
    }
    
    if (playback) {
        UpdateStatus("⏸️ F9 BLOCKED: Macro playback active")
        return
    }
    
    if (awaitingAssignment) {
        UpdateStatus("🎯 F9 BLOCKED: Assignment pending - ESC to cancel")
        return
    }
    
    ; Clean up any conflicting timers
    try {
        SetTimer(CheckForAssignment, 0)
    } catch {
    }
    
    ; Execute recording toggle with full error handling
    try {
        if (recording) {
            UpdateStatus("🛑 F9: STOPPING recording...")
            ForceStopRecording()
        } else {
            UpdateStatus("🎥 F9: STARTING recording...")
            ForceStartRecording()
        }
    } catch Error as e {
        UpdateStatus("❌ F9 FAILED: " . e.Message)
        ; Emergency state reset
        recording := false
        SafeUninstallMouseHook()
        SafeUninstallKeyboardHook()
        ResetRecordingUI()
    }
}

; ===== FORCED RECORDING FUNCTIONS =====
ForceStartRecording() {
    global recording, currentMacro, macroEvents, currentLayer, mainGui, pendingBoxForTagging
    
    ; Force clean state
    recording := false
    SafeUninstallMouseHook()
    SafeUninstallKeyboardHook()
    
    ; Start fresh
    recording := true
    currentMacro := "temp_recording_" . A_TickCount
    macroEvents[currentMacro] := []
    pendingBoxForTagging := ""
    
    CoordMode("Mouse", "Screen")
    InstallMouseHook()
    InstallKeyboardHook()
    
    ; Update UI
    if (mainGui && mainGui.HasProp("btnRecord")) {
        mainGui.btnRecord.Text := "🔴 Stop (F9)"
        mainGui.btnRecord.Opt("+Background0xDC143C")
    }
    
    UpdateStatus("🎥 RECORDING ACTIVE on Layer " . currentLayer . " - Draw boxes, F9 to stop")
}

ForceStopRecording() {
    global recording, currentMacro, macroEvents, awaitingAssignment, mainGui, pendingBoxForTagging
    
    if (!recording) {
        UpdateStatus("⚠️ Not recording - F9 ignored")
        return
    }
    
    recording := false
    SafeUninstallMouseHook()
    SafeUninstallKeyboardHook()
    pendingBoxForTagging := ""
    
    ResetRecordingUI()
    
    eventCount := macroEvents.Has(currentMacro) ? macroEvents[currentMacro].Length : 0
    if (eventCount = 0) {
        UpdateStatus("🎬 Recording stopped - No events captured")
        if (macroEvents.Has(currentMacro)) {
            macroEvents.Delete(currentMacro)
        }
        return
    }
    
    ; Analyze and save
    AnalyzeRecordedMacro(currentMacro)
    SaveConfig()
    
    awaitingAssignment := true
    UpdateStatus("🎯 Recording complete (" . eventCount . " events) → Press numpad key to assign")
    SetTimer(CheckForAssignment, 25)
}

ResetRecordingUI() {
    global mainGui
    if (mainGui && mainGui.HasProp("btnRecord")) {
        mainGui.btnRecord.Text := "🎥 Record"
        mainGui.btnRecord.Opt("-Background +BackgroundDefault")
    }
}

; ===== SAFE MACRO EXECUTION - BLOCKS F9 =====
SafeExecuteMacroByKey(buttonName) {
    ; CRITICAL: Absolutely prevent F9 from reaching macro execution
    if (buttonName = "F9" || InStr(buttonName, "F9")) {
        UpdateStatus("🚫 F9 BLOCKED from macro execution - Use for recording only")
        return
    }
    
    UpdateStatus("🎹 Numpad: " . buttonName)
    ExecuteMacro(buttonName)
}

ExecuteMacro(buttonName) {
    global awaitingAssignment, currentLayer, macroEvents, playback, focusDelay
    
    ; Double-check F9 protection
    if (buttonName = "F9" || InStr(buttonName, "F9")) {
        UpdateStatus("🚫 F9 EXECUTION BLOCKED")
        return
    }
    
    if (awaitingAssignment) {
        SetTimer(CheckForAssignment, 0)
        AssignToButton(buttonName)
        return
    }
    
    layerMacroName := "L" . currentLayer . "_" . buttonName
    if (!macroEvents.Has(layerMacroName) || macroEvents[layerMacroName].Length = 0) {
        UpdateStatus("⌛ No macro: " . buttonName . " L" . currentLayer . " | F9 to record")
        return
    }
    
    if (playback) {
        UpdateStatus("⌚ Already executing")
        return
    }
    
    playback := true
    FlashButton(buttonName, true)
    FocusBrowser()
    
    events := macroEvents[layerMacroName]
    startTime := A_TickCount
    
    if (events.Length = 1 && events[1].type = "jsonAnnotation") {
        UpdateStatus("⚡ JSON " . events[1].mode . " L" . currentLayer)
        ExecuteJsonAnnotation(events[1])
    } else {
        UpdateStatus("▶️ Playing macro...")
        PlayEventsOptimized(events)
    }
    
    executionTime := A_TickCount - startTime
    analysisRecord := MacroExecutionAnalysis(buttonName, events, executionTime)
    
    ; Record execution stats with analysis data
    if (events.Length = 1 && events[1].type = "jsonAnnotation") {
        RecordExecutionStats(buttonName, startTime, "json_profile", events, analysisRecord)
    } else {
        RecordExecutionStats(buttonName, startTime, "macro", events, analysisRecord)
    }
    
    FlashButton(buttonName, false)
    playback := false
    UpdateStatus("✅ Completed: " . buttonName)
}

; ===== RECORDING SYSTEM =====
InstallMouseHook() {
    global mouseHook
    if (!mouseHook) {
        mouseHook := DllCall("SetWindowsHookEx", "Int", 14, "Ptr", CallbackCreate(MouseProc), "Ptr", 0, "UInt", 0, "Ptr")
    }
}

SafeUninstallMouseHook() {
    global mouseHook
    if (mouseHook) {
        try {
            result := DllCall("UnhookWindowsHookEx", "Ptr", mouseHook)
            if (!result) {
                DllCall("UnhookWindowsHookEx", "Ptr", mouseHook)
            }
        } catch {
        } finally {
            mouseHook := 0
        }
    }
}

MouseProc(nCode, wParam, lParam) {
    global recording, currentMacro, macroEvents, mouseMoveThreshold, mouseMoveInterval, boxDragMinDistance
    
    if (nCode < 0 || !recording || currentMacro = "") {
        return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "UInt", wParam, "Ptr", lParam)
    }
    
    static WM_LBUTTONDOWN := 0x0201, WM_LBUTTONUP := 0x0202, WM_MOUSEMOVE := 0x0200
    static lastX := 0, lastY := 0, lastMoveTime := 0, isDrawingBox := false, boxStartX := 0, boxStartY := 0
    
    local x := NumGet(lParam, 0, "Int")
    local y := NumGet(lParam, 4, "Int")
    local timestamp := A_TickCount
    
    if (!macroEvents.Has(currentMacro))
        macroEvents[currentMacro] := []
    
    local events := macroEvents[currentMacro]
    
    if (wParam = WM_LBUTTONDOWN) {
        isDrawingBox := true
        boxStartX := x
        boxStartY := y
        events.Push({type: "mouseDown", button: "left", x: x, y: y, time: timestamp})
        
    } else if (wParam = WM_LBUTTONUP) {
        if (isDrawingBox) {
            local dragDistX := Abs(x - boxStartX)
            local dragDistY := Abs(y - boxStartY)
            
            if (dragDistX > boxDragMinDistance && dragDistY > boxDragMinDistance) {
                local boundingBoxEvent := {
                    type: "boundingBox", 
                    left: Min(boxStartX, x),
                    top: Min(boxStartY, y),
                    right: Max(boxStartX, x),
                    bottom: Max(boxStartY, y),
                    time: timestamp
                }
                events.Push(boundingBoxEvent)
                UpdateStatus("📦 Box created → Press 1-9 to tag")
            } else {
                events.Push({type: "click", button: "left", x: x, y: y, time: timestamp})
            }
            isDrawingBox := false
        }
        events.Push({type: "mouseUp", button: "left", x: x, y: y, time: timestamp})
        
    } else if (wParam = WM_MOUSEMOVE) {
        local moveDistance := Sqrt((x - lastX) ** 2 + (y - lastY) ** 2)
        local timeDelta := timestamp - lastMoveTime
        if (moveDistance > mouseMoveThreshold && timeDelta > mouseMoveInterval) {
            events.Push({type: "mouseMove", x: x, y: y, time: timestamp})
            lastX := x
            lastY := y
            lastMoveTime := timestamp
        }
    }
    
    return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "UInt", wParam, "Ptr", lParam)
}

InstallKeyboardHook() {
    global keyboardHook
    if (!keyboardHook) {
        keyboardHook := DllCall("SetWindowsHookEx", "Int", 13, "Ptr", CallbackCreate(KeyboardProc), "Ptr", 0, "UInt", 0, "Ptr")
    }
}

SafeUninstallKeyboardHook() {
    global keyboardHook
    if (keyboardHook) {
        try {
            result := DllCall("UnhookWindowsHookEx", "Ptr", keyboardHook)
            if (!result) {
                DllCall("UnhookWindowsHookEx", "Ptr", keyboardHook)
            }
        } catch {
        } finally {
            keyboardHook := 0
        }
    }
}

KeyboardProc(nCode, wParam, lParam) {
    global recording, currentMacro, macroEvents
    
    if (nCode < 0 || !recording || currentMacro = "") {
        return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "UInt", wParam, "Ptr", lParam)
    }
    
    static WM_KEYDOWN := 0x0100, WM_KEYUP := 0x0101
    local vkCode := NumGet(lParam, 0, "UInt")
    local keyName := GetKeyName("vk" . Format("{:X}", vkCode))
    
    ; Never record F9 or RCtrl
    if (keyName = "F9" || keyName = "RCtrl") {
        return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "UInt", wParam, "Ptr", lParam)
    }
    
    if (!macroEvents.Has(currentMacro))
        macroEvents[currentMacro] := []
    
    local events := macroEvents[currentMacro]
    local timestamp := A_TickCount
    
    if (wParam = WM_KEYDOWN) {
        events.Push({type: "keyDown", key: keyName, time: timestamp})
    } else if (wParam = WM_KEYUP) {
        events.Push({type: "keyUp", key: keyName, time: timestamp})
    }
    
    return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "UInt", wParam, "Ptr", lParam)
}

; ===== ASSIGNMENT PROCESS =====
CheckForAssignment() {
    global awaitingAssignment
    if (!awaitingAssignment) {
        SetTimer(CheckForAssignment, 0)
        return
    }
    
    keyMappings := Map(
        "Numpad7", "Num7", "Numpad8", "Num8", "Numpad9", "Num9",
        "Numpad4", "Num4", "Numpad5", "Num5", "Numpad6", "Num6",
        "Numpad1", "Num1", "Numpad2", "Num2", "Numpad3", "Num3",
        "Numpad0", "Num0", "NumpadDot", "NumDot", "NumpadMult", "NumMult"
    )
    
    for numpadKey, buttonName in keyMappings {
        if (GetKeyState(numpadKey, "P")) {
            awaitingAssignment := false
            SetTimer(CheckForAssignment, 0)
            KeyWait(numpadKey)
            AssignToButton(buttonName)
            return
        }
    }
    
    if (GetKeyState("Escape", "P")) {
        awaitingAssignment := false
        SetTimer(CheckForAssignment, 0)
        KeyWait("Escape")
        CancelAssignmentProcess()
        return
    }
}

CancelAssignmentProcess() {
    global currentMacro, macroEvents, awaitingAssignment
    awaitingAssignment := false
    if (macroEvents.Has(currentMacro)) {
        macroEvents.Delete(currentMacro)
    }
    UpdateStatus("⚠️ Assignment cancelled")
}

AssignToButton(buttonName) {
    global currentMacro, macroEvents, currentLayer, awaitingAssignment
    
    awaitingAssignment := false
    layerMacroName := "L" . currentLayer . "_" . buttonName
    
    if (!macroEvents.Has(currentMacro) || macroEvents[currentMacro].Length = 0) {
        UpdateStatus("⚠️ No macro to assign")
        return
    }
    
    if (macroEvents.Has(layerMacroName)) {
        macroEvents.Delete(layerMacroName)
    }
    
    macroEvents[layerMacroName] := []
    for event in macroEvents[currentMacro] {
        macroEvents[layerMacroName].Push(event)
    }
    
    macroEvents.Delete(currentMacro)
    
    events := macroEvents[layerMacroName]
    UpdateButtonAppearance(buttonName)
    SaveMacroState()
    
    UpdateStatus("✅ Assigned to " . buttonName . " Layer " . currentLayer . " (" . events.Length . " events)")
}

; ===== MACRO PLAYBACK =====
PlayEventsOptimized(recordedEvents) {
    global playback, boxDrawDelay, mouseClickDelay, mouseDragDelay, mouseReleaseDelay, betweenBoxDelay, keyPressDelay
    
    SetMouseDelay(0)
    SetKeyDelay(5)
    CoordMode("Mouse", "Screen")
    
    for eventIndex, event in recordedEvents {
        if (!playback)
            break
        
        if (event.type = "boundingBox") {
            MouseMove(event.left, event.top, 2)
            Sleep(boxDrawDelay)
            
            Send("{LButton Down}")
            Sleep(mouseClickDelay)
            
            MouseMove(event.right, event.bottom, 5)
            Sleep(mouseReleaseDelay)
            
            Send("{LButton Up}")
            Sleep(betweenBoxDelay)
        }
        else if (event.type = "mouseDown") {
            MouseMove(event.x, event.y, 2)
            Sleep(10)
            Send("{LButton Down}")
        }
        else if (event.type = "mouseUp") {
            MouseMove(event.x, event.y, 2)
            Sleep(10)
            Send("{LButton Up}")
        }
        else if (event.type = "keyDown") {
            Send("{" . event.key . " Down}")
            Sleep(keyPressDelay)
        }
        else if (event.type = "keyUp") {
            Send("{" . event.key . " Up}")
        }
    }
    
    SetMouseDelay(10)
    SetKeyDelay(10)
}

ExecuteJsonAnnotation(jsonEvent) {
    global annotationMode
    
    UpdateStatus("⚡ Executing JSON annotation (" . jsonEvent.mode . " mode)")
    FocusBrowser()
    
    ; Use the stored annotation from the JSON event
    A_Clipboard := jsonEvent.annotation
    Sleep(20)
    Send("^v")
    Sleep(30)
    Send("+{Enter}")
    
    UpdateStatus("✅ JSON annotation executed in " . jsonEvent.mode . " mode")
}

FocusBrowser() {
    global focusDelay
    if (WinExist("ahk_exe chrome.exe"))
        WinActivate("ahk_exe chrome.exe")
    else if (WinExist("ahk_exe firefox.exe"))
        WinActivate("ahk_exe firefox.exe")
    else if (WinExist("ahk_exe msedge.exe"))
        WinActivate("ahk_exe msedge.exe")
    else
        return false
    
    Sleep(focusDelay)
    return true
}

; ===== GUI MANAGEMENT =====
InitializeGui() {
    global mainGui, statusBar, darkMode, windowWidth, windowHeight, scaleFactor, minWindowWidth, minWindowHeight
    
    mainGui := Gui("+Resize +MinSize" . minWindowWidth . "x" . minWindowHeight, "Data Labeling Assistant")
    mainGui.BackColor := darkMode ? "0x2D2D2D" : "0xF0F0F0"
    mainGui.SetFont("s" . Round(10 * scaleFactor), darkMode ? "c0xFFFFFF" : "c0x000000")
    
    CreateToolbar()
    CreateGridOutline()
    CreateButtonGrid()
    CreateStatusBar()
    
    mainGui.OnEvent("Size", GuiResize)
    mainGui.OnEvent("Close", (*) => SafeExit())
    
    mainGui.Show("w" . windowWidth . " h" . windowHeight)
}

CreateToolbar() {
    global mainGui, layerIndicator, darkMode, currentLayer, layerNames, modeToggleBtn, scaleFactor, windowWidth, layerBorderColors
    
    toolbarHeight := Round(35 * scaleFactor)
    btnHeight := Round(30 * scaleFactor)
    btnY := Round((toolbarHeight - btnHeight) / 2)
    
    ; Background
    tbBg := mainGui.Add("Text", "x0 y0 w" . windowWidth . " h" . toolbarHeight)
    tbBg.BackColor := darkMode ? "0x1E1E1E" : "0xE8E8E8"
    mainGui.tbBg := tbBg
    
    ; Left section
    spacing := 8
    x := spacing
    
    ; Record button
    btnRecord := mainGui.Add("Button", "x" . x . " y" . btnY . " w" . Round(75 * scaleFactor) . " h" . btnHeight, "🎥 Record")
    btnRecord.OnEvent("Click", (*) => F9_RecordingOnly())  ; Direct call to F9 handler
    btnRecord.SetFont("s9 bold")
    mainGui.btnRecord := btnRecord
    x += Round(80 * scaleFactor)
    
    ; Mode toggle - start with current annotation mode
    modeToggleBtn := mainGui.Add("Button", "x" . x . " y" . btnY . " w" . Round(90 * scaleFactor) . " h" . btnHeight, (annotationMode = "Wide" ? "🔦 WIDE MODE" : "📱 NARROW MODE"))
    modeToggleBtn.OnEvent("Click", (*) => ToggleAnnotationMode())
    modeToggleBtn.SetFont("s9 bold")
    modeToggleBtn.Opt("+Background" . (annotationMode = "Wide" ? "0x1E90FF" : "0xFF8C00"))
    modeToggleBtn.SetFont(, "cWhite")
    
    ; Store reference in main GUI for global access
    mainGui.modeToggleBtn := modeToggleBtn
    x += Round(95 * scaleFactor)
    
    ; Break mode toggle
    btnBreakMode := mainGui.Add("Button", "x" . x . " y" . btnY . " w" . Round(70 * scaleFactor) . " h" . btnHeight, "☕ Break")
    btnBreakMode.OnEvent("Click", (*) => ToggleBreakMode())
    btnBreakMode.SetFont("s8 bold")
    btnBreakMode.Opt("+Background0x4CAF50")
    mainGui.btnBreakMode := btnBreakMode
    x += Round(75 * scaleFactor)
    
    ; Clear button
    btnClear := mainGui.Add("Button", "x" . x . " y" . btnY . " w" . Round(55 * scaleFactor) . " h" . btnHeight, "🗑️ Clear")
    btnClear.OnEvent("Click", (*) => ShowClearDialog())
    btnClear.SetFont("s7 bold")
    btnClear.Opt("+Background0xFF6347")
    x += Round(60 * scaleFactor)
    
    ; Center section - Layer navigation
    centerStart := Round(windowWidth * 0.35)
    layerWidth := Round(windowWidth * 0.3)
    
    btnPrevLayer := mainGui.Add("Button", "x" . centerStart . " y" . btnY . " w30 h" . btnHeight, "◀")
    btnPrevLayer.OnEvent("Click", (*) => SwitchLayer("prev"))
    btnPrevLayer.SetFont("s9 bold")
    mainGui.btnPrevLayer := btnPrevLayer
    
    layerIndicator := mainGui.Add("Text", "x" . (centerStart + 35) . " y" . (btnY + 2) . " w" . (layerWidth - 70) . " h" . (btnHeight - 4) . " Center +Border", "Layer " . currentLayer)
    layerIndicator.Opt("c" . (darkMode ? "White" : "Black"))
    layerIndicator.SetFont("s9 bold")
    layerIndicator.Opt("+Background" . layerBorderColors[currentLayer])
    
    btnNextLayer := mainGui.Add("Button", "x" . (centerStart + layerWidth - 30) . " y" . btnY . " w30 h" . btnHeight, "▶")
    btnNextLayer.OnEvent("Click", (*) => SwitchLayer("next"))
    btnNextLayer.SetFont("s9 bold")
    mainGui.btnNextLayer := btnNextLayer
    
    ; Right section
    rightSection := Round(windowWidth * 0.7)
    rightWidth := windowWidth - rightSection - spacing
    btnWidth := Round((rightWidth - 20) / 3)
    
    btnStats := mainGui.Add("Button", "x" . rightSection . " y" . btnY . " w" . btnWidth . " h" . btnHeight, "📊 Stats")
    btnStats.OnEvent("Click", (*) => ShowStats())
    btnStats.SetFont("s8 bold")
    mainGui.btnStats := btnStats
    
    btnSettings := mainGui.Add("Button", "x" . (rightSection + btnWidth + 5) . " y" . btnY . " w" . btnWidth . " h" . btnHeight, "⚙️ Config")
    btnSettings.OnEvent("Click", (*) => ShowSettings())
    btnSettings.SetFont("s8 bold")
    mainGui.btnSettings := btnSettings
    
    btnEmergency := mainGui.Add("Button", "x" . (rightSection + (btnWidth * 2) + 10) . " y" . btnY . " w" . btnWidth . " h" . btnHeight, "🚨 RCtrl")
    btnEmergency.OnEvent("Click", (*) => EmergencyStop())
    btnEmergency.SetFont("s8 bold")
    btnEmergency.Opt("+Background0xDC143C")
    mainGui.btnEmergency := btnEmergency
}

CreateGridOutline() {
    global mainGui, gridOutline, currentLayer, layerBorderColors
    
    gridOutline := mainGui.Add("Text", "x0 y0 w100 h100 +0x1", "")
    gridOutline.Opt("+Background" . layerBorderColors[currentLayer])
}

CreateButtonGrid() {
    global mainGui, buttonGrid, buttonLabels, buttonPictures, buttonNames, darkMode, windowWidth, windowHeight, gridOutline, scaleFactor
    
    margin := 8
    padding := 4
    toolbarHeight := Round(35 * scaleFactor)
    gridTopPadding := 4
    gridBottomPadding := 30
    
    gridWidth := windowWidth - (margin * 2)
    gridHeight := windowHeight - toolbarHeight - gridTopPadding - gridBottomPadding - (margin * 2)
    
    buttonWidth := Floor((gridWidth - padding * 2) / 3)
    buttonHeight := Floor((gridHeight - padding * 3) / 4)
    labelHeight := Round(18 * scaleFactor)
    thumbHeight := buttonHeight - labelHeight - 2
    
    outlineThickness := 2
    gridOutline.Move(margin - outlineThickness, toolbarHeight + gridTopPadding + margin - outlineThickness, 
                    gridWidth + (outlineThickness * 2), gridHeight + (outlineThickness * 2))
    
    for row in [0, 1, 2, 3] {
        for col in [0, 1, 2] {
            index := row * 3 + col + 1
            if (index > 12)
                continue
                
            buttonName := buttonNames[index]
            x := margin + col * (buttonWidth + padding)
            y := toolbarHeight + gridTopPadding + margin + row * (buttonHeight + padding)
            
            button := mainGui.Add("Text", "x" . Floor(x) . " y" . Floor(y) . " w" . Floor(buttonWidth) . " h" . Floor(thumbHeight) . " 0x201 +Border", "")
            if (darkMode) {
                button.Opt("+Background0x2A2A2A")
                button.SetFont("s" . Round(9 * scaleFactor), "cWhite")
            } else {
                button.Opt("+Background0xF8F8F8")
                button.SetFont("s" . Round(9 * scaleFactor), "cBlack")
            }
            
            picture := mainGui.Add("Picture", "x" . Floor(x) . " y" . Floor(y) . " w" . Floor(buttonWidth) . " h" . Floor(thumbHeight) . " Hidden")
            
            label := mainGui.Add("Text", "x" . Floor(x) . " y" . Floor(y + thumbHeight + 1) . " w" . Floor(buttonWidth) . " h" . Floor(labelHeight) . " Center BackgroundTrans", buttonName)
            label.Opt("c" . (darkMode ? "White" : "Black"))
            label.SetFont("s" . Round(8 * scaleFactor) . " bold")
            
            buttonGrid[buttonName] := button
            buttonLabels[buttonName] := label
            buttonPictures[buttonName] := picture
            
            button.OnEvent("Click", HandleButtonClick.Bind(buttonName))
            button.OnEvent("ContextMenu", HandleContextMenu.Bind(buttonName))
            picture.OnEvent("Click", HandleButtonClick.Bind(buttonName))
            picture.OnEvent("ContextMenu", HandleContextMenu.Bind(buttonName))
            
            UpdateButtonAppearance(buttonName)
        }
    }
}

CreateStatusBar() {
    global mainGui, statusBar, darkMode, windowWidth, windowHeight
    
    statusY := windowHeight - 25
    statusBar := mainGui.Add("Text", "x8 y" . statusY . " w" . (windowWidth - 16) . " h20", "✅ Ready - F9 to record")
    statusBar.Opt("c" . (darkMode ? "White" : "Black"))
    statusBar.SetFont("s9")
}

HandleButtonClick(buttonName, *) {
    UpdateStatus("🖱️ Button: " . buttonName)
    ExecuteMacro(buttonName)
}

HandleContextMenu(buttonName, *) {
    UpdateStatus("🖱️ Right-click: " . buttonName)
    ShowContextMenu(buttonName)
}

; ===== BUTTON APPEARANCE =====
RefreshAllButtonAppearances() {
    global buttonNames
    for buttonName in buttonNames {
        UpdateButtonAppearance(buttonName)
    }
}

UpdateButtonAppearance(buttonName) {
    global buttonGrid, buttonPictures, buttonThumbnails, macroEvents, buttonCustomLabels, darkMode, currentLayer, layerBorderColors, degradationTypes, degradationColors
    
    if (!buttonGrid.Has(buttonName))
        return
    
    button := buttonGrid[buttonName]
    picture := buttonPictures[buttonName]
    layerMacroName := "L" . currentLayer . "_" . buttonName
    
    hasMacro := macroEvents.Has(layerMacroName) && macroEvents[layerMacroName].Length > 0
    
    buttonLabels[buttonName].Text := buttonCustomLabels.Has(buttonName) ? buttonCustomLabels[buttonName] : buttonName
    
    hasThumbnail := buttonThumbnails.Has(layerMacroName) && FileExist(buttonThumbnails[layerMacroName])
    
    isJsonAnnotation := false
    jsonInfo := ""
    jsonColor := "0xFFD700"
    
    if (hasMacro && macroEvents[layerMacroName].Length = 1 && macroEvents[layerMacroName][1].type = "jsonAnnotation") {
        isJsonAnnotation := true
        jsonEvent := macroEvents[layerMacroName][1]
        typeName := StrTitle(degradationTypes[jsonEvent.categoryId])
        jsonInfo := jsonEvent.mode . "`n" . typeName . " " . StrUpper(jsonEvent.severity)
        
        if (degradationColors.Has(jsonEvent.categoryId)) {
            jsonColor := degradationColors[jsonEvent.categoryId]
        }
    }
    
    try {
        ; PRIORITY 1: Check for live macro visualization (NEW!)
        hasVisualizableMacro := hasMacro && !isJsonAnnotation && macroEvents[layerMacroName].Length > 1
        
        if (hasVisualizableMacro) {
            ; Generate live macro visualization using exact thumbnail dimensions
            ; Get actual thumbnail dimensions from button layout
            buttonSize := GetButtonThumbnailSize()
            
            ; Extract boxes first to debug
            boxes := ExtractBoxEvents(macroEvents[layerMacroName])
            
            if (boxes.Length > 0) {
                vizFile := CreateMacroVisualization(macroEvents[layerMacroName], buttonSize)
                
                if (vizFile && FileExist(vizFile)) {
                    button.Visible := false
                    picture.Visible := true
                    picture.Text := ""
                    try {
                        picture.Value := vizFile
                        ; Clean up old visualization file after a delay
                        SetTimer(() => DeleteVisualizationFile(vizFile), -5000)
                    } catch Error as e {
                        ; Fall back to text display with debug info
                        ShowMacroAsText(button, picture, macroEvents[layerMacroName], "IMG_ERR")
                    }
                } else {
                    ; Fall back to text display if visualization creation fails
                    ShowMacroAsText(button, picture, macroEvents[layerMacroName], "VIZ_ERR")
                }
            } else {
                ; No boxes found - fall back to text display
                ShowMacroAsText(button, picture, macroEvents[layerMacroName], "NO_BOXES")
            }
        } else if (hasThumbnail && !isJsonAnnotation) {
            ; PRIORITY 2: Static thumbnail (existing functionality)
            button.Visible := false
            picture.Visible := true
            picture.Text := ""
            try {
                picture.Value := buttonThumbnails[layerMacroName]
            } catch {
                ShowMacroAsText(button, picture, macroEvents[layerMacroName])
            }
        } else {
            ; PRIORITY 3: Text display (existing functionality)
            picture.Visible := false
            button.Visible := true
            button.Opt("-Background")
            
            if (isJsonAnnotation) {
                button.Opt("+Background" . jsonColor)
                button.SetFont("s7 bold", "cBlack")
                button.Text := jsonInfo
            } else if (hasMacro) {
                events := macroEvents[layerMacroName]
                button.Opt("+Background" . layerBorderColors[currentLayer])
                button.SetFont("s7 bold", "cWhite")
                button.Text := "MACRO`n" . events.Length . " events"
            } else {
                button.Opt("+Background" . (darkMode ? "0x2A2A2A" : "0xF8F8F8"))
                button.SetFont("s8", "cGray")
                button.Text := "L" . currentLayer
            }
        }
        
        if (button.Visible)
            button.Redraw()
        if (picture.Visible)
            picture.Redraw()
            
    } catch Error as e {
        button.Visible := true
        picture.Visible := false
        button.Opt("+Background" . (darkMode ? "0x2A2A2A" : "0xF8F8F8"))
        button.SetFont("s8", "cGray")
        button.Text := "ERROR"
    }
}

; Helper function for macro text display fallback
ShowMacroAsText(button, picture, events, debugInfo := "viz unavailable") {
    global layerBorderColors, currentLayer
    
    picture.Visible := false
    button.Visible := true
    button.Opt("+Background" . layerBorderColors[currentLayer])
    button.SetFont("s7 bold", "cWhite")
    button.Text := "MACRO`n" . events.Length . " events`n(" . debugInfo . ")"
}

; Helper function to get exact button thumbnail dimensions
GetButtonThumbnailSize() {
    global windowWidth, windowHeight, scaleFactor
    
    ; Calculate based on CreateButtonGrid logic
    margin := 12
    padding := 4
    toolbarHeight := Round(45 * scaleFactor)
    gridTopPadding := 8
    gridBottomPadding := 50
    
    gridWidth := windowWidth - 2 * margin
    gridHeight := windowHeight - toolbarHeight - gridTopPadding - gridBottomPadding
    
    buttonWidth := Floor((gridWidth - padding * 2) / 3)
    buttonHeight := Floor((gridHeight - padding * 3) / 4)
    labelHeight := Round(18 * scaleFactor)
    thumbHeight := buttonHeight - labelHeight - 2
    
    ; Return actual thumbnail dimensions (not minimum) to fill the area properly
    return {width: buttonWidth, height: thumbHeight}
}

; Helper function to clean up temporary visualization files
DeleteVisualizationFile(filePath) {
    try {
        if (FileExist(filePath)) {
            FileDelete(filePath)
        }
    } catch {
        ; Ignore deletion errors
    }
}

FlashButton(buttonName, isFlashing) {
    global buttonGrid
    if (!buttonGrid.Has(buttonName))
        return
    
    button := buttonGrid[buttonName]
    if (isFlashing) {
        button.Opt("+Background0xFFFFFF")
        button.SetFont(, "cBlack")
        SetTimer(UpdateButtonAppearanceDelayed.Bind(buttonName), -100)
    }
}

UpdateButtonAppearanceDelayed(buttonName) {
    UpdateButtonAppearance(buttonName)
}

UpdateStatus(text) {
    global statusBar
    if (IsObject(statusBar)) {
        statusBar.Text := text
        ; Clear save/config messages after 3 seconds to prevent overlap
        if (InStr(text, "💾") || InStr(text, "📄") || InStr(text, "config")) {
            SetTimer(() => (statusBar.Text := "✅ Ready - F9 to record"), -3000)
        }
    }
}

GuiResize(thisGui, minMax, width, height) {
    global statusBar, windowWidth, windowHeight, mainGui
    
    if (minMax = -1)
        return
    
    windowWidth := width
    windowHeight := height
    
    if (statusBar) {
        statusY := height - 25
        statusBar.Move(8, statusY, width - 16, 20)
    }
    
    if (mainGui.HasProp("tbBg") && mainGui.tbBg) {
        mainGui.tbBg.Move(0, 0, width, 35)
    }
    
    CreateButtonGrid()
}

; ===== LAYER SYSTEM =====
SwitchLayer(direction) {
    global currentLayer, totalLayers, layerIndicator, layerNames, buttonNames, gridOutline, layerBorderColors
    
    if (direction = "next") {
        currentLayer++
        if (currentLayer > totalLayers)
            currentLayer := 1
    } else if (direction = "prev") {
        currentLayer--
        if (currentLayer < 1)
            currentLayer := totalLayers
    }
    
    layerIndicator.Text := "Layer " . currentLayer
    layerIndicator.Opt("+Background" . layerBorderColors[currentLayer])
    gridOutline.Opt("+Background" . layerBorderColors[currentLayer])
    
    gridOutline.Redraw()
    layerIndicator.Redraw()
    
    for name in buttonNames {
        UpdateButtonAppearance(name)
    }
    
    UpdateStatus("🔥 Layer " . currentLayer)
}

; ===== CONTEXT MENUS =====
ShowContextMenu(buttonName, *) {
    global currentLayer, degradationTypes, severityLevels
    
    contextMenu := Menu()
    
    contextMenu.Add("🎥 Record Macro", (*) => F9_RecordingOnly())  ; Use F9 handler
    contextMenu.Add("🗑️ Clear Macro", (*) => ClearMacro(buttonName))
    contextMenu.Add("🏷️ Edit Label", (*) => EditCustomLabel(buttonName))
    contextMenu.Add()
    
    jsonMainMenu := Menu()
    
    for id, typeName in degradationTypes {
        typeMenu := Menu()
        
        for severity in severityLevels {
            presetName := StrTitle(typeName) . " (" . StrTitle(severity) . ")"
            typeMenu.Add(StrTitle(severity), AssignJsonAnnotation.Bind(buttonName, presetName))
        }
        
        jsonMainMenu.Add("🎨 " . StrTitle(typeName), typeMenu)
    }
    
    contextMenu.Add("🏷️ JSON Profiles", jsonMainMenu)
    contextMenu.Add()
    
    contextMenu.Add("🖼️ Add Thumbnail", (*) => AddThumbnail(buttonName))
    contextMenu.Add("🗑️ Remove Thumbnail", (*) => RemoveThumbnail(buttonName))
    
    contextMenu.Show()
}

ClearMacro(buttonName) {
    global macroEvents, currentLayer
    layerMacroName := "L" . currentLayer . "_" . buttonName
    if (MsgBox("Clear macro for " . buttonName . " on Layer " . currentLayer . "?", "Confirm Clear", "YesNo Icon!") = "Yes") {
        macroEvents.Delete(layerMacroName)
        UpdateButtonAppearance(buttonName)
        SaveConfig()
        UpdateStatus("🗑️ Cleared " . buttonName)
    }
}

ShowClearDialog() {
    if (MsgBox("Clear all macros and data?", "Confirm Clear All", "YesNo Icon!") = "Yes") {
        global macroEvents, macroExecutionLog
        macroEvents.Clear()
        macroExecutionLog := []
        
        for buttonName in buttonNames {
            UpdateButtonAppearance(buttonName)
        }
        
        UpdateStatus("🗑️ All data cleared")
    }
}

; ===== BREAK MODE =====
ToggleBreakMode() {
    global breakMode, breakStartTime, totalActiveTime, lastActiveTime, mainGui, buttonGrid, buttonNames
    
    if (breakMode) {
        breakMode := false
        lastActiveTime := A_TickCount
        
        if (mainGui && mainGui.HasProp("btnBreakMode")) {
            mainGui.btnBreakMode.Text := "☕ Break"
            mainGui.btnBreakMode.Opt("+Background0x4CAF50")
        }
        
        EnableAllControls(true)
        RestoreNormalUI()
        UpdateStatus("✅ Back from break")
        
    } else {
        breakMode := true
        breakStartTime := A_TickCount
        
        if (lastActiveTime > 0) {
            totalActiveTime += A_TickCount - lastActiveTime
        }
        
        if (mainGui && mainGui.HasProp("btnBreakMode")) {
            mainGui.btnBreakMode.Text := "🔴 Resume"
            mainGui.btnBreakMode.Opt("+Background0xFF5722")
        }
        
        EnableAllControls(false)
        ApplyBreakModeUI()
        UpdateStatus("☕ Break mode active")
    }
}

EnableAllControls(enabled) {
    global mainGui, recording, buttonGrid, buttonNames
    
    if (!enabled && recording) {
        ForceStopRecording()
    }
    
    if (mainGui) {
        try {
            if (mainGui.HasProp("btnRecord")) mainGui.btnRecord.Enabled := enabled
            if (mainGui.HasProp("modeToggleBtn")) mainGui.modeToggleBtn.Enabled := enabled
            
            for buttonName in buttonNames {
                if (buttonGrid.Has(buttonName)) {
                    buttonGrid[buttonName].Enabled := enabled
                }
            }
        } catch {
        }
    }
}

ApplyBreakModeUI() {
    global mainGui, darkMode
    
    try {
        if (mainGui) {
            mainGui.BackColor := "0x8B0000"
            
            if (mainGui.HasProp("tbBg")) {
                mainGui.tbBg.BackColor := "0xDC143C"
                mainGui.tbBg.Redraw()
            }
            
            mainGui.Redraw()
        }
    } catch {
    }
}

RestoreNormalUI() {
    global mainGui, darkMode
    
    try {
        if (mainGui) {
            mainGui.BackColor := darkMode ? "0x2D2D2D" : "0xF0F0F0"
            
            if (mainGui.HasProp("tbBg")) {
                mainGui.tbBg.BackColor := darkMode ? "0x1E1E1E" : "0xE8E8E8"
                mainGui.tbBg.Redraw()
            }
            
            mainGui.Redraw()
        }
    } catch {
    }
}

; ===== COMPREHENSIVE STATS SYSTEM =====
ShowStats() {
    global macroExecutionLog, degradationTypes, degradationColors, annotationMode
    global applicationStartTime, totalActiveTime, lastActiveTime, breakMode
    
    statsGui := Gui("+Resize", "📊 Comprehensive Analytics")
    statsGui.SetFont("s10")
    
    ; Header
    statsGui.Add("Text", "x20 y20 w860 h30 Center", "COMPREHENSIVE DEGRADATION & USAGE ANALYTICS")
    statsGui.SetFont("s14 Bold")
    
    ; Timeline filter controls
    statsGui.SetFont("s9")
    statsGui.Add("Text", "x20 y60 w100 h20", "Timeline Filter:")
    
    timelineCombo := statsGui.Add("ComboBox", "x120 y58 w120 h200", ["All Time", "Last 1 Hour", "Last 4 Hours", "Last 1 Day", "Last 1 Week"])
    timelineCombo.Text := "All Time"
    
    btnResetStats := statsGui.Add("Button", "x250 y57 w100 h25", "Reset Stats")
    btnResetStats.OnEvent("Click", (*) => ResetStatsData(statsGui, timelineCombo.Text))
    
    ; Time tracking display with proper formatting
    currentActiveTime := breakMode ? totalActiveTime : (totalActiveTime + (A_TickCount - lastActiveTime))
    timeDisplay := FormatActiveTime(currentActiveTime)
    
    statsGui.Add("Text", "x370 y60 w200 h20", "Active Time: " . timeDisplay)
    
    ; Create tabbed interface
    tabs := statsGui.Add("Tab3", "x20 y90 w860 h450", ["📦 Recorded Macros", "📋 JSON Profiles", "📊 Combined Overview"])
    
    ; Store references for updates
    statsGui.timelineCombo := timelineCombo
    statsGui.tabs := tabs
    
    ; Setup tab content
    CreateRecordedMacrosTab(statsGui, tabs, "All Time")
    CreateJsonProfilesTab(statsGui, tabs, "All Time")
    CreateCombinedOverviewTab(statsGui, tabs, "All Time")
    
    ; Timeline combo event handler
    timelineCombo.OnEvent("Change", (*) => RefreshAllTabs(statsGui, timelineCombo.Text))
    
    ; Export and control buttons
    statsGui.Add("Text", "x20 y560 w860 h20", "📤 Export & Controls:")
    
    btnExportCSV := statsGui.Add("Button", "x20 y590 w120 h30", "📊 Export CSV")
    btnExportCSV.OnEvent("Click", (*) => ExportDegradationData())
    
    btnExportAll := statsGui.Add("Button", "x150 y590 w130 h30", "📄 Export All Data")
    btnExportAll.OnEvent("Click", (*) => ExportAllHistoricalData())
    
    ; Quick reference
    statsGui.Add("Text", "x20 y640 w860 h40", "🎯 DEGRADATION MAPPING: 1=Smudge, 2=Glare, 3=Splashes, 4=Partial Block, 5=Full Block, 6=Light Flare, 7=Rain, 8=Haze, 9=Snow")
    
    btnClose := statsGui.Add("Button", "x800 y690 w80 h30", "Close")
    btnClose.OnEvent("Click", (*) => statsGui.Destroy())
    
    statsGui.Show("w900 h730")
}

ShowSettings() {
    ; Create settings dialog with tabbed interface
    settingsGui := Gui("+Resize", "⚙️ Configuration Manager")
    settingsGui.SetFont("s10")
    
    ; Header
    settingsGui.Add("Text", "x20 y20 w460 h30 Center", "CONFIGURATION MANAGEMENT")
    settingsGui.SetFont("s12 Bold")
    
    ; Create tabbed interface
    tabs := settingsGui.Add("Tab3", "x20 y60 w460 h400", ["📦 Configuration", "⚙️ Execution Settings", "🎁 Macro Packs"])
    
    ; TAB 1: Configuration Management
    tabs.UseTab(1)
    
    ; Import/Export section
    settingsGui.SetFont("s9")
    settingsGui.Add("Text", "x40 y95 w400 h20", "📦 Import & Export:")
    
    btnExport := settingsGui.Add("Button", "x40 y120 w120 h30", "📤 Export Config")
    btnExport.OnEvent("Click", (*) => ExportConfiguration())
    
    btnImport := settingsGui.Add("Button", "x170 y120 w120 h30", "📥 Import Config")
    btnImport.OnEvent("Click", (*) => ImportConfiguration())
    
    btnCreatePack := settingsGui.Add("Button", "x300 y120 w120 h30", "📦 Create Pack")
    btnCreatePack.OnEvent("Click", (*) => CreateMacroPack())
    
    ; Quick save/load slots
    settingsGui.Add("Text", "x40 y165 w400 h20", "🎛️ Quick Save Slots:")
    
    ; Slot 1
    btnSaveSlot1 := settingsGui.Add("Button", "x40 y190 w80 h25", "Save Slot 1")
    btnSaveSlot1.OnEvent("Click", (*) => SaveToSlot(1))
    
    btnLoadSlot1 := settingsGui.Add("Button", "x125 y190 w80 h25", "Load Slot 1")
    btnLoadSlot1.OnEvent("Click", (*) => LoadFromSlot(1))
    
    ; Slot 2
    btnSaveSlot2 := settingsGui.Add("Button", "x220 y190 w80 h25", "Save Slot 2")
    btnSaveSlot2.OnEvent("Click", (*) => SaveToSlot(2))
    
    btnLoadSlot2 := settingsGui.Add("Button", "x305 y190 w80 h25", "Load Slot 2")
    btnLoadSlot2.OnEvent("Click", (*) => LoadFromSlot(2))
    
    ; Slot 3
    btnSaveSlot3 := settingsGui.Add("Button", "x40 y220 w80 h25", "Save Slot 3")
    btnSaveSlot3.OnEvent("Click", (*) => SaveToSlot(3))
    
    btnLoadSlot3 := settingsGui.Add("Button", "x125 y220 w80 h25", "Load Slot 3")
    btnLoadSlot3.OnEvent("Click", (*) => LoadFromSlot(3))
    
    ; Slot 4
    btnSaveSlot4 := settingsGui.Add("Button", "x220 y220 w80 h25", "Save Slot 4")
    btnSaveSlot4.OnEvent("Click", (*) => SaveToSlot(4))
    
    btnLoadSlot4 := settingsGui.Add("Button", "x305 y220 w80 h25", "Load Slot 4")
    btnLoadSlot4.OnEvent("Click", (*) => LoadFromSlot(4))
    
    ; Clear configuration
    settingsGui.Add("Text", "x40 y260 w400 h20", "🗑️ Reset Options:")
    
    btnClearConfig := settingsGui.Add("Button", "x40 y285 w180 h30", "🗑️ Clear All Macros")
    btnClearConfig.OnEvent("Click", (*) => ClearAllMacros(settingsGui))
    
    btnResetStats := settingsGui.Add("Button", "x240 y285 w180 h30", "📊 Reset Statistics")
    btnResetStats.OnEvent("Click", (*) => ResetStatsFromSettings(settingsGui))
    
    ; Canvas configuration section
    settingsGui.Add("Text", "x40 y330 w400 h20", "🖼️ Thumbnail Canvas Configuration:")
    
    ; Show canvas status
    global wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom, isWideCanvasCalibrated
    global narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom, isNarrowCanvasCalibrated
    
    wideStatusText := isWideCanvasCalibrated ? "✅ Wide Canvas Configured" : "❌ Wide Canvas Not Set"
    narrowStatusText := isNarrowCanvasCalibrated ? "✅ Narrow Canvas Configured" : "❌ Narrow Canvas Not Set"
    
    settingsGui.Add("Text", "x60 y355 w180 h15 " . (isWideCanvasCalibrated ? "cGreen" : "cRed"), wideStatusText)
    settingsGui.Add("Text", "x260 y355 w180 h15 " . (isNarrowCanvasCalibrated ? "cGreen" : "cRed"), narrowStatusText)
    
    ; Configuration buttons
    btnConfigureWide := settingsGui.Add("Button", "x40 y375 w180 h30", "📐 Configure Wide Canvas")
    btnConfigureWide.OnEvent("Click", (*) => ConfigureWideCanvasFromSettings(settingsGui))
    
    btnConfigureNarrow := settingsGui.Add("Button", "x240 y375 w180 h30", "📐 Configure Narrow Canvas")
    btnConfigureNarrow.OnEvent("Click", (*) => ConfigureNarrowCanvasFromSettings(settingsGui))
    
    ; Help text
    settingsGui.Add("Text", "x40 y410 w400 h25", "Set up canvas areas for picture-perfect thumbnails:`nWide = landscape/widescreen, Narrow = portrait/square")
    
    ; TAB 2: Execution Settings
    tabs.UseTab(2)
    settingsGui.Add("Text", "x40 y95 w400 h20", "⚡ Macro Execution Fine-Tuning:")
    
    ; Timing controls
    global boxDrawDelay, mouseClickDelay, mouseDragDelay, mouseReleaseDelay, betweenBoxDelay, keyPressDelay, focusDelay
    
    ; Box drawing delays
    settingsGui.Add("Text", "x40 y125 w150 h20", "Box Draw Delay (ms):")
    boxDelayEdit := settingsGui.Add("Edit", "x190 y123 w60 h22", boxDrawDelay)
    boxDelayEdit.OnEvent("Change", (*) => UpdateTimingFromEdit("boxDrawDelay", boxDelayEdit))
    
    settingsGui.Add("Text", "x40 y155 w150 h20", "Mouse Click Delay (ms):")
    clickDelayEdit := settingsGui.Add("Edit", "x190 y153 w60 h22", mouseClickDelay)
    clickDelayEdit.OnEvent("Change", (*) => UpdateTimingFromEdit("mouseClickDelay", clickDelayEdit))
    
    settingsGui.Add("Text", "x40 y185 w150 h20", "Mouse Drag Delay (ms):")
    dragDelayEdit := settingsGui.Add("Edit", "x190 y183 w60 h22", mouseDragDelay)
    dragDelayEdit.OnEvent("Change", (*) => UpdateTimingFromEdit("mouseDragDelay", dragDelayEdit))
    
    settingsGui.Add("Text", "x40 y215 w150 h20", "Mouse Release Delay (ms):")
    releaseDelayEdit := settingsGui.Add("Edit", "x190 y213 w60 h22", mouseReleaseDelay)
    releaseDelayEdit.OnEvent("Change", (*) => UpdateTimingFromEdit("mouseReleaseDelay", releaseDelayEdit))
    
    settingsGui.Add("Text", "x270 y125 w150 h20", "Between Box Delay (ms):")
    betweenDelayEdit := settingsGui.Add("Edit", "x420 y123 w60 h22", betweenBoxDelay)
    betweenDelayEdit.OnEvent("Change", (*) => UpdateTimingFromEdit("betweenBoxDelay", betweenDelayEdit))
    
    settingsGui.Add("Text", "x270 y155 w150 h20", "Key Press Delay (ms):")
    keyDelayEdit := settingsGui.Add("Edit", "x420 y153 w60 h22", keyPressDelay)
    keyDelayEdit.OnEvent("Change", (*) => UpdateTimingFromEdit("keyPressDelay", keyDelayEdit))
    
    settingsGui.Add("Text", "x270 y185 w150 h20", "Focus Delay (ms):")
    focusDelayEdit := settingsGui.Add("Edit", "x420 y183 w60 h22", focusDelay)
    focusDelayEdit.OnEvent("Change", (*) => UpdateTimingFromEdit("focusDelay", focusDelayEdit))
    
    ; Preset buttons
    settingsGui.Add("Text", "x40 y255 w400 h20", "🎚️ Timing Presets:")
    
    btnFast := settingsGui.Add("Button", "x40 y280 w90 h25", "⚡ Fast")
    btnFast.OnEvent("Click", (*) => ApplyTimingPreset("fast", settingsGui))
    
    btnDefault := settingsGui.Add("Button", "x140 y280 w90 h25", "🎯 Default")
    btnDefault.OnEvent("Click", (*) => ApplyTimingPreset("default", settingsGui))
    
    btnSafe := settingsGui.Add("Button", "x240 y280 w90 h25", "🛡️ Safe")
    btnSafe.OnEvent("Click", (*) => ApplyTimingPreset("safe", settingsGui))
    
    btnSlow := settingsGui.Add("Button", "x340 y280 w90 h25", "🐌 Slow")
    btnSlow.OnEvent("Click", (*) => ApplyTimingPreset("slow", settingsGui))
    
    ; Instructions
    settingsGui.Add("Text", "x40 y320 w400 h50", "💡 Adjust timing delays to optimize macro execution speed vs reliability. Higher values = more reliable but slower execution. Use presets for quick setup.")
    
    ; TAB 3: Macro Packs
    tabs.UseTab(3)
    settingsGui.Add("Text", "x40 y95 w400 h20", "🎁 Macro Pack Management:")
    
    btnBrowsePacks := settingsGui.Add("Button", "x40 y120 w180 h30", "📚 Browse Local Packs")
    btnBrowsePacks.OnEvent("Click", (*) => BrowseMacroPacks())
    
    btnImportPack := settingsGui.Add("Button", "x240 y120 w180 h30", "📥 Import New Pack")
    btnImportPack.OnEvent("Click", (*) => ImportNewMacroPack())
    
    ; Pack sharing info
    settingsGui.Add("Text", "x40 y165 w400 h80", "📝 Macro Packs are specialized sharing packages that contain:• Selected layers with macros• Degradation tracking data• Optional thumbnails and statistics• Author information and descriptions")
    
    settingsGui.Add("Text", "x40 y255 w400 h40", "🌐 Share packs with other users by sending the ZIP files. Recipients can import them via 'Import New Pack' to add macros to their collection.")
    
    ; Close button
    btnClose := settingsGui.Add("Button", "x420 y470 w60 h25", "Close")
    btnClose.OnEvent("Click", (*) => settingsGui.Destroy())
    
    settingsGui.Show("w500 h510")
}

; Aspect ratio specific calibration functions
CalibrateWideCanvas() {
    global wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom, isWideCanvasCalibrated, buttonNames
    
    result := MsgBox("Calibrate 16:9 Wide Canvas Area`n`nThis is for WIDE mode recordings (full screen, widescreen).`n`nClick OK then:`n1. Click TOP-LEFT corner of your 16:9 area`n2. Click BOTTOM-RIGHT corner of your 16:9 area", "Wide Canvas Calibration", "OKCancel")
    
    if (result = "Cancel") {
        return
    }
    
    UpdateStatus("🔦 Wide Canvas (16:9): Click TOP-LEFT corner...")
    
    KeyWait("LButton", "D")
    MouseGetPos(&x1, &y1)
    Sleep(500)
    
    UpdateStatus("🔦 Wide Canvas (16:9): Click BOTTOM-RIGHT corner...")
    
    KeyWait("LButton", "D")
    MouseGetPos(&x2, &y2)
    
    ; Set wide canvas bounds
    wideCanvasLeft := Min(x1, x2)
    wideCanvasTop := Min(y1, y2)
    wideCanvasRight := Max(x1, x2)
    wideCanvasBottom := Max(y1, y2)
    isWideCanvasCalibrated := true
    
    ; Validate aspect ratio
    canvasW := wideCanvasRight - wideCanvasLeft
    canvasH := wideCanvasBottom - wideCanvasTop
    aspectRatio := canvasW / canvasH
    
    if (Abs(aspectRatio - 1.777) > 0.1) {
        UpdateStatus("⚠️ Wide canvas aspect ratio is " . Round(aspectRatio, 2) . " (expected ~1.78 for 16:9)")
    } else {
        UpdateStatus("✅ Wide canvas (16:9) calibrated: " . wideCanvasLeft . "," . wideCanvasTop . " to " . wideCanvasRight . "," . wideCanvasBottom)
    }
    
    SaveConfig()
    for buttonName in buttonNames {
        UpdateButtonAppearance(buttonName)
    }
}

CalibrateNarrowCanvas() {
    global narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom, isNarrowCanvasCalibrated, buttonNames
    
    result := MsgBox("Calibrate 4:3 Narrow Canvas Area`n`nThis is for NARROW mode recordings (constrained, square-ish).`n`nClick OK then:`n1. Click TOP-LEFT corner of your 4:3 area`n2. Click BOTTOM-RIGHT corner of your 4:3 area", "Narrow Canvas Calibration", "OKCancel")
    
    if (result = "Cancel") {
        return
    }
    
    UpdateStatus("📱 Narrow Canvas (4:3): Click TOP-LEFT corner...")
    
    KeyWait("LButton", "D")
    MouseGetPos(&x1, &y1)
    Sleep(500)
    
    UpdateStatus("📱 Narrow Canvas (4:3): Click BOTTOM-RIGHT corner...")
    
    KeyWait("LButton", "D")
    MouseGetPos(&x2, &y2)
    
    ; Set narrow canvas bounds
    narrowCanvasLeft := Min(x1, x2)
    narrowCanvasTop := Min(y1, y2)
    narrowCanvasRight := Max(x1, x2)
    narrowCanvasBottom := Max(y1, y2)
    isNarrowCanvasCalibrated := true
    
    ; Validate aspect ratio
    canvasW := narrowCanvasRight - narrowCanvasLeft
    canvasH := narrowCanvasBottom - narrowCanvasTop
    aspectRatio := canvasW / canvasH
    
    if (Abs(aspectRatio - 1.333) > 0.1) {
        UpdateStatus("⚠️ Narrow canvas aspect ratio is " . Round(aspectRatio, 2) . " (expected ~1.33 for 4:3)")
    } else {
        UpdateStatus("✅ Narrow canvas (4:3) calibrated: " . narrowCanvasLeft . "," . narrowCanvasTop . " to " . narrowCanvasRight . "," . narrowCanvasBottom)
    }
    
    SaveConfig()
    for buttonName in buttonNames {
        UpdateButtonAppearance(buttonName)
    }
}

; Helper functions for settings interface canvas configuration
ConfigureWideCanvasFromSettings(settingsGui) {
    settingsGui.Hide()
    CalibrateWideCanvas()
    settingsGui.Destroy()
    ShowSettings()  ; Refresh the settings dialog
}

ConfigureNarrowCanvasFromSettings(settingsGui) {
    settingsGui.Hide()
    CalibrateNarrowCanvas()
    settingsGui.Destroy()
    ShowSettings()  ; Refresh the settings dialog
}

UpdateModeToggleButton() {
    global annotationMode, modeToggleBtn
    
    if (modeToggleBtn) {
        if (annotationMode = "Narrow") {
            modeToggleBtn.Text := "📱 NARROW MODE"
            modeToggleBtn.Opt("+Background0xFF8C00")
        } else {
            modeToggleBtn.Text := "🔦 WIDE MODE"  
            modeToggleBtn.Opt("+Background0x1E90FF")
        }
        modeToggleBtn.SetFont("s9 bold", "cWhite")
        modeToggleBtn.Redraw()
        
        ; Don't spam status on initialization
    }
}

ToggleAnnotationMode() {
    global annotationMode, modeToggleBtn
    
    if (annotationMode = "Wide") {
        annotationMode := "Narrow"
        modeToggleBtn.Text := "📱 NARROW MODE"
        modeToggleBtn.Opt("+Background0xFF8C00")
        UpdateStatus("📱 SWITCHED TO NARROW MODE - Constrained recording with letterbox bars")
    } else {
        annotationMode := "Wide"
        modeToggleBtn.Text := "🔦 WIDE MODE"
        modeToggleBtn.Opt("+Background0x1E90FF")
        UpdateStatus("🔦 SWITCHED TO WIDE MODE - Full screen recording area")
    }
    
    modeToggleBtn.SetFont("s9 bold", "cWhite")
    
    ; Update existing JSON macros when mode changes
    UpdateExistingJSONMacros(annotationMode)
    
    ; Quietly save the mode change (no status spam)
    try {
        SaveConfig()
    } catch {
        ; Silent save, don't spam status
    }
}

; ===== UPDATE EXISTING JSON MACROS =====
UpdateExistingJSONMacros(newMode) {
    global macroEvents, degradationTypes, buttonNames, totalLayers, jsonAnnotations, currentLayer
    
    updatedCount := 0
    Loop totalLayers {
        layer := A_Index
        for buttonName in buttonNames {
            layerMacroName := "L" . layer . "_" . buttonName
            if (macroEvents.Has(layerMacroName) && macroEvents[layerMacroName].Length = 1 && macroEvents[layerMacroName][1].type = "jsonAnnotation") {
                jsonEvent := macroEvents[layerMacroName][1]
                typeName := StrTitle(degradationTypes[jsonEvent.categoryId])
                presetName := typeName . " (" . StrTitle(jsonEvent.severity) . ")" . (newMode = "Narrow" ? " Narrow" : "")
                
                if (jsonAnnotations.Has(presetName)) {
                    ; Update the annotation
                    jsonEvent.annotation := jsonAnnotations[presetName]
                    jsonEvent.mode := newMode
                    updatedCount++
                    
                    ; Update button appearance if it's on current layer
                    if (layer = currentLayer) {
                        UpdateButtonAppearance(buttonName)
                    }
                }
            }
        }
    }
    
    if (updatedCount > 0) {
        SaveConfig()
        UpdateStatus("Updated " . updatedCount . " JSON macros to " . newMode . " mode")
    }
}

; ===== ENHANCED CONTEXT MENU FUNCTIONS =====
EditCustomLabel(buttonName) {
    global buttonCustomLabels, buttonLabels
    
    currentLabel := buttonCustomLabels.Has(buttonName) ? buttonCustomLabels[buttonName] : buttonName
    result := InputBox("Enter label for " . buttonName . ":", "Edit Label", "w300 h130", currentLabel)
    
    if (result.Result != "Cancel" && result.Value != "") {
        buttonCustomLabels[buttonName] := result.Value
        buttonLabels[buttonName].Text := result.Value
        SaveConfig()
        UpdateStatus("🏷️ Updated label for " . buttonName . ": " . result.Value)
    }
}

AssignJsonAnnotation(buttonName, presetName, *) {
    global currentLayer, macroEvents, jsonAnnotations, degradationTypes, annotationMode
    
    layerMacroName := "L" . currentLayer . "_" . buttonName
    
    ; Use current annotation mode
    currentMode := annotationMode
    fullPresetName := presetName . (currentMode = "Narrow" ? " Narrow" : "")
    
    ; Debug logging
    UpdateStatus("🎨 Assigning " . fullPresetName . " in " . currentMode . " mode")
    
    if (jsonAnnotations.Has(fullPresetName)) {
        parts := StrSplit(presetName, " (")
        typeName := parts[1]
        severity := StrLower(SubStr(parts[2], 1, -1))
        
        categoryId := 0
        for id, name in degradationTypes {
            if (StrTitle(name) = typeName) {
                categoryId := id
                break
            }
        }
        
        if (categoryId > 0) {
            macroEvents[layerMacroName] := [{
                type: "jsonAnnotation",
                annotation: jsonAnnotations[fullPresetName],
                mode: currentMode,
                categoryId: categoryId,
                severity: severity
            }]
            UpdateButtonAppearance(buttonName)
            SaveConfig()
            UpdateStatus("🏷️ Assigned " . currentMode . " " . presetName . " to " . buttonName)
        } else {
            UpdateStatus("❌ Could not find category ID for " . typeName)
        }
    } else {
        UpdateStatus("❌ Could not find JSON annotation for " . fullPresetName)
        
        ; Debug: Show what's available
        UpdateStatus("🔍 Available modes: Wide=" . jsonAnnotations.Has(presetName) . ", Narrow=" . jsonAnnotations.Has(presetName . " Narrow"))
    }
}

AddThumbnail(buttonName) {
    global buttonThumbnails, currentLayer
    
    selectedFile := FileSelect("3", A_ScriptDir, "Select Thumbnail", "Images (*.png; *.jpg; *.jpeg; *.gif; *.bmp)")
    if (selectedFile != "") {
        layerMacroName := "L" . currentLayer . "_" . buttonName
        buttonThumbnails[layerMacroName] := selectedFile
        UpdateButtonAppearance(buttonName)
        SaveMacroState()
        UpdateStatus("🖼️ Added thumbnail for " . buttonName . " on Layer " . currentLayer)
    }
}

RemoveThumbnail(buttonName) {
    global buttonThumbnails, currentLayer
    
    layerMacroName := "L" . currentLayer . "_" . buttonName
    if (MsgBox("Remove thumbnail for " . buttonName . " on Layer " . currentLayer . "?", "Confirm Remove", "YesNo Icon!") = "Yes") {
        if (buttonThumbnails.Has(layerMacroName)) {
            buttonThumbnails.Delete(layerMacroName)
            UpdateButtonAppearance(buttonName)
            SaveMacroState()
            UpdateStatus("🗑️ Removed thumbnail for " . buttonName . " on Layer " . currentLayer)
        }
    }
}

; ===== JSON PLACEHOLDER CLASS =====
class JSON {
    static parse(text) {
        return []
    }
    
    static stringify(obj, replacer := "", space := "") {
        return "{}"
    }
}

InitializeStatsSystem() {
    global thumbnailDir
    
    ; Create thumbnail directory
    if !DirExist(thumbnailDir)
        DirCreate(thumbnailDir)
    
    LoadStatsData()
    
    ; Initialize offline data storage system
    InitializeOfflineStorage()
}

InitializeJsonAnnotations() {
    global jsonAnnotations, degradationTypes, severityLevels
    
    ; Clear any existing annotations
    jsonAnnotations := Map()
    
    ; Create annotations for all degradation types and severity levels in both modes
    for id, typeName in degradationTypes {
        for severity in severityLevels {
            presetName := StrTitle(typeName) . " (" . StrTitle(severity) . ")"
            
            ; Create Wide mode annotation
            jsonAnnotations[presetName] := BuildJsonAnnotation("Wide", id, severity)
            
            ; Create Narrow mode annotation  
            jsonAnnotations[presetName . " Narrow"] := BuildJsonAnnotation("Narrow", id, severity)
        }
    }
    
    UpdateStatus("📋 JSON annotations initialized for " . jsonAnnotations.Count . " presets")
}

BuildJsonAnnotation(mode, categoryId, severity) {
    ; Define precise coordinates for each mode
    if (mode = "Wide") {
        points := [[-22.18,-22.57],[3808.41,2130.71]]
    } else {
        points := [[-23.54,-23.12],[1891.76,1506.66]]
    }
    
    ; Build the complete JSON annotation string
    jsonStr := '{"is3DObject":false,"segmentsAnnotation":{"attributes":{"severity":"' . severity . '"},"track_id":1,"type":"bbox","category_id":' . categoryId . ',"points":[[' . points[1][1] . ',' . points[1][2] . '],[' . points[2][1] . ',' . points[2][2] . ']]}}'
    
    return jsonStr
}

; ===== TIME FORMATTING FUNCTION =====
FormatActiveTime(timeMs) {
    totalMinutes := Floor(timeMs / 60000)
    
    if (totalMinutes < 60) {
        return totalMinutes . "m"
    } else if (totalMinutes < 1440) {  ; Less than 24 hours
        hours := Floor(totalMinutes / 60)
        minutes := Mod(totalMinutes, 60)
        return hours . "h " . minutes . "m"
    } else {  ; Days
        days := Floor(totalMinutes / 1440)
        hours := Floor(Mod(totalMinutes, 1440) / 60)
        return days . "d " . hours . "h"
    }
}

; ===== TAB CREATION FUNCTIONS =====
CreateRecordedMacrosTab(statsGui, tabs, timeFilter) {
    tabs.UseTab(1)
    
    filteredExecutions := FilterExecutionsByTime(timeFilter)
    macroExecutions := []
    
    ; Filter only recorded macro executions
    for execution in filteredExecutions {
        if (execution.category = "macro" && execution.HasOwnProp("detailedBoxes")) {
            macroExecutions.Push(execution)
        }
    }
    
    ; Build recorded macros content with better formatting
    content := "╔═══════════════════════════════════════════════════════════════════════════════╗`n"
    content .= "║                    📦 RECORDED MACRO DEGRADATION ANALYSIS                     ║`n"
    content .= "║                              (" . timeFilter . ")                                    ║`n"
    content .= "╚═══════════════════════════════════════════════════════════════════════════════╝`n`n"
    content .= "📊 EXECUTION SUMMARY: " . macroExecutions.Length . " macro runs`n`n"
    
    if (macroExecutions.Length > 0) {
        ; Count degradations
        degradationCounts := Map()
        for id, typeName in degradationTypes {
            degradationCounts[typeName] := 0
        }
        
        totalBoxes := 0
        for execution in macroExecutions {
            totalBoxes += execution.boundingBoxCount
            for box in execution.detailedBoxes {
                if (degradationCounts.Has(box.degradationName)) {
                    degradationCounts[box.degradationName]++
                }
            }
        }
        
        content .= "┌──────────────────────────────────────────────────────────────────────────────┐`n"
        content .= "│                        📦 DEGRADATION TYPE BREAKDOWN                        │`n"
        content .= "│                         Total Boxes: " . totalBoxes . " boxes                            │`n"
        content .= "└──────────────────────────────────────────────────────────────────────────────┘`n`n"
        
        ; Create visual bars for degradation types
        for id, typeName in degradationTypes {
            count := degradationCounts[typeName]
            if (count > 0) {
                percentage := Round((count / totalBoxes) * 100, 1)
                ; Create visual bar (10 chars max)
                barLength := Round((count / totalBoxes) * 20)
                visualBar := ""
                Loop barLength {
                    visualBar .= "█"
                }
                Loop (20 - barLength) {
                    visualBar .= "░"
                }
                
                content .= id . ". " . StrTitle(typeName) . ": " . count . " (" . percentage . "%) [" . visualBar . "]`n"
            }
        }
        
        ; Show most frequently used macros
        content .= "`n┌──────────────────────────────────────────────────────────────────────────────┐`n"
        content .= "│                        🔥 MOST FREQUENTLY USED MACROS                       │`n"
        content .= "└──────────────────────────────────────────────────────────────────────────────┘`n"
        buttonCounts := Map()
        buttonDetails := Map()
        
        ; Count executions per button and collect details
        for execution in macroExecutions {
            buttonKey := execution.button . " (L" . execution.layer . ")"
            if (!buttonCounts.Has(buttonKey)) {
                buttonCounts[buttonKey] := 0
                buttonDetails[buttonKey] := {
                    totalBoxes: 0,
                    totalTime: 0,
                    lastUsed: execution.timestamp,
                    degradationSummary: ""
                }
            }
            buttonCounts[buttonKey]++
            buttonDetails[buttonKey].totalBoxes += execution.boundingBoxCount
            buttonDetails[buttonKey].totalTime += execution.executionTime
            if (execution.timestamp > buttonDetails[buttonKey].lastUsed) {
                buttonDetails[buttonKey].lastUsed := execution.timestamp
                buttonDetails[buttonKey].degradationSummary := execution.perBoxSummary
            }
        }
        
        ; Sort by frequency and show top 8
        sortedButtons := []
        for button, count in buttonCounts {
            sortedButtons.Push({button: button, count: count})
        }
        
        ; Simple bubble sort by count (descending)
        if (sortedButtons.Length > 1) {
            Loop (sortedButtons.Length - 1) {
                i := A_Index
                Loop (sortedButtons.Length - i) {
                    j := A_Index
                    if (sortedButtons[j].count < sortedButtons[j + 1].count) {
                        temp := sortedButtons[j]
                        sortedButtons[j] := sortedButtons[j + 1]
                        sortedButtons[j + 1] := temp
                    }
                }
            }
        }
        
        maxShow := Min(sortedButtons.Length, 8)
        Loop maxShow {
            buttonInfo := sortedButtons[A_Index]
            details := buttonDetails[buttonInfo.button]
            avgTime := Round(details.totalTime / buttonInfo.count)
            
            content .= "`n" . A_Index . ". " . buttonInfo.button . " ➤ " . buttonInfo.count . " executions"
            content .= " | " . details.totalBoxes . " boxes | ~" . avgTime . "ms avg"
            content .= "`n   ├─ Last: " . FormatTime(details.lastUsed, "MM/dd HH:mm")
            content .= "`n   └─ " . (details.degradationSummary != "" ? details.degradationSummary : "No degradations") . "`n"
        }
    } else {
        content .= "No recorded macro executions in this time period."
    }
    
    editRecorded := statsGui.Add("Edit", "x30 y120 w840 h400 ReadOnly VScroll", content)
    statsGui.editRecorded := editRecorded
}

CreateJsonProfilesTab(statsGui, tabs, timeFilter) {
    tabs.UseTab(2)
    
    filteredExecutions := FilterExecutionsByTime(timeFilter)
    jsonExecutions := []
    
    ; Filter only JSON profile executions
    for execution in filteredExecutions {
        if (execution.category = "json_profile") {
            jsonExecutions.Push(execution)
        }
    }
    
    ; Build JSON profiles content with better formatting
    content := "╔═══════════════════════════════════════════════════════════════════════════════╗`n"
    content .= "║                      📋 JSON PROFILE SEVERITY ANALYSIS                       ║`n"
    content .= "║                              (" . timeFilter . ")                                    ║`n"
    content .= "╚═══════════════════════════════════════════════════════════════════════════════╝`n`n"
    content .= "📊 PROFILE SUMMARY: " . jsonExecutions.Length . " JSON executions`n`n"
    
    if (jsonExecutions.Length > 0) {
        ; Count severities and degradation types for JSON annotations
        severityCounts := Map()
        jsonDegradationCounts := Map()
        
        for execution in jsonExecutions {
            ; Count severities
            if (execution.severity != "unknown") {
                if (!severityCounts.Has(execution.severity)) {
                    severityCounts[execution.severity] := 0
                }
                severityCounts[execution.severity]++
            }
            
            ; Count degradation types from JSON annotations
            if (execution.HasOwnProp("jsonDegradationName")) {
                degradationName := execution.jsonDegradationName
                if (!jsonDegradationCounts.Has(degradationName)) {
                    jsonDegradationCounts[degradationName] := 0
                }
                jsonDegradationCounts[degradationName]++
            }
        }
        
        content .= "┌──────────────────────────────────────────────────────────────────────────────┐`n"
        content .= "│                          🎯 SEVERITY USAGE BREAKDOWN                         │`n"
        content .= "└──────────────────────────────────────────────────────────────────────────────┘`n`n"
        
        ; Create visual bars for severity levels
        for severity, count in severityCounts {
            percentage := Round((count / jsonExecutions.Length) * 100, 1)
            ; Create visual bar
            barLength := Round((count / jsonExecutions.Length) * 20)
            visualBar := ""
            Loop barLength {
                visualBar .= "█"
            }
            Loop (20 - barLength) {
                visualBar .= "░"
            }
            
            content .= StrTitle(severity) . " Severity: " . count . " (" . percentage . "%) [" . visualBar . "]`n"
        }
        
        ; Show JSON degradation type breakdown
        if (jsonDegradationCounts.Count > 0) {
            content .= "`n┌──────────────────────────────────────────────────────────────────────────────┐`n"
            content .= "│                      🎨 JSON DEGRADATION TYPE BREAKDOWN                      │`n"
            content .= "└──────────────────────────────────────────────────────────────────────────────┘`n`n"
            
            for degradationName, count in jsonDegradationCounts {
                percentage := Round((count / jsonExecutions.Length) * 100, 1)
                ; Create visual bar
                barLength := Round((count / jsonExecutions.Length) * 20)
                visualBar := ""
                Loop barLength {
                    visualBar .= "█"
                }
                Loop (20 - barLength) {
                    visualBar .= "░"
                }
                
                content .= StrTitle(degradationName) . ": " . count . " (" . percentage . "%) [" . visualBar . "]`n"
            }
        }
    } else {
        content .= "No JSON profile executions in this time period."
    }
    
    editJson := statsGui.Add("Edit", "x30 y120 w840 h400 ReadOnly VScroll", content)
    statsGui.editJson := editJson
}

CreateCombinedOverviewTab(statsGui, tabs, timeFilter) {
    tabs.UseTab(3)
    
    filteredExecutions := FilterExecutionsByTime(timeFilter)
    
    ; Build combined overview with better formatting
    content := "╔═══════════════════════════════════════════════════════════════════════════════╗`n"
    content .= "║                          📊 COMBINED USAGE OVERVIEW                          ║`n"
    content .= "║                              (" . timeFilter . ")                                    ║`n"
    content .= "╚═══════════════════════════════════════════════════════════════════════════════╝`n`n"
    content .= "📄 TOTAL EXECUTIONS: " . filteredExecutions.Length . " operations`n`n"
    
    ; Separate counts
    macroCount := 0
    jsonCount := 0
    totalBoxes := 0
    
    for execution in filteredExecutions {
        if (execution.category = "macro") {
            macroCount++
            totalBoxes += execution.boundingBoxCount
        } else if (execution.category = "json_profile") {
            jsonCount++
        }
    }
    
    content .= "┌──────────────────────────────────────────────────────────────────────────────┐`n"
    content .= "│                        📊 EXECUTION TYPE BREAKDOWN                          │`n"
    content .= "└──────────────────────────────────────────────────────────────────────────────┘`n"
    content .= "🎬 Recorded Macros: " . macroCount . " executions (" . totalBoxes . " total boxes)`n"
    content .= "📋 JSON Profiles: " . jsonCount . " executions`n`n"
    
    if (filteredExecutions.Length > 0) {
        ; Calculate average execution time
        totalTime := 0
        for execution in filteredExecutions {
            totalTime += execution.executionTime
        }
        avgTime := Round(totalTime / filteredExecutions.Length)
        content .= "⚡ Average Execution Time: " . avgTime . "ms`n"
        
        ; Most used button
        buttonCounts := Map()
        layerCounts := Map()
        for execution in filteredExecutions {
            if (!buttonCounts.Has(execution.button)) {
                buttonCounts[execution.button] := 0
            }
            buttonCounts[execution.button]++
            
            if (!layerCounts.Has(execution.layer)) {
                layerCounts[execution.layer] := 0
            }
            layerCounts[execution.layer]++
        }
        
        maxCount := 0
        mostUsedButton := ""
        for button, count in buttonCounts {
            if (count > maxCount) {
                maxCount := count
                mostUsedButton := button
            }
        }
        
        maxLayerCount := 0
        mostUsedLayer := 0
        for layer, count in layerCounts {
            if (count > maxLayerCount) {
                maxLayerCount := count
                mostUsedLayer := layer
            }
        }
        
        content .= "🏆 Most Used Button: " . mostUsedButton . " (" . maxCount . " executions)`n"
        content .= "📊 Most Active Layer: Layer " . mostUsedLayer . " (" . maxLayerCount . " executions)`n"
        
        ; Efficiency metrics
        if (macroCount > 0) {
            avgBoxesPerMacro := Round(totalBoxes / macroCount, 1)
            content .= "📦 Average Boxes per Macro: " . avgBoxesPerMacro . " boxes`n"
        }
    }
    
    editCombined := statsGui.Add("Edit", "x30 y120 w840 h400 ReadOnly VScroll", content)
    statsGui.editCombined := editCombined
}

RefreshAllTabs(statsGui, timeFilter) {
    ; Clear existing content
    if (statsGui.HasProp("editRecorded")) {
        statsGui.editRecorded.Destroy()
    }
    if (statsGui.HasProp("editJson")) {
        statsGui.editJson.Destroy()
    }
    if (statsGui.HasProp("editCombined")) {
        statsGui.editCombined.Destroy()
    }
    
    ; Recreate all tabs
    CreateRecordedMacrosTab(statsGui, statsGui.tabs, timeFilter)
    CreateJsonProfilesTab(statsGui, statsGui.tabs, timeFilter)
    CreateCombinedOverviewTab(statsGui, statsGui.tabs, timeFilter)
}

FilterExecutionsByTime(timeFilter) {
    global macroExecutionLog
    
    if (timeFilter = "All Time") {
        return macroExecutionLog
    }
    
    ; Calculate time threshold
    currentTime := A_Now
    timeThreshold := 0
    
    switch timeFilter {
        case "Last 1 Hour":
            timeThreshold := DateAdd(currentTime, -1, "Hours")
        case "Last 4 Hours":
            timeThreshold := DateAdd(currentTime, -4, "Hours")
        case "Last 1 Day":
            timeThreshold := DateAdd(currentTime, -1, "Days")
        case "Last 1 Week":
            timeThreshold := DateAdd(currentTime, -7, "Days")
    }
    
    ; Filter executions
    filteredExecutions := []
    for execution in macroExecutionLog {
        if (execution.timestamp >= timeThreshold) {
            filteredExecutions.Push(execution)
        }
    }
    
    return filteredExecutions
}

ResetStatsData(statsGui, timeFilter) {
    global macroExecutionLog
    
    ; Export current data before clearing
    ExportAllHistoricalData()
    
    if (MsgBox("Reset all statistics data? This will clear current session data but preserve historical logs.", "Confirm Reset", "YesNo Icon!") = "Yes") {
        macroExecutionLog := []
        SaveExecutionData()
        RefreshAllTabs(statsGui, timeFilter)
        UpdateStatus("📊 Statistics reset - Historical data preserved")
    }
}

; ===== DATA EXPORT FUNCTIONS =====
ExportDegradationData() {
    global macroExecutionLog, workDir, degradationTypes
    
    if (macroExecutionLog.Length = 0) {
        UpdateStatus("⚠️ No execution data to export")
        return
    }
    
    try {
        timestamp := FormatTime(A_Now, "yyyyMMdd_HHmmss")
        filename := workDir . "\degradation_analysis_" . timestamp . ".csv"
        
        ; Create simplified CSV focused on degradation counts
        csvContent := "Timestamp,Button,Layer,Mode,TotalBoxes,DegradationSummary,ExecutionTime_ms`n"
        
        for execution in macroExecutionLog {
            csvContent .= FormatTime(execution.timestamp, "yyyy-MM-dd HH:mm:ss") . ","
            csvContent .= execution.button . ","
            csvContent .= execution.layer . ","
            csvContent .= execution.mode . ","
            csvContent .= execution.boundingBoxCount . ","
            csvContent .= (execution.HasOwnProp("perBoxSummary") ? execution.perBoxSummary : "No degradation data") . ","
            csvContent .= execution.executionTime . "`n"
        }
        
        FileDelete(filename)
        FileAppend(csvContent, filename)
        
        Run("notepad.exe " . filename)
        UpdateStatus("📊 Exported degradation analysis for " . macroExecutionLog.Length . " executions")
    } catch Error as e {
        UpdateStatus("⚠️ Export failed: " . e.Message)
    }
}

ExportAllHistoricalData() {
    global macroExecutionLog, workDir, totalActiveTime, lastActiveTime, breakMode, applicationStartTime
    
    try {
        timestamp := FormatTime(A_Now, "yyyyMMdd_HHmmss")
        filename := workDir . "\historical_session_data_" . timestamp . ".json"
        
        ; Calculate current active time
        currentActiveTime := breakMode ? totalActiveTime : (totalActiveTime + (A_TickCount - lastActiveTime))
        
        ; Create comprehensive session data
        sessionData := {
            sessionStartTime: FormatTime(applicationStartTime, "yyyy-MM-dd HH:mm:ss"),
            sessionEndTime: FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss"),
            totalActiveTimeMs: currentActiveTime,
            totalActiveTimeHours: Round(currentActiveTime / 3600000, 2),
            totalExecutions: macroExecutionLog.Length,
            exportTimestamp: A_Now,
            executions: macroExecutionLog
        }
        
        FileDelete(filename)
        FileAppend(JSON.stringify(sessionData, , 2), filename)
        
        UpdateStatus("📄 Historical data exported to " . filename)
        return filename
    } catch Error as e {
        UpdateStatus("⚠️ Historical export failed: " . e.Message)
        return ""
    }
}

MacroExecutionAnalysis(buttonName, events, executionTime) {
    global macroExecutionLog, currentLayer, annotationMode, macroEvents
    
    ; Extract bounding boxes and degradation information
    boundingBoxes := []
    detailedBoxes := []
    
    ; Process each bounding box and look for keypress AFTER it
    for eventIndex, event in events {
        if (event.type = "boundingBox") {
            ; Basic box count for compatibility
            boundingBoxes.Push({
                left: event.left,
                top: event.top,
                right: event.right,
                bottom: event.bottom
            })
            
            ; Default to smudge if no keypress found
            boxDegradationType := 1
            boxDegradationName := "smudge"
            isTagged := false
            
            ; Look for the NEXT keypress event after this bounding box
            Loop events.Length - eventIndex {
                nextIndex := eventIndex + A_Index
                if (nextIndex > events.Length)
                    break
                    
                nextEvent := events[nextIndex]
                
                ; Stop at next bounding box - keypress should be immediately after current box
                if (nextEvent.type = "boundingBox")
                    break
                
                ; Found a keypress after this box - this assigns the degradation type
                if (nextEvent.type = "keyDown" && RegExMatch(nextEvent.key, "^\d$")) {
                    keyNumber := Integer(nextEvent.key)
                    if (keyNumber >= 1 && keyNumber <= 9 && degradationTypes.Has(keyNumber)) {
                        boxDegradationType := keyNumber
                        boxDegradationName := degradationTypes[keyNumber]
                        isTagged := true
                        break  ; Found the assignment keypress, stop looking
                    }
                }
            }
            
            ; Create detailed box info
            detailedBox := {
                boxId: event.HasOwnProp("boxId") ? event.boxId : ("box_" . A_TickCount . "_" . eventIndex),
                degradationType: boxDegradationType,
                degradationName: boxDegradationName,
                recordingContext: isTagged ? "post_box_keypress" : "untagged_default",
                isTagged: isTagged
            }
            detailedBoxes.Push(detailedBox)
        }
    }
    
    ; Create simplified execution record
    executionRecord := {
        id: A_TickCount,
        timestamp: A_Now,
        button: buttonName,
        layer: currentLayer,
        mode: annotationMode,
        boundingBoxCount: boundingBoxes.Length,
        boundingBoxes: boundingBoxes,
        detailedBoxes: detailedBoxes,
        executionTime: executionTime,
        category: "macro",
        severity: "unknown",
        perBoxSummary: "",
        taggedBoxCount: 0,
        untaggedBoxCount: 0
    }
    
    ; Generate per-box summary and count tagged/untagged
    if (detailedBoxes.Length > 0) {
        boxSummary := Map()
        taggedCount := 0
        untaggedCount := 0
        
        for box in detailedBoxes {
            if (box.isTagged && box.degradationName != "untagged") {
                key := box.degradationName
                if (!boxSummary.Has(key)) {
                    boxSummary[key] := 0
                }
                boxSummary[key]++
                taggedCount++
            } else {
                untaggedCount++
            }
        }
        
        executionRecord.taggedBoxCount := taggedCount
        executionRecord.untaggedBoxCount := untaggedCount
        
        summaryParts := []
        for key, count in boxSummary {
            summaryParts.Push(count . "x" . key)
        }
        
        if (summaryParts.Length > 0) {
            executionRecord.perBoxSummary := Join(summaryParts, ", ")
            if (untaggedCount > 0) {
                executionRecord.perBoxSummary .= " | " . untaggedCount . " untagged"
            }
        } else if (untaggedCount > 0) {
            executionRecord.perBoxSummary := untaggedCount . " untagged boxes"
        }
    }
    
    ; Check if it's a JSON annotation to get degradation type and severity
    layerMacroName := "L" . currentLayer . "_" . buttonName
    if (macroEvents.Has(layerMacroName) && macroEvents[layerMacroName].Length = 1 && macroEvents[layerMacroName][1].type = "jsonAnnotation") {
        jsonEvent := macroEvents[layerMacroName][1]
        executionRecord.category := "json_profile"
        executionRecord.severity := jsonEvent.severity
        
        ; Add JSON annotation degradation type info
        if (jsonEvent.HasOwnProp("categoryId") && degradationTypes.Has(jsonEvent.categoryId)) {
            degradationName := degradationTypes[jsonEvent.categoryId]
            executionRecord.jsonDegradationType := jsonEvent.categoryId
            executionRecord.jsonDegradationName := degradationName
            executionRecord.perBoxSummary := "JSON: " . StrTitle(degradationName) . " (" . StrTitle(jsonEvent.severity) . ")"
        }
    }
    
    ; Add to execution log
    macroExecutionLog.Push(executionRecord)
    
    ; Save data
    SaveExecutionData()
    
    ; Create degradation assignments string for CSV
    degradationAssignments := ""
    if (detailedBoxes.Length > 0) {
        assignmentParts := []
        for box in detailedBoxes {
            assignmentParts.Push(box.degradationName)
        }
        degradationAssignments := Join(assignmentParts, ",")
    }
    
    ; Store degradation assignments in execution record for retrieval
    executionRecord.degradationAssignments := degradationAssignments
    
    ; Simple status update focused on degradation counts
    if (boundingBoxes.Length > 0) {
        if (executionRecord.perBoxSummary != "") {
            UpdateStatus("📊 Executed: " . executionRecord.perBoxSummary . " | " . executionTime . "ms")
        } else {
            UpdateStatus("📊 Executed " . boundingBoxes.Length . " boxes | " . executionTime . "ms")
        }
    } else {
        UpdateStatus("📊 Executed " . buttonName . " (no boxes)")
    }
    
    ; Return the execution record so degradation assignments can be retrieved
    return executionRecord
}

; Helper function for joining arrays
Join(array, delimiter) {
    result := ""
    for index, item in array {
        if (index > 1)
            result .= delimiter
        result .= item
    }
    return result
}

SaveExecutionData() {
    global workDir, macroExecutionLog
    
    try {
        ; Ensure directory exists
        if !DirExist(workDir) {
            DirCreate(workDir)
        }
        
        logFile := workDir . "\macro_execution_log.json"
        
        ; Simple JSON-like format since we have a placeholder JSON class
        jsonContent := "[\n"
        for i, execution in macroExecutionLog {
            if (i > 1) {
                jsonContent .= ",\n"
            }
            jsonContent .= "  {\n"
            jsonContent .= '    "id": ' . execution.id . ",\n"
            jsonContent .= '    "timestamp": "' . execution.timestamp . '",\n'
            jsonContent .= '    "button": "' . execution.button . '",\n'
            jsonContent .= '    "layer": ' . execution.layer . ",\n"
            jsonContent .= '    "mode": "' . execution.mode . '",\n'
            jsonContent .= '    "boundingBoxCount": ' . execution.boundingBoxCount . ",\n"
            jsonContent .= '    "executionTime": ' . execution.executionTime . ",\n"
            jsonContent .= '    "category": "' . execution.category . '",\n'
            jsonContent .= '    "severity": "' . execution.severity . '",\n'
            jsonContent .= '    "perBoxSummary": "' . (execution.HasOwnProp("perBoxSummary") ? execution.perBoxSummary : "") . '"\n'
            jsonContent .= "  }"
        }
        jsonContent .= "\n]"
        
        ; Delete existing file if it exists
        if FileExist(logFile) {
            FileDelete(logFile)
        }
        
        FileAppend(jsonContent, logFile)
        
    } catch Error as e {
        UpdateStatus("⚠️ Failed to save execution data: " . e.Message . " (Path: " . workDir . ")")
    }
}

LoadStatsData() {
    global workDir, macroExecutionLog, persistentStatsFile, totalExecutionTime, executionTimeLog
    
    try {
        ; Ensure directory exists
        if !DirExist(workDir) {
            DirCreate(workDir)
        }
        
        ; Load persistent stats
        if FileExist(persistentStatsFile) {
            content := FileRead(persistentStatsFile)
            if (content != "" && content != "{}") {
                try {
                    statsData := JSON.parse(content)
                    totalExecutionTime := statsData.Has("totalExecutionTime") ? statsData["totalExecutionTime"] : 0
                    if (statsData.Has("executionTimeLog")) {
                        executionTimeLog := statsData["executionTimeLog"]
                    } else {
                        executionTimeLog := []
                    }
                } catch {
                    totalExecutionTime := 0
                    executionTimeLog := []
                }
            }
        } else {
            totalExecutionTime := 0
            executionTimeLog := []
        }
        
        ; Load execution log (legacy support)
        logFile := workDir . "\macro_execution_log.json"
        if FileExist(logFile) {
            macroExecutionLog := []
        } else {
            macroExecutionLog := []
        }
        
        UpdateStatus("📊 Persistent stats loaded - Total execution time: " . Round(totalExecutionTime/1000, 2) . "s")
    } catch Error as e {
        macroExecutionLog := []
        totalExecutionTime := 0
        executionTimeLog := []
        UpdateStatus("⚠️ Failed to load stats data: " . e.Message)
    }
}

SavePersistentStats() {
    global persistentStatsFile, totalExecutionTime, executionTimeLog
    
    try {
        statsData := Map()
        statsData["lastUpdated"] := A_Now
        statsData["totalExecutionTime"] := totalExecutionTime
        statsData["executionTimeLog"] := executionTimeLog
        statsData["sessionCount"] := executionTimeLog.Length
        
        ; Add summary statistics
        if (executionTimeLog.Length > 0) {
            totalTime := 0
            for entry in executionTimeLog {
                totalTime += entry.executionTime
            }
            statsData["averageExecutionTime"] := totalTime / executionTimeLog.Length
            statsData["totalSessions"] := executionTimeLog.Length
        }
        
        jsonContent := JSON.stringify(statsData, , "  ")
        FileDelete(persistentStatsFile)
        FileAppend(jsonContent, persistentStatsFile, "UTF-8")
        
    } catch Error as e {
        UpdateStatus("⚠️ Failed to save persistent stats: " . e.Message)
    }
}
SaveMacroState() {
    global macroEvents, buttonThumbnails, configFile
    
    stateFile := StrReplace(configFile, ".ini", "_simple.txt")
    stateContent := ""
    macroCount := 0
    
    for macroName, events in macroEvents {
        if (events.Length > 0) {
            macroCount++
            for event in events {
                if (event.type = "boundingBox") {
                    stateContent .= macroName . "=boundingBox," . event.left . "," . event.top . "," . event.right . "," . event.bottom . "`n"
                }
                else if (event.type = "jsonAnnotation") {
                    stateContent .= macroName . "=jsonAnnotation," . event.mode . "," . event.categoryId . "," . event.severity . "`n"
                }
                else if (event.type = "keyDown") {
                    stateContent .= macroName . "=keyDown," . event.key . "`n"
                }
                else if (event.type = "keyUp") {
                    stateContent .= macroName . "=keyUp," . event.key . "`n"
                }
                else if (event.type = "mouseDown") {
                    stateContent .= macroName . "=mouseDown," . event.x . "," . event.y . "," . event.button . "`n"
                }
                else if (event.type = "mouseUp") {
                    stateContent .= macroName . "=mouseUp," . event.x . "," . event.y . "," . event.button . "`n"
                }
            }
        }
    }
    
    for macroName, thumbnailPath in buttonThumbnails {
        if (thumbnailPath != "" && FileExist(thumbnailPath)) {
            stateContent .= macroName . "=thumbnail," . thumbnailPath . "`n"
        }
    }
    
    if FileExist(stateFile)
        FileDelete(stateFile)
    if (stateContent != "")
        FileAppend(stateContent, stateFile)
    
    return macroCount
}

LoadMacroState() {
    global macroEvents, buttonThumbnails, configFile
    
    stateFile := StrReplace(configFile, ".ini", "_simple.txt")
    
    if !FileExist(stateFile)
        return 0
    
    macroEvents := Map()
    buttonThumbnails := Map()
    
    content := FileRead(stateFile)
    lines := StrSplit(content, "`n")
    
    macroCount := 0
    for line in lines {
        line := Trim(line)
        if (line = "")
            continue
            
        if (InStr(line, "=")) {
            equalPos := InStr(line, "=")
            macroName := SubStr(line, 1, equalPos - 1)
            data := SubStr(line, equalPos + 1)
            parts := StrSplit(data, ",")
            
            if (parts.Length >= 1) {
                event := {}
                
                if (parts[1] = "boundingBox" && parts.Length >= 5) {
                    event := {
                        type: "boundingBox",
                        left: Integer(parts[2]),
                        top: Integer(parts[3]),
                        right: Integer(parts[4]),
                        bottom: Integer(parts[5])
                    }
                }
                else if (parts[1] = "jsonAnnotation" && parts.Length >= 4) {
                    event := {
                        type: "jsonAnnotation",
                        mode: parts[2],
                        categoryId: Integer(parts[3]),
                        severity: parts[4],
                        annotation: BuildJsonAnnotation(parts[2], Integer(parts[3]), parts[4])
                    }
                }
                else if (parts[1] = "keyDown" && parts.Length >= 2) {
                    event := {
                        type: "keyDown",
                        key: parts[2]
                    }
                }
                else if (parts[1] = "keyUp" && parts.Length >= 2) {
                    event := {
                        type: "keyUp",
                        key: parts[2]
                    }
                }
                else if (parts[1] = "mouseDown" && parts.Length >= 4) {
                    event := {
                        type: "mouseDown",
                        x: Integer(parts[2]),
                        y: Integer(parts[3]),
                        button: parts[4]
                    }
                }
                else if (parts[1] = "mouseUp" && parts.Length >= 4) {
                    event := {
                        type: "mouseUp",
                        x: Integer(parts[2]),
                        y: Integer(parts[3]),
                        button: parts[4]
                    }
                }
                else if (parts[1] = "thumbnail" && parts.Length >= 2) {
                    thumbnailPath := parts[2]
                    if (FileExist(thumbnailPath)) {
                        buttonThumbnails[macroName] := thumbnailPath
                    }
                    continue
                }
                
                if (event.HasOwnProp("type")) {
                    if (!macroEvents.Has(macroName)) {
                        macroEvents[macroName] := []
                        macroCount++
                    }
                    macroEvents[macroName].Push(event)
                }
            }
        }
    }
    
    return macroCount
}

; ===== TIMING CONFIGURATION FUNCTIONS =====
UpdateTimingFromEdit(variableName, editControl) {
    global boxDrawDelay, mouseClickDelay, mouseDragDelay, mouseReleaseDelay, betweenBoxDelay, keyPressDelay, focusDelay
    
    try {
        value := Integer(editControl.Text)
        if (value < 0 || value > 5000) {
            UpdateStatus("⚠️ Timing value must be between 0-5000ms")
            return
        }
        
        switch variableName {
            case "boxDrawDelay":
                boxDrawDelay := value
            case "mouseClickDelay":
                mouseClickDelay := value
            case "mouseDragDelay":
                mouseDragDelay := value
            case "mouseReleaseDelay":
                mouseReleaseDelay := value
            case "betweenBoxDelay":
                betweenBoxDelay := value
            case "keyPressDelay":
                keyPressDelay := value
            case "focusDelay":
                focusDelay := value
        }
        
        ; Save configuration
        SaveConfig()
        UpdateStatus("⚡ Updated " . variableName . " to " . value . "ms")
        
    } catch {
        UpdateStatus("⚠️ Invalid timing value")
    }
}

ApplyTimingPreset(preset, settingsGui) {
    global boxDrawDelay, mouseClickDelay, mouseDragDelay, mouseReleaseDelay, betweenBoxDelay, keyPressDelay, focusDelay
    
    switch preset {
        case "fast":
            boxDrawDelay := 35
            mouseClickDelay := 45
            mouseDragDelay := 50
            mouseReleaseDelay := 50
            betweenBoxDelay := 100
            keyPressDelay := 10
            focusDelay := 60
            
        case "default":
            boxDrawDelay := 50
            mouseClickDelay := 60
            mouseDragDelay := 65
            mouseReleaseDelay := 65
            betweenBoxDelay := 150
            keyPressDelay := 12
            focusDelay := 80
            
        case "safe":
            boxDrawDelay := 75
            mouseClickDelay := 90
            mouseDragDelay := 95
            mouseReleaseDelay := 95
            betweenBoxDelay := 200
            keyPressDelay := 20
            focusDelay := 120
            
        case "slow":
            boxDrawDelay := 100
            mouseClickDelay := 120
            mouseDragDelay := 125
            mouseReleaseDelay := 125
            betweenBoxDelay := 300
            keyPressDelay := 30
            focusDelay := 180
    }
    
    ; Save configuration
    SaveConfig()
    
    ; Close and reopen settings to refresh values
    settingsGui.Destroy()
    ShowSettings()
    
    UpdateStatus("🎚️ Applied " . StrTitle(preset) . " timing preset")
}

ClearAllMacros(parentGui := 0) {
    global macroEvents, buttonNames, totalLayers
    
    result := MsgBox("Clear ALL macros from ALL layers?`n`nThis will permanently delete all recorded macros but preserve stats.", "Confirm Clear All", "YesNo Icon!")
    
    if (result = "Yes") {
        ; Clear all macros
        macroEvents := Map()
        
        ; Save the cleared state
        SaveConfig()
        
        ; Update all button appearances
        for buttonName in buttonNames {
            UpdateButtonAppearance(buttonName)
        }
        
        UpdateStatus("🗑️ All macros cleared from all layers")
        
        if (parentGui) {
            parentGui.Destroy()
        }
    }
}

ResetStatsFromSettings(parentGui) {
    global macroExecutionLog
    
    result := MsgBox("Reset all statistics data?`n`nThis will clear execution logs but preserve macros.", "Confirm Stats Reset", "YesNo Icon!")
    
    if (result = "Yes") {
        ; Export current data before clearing
        ExportAllHistoricalData()
        
        ; Clear stats
        macroExecutionLog := []
        SaveExecutionData()
        
        UpdateStatus("📊 Statistics reset - Historical data preserved")
        
        if (parentGui) {
            parentGui.Destroy()
        }
    }
}

; ===== CONFIGURATION SAVE/LOAD SYSTEM =====
SaveConfig() {
    global currentLayer, macroEvents, configFile, totalLayers, buttonNames, buttonCustomLabels, annotationMode, workDir
    global userCanvasLeft, userCanvasTop, userCanvasRight, userCanvasBottom, isCanvasCalibrated
    global wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom, isWideCanvasCalibrated
    global narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom, isNarrowCanvasCalibrated
    
    try {
        ; Ensure directories exist
        if !DirExist(workDir) {
            DirCreate(workDir)
        }
        
        ; Clear existing config file to start fresh
        if FileExist(configFile) {
            FileDelete(configFile)
        }
        
        ; Ensure parent directory exists for config file
        SplitPath(configFile, , &configDir)
        if !DirExist(configDir) {
            DirCreate(configDir)
        }
        
        ; Create manual INI content to avoid encoding issues
        configContent := "[General]`n"
        configContent .= "CurrentLayer=" . currentLayer . "`n"
        configContent .= "AnnotationMode=" . annotationMode . "`n"
        configContent .= "LastSaved=" . A_Now . "`n`n"
        
        ; Add canvas configuration section
        configContent .= "[Canvas]`n"
        configContent .= "UserCanvasLeft=" . userCanvasLeft . "`n"
        configContent .= "UserCanvasTop=" . userCanvasTop . "`n"
        configContent .= "UserCanvasRight=" . userCanvasRight . "`n"
        configContent .= "UserCanvasBottom=" . userCanvasBottom . "`n"
        configContent .= "IsCanvasCalibrated=" . (isCanvasCalibrated ? "1" : "0") . "`n"
        configContent .= "WideCanvasLeft=" . wideCanvasLeft . "`n"
        configContent .= "WideCanvasTop=" . wideCanvasTop . "`n"
        configContent .= "WideCanvasRight=" . wideCanvasRight . "`n"
        configContent .= "WideCanvasBottom=" . wideCanvasBottom . "`n"
        configContent .= "IsWideCanvasCalibrated=" . (isWideCanvasCalibrated ? "1" : "0") . "`n"
        configContent .= "NarrowCanvasLeft=" . narrowCanvasLeft . "`n"
        configContent .= "NarrowCanvasTop=" . narrowCanvasTop . "`n"
        configContent .= "NarrowCanvasRight=" . narrowCanvasRight . "`n"
        configContent .= "NarrowCanvasBottom=" . narrowCanvasBottom . "`n"
        configContent .= "IsNarrowCanvasCalibrated=" . (isNarrowCanvasCalibrated ? "1" : "0") . "`n`n"
        
        ; Add labels section
        if (buttonCustomLabels.Count > 0) {
            configContent .= "[Labels]`n"
            for buttonName in buttonNames {
                if (buttonCustomLabels.Has(buttonName) && buttonCustomLabels[buttonName] != buttonName) {
                    configContent .= buttonName . "=" . buttonCustomLabels[buttonName] . "`n"
                }
            }
            configContent .= "`n"
        }
        
        ; Add macros section
        configContent .= "[Macros]`n"
        savedMacros := 0
        
        ; Build macro content manually to avoid encoding issues
        Loop totalLayers {
            layer := A_Index
            for buttonName in buttonNames {
                layerMacroName := "L" . layer . "_" . buttonName
                if (macroEvents.Has(layerMacroName) && macroEvents[layerMacroName].Length > 0) {
                    eventsStr := ""
                    eventCount := 0
                    for event in macroEvents[layerMacroName] {
                        eventCount++
                        if (event.type = "jsonAnnotation") {
                            if (eventCount > 1) eventsStr .= "|"
                            eventsStr .= event.type . ",mode=" . event.mode . ",cat=" . event.categoryId . ",sev=" . event.severity
                        } else if (event.type = "boundingBox") {
                            degradationType := event.HasOwnProp("degradationType") ? event.degradationType : 1
                            degradationName := event.HasOwnProp("degradationName") ? event.degradationName : "smudge"
                            isTagged := event.HasOwnProp("isTagged") ? event.isTagged : false
                            if (eventCount > 1) eventsStr .= "|"
                            eventsStr .= event.type . "," . event.left . "," . event.top . "," . event.right . "," . event.bottom . ",deg=" . degradationType . ",name=" . degradationName . ",tagged=" . isTagged
                        } else {
                            if (eventCount > 1) eventsStr .= "|"
                            eventsStr .= event.type . "," . (event.HasOwnProp("x") ? event.x : "") . "," . (event.HasOwnProp("y") ? event.y : "")
                        }
                    }
                    if (eventsStr != "") {
                        ; Add to manual content instead of using IniWrite  
                        configContent .= layerMacroName . "=" . eventsStr . "`n"
                        savedMacros++
                    }
                }
            }
        }
        
        ; Add debug section
        configContent .= "`n[Debug]`n"
        Loop totalLayers {
            layer := A_Index
            for buttonName in buttonNames {
                layerMacroName := "L" . layer . "_" . buttonName
                if (macroEvents.Has(layerMacroName) && macroEvents[layerMacroName].Length > 0) {
                    configContent .= layerMacroName . "_Count=" . macroEvents[layerMacroName].Length . "`n"
                }
            }
        }
        
        ; Write the entire file at once with UTF-8 encoding
        FileAppend(configContent, configFile, "UTF-8")
        
        ; Add detailed debug logging
        if (savedMacros > 0) {
            UpdateStatus("💾 Saved " . savedMacros . " macros to config file")
        }
        
    } catch Error as e {
        UpdateStatus("⚠️ Save config failed: " . e.Message . " (File: " . configFile . ")")
    }
}

LoadConfig() {
    global currentLayer, macroEvents, configFile, totalLayers, buttonNames, buttonCustomLabels, annotationMode, modeToggleBtn
    global userCanvasLeft, userCanvasTop, userCanvasRight, userCanvasBottom, isCanvasCalibrated
    global wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom, isWideCanvasCalibrated
    global narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom, isNarrowCanvasCalibrated
    
    if !FileExist(configFile) {
        UpdateStatus("📚 No config file found - starting fresh")
        return
    }
    
    try {
        ; Read the entire file with proper encoding
        configContent := FileRead(configFile, "UTF-8")
        
        ; Parse manually to avoid encoding issues
        lines := StrSplit(configContent, "`n", "`r")
        currentSection := ""
        macrosLoaded := 0
        
        ; Clear existing macros
        macroEvents := Map()
        
        for line in lines {
            line := Trim(line)
            if (line = "")
                continue
                
            ; Check for section headers
            if (RegExMatch(line, "^\[(.+)\]$", &match)) {
                currentSection := match[1]
                continue
            }
            
            ; Parse key=value pairs
            if (InStr(line, "=")) {
                equalPos := InStr(line, "=")
                key := Trim(SubStr(line, 1, equalPos - 1))
                value := Trim(SubStr(line, equalPos + 1))
                
                if (currentSection = "General") {
                    if (key = "CurrentLayer") {
                        currentLayer := Integer(value)
                    } else if (key = "AnnotationMode") {
                        annotationMode := value
                    }
                } else if (currentSection = "Canvas") {
                    if (key = "UserCanvasLeft") {
                        userCanvasLeft := Integer(value)
                    } else if (key = "UserCanvasTop") {
                        userCanvasTop := Integer(value)
                    } else if (key = "UserCanvasRight") {
                        userCanvasRight := Integer(value)
                    } else if (key = "UserCanvasBottom") {
                        userCanvasBottom := Integer(value)
                    } else if (key = "IsCanvasCalibrated") {
                        isCanvasCalibrated := (value = "1")
                    } else if (key = "WideCanvasLeft") {
                        wideCanvasLeft := Integer(value)
                    } else if (key = "WideCanvasTop") {
                        wideCanvasTop := Integer(value)
                    } else if (key = "WideCanvasRight") {
                        wideCanvasRight := Integer(value)
                    } else if (key = "WideCanvasBottom") {
                        wideCanvasBottom := Integer(value)
                    } else if (key = "IsWideCanvasCalibrated") {
                        isWideCanvasCalibrated := (value = "1")
                    } else if (key = "NarrowCanvasLeft") {
                        narrowCanvasLeft := Integer(value)
                    } else if (key = "NarrowCanvasTop") {
                        narrowCanvasTop := Integer(value)
                    } else if (key = "NarrowCanvasRight") {
                        narrowCanvasRight := Integer(value)
                    } else if (key = "NarrowCanvasBottom") {
                        narrowCanvasBottom := Integer(value)
                    } else if (key = "IsNarrowCanvasCalibrated") {
                        isNarrowCanvasCalibrated := (value = "1")
                    }
                } else if (currentSection = "Labels") {
                    if (buttonCustomLabels.Has(key)) {
                        buttonCustomLabels[key] := value
                    }
                } else if (currentSection = "Macros" && InStr(key, "L") = 1) {
                    ; Parse macro data
                    if (value != "") {
                        macroEvents[key] := []
                        loadedEvents := 0
                        
                        ; Split by | separator (our new format)
                        eventLines := StrSplit(value, "|")
                        
                        for eventLine in eventLines {
                            if (eventLine = "" || Trim(eventLine) = "")
                                continue
                            parts := StrSplit(eventLine, ",")
                            
                            if (parts.Length = 0)
                                continue
                                
                            if (parts[1] = "jsonAnnotation") {
                                mode := StrReplace(parts[2], "mode=", "")
                                catId := Integer(StrReplace(parts[3], "cat=", ""))
                                sev := StrReplace(parts[4], "sev=", "")
                                macroEvents[key].Push({
                                    type: "jsonAnnotation",
                                    annotation: BuildJsonAnnotation(mode, catId, sev),
                                    mode: mode,
                                    categoryId: catId,
                                    severity: sev
                                })
                                loadedEvents++
                            } else if (parts[1] = "boundingBox" && parts.Length >= 5) {
                                event := {
                                    type: "boundingBox",
                                    left: Integer(parts[2]),
                                    top: Integer(parts[3]),
                                    right: Integer(parts[4]),
                                    bottom: Integer(parts[5])
                                }
                                
                                ; Load degradation data if present
                                if (parts.Length >= 6) {
                                    Loop (parts.Length - 5) {
                                        i := A_Index + 5
                                        if (i <= parts.Length) {
                                            part := parts[i]
                                            if (InStr(part, "deg=")) {
                                                event.degradationType := Integer(StrReplace(part, "deg=", ""))
                                            } else if (InStr(part, "name=")) {
                                                event.degradationName := StrReplace(part, "name=", "")
                                            } else if (InStr(part, "tagged=")) {
                                                event.isTagged := (StrReplace(part, "tagged=", "") = "true")
                                            }
                                        }
                                    }
                                }
                                
                                ; Ensure degradation defaults if not loaded
                                if (!event.HasOwnProp("degradationType"))
                                    event.degradationType := 1
                                if (!event.HasOwnProp("degradationName"))
                                    event.degradationName := "smudge"
                                if (!event.HasOwnProp("isTagged"))
                                    event.isTagged := false
                                
                                macroEvents[key].Push(event)
                                loadedEvents++
                            } else {
                                event := {type: parts[1]}
                                if (parts.Length > 1 && parts[2] != "") event.x := Integer(parts[2])
                                if (parts.Length > 2 && parts[3] != "") event.y := Integer(parts[3])
                                macroEvents[key].Push(event)
                                loadedEvents++
                            }
                        }
                        
                        if (loadedEvents > 0) {
                            macrosLoaded++
                        }
                    }
                }
            }
        }
        
        ; Update mode toggle button to match loaded setting
        if (modeToggleBtn) {
            if (annotationMode = "Narrow") {
                modeToggleBtn.Text := "📱 Narrow"
                modeToggleBtn.Opt("+Background0xFF8C00")
            } else {
                modeToggleBtn.Text := "🔦 Wide"
                modeToggleBtn.Opt("+Background0x4169E1")
            }
            modeToggleBtn.SetFont(, "cWhite")
            
            ; Force redraw the button
            modeToggleBtn.Redraw()
        }
        
        ; Update UI to reflect loaded configuration
        SwitchLayer("")
        
        ; Refresh all button appearances to ensure JSON annotations display correctly
        RefreshAllButtonAppearances()
        
        if (macrosLoaded > 0) {
            UpdateStatus("📚 Configuration loaded: " . macrosLoaded . " macros restored")
        } else {
            UpdateStatus("📚 Configuration loaded: No macros found")
        }
    } catch Error as e {
        UpdateStatus("⚠️ Load config failed: " . e.Message)
    }
}

; ===== QUICK SAVE/LOAD SLOTS =====
SaveToSlot(slotNumber) {
    global workDir, configFile
    
    try {
        SaveConfig()
        SaveExecutionData()
        
        slotDir := workDir . "\slots\slot_" . slotNumber
        if !DirExist(slotDir) {
            DirCreate(slotDir)
        }
        
        ; Copy current config to slot
        FileCopy(configFile, slotDir . "\config.ini", true)
        
        logFile := workDir . "\macro_execution_log.json"
        if FileExist(logFile) {
            FileCopy(logFile, slotDir . "\macro_execution_log.json", true)
        }
        
        ; Save slot info
        slotInfo := "Slot " . slotNumber . " - Saved: " . FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        FileAppend(slotInfo, slotDir . "\slot_info.txt")
        
        UpdateStatus("💾 Saved to slot " . slotNumber)
        
    } catch Error as e {
        UpdateStatus("⚠️ Save to slot failed: " . e.Message)
    }
}

LoadFromSlot(slotNumber) {
    global workDir, configFile
    
    try {
        slotDir := workDir . "\slots\slot_" . slotNumber
        
        if (!DirExist(slotDir) || !FileExist(slotDir . "\config.ini")) {
            UpdateStatus("⚠️ Slot " . slotNumber . " is empty")
            return false
        }
        
        ; Copy slot config to current
        FileCopy(slotDir . "\config.ini", configFile, true)
        
        logFile := workDir . "\macro_execution_log.json"
        if FileExist(slotDir . "\macro_execution_log.json") {
            FileCopy(slotDir . "\macro_execution_log.json", logFile, true)
        }
        
        LoadConfig()
        LoadStatsData()
        
        ; Refresh UI
        global buttonNames
        for buttonName in buttonNames {
            UpdateButtonAppearance(buttonName)
        }
        SwitchLayer("")
        
        UpdateStatus("📂 Loaded from slot " . slotNumber)
        return true
        
    } catch Error as e {
        UpdateStatus("⚠️ Load from slot failed: " . e.Message)
        return false
    }
}

; ===== PLACEHOLDER EXPORT/IMPORT FUNCTIONS =====
ExportConfiguration() {
    UpdateStatus("📤 Export configuration feature - coming soon")
    MsgBox("Export configuration feature is available in the full modular version.", "Feature Notice", "Icon!")
}

ImportConfiguration() {
    UpdateStatus("📥 Import configuration feature - coming soon") 
    MsgBox("Import configuration feature is available in the full modular version.", "Feature Notice", "Icon!")
}

CreateMacroPack() {
    UpdateStatus("📦 Create macro pack feature - coming soon")
    MsgBox("Macro pack creation is available in the full modular version.", "Feature Notice", "Icon!")
}

BrowseMacroPacks() {
    UpdateStatus("📚 Browse macro packs feature - coming soon")
    MsgBox("Macro pack browsing is available in the full modular version.", "Feature Notice", "Icon!")
}

ImportNewMacroPack() {
    UpdateStatus("📥 Import macro pack feature - coming soon")
    MsgBox("Macro pack import is available in the full modular version.", "Feature Notice", "Icon!")
}

; ===== ANALYSIS FUNCTIONS =====
AnalyzeRecordedMacro(macroKey) {
    global macroEvents
    
    if (!macroEvents.Has(macroKey))
        return
    
    local events := macroEvents[macroKey]
    local boundingBoxCount := 0
    
    local degradationAnalysis := AnalyzeDegradationPattern(events)
    
    for event in events {
        if (event.type = "boundingBox") {
            boundingBoxCount++
        }
    }
    
    if (boundingBoxCount > 0) {
        local statusMsg := "📦 Recorded " . boundingBoxCount . " boxes"
        
        if (degradationAnalysis.summary != "") {
            statusMsg .= " | " . degradationAnalysis.summary
        }
        
        UpdateStatus(statusMsg)
    }
}

AnalyzeDegradationPattern(events) {
    global degradationTypes
    
    local boxes := []
    local keyPresses := []
    
    for event in events {
        if (event.type = "boundingBox") {
            boxes.Push({
                index: boxes.Length + 1,
                time: event.time,
                event: event,
                degradationType: 1,
                assignedBy: "default"
            })
        } else if (event.type = "keyDown" && IsNumberKey(event.key)) {
            local keyNum := GetNumberFromKey(event.key)
            if (keyNum >= 1 && keyNum <= 9) {
                keyPresses.Push({
                    time: event.time,
                    degradationType: keyNum,
                    key: event.key
                })
            }
        }
    }
    
    local currentDegradationType := 1
    local degradationCounts := Map()
    
    for id, typeName in degradationTypes {
        degradationCounts[id] := 0
    }
    
    for boxIndex, box in boxes {
        local nextBoxTime := (boxIndex < boxes.Length) ? boxes[boxIndex + 1].time : 999999999
        
        local closestKeyPress := ""
        local closestTime := 999999999
        
        for keyPress in keyPresses {
            if (keyPress.time > box.time && keyPress.time < nextBoxTime && keyPress.time < closestTime) {
                closestKeyPress := keyPress
                closestTime := keyPress.time
            }
        }
        
        if (closestKeyPress != "") {
            currentDegradationType := closestKeyPress.degradationType
            box.degradationType := currentDegradationType
            box.assignedBy := "user_selection"
        } else {
            box.degradationType := currentDegradationType
            box.assignedBy := "auto_default"
        }
        
        degradationCounts[box.degradationType]++
        
        box.event.degradationType := box.degradationType
        box.event.degradationName := degradationTypes[box.degradationType]
        box.event.assignedBy := box.assignedBy
    }
    
    local totalBoxes := 0
    local summary := []
    
    for id, count in degradationCounts {
        if (count > 0) {
            totalBoxes += count
            local typeName := StrTitle(degradationTypes[id])
            summary.Push(count . "x" . typeName)
        }
    }
    
    return {
        totalBoxes: totalBoxes,
        summary: summary.Length > 0 ? JoinArray(summary, ", ") : "",
        counts: degradationCounts,
        boxes: boxes
    }
}

IsNumberKey(keyName) {
    return RegExMatch(keyName, "^[1-9]$")
}

GetNumberFromKey(keyName) {
    if (RegExMatch(keyName, "^([1-9])$", &match)) {
        return Integer(match[1])
    }
    return 0
}

JoinArray(array, delimiter) {
    local result := ""
    for index, item in array {
        if (index > 1)
            result .= delimiter
        result .= item
    }
    return result
}

; ===== UTILITY FUNCTIONS =====
StrTitle(str) {
    str := StrReplace(str, "_", " ")
    return StrUpper(SubStr(str, 1, 1)) . SubStr(str, 2)
}

; ===== CSV STATS FUNCTIONS =====
InitializeCSVFile() {
    global masterStatsCSV
    
    try {
        ; Create data directory if doesn't exist
        SplitPath(masterStatsCSV,, &dataDir)
        if (!DirExist(dataDir)) {
            DirCreate(dataDir)
        }
        
        ; Create CSV with header if file doesn't exist
        if (!FileExist(masterStatsCSV)) {
            header := "timestamp,session_id,username,execution_type,button_key,layer,execution_time_ms,bbox_count,degradation_assignments,severity_level,canvas_mode,session_active_time_ms,break_mode_active`n"
            FileAppend(header, masterStatsCSV, "UTF-8")
        }
    } catch as e {
        ; Handle error gracefully without breaking the app
        ; Could add logging here if needed
    }
}

AppendToCSV(timestamp, execution_type, button_key, layer, execution_time_ms, bbox_count, degradation_assignments, severity_level, canvas_mode) {
    global masterStatsCSV, sessionId, currentUsername, breakModeActive, totalActiveTime
    
    try {
        ; Calculate session_active_time_ms using existing totalTime variable
        session_active_time_ms := totalActiveTime
        
        ; Build CSV row
        csvRow := timestamp . ","
                . sessionId . ","
                . currentUsername . ","
                . execution_type . ","
                . button_key . ","
                . layer . ","
                . execution_time_ms . ","
                . bbox_count . ","
                . degradation_assignments . ","
                . severity_level . ","
                . canvas_mode . ","
                . session_active_time_ms . ","
                . breakModeActive . "`n"
        
        ; Append to CSV file
        FileAppend(csvRow, masterStatsCSV, "UTF-8")
    } catch as e {
        ; Handle file access errors gracefully
        ; Could add error logging if needed
    }
}

RecordExecutionStats(macroKey, executionStartTime, executionType, events, analysisRecord := "") {
    global breakModeActive, recording, playback, currentLayer, canvasType
    
    ; Skip if breakModeActive is true (don't track during break) - return early
    if (breakModeActive) {
        return
    }
    
    ; Skip if currently recording or playback is active (avoid double-tracking)
    if (recording || playback) {
        return
    }
    
    ; Calculate execution_time_ms
    execution_time_ms := A_TickCount - executionStartTime
    
    ; Get current layer from existing layer variable
    layer := currentLayer
    
    ; Get canvas_mode from existing wide/narrow toggle variable
    canvas_mode := canvasType
    
    ; Get current timestamp
    timestamp := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    
    ; Initialize default values
    bbox_count := 0
    degradation_assignments := ""
    severity_level := ""
    
    ; Process based on execution type
    if (executionType = "macro") {
        ; Get data from analysis record if available
        if (IsObject(analysisRecord)) {
            bbox_count := analysisRecord.boundingBoxCount
            degradation_assignments := analysisRecord.HasOwnProp("degradationAssignments") ? analysisRecord.degradationAssignments : ""
        } else {
            ; Fallback: Count bounding boxes from events
            for event in events {
                if (event.type = "drag" || event.type = "bbox" || event.type = "boundingBox") {
                    bbox_count++
                }
            }
            degradation_assignments := "smudge" ; Default fallback
        }
    } else if (executionType = "json_profile") {
        ; For JSON profiles: get data from analysis record
        if (IsObject(analysisRecord)) {
            bbox_count := 0
            degradation_assignments := ""
            severity_level := analysisRecord.HasOwnProp("severity") ? analysisRecord.severity : "medium"
        } else {
            bbox_count := 0
            degradation_assignments := ""
            severity_level := "medium" ; Default fallback
        }
    }
    
    ; Call AppendToCSV with all data
    AppendToCSV(timestamp, executionType, macroKey, layer, execution_time_ms, bbox_count, degradation_assignments, severity_level, canvas_mode)
}

ReadStatsFromCSV() {
    global masterStatsCSV, sessionId, totalActiveTime
    
    stats := Map()
    stats["total_executions"] := 0
    stats["total_boxes"] := 0
    stats["boxes_per_hour"] := 0
    stats["executions_per_hour"] := 0
    stats["average_execution_time"] := 0
    stats["most_used_button"] := ""
    stats["most_active_layer"] := ""
    stats["degradation_breakdown"] := Map()
    
    try {
        if (!FileExist(masterStatsCSV)) {
            return stats
        }
        
        csvContent := FileRead(masterStatsCSV, "UTF-8")
        lines := StrSplit(csvContent, "`n")
        
        if (lines.Length <= 1) {
            return stats ; No data rows
        }
        
        ; Process data rows (skip header)
        executionTimes := []
        buttonCount := Map()
        layerCount := Map()
        degradationCount := Map()
        totalBoxes := 0
        sessionActiveTime := 0
        
        Loop lines.Length - 1 {
            lineIndex := A_Index + 1 ; Skip header
            if (lineIndex > lines.Length || Trim(lines[lineIndex]) = "") {
                continue
            }
            
            fields := StrSplit(lines[lineIndex], ",")
            if (fields.Length < 13) {
                continue ; Skip malformed rows
            }
            
            ; Only process current session data
            if (fields[2] = sessionId) {
                stats["total_executions"]++
                
                ; Parse fields
                execution_time := Integer(fields[7])
                bbox_count := Integer(fields[8])
                degradation_assignments := fields[9]
                button_key := fields[5]
                layer := Integer(fields[6])
                session_time := Integer(fields[12])
                
                ; Accumulate data
                executionTimes.Push(execution_time)
                totalBoxes += bbox_count
                sessionActiveTime := session_time ; Latest session time
                
                ; Count buttons
                if (!buttonCount.Has(button_key)) {
                    buttonCount[button_key] := 0
                }
                buttonCount[button_key]++
                
                ; Count layers
                if (!layerCount.Has(layer)) {
                    layerCount[layer] := 0
                }
                layerCount[layer]++
                
                ; Process degradation assignments
                if (degradation_assignments != "" && degradation_assignments != "\"\"") {
                    assignments := StrSplit(degradation_assignments, ",")
                    for assignment in assignments {
                        assignment := Trim(assignment)
                        if (assignment != "") {
                            if (!degradationCount.Has(assignment)) {
                                degradationCount[assignment] := 0
                            }
                            degradationCount[assignment]++
                        }
                    }
                }
            }
        }
        
        ; Calculate final stats
        stats["total_boxes"] := totalBoxes
        
        ; Calculate rates (boxes and executions per hour)
        if (sessionActiveTime > 0) {
            hoursActive := sessionActiveTime / 3600000 ; Convert ms to hours
            stats["boxes_per_hour"] := Round(totalBoxes / hoursActive, 1)
            stats["executions_per_hour"] := Round(stats["total_executions"] / hoursActive, 1)
        }
        
        ; Calculate average execution time
        if (executionTimes.Length > 0) {
            totalTime := 0
            for time in executionTimes {
                totalTime += time
            }
            stats["average_execution_time"] := Round(totalTime / executionTimes.Length, 1)
        }
        
        ; Find most used button
        maxCount := 0
        mostButton := ""
        for button, count in buttonCount {
            if (count > maxCount) {
                maxCount := count
                mostButton := button
            }
        }
        stats["most_used_button"] := mostButton
        
        ; Find most active layer
        maxCount := 0
        mostLayer := ""
        for layer, count in layerCount {
            if (count > maxCount) {
                maxCount := count
                mostLayer := "L" . layer
            }
        }
        stats["most_active_layer"] := mostLayer
        
        ; Store degradation breakdown
        stats["degradation_breakdown"] := degradationCount
        
    } catch as e {
        ; Return empty stats on error
    }
    
    return stats
}

UpdateActiveTime() {
    global breakMode, totalActiveTime, lastActiveTime
    
    if (!breakMode && lastActiveTime > 0) {
        totalActiveTime += A_TickCount - lastActiveTime
        lastActiveTime := A_TickCount
    }
}

AutoSave() {
    global breakMode, recording
    
    if (!recording && !breakMode) {
        SaveConfig()
        SaveExecutionData()
    }
}

CleanupAndExit() {
    global recording, playback, awaitingAssignment
    
    try {
        UpdateActiveTime()
        
        if (recording) {
            recording := false
            UpdateStatus("🛑 Recording stopped for exit")
        }
        
        if (playback) {
            playback := false
            UpdateStatus("🛑 Playback stopped for exit")
        }
        
        if (awaitingAssignment) {
            awaitingAssignment := false
            SetTimer(CheckForAssignment, 0)
        }
        
        savedMacros := SaveMacroState()
        SaveExecutionData()
        UpdateStatus("💾 Saved " . savedMacros . " macros")
        
        SafeUninstallMouseHook()
        SafeUninstallKeyboardHook()
        
        SetTimer(UpdateActiveTime, 0)
        SetTimer(AutoSave, 0)
        
        Send("{LButton Up}{RButton Up}{MButton Up}")
        Send("{Shift Up}{Ctrl Up}{Alt Up}{Win Up}")
        
        SetMouseDelay(10)
        SetKeyDelay(10)
        
        UpdateStatus("💾 All data saved - Application closing")
        
    } catch Error as e {
        try {
            SaveConfig()
            SaveExecutionData()
        } catch {
            SafeUninstallMouseHook()
            SafeUninstallKeyboardHook()
        }
    }
}

ShowWelcomeMessage() {
    UpdateStatus("📦 Draw boxes, press 1-9 to tag | F9: Record | All systems ready")
}

EmergencyStop() {
    global recording, playback, awaitingAssignment, mainGui
    
    UpdateStatus("🚨 EMERGENCY STOP")
    
    recording := false
    playback := false
    awaitingAssignment := false
    
    try {
        SafeUninstallMouseHook()
        SafeUninstallKeyboardHook()
        SetTimer(CheckForAssignment, 0)
        SetTimer(UpdateActiveTime, 0)
    } catch {
    }
    
    if (mainGui && mainGui.HasProp("btnRecord")) {
        try {
            mainGui.btnRecord.Text := "🎥 Record"
            mainGui.btnRecord.Opt("-Background +BackgroundDefault")
        } catch {
        }
    }
    
    try {
        Send("{LButton Up}{RButton Up}{MButton Up}")
        Send("{Shift Up}{Ctrl Up}{Alt Up}{Win Up}")
        Send("{Esc}")
    } catch {
    }
    
    SetMouseDelay(10)
    SetKeyDelay(10)
    
    UpdateStatus("🚨 Emergency Stop complete")
}

SafeExit() {
    UpdateStatus("💾 Saving and exiting...")
    CleanupAndExit()
    Sleep(500)
    ExitApp(0)
}

SubmitCurrentImage() {
    global focusDelay
    browserFocused := false
    
    if (WinExist("ahk_exe chrome.exe")) {
        WinActivate("ahk_exe chrome.exe")
        browserFocused := true
    } else if (WinExist("ahk_exe firefox.exe")) {
        WinActivate("ahk_exe firefox.exe")
        browserFocused := true
    } else if (WinExist("ahk_exe msedge.exe")) {
        WinActivate("ahk_exe msedge.exe")
        browserFocused := true
    }
    
    if (browserFocused) {
        Sleep(focusDelay)
        Send("+{Enter}")
        UpdateStatus("📤 Submitted")
    } else {
        UpdateStatus("⚠️ No browser")
    }
}

ShowRecordingDebug() {
    global recording, currentMacro, macroEvents, currentLayer, buttonNames
    
    debugInfo := "=== F9 DEBUG INFO ===`n"
    debugInfo .= "Recording: " . (recording ? "ACTIVE" : "INACTIVE") . "`n"
    debugInfo .= "Current Macro: " . currentMacro . "`n"
    debugInfo .= "Layer: " . currentLayer . "`n`n"
    
    totalMacros := 0
    for layer in 1..8 {
        for buttonName in buttonNames {
            layerMacroName := "L" . layer . "_" . buttonName
            if (macroEvents.Has(layerMacroName) && macroEvents[layerMacroName].Length > 0) {
                totalMacros++
            }
        }
    }
    
    debugInfo .= "Total Macros: " . totalMacros . "`n"
    
    if (macroEvents.Has(currentMacro) && currentMacro != "") {
        debugInfo .= "Current Recording Events: " . macroEvents[currentMacro].Length . "`n"
    }
    
    MsgBox(debugInfo, "F9 Debug", "Icon!")
}

TestSaveLoad() {
    global macroEvents, buttonNames
    
    ; Count current macros
    currentMacros := 0
    for layer in 1..8 {
        for buttonName in buttonNames {
            layerMacroName := "L" . layer . "_" . buttonName
            if (macroEvents.Has(layerMacroName) && macroEvents[layerMacroName].Length > 0) {
                currentMacros++
            }
        }
    }
    
    UpdateStatus("🔬 Testing: " . currentMacros . " macros before save")
    
    ; Force save
    SaveConfig()
    
    ; Clear in-memory macros
    macroEventsBackup := Map()
    for layer in 1..8 {
        for buttonName in buttonNames {
            layerMacroName := "L" . layer . "_" . buttonName
            if (macroEvents.Has(layerMacroName)) {
                macroEventsBackup[layerMacroName] := macroEvents[layerMacroName]
                macroEvents.Delete(layerMacroName)
            }
        }
    }
    
    ; Update UI to show cleared state
    for buttonName in buttonNames {
        UpdateButtonAppearance(buttonName)
    }
    
    UpdateStatus("🗑️ Cleared macros from memory")
    Sleep(1000)
    
    ; Force load
    LoadConfig()
    
    ; Count loaded macros
    loadedMacros := 0
    for layer in 1..8 {
        for buttonName in buttonNames {
            layerMacroName := "L" . layer . "_" . buttonName
            if (macroEvents.Has(layerMacroName) && macroEvents[layerMacroName].Length > 0) {
                loadedMacros++
            }
        }
    }
    
    ; Update UI to show loaded state
    for buttonName in buttonNames {
        UpdateButtonAppearance(buttonName)
    }
    
    UpdateStatus("📂 Test complete: " . currentMacros . " saved → " . loadedMacros . " loaded")
    
    if (loadedMacros != currentMacros) {
        MsgBox("Save/Load mismatch!`n`nOriginal: " . currentMacros . " macros`nLoaded: " . loadedMacros . " macros`n`nPress F11 for detailed debug info.", "Save/Load Test Failed", "Icon!")
    } else {
        MsgBox("Save/Load test successful!`n`n" . loadedMacros . " macros preserved correctly.", "Save/Load Test Passed", "Icon!")
    }
}

; ===== OFFLINE DATA STORAGE SYSTEM =====
global currentUsername := ""
global persistentDataFile := A_ScriptDir . "\data\persistent_user_data.json"
global dailyStatsFile := A_ScriptDir . "\data\daily_stats.json"
global offlineLogFile := A_ScriptDir . "\data\offline_log.txt"
global dataQueue := []
global lastSaveTime := 0

; Initialize username from Windows user
InitializeUsername() {
    global currentUsername
    
    ; Use raw Windows username
    currentUsername := A_UserName
    
    ; Basic validation
    if (!currentUsername || currentUsername == "") {
        currentUsername := "DefaultUser"
        UpdateStatus("⚠️ No username detected, using: " . currentUsername)
    } else {
        UpdateStatus("👤 User initialized: " . currentUsername)
    }
    
    return currentUsername
}

; Initialize offline data storage files
InitializeOfflineDataFiles() {
    global persistentDataFile, dailyStatsFile, offlineLogFile
    
    try {
        ; Create data directory if it doesn't exist
        if (!DirExist(A_ScriptDir . "\data")) {
            DirCreate(A_ScriptDir . "\data")
        }
        
        ; Initialize persistent data file if it doesn't exist
        if (!FileExist(persistentDataFile)) {
            initialData := "{"
            initialData .= "`n  `"version`": `"1.0.0`","
            initialData .= "`n  `"created`": `"" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "`","
            initialData .= "`n  `"users`": {},"
            initialData .= "`n  `"totalStats`": {"
            initialData .= "`n    `"totalBoxCount`": 0,"
            initialData .= "`n    `"totalExecutionTimeMs`": 0,"
            initialData .= "`n    `"totalActiveTimeSeconds`": 0,"
            initialData .= "`n    `"totalExecutionCount`": 0,"
            initialData .= "`n    `"totalSessions`": 0,"
            initialData .= "`n    `"firstSessionDate`": null,"
            initialData .= "`n    `"lastSessionDate`": null"
            initialData .= "`n  }"
            initialData .= "`n}"
            
            FileAppend(initialData, persistentDataFile)
        }
        
        ; Initialize daily stats file if it doesn't exist
        if (!FileExist(dailyStatsFile)) {
            currentDay := FormatTime(, "dddd, MMMM d, yyyy")
            initialDaily := "{"
            initialDaily .= "`n  `"lastReset`": `"" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "`","
            initialDaily .= "`n  `"currentDay`": `"" . currentDay . "`","
            initialDaily .= "`n  `"resetTime`": `"18:00:00`","
            initialDaily .= "`n  `"stats`": {"
            initialDaily .= "`n    `"totalBoxCount`": 0,"
            initialDaily .= "`n    `"totalExecutionTimeMs`": 0,"
            initialDaily .= "`n    `"activeTimeSeconds`": 0,"
            initialDaily .= "`n    `"executionCount`": 0,"
            initialDaily .= "`n    `"sessions`": []"
            initialDaily .= "`n  }"
            initialDaily .= "`n}"
            
            FileAppend(initialDaily, dailyStatsFile)
        }
        
        ; Log initialization
        LogOfflineActivity("Offline storage initialized")
        
        UpdateStatus("💾 Offline data storage initialized successfully")
        return true
    } catch Error as e {
        UpdateStatus("⚠️ Error initializing offline storage: " . e.Message)
        return false
    }
}

; Save aggregated stats to offline storage (replaces SendStatsToWebhook)
SaveStatsOffline() {
    global macroExecutionLog, currentUsername, dataQueue, lastSaveTime, offlineLogFile, dailyStatsFile
    
    ; Check if enough time has passed (5 minutes instead of 10 for more frequent saves)
    currentTime := A_TickCount
    if ((currentTime - lastSaveTime) < 300000) { ; 5 minutes in milliseconds
        return false
    }
    
    if (!macroExecutionLog || macroExecutionLog.Length = 0) {
        return false
    }
    
    try {
        ; Check for daily reset first
        CheckDailyReset()
        
        ; Ensure username is initialized
        if (!currentUsername) {
            InitializeUsername()
        }
        
        ; Aggregate metrics from execution log
        metrics := AggregateMetrics()
        
        ; Save to offline storage
        SaveMetricsToFile(metrics)
        
        ; Update last save time
        lastSaveTime := currentTime
        
        ; Clear the execution log after successful save
        macroExecutionLog := []
        SaveExecutionData()
        
        UpdateStatus("💾 Data saved to offline storage")
        
        ; Log the save
        LogOfflineActivity("Saved session data for " . currentUsername)
        
        return true
        
    } catch Error as e {
        UpdateStatus("⚠️ Offline save failed: " . e.Message)
        
        ; Add to queue for retry
        dataQueue.Push({
            timestamp: A_Now,
            username: currentUsername,
            metrics: AggregateMetrics()
        })
        
        return false
    }
}

; Aggregate execution data into metrics format
AggregateMetrics() {
    global macroExecutionLog, applicationStartTime, totalActiveTime, lastActiveTime
    
    if (!macroExecutionLog || macroExecutionLog.Length = 0) {
        return {}
    }
    
    ; Calculate totals
    totalBoxCount := 0
    totalExecutionTimeMs := 0
    executionCount := macroExecutionLog.Length
    degradationSummary := Map()
    individualMetrics := []
    
    ; Process each execution record
    for execution in macroExecutionLog {
        totalBoxCount += execution.boundingBoxes.Length
        totalExecutionTimeMs += execution.executionTime
        
        ; Track degradation types
        if (execution.degradationSummary) {
            for degradationType in StrSplit(execution.degradationSummary, ",") {
                degradationType := Trim(degradationType)
                if (degradationType) {
                    if (degradationSummary.Has(degradationType)) {
                        degradationSummary[degradationType]++
                    } else {
                        degradationSummary[degradationType] := 1
                    }
                }
            }
        }
        
        ; Add individual metric
        individualMetrics.Push({
            boxCount: execution.boundingBoxes.Length,
            executionTime: execution.executionTime,
            degradationSummary: execution.degradationSummary,
            layer: execution.layer,
            mode: execution.mode,
            taggedBoxCount: execution.taggedBoxes,
            untaggedBoxCount: execution.untaggedBoxes,
            category: execution.button,
            severity: execution.severity || "medium"
        })
    }
    
    ; Convert degradation map to string
    degradationSummaryStr := ""
    for degradationType, count in degradationSummary {
        if (degradationSummaryStr) {
            degradationSummaryStr .= ", "
        }
        degradationSummaryStr .= degradationType . ":" . count
    }
    
    ; Calculate active time in seconds
    currentActiveTime := totalActiveTime
    if (lastActiveTime > 0) {
        currentActiveTime += (A_TickCount - lastActiveTime)
    }
    activeTimeSeconds := Round(currentActiveTime / 1000, 2)
    
    return {
        timestamp: FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss"),
        taskId: "session_" . FormatTime(applicationStartTime, "yyyyMMdd_HHmmss"),
        totalBoxCount: totalBoxCount,
        totalExecutionTimeMs: totalExecutionTimeMs,
        activeTimeSeconds: activeTimeSeconds,
        executionCount: executionCount,
        degradationSummary: degradationSummaryStr,
        individualMetrics: individualMetrics
    }
}

; Retry queued offline saves (replaces RetryQueuedUploads)
RetryQueuedSaves() {
    global dataQueue
    
    if (!dataQueue || dataQueue.Length = 0) {
        return
    }
    
    successfulSaves := []
    
    for i, queuedData in dataQueue {
        try {
            ; Attempt to save queued data offline
            SaveMetricsToFile(queuedData.metrics)
            successfulSaves.Push(i)
        } catch {
            ; Continue with next save attempt
        }
    }
    
    ; Remove successful saves from queue (in reverse order to maintain indices)
    for i in successfulSaves {
        dataQueue.RemoveAt(dataQueue.Length - i + 1)
    }
    
    if (successfulSaves.Length > 0) {
        UpdateStatus("💾 Saved " . successfulSaves.Length . " queued items offline")
    }
}

; Initialize offline data storage system
InitializeOfflineStorage() {
    ; Initialize username
    InitializeUsername()
    
    ; Initialize offline data files
    InitializeOfflineDataFiles()
    
    ; Set up periodic save timer (every 5 minutes)
    SetTimer(SaveStatsOffline, 300000) ; Every 5 minutes
    
    ; Set up daily reset check timer (every hour)
    SetTimer(CheckDailyReset, 3600000) ; Every hour
}

; ===== OFFLINE DATA MANAGEMENT FUNCTIONS =====

; Centralized logging function
LogOfflineActivity(message) {
    global offlineLogFile
    timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    logEntry := timestamp . " - " . message . "`n"
    try {
        FileAppend(logEntry, offlineLogFile)
    } catch {
        ; Silent fail for logging to prevent cascading errors
    }
}

; Check if daily reset is needed (6 PM CST)
CheckDailyReset() {
    global dailyStatsFile, offlineLogFile
    
    ; Get current time in CST (UTC-6) - simplified version
    currentHour := Integer(FormatTime(, "H"))
    currentDay := FormatTime(, "dddd, MMMM d, yyyy")
    
    try {
        ; Read current daily stats to check if reset is needed
        if (FileExist(dailyStatsFile)) {
            dailyContent := FileRead(dailyStatsFile)
            
            ; Simple check - if it's past 6 PM and current day is not in file
            if (currentHour >= 18 && !InStr(dailyContent, currentDay)) {
                ResetDailyStats()
            }
        }
    } catch Error as e {
        ; Log error but don't fail
        LogOfflineActivity("Reset check failed: " . e.Message)
    }
}

; Reset daily stats at 6 PM CST
ResetDailyStats() {
    global dailyStatsFile, offlineLogFile
    
    try {
        ; Backup current daily stats before reset
        currentDay := FormatTime(, "yyyy-MM-dd")
        backupFile := A_ScriptDir . "\data\backup_daily_" . currentDay . ".json"
        if (FileExist(dailyStatsFile)) {
            FileCopy(dailyStatsFile, backupFile)
        }
        
        ; Create new daily stats
        newDay := FormatTime(, "dddd, MMMM d, yyyy")
        newDaily := "{"
        newDaily .= "`n  `"lastReset`": `"" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "`","
        newDaily .= "`n  `"currentDay`": `"" . newDay . "`","
        newDaily .= "`n  `"resetTime`": `"18:00:00`","
        newDaily .= "`n  `"stats`": {"
        newDaily .= "`n    `"totalBoxCount`": 0,"
        newDaily .= "`n    `"totalExecutionTimeMs`": 0,"
        newDaily .= "`n    `"activeTimeSeconds`": 0,"
        newDaily .= "`n    `"executionCount`": 0,"
        newDaily .= "`n    `"sessions`": []"
        newDaily .= "`n  }"
        newDaily .= "`n}"
        
        ; Write new daily stats
        FileDelete(dailyStatsFile)
        FileAppend(newDaily, dailyStatsFile)
        
        ; Log reset
        LogOfflineActivity("Daily stats reset for " . newDay)
        
        UpdateStatus("🔄 Daily stats reset at 6 PM CST")
    } catch Error as e {
        UpdateStatus("⚠️ Daily reset failed: " . e.Message)
    }
}

; Save metrics to both persistent and daily files
SaveMetricsToFile(metrics) {
    global currentUsername, persistentDataFile, dailyStatsFile, offlineLogFile
    
    try {
        ; For simplified implementation, append to log files
        ; In a full JSON implementation, you'd parse and update the JSON objects
        
        timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        
        ; Append to persistent log
        persistentLog := A_ScriptDir . "\data\persistent_log.txt"
        logEntry := timestamp . " - " . currentUsername . " - Boxes:" . metrics.totalBoxCount . " Time:" . metrics.totalExecutionTimeMs . "ms Sessions:" . metrics.executionCount . "`n"
        FileAppend(logEntry, persistentLog)
        
        ; Append to daily log  
        dailyLog := A_ScriptDir . "\data\daily_log.txt"
        FileAppend(logEntry, dailyLog)
        
        ; Log successful save
        LogOfflineActivity("Saved metrics for " . currentUsername . ": " . metrics.totalBoxCount . " boxes")
        
    } catch Error as e {
        throw Error("Failed to save metrics: " . e.Message)
    }
}

; Show comprehensive offline stats screen with daily and lifetime data
ShowOfflineStatsScreen() {
    global currentUsername, persistentDataFile, dailyStatsFile, offlineLogFile
    
    try {
        ; Check for daily reset before showing stats
        CheckDailyReset()
        
        ; Read the log files to get basic stats
        dailyStats := GetDailyStats()
        lifetimeStats := GetLifetimeStats()
        
        ; Calculate additional metrics
        currentTime := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        nextResetTime := "Today at 6:00 PM CST"
        
        ; If it's past 6 PM, next reset is tomorrow
        currentHour := Integer(FormatTime(, "H"))
        if (currentHour >= 18) {
            nextResetTime := "Tomorrow at 6:00 PM CST"
        }
        
        ; Build comprehensive stats display
        statsText := "📊 MACROMASTER OFFLINE STATISTICS`n"
        statsText .= "════════════════════════════════════════`n`n"
        
        ; User info
        statsText .= "👤 USER: " . currentUsername . "`n"
        statsText .= "⏰ CURRENT TIME: " . currentTime . "`n"
        statsText .= "🔄 NEXT DAILY RESET: " . nextResetTime . "`n`n"
        
        ; Daily stats section
        statsText .= "📅 TODAY'S STATS (Resets at 6 PM CST)`n"
        statsText .= "────────────────────────────────────────`n"
        statsText .= "📦 Boxes Processed: " . dailyStats.totalBoxes . "`n"
        statsText .= "⏱️  Total Time: " . FormatMillisecondsToTime(dailyStats.totalTime) . "`n"
        statsText .= "🎯 Sessions Completed: " . dailyStats.totalSessions . "`n"
        if (dailyStats.totalSessions > 0) {
            avgBoxesPerSession := Round(dailyStats.totalBoxes / dailyStats.totalSessions, 1)
            avgTimePerSession := FormatMillisecondsToTime(Round(dailyStats.totalTime / dailyStats.totalSessions))
            statsText .= "📈 Avg Boxes/Session: " . avgBoxesPerSession . "`n"
            statsText .= "📈 Avg Time/Session: " . avgTimePerSession . "`n"
        }
        statsText .= "`n"
        
        ; Lifetime stats section
        statsText .= "🏆 LIFETIME STATS (Never Reset)`n"
        statsText .= "────────────────────────────────────────`n"
        statsText .= "📦 Total Boxes: " . lifetimeStats.totalBoxes . "`n"
        statsText .= "⏱️  Total Time: " . FormatMillisecondsToTime(lifetimeStats.totalTime) . "`n"
        statsText .= "🎯 Total Sessions: " . lifetimeStats.totalSessions . "`n"
        if (lifetimeStats.totalSessions > 0) {
            avgBoxesLifetime := Round(lifetimeStats.totalBoxes / lifetimeStats.totalSessions, 1)
            avgTimeLifetime := FormatMillisecondsToTime(Round(lifetimeStats.totalTime / lifetimeStats.totalSessions))
            statsText .= "📈 Avg Boxes/Session: " . avgBoxesLifetime . "`n"
            statsText .= "📈 Avg Time/Session: " . avgTimeLifetime . "`n"
        }
        
        if (lifetimeStats.totalTime > 0 && lifetimeStats.totalBoxes > 0) {
            avgTimePerBox := Round(lifetimeStats.totalTime / lifetimeStats.totalBoxes)
            statsText .= "⚡ Avg Time/Box: " . avgTimePerBox . " ms`n"
        }
        statsText .= "`n"
        
        ; Data persistence info
        statsText .= "💾 DATA STORAGE INFO`n"
        statsText .= "────────────────────────────────────────`n"
        statsText .= "📁 Persistent Data: " . (FileExist(persistentDataFile) ? "✅ Active" : "❌ Missing") . "`n"
        statsText .= "📅 Daily Data: " . (FileExist(dailyStatsFile) ? "✅ Active" : "❌ Missing") . "`n"
        statsText .= "📝 Activity Log: " . (FileExist(offlineLogFile) ? "✅ Active" : "❌ Missing") . "`n`n"
        
        ; Footer
        statsText .= "════════════════════════════════════════`n"
        statsText .= "🖱️  Press F12 to refresh • ESC to close`n"
        statsText .= "💾 All data stored locally • No internet required"
        
        ; Display the stats in a message box with custom options
        result := MsgBox(statsText, "MacroMaster Offline Statistics", "OKCancel Icon!")
        
        if (result = "OK") {
            ; Could add export functionality here in the future
            UpdateStatus("📊 Stats viewed successfully")
        }
        
    } catch Error as e {
        MsgBox("Failed to display stats: " . e.Message, "Stats Error", "IconX")
    }
}

; Get daily stats from log file
GetDailyStats() {
    dailyLog := A_ScriptDir . "\data\daily_log.txt"
    
    stats := {
        totalBoxes: 0,
        totalTime: 0,
        totalSessions: 0
    }
    
    if (FileExist(dailyLog)) {
        try {
            content := FileRead(dailyLog)
            
            ; Count sessions (lines in log)
            Loop Parse, content, "`n", "`r" {
                if (Trim(A_LoopField) != "") {
                    stats.totalSessions++
                    
                    ; Extract boxes and time from each line
                    ; Format: timestamp - username - Boxes:X Time:Yms Sessions:Z
                    if (RegExMatch(A_LoopField, "Boxes:(\d+)", &boxMatch)) {
                        stats.totalBoxes += Integer(boxMatch[1])
                    }
                    if (RegExMatch(A_LoopField, "Time:(\d+)ms", &timeMatch)) {
                        stats.totalTime += Integer(timeMatch[1])
                    }
                }
            }
        } catch {
            ; If reading fails, return zeros
        }
    }
    
    return stats
}

; Get lifetime stats from log file
GetLifetimeStats() {
    persistentLog := A_ScriptDir . "\data\persistent_log.txt"
    
    stats := {
        totalBoxes: 0,
        totalTime: 0,
        totalSessions: 0
    }
    
    if (FileExist(persistentLog)) {
        try {
            content := FileRead(persistentLog)
            
            ; Count sessions (lines in log)
            Loop Parse, content, "`n", "`r" {
                if (Trim(A_LoopField) != "") {
                    stats.totalSessions++
                    
                    ; Extract boxes and time from each line
                    if (RegExMatch(A_LoopField, "Boxes:(\d+)", &boxMatch)) {
                        stats.totalBoxes += Integer(boxMatch[1])
                    }
                    if (RegExMatch(A_LoopField, "Time:(\d+)ms", &timeMatch)) {
                        stats.totalTime += Integer(timeMatch[1])
                    }
                }
            }
        } catch {
            ; If reading fails, return zeros
        }
    }
    
    return stats
}

; Format milliseconds to human-readable time
FormatMillisecondsToTime(ms) {
    if (ms < 1000) {
        return ms . " ms"
    }
    
    seconds := Round(ms / 1000, 1)
    if (seconds < 60) {
        return seconds . " sec"
    }
    
    minutes := Floor(seconds / 60)
    remainingSeconds := Mod(seconds, 60)
    
    if (minutes < 60) {
        return minutes . "m " . Round(remainingSeconds) . "s"
    }
    
    hours := Floor(minutes / 60)
    remainingMinutes := Mod(minutes, 60)
    
    return hours . "h " . remainingMinutes . "m"
}

; ===== START APPLICATION =====
Main()
