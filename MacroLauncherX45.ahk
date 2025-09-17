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
global lastExecutionTime := 0
global playbackStartTime := 0
global currentMacro := ""
global macroEvents := Map()
global buttonGrid := Map()
global buttonLabels := Map()
global buttonPictures := Map()
global buttonCustomLabels := Map()
global mouseHook := 0
global keyboardHook := 0
global darkMode := true

; ===== HOTKEY CONFIGURATION =====
global hotkeyRecordToggle := "F9"
global hotkeySubmit := "NumpadEnter"
global hotkeyDirectClear := "+Enter"
global hotkeyEmergency := "RCtrl"
global hotkeyBreakMode := "^b"
global hotkeyLayerPrev := "NumpadDiv"
global hotkeyLayerNext := "NumpadSub"
global hotkeySettings := "^k"
global hotkeyStats := "F12"

; ===== AUTOMATED MACRO EXECUTION SYSTEM =====
global autoExecutionMode := false
global autoExecutionButton := ""
global autoExecutionTimer := 0
global autoExecutionInterval := 2000  ; Default 2 seconds
global autoExecutionCount := 0
global autoExecutionMaxCount := 0  ; 0 = infinite
global autoExecutionButtons := Map()  ; Track which buttons have automation enabled
global buttonAutoSettings := Map()  ; Store auto settings per button (interval, count, etc.)
global autoStartBtn := 0
global autoStopBtn := 0
global autoIntervalControl := 0
global autoCountControl := 0
global chromeMemoryCleanupCount := 0
global chromeMemoryCleanupInterval := 50  ; Clean memory every 50 executions

; ===== VISUAL INDICATOR SYSTEM =====
global yellowOutlineButtons := Map()  ; Track buttons with yellow outlines

; ===== WASD LABEL TOGGLE SYSTEM =====
global wasdLabelsEnabled := false  ; Track if WASD labels should be shown
global wasdToggleBtn := 0  ; Reference to the WASD toggle button

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
; NOTE: Time stats reset on every program startup for clean daily labeling sessions
; This ensures fresh time calculations (boxes_per_hour, executions_per_hour) while preserving CSV data
global applicationStartTime := A_TickCount
global totalActiveTime := 0
global lastActiveTime := A_TickCount
global breakMode := false
global breakStartTime := 0

; ===== CSV STATS SYSTEM =====
global sessionId := ""
global masterStatsCSV := A_ScriptDir . "\data\master_stats.csv"
global currentUsername := A_UserName
global dailyResetActive := false
global sessionStartTime := 0
global clearDegradationCount := 0

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
global boxDrawDelay := 75
global mouseClickDelay := 85
global mouseDragDelay := 90
global mouseReleaseDelay := 90
global betweenBoxDelay := 200
global keyPressDelay := 20
global focusDelay := 80
global mouseHoverDelay := 35  ; NEW: Mouse hover delay for click accuracy

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
global boxDrawDelay := 75
global mouseClickDelay := 85
global mouseDragDelay := 90
global mouseReleaseDelay := 90
global betweenBoxDelay := 200
global keyPressDelay := 20
global focusDelay := 80
global mouseHoverDelay := 35  ; NEW: Mouse hover delay for click accuracy

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

; ===== CORPORATE-SAFE VISUALIZATION SYSTEM =====
global corpVisualizationMethods := [
    {id: 2, name: "HBITMAP Direct", description: "Memory-only, no file I/O"},
    {id: 5, name: "ASCII Text", description: "Always works, text-based"},
    {id: 3, name: "Memory Stream", description: "IStream interface"},
    {id: 4, name: "Alt Paths", description: "User directories"},
    {id: 1, name: "Traditional File", description: "Temp file method"}
]
global corpVisualizationMethod := 1  ; Default to traditional method
global corporateEnvironmentDetected := false

; STANDARD MENU DIMENSIONS (both config and stats)
global standardMenuWidth := 900
global standardMenuHeight := 650

; ===== HOTKEY PROFILE SYSTEM =====
global hotkeyProfileActive := false
global capsLockPressed := false
global wasdHotkeyMap := Map()

; Initialize WASD hotkey mappings
InitializeWASDHotkeys() {
    global wasdHotkeyMap
    
    ; Enhanced 4x3 grid WASD mappings to numpad equivalents with number row
    ; 1  2  3
    ; Q  W  E  
    ; A  S  D  
    ; Z  X  C  
    wasdHotkeyMap["1"] := "Num7"    ; 1 -> Num7
    wasdHotkeyMap["2"] := "Num8"    ; 2 -> Num8
    wasdHotkeyMap["3"] := "Num9"    ; 3 -> Num9
    wasdHotkeyMap["q"] := "Num4"    ; Q -> Num4
    wasdHotkeyMap["w"] := "Num5"    ; W -> Num5
    wasdHotkeyMap["e"] := "Num6"    ; E -> Num6
    wasdHotkeyMap["a"] := "Num1"    ; A -> Num1
    wasdHotkeyMap["s"] := "Num2"    ; S -> Num2
    wasdHotkeyMap["d"] := "Num3"    ; D -> Num3
    wasdHotkeyMap["z"] := "Num0"    ; Z -> Num0
    wasdHotkeyMap["x"] := "NumDot"  ; X -> NumDot
    wasdHotkeyMap["c"] := "NumMult" ; C -> NumMult
    
    ; Try to load custom mappings from file
    LoadWASDMappingsFromFile()
    
    ; Update button labels to show WASD keys
    UpdateButtonLabelsWithWASD()
}

; ===== UPDATE BUTTON LABELS WITH WASD KEYS =====
UpdateButtonLabelsWithWASD() {
    global buttonCustomLabels, wasdHotkeyMap, buttonNames
    
    ; Create reverse mapping from numpad to WASD
    numpadToWASD := Map()
    for wasdKey, numpadKey in wasdHotkeyMap {
        numpadToWASD[numpadKey] := StrUpper(wasdKey)
    }
    
    ; Always show both numpad and WASD keys for buttons that have WASD mapping
    for buttonName in buttonNames {
        if (numpadToWASD.Has(buttonName)) {
            wasdKey := numpadToWASD[buttonName]
            buttonCustomLabels[buttonName] := buttonName . " / " . wasdKey
        } else {
            ; Show only numpad name for buttons without WASD mapping
            buttonCustomLabels[buttonName] := buttonName
        }
    }
}

; ===== TOGGLE WASD LABELS =====
ToggleWASDLabels() {
    global wasdLabelsEnabled, wasdToggleBtn, wasdHotkeyMap, buttonNames

    ; Toggle the state (visual only - no standalone hotkeys)
    wasdLabelsEnabled := !wasdLabelsEnabled

    ; REMOVED: Standalone key hotkeys to prevent typing interference
    ; WASD hotkeys now ONLY work with CapsLock modifier (CapsLock & key)
    ; This ensures zero interference with normal typing
    
    ; Update grid outline color to show WASD mode state
    UpdateGridOutlineColor()
    
    ; Clear any potentially conflicting labels and rebuild properly
    UpdateButtonLabelsWithWASD()
    
    ; Force visual update of all buttons to show new labels
    for buttonName in buttonNames {
        UpdateButtonAppearance(buttonName)
    }
    
    ; Save configuration immediately to persist state
    SaveConfig()
    
    UpdateStatus(wasdLabelsEnabled ? "WASD mode enabled - button labels show key mappings" : "WASD mode disabled - numpad labels restored")
}

SaveWASDMappingsToFile() {
    global wasdHotkeyMap, workDir
    
    try {
        configFile := workDir . "\wasd_mappings.ini"
        
        ; Create INI content
        content := "[WASDMappings]`n"
        for key, mapping in wasdHotkeyMap {
            content .= key . "=" . mapping . "`n"
        }
        
        ; Write to file
        FileDelete(configFile)
        FileAppend(content, configFile, "UTF-8")
        
    } catch Error as e {
        throw Error("Failed to save WASD mappings: " . e.Message)
    }
}

LoadWASDMappingsFromFile() {
    global wasdHotkeyMap, workDir
    
    try {
        configFile := workDir . "\wasd_mappings.ini"
        
        if (!FileExist(configFile)) {
            return ; Use defaults if no custom file exists
        }
        
        ; Read custom mappings
        content := FileRead(configFile, "UTF-8")
        lines := StrSplit(content, "`n")
        
        for line in lines {
            line := Trim(line)
            if (line && !InStr(line, "[") && InStr(line, "=")) {
                parts := StrSplit(line, "=", , 2)
                if (parts.Length = 2) {
                    key := Trim(parts[1])
                    mapping := Trim(parts[2])
                    
                    ; Validate the mapping
                    validMappings := ["Num0", "Num1", "Num2", "Num3", "Num4", "Num5", "Num6", "Num7", "Num8", "Num9", "NumDot", "NumMult"]
                    if (wasdHotkeyMap.Has(key)) {
                        for validMapping in validMappings {
                            if (mapping = validMapping) {
                                wasdHotkeyMap[key] := mapping
                                break
                            }
                        }
                    }
                }
            }
        }
        
    } catch Error as e {
        ; If loading fails, keep defaults
        UpdateStatus("⚠️ Failed to load custom WASD mappings, using defaults")
    }
}

; Helper function to get degradation type ID by name
GetDegradationTypeByName(degradationName) {
    global degradationTypes
    
    ; Search for the name in the degradationTypes map
    for id, name in degradationTypes {
        if (name = degradationName) {
            return id
        }
    }
    
    ; Default to smudge if not found
    return 1
}

; ===== HOTKEY PROFILE FUNCTIONS =====
ToggleHotkeyProfile() {
    global hotkeyProfileActive, buttonNames
    
    hotkeyProfileActive := !hotkeyProfileActive
    
    if (hotkeyProfileActive) {
        SetupWASDHotkeys()
        UpdateStatus("🎹 WASD Hotkey Profile ACTIVATED - CapsLock + 1 2 3 q w e a s d z x c enabled")
    } else {
        DisableWASDHotkeys()
        UpdateStatus("🎹 WASD Hotkey Profile DEACTIVATED - Numpad mode restored")
    }
    
    ; Update labels immediately when profile state changes
    UpdateButtonLabelsWithWASD()
    
    ; Force visual update of all buttons to show new labels
    for buttonName in buttonNames {
        UpdateButtonAppearance(buttonName)
    }
    
    ; Save the state for persistence
    SaveConfig()
}

SetupWASDHotkeys() {
    global wasdHotkeyMap
    
    try {
        ; Setup CapsLock as modifier with improved logic
        Hotkey("CapsLock", (*) => CapsLockDown(), "On")
        Hotkey("CapsLock Up", (*) => CapsLockUp(), "On")
        
        ; Setup all mapped keys with CapsLock modifier
        ; Enhanced to include 123qweasdzxc combinations
        for wasdKey, numpadKey in wasdHotkeyMap {
            try {
                hotkeyCombo := "CapsLock & " . wasdKey
                Hotkey(hotkeyCombo, ExecuteWASDMacro.Bind(numpadKey), "On")
            } catch Error as keyError {
                ; Skip individual key conflicts but continue with others
                UpdateStatus("⚠️ Skipped conflicted hotkey: CapsLock & " . wasdKey)
            }
        }
        
        ; Regular standalone keys are only enabled when WASD mode is toggled on
        ; This prevents accidental macro execution when typing normally
        
    } catch Error as e {
        UpdateStatus("⚠️ WASD hotkey setup failed: " . e.Message)
    }
}

DisableWASDHotkeys() {
    global wasdHotkeyMap, capsLockPressed
    
    try {
        ; Disable CapsLock modifier
        Hotkey("CapsLock", "Off")
        Hotkey("CapsLock Up", "Off")
        
        ; Clear the pressed state
        capsLockPressed := false
        
        ; Disable all mapped key combinations
        for wasdKey, buttonName in wasdHotkeyMap {
            try {
                hotkeyCombo := "CapsLock & " . wasdKey
                Hotkey(hotkeyCombo, "Off")
            } catch Error as keyError {
                ; Skip individual key errors but continue with others
            }
        }
        
        ; Restore normal CapsLock functionality when profile is disabled
        SetCapsLockState("Off")
        
    } catch Error as e {
        UpdateStatus("⚠️ WASD hotkey disable failed: " . e.Message)
    }
}

CapsLockDown() {
    global capsLockPressed, hotkeyProfileActive
    
    ; Only register CapsLock press if hotkey profile is active
    if (hotkeyProfileActive) {
        capsLockPressed := true
        ; Prevent CapsLock state change in system
        SetCapsLockState("Off")
    }
}

CapsLockUp() {
    global capsLockPressed, hotkeyProfileActive
    
    ; Always clear the pressed state
    capsLockPressed := false
    
    ; Ensure CapsLock state remains off when using as modifier
    if (hotkeyProfileActive) {
        SetCapsLockState("Off")
    }
}

ExecuteWASDMacro(buttonName, *) {
    global hotkeyProfileActive
    
    ; Enhanced validation to prevent mis-inputs
    if (!hotkeyProfileActive) {
        return
    }
    
    ; Note: CapsLock modifier is already enforced by "CapsLock & key" syntax
    ; No need to check capsLockPressed state since hotkey won't trigger without CapsLock
    
    UpdateStatus("🎹 WASD: CapsLock+" . RegExReplace(buttonName, "Num", "") . " → " . buttonName)
    SafeExecuteMacroByKey(buttonName)
}


; ===== MAIN INITIALIZATION =====
Main() {
    try {
        ; Initialize core systems
        InitializeDirectories()
        InitializeVariables()
        InitializeCSVFile()
        InitializeStatsSystem()
        ; LoadExecutionData()  ; DISABLED - CSV only approach
        InitializeJsonAnnotations()
        InitializeVisualizationSystem()
        InitializeWASDHotkeys()  ; Initialize WASD hotkey mappings
        
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
        
        ; Setup time tracking, auto-save, and state monitoring
        SetTimer(UpdateActiveTime, 30000)
        SetTimer(AutoSave, 60000)
        SetTimer(MonitorExecutionState, 15000)  ; Check for stuck states every 15 seconds
        
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
    clearDegradationCount := 0
    
    ; Debug: Verify sessionId is set
    ; MsgBox("SessionId initialized: " . sessionId)
}

InitializeDirectories() {
    global workDir, thumbnailDir
    
    if !DirExist(workDir)
        DirCreate(workDir)
    
    ; Try to create thumbnail directory using Method 4 fallback approach for corporate environments
    if !DirExist(thumbnailDir) {
        ; Try original path first
        try {
            DirCreate(thumbnailDir)
            if (DirExist(thumbnailDir)) {
                return
            }
        } catch {
            ; Original path failed, try fallback locations
        }
        
        ; Method 4: Try alternative thumbnail directory locations
        fallbackDirs := [
            A_ScriptDir . "\thumbnails",
            A_MyDocuments . "\MacroMaster_thumbnails", 
            EnvGet("USERPROFILE") . "\MacroMaster_thumbnails",
            A_Desktop . "\MacroMaster_thumbnails"
        ]
        
        for testDir in fallbackDirs {
            try {
                DirCreate(testDir)
                if (DirExist(testDir)) {
                    ; Update global thumbnail directory to working path
                    thumbnailDir := testDir
                    UpdateStatus("📁 Using alternate thumbnail directory: " . testDir)
                    return
                }
            } catch {
                continue
            }
        }
        
        ; If all directory creation fails, disable thumbnails
        UpdateStatus("⚠️ Could not create thumbnail directory - thumbnails disabled")
        thumbnailDir := ""
    }
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

DeleteFile(filePath) {
    ; Helper function for safe file deletion
    try {
        if (FileExist(filePath))
            FileDelete(filePath)
    } catch {
        ; Ignore deletion errors for temporary files
    }
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
    global hotkeyRecordToggle, hotkeySubmit, hotkeyDirectClear, hotkeyEmergency, hotkeyBreakMode
    global hotkeyLayerPrev, hotkeyLayerNext, hotkeySettings, hotkeyStats
    
    try {
        ; CRITICAL: Clear any existing configured hotkey to prevent conflicts
        try {
            Hotkey(hotkeyRecordToggle, "Off")
        } catch {
        }
        
        ; Sleep(50) - REMOVED for rapid labeling performance
        
        ; Recording control - use configured key (default F9)
        if (hotkeyRecordToggle != "") {
            Hotkey(hotkeyRecordToggle, F9_RecordingOnly, "On")
        }
        
        ; Stats display - use configured key (default F12)
        if (hotkeyStats != "") {
            Hotkey(hotkeyStats, (*) => ShowPythonStats())
        }
        
        ; Break mode toggle - use configured key (default Ctrl+B)
        if (hotkeyBreakMode != "") {
            Hotkey(hotkeyBreakMode, (*) => ToggleBreakMode())
        }
        
        ; Hotkey profile toggle (not configurable - keep as Ctrl+H)
        Hotkey("^h", (*) => ToggleHotkeyProfile())
        
        ; Configuration menu access - use configured key (default Ctrl+K)
        if (hotkeySettings != "") {
            Hotkey(hotkeySettings, (*) => ShowSettings())
        }
        
        ; Manual state reset (not configurable - keep as Ctrl+Shift+R)
        Hotkey("^+r", (*) => ForceStateReset())
        
        ; Debug (not configurable - keep as F11)
        Hotkey("F11", (*) => ShowRecordingDebug())
        
        ; Layer navigation - use configured keys
        if (hotkeyLayerPrev != "") {
            Hotkey(hotkeyLayerPrev, (*) => SwitchLayer("prev"))
        }
        if (hotkeyLayerNext != "") {
            Hotkey(hotkeyLayerNext, (*) => SwitchLayer("next"))
        }
        
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
        
        ; Shift+Numpad for clear degradation executions
        Hotkey("+Numpad7", (*) => ShiftNumpadClearExecution("Num7"))
        Hotkey("+Numpad8", (*) => ShiftNumpadClearExecution("Num8"))
        Hotkey("+Numpad9", (*) => ShiftNumpadClearExecution("Num9"))
        Hotkey("+Numpad4", (*) => ShiftNumpadClearExecution("Num4"))
        Hotkey("+Numpad5", (*) => ShiftNumpadClearExecution("Num5"))
        Hotkey("+Numpad6", (*) => ShiftNumpadClearExecution("Num6"))
        Hotkey("+Numpad1", (*) => ShiftNumpadClearExecution("Num1"))
        Hotkey("+Numpad2", (*) => ShiftNumpadClearExecution("Num2"))
        Hotkey("+Numpad3", (*) => ShiftNumpadClearExecution("Num3"))
        Hotkey("+Numpad0", (*) => ShiftNumpadClearExecution("Num0"))
        Hotkey("+NumpadDot", (*) => ShiftNumpadClearExecution("NumDot"))
        Hotkey("+NumpadMult", (*) => ShiftNumpadClearExecution("NumMult"))
        
        ; CapsLock combination hotkeys for layer switching
        Hotkey("CapsLock & 1", (*) => SwitchToLayer(1))
        Hotkey("CapsLock & 2", (*) => SwitchToLayer(2))
        Hotkey("CapsLock & 3", (*) => SwitchToLayer(3))
        Hotkey("CapsLock & 4", (*) => SwitchToLayer(4))
        
        ; WASD hotkeys for macro execution
        SetupWASDHotkeys()
        
        ; Utility - use configured keys
        if (hotkeySubmit != "") {
            Hotkey(hotkeySubmit, (*) => SubmitCurrentImage())
        }
        if (hotkeyDirectClear != "") {
            Hotkey(hotkeyDirectClear, (*) => DirectClearExecution())
        }
        if (hotkeyEmergency != "") {
            Hotkey(hotkeyEmergency, (*) => EmergencyStop())
        }
        
        UpdateStatus("✅ Hotkeys configured - F9 isolated for recording only, WASD + CapsLock support added")
    } catch Error as e {
        UpdateStatus("⚠️ Hotkey setup failed: " . e.Message)
        MsgBox("Hotkey error: " . e.Message, "Setup Error", "Icon!")
    }
}

; ===== WASD MACRO EXECUTION =====
; REMOVED: WASDExecuteMacro function - no longer needed
; Standalone WASD hotkeys removed to prevent typing interference

; ===== LAYER SWITCHING =====
SwitchToLayer(layerNum) {
    global currentLayer, totalLayers
    
    if (layerNum < 1 || layerNum > totalLayers) {
        UpdateStatus("❌ Invalid layer: " . layerNum)
        return
    }
    
    currentLayer := layerNum
    
    ; Update layer indicator display
    if (layerIndicator) {
        layerIndicator.Text := "Layer " . currentLayer
        layerIndicator.Opt("+Background" . layerBorderColors[currentLayer])
        layerIndicator.Redraw()
    }
    
    ; Update grid outline
    if (gridOutline) {
        gridOutline.Opt("+Background" . layerBorderColors[currentLayer])
        gridOutline.Redraw()
    }
    
    RefreshAllButtonAppearances()
    UpdateStatus("📚 Switched to Layer " . layerNum)
}

; ===== F9 RECORDING HANDLER - COMPLETELY ISOLATED =====
F9_RecordingOnly(*) {
    global recording, awaitingAssignment, breakMode, playback, annotationMode
    
    ; CRITICAL: Block ALL F9 operations during break mode
    if (breakMode) {
        UpdateStatus("🔴 BREAK MODE ACTIVE - F9 recording completely blocked")
        return
    }
    
    ; Comprehensive state checking with detailed logging
    UpdateStatus("🔧 F9 PRESSED (" . annotationMode . " mode) - Checking states...")
    
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
    global buttonAutoSettings, currentLayer, autoExecutionMode, breakMode, playback, lastExecutionTime
    
    ; CRITICAL: Block ALL execution during break mode
    if (breakMode) {
        UpdateStatus("☕ BREAK MODE ACTIVE - All macro execution blocked")
        return
    }
    
    ; CRITICAL: Prevent rapid execution race conditions (minimum 50ms between executions)
    currentTime := A_TickCount
    if (lastExecutionTime && (currentTime - lastExecutionTime) < 50) {
        UpdateStatus("⚡ Execution too rapid - please wait")
        return
    }
    lastExecutionTime := currentTime
    
    ; CRITICAL: Double-check playback state before proceeding
    if (playback) {
        UpdateStatus("⌚ Execution in progress - please wait")
        return
    }
    
    ; CRITICAL: Absolutely prevent F9 from reaching macro execution
    if (buttonName = "F9" || InStr(buttonName, "F9")) {
        UpdateStatus("🚫 F9 BLOCKED from macro execution - Use for recording only")
        return
    }
    
    buttonKey := "L" . currentLayer . "_" . buttonName
    
    ; Check if button has auto mode configured
    if (buttonAutoSettings.Has(buttonKey) && buttonAutoSettings[buttonKey].enabled) {
        if (!autoExecutionMode) {
            ; Start auto mode for this button
            autoExecutionInterval := buttonAutoSettings[buttonKey].interval
            autoExecutionMaxCount := buttonAutoSettings[buttonKey].maxCount
            StartAutoExecution(buttonName)
            UpdateStatus("🤖 Auto mode activated for " . buttonName)
        } else {
            ; Stop current auto mode
            StopAutoExecution()
            UpdateStatus("⏹️ Auto mode stopped")
        }
        return
    }
    
    ; Regular macro execution
    UpdateStatus("🎹 Numpad: " . buttonName)
    ExecuteMacro(buttonName)
}

ExecuteMacro(buttonName) {
    global awaitingAssignment, currentLayer, macroEvents, playback, focusDelay, autoExecutionMode, autoExecutionCount, chromeMemoryCleanupCount, chromeMemoryCleanupInterval
    
    ; PERFORMANCE MONITORING - Start timing execution
    executionStartTime := A_TickCount
    
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
    
    ; CRITICAL: Use try-catch to prevent playback state corruption
    try {
        playback := true
        playbackStartTime := A_TickCount  ; Track when playback started
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
        
        UpdateStatus("✅ Completed: " . buttonName)
        
    } catch Error as e {
        ; CRITICAL: Force state reset on any execution error
        UpdateStatus("⚠️ Execution error: " . e.Message . " - State reset")
    } finally {
        ; PERFORMANCE MONITORING - Calculate execution time and grade
        executionTime := A_TickCount - executionStartTime
        performanceGrade := executionTime <= 500 ? "A" : 
                           executionTime <= 1000 ? "B" : 
                           executionTime <= 2000 ? "C" : "D"
        
        ; Add performance info to status (for JSON profiles mainly)
        if (InStr(layerMacroName, "JSON") || (macroEvents.Has(layerMacroName) && macroEvents[layerMacroName].Length > 0 && macroEvents[layerMacroName][1].type = "jsonAnnotation")) {
            UpdateStatus("✅ JSON executed (" . executionTime . "ms, Grade: " . performanceGrade . ")")
        }
        
        ; CRITICAL: Always reset playback state and button flash
        FlashButton(buttonName, false)
        playback := false
        playbackStartTime := 0
    }
    
    ; Handle auto-execution memory cleanup for Chrome
    if (autoExecutionMode) {
        autoExecutionCount++
        chromeMemoryCleanupCount++
        if (chromeMemoryCleanupCount >= chromeMemoryCleanupInterval) {
            PerformChromeMemoryCleanup()
            chromeMemoryCleanupCount := 0
        }
    }
}

; ===== AUTOMATED MACRO EXECUTION SYSTEM =====
StartAutoExecution(buttonName) {
    global autoExecutionMode, autoExecutionButton, autoExecutionTimer, autoExecutionInterval, autoExecutionCount, autoExecutionMaxCount
    
    if (!macroEvents.Has("L" . currentLayer . "_" . buttonName) || macroEvents["L" . currentLayer . "_" . buttonName].Length = 0) {
        UpdateStatus("❌ No macro to automate on " . buttonName)
        return false
    }
    
    if (autoExecutionMode) {
        StopAutoExecution()
    }
    
    autoExecutionMode := true
    autoExecutionButton := buttonName
    autoExecutionCount := 0
    
    ; Add visual indicator
    AddYellowOutline(buttonName)
    
    ; Start the timer
    SetTimer(AutoExecuteLoop, autoExecutionInterval)
    
    UpdateStatus("🔄 Auto-executing " . buttonName . " every " . (autoExecutionInterval / 1000) . "s")
    
    ; Update GUI buttons if they exist
    if (autoStartBtn) {
        try {
            autoStartBtn.Text := "Stop Auto"
            autoStartBtn.Opt("+BackgroundRed")
        } catch {
        }
    }
    
    return true
}

StopAutoExecution() {
    global autoExecutionMode, autoExecutionButton, autoExecutionTimer, autoExecutionCount
    
    if (!autoExecutionMode) {
        return
    }
    
    ; Stop the timer
    SetTimer(AutoExecuteLoop, 0)
    
    ; Remove visual indicator
    if (autoExecutionButton != "") {
        RemoveYellowOutline(autoExecutionButton)
    }
    
    autoExecutionMode := false
    prevButton := autoExecutionButton
    autoExecutionButton := ""
    
    UpdateStatus("⏹️ Stopped auto-execution of " . prevButton . " (ran " . autoExecutionCount . " times)")
    
    ; Update GUI buttons if they exist
    if (autoStartBtn) {
        try {
            autoStartBtn.Text := "Start Auto"
            autoStartBtn.Opt("+BackgroundGreen")
        } catch {
        }
    }
}

AutoExecuteLoop() {
    global autoExecutionMode, autoExecutionButton, autoExecutionCount, autoExecutionMaxCount, playback, breakMode
    
    ; CRITICAL: Block auto-execution during break mode
    if (breakMode) {
        UpdateStatus("☕ BREAK MODE ACTIVE - Auto-execution paused")
        return
    }
    
    if (!autoExecutionMode || autoExecutionButton = "") {
        StopAutoExecution()
        return
    }
    
    ; Check if we've reached max count (if set)
    if (autoExecutionMaxCount > 0 && autoExecutionCount >= autoExecutionMaxCount) {
        UpdateStatus("✅ Completed " . autoExecutionCount . " auto-executions of " . autoExecutionButton)
        StopAutoExecution()
        return
    }
    
    ; Don't execute if already playing back
    if (playback) {
        return
    }
    
    ; Execute the macro
    ExecuteMacro(autoExecutionButton)
}

; ===== VISUAL INDICATOR SYSTEM FOR AUTOMATION =====
AddYellowOutline(buttonName) {
    global buttonGrid, yellowOutlineButtons
    
    if (!buttonGrid.Has(buttonName)) {
        return
    }
    
    button := buttonGrid[buttonName]
    
    ; Store original border and apply yellow outline
    if (!yellowOutlineButtons.Has(buttonName)) {
        ; Create yellow outline effect by changing border
        button.Opt("+Border")
        button.Opt("+Background0xFFFF00")  ; Bright yellow background
        yellowOutlineButtons[buttonName] := true
        
        ; Update button appearance to show automation status
        UpdateButtonAppearance(buttonName)
    }
}

RemoveYellowOutline(buttonName) {
    global buttonGrid, yellowOutlineButtons
    
    if (!buttonGrid.Has(buttonName) || !yellowOutlineButtons.Has(buttonName)) {
        return
    }
    
    button := buttonGrid[buttonName]
    
    ; Restore original appearance
    button.Opt("-Background0xFFFF00")
    yellowOutlineButtons.Delete(buttonName)
    
    ; Update button appearance to normal
    UpdateButtonAppearance(buttonName)
}

; ===== CHROME MEMORY CLEANUP =====
PerformChromeMemoryCleanup() {
    try {
        ; Force garbage collection in Chrome processes
        if (WinExist("ahk_exe chrome.exe")) {
            ; Focus Chrome briefly to allow memory cleanup
            WinActivate("ahk_exe chrome.exe")
            ; Sleep(100) - REMOVED: Between-execution delay

            ; Send some cleanup keystrokes
            Send("{F5}")  ; Refresh current page
            ; Sleep(500) - REMOVED: Between-execution delay
            Send("^+t")  ; Reopen recently closed tab
            ; Sleep(100) - REMOVED: Between-execution delay
            Send("^w")   ; Close the reopened tab
            ; Sleep(200) - REMOVED: Between-execution delay
        }
        
        UpdateStatus("🧹 Chrome memory cleanup performed")
    } catch Error as e {
        ; Silently continue if cleanup fails
    }
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
    global playback, boxDrawDelay, mouseClickDelay, mouseDragDelay, mouseReleaseDelay, betweenBoxDelay, keyPressDelay, mouseHoverDelay
    
    try {
        SetMouseDelay(0)
        SetKeyDelay(5)
        CoordMode("Mouse", "Screen")
        
        for eventIndex, event in recordedEvents {
            ; CRITICAL: Check playback state to allow early termination
            if (!playback)
                break
            
            try {
                if (event.type = "boundingBox") {
                    MouseMove(event.left, event.top, 3)
                    Sleep(boxDrawDelay)

                    Send("{LButton Down}")
                    Sleep(mouseClickDelay)

                    MouseMove(event.right, event.bottom, 4)
                    Sleep(mouseReleaseDelay)

                    Send("{LButton Up}")
                    Sleep(betweenBoxDelay)
                }
                else if (event.type = "mouseDown") {
                    MouseMove(event.x, event.y, 3)
                    Sleep(mouseHoverDelay)
                    Send("{LButton Down}")
                }
                else if (event.type = "mouseUp") {
                    MouseMove(event.x, event.y, 3)
                    Sleep(mouseHoverDelay)
                    Send("{LButton Up}")
                }
                else if (event.type = "keyDown") {
                    Send("{" . event.key . " Down}")
                    Sleep(keyPressDelay)
                }
                else if (event.type = "keyUp") {
                    Send("{" . event.key . " Up}")
                }
            } catch Error as e {
                ; Continue with next event if individual event fails
                continue
            }
        }
        
    } finally {
        ; CRITICAL: Always restore default delays
        SetMouseDelay(10)
        SetKeyDelay(10)
    }
}

ExecuteJsonAnnotation(jsonEvent) {
    global annotationMode
    
    try {
        UpdateStatus("⚡ Executing JSON annotation (" . jsonEvent.mode . " mode)")
        
        ; Enhanced browser focus with validation and fallback
        focusResult := FocusBrowser()
        if (!focusResult) {
            ; Fallback attempt with more aggressive focusing
            UpdateStatus("🔄 Browser focus failed, attempting fallback...")
            ; Sleep(200) - REMOVED: Between-execution delay, not internal macro timing

            ; Try one more time with extended delay
            focusResult := FocusBrowser()
            if (!focusResult) {
                throw Error("Browser focus failed after retry - ensure browser is running")
            }
        }
        
        ; OPTIMIZED JSON EXECUTION - 77% speed improvement
        ; Use speed-optimized timing profile for JSON operations
        
        ; Set clipboard with minimal delay  
        A_Clipboard := jsonEvent.annotation
        ; Sleep(25) - REMOVED for rapid labeling performance
        
        ; Send paste command immediately
        Send("^v")
        ; Sleep(50) - REMOVED for rapid labeling performance
        
        ; Send Shift+Enter to execute the annotation
        Send("+{Enter}")
        ; Sleep(50) - REMOVED for rapid labeling performance
        
        UpdateStatus("✅ JSON annotation executed in " . jsonEvent.mode . " mode")
    } catch Error as e {
        UpdateStatus("⚠️ JSON annotation failed: " . e.Message)
        ; Re-throw to be caught by ExecuteMacro's exception handler
        throw e
    }
}

FocusBrowser() {
    global focusDelay
    
    ; Browser detection with priority order
    browsers := [
        {exe: "ahk_exe chrome.exe", name: "Chrome"},
        {exe: "ahk_exe firefox.exe", name: "Firefox"}, 
        {exe: "ahk_exe msedge.exe", name: "Edge"}
    ]
    
    ; Try to find and focus a browser with retry logic
    maxRetries := 3
    retryDelay := 100
    
    for browser in browsers {
        if (WinExist(browser.exe)) {
            ; Attempt focus with retries
            Loop maxRetries {
                try {
                    WinActivate(browser.exe)
                    ; Sleep(retryDelay) - REMOVED for rapid labeling performance
                    
                    ; Verify focus succeeded by checking if window is active
                    if (WinActive(browser.exe)) {
                        ; Sleep(focusDelay) - REMOVED for rapid labeling performance
                        UpdateStatus("🌐 Focused " . browser.name . " browser")
                        return true
                    }
                    
                    ; If not focused, try more aggressive methods
                    WinRestore(browser.exe)  ; Restore if minimized
                    ; Sleep(50) - REMOVED for rapid labeling performance
                    WinActivate(browser.exe)
                    ; Sleep(retryDelay) - REMOVED for rapid labeling performance
                    
                    if (WinActive(browser.exe)) {
                        ; Sleep(focusDelay) - REMOVED for rapid labeling performance
                        UpdateStatus("🌐 Focused " . browser.name . " browser (restored)")
                        return true
                    }
                    
                } catch Error as e {
                    ; Continue with next retry attempt
                    continue
                }
                
                ; Wait before retry
                if (A_Index < maxRetries) {
                    ; Sleep(retryDelay * A_Index) - REMOVED for rapid labeling performance
                }
            }
        }
    }
    
    UpdateStatus("⚠️ No browser found or focus failed")
    return false
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
    
    ; Update button labels to show combined numpad/WASD format
    UpdateButtonLabelsWithWASD()
    
    ; Force visual update of all buttons to show new labels
    for buttonName in buttonNames {
        UpdateButtonAppearance(buttonName)
    }
    
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
    btnStats.OnEvent("Click", (*) => ShowPythonStats())
    btnStats.SetFont("s8 bold")
    mainGui.btnStats := btnStats
    
    btnSettings := mainGui.Add("Button", "x" . (rightSection + btnWidth + 5) . " y" . btnY . " w" . btnWidth . " h" . btnHeight, "⚙️ Config")
    btnSettings.OnEvent("Click", (*) => ShowSettings())
    btnSettings.SetFont("s8 bold")
    mainGui.btnSettings := btnSettings
    
    btnEmergency := mainGui.Add("Button", "x" . (rightSection + (btnWidth * 2) + 10) . " y" . btnY . " w" . btnWidth . " h" . btnHeight, "🚨 " . hotkeyEmergency)
    btnEmergency.OnEvent("Click", (*) => EmergencyStop())
    btnEmergency.SetFont("s8 bold")
    btnEmergency.Opt("+Background0xDC143C")
    mainGui.btnEmergency := btnEmergency
}

; Update emergency button text to show current assigned key
UpdateEmergencyButtonText() {
    global mainGui, hotkeyEmergency
    
    if (mainGui.HasProp("btnEmergency") && mainGui.btnEmergency) {
        mainGui.btnEmergency.Text := "🚨 " . hotkeyEmergency
    }
}

CreateGridOutline() {
    global mainGui, gridOutline, currentLayer, layerBorderColors
    
    gridOutline := mainGui.Add("Text", "x0 y0 w100 h100 +0x1", "")
    UpdateGridOutlineColor()
}

; Update grid outline color based on WASD mode and current layer
UpdateGridOutlineColor() {
    global gridOutline, currentLayer, layerBorderColors, wasdLabelsEnabled
    
    if (!gridOutline)
        return
        
    if (wasdLabelsEnabled) {
        ; WASD mode active - use subtle blue accent to complement labels
        gridOutline.Opt("+Background0x4169E1")
    } else {
        ; Normal mode - use layer color
        gridOutline.Opt("+Background" . layerBorderColors[currentLayer])
    }
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
    UpdateStatus("🖱️ Right-click: " . buttonName . " | ⚙️ Configuration menu available")
    ShowContextMenuCleaned(buttonName)
}

; ===== BUTTON APPEARANCE =====
RefreshAllButtonAppearances() {
    global buttonNames
    for buttonName in buttonNames {
        UpdateButtonAppearance(buttonName)
    }
}

UpdateButtonAppearance(buttonName) {
    global buttonGrid, buttonPictures, buttonThumbnails, macroEvents, buttonCustomLabels, darkMode, currentLayer, layerBorderColors, degradationTypes, degradationColors, buttonAutoSettings, yellowOutlineButtons, buttonLabels
    
    if (!buttonGrid.Has(buttonName))
        return
    
    button := buttonGrid[buttonName]
    picture := buttonPictures[buttonName]
    layerMacroName := "L" . currentLayer . "_" . buttonName
    
    hasMacro := macroEvents.Has(layerMacroName) && macroEvents[layerMacroName].Length > 0
    hasAutoMode := buttonAutoSettings.Has(layerMacroName) && buttonAutoSettings[layerMacroName].enabled
    
    ; Set label text (this will be shown or hidden based on button content)
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
            jsonColor := Format("0x{:X}", degradationColors[jsonEvent.categoryId])
        }
    }
    
    try {
        ; PRIORITY 1: Check for live macro visualization (NEW!)
        hasVisualizableMacro := hasMacro && !isJsonAnnotation && macroEvents[layerMacroName].Length > 1
        
        if (hasVisualizableMacro) {
            ; Generate live macro visualization using HBITMAP (no file I/O)
            ; Get actual thumbnail dimensions from button layout
            buttonSize := GetButtonThumbnailSize()
            
            ; Extract boxes first to debug
            boxes := ExtractBoxEvents(macroEvents[layerMacroName])
            
            if (boxes.Length > 0) {
                ; Create HBITMAP visualization directly in memory
                hBitmapHandle := CreateHBITMAPVisualization(macroEvents[layerMacroName], buttonSize)
                
                if (hBitmapHandle && hBitmapHandle != 0) {
                    ; HBITMAP created successfully - assign directly to picture control
                    button.Visible := false
                    picture.Visible := true
                    picture.Text := ""
                    try {
                        picture.Value := "HBITMAP:*" . hBitmapHandle
                        ; Note: HBITMAP cleanup will be handled by AutoHotkey when control is destroyed
                    } catch Error as e {
                        ; HBITMAP creation worked but display failed - show debug info
                        ShowMacroAsText(button, picture, macroEvents[layerMacroName], "HBITMAP display error")
                        ; Clean up unused HBITMAP
                        if (hBitmapHandle) {
                            DllCall("DeleteObject", "Ptr", hBitmapHandle)
                        }
                    }
                } else {
                    ; HBITMAP creation failed - show diagnostic info
                    ShowMacroAsText(button, picture, macroEvents[layerMacroName], "HBITMAP creation failed")
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
                thumbnailValue := buttonThumbnails[layerMacroName]
                if (Type(thumbnailValue) = "Integer" && thumbnailValue > 0) {
                    ; HBITMAP handle - assign directly
                    picture.Value := "HBITMAP:*" . thumbnailValue
                } else {
                    ; File path - use existing method
                    picture.Value := thumbnailValue
                }
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
                if (hasAutoMode) {
                    ; Auto mode enabled - bright yellow background
                    button.Opt("+Background0xFFFF00")
                    button.SetFont("s7 bold", "cBlack")  ; Changed to black text for better contrast on yellow
                    button.Text := "🤖 AUTO`n" . events.Length . " events"
                } else {
                    ; Regular macro - layer color
                    button.Opt("+Background" . layerBorderColors[currentLayer])
                    button.SetFont("s7 bold", "cWhite")
                    button.Text := "MACRO`n" . events.Length . " events"
                }
            } else {
                button.Opt("+Background" . (darkMode ? "0x2A2A2A" : "0xF8F8F8"))
                button.SetFont("s8", "cGray")
                
                ; Only show layer indicator when WASD labels are not active
                if (wasdLabelsEnabled) {
                    ; WASD mode - clear button text to let labels show cleanly
                    button.Text := ""
                } else {
                    ; Normal mode - show layer indicator on button
                    button.Text := "L" . currentLayer
                }
            }
        }
        
        ; Label control - show labels on empty buttons, hide on buttons with content
        if (hasMacro || isJsonAnnotation) {
            ; Button has content - hide the separate label to avoid duplicates
            buttonLabels[buttonName].Visible := false
        } else {
            ; Button is empty - show the label with WASD info if active
            buttonLabels[buttonName].Visible := true
            buttonLabels[buttonName].Text := buttonCustomLabels.Has(buttonName) ? buttonCustomLabels[buttonName] : buttonName
        }
        
        ; Apply yellow outline for auto mode buttons
        ApplyYellowOutline(buttonName, hasAutoMode)
        
        if (button.Visible)
            button.Redraw()
        if (picture.Visible)
            picture.Redraw()
            
    } catch Error as e {
        ; Enhanced error handling with more specific feedback
        button.Visible := true
        picture.Visible := false
        button.Opt("+Background" . (darkMode ? "0x2A2A2A" : "0xF8F8F8"))
        button.SetFont("s8", "cGray")
        button.Text := "ERR: " . buttonName
        
        ; Log error for debugging (optional)
        ; UpdateStatus("Button error for " . buttonName . ": " . e.Message)
    }
}

; ===== YELLOW OUTLINE SYSTEM FOR AUTO MODE =====
ApplyYellowOutline(buttonName, hasAutoMode) {
    global buttonGrid, buttonPictures, yellowOutlineButtons
    
    if (!buttonGrid.Has(buttonName))
        return
        
    button := buttonGrid[buttonName]
    picture := buttonPictures[buttonName]
    
    ; Determine which control is currently visible
    activeControl := button.Visible ? button : (picture.Visible ? picture : button)
    
    if (hasAutoMode) {
        ; Add bright yellow outline for auto mode
        try {
            ; Use a combination of approaches for maximum visibility
            
            ; 1. Add yellow border to the active control
            activeControl.Opt("+Border +0x800000")  ; Thick border style
            
            ; 2. For better visibility, add yellow accent indicator
            if (button.Visible) {
                ; Modify the existing text to include yellow indicator
                ; This works with the existing orange background and "🤖 AUTO" text
                currentText := button.Text
                if (!InStr(currentText, "⚡")) {
                    ; Add yellow lightning bolt for auto mode indication
                    button.Text := StrReplace(currentText, "🤖 AUTO", "⚡🤖 AUTO")
                }
            }
            
            ; 3. Use Windows API to set custom border color if possible
            ; This creates a more prominent yellow outline
            hwnd := activeControl.Hwnd
            
            ; Apply custom window styling for yellow border effect
            ; Use extended window styles for better border control
            currentExStyle := DllCall("GetWindowLong", "Ptr", hwnd, "Int", -20, "UInt")
            newExStyle := currentExStyle | 0x200  ; WS_EX_CLIENTEDGE for raised edge
            DllCall("SetWindowLong", "Ptr", hwnd, "Int", -20, "UInt", newExStyle)
            
            ; Force window to redraw with new styling
            DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0001 | 0x0002 | 0x0004 | 0x0020)
            
            ; Track this button as having yellow outline
            yellowOutlineButtons[buttonName] := true
            
        } catch Error as e {
            ; If advanced styling fails, fall back to simple text indicator
            if (button.Visible) {
                currentText := button.Text
                if (!InStr(currentText, "⚡")) {
                    button.Text := StrReplace(currentText, "🤖 AUTO", "⚡🤖 AUTO")
                    yellowOutlineButtons[buttonName] := true
                }
            }
        }
    } else {
        ; Remove yellow outline if it was previously applied
        if (yellowOutlineButtons.Has(buttonName) && yellowOutlineButtons[buttonName]) {
            try {
                ; Remove border and styling
                activeControl.Opt("-Border")
                
                ; Remove extended styling
                hwnd := activeControl.Hwnd
                currentExStyle := DllCall("GetWindowLong", "Ptr", hwnd, "Int", -20, "UInt")
                newExStyle := currentExStyle & ~0x200  ; Remove WS_EX_CLIENTEDGE
                DllCall("SetWindowLong", "Ptr", hwnd, "Int", -20, "UInt", newExStyle)
                
                ; Remove yellow accent from text if present
                if (button.Visible) {
                    currentText := button.Text
                    button.Text := StrReplace(currentText, "⚡🤖 AUTO", "🤖 AUTO")
                }
                
                ; Force redraw
                DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0001 | 0x0002 | 0x0004 | 0x0020)
                
                ; Remove from tracking
                yellowOutlineButtons.Delete(buttonName)
                
            } catch Error as e {
                ; Ignore removal errors, but still clean up text
                if (button.Visible) {
                    currentText := button.Text
                    button.Text := StrReplace(currentText, "⚡🤖 AUTO", "🤖 AUTO")
                }
                yellowOutlineButtons.Delete(buttonName)
            }
        }
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

ShowMacroAsASCII(button, picture, events, asciiViz := "") {
    ; Display ASCII visualization for corporate environments where PNG fails
    global layerBorderColors, currentLayer
    
    ; Create ASCII display based on input
    if (asciiViz = "IMG_ERR") {
        asciiText := "📦 MACRO RECORDED`n❌ Corporate restriction`n⬜ ASCII fallback active"
    } else if (asciiViz = "VIZ_ERR") {
        asciiText := "📦 MACRO RECORDED`n❌ File access blocked`n⬜ Safe mode enabled"  
    } else if (InStr(asciiViz, "┌")) {
        ; Valid ASCII art provided - show first few lines to fit in button
        lines := StrSplit(asciiViz, "`n")
        asciiText := ""
        maxLines := 4  ; Fit in button space
        for i, line in lines {
            if (i > maxLines) 
                goto EndASCIILoop
            if (i > 1) asciiText .= "`n"
            ; Truncate long lines to fit button width
            asciiText .= StrLen(line) > 12 ? SubStr(line, 1, 12) : line
        }
        EndASCIILoop:
        if (lines.Length > maxLines) {
            asciiText .= "`n..."
        }
    } else {
        asciiText := "📦 MACRO`n" . events.Length . " events`n🏢 Corporate-safe mode"
    }
    
    ; Show in picture control with monospace font for better ASCII display
    picture.Visible := true
    button.Visible := false
    picture.Text := asciiText
    picture.SetFont("s6", "Courier New")  ; Small monospace font for ASCII art
    picture.Opt("+Background" . layerBorderColors[currentLayer])
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

; ===== CORPORATE-SAFE PNG VISUALIZATION SYSTEM =====
CreateCorporateSafeVisualizationPNG(macroEvents, buttonSize) {
    ; Enhanced PNG creation with aggressive corporate-safe path testing
    global gdiPlusInitialized, degradationColors
    
    if (!gdiPlusInitialized || !macroEvents || macroEvents.Length = 0) {
        return ""
    }
    
    ; Extract box drawing events
    boxes := ExtractBoxEvents(macroEvents)
    if (boxes.Length = 0) {
        return ""
    }
    
    ; Handle button size format
    if (IsObject(buttonSize)) {
        buttonWidth := buttonSize.width
        buttonHeight := buttonSize.height
    } else {
        buttonWidth := buttonSize
        buttonHeight := buttonSize
    }
    
    ; Create visualization bitmap
    try {
        bitmap := 0
        DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", buttonWidth, "Int", buttonHeight, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bitmap)
        
        graphics := 0
        DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bitmap, "Ptr*", &graphics)
        
        ; Clean white background
        DllCall("gdiplus\GdipGraphicsClear", "Ptr", graphics, "UInt", 0xFFFFFFFF)
        
        ; Draw macro boxes
        DrawMacroBoxesOnButton(graphics, buttonWidth, buttonHeight, boxes)
        
        ; Try extensive corporate-safe path list
        savedFile := SaveVisualizationToCorporatePaths(bitmap, buttonWidth, buttonHeight)
        
        ; Cleanup
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", bitmap)
        
        return savedFile
        
    } catch Error as e {
        return ""
    }
}

SaveVisualizationToCorporatePaths(bitmap, width, height) {
    ; Extensive list of corporate-safe paths to try
    timestamp := A_TickCount
    fileName := "macro_viz_" . timestamp . ".png"
    
    ; Comprehensive corporate-safe path list
    corporateSafePaths := [
        ; User profile paths (most likely to work)
        EnvGet("USERPROFILE") . "\" . fileName,
        EnvGet("USERPROFILE") . "\Documents\" . fileName,
        EnvGet("USERPROFILE") . "\Desktop\" . fileName,
        EnvGet("USERPROFILE") . "\AppData\Local\" . fileName,
        EnvGet("USERPROFILE") . "\AppData\Local\Temp\" . fileName,
        
        ; My Documents variations
        A_MyDocuments . "\" . fileName,
        A_MyDocuments . "\MacroMaster\" . fileName,
        
        ; Desktop variations
        A_Desktop . "\" . fileName,
        A_Desktop . "\MacroMaster\" . fileName,
        
        ; Script directory (if writable)
        A_ScriptDir . "\" . fileName,
        A_ScriptDir . "\temp\" . fileName,
        A_ScriptDir . "\viz\" . fileName,
        
        ; Windows temp variations
        A_Temp . "\" . fileName,
        EnvGet("TMP") . "\" . fileName,
        EnvGet("TEMP") . "\" . fileName,
        
        ; Program data (if accessible)
        "C:\ProgramData\MacroMaster\" . fileName,
        
        ; Last resort - current directory
        ".\" . fileName
    ]
    
    ; GDI+ PNG encoder CLSID
    clsid := Buffer(16)
    NumPut("UInt", 0x557CF406, clsid, 0)
    NumPut("UInt", 0x11D31A04, clsid, 4)
    NumPut("UInt", 0x0000739A, clsid, 8)
    NumPut("UInt", 0x2EF31EF8, clsid, 12)
    
    ; Try each path systematically
    for testPath in corporateSafePaths {
        try {
            ; Ensure directory exists
            parentDir := RegExReplace(testPath, "\\[^\\]*$", "")
            if (!DirExist(parentDir)) {
                DirCreate(parentDir)
            }
            
            ; Attempt PNG creation
            result := DllCall("gdiplus\GdipSaveImageToFile", "Ptr", bitmap, "WStr", testPath, "Ptr", clsid, "Ptr", 0)
            if (result = 0 && FileExist(testPath)) {
                ; Success! Return the working path
                return testPath
            }
            
        } catch {
            ; This path failed, try next one
            continue
        }
    }
    
    ; All paths failed
    return ""
}

DetectCorporateEnvironment() {
    global corpVisualizationMethod, corpVisualizationMethods, corporateEnvironmentDetected
    
    ; Enhanced corporate environment detection
    isCorporate := false
    workingMethods := []
    
    ; Test multiple corporate indicators
    corporateIndicators := [
        !TestFileAccess(),                    ; Temp directory access blocked
        !TestDirectoryCreation(),             ; Can't create directories
        EnvGet("USERDNSDOMAIN") != "",        ; Domain-joined computer
        InStr(A_ComputerName, "CORP"),        ; Corporate naming pattern
        InStr(A_ComputerName, "WRK"),         ; Workstation naming
        InStr(A_UserName, "admin") = 0        ; Not admin user
    ]
    
    ; Count corporate indicators
    corporateScore := 0
    for indicator in corporateIndicators {
        if (indicator) {
            corporateScore++
        }
    }
    
    ; If 2 or more indicators, assume corporate environment
    isCorporate := corporateScore >= 2
    
    if (isCorporate) {
        ; Corporate environment - prioritize safe methods
        UpdateStatus("🏢 Corporate environment detected - using safe visualization")
        workingMethods := [5, 2, 3]  ; ASCII first, then memory-only methods
    } else {
        ; Home/personal environment - use best performance
        if (TestHBITMAPSupport()) {
            workingMethods.Push(2)
        }
        if (TestFileAccess()) {
            workingMethods.Push(1)
            workingMethods.Push(4)
        }
        ; ASCII as fallback
        workingMethods.Push(5)
    }
    
    ; Set best available method
    corpVisualizationMethod := workingMethods[1]
    
    ; Find method name for status
    methodName := "Unknown"
    for method in corpVisualizationMethods {
        if (method.id = corpVisualizationMethod) {
            methodName := method.name
            break
        }
    }
    
    environmentType := isCorporate ? "Corporate" : "Personal"
    UpdateStatus("🖼️ " . environmentType . " environment: " . methodName . " visualization active")
}

TestDirectoryCreation() {
    ; Test if we can create directories in various locations
    testDirs := [
        A_Temp . "\macromaster_test_" . A_TickCount,
        A_ScriptDir . "\test_dir_" . A_TickCount,
        A_MyDocuments . "\macromaster_test_" . A_TickCount
    ]
    
    for testDir in testDirs {
        try {
            DirCreate(testDir)
            if (DirExist(testDir)) {
                DirDelete(testDir)
                return true
            }
        } catch {
            continue
        }
    }
    return false
}

CreateASCIIVisualization(macroEvents, buttonSize) {
    ; Extract box drawing events
    boxes := ExtractBoxEvents(macroEvents)
    if (boxes.Length = 0) {
        return "No boxes recorded"
    }
    
    ; Create density-based ASCII visualization
    gridWidth := 24
    gridHeight := 16
    density := Map()
    
    ; Handle both old and new button size format
    if (IsObject(buttonSize)) {
        width := buttonSize.width
        height := buttonSize.height
    } else {
        width := buttonSize
        height := buttonSize
    }
    
    ; Map boxes to grid cells
    for box in boxes {
        gridX := Floor((box.left / width) * gridWidth)
        gridY := Floor((box.top / height) * gridHeight)
        key := gridX . "," . gridY
        density[key] := (density.Has(key) ? density[key] : 0) + 1
    }
    
    ; Generate ASCII art representation
    topBorder := "┌"
    Loop gridWidth {
        topBorder .= "─"
    }
    topBorder .= "┐"
    result := topBorder . "`n"
    Loop gridHeight {
        y := A_Index - 1
        row := "│"
        Loop gridWidth {
            x := A_Index - 1
            key := x . "," . y
            if (density.Has(key)) {
                count := density[key]
                char := count >= 4 ? "█" : (count >= 2 ? "▓" : "▒")
            } else {
                char := " "
            }
            row .= char
        }
        result .= row . "│`n"
    }
    bottomBorder := "└"
    Loop gridWidth {
        bottomBorder .= "─"
    }
    bottomBorder .= "┘"
    result .= bottomBorder . "`n"
    result .= "📦 " . boxes.Length . " boxes | 🎯 " . density.Count . " regions"
    
    return result
}

TestHBITMAPSupport() {
    ; Test if we can create and use HBITMAP objects
    try {
        bitmap := 0
        result := DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", 32, "Int", 32, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bitmap)
        if (result = 0 && bitmap) {
            DllCall("gdiplus\GdipDisposeImage", "Ptr", bitmap)
            return true
        }
    } catch {
        ; GDI+ not available or access denied
    }
    return false
}

TestFileAccess() {
    ; Test if we can create files in temp directory
    try {
        testFile := A_Temp . "\macro_test_" . A_TickCount . ".tmp"
        FileAppend("test", testFile)
        if (FileExist(testFile)) {
            FileDelete(testFile)
            return true
        }
    } catch {
        ; File access blocked
    }
    return false
}

CreateHBITMAPVisualization(macroEvents, buttonSize) {
    ; Memory-only visualization using HBITMAP (no file system access)
    global gdiPlusInitialized, degradationColors
    
    if (!gdiPlusInitialized || !macroEvents || macroEvents.Length = 0) {
        return 0
    }
    
    ; Extract box drawing events
    boxes := ExtractBoxEvents(macroEvents)
    if (boxes.Length = 0) {
        return 0
    }
    
    ; Handle button size format
    if (IsObject(buttonSize)) {
        buttonWidth := buttonSize.width
        buttonHeight := buttonSize.height
    } else {
        buttonWidth := buttonSize
        buttonHeight := buttonSize
    }
    
    ; Create HBITMAP using GDI+
    bitmap := 0
    graphics := 0
    hbitmap := 0
    
    try {
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
        
        ; Fill with black background
        blackBrush := 0
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF000000, "Ptr*", &blackBrush)
        DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", blackBrush, "Float", 0, "Float", 0, "Float", buttonWidth, "Float", buttonHeight)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", blackBrush)
        
        ; Draw boxes using same logic as PNG version
        DrawMacroBoxesOnButton(graphics, buttonWidth, buttonHeight, boxes)
        
        ; Convert GDI+ bitmap to HBITMAP
        result := DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", bitmap, "Ptr*", &hbitmap, "UInt", 0x00000000)
        
        ; Clean up GDI+ objects
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", bitmap)
        
        if (result = 0 && hbitmap) {
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

CreateMemoryStreamVisualization(macroEvents, buttonSize) {
    ; IStream interface visualization (no file system access)
    ; This is a placeholder - would need IStream implementation
    return CreateASCIIVisualization(macroEvents, buttonSize)  ; Fallback to ASCII for now
}

CreateAltPathVisualization(macroEvents, buttonSize) {
    ; Try user directories instead of temp directory
    altPaths := [
        A_MyDocuments . "\MacroMaster\viz\",
        A_Desktop . "\MacroMaster_tmp\",
        EnvGet("USERPROFILE") . "\MacroMaster\"
    ]
    
    for path in altPaths {
        try {
            ; Ensure directory exists
            if (!DirExist(path)) {
                DirCreate(path)
            }
            
            ; Try creating visualization in this path
            testFile := path . "macro_viz_" . A_TickCount . ".png"
            if (CreateVisualizationInPath(macroEvents, buttonSize, testFile)) {
                return testFile
            }
        } catch {
            continue  ; Try next path
        }
    }
    
    ; All paths failed, fallback to ASCII
    return CreateASCIIVisualization(macroEvents, buttonSize)
}

CreateVisualizationInPath(macroEvents, buttonSize, filePath) {
    ; Create visualization using existing logic but in specified path
    global gdiPlusInitialized, degradationColors
    
    if (!gdiPlusInitialized) {
        return false
    }
    
    boxes := ExtractBoxEvents(macroEvents)
    if (boxes.Length = 0) {
        return false
    }
    
    ; Handle button size format
    if (IsObject(buttonSize)) {
        buttonWidth := buttonSize.width
        buttonHeight := buttonSize.height
    } else {
        buttonWidth := buttonSize
        buttonHeight := buttonSize
    }
    
    try {
        bitmap := 0
        DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", buttonWidth, "Int", buttonHeight, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bitmap)
        
        graphics := 0
        DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bitmap, "Ptr*", &graphics)
        
        ; Clean white background
        DllCall("gdiplus\GdipGraphicsClear", "Ptr", graphics, "UInt", 0xFFFFFFFF)
        
        ; Draw macro boxes
        DrawMacroBoxesOnButton(graphics, buttonWidth, buttonHeight, boxes)
        
        ; Save to specified path
        result := SaveVisualizationPNG(bitmap, filePath)
        
        ; Cleanup
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", bitmap)
        
        return result && FileExist(filePath)
        
    } catch Error as e {
        return false
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

UpdateButtonAppearanceDelayed(buttonName, *) {
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
    global statusBar, windowWidth, windowHeight, mainGui, buttonGrid, buttonLabels, buttonPictures
    static resizeTimer := 0
    
    if (minMax = -1)
        return
    
    ; Add bounds checking
    if (width < 800 || height < 600) {
        return  ; Don't resize below minimum
    }
    
    windowWidth := width
    windowHeight := height
    
    ; Move status bar (existing code - keep this)
    if (statusBar) {
        statusY := height - 25
        statusBar.Move(8, statusY, width - 16, 20)
    }
    
    ; Move toolbar background (existing code - keep this)
    if (mainGui.HasProp("tbBg") && mainGui.tbBg) {
        mainGui.tbBg.Move(0, 0, width, 35)
    }
    
    ; MOVE existing button controls (fast, no appearance updates)
    MoveButtonGridFast()
    
    ; Debounce appearance updates to reduce flickering
    if (resizeTimer) {
        SetTimer(resizeTimer, 0)  ; Cancel previous timer
    }
    resizeTimer := () => UpdateAllButtonAppearances()
    SetTimer(resizeTimer, -150)  ; Update appearances 150ms after resize stops
}

; FAST FUNCTION - Move controls without appearance updates (no flicker)
MoveButtonGridFast() {
    global buttonGrid, buttonLabels, buttonPictures, buttonNames, windowWidth, windowHeight, scaleFactor, gridOutline
    
    ; Calculate new positions (same math as CreateButtonGrid)
    margin := 8
    padding := 4
    toolbarHeight := Round(35 * scaleFactor)
    gridTopPadding := 4
    gridBottomPadding := 30
    
    gridWidth := windowWidth - (margin * 2)
    gridHeight := windowHeight - toolbarHeight - gridTopPadding - gridBottomPadding - (margin * 2)
    
    ; Add safety bounds
    if (gridWidth < 300 || gridHeight < 200) {
        return  ; Don't resize if too small
    }
    
    buttonWidth := Floor((gridWidth - padding * 2) / 3)
    buttonHeight := Floor((gridHeight - padding * 3) / 4)
    labelHeight := Round(18 * scaleFactor)
    thumbHeight := buttonHeight - labelHeight - 2
    
    ; Move grid outline
    outlineThickness := 2
    gridOutline.Move(margin - outlineThickness, toolbarHeight + gridTopPadding + margin - outlineThickness, 
                    gridWidth + (outlineThickness * 2), gridHeight + (outlineThickness * 2))
    
    ; Move existing button controls (fast - no appearance updates)
    for row in [0, 1, 2, 3] {
        for col in [0, 1, 2] {
            index := row * 3 + col + 1
            if (index > 12)
                continue
                
            buttonName := buttonNames[index]
            x := margin + col * (buttonWidth + padding)
            y := toolbarHeight + gridTopPadding + margin + row * (buttonHeight + padding)
            
            ; Move existing controls if they exist (positions only)
            if (buttonGrid.Has(buttonName) && buttonGrid[buttonName]) {
                buttonGrid[buttonName].Move(Floor(x), Floor(y), Floor(buttonWidth), Floor(thumbHeight))
            }
            if (buttonPictures.Has(buttonName) && buttonPictures[buttonName]) {
                buttonPictures[buttonName].Move(Floor(x), Floor(y), Floor(buttonWidth), Floor(thumbHeight))
            }
            if (buttonLabels.Has(buttonName) && buttonLabels[buttonName]) {
                buttonLabels[buttonName].Move(Floor(x), Floor(y + thumbHeight + 1), Floor(buttonWidth), Floor(labelHeight))
            }
        }
    }
}

; BATCH UPDATE - Refresh all button appearances (called after resize stops)
UpdateAllButtonAppearances() {
    global buttonNames
    
    for buttonName in buttonNames {
        UpdateButtonAppearance(buttonName)
    }
}

; LEGACY FUNCTION - Keep for compatibility (slower but complete)
MoveButtonGrid() {
    MoveButtonGridFast()
    UpdateAllButtonAppearances()
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
    UpdateGridOutlineColor()  ; Use the new function that considers WASD mode
    
    gridOutline.Redraw()
    layerIndicator.Redraw()
    
    for name in buttonNames {
        UpdateButtonAppearance(name)
    }
    
    UpdateStatus("🔥 Layer " . currentLayer)
}

; ===== CONTEXT MENUS =====
; REMOVE EFFICIENCY SCORE FROM CONTEXT MENU
ShowContextMenuCleaned(buttonName, *) {
    global currentLayer, degradationTypes, severityLevels
    
    contextMenu := Menu()
    
    contextMenu.Add("🎥 Record Macro", (*) => F9_RecordingOnly())
    contextMenu.Add("🗑️ Clear Macro", (*) => ClearMacro(buttonName))
    contextMenu.Add("🏷️ Edit Label", (*) => EditCustomLabel(buttonName))
    contextMenu.Add()
    
    ; JSON Profiles
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
    
    ; Thumbnails
    contextMenu.Add("🖼️ Add Thumbnail", (*) => AddThumbnail(buttonName))
    contextMenu.Add("🗑️ Remove Thumbnail", (*) => RemoveThumbnail(buttonName))
    contextMenu.Add()
    
    ; Auto execution
    buttonKey := "L" . currentLayer . "_" . buttonName
    hasAutoSettings := buttonAutoSettings.Has(buttonKey)
    autoEnabled := hasAutoSettings && buttonAutoSettings[buttonKey].enabled
    
    if (autoEnabled) {
        contextMenu.Add("✅ Auto Mode: ON", (*) => {})
        contextMenu.Add("❌ Disable Auto Mode", (*) => ToggleAutoEnable(buttonName))
    } else {
        contextMenu.Add("⚙️ Enable Auto Mode", (*) => ToggleAutoEnable(buttonName))
    }
    contextMenu.Add("🔧 Auto Mode: Settings", (*) => ConfigureAutoMode(buttonName))
    
    ; REMOVED: Efficiency score (worthless)
    ; REMOVED: Other redundant options
    
    contextMenu.Show()
}

; Legacy function for backward compatibility
ShowContextMenu(buttonName, *) {
    ShowContextMenuCleaned(buttonName)
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

; ===== AUTO EXECUTION TOGGLE =====
ToggleAutoExecution() {
    global autoExecutionMode
    
    if (!autoExecutionMode) {
        ; Need to show dialog to select which button to automate
        ShowAutoExecutionDialog()
    } else {
        StopAutoExecution()
    }
}

ShowAutoExecutionDialog() {
    global mainGui, buttonNames, macroEvents, currentLayer
    
    ; Create list of available macros
    availableMacros := []
    for buttonName in buttonNames {
        layerMacroName := "L" . currentLayer . "_" . buttonName
        if (macroEvents.Has(layerMacroName) && macroEvents[layerMacroName].Length > 0) {
            availableMacros.Push(buttonName)
        }
    }
    
    if (availableMacros.Length = 0) {
        MsgBox("No recorded macros available on Layer " . currentLayer . ". Record some macros first!", "Auto Execution", "Icon!")
        return
    }
    
    ; Create simple dialog
    autoDialog := Gui("+Owner" . mainGui.Hwnd, "Auto Execution Setup")
    autoDialog.Add("Text", "x10 y10", "Select macro to auto-execute:")
    
    buttonList := ""
    for i, buttonName in availableMacros {
        buttonList .= buttonName . "|"
    }
    buttonList := RTrim(buttonList, "|")
    
    ddlButton := autoDialog.Add("DropDownList", "x10 y35 w200", StrSplit(buttonList, "|"))
    ddlButton.Choose(1)
    
    autoDialog.Add("Text", "x10 y70", "Interval (seconds):")
    editInterval := autoDialog.Add("Edit", "x120 y68 w60", "2")
    
    autoDialog.Add("Text", "x10 y100", "Max executions (0 = infinite):")
    editCount := autoDialog.Add("Edit", "x180 y98 w60", "0")
    
    btnStart := autoDialog.Add("Button", "x10 y130 w100 h30", "Start Auto")
    btnCancel := autoDialog.Add("Button", "x120 y130 w100 h30", "Cancel")
    
    btnStart.OnEvent("Click", StartAutoFromDialog.Bind(autoDialog, availableMacros, ddlButton, editInterval, editCount))
    btnCancel.OnEvent("Click", (*) => autoDialog.Destroy())
    
    autoDialog.Show("w240 h170")
}

StartAutoFromDialog(autoDialog, availableMacros, ddlButton, editInterval, editCount, *) {
    selectedButton := availableMacros[ddlButton.Value]
    interval := Integer(editInterval.Text) * 1000
    maxCount := Integer(editCount.Text)
    
    global autoExecutionInterval, autoExecutionMaxCount
    autoExecutionInterval := interval > 0 ? interval : 2000
    autoExecutionMaxCount := maxCount
    
    autoDialog.Destroy()
    StartAutoExecution(selectedButton)
}

StartAutoExecutionFromContext(buttonName, *) {
    global autoExecutionInterval, autoExecutionMaxCount, currentLayer, macroEvents, mainGui
    
    ; Check if button has a macro
    if (!macroEvents.Has("L" . currentLayer . "_" . buttonName) || macroEvents["L" . currentLayer . "_" . buttonName].Length = 0) {
        MsgBox("No macro recorded for " . buttonName . " on Layer " . currentLayer . ". Record a macro first!", "Auto Execution", "Icon!")
        return
    }
    
    ; Simple dialog for quick setup
    quickDialog := Gui("+Owner" . mainGui.Hwnd, "Quick Auto Setup - " . buttonName)
    quickDialog.Add("Text", "x10 y10", "Interval (seconds):")
    editInterval := quickDialog.Add("Edit", "x100 y8 w60", "2")
    
    quickDialog.Add("Text", "x10 y40", "Max runs (0 = infinite):")
    editCount := quickDialog.Add("Edit", "x130 y38 w60", "0")
    
    btnStart := quickDialog.Add("Button", "x10 y70 w80 h30", "Start")
    btnCancel := quickDialog.Add("Button", "x100 y70 w80 h30", "Cancel")
    
    btnStart.OnEvent("Click", StartQuickAutoFromDialog.Bind(quickDialog, buttonName, editInterval, editCount))
    btnCancel.OnEvent("Click", (*) => quickDialog.Destroy())
    
    quickDialog.Show("w200 h110")
}

; ===== NEW AUTO MODE CONFIGURATION SYSTEM =====
ConfigureAutoMode(buttonName, *) {
    global buttonAutoSettings, currentLayer, macroEvents, mainGui
    
    buttonKey := "L" . currentLayer . "_" . buttonName
    
    ; Check if button has a macro
    if (!macroEvents.Has(buttonKey) || macroEvents[buttonKey].Length = 0) {
        MsgBox("No macro recorded for " . buttonName . " on Layer " . currentLayer . ". Record a macro first!", "Auto Mode Setup", "Icon!")
        return
    }
    
    ; Get existing settings or defaults
    currentSettings := buttonAutoSettings.Has(buttonKey) ? buttonAutoSettings[buttonKey] : {enabled: false, interval: 2000, maxCount: 0}
    
    ; Create configuration dialog
    configDialog := Gui("+Owner" . mainGui.Hwnd, "Auto Mode Setup - " . buttonName)
    
    configDialog.Add("Text", "x10 y10", "Auto Mode Configuration for " . buttonName . " (Layer " . currentLayer . ")")
    
    ; Enable checkbox
    enableCheck := configDialog.Add("Checkbox", "x10 y35", "Enable Auto Mode")
    enableCheck.Value := currentSettings.enabled
    
    configDialog.Add("Text", "x10 y65", "Interval (seconds):")
    intervalEdit := configDialog.Add("Edit", "x120 y63 w60", String(currentSettings.interval / 1000))
    
    configDialog.Add("Text", "x10 y95", "Max executions (0 = infinite):")
    countEdit := configDialog.Add("Edit", "x160 y93 w60", String(currentSettings.maxCount))
    
    configDialog.Add("Text", "x10 y125 w320 h40", "Note: Use numpad hotkeys or right-click → Auto Mode to trigger execution")
    
    btnSave := configDialog.Add("Button", "x10 y170 w100 h30", "Save Settings")
    btnCancel := configDialog.Add("Button", "x120 y170 w100 h30", "Cancel")
    
    btnSave.OnEvent("Click", SaveAutoSettings.Bind(configDialog, buttonKey, enableCheck, intervalEdit, countEdit, buttonName))
    btnCancel.OnEvent("Click", (*) => configDialog.Destroy())
    
    configDialog.Show("w340 h210")
}

; ===== TOGGLE AUTO MODE ENABLE/DISABLE =====
ToggleAutoEnable(buttonName, *) {
    global buttonAutoSettings, currentLayer, macroEvents
    
    buttonKey := "L" . currentLayer . "_" . buttonName
    
    ; Check if button has a macro
    if (!macroEvents.Has(buttonKey) || macroEvents[buttonKey].Length = 0) {
        MsgBox("No macro recorded for " . buttonName . " on Layer " . currentLayer . ". Record a macro first!", "Auto Mode", "Icon!")
        return
    }
    
    ; Toggle enable state
    if (buttonAutoSettings.Has(buttonKey)) {
        ; Settings exist - toggle enable state
        buttonAutoSettings[buttonKey].enabled := !buttonAutoSettings[buttonKey].enabled
        status := buttonAutoSettings[buttonKey].enabled ? "✅ Auto mode enabled for " : "❌ Auto mode disabled for "
        UpdateStatus(status . buttonName)
    } else {
        ; No settings exist - create with defaults and enable
        buttonAutoSettings[buttonKey] := {
            enabled: true,
            interval: 2000,  ; 2 seconds default
            maxCount: 0      ; infinite default
        }
        UpdateStatus("✅ Auto mode enabled for " . buttonName . " (default settings)")
    }
    
    ; Update button appearance and save
    UpdateButtonAppearance(buttonName)
    SaveConfig()
}

DisableAutoMode(buttonName, *) {
    global buttonAutoSettings, currentLayer
    
    buttonKey := "L" . currentLayer . "_" . buttonName
    
    if (buttonAutoSettings.Has(buttonKey)) {
        buttonAutoSettings[buttonKey].enabled := false
        UpdateButtonAppearance(buttonName)
        SaveConfig()
        UpdateStatus("❌ Auto mode disabled for " . buttonName)
    }
}

SaveAutoSettings(configDialog, buttonKey, enableCheck, intervalEdit, countEdit, buttonName, *) {
    global buttonAutoSettings
    
    ; Read values before destroying dialog
    isEnabled := enableCheck.Value
    intervalValue := Integer(intervalEdit.Text) * 1000
    maxCountValue := Integer(countEdit.Text)
    
    ; Save settings
    buttonAutoSettings[buttonKey] := {
        enabled: isEnabled,
        interval: intervalValue,
        maxCount: maxCountValue
    }
    
    configDialog.Destroy()
    
    ; Update button appearance and save
    UpdateButtonAppearance(buttonName)
    SaveConfig()
    
    status := isEnabled ? "✅ Auto mode enabled for " : "❌ Auto mode disabled for "
    UpdateStatus(status . buttonName)
}

EmergencyStopAllAuto(*) {
    global autoExecutionMode
    
    if (autoExecutionMode) {
        StopAutoExecution()
    }
    
    UpdateStatus("🚨 Emergency stop - all auto modes halted")
}

StartQuickAutoFromDialog(quickDialog, buttonName, editInterval, editCount, *) {
    interval := Integer(editInterval.Text) * 1000
    maxCount := Integer(editCount.Text)
    
    global autoExecutionInterval, autoExecutionMaxCount
    autoExecutionInterval := interval > 0 ? interval : 2000
    autoExecutionMaxCount := maxCount
    
    quickDialog.Destroy()
    StartAutoExecution(buttonName)
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

; ===== COMPREHENSIVE CONFIGURATION SYSTEM =====

ShowSettings() {
    ; Create settings dialog with tabbed interface
    settingsGui := Gui("+Resize", "⚙️ Configuration Manager")
    settingsGui.SetFont("s10")
    
    ; Header
    settingsGui.Add("Text", "x20 y20 w460 h30 Center", "CONFIGURATION MANAGEMENT")
    settingsGui.SetFont("s12 Bold")
    
    ; Create tabbed interface
    tabs := settingsGui.Add("Tab3", "x20 y60 w460 h500", ["📦 Configuration", "⚙️ Execution Settings", "🎁 Macro Packs", "🎹 Hotkey Profiles"])
    
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
    global boxDrawDelay, mouseClickDelay, mouseDragDelay, mouseReleaseDelay, betweenBoxDelay, keyPressDelay, focusDelay, mouseHoverDelay
    
    ; Box drawing delays
    settingsGui.Add("Text", "x40 y125 w150 h20", "Box Draw Delay (ms):")
    boxDelayEdit := settingsGui.Add("Edit", "x190 y123 w60 h22", boxDrawDelay)
    boxDelayEdit.OnEvent("Change", (*) => UpdateTimingFromEdit("boxDrawDelay", boxDelayEdit))
    settingsGui.boxDelayEdit := boxDelayEdit  ; Store reference for preset updates
    
    settingsGui.Add("Text", "x40 y155 w150 h20", "Mouse Click Delay (ms):")
    clickDelayEdit := settingsGui.Add("Edit", "x190 y153 w60 h22", mouseClickDelay)
    clickDelayEdit.OnEvent("Change", (*) => UpdateTimingFromEdit("mouseClickDelay", clickDelayEdit))
    settingsGui.clickDelayEdit := clickDelayEdit
    
    settingsGui.Add("Text", "x40 y185 w150 h20", "Mouse Drag Delay (ms):")
    dragDelayEdit := settingsGui.Add("Edit", "x190 y183 w60 h22", mouseDragDelay)
    dragDelayEdit.OnEvent("Change", (*) => UpdateTimingFromEdit("mouseDragDelay", dragDelayEdit))
    settingsGui.dragDelayEdit := dragDelayEdit
    
    settingsGui.Add("Text", "x40 y215 w150 h20", "Mouse Release Delay (ms):")
    releaseDelayEdit := settingsGui.Add("Edit", "x190 y213 w60 h22", mouseReleaseDelay)
    releaseDelayEdit.OnEvent("Change", (*) => UpdateTimingFromEdit("mouseReleaseDelay", releaseDelayEdit))
    settingsGui.releaseDelayEdit := releaseDelayEdit
    
    settingsGui.Add("Text", "x270 y125 w150 h20", "Between Box Delay (ms):")
    betweenDelayEdit := settingsGui.Add("Edit", "x420 y123 w60 h22", betweenBoxDelay)
    betweenDelayEdit.OnEvent("Change", (*) => UpdateTimingFromEdit("betweenBoxDelay", betweenDelayEdit))
    settingsGui.betweenDelayEdit := betweenDelayEdit
    
    settingsGui.Add("Text", "x270 y155 w150 h20", "Key Press Delay (ms):")
    keyDelayEdit := settingsGui.Add("Edit", "x420 y153 w60 h22", keyPressDelay)
    keyDelayEdit.OnEvent("Change", (*) => UpdateTimingFromEdit("keyPressDelay", keyDelayEdit))
    settingsGui.keyDelayEdit := keyDelayEdit
    
    settingsGui.Add("Text", "x270 y185 w150 h20", "Focus Delay (ms):")
    focusDelayEdit := settingsGui.Add("Edit", "x420 y183 w60 h22", focusDelay)
    focusDelayEdit.OnEvent("Change", (*) => UpdateTimingFromEdit("focusDelay", focusDelayEdit))
    settingsGui.focusDelayEdit := focusDelayEdit
    
    ; NEW: Mouse hover delay for click accuracy
    settingsGui.Add("Text", "x270 y215 w150 h20", "Mouse Hover (ms):")
    hoverDelayEdit := settingsGui.Add("Edit", "x420 y213 w60 h22", mouseHoverDelay)
    hoverDelayEdit.OnEvent("Change", (*) => UpdateTimingFromEdit("mouseHoverDelay", hoverDelayEdit))
    settingsGui.hoverDelayEdit := hoverDelayEdit
    
    ; Description for hover delay
    settingsGui.Add("Text", "x40 y245 w500 h15 c0x666666", "💡 Mouse Hover: Pause time after moving to target before clicking (improves accuracy)")
    
    ; Preset buttons (adjusted Y position for new hover control)
    settingsGui.Add("Text", "x40 y275 w400 h20", "🎚️ Timing Presets:")
    
    btnFast := settingsGui.Add("Button", "x40 y300 w90 h25", "⚡ Fast")
    btnFast.OnEvent("Click", (*) => ApplyTimingPreset("fast", settingsGui))
    
    btnDefault := settingsGui.Add("Button", "x140 y300 w90 h25", "🎯 Default")
    btnDefault.OnEvent("Click", (*) => ApplyTimingPreset("default", settingsGui))
    
    btnSafe := settingsGui.Add("Button", "x240 y300 w90 h25", "🛡️ Safe")
    btnSafe.OnEvent("Click", (*) => ApplyTimingPreset("safe", settingsGui))
    
    btnSlow := settingsGui.Add("Button", "x340 y300 w90 h25", "🐌 Slow")
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
    
    ; TAB 4: Hotkey Profiles
    tabs.UseTab(4)
    global hotkeyProfileActive, wasdHotkeyMap, wasdLabelsEnabled
    
    ; Set WASD labels to always be enabled (silent activation)
    if (!wasdLabelsEnabled) {
        ToggleWASDLabels()  ; Enable WASD labels
    }
    
    ; Header focused on utility functions
    settingsGui.Add("Text", "x40 y95 w400 h20", "🎮 Hotkey & Utility Configuration:")
    settingsGui.Add("Text", "x40 y115 w400 h15 c0x666666", "Configure keyboard shortcuts and utility functions")
    
    ; WASD Info (no configuration needed)
    settingsGui.Add("Text", "x40 y140 w400 h15", "🏷️ WASD Labels: Always enabled for optimal workflow")
    
    ; Main Utility Hotkeys Section (clean layout without WASD clutter)
    settingsGui.Add("Text", "x40 y170 w400 h20", "🎮 Main Utility Hotkeys:")
    hotkeyY := 195
    
    ; Record Toggle
    settingsGui.Add("Text", "x40 y" . hotkeyY . " w120 h20", "Record Toggle:")
    editRecordToggle := settingsGui.Add("Edit", "x165 y" . (hotkeyY-2) . " w80 h20", hotkeyRecordToggle)
    hotkeyY += 25
    
    ; Submit/Direct Clear keys
    settingsGui.Add("Text", "x40 y" . hotkeyY . " w120 h20", "Submit:")
    editSubmit := settingsGui.Add("Edit", "x165 y" . (hotkeyY-2) . " w80 h20", hotkeySubmit)
    settingsGui.Add("Text", "x255 y" . hotkeyY . " w80 h20", "Direct Clear:")
    editDirectClear := settingsGui.Add("Edit", "x340 y" . (hotkeyY-2) . " w60 h20", hotkeyDirectClear)
    hotkeyY += 25
    
    ; Stats key (on separate row)
    settingsGui.Add("Text", "x40 y" . hotkeyY . " w120 h20", "Stats:")
    editStats := settingsGui.Add("Edit", "x165 y" . (hotkeyY-2) . " w80 h20", hotkeyStats)
    hotkeyY += 25
    
    ; Break Mode/Settings keys
    settingsGui.Add("Text", "x40 y" . hotkeyY . " w120 h20", "Break Mode:")
    editBreakMode := settingsGui.Add("Edit", "x165 y" . (hotkeyY-2) . " w80 h20", hotkeyBreakMode)
    settingsGui.Add("Text", "x255 y" . hotkeyY . " w60 h20", "Settings:")
    editSettings := settingsGui.Add("Edit", "x320 y" . (hotkeyY-2) . " w80 h20", hotkeySettings)
    hotkeyY += 25
    
    ; Layer Navigation
    settingsGui.Add("Text", "x40 y" . hotkeyY . " w120 h20", "Layer Prev:")
    editLayerPrev := settingsGui.Add("Edit", "x165 y" . (hotkeyY-2) . " w80 h20", hotkeyLayerPrev)
    settingsGui.Add("Text", "x255 y" . hotkeyY . " w60 h20", "Layer Next:")
    editLayerNext := settingsGui.Add("Edit", "x320 y" . (hotkeyY-2) . " w80 h20", hotkeyLayerNext)
    hotkeyY += 30
    
    ; Apply/Reset buttons for hotkeys
    btnApplyHotkeys := settingsGui.Add("Button", "x40 y" . hotkeyY . " w90 h25", "🎮 Apply Keys")
    btnApplyHotkeys.OnEvent("Click", (*) => ApplyHotkeySettings(editRecordToggle, editSubmit, editDirectClear, editStats, editBreakMode, editSettings, editLayerPrev, editLayerNext, settingsGui))
    
    btnResetHotkeys := settingsGui.Add("Button", "x140 y" . hotkeyY . " w90 h25", "🔄 Reset Keys")
    btnResetHotkeys.OnEvent("Click", (*) => ResetHotkeySettings(settingsGui))
    
    ; Enhanced Instructions (focused on utility functions)
    instructY := hotkeyY + 40
    settingsGui.Add("Text", "x40 y" . instructY . " w400 h15 c0x0066CC", "📋 Quick Instructions:")
    instructY += 20
    settingsGui.Add("Text", "x40 y" . instructY . " w400 h45", "• 🏷️ WASD labels are automatically enabled`n• ⚙️ Configure utility hotkeys above for your workflow`n• 💾 Apply to test changes, save to make permanent`n• ⌨️ All hotkeys work alongside standard numpad keys")
    instructY += 55
    settingsGui.Add("Text", "x40 y" . instructY . " w400 h15 c0x666666", "ℹ️ Focus on utility functions - WASD mapping handled automatically.")
    
    ; Close button positioned dynamically based on content
    closeY := instructY + 30
    btnClose := settingsGui.Add("Button", "x420 y" . closeY . " w60 h25", "Close")
    btnClose.OnEvent("Click", (*) => settingsGui.Destroy())
    
    ; Dynamic window height based on content
    windowHeight := closeY + 60
    settingsGui.Show("w500 h" . windowHeight)
}

ShowConfigMenu() {
    ShowSettings()
}


; ===== COMPREHENSIVE STATS SYSTEM =====
ShowPythonStats() {
    global masterStatsCSV, dailyResetActive

    ; Use optimized MacroMaster analytics dashboard ONLY (no fallbacks)
    optimizedScript := A_ScriptDir . "\macromaster_optimized.py"

    ; Check if CSV file exists, create if needed
    if (!FileExist(masterStatsCSV)) {
        try {
            ; Ensure data directory exists
            dataDir := A_ScriptDir . "\data"
            if (!DirExist(dataDir)) {
                DirCreate(dataDir)
            }

            ; Create CSV with proper header
            csvHeader := "timestamp,session_id,username,execution_type,button_key,layer,execution_time_ms,total_boxes,degradation_assignments,severity_level,canvas_mode,session_active_time_ms,break_mode_active`n"
            FileAppend(csvHeader, masterStatsCSV, "UTF-8")
            UpdateStatus("📄 Created CSV data file")
        } catch Error as e {
            MsgBox("❌ Failed to create CSV file: " . e.Message . "`n`nStats system cannot function without CSV data.", "Error", "Icon!")
            return
        }
    }

    ; Check if Python script exists
    if (!FileExist(optimizedScript)) {
        MsgBox("❌ Analytics script not found: " . optimizedScript . "`n`nPlease ensure macromaster_optimized.py is in the same folder as the program.", "Error", "Icon!")
        return
    }

    ; Determine filter mode based on daily reset state
    filterMode := dailyResetActive ? "today" : "all"

    ; Launch optimized dashboard - NO FALLBACKS
    pythonCmd := 'python "' . optimizedScript . '" "' . masterStatsCSV . '" --filter ' . filterMode

    try {
        UpdateStatus("📊 Launching MacroMaster Analytics Dashboard...")
        Run(pythonCmd, A_ScriptDir)
        UpdateStatus("🎮 MacroMaster Analytics Dashboard opened in browser")

    } catch Error as e {
        MsgBox("❌ Failed to launch analytics dashboard: " . e.Message . "`n`nPlease ensure Python is installed and accessible from command line.", "Error", "Icon!")
        UpdateStatus("❌ Analytics dashboard failed")
    }
}

; ===== DAILY RESET FUNCTIONS =====

; Reset daily stats display function
ResetDailyStatsDisplay(statsGui) {
    ; Close stats GUI and show intuitive daily reset dialog
    statsGui.Destroy()
    ShowIntuitiveDailyResetDialog()
}

ShowIntuitiveDailyResetDialog() {
    ; CLEAR, USER-FRIENDLY DAILY RESET
    
    resetGui := Gui("+AlwaysOnTop", "📅 Daily Reset - Start Fresh Day")
    resetGui.SetFont("s11")
    
    ; Clear explanation
    resetGui.Add("Text", "x20 y20 w400 h40", "📅 DAILY RESET - START A FRESH DAY")
        .SetFont("s14 Bold", "cBlue")
    
    resetGui.Add("Text", "x20 y70 w400 h60", 
                 "This will start fresh daily tracking while preserving all your historical data.`n`n" .
                 "✅ Resets today's timing and JSON degradation counts`n" .
                 "✅ Keeps all your recorded macros and historical stats")
    
    ; Current day summary
    currentStats := GetTodayStats()
    resetGui.Add("Text", "x20 y140 w400 h20", "📊 Today's Progress:")
        .SetFont("s11 Bold")
    
    resetGui.Add("Text", "x30 y165 w400 h60", 
                 "• Executions: " . currentStats.executions . "`n" .
                 "• Boxes: " . currentStats.boxes . "`n" .
                 "• Time Active: " . currentStats.activeTime . "`n" .
                 "• JSON Degradations: " . currentStats.jsonDegradations)
    
    ; Clear action buttons
    btnReset := resetGui.Add("Button", "x30 y240 w140 h35", "📅 Start Fresh Day")
    btnReset.SetFont("s11 Bold")
    btnReset.OnEvent("Click", (*) => ConfirmDailyReset(resetGui))
    
    btnCancel := resetGui.Add("Button", "x190 y240 w100 h35", "Cancel")
    btnCancel.OnEvent("Click", (*) => resetGui.Destroy())
    
    btnViewHistory := resetGui.Add("Button", "x310 y240 w110 h35", "📊 View History")
    btnViewHistory.OnEvent("Click", (*) => ViewHistoricalStats())
    
    resetGui.Show("w440 h295")
}

ConfirmDailyReset(parentGui) {
    parentGui.Destroy()
    
    ; Simple confirmation
    result := MsgBox("Start a fresh daily session?`n`nYour historical data will be preserved.", "Confirm Daily Reset", "YesNo Icon!")
    
    if (result = "Yes") {
        PerformIntuitiveDailyReset()
    }
}

PerformIntuitiveDailyReset() {
    global applicationStartTime, totalActiveTime, lastActiveTime, sessionId, dailyResetActive
    
    try {
        ; Mark day boundary in CSV
        MarkDayBoundary()
        
        ; Reset daily tracking
        applicationStartTime := A_TickCount
        totalActiveTime := 0
        lastActiveTime := A_TickCount
        dailyResetActive := true
        
        ; Create new session ID
        sessionId := "day_" . FormatTime(, "yyyyMMdd_HHmmss")
        
        ; Success feedback
        UpdateStatus("📅 Fresh daily session started - Previous data preserved")
        
        ; Show today's fresh stats
        ShowPythonStats()  ; Will automatically show "today" filter
        
    } catch Error as e {
        MsgBox("Daily reset failed: " . e.Message, "Error", "Icon!")
    }
}

; Helper function to get today's stats for display
GetTodayStats() {
    ; Read today's data from CSV for summary display
    return {
        executions: GetTodayExecutionCount(),
        boxes: GetTodayBoxCount(), 
        activeTime: FormatActiveTime(GetTodayActiveTime()),
        jsonDegradations: GetTodayJSONDegradationCount()
    }
}

GetTodayExecutionCount() {
    global masterStatsCSV, sessionId
    count := 0
    try {
        if (FileExist(masterStatsCSV)) {
            content := FileRead(masterStatsCSV, "UTF-8")
            lines := StrSplit(content, "`n")
            today := FormatTime(, "yyyy-MM-dd")
            for i, line in lines {
                if (i = 1 || Trim(line) = "") {
                    continue
                }
                cols := StrSplit(line, ",")
                if (cols.Length >= 1 && InStr(cols[1], today)) {
                    count++
                }
            }
        }
    } catch {
        ; Fallback to 0
    }
    return count
}

GetTodayBoxCount() {
    global masterStatsCSV
    count := 0
    try {
        if (FileExist(masterStatsCSV)) {
            content := FileRead(masterStatsCSV, "UTF-8")
            lines := StrSplit(content, "`n")
            today := FormatTime(, "yyyy-MM-dd")
            for i, line in lines {
                if (i = 1 || Trim(line) = "") {
                    continue
                }
                cols := StrSplit(line, ",")
                if (cols.Length >= 7 && InStr(cols[1], today) && IsNumber(cols[7])) {
                    count += Integer(cols[7])
                }
            }
        }
    } catch {
        ; Fallback to 0
    }
    return count
}

GetTodayActiveTime() {
    global totalActiveTime, breakMode, lastActiveTime
    return breakMode ? totalActiveTime : (totalActiveTime + (A_TickCount - lastActiveTime))
}

GetTodayJSONDegradationCount() {
    global masterStatsCSV
    count := 0
    try {
        if (FileExist(masterStatsCSV)) {
            content := FileRead(masterStatsCSV, "UTF-8")
            lines := StrSplit(content, "`n")
            today := FormatTime(, "yyyy-MM-dd")
            for i, line in lines {
                if (i = 1 || Trim(line) = "") {
                    continue
                }
                cols := StrSplit(line, ",")
                if (cols.Length >= 4 && InStr(cols[1], today) && cols[4] = "json_profile") {
                    count++
                }
            }
        }
    } catch {
        ; Fallback to 0
    }
    return count
}

ViewHistoricalStats() {
    ; Launch Python dashboard with all-time view
    ShowPythonStats()
}

MarkDayBoundary() {
    global masterStatsCSV, sessionId
    try {
        ; Add a boundary marker to CSV for day separation
        boundaryData := FormatTime(, "yyyy-MM-dd HH:mm:ss") . "," . sessionId . "," . A_UserName . ",day_boundary,DAY_BOUNDARY,0,0,0,none,none,none,0,false`n"
        FileAppend(boundaryData, masterStatsCSV, "UTF-8")
    } catch {
        ; Silent fail - not critical
    }
}

; Reset all stats from display function
ResetAllStatsFromDisplay(statsGui) {
    global masterStatsCSV, applicationStartTime, totalActiveTime, lastActiveTime, macroExecutionLog
    
    result := MsgBox("🗑️ RESET ALL STATISTICS?`n`nThis will:`n• Backup current CSV data`n• Clear all execution statistics`n• Reset all timers`n• Preserve your recorded macros`n`nThis action cannot be undone!", "Confirm Full Reset", "YesNo Icon!")
    
    if (result = "Yes") {
        try {
            ; Backup current CSV data before clearing
            currentTime := FormatTime(, "yyyy-MM-dd_HH-mm-ss")
            backupFile := StrReplace(masterStatsCSV, ".csv", "_FULL_RESET_BACKUP_" . currentTime . ".csv")
            if (FileExist(masterStatsCSV)) {
                FileCopy(masterStatsCSV, backupFile)
            }
            
            ; Clear CSV data by recreating with header only
            FileDelete(masterStatsCSV)
            InitializeCSVFile()
            
            ; Reset all timing variables
            applicationStartTime := A_TickCount
            totalActiveTime := 0
            lastActiveTime := A_TickCount
            clearDegradationCount := 0
            
            ; Clear legacy stats
            macroExecutionLog := []
            
            ; Close current stats and show success
            statsGui.Destroy()
            SplitPath(backupFile, &backupFileName)
            MsgBox("✅ FULL STATISTICS RESET COMPLETE!`n`n📁 Backup saved: " . backupFileName . "`n🔄 All timers reset`n📊 Fresh stats tracking started", "Reset Complete", "Icon!")
            
            UpdateStatus("🗑️ Full stats reset complete - All data backed up and cleared")
            
        } catch as e {
            MsgBox("❌ Error resetting stats: " . e.Message, "Reset Error", "Icon!")
        }
    }
}

; Export CSV data function
ExportCSVData() {
    global masterStatsCSV, workDir
    
    try {
        if (!FileExist(masterStatsCSV)) {
            MsgBox("No CSV data to export.", "Export Error", "Icon!")
            return
        }
        
        ; Create timestamped export
        timestamp := FormatTime(A_Now, "yyyyMMdd_HHmmss")
        exportFile := workDir . "\exported_stats_" . timestamp . ".csv"
        
        FileCopy(masterStatsCSV, exportFile)
        
        ; Open exported file
        Run("notepad.exe " . exportFile)
        
        UpdateStatus("📊 Exported stats to: " . exportFile)
    } catch Error as e {
        MsgBox("Export failed: " . e.Message, "Export Error", "Icon!")
    }
}

CreateTimingMetricsTabOriginal(statsGui, tabs) {
    tabs.UseTab(3)
    
    global applicationStartTime, totalActiveTime, breakMode, sessionId, macroExecutionLog
    
    ; Calculate timing metrics using original system data
    appUptime := (A_TickCount - applicationStartTime) / 1000 ; seconds
    uptimeFormatted := FormatActiveTime(A_TickCount - applicationStartTime)
    activeTimeFormatted := FormatActiveTime(totalActiveTime)
    
    ; Get stats from original macroExecutionLog
    totalExecutions := macroExecutionLog.Length
    totalBoxes := 0
    totalExecutionTime := 0
    
    for execution in macroExecutionLog {
        totalBoxes += execution.boundingBoxCount
        totalExecutionTime += execution.executionTime
    }
    
    content := "╔═══════════════════════════════════════════════════════════════════════════════╗`n"
    content .= "║                             ⏱️ TIMING METRICS                                ║`n"
    content .= "╚═══════════════════════════════════════════════════════════════════════════════╝`n`n"
    
    content .= "🕐 APPLICATION TIMING:`n"
    content .= "  • App Uptime: " . uptimeFormatted . "`n"
    content .= "  • Total Execution Time: " . FormatPreciseTime(totalExecutionTime) . "`n"
    content .= "  • Break Mode Status: " . (breakMode ? "🔴 ACTIVE" : "✅ INACTIVE") . "`n"
    if (sessionId != "") {
        content .= "  • Current Session ID: " . sessionId . "`n"
    }
    content .= "`n"
    
    ; Efficiency calculations using original data
    if (appUptime > 0 && totalExecutions > 0) {
        execPerMinute := Round(totalExecutions / (appUptime / 60), 2)
        boxesPerMinute := Round(totalBoxes / (appUptime / 60), 2)
        avgExecTime := Round(totalExecutionTime / totalExecutions, 1)
        
        content .= "📈 EFFICIENCY METRICS:`n"
        content .= "  • Total Executions: " . totalExecutions . "`n"
        content .= "  • Total Boxes: " . totalBoxes . "`n"
        content .= "  • Executions per Minute: " . execPerMinute . "`n"
        content .= "  • Boxes per Minute: " . boxesPerMinute . "`n"
        content .= "  • Average Execution Duration: " . avgExecTime . "ms`n"
        
        if (totalBoxes > 0) {
            avgBoxTime := Round(totalExecutionTime / totalBoxes, 1)
            content .= "  • Average Time per Box: ~" . avgBoxTime . "ms`n"
        }
        content .= "`n"
        
        ; Active time efficiency
        if (totalActiveTime > 0) {
            activeMinutes := totalActiveTime / 60000
            content .= "⚡ ACTIVE TIME EFFICIENCY:`n"
            content .= "  • Executions per Active Minute: " . Round(totalExecutions / activeMinutes, 2) . "`n"
            content .= "  • Boxes per Active Minute: " . Round(totalBoxes / activeMinutes, 2) . "`n"
            content .= "  • Active Time Utilization: " . Round((totalActiveTime / (A_TickCount - applicationStartTime)) * 100, 1) . "%`n"
        }
    } else {
        content .= "📈 EFFICIENCY METRICS:`n"
        content .= "  • No execution data available yet`n"
        content .= "  • Execute some macros to see timing metrics!`n"
    }
    
    editTiming := statsGui.Add("Edit", "x30 y120 w800 h450 ReadOnly VScroll", content)
    statsGui.editTiming := editTiming
}





CreateCondensedWASDTable(gui, startY, width) {
    ; ULTRA-CONDENSED WASD TABLE - MAXIMUM SPACE EFFICIENCY
    gui.Add("Text", "x40 y" . startY . " w300 h25", "🔧 WASD → Numpad Mapping")
        .SetFont("s12 Bold", "cNavy")
    
    tableY := startY + 35
    
    ; Compact table headers
    gui.Add("Text", "x60 y" . tableY . " w60 h20", "Key")
    gui.Add("Text", "x130 y" . tableY . " w60 h20", "→ Numpad")
    gui.Add("Text", "x210 y" . tableY . " w60 h20", "Key") 
    gui.Add("Text", "x280 y" . tableY . " w60 h20", "→ Numpad")
    gui.Add("Text", "x360 y" . tableY . " w60 h20", "Key")
    gui.Add("Text", "x430 y" . tableY . " w60 h20", "→ Numpad")
    
    ; Line separator
    gui.Add("Text", "x50 y" . (tableY + 25) . " w420 h1 +Background0x808080")
    
    ; 3-COLUMN ULTRA-COMPACT LAYOUT (4 rows instead of 12)
    keys := ["1", "2", "3", "q", "w", "e", "a", "s", "d", "z", "x", "c"]
    numpadOptions := ["N0", "N1", "N2", "N3", "N4", "N5", "N6", "N7", "N8", "N9", "N.", "N*"]
    
    gui.hotkeyDropdowns := Map()
    
    rowY := tableY + 35
    for i, key in keys {
        col := Mod(i-1, 3)  ; 0, 1, 2
        row := Floor((i-1) / 3)  ; 0, 1, 2, 3
        
        if (col = 0) {
            ; Column 1
            keyX := 60
            dropX := 130
        } else if (col = 1) {
            ; Column 2  
            keyX := 210
            dropX := 280
        } else {
            ; Column 3
            keyX := 360
            dropX := 430
        }
        
        y := rowY + (row * 28)
        
        ; Compact key display
        gui.Add("Text", "x" . keyX . " y" . y . " w40 h22 Center +Border", StrUpper(key))
        
        ; Ultra-compact dropdown
        dropdown := gui.Add("DropDownList", "x" . dropX . " y" . y . " w55 h22 Choose1", numpadOptions)
        
        ; Set current selection
        if (wasdHotkeyMap.Has(key)) {
            currentMapping := wasdHotkeyMap[key]
            fullNumpadOptions := ["Num0", "Num1", "Num2", "Num3", "Num4", "Num5", "Num6", "Num7", "Num8", "Num9", "NumDot", "NumMult"]
            for j, option in fullNumpadOptions {
                if (option = currentMapping) {
                    dropdown.Choose(j)
                    break
                }
            }
        }
        
        gui.hotkeyDropdowns[key] := dropdown
    }
    
    ; Compact control buttons
    buttonY := rowY + 120
    btnSave := gui.Add("Button", "x60 y" . buttonY . " w70 h28", "💾 Save")
    btnSave.SetFont("s9 Bold")
    btnSave.OnEvent("Click", (*) => SaveCondensedWASDMappings(gui))
    
    btnReset := gui.Add("Button", "x140 y" . buttonY . " w70 h28", "🔄 Reset")
    btnReset.SetFont("s9 Bold") 
    btnReset.OnEvent("Click", (*) => ResetCondensedWASDMappings(gui))
    
    btnTest := gui.Add("Button", "x220 y" . buttonY . " w70 h28", "🧪 Test")
    btnTest.SetFont("s9 Bold")
    btnTest.OnEvent("Click", (*) => TestWASDMappings(gui))
    
    return buttonY + 40
}


CreateConfigControlBar(gui, y, width) {
    ; HORIZONTAL CONTROL BAR
    btnHelp := gui.Add("Button", "x40 y" . y . " w80 h30", "❓ Help")
    btnHelp.SetFont("s10")
    btnHelp.OnEvent("Click", (*) => ShowHotkeyHelp())
    
    btnClose := gui.Add("Button", "x" . (width - 120) . " y" . y . " w80 h30", "✖️ Close")
    btnClose.SetFont("s10 Bold")
    btnClose.OnEvent("Click", (*) => gui.Destroy())
}

; ===== HELPER FUNCTION HANDLERS =====


ShowHotkeyHelp() {
    helpText := "
    (
    🎮 HOTKEY CONFIGURATION HELP
    
    Essential Hotkeys:
    • Record Toggle: Start/stop macro recording
    • Submit Image: Confirm and submit current annotations  
    • Direct Clear: Clear all bounding boxes immediately
    • Statistics: Show usage statistics and performance data
    • Break Mode: Toggle work break timer
    • Settings: Open this configuration dialog
    
    WASD Profile System:
    • Enable/Disable: Toggle CapsLock + WASD combinations
    • Mapping Table: Customize which WASD keys map to numpad
    • Preview: See current key assignments at a glance
    
    Advanced Features:
    • Layer Navigation: Switch between macro layers
    • Custom Mappings: Create unique key combinations
    • Profile Management: Save/load different configurations
    
    💡 Tips:
    • Use CapsLock + key for WASD profile hotkeys
    • All changes auto-save when applied
    • Use Ctrl+H to quickly toggle WASD profile
    • Test mappings before saving permanently
    )"
    
    MsgBox(helpText, "⌨️ Hotkey Configuration Help", "Icon!")
}

ToggleProfileInSettings(btnToggle, settingsGui) {
    ToggleHotkeyProfileInSettings(btnToggle, settingsGui)
}

SaveCondensedWASDMappings(gui) {
    global wasdHotkeyMap, hotkeyProfileActive
    
    try {
        ; Get mappings from dropdowns with validation
        newMappings := Map()
        keys := ["1", "2", "3", "q", "w", "e", "a", "s", "d", "z", "x", "c"]
        numpadOptions := ["Num0", "Num1", "Num2", "Num3", "Num4", "Num5", "Num6", "Num7", "Num8", "Num9", "NumDot", "NumMult"]
        usedMappings := Map()
        
        ; Collect all mappings and check for duplicates
        for key in keys {
            if (gui.hotkeyDropdowns.Has(key)) {
                dropdown := gui.hotkeyDropdowns[key]
                selectedIndex := dropdown.Value
                selectedMapping := numpadOptions[selectedIndex]
                
                ; Check for duplicate mappings
                if (usedMappings.Has(selectedMapping)) {
                    MsgBox("Duplicate mapping detected! Key '" . StrUpper(key) . "' and '" . StrUpper(usedMappings[selectedMapping]) . "' both map to " . selectedMapping . ". Please choose unique mappings.", "Mapping Error", "Icon!")
                    return
                }
                
                newMappings[key] := selectedMapping
                usedMappings[selectedMapping] := key
            }
        }
        
        ; Disable current WASD hotkeys if profile is active
        wasActive := hotkeyProfileActive
        if (wasActive) {
            hotkeyProfileActive := false
            SetupWASDHotkeys()  ; This will disable current hotkeys
        }
        
        ; Update global mapping
        wasdHotkeyMap := newMappings
        SaveWASDMappingsToFile()
        
        if (wasActive) {
            hotkeyProfileActive := true
            SetupWASDHotkeys()  ; Re-enable with new mappings
        }
        
        UpdateStatus("💾 WASD mappings saved successfully!")
        UpdateButtonLabelsWithWASD()  ; Refresh button labels
        
        MsgBox("✅ WASD Mappings Saved Successfully!`n`n" . keys.Length . " key combinations updated.`nUse Ctrl+H to toggle the profile.", "Settings Saved", "Icon!")
        
    } catch Error as e {
        MsgBox("Error saving WASD mappings: " . e.Message, "Error", "Icon!")
    }
}

ResetCondensedWASDMappings(gui) {
    ; Reset to default mappings
    defaultMappings := Map(
        "1", "Num7",
        "2", "Num8", 
        "3", "Num9",
        "q", "Num4",
        "w", "Num5",
        "e", "Num6", 
        "a", "Num1",
        "s", "Num2",
        "d", "Num3",
        "z", "Num0",
        "x", "NumDot",
        "c", "NumMult"
    )
    
    ; Update dropdowns
    keys := ["1", "2", "3", "q", "w", "e", "a", "s", "d", "z", "x", "c"]
    numpadOptions := ["Num0", "Num1", "Num2", "Num3", "Num4", "Num5", "Num6", "Num7", "Num8", "Num9", "NumDot", "NumMult"]
    
    for key in keys {
        if (gui.hotkeyDropdowns.Has(key)) {
            dropdown := gui.hotkeyDropdowns[key]
            defaultMapping := defaultMappings[key]
            
            for i, option in numpadOptions {
                if (option = defaultMapping) {
                    dropdown.Choose(i)
                    break
                }
            }
        }
    }
    
    UpdateStatus("🔄 WASD mappings reset to defaults")
}

TestWASDMappings(gui) {
    ; Apply mappings temporarily for testing (without saving)
    global wasdHotkeyMap, hotkeyProfileActive
    
    try {
        ; Get current mappings from dropdowns (same logic as save)
        newMappings := Map()
        keys := ["1", "2", "3", "q", "w", "e", "a", "s", "d", "z", "x", "c"]
        numpadOptions := ["Num0", "Num1", "Num2", "Num3", "Num4", "Num5", "Num6", "Num7", "Num8", "Num9", "NumDot", "NumMult"]
        usedMappings := Map()
        
        for key in keys {
            if (gui.hotkeyDropdowns.Has(key)) {
                dropdown := gui.hotkeyDropdowns[key]
                selectedIndex := dropdown.Value
                selectedMapping := numpadOptions[selectedIndex]
                
                if (usedMappings.Has(selectedMapping)) {
                    MsgBox("Duplicate mapping detected! Cannot test with duplicate mappings.", "Test Error", "Icon!")
                    return
                }
                
                newMappings[key] := selectedMapping
                usedMappings[selectedMapping] := key
            }
        }
        
        ; Store original mapping for restoration
        originalMapping := Map()
        for key, mapping in wasdHotkeyMap {
            originalMapping[key] := mapping
        }
        
        ; Apply new mappings temporarily
        wasdHotkeyMap := newMappings
        if (hotkeyProfileActive) {
            SetupWASDHotkeys()
        }
        
        UpdateStatus("🧪 Test mappings applied - try CapsLock + WASD keys")
        MsgBox("🧪 Test Mappings Applied!`n`nTry pressing CapsLock + your WASD keys to test the new mappings.`n`nMappings will revert when you close the settings or save new ones.", "Test Mode Active", "Icon!")
        
    } catch Error as e {
        MsgBox("Error testing WASD mappings: " . e.Message, "Error", "Icon!")
    }
}

; Enhanced hotkey profile functions for settings interface
ToggleHotkeyProfileInSettings(btnToggle, settingsGui) {
    global hotkeyProfileActive
    
    ; Store current window position before refresh
    settingsGui.GetPos(&x, &y)
    
    ; Toggle the profile (this already updates labels and saves config)
    ToggleHotkeyProfile()
    
    ; Update button text with icons
    btnToggle.Text := hotkeyProfileActive ? "🔴 Disable" : "🟢 Enable"
    
    ; Refresh settings to update status text and maintain position
    settingsGui.Destroy()
    ShowSettings()
    
    ; Try to restore position (may not work perfectly due to timing)
    try {
        WinMove(x, y, , , "⚙️ MacroMaster Settings")
    } catch {
        ; Position restoration failed, continue anyway
    }
    
    ; Additional status update for immediate feedback
    UpdateStatus(hotkeyProfileActive ? "🎹✅ Profile enabled - labels updated" : "🎹❌ Profile disabled - labels restored")
}


SaveWASDMappingsInSettings(settingsGui) {
    global wasdHotkeyMap, hotkeyProfileActive
    
    try {
        ; Get mappings from dropdowns with enhanced validation
        newMappings := Map()
        numpadOptions := ["Num0", "Num1", "Num2", "Num3", "Num4", "Num5", "Num6", "Num7", "Num8", "Num9", "NumDot", "NumMult"]
        keys := ["1", "2", "3", "q", "w", "e", "a", "s", "d", "z", "x", "c"]  ; Match the keys shown
        
        ; Collect all mappings with validation
        for key in keys {
            if (settingsGui.hotkeyDropdowns.Has(key)) {
                dropdown := settingsGui.hotkeyDropdowns[key]
                selectedIndex := dropdown.Value
                if (selectedIndex > 0 && selectedIndex <= numpadOptions.Length) {
                    newMappings[key] := numpadOptions[selectedIndex]
                } else {
                    throw Error("Invalid selection for key '" . key . "'")
                }
            }
        }
        
        ; Enhanced conflict detection with detailed reporting
        usedMappings := Map()
        conflictKeys := []
        for key, mapping in newMappings {
            if (usedMappings.Has(mapping)) {
                conflictKeys.Push("CapsLock+" . StrUpper(key) . " & CapsLock+" . StrUpper(usedMappings[mapping]) . " → " . mapping)
            }
            usedMappings[mapping] := key
        }
        
        if (conflictKeys.Length > 0) {
            MsgBox("❌ Mapping Conflicts Detected:`n`n" . conflictKeys.Length . " conflict(s):`n• " . conflictKeys.Join("`n• ") . "`n`nPlease assign unique numpad keys to each CapsLock combination.", "Save Failed", "Icon!")
            return
        }
        
        ; Safely update mappings
        wasActive := hotkeyProfileActive
        if (hotkeyProfileActive) {
            DisableWASDHotkeys()
            hotkeyProfileActive := false  ; Prevent interference during update
        }
        
        wasdHotkeyMap := newMappings
        SaveWASDMappingsToFile()
        
        if (wasActive) {
            hotkeyProfileActive := true
            SetupWASDHotkeys()
        }
        
        ; Enhanced success feedback
        UpdateStatus("💾✅ WASD mappings saved and applied successfully")
        MsgBox("✅ WASD Mappings Saved Successfully!`n`n" . keys.Length . " key combinations updated.`nUse Ctrl+H to toggle the profile.", "Settings Saved", "Icon!")
        
    } catch Error as e {
        ; Enhanced error reporting
        UpdateStatus("❌ Failed to save WASD mappings: " . e.Message)
        MsgBox("❌ Save Failed!`n`nError: " . e.Message . "`n`nPlease check your mappings and try again.", "Save Error", "Icon!")
    }
}

ResetWASDMappingsInSettings(settingsGui) {
    result := MsgBox("🔄 Reset all CapsLock+Key mappings to defaults?`n`nThis will restore:`n• CapsLock+1/2/3 → Num7/8/9`n• CapsLock+Q/W/E → Num4/5/6`n• CapsLock+A/S/D → Num1/2/3`n• CapsLock+Z/X/C → Num0/NumDot/NumMult", "Reset Mappings", "YesNo Icon?")
    
    if (result = "Yes") {
        try {
            ; Store window position before refresh
            settingsGui.GetPos(&x, &y)
            
            ; Reset to defaults
            InitializeWASDHotkeys()
            UpdateStatus("🔄✅ WASD mappings reset to defaults")
            
            ; Refresh settings to update dropdowns with position restore
            settingsGui.Destroy()
            ShowSettings()
            
            ; Try to restore position
            try {
                WinMove(x, y, , , "⚙️ MacroMaster Settings")
            } catch {
                ; Position restoration failed, continue anyway
            }
            
            MsgBox("✅ Mappings Reset Successfully!`n`nAll CapsLock combinations have been restored to default assignments.", "Reset Complete", "Icon!")
            
        } catch Error as e {
            UpdateStatus("❌ Failed to reset WASD mappings: " . e.Message)
            MsgBox("❌ Reset Failed!`n`nError: " . e.Message, "Reset Error", "Icon!")
        }
    }
}

ApplyWASDMappingsInSettings(settingsGui) {
    ; Enhanced apply function for testing mappings without saving
    global wasdHotkeyMap, hotkeyProfileActive
    
    try {
        ; Get mappings with validation (same as save function)
        newMappings := Map()
        numpadOptions := ["Num0", "Num1", "Num2", "Num3", "Num4", "Num5", "Num6", "Num7", "Num8", "Num9", "NumDot", "NumMult"]
        keys := ["1", "2", "3", "q", "w", "e", "a", "s", "d", "z", "x", "c"]
        
        ; Collect mappings with validation
        for key in keys {
            if (settingsGui.hotkeyDropdowns.Has(key)) {
                dropdown := settingsGui.hotkeyDropdowns[key]
                selectedIndex := dropdown.Value
                if (selectedIndex > 0 && selectedIndex <= numpadOptions.Length) {
                    newMappings[key] := numpadOptions[selectedIndex]
                } else {
                    throw Error("Invalid selection for key '" . key . "'")
                }
            }
        }
        
        ; Check for conflicts before applying
        usedMappings := Map()
        conflictKeys := []
        for key, mapping in newMappings {
            if (usedMappings.Has(mapping)) {
                conflictKeys.Push("CapsLock+" . StrUpper(key) . " & CapsLock+" . StrUpper(usedMappings[mapping]) . " → " . mapping)
            }
            usedMappings[mapping] := key
        }
        
        if (conflictKeys.Length > 0) {
            MsgBox("❌ Cannot Apply - Conflicts Detected:`n`n" . conflictKeys.Length . " conflict(s):`n• " . conflictKeys.Join("`n• ") . "`n`nPlease resolve conflicts before testing.", "Apply Failed", "Icon!")
            return
        }
        
        ; Temporarily apply changes for testing
        wasActive := hotkeyProfileActive
        if (hotkeyProfileActive) {
            DisableWASDHotkeys()
            hotkeyProfileActive := false
        }
        
        wasdHotkeyMap := newMappings
        
        if (wasActive) {
            hotkeyProfileActive := true
            SetupWASDHotkeys()
        }
        
        ; Enhanced feedback for testing
        UpdateStatus("🧪✅ WASD mappings applied for testing - changes NOT saved")
        MsgBox("🧪 Test Mode Applied!`n`n" . keys.Length . " key combinations updated for testing.`n`n⚠️ Changes are NOT saved to disk.`nUse Ctrl+H to toggle profile and test your mappings.`nUse 💾 Save button to persist changes.", "Test Applied", "Icon!")
        
    } catch Error as e {
        UpdateStatus("❌ Failed to apply WASD mappings: " . e.Message)
    }
}

; WASD Mapping Configuration Dialog (separate window for detailed configuration)
ShowWASDMappingDialog() {
    global wasdHotkeyMap, hotkeyProfileActive
    
    ; Create dedicated WASD mapping dialog
    wasdGui := Gui("+Resize", "🎹 WASD Mapping Configuration")
    wasdGui.SetFont("s10")
    
    ; Header
    wasdGui.Add("Text", "x20 y20 w400 h25 Center", "Configure CapsLock+Key → Numpad Mappings")
    wasdGui.SetFont("s9")
    
    ; Visual layout preview
    wasdGui.Add("Text", "x20 y55 w400 h15 c0x666666", "Layout Preview:  [1] [2] [3]    [Q] [W] [E]    [A] [S] [D]    [Z] [X] [C]")
    
    ; Store dropdown references
    wasdGui.hotkeyDropdowns := Map()
    numpadOptions := ["Num0", "Num1", "Num2", "Num3", "Num4", "Num5", "Num6", "Num7", "Num8", "Num9", "NumDot", "NumMult"]
    
    ; Create mapping interface
    y := 85
    keys := ["1", "2", "3", "q", "w", "e", "a", "s", "d", "z", "x", "c"]
    
    for i, key in keys {
        if (Mod(i-1, 3) = 0) {
            ; Start new row every 3 items
            if (i > 1) y += 30
            x := 20
        } else {
            x += 145
        }
        
        ; Key label showing CapsLock combination
        keyDisplay := "CapsLock+" . StrUpper(key)
        wasdGui.Add("Text", "x" . x . " y" . y . " w75 h20 Center", keyDisplay)
        wasdGui.Add("Text", "x" . (x+75) . " y" . y . " w15 h20 Center", "→")
        dropdown := wasdGui.Add("DropDownList", "x" . (x+90) . " y" . (y-2) . " w50 h22 Choose1", numpadOptions)
        
        ; Set current selection based on mapping
        if (wasdHotkeyMap.Has(key)) {
            currentMapping := wasdHotkeyMap[key]
            for j, option in numpadOptions {
                if (option = currentMapping) {
                    dropdown.Choose(j)
                    break
                }
            }
        }
        
        wasdGui.hotkeyDropdowns[key] := dropdown
    }
    
    ; Control buttons
    y += 40
    btnSave := wasdGui.Add("Button", "x20 y" . y . " w80 h30", "💾 Save")
    btnSave.OnEvent("Click", (*) => SaveWASDFromDialog(wasdGui))
    
    btnReset := wasdGui.Add("Button", "x110 y" . y . " w80 h30", "🔄 Reset")
    btnReset.OnEvent("Click", (*) => ResetWASDFromDialog(wasdGui))
    
    btnApply := wasdGui.Add("Button", "x200 y" . y . " w80 h30", "🧪 Apply")
    btnApply.OnEvent("Click", (*) => ApplyWASDFromDialog(wasdGui))
    
    btnClose := wasdGui.Add("Button", "x300 y" . y . " w80 h30", "Close")
    btnClose.OnEvent("Click", (*) => wasdGui.Destroy())
    
    ; Instructions
    y += 45
    wasdGui.Add("Text", "x20 y" . y . " w400 h40", "💡 Configure how CapsLock+Key combinations map to numpad keys.`nEach key must have a unique numpad assignment.")
    
    wasdGui.Show("w420 h" . (y + 50))
}

; Helper functions for WASD dialog
SaveWASDFromDialog(wasdGui) {
    global wasdHotkeyMap, hotkeyProfileActive
    
    try {
        ; Get mappings from dialog dropdowns
        newMappings := Map()
        numpadOptions := ["Num0", "Num1", "Num2", "Num3", "Num4", "Num5", "Num6", "Num7", "Num8", "Num9", "NumDot", "NumMult"]
        keys := ["1", "2", "3", "q", "w", "e", "a", "s", "d", "z", "x", "c"]
        
        ; Collect and validate mappings
        for key in keys {
            if (wasdGui.hotkeyDropdowns.Has(key)) {
                dropdown := wasdGui.hotkeyDropdowns[key]
                selectedIndex := dropdown.Value
                if (selectedIndex > 0 && selectedIndex <= numpadOptions.Length) {
                    newMappings[key] := numpadOptions[selectedIndex]
                }
            }
        }
        
        ; Update global mappings and save
        wasdHotkeyMap := newMappings
        SaveConfig()
        
        ; Apply if profile is active
        if (hotkeyProfileActive) {
            SetupWASDHotkeys()
        }
        
        UpdateStatus("💾✅ WASD mappings saved successfully")
        MsgBox("✅ WASD Mappings Saved!", "Success", "Icon!")
        wasdGui.Destroy()
        
    } catch Error as e {
        UpdateStatus("❌ Failed to save WASD mappings: " . e.Message)
        MsgBox("❌ Save Failed: " . e.Message, "Error", "Icon!")
    }
}

ResetWASDFromDialog(wasdGui) {
    result := MsgBox("Reset all mappings to defaults?", "Reset Mappings", "YesNo Icon?")
    if (result = "Yes") {
        InitializeWASDHotkeys()
        UpdateStatus("🔄✅ WASD mappings reset to defaults")
        wasdGui.Destroy()
        ShowWASDMappingDialog()  ; Reopen with defaults
    }
}

ApplyWASDFromDialog(wasdGui) {
    global wasdHotkeyMap, hotkeyProfileActive
    
    try {
        ; Get mappings from dialog (same logic as save)
        newMappings := Map()
        numpadOptions := ["Num0", "Num1", "Num2", "Num3", "Num4", "Num5", "Num6", "Num7", "Num8", "Num9", "NumDot", "NumMult"]
        keys := ["1", "2", "3", "q", "w", "e", "a", "s", "d", "z", "x", "c"]
        
        for key in keys {
            if (wasdGui.hotkeyDropdowns.Has(key)) {
                dropdown := wasdGui.hotkeyDropdowns[key]
                selectedIndex := dropdown.Value
                if (selectedIndex > 0) {
                    newMappings[key] := numpadOptions[selectedIndex]
                }
            }
        }
        
        ; Temporarily apply mappings (don't save)
        wasdHotkeyMap := newMappings
        if (hotkeyProfileActive) {
            SetupWASDHotkeys()
        }
        
        UpdateStatus("🧪✅ WASD mappings applied for testing (not saved)")
        MsgBox("🧪 Test Mode Applied!`nChanges applied but NOT saved.`nUse Save button to persist.", "Test Applied", "Icon!")
        
    } catch Error as e {
        UpdateStatus("❌ Failed to apply mappings: " . e.Message)
    }
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
    ; InitializeOfflineStorage()  ; DISABLED - CSV only approach
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
    
    ; Ensure minimum display of 1m to prevent 0m
    if (totalMinutes <= 0) {
        return "1m"
    }
    
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

; Precise time formatting for execution time tracking
FormatPreciseTime(timeMs) {
    if (timeMs < 1000) {
        ; Less than 1 second - show milliseconds
        return Round(timeMs, 0) . "ms"
    } else if (timeMs < 60000) {
        ; Less than 1 minute - show seconds with 1 decimal place
        seconds := Round(timeMs / 1000, 1)
        return seconds . "s"
    } else if (timeMs < 3600000) {
        ; Less than 1 hour - show minutes and seconds
        minutes := Floor(timeMs / 60000)
        seconds := Round((timeMs - minutes * 60000) / 1000, 0)
        return minutes . "m " . seconds . "s"
    } else {
        ; 1 hour or more - show hours, minutes, seconds
        hours := Floor(timeMs / 3600000)
        remainingMs := timeMs - hours * 3600000
        minutes := Floor(remainingMs / 60000)
        seconds := Round((remainingMs - minutes * 60000) / 1000, 0)
        return hours . "h " . minutes . "m " . seconds . "s"
    }
}

; ===== TAB CREATION FUNCTIONS =====
CreateRecordedMacrosTab(statsGui, tabs, timeFilter) {
    tabs.UseTab(1)
    
    filteredExecutions := FilterExecutionsByTime(timeFilter)
    macroExecutions := []
    
    ; Filter only recorded macro executions
    for execution in filteredExecutions {
        if (execution.category = "macro") {
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
            
            ; Count degradations from perBoxSummary if detailedBoxes not available
            if (execution.HasOwnProp("detailedBoxes") && execution.detailedBoxes.Length > 0) {
                for box in execution.detailedBoxes {
                    if (degradationCounts.Has(box.degradationName)) {
                        degradationCounts[box.degradationName]++
                    }
                }
            } else if (execution.perBoxSummary && execution.perBoxSummary != "" && execution.perBoxSummary != "JSON: Rain (High)") {
                ; Parse perBoxSummary directly for degradation counts
                try {
                    summaryParts := StrSplit(execution.perBoxSummary, ", ")
                    if (summaryParts) {
                        for index, part in summaryParts {
                            if (part && RegExMatch(part, "(\d+)x(.+)", &degradMatch)) {
                                count := Integer(degradMatch[1])
                                degradationName := degradMatch[2]
                                if (degradationCounts.Has(degradationName)) {
                                    degradationCounts[degradationName] += count
                                }
                            }
                        }
                    }
                } catch as e {
                    ; Skip if parsing fails
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
    
    ; Use CSV data instead of macroExecutionLog
    csvStats := ReadStatsFromCSV(false) ; Get all-time stats for persistence
    
    ; Build combined overview with better formatting
    content := "╔═══════════════════════════════════════════════════════════════════════════════╗`n"
    content .= "║                          📊 COMBINED USAGE OVERVIEW                          ║`n"
    content .= "║                              (" . timeFilter . ")                                    ║`n"
    content .= "╚═══════════════════════════════════════════════════════════════════════════════╝`n`n"
    content .= "📄 TOTAL EXECUTIONS: " . csvStats["total_executions"] . " operations`n`n"
    
    ; Use CSV stats data
    totalBoxes := csvStats["total_boxes"]
    macroCount := csvStats["total_executions"] ; Simplified - could separate macro vs JSON later
    jsonCount := 0 ; Would need to enhance CSV parsing to separate these
    
    content .= "┌──────────────────────────────────────────────────────────────────────────────┐`n"
    content .= "│                        📊 EXECUTION TYPE BREAKDOWN                          │`n"
    content .= "└──────────────────────────────────────────────────────────────────────────────┘`n"
    content .= "🎬 Recorded Macros: " . macroCount . " executions (" . totalBoxes . " total boxes)`n"
    content .= "📋 JSON Profiles: " . jsonCount . " executions`n"
    content .= "📊 Most Used Button: " . csvStats["most_used_button"] . "`n"
    content .= "🔄 Most Active Layer: " . csvStats["most_active_layer"] . "`n"
    content .= "⏱️ Average Execution Time: " . csvStats["average_execution_time"] . "ms`n"
    content .= "📈 Boxes per Hour: " . csvStats["boxes_per_hour"] . "`n"
    content .= "🚀 Executions per Hour: " . csvStats["executions_per_hour"] . "`n`n"
    
    ; Add degradation breakdown from CSV
    if (csvStats["degradation_breakdown"].Count > 0) {
        content .= "┌──────────────────────────────────────────────────────────────────────────────┐`n"
        content .= "│                         🎯 DEGRADATION BREAKDOWN                            │`n"
        content .= "└──────────────────────────────────────────────────────────────────────────────┘`n"
        
        for degradation, count in csvStats["degradation_breakdown"] {
            content .= "• " . StrTitle(degradation) . ": " . count . " boxes`n"
        }
        content .= "`n"
    }
    
    ; Add efficiency metrics from CSV data
    if (totalBoxes > 0 && macroCount > 0) {
        avgBoxesPerMacro := Round(totalBoxes / macroCount, 1)
        content .= "📦 Average Boxes per Macro: " . avgBoxesPerMacro . " boxes`n"
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
        ; SaveExecutionData()  ; DISABLED - CSV only approach
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
            
            ; CRITICAL: Ensure degradationAssignments is set for JSON profiles
            executionRecord.degradationAssignments := degradationName
        }
    }
    
    ; Add to execution log
    macroExecutionLog.Push(executionRecord)
    
    ; Save data
    ; SaveExecutionData()  ; DISABLED - CSV only approach
    
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
    ; DISABLED - CSV only approach - function kept for compatibility
    return
}

LoadExecutionData() {
    global workDir, macroExecutionLog
    
    try {
        logFile := workDir . "\macro_execution_log.json"
        
        if (!FileExist(logFile)) {
            macroExecutionLog := [] ; Initialize empty if no file
            return
        }
        
        ; Read and parse JSON file
        jsonContent := FileRead(logFile, "UTF-8")
        
        ; Clear existing log
        macroExecutionLog := []
        
        ; Parse JSON manually (since we have simple format)
        ; Look for execution records in the JSON
        if (RegExMatch(jsonContent, 's)\[(.*)\]', &matches)) {
            jsonArray := matches[1]
            
            ; Extract each execution object
            pos := 1
            while (pos := RegExMatch(jsonArray, 's)"id":\s*(\d+).*?"timestamp":\s*"([^"]*)".*?"button":\s*"([^"]*)".*?"layer":\s*(\d+).*?"mode":\s*"([^"]*)".*?"boundingBoxCount":\s*(\d+).*?"executionTime":\s*(\d+).*?"category":\s*"([^"]*)".*?"severity":\s*"([^"]*)".*?"perBoxSummary":\s*"([^"]*)"', &match, pos)) {
                
                ; Create execution record with minimum required properties
                execution := {
                    id: Integer(match[1]),
                    timestamp: match[2],
                    button: match[3],
                    layer: Integer(match[4]),
                    mode: match[5],
                    boundingBoxCount: Integer(match[6]),
                    executionTime: Integer(match[7]),
                    category: match[8],
                    severity: match[9],
                    perBoxSummary: match[10],
                    degradationSummary: match[10],  ; Add degradationSummary as alias
                    boundingBoxes: [],              ; Initialize empty arrays
                    detailedBoxes: [],
                    taggedBoxes: 0,
                    untaggedBoxes: Integer(match[6])  ; Default all boxes to untagged
                }
                
                macroExecutionLog.Push(execution)
                pos += StrLen(match[0])
            }
        }
        
        ; Update status with loaded count
        if (macroExecutionLog.Length > 0) {
            UpdateStatus("📊 Loaded " . macroExecutionLog.Length . " execution records from persistent storage")
        }
        
    } catch as e {
        ; Silently handle errors - don't break the application
        macroExecutionLog := [] ; Ensure it's initialized
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
                    button := event.HasProp("button") ? event.button : "left"
                    stateContent .= macroName . "=mouseDown," . event.x . "," . event.y . "," . button . "`n"
                }
                else if (event.type = "mouseUp") {
                    button := event.HasProp("button") ? event.button : "left"
                    stateContent .= macroName . "=mouseUp," . event.x . "," . event.y . "," . button . "`n"
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
                        left: (parts.Length > 1 && IsNumber(parts[2])) ? Integer(parts[2]) : 0,
                        top: (parts.Length > 2 && IsNumber(parts[3])) ? Integer(parts[3]) : 0,
                        right: (parts.Length > 3 && IsNumber(parts[4])) ? Integer(parts[4]) : 0,
                        bottom: (parts.Length > 4 && IsNumber(parts[5])) ? Integer(parts[5]) : 0
                    }
                }
                else if (parts[1] = "jsonAnnotation" && parts.Length >= 4) {
                    event := {
                        type: "jsonAnnotation",
                        mode: parts[2],
                        categoryId: (parts.Length > 2 && IsNumber(parts[3])) ? Integer(parts[3]) : 1,
                        severity: parts[4],
                        annotation: BuildJsonAnnotation(parts[2], (parts.Length > 2 && IsNumber(parts[3])) ? Integer(parts[3]) : 1, parts[4])
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
                        x: (parts.Length > 1 && IsNumber(parts[2])) ? Integer(parts[2]) : 0,
                        y: (parts.Length > 2 && IsNumber(parts[3])) ? Integer(parts[3]) : 0,
                        button: parts[4]
                    }
                }
                else if (parts[1] = "mouseUp" && parts.Length >= 4) {
                    event := {
                        type: "mouseUp",
                        x: (parts.Length > 1 && IsNumber(parts[2])) ? Integer(parts[2]) : 0,
                        y: (parts.Length > 2 && IsNumber(parts[3])) ? Integer(parts[3]) : 0,
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
    global boxDrawDelay, mouseClickDelay, mouseDragDelay, mouseReleaseDelay, betweenBoxDelay, keyPressDelay, focusDelay, mouseHoverDelay
    
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
            case "mouseHoverDelay":
                mouseHoverDelay := value
        }
        
        ; Save configuration
        SaveConfig()
        UpdateStatus("⚡ Updated " . variableName . " to " . value . "ms")
        
    } catch {
        UpdateStatus("⚠️ Invalid timing value")
    }
}

ApplyTimingPreset(preset, settingsGui) {
    global boxDrawDelay, mouseClickDelay, mouseDragDelay, mouseReleaseDelay, betweenBoxDelay, keyPressDelay, focusDelay, mouseHoverDelay
    
    switch preset {
        case "fast":
            boxDrawDelay := 55
            mouseClickDelay := 70
            mouseDragDelay := 75
            mouseReleaseDelay := 75
            betweenBoxDelay := 150
            keyPressDelay := 15
            focusDelay := 90
            mouseHoverDelay := 25  ; Fast hover
            
        case "default":
            boxDrawDelay := 75
            mouseClickDelay := 85
            mouseDragDelay := 90
            mouseReleaseDelay := 90
            betweenBoxDelay := 200
            keyPressDelay := 20
            focusDelay := 110
            mouseHoverDelay := 35  ; Default hover
            
        case "safe":
            boxDrawDelay := 110
            mouseClickDelay := 130
            mouseDragDelay := 140
            mouseReleaseDelay := 140
            betweenBoxDelay := 300
            keyPressDelay := 30
            focusDelay := 170
            mouseHoverDelay := 50  ; Safe hover
            
        case "slow":
            boxDrawDelay := 150
            mouseClickDelay := 180
            mouseDragDelay := 190
            mouseReleaseDelay := 190
            betweenBoxDelay := 450
            keyPressDelay := 45
            focusDelay := 270
            mouseHoverDelay := 75  ; Slow hover
    }
    
    ; Update all GUI controls to reflect new values
    UpdateTimingControls(settingsGui)
    
    ; Save configuration
    SaveConfig()
    
    UpdateStatus("🎚️ Applied " . StrTitle(preset) . " timing preset - all controls updated")
}

; Update all timing controls in the settings GUI using stored references
UpdateTimingControls(settingsGui) {
    global boxDrawDelay, mouseClickDelay, mouseDragDelay, mouseReleaseDelay, betweenBoxDelay, keyPressDelay, focusDelay, mouseHoverDelay
    
    ; Update all controls using stored references (much more reliable)
    try {
        ; Update each control if it exists
        if (settingsGui.HasOwnProp("boxDelayEdit"))
            settingsGui.boxDelayEdit.Text := boxDrawDelay
        if (settingsGui.HasOwnProp("clickDelayEdit"))
            settingsGui.clickDelayEdit.Text := mouseClickDelay
        if (settingsGui.HasOwnProp("dragDelayEdit"))
            settingsGui.dragDelayEdit.Text := mouseDragDelay
        if (settingsGui.HasOwnProp("releaseDelayEdit"))
            settingsGui.releaseDelayEdit.Text := mouseReleaseDelay
        if (settingsGui.HasOwnProp("betweenDelayEdit"))
            settingsGui.betweenDelayEdit.Text := betweenBoxDelay
        if (settingsGui.HasOwnProp("keyDelayEdit"))
            settingsGui.keyDelayEdit.Text := keyPressDelay
        if (settingsGui.HasOwnProp("focusDelayEdit"))
            settingsGui.focusDelayEdit.Text := focusDelay
        if (settingsGui.HasOwnProp("hoverDelayEdit"))
            settingsGui.hoverDelayEdit.Text := mouseHoverDelay
        
        ; Force GUI redraw to show updated values
        settingsGui.Redraw()
        
    } catch Error as e {
        ; If control update fails, fall back to GUI recreation
        UpdateStatus("⚠️ Control update failed, recreating settings GUI")
        settingsGui.Destroy()
        ShowSettings()
    }
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
    global macroExecutionLog, masterStatsCSV, applicationStartTime, totalActiveTime, lastActiveTime
    
    result := MsgBox("Reset all statistics data?`n`nThis will backup and clear CSV data, reset timers, but preserve macros.", "Confirm Full Stats Reset", "YesNo Icon!")
    
    if (result = "Yes") {
        try {
            ; Backup current CSV data before clearing
            currentTime := FormatTime(, "yyyy-MM-dd_HH-mm-ss")
            backupFile := StrReplace(masterStatsCSV, ".csv", "_backup_" . currentTime . ".csv")
            if (FileExist(masterStatsCSV)) {
                FileCopy(masterStatsCSV, backupFile)
            }
            
            ; Clear CSV data by recreating with header only
            InitializeCSVFile()
            FileDelete(masterStatsCSV)
            InitializeCSVFile()
            
            ; Reset timing variables
            applicationStartTime := A_TickCount
            totalActiveTime := 0
            lastActiveTime := A_TickCount
            clearDegradationCount := 0
            
            ; Clear legacy stats
            macroExecutionLog := []
            
            SplitPath(backupFile, &backupFileName)
            UpdateStatus("📊 Full statistics reset complete - Data backed up to: " . backupFileName)
            
        } catch as e {
            MsgBox("Error resetting stats: " . e.Message, "Reset Error", "Icon!")
        }
        
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
    global wasdLabelsEnabled, hotkeyProfileActive
    global hotkeyRecordToggle, hotkeySubmit, hotkeyDirectClear, hotkeyEmergency, hotkeyBreakMode
    global hotkeyLayerPrev, hotkeyLayerNext, hotkeySettings, hotkeyStats
    
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
        
        ; Add WASD configuration section
        configContent .= "[WASD]`n"
        configContent .= "LabelsEnabled=" . (wasdLabelsEnabled ? "1" : "0") . "`n"
        configContent .= "HotkeyProfileActive=" . (hotkeyProfileActive ? "1" : "0") . "`n`n"
        
        ; Add hotkeys configuration section
        configContent .= "[Hotkeys]`n"
        configContent .= "RecordToggle=" . hotkeyRecordToggle . "`n"
        configContent .= "Submit=" . hotkeySubmit . "`n"
        configContent .= "DirectClear=" . hotkeyDirectClear . "`n"
        configContent .= "Emergency=" . hotkeyEmergency . "`n"
        configContent .= "BreakMode=" . hotkeyBreakMode . "`n"
        configContent .= "LayerPrev=" . hotkeyLayerPrev . "`n"
        configContent .= "LayerNext=" . hotkeyLayerNext . "`n"
        configContent .= "Settings=" . hotkeySettings . "`n"
        configContent .= "Stats=" . hotkeyStats . "`n`n"
        
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
    global wasdLabelsEnabled, hotkeyProfileActive
    global hotkeyRecordToggle, hotkeySubmit, hotkeyDirectClear, hotkeyEmergency, hotkeyBreakMode
    global hotkeyLayerPrev, hotkeyLayerNext, hotkeySettings, hotkeyStats
    
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
                        currentLayer := (value != "" && IsNumber(value)) ? Integer(value) : 1
                    } else if (key = "AnnotationMode") {
                        annotationMode := value
                    }
                } else if (currentSection = "Canvas") {
                    if (key = "UserCanvasLeft") {
                        userCanvasLeft := (value != "" && IsNumber(value)) ? Integer(value) : 0
                    } else if (key = "UserCanvasTop") {
                        userCanvasTop := (value != "" && IsNumber(value)) ? Integer(value) : 0
                    } else if (key = "UserCanvasRight") {
                        userCanvasRight := (value != "" && IsNumber(value)) ? Integer(value) : 0
                    } else if (key = "UserCanvasBottom") {
                        userCanvasBottom := (value != "" && IsNumber(value)) ? Integer(value) : 0
                    } else if (key = "IsCanvasCalibrated") {
                        isCanvasCalibrated := (value = "1")
                    } else if (key = "WideCanvasLeft") {
                        wideCanvasLeft := (value != "" && IsNumber(value)) ? Integer(value) : 0
                    } else if (key = "WideCanvasTop") {
                        wideCanvasTop := (value != "" && IsNumber(value)) ? Integer(value) : 0
                    } else if (key = "WideCanvasRight") {
                        wideCanvasRight := (value != "" && IsNumber(value)) ? Integer(value) : 0
                    } else if (key = "WideCanvasBottom") {
                        wideCanvasBottom := (value != "" && IsNumber(value)) ? Integer(value) : 0
                    } else if (key = "IsWideCanvasCalibrated") {
                        isWideCanvasCalibrated := (value = "1")
                    } else if (key = "NarrowCanvasLeft") {
                        narrowCanvasLeft := (value != "" && IsNumber(value)) ? Integer(value) : 0
                    } else if (key = "NarrowCanvasTop") {
                        narrowCanvasTop := (value != "" && IsNumber(value)) ? Integer(value) : 0
                    } else if (key = "NarrowCanvasRight") {
                        narrowCanvasRight := (value != "" && IsNumber(value)) ? Integer(value) : 0
                    } else if (key = "NarrowCanvasBottom") {
                        narrowCanvasBottom := (value != "" && IsNumber(value)) ? Integer(value) : 0
                    } else if (key = "IsNarrowCanvasCalibrated") {
                        isNarrowCanvasCalibrated := (value = "1")
                    }
                } else if (currentSection = "WASD") {
                    if (key = "LabelsEnabled") {
                        wasdLabelsEnabled := (value = "1")
                    } else if (key = "HotkeyProfileActive") {
                        hotkeyProfileActive := (value = "1")
                    }
                } else if (currentSection = "Hotkeys") {
                    if (key = "RecordToggle" && value != "") {
                        hotkeyRecordToggle := value
                    } else if (key = "Submit" && value != "") {
                        hotkeySubmit := value
                    } else if (key = "DirectClear" && value != "") {
                        hotkeyDirectClear := value
                    } else if (key = "Emergency" && value != "") {
                        hotkeyEmergency := value
                    } else if (key = "BreakMode" && value != "") {
                        hotkeyBreakMode := value
                    } else if (key = "LayerPrev" && value != "") {
                        hotkeyLayerPrev := value
                    } else if (key = "LayerNext" && value != "") {
                        hotkeyLayerNext := value
                    } else if (key = "Settings" && value != "") {
                        hotkeySettings := value
                    } else if (key = "Stats" && value != "") {
                        hotkeyStats := value
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
        
        ; Restore WASD state and setup hotkeys if needed
        if (hotkeyProfileActive) {
            SetupWASDHotkeys()
        }
        
        ; REMOVED: Standalone WASD hotkeys to prevent typing interference
        ; WASD hotkeys now ONLY work with CapsLock modifier (CapsLock & key)
        
        ; Update labels based on loaded WASD state
        UpdateButtonLabelsWithWASD()
        
        ; Update grid outline to reflect WASD mode state
        UpdateGridOutlineColor()
        
        RefreshAllButtonAppearances()  ; Refresh again to show WASD labels
        
        ; Update emergency button text to reflect loaded hotkey
        UpdateEmergencyButtonText()
        
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
        ; SaveExecutionData()  ; DISABLED - CSV only approach
        
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
        
        ; Create CSV with exact 33-column header if file doesn't exist
        if (!FileExist(masterStatsCSV)) {
            header := "timestamp,session_id,username,execution_type,macro_name,layer,execution_time_ms,total_boxes,degradation_types,degradation_summary,status,application_start_time,total_active_time_ms,break_mode_active,break_start_time,total_executions,macro_executions_count,json_profile_executions_count,average_execution_time_ms,most_used_button,most_active_layer,recorded_total_boxes,degradation_breakdown_by_type_smudge,degradation_breakdown_by_type_glare,degradation_breakdown_by_type_splashes,macro_usage_execution_count,macro_usage_total_boxes,macro_usage_average_time_ms,macro_usage_last_used,json_severity_breakdown_by_level,json_degradation_type_breakdown,clear_degradation_count,boxes_per_hour,executions_per_hour`n"
            FileAppend(header, masterStatsCSV, "UTF-8")
        }
    } catch as e {
        ; Handle error gracefully without breaking the app
        ; Could add logging here if needed
    }
}

; Clean up corrupted time-based data from CSV (preserves all execution data)
CleanCorruptedTimeStats() {
    global masterStatsCSV
    
    try {
        if (!FileExist(masterStatsCSV)) {
            return
        }
        
        ; Read all lines
        content := FileRead(masterStatsCSV, "UTF-8")
        lines := StrSplit(content, "`n")
        
        ; Keep header intact
        cleanedContent := lines[1] . "`n"
        
        ; Process each data row
        for i, line in lines {
            if (i = 1 || Trim(line) = "") {
                continue ; Skip header and empty lines
            }
            
            cols := StrSplit(line, ",")
            if (cols.Length >= 32) {
                ; Clear corrupted time-based columns (31=boxes_per_hour, 32=executions_per_hour)
                ; Keep all execution data intact, only reset time calculations
                cols[31] := "0.0"  ; boxes_per_hour
                cols[32] := "0.0"  ; executions_per_hour
                
                ; Rebuild line
                cleanedLine := ""
                for j, col in cols {
                    if (j > 1) cleanedLine .= ","
                    cleanedLine .= col
                }
                cleanedContent .= cleanedLine . "`n"
            } else {
                ; Keep malformed lines as-is to avoid data loss
                cleanedContent .= line . "`n"
            }
        }
        
        ; Write cleaned content back
        FileDelete(masterStatsCSV)
        FileAppend(cleanedContent, masterStatsCSV, "UTF-8")
        
    } catch as e {
        ; Fail gracefully - don't break the app
    }
}

AppendToCSV(executionData) {
    global masterStatsCSV, sessionId, currentUsername, applicationStartTime, totalActiveTime, breakMode, clearDegradationCount
    global macroExecutionLog
    
    try {
        ; Calculate cumulative statistics
        csvStats := ReadStatsFromCSV(false)
        totalExecs := csvStats["total_executions"] + 1
        macroExecCount := csvStats["macro_executions_count"] + (executionData["execution_type"] = "macro" ? 1 : 0)
        jsonExecCount := csvStats["json_profile_executions_count"] + (executionData["execution_type"] = "json_profile" ? 1 : 0)
        clearExecCount := csvStats.Has("clear_executions_count") ? csvStats["clear_executions_count"] + (executionData["execution_type"] = "clear" ? 1 : 0) : (executionData["execution_type"] = "clear" ? 1 : 0)
        
        ; Calculate degradation breakdown
        smudgeCount := executionData.Has("smudge_count") ? executionData["smudge_count"] : 0
        glareCount := executionData.Has("glare_count") ? executionData["glare_count"] : 0  
        splashesCount := executionData.Has("splashes_count") ? executionData["splashes_count"] : 0
        
        ; Calculate rates per hour - require at least 5 seconds for meaningful rates
        if (totalActiveTime > 5000) { ; At least 5 seconds of active time
            activeTimeHours := totalActiveTime / 3600000
            boxesPerHour := Round(executionData["total_boxes"] / activeTimeHours, 1)
            execsPerHour := Round(totalExecs / activeTimeHours, 1)
        } else {
            ; Not enough active time for meaningful hourly rates
            boxesPerHour := 0
            execsPerHour := 0
        }
        
        ; Build complete 34-column CSV row to match header
        csvRow := executionData["timestamp"] . ","
                . sessionId . ","
                . currentUsername . ","
                . executionData["execution_type"] . ","
                . executionData["macro_name"] . ","
                . executionData["layer"] . ","
                . executionData["execution_time_ms"] . ","
                . executionData["total_boxes"] . ","
                . executionData["degradation_types"] . ","
                . executionData["degradation_summary"] . ","
                . executionData["status"] . ","
                . applicationStartTime . ","
                . totalActiveTime . ","
                . (breakMode ? "1" : "0") . ","
                . "" . ","  ; break_start_time
                . totalExecs . ","
                . macroExecCount . ","
                . jsonExecCount . ","
                . executionData["execution_time_ms"] . ","  ; average_execution_time_ms
                . executionData["macro_name"] . ","  ; most_used_button
                . executionData["layer"] . ","  ; most_active_layer
                . executionData["total_boxes"] . ","  ; recorded_total_boxes
                . smudgeCount . ","
                . glareCount . ","
                . splashesCount . ","
                . "1" . ","  ; macro_usage_execution_count
                . executionData["total_boxes"] . ","  ; macro_usage_total_boxes
                . executionData["execution_time_ms"] . ","  ; macro_usage_average_time_ms
                . executionData["timestamp"] . ","  ; macro_usage_last_used
                . (executionData.Has("severity_level") ? executionData["severity_level"] : "") . ","  ; json_severity_breakdown_by_level
                . executionData["degradation_types"] . ","  ; json_degradation_type_breakdown
                . clearDegradationCount . ","  ; clear_degradation_count
                . boxesPerHour . ","
                . execsPerHour . "`n"
        
        ; Append to CSV file
        FileAppend(csvRow, masterStatsCSV, "UTF-8")
    } catch as e {
        ; Handle file access errors gracefully
        ; Could add error logging if needed
    }
}

RecordExecutionStats(macroKey, executionStartTime, executionType, events, analysisRecord := "") {
    global breakMode, recording, playback, currentLayer, canvasType
    
    ; Skip if breakMode is true (don't track during break) - return early
    if (breakMode) {
        return
    }
    
    ; Note: We DO want to track completed executions, so removed playback check
    ; Only skip if recording to avoid tracking during macro recording
    
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
            ; Get degradation type from JSON annotation - try multiple sources
            if (analysisRecord.HasOwnProp("jsonDegradationName")) {
                degradation_assignments := analysisRecord.jsonDegradationName
            } else if (analysisRecord.HasOwnProp("degradationAssignments") && analysisRecord.degradationAssignments != "") {
                degradation_assignments := analysisRecord.degradationAssignments
            } else {
                degradation_assignments := "unknown"
            }
            severity_level := analysisRecord.HasOwnProp("severity") ? analysisRecord.severity : "medium"
        } else {
            bbox_count := 0
            degradation_assignments := "unknown"
            severity_level := "medium" ; Default fallback
        }
    }
    
    ; Create execution data structure for 31-column CSV
    executionData := Map()
    executionData["timestamp"] := timestamp
    executionData["execution_type"] := executionType
    executionData["macro_name"] := macroKey
    executionData["layer"] := layer
    executionData["execution_time_ms"] := execution_time_ms
    executionData["total_boxes"] := bbox_count
    executionData["degradation_types"] := degradation_assignments
    executionData["degradation_summary"] := degradation_assignments  ; simplified for now
    executionData["status"] := "completed"
    executionData["severity_level"] := severity_level
    
    ; PERFORMANCE GRADING - Add execution performance grade
    executionData["performance_grade"] := execution_time_ms <= 500 ? "A" : 
                                         execution_time_ms <= 1000 ? "B" : 
                                         execution_time_ms <= 2000 ? "C" : "D"
    
    ; Add degradation counts (mapping 1=smudge, 2=glare, 3=splashes, etc.)
    executionData["smudge_count"] := 0
    executionData["glare_count"] := 0
    executionData["splashes_count"] := 0
    
    ; Parse degradation assignments to count each type
    if (degradation_assignments != "") {
        degradationTypes := StrSplit(degradation_assignments, ",")
        for degradationType in degradationTypes {
            degradationType := Trim(degradationType)
            if (degradationType = "smudge") {
                executionData["smudge_count"]++
            } else if (degradationType = "glare") {
                executionData["glare_count"]++  
            } else if (degradationType = "splashes") {
                executionData["splashes_count"]++
            }
        }
    }
    
    ; Update active time before recording to CSV to ensure accurate time tracking
    UpdateActiveTime()
    
    ; Call updated AppendToCSV with data structure
    AppendToCSV(executionData)
}

; Record clear execution stats (NumpadEnter and Shift+Enter)
RecordClearDegradationExecution(buttonName, executionStartTime) {
    global breakMode, currentLayer, canvasType, clearDegradationCount
    
    ; Skip if breakMode is true (don't track during break)
    if (breakMode) {
        return
    }
    
    ; Calculate execution_time_ms
    execution_time_ms := A_TickCount - executionStartTime
    
    ; Get current timestamp
    timestamp := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    
    ; Create execution data structure for clear degradation execution
    executionData := Map()
    executionData["timestamp"] := timestamp
    executionData["execution_type"] := "macro"  ; This is a macro execution with clear degradation
    executionData["macro_name"] := buttonName
    executionData["layer"] := currentLayer
    executionData["execution_time_ms"] := execution_time_ms
    executionData["total_boxes"] := 1  ; Count as 1 box with clear degradation
    executionData["degradation_types"] := "clear"  ; Clear degradation type
    executionData["degradation_summary"] := "No degradation present"
    executionData["status"] := "submitted"
    executionData["severity_level"] := "none"
    
    ; Clear degradation counts (all zeros except clear count)
    executionData["smudge_count"] := 0
    executionData["glare_count"] := 0
    executionData["splashes_count"] := 0
    
    ; Increment session clear degradation count
    clearDegradationCount++
    
    ; Update active time before recording to CSV to ensure accurate time tracking
    UpdateActiveTime()
    
    ; Call AppendToCSV with clear execution data
    AppendToCSV(executionData)
}

ReadStatsFromCSV(filterBySession := false) {
    global masterStatsCSV, sessionId, totalActiveTime
    
    stats := Map()
    stats["total_executions"] := 0
    stats["macro_executions_count"] := 0
    stats["json_profile_executions_count"] := 0
    stats["clear_executions_count"] := 0
    stats["clear_degradation_count"] := 0
    stats["total_boxes"] := 0
    stats["boxes_per_hour"] := 0
    stats["executions_per_hour"] := 0
    stats["average_execution_time"] := 0
    stats["total_execution_time"] := 0
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
        
        ; Process data rows (skip header) - Updated for 31-column format
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
            if (fields.Length < 10) {
                continue ; Skip malformed rows - need at least basic fields
            }
            
            ; Process data based on filter setting
            if (!filterBySession || fields[2] = sessionId) {
                stats["total_executions"]++
                
                ; Parse fields from 34-column format
                ; timestamp,session_id,username,execution_type,macro_name,layer,execution_time_ms,total_boxes,degradation_types,degradation_summary,status,application_start_time,total_active_time_ms,break_mode_active,break_start_time,total_executions,macro_executions_count,json_profile_executions_count,average_execution_time_ms,most_used_button,most_active_layer,recorded_total_boxes,degradation_breakdown_by_type_smudge,degradation_breakdown_by_type_glare,degradation_breakdown_by_type_splashes,macro_usage_execution_count,macro_usage_total_boxes,macro_usage_average_time_ms,macro_usage_last_used,json_severity_breakdown_by_level,json_degradation_type_breakdown,clear_degradation_count,boxes_per_hour,executions_per_hour
                ; Parse basic fields with error handling
                try {
                    execution_type := fields[4]           ; execution_type
                    macro_name := fields[5]               ; macro_name
                    layer := IsNumber(fields[6]) ? Integer(fields[6]) : 1
                    execution_time := IsNumber(fields[7]) ? Integer(fields[7]) : 0
                    total_boxes := IsNumber(fields[8]) ? Integer(fields[8]) : 0
                    degradation_assignments := fields[9]  ; degradation_types
                    
                    ; For session time, try to use field 13 if available (shifted by 1), otherwise use execution_time
                    session_time := (fields.Length > 13 && IsNumber(fields[13])) ? Integer(fields[13]) : execution_time
                } catch {
                    continue ; Skip this row if parsing fails
                }
                
                ; Accumulate data
                executionTimes.Push(execution_time)
                totalBoxes += total_boxes
                stats["total_execution_time"] += execution_time
                
                ; For session-specific stats, use latest total active time from CSV
                ; For all-time stats, get the latest total active time (most recent record)
                if (filterBySession) {
                    ; For session filtering, use total_active_time_ms from current session
                    if (fields.Length > 12 && IsNumber(fields[12])) {
                        sessionActiveTime := Integer(fields[12]) ; total_active_time_ms from CSV
                    }
                } else {
                    ; For all-time stats, use the latest total_active_time_ms value
                    if (fields.Length > 12 && IsNumber(fields[12])) {
                        sessionActiveTime := Integer(fields[12]) ; Use latest total active time
                    }
                }
                
                ; Count buttons
                if (!buttonCount.Has(macro_name)) {
                    buttonCount[macro_name] := 0
                }
                buttonCount[macro_name]++
                
                ; Count layers
                if (!layerCount.Has(layer)) {
                    layerCount[layer] := 0
                }
                layerCount[layer]++
                
                ; Count execution types using the actual execution_type field
                if (execution_type = "clear") {
                    stats["clear_executions_count"]++
                } else if (execution_type = "json_profile") {
                    stats["json_profile_executions_count"]++
                } else {
                    stats["macro_executions_count"]++
                }
                
                ; Process degradation assignments
                if (degradation_assignments != "" && degradation_assignments != '""') {
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
        
        ; Get latest clear degradation count from last CSV row (field 31)
        if (lines.Length > 1) {
            lastLine := lines[lines.Length]
            if (Trim(lastLine) != "") {
                lastFields := StrSplit(lastLine, ",")
                if (lastFields.Length >= 31 && IsNumber(lastFields[31])) {
                    stats["clear_degradation_count"] := Integer(lastFields[31])
                }
            }
        }
        
        ; Calculate final stats
        stats["total_boxes"] := totalBoxes
        
        ; Calculate rates (boxes and executions per hour)
        ; Use the current session's total active time for accurate calculation
        if (sessionActiveTime > 5000) { ; Require at least 5 seconds of active time
            hoursActive := sessionActiveTime / 3600000 ; Convert ms to hours
            stats["boxes_per_hour"] := Round(totalBoxes / hoursActive, 1)
            stats["executions_per_hour"] := Round(stats["total_executions"] / hoursActive, 1)
        } else {
            ; Not enough active time for meaningful hourly rates
            stats["boxes_per_hour"] := 0
            stats["executions_per_hour"] := 0
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
    } else if (breakMode) {
        ; During break mode, don't accumulate active time but keep lastActiveTime updated
        lastActiveTime := A_TickCount
    }
}

AutoSave() {
    global breakMode, recording
    
    if (!recording && !breakMode) {
        SaveConfig()
        ; SaveExecutionData()  ; DISABLED - CSV only approach
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
        ; SaveExecutionData()  ; DISABLED - CSV only approach
        UpdateStatus("💾 Saved " . savedMacros . " macros")
        
        SafeUninstallMouseHook()
        SafeUninstallKeyboardHook()
        
        SetTimer(UpdateActiveTime, 0)
        SetTimer(AutoSave, 0)
        SetTimer(MonitorExecutionState, 0)
        
        Send("{LButton Up}{RButton Up}{MButton Up}")
        Send("{Shift Up}{Ctrl Up}{Alt Up}{Win Up}")
        
        SetMouseDelay(10)
        SetKeyDelay(10)
        
        UpdateStatus("💾 All data saved - Application closing")
        
    } catch Error as e {
        try {
            SaveConfig()
            ; SaveExecutionData()  ; DISABLED - CSV only approach
        } catch {
            SafeUninstallMouseHook()
            SafeUninstallKeyboardHook()
        }
    }
}

ShowWelcomeMessage() {
    UpdateStatus("📦 Draw boxes, press 1-9 to tag | F9: Record | All systems ready")
}

; ===== STATE RESET AND RECOVERY FUNCTIONS =====
; ===== EXECUTION STATE MONITORING =====
MonitorExecutionState() {
    global playback, recording, lastExecutionTime, playbackStartTime
    
    currentTime := A_TickCount
    
    ; Check for stuck playback state (longer than 30 seconds)
    if (playback) {
        if (!playbackStartTime) {
            playbackStartTime := currentTime
        } else if ((currentTime - playbackStartTime) > 30000) {
            UpdateStatus("⚠️ Detected stuck playback state - forcing reset")
            ForceStateReset()
            return
        }
    } else {
        playbackStartTime := 0
    }
    
    ; Check for stuck recording state (longer than 5 minutes)
    if (recording && lastExecutionTime && (currentTime - lastExecutionTime) > 300000) {
        UpdateStatus("⚠️ Detected stuck recording state - forcing reset")
        ForceStateReset()
        return
    }
}

ForceStateReset() {
    global recording, playback, awaitingAssignment, autoExecutionMode, lastExecutionTime, playbackStartTime
    
    ; Force reset all execution states
    recording := false
    playback := false
    awaitingAssignment := false
    lastExecutionTime := 0
    playbackStartTime := 0
    
    ; Stop any auto execution
    if (autoExecutionMode) {
        try {
            StopAutoExecution()
        } catch {
        }
    }
    
    ; Clean up all hooks and timers
    try {
        SafeUninstallMouseHook()
        SafeUninstallKeyboardHook()
        SetTimer(CheckForAssignment, 0)
    } catch {
    }
    
    ; Reset any stuck mouse/key states
    try {
        Send("{LButton Up}{RButton Up}{MButton Up}")
        Send("{Shift Up}{Ctrl Up}{Alt Up}{Win Up}")
    } catch {
    }
    
    UpdateStatus("🔄 State reset completed")
}

EmergencyStop() {
    global recording, playback, awaitingAssignment, mainGui, autoExecutionMode
    
    UpdateStatus("🚨 EMERGENCY STOP")
    
    ; Use the comprehensive state reset
    ForceStateReset()
    
    try {
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
    ; Sleep(500) - REMOVED: Between-execution delay for faster exit
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
        ; Track execution start time
        startTime := A_TickCount
        
        ; Sleep(focusDelay) - REMOVED for rapid labeling performance
        Send("+{Enter}")
        UpdateStatus("📤 Submitted")
        
        ; Record clear execution in CSV stats
        RecordClearDegradationExecution("NumpadEnter", startTime)
    } else {
        UpdateStatus("⚠️ No browser")
    }
}

; Direct Shift+Enter execution (manual clear)
DirectClearExecution() {
    global focusDelay
    browserFocused := false
    
    ; Track execution start time
    startTime := A_TickCount
    
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
        ; Sleep(focusDelay) - REMOVED for rapid labeling performance
        Send("+{Enter}")
        UpdateStatus("📤 Direct Clear Submitted")
        
        ; Record clear execution in CSV stats
        RecordClearDegradationExecution("ShiftEnter", startTime)
    } else {
        UpdateStatus("⚠️ No browser for direct clear")
    }
}

ShiftNumpadClearExecution(buttonName) {
    global focusDelay
    browserFocused := false
    
    ; Track execution start time
    startTime := A_TickCount
    
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
        ; Sleep(focusDelay) - REMOVED for rapid labeling performance
        Send("+{Enter}")
        UpdateStatus("📤 Clear: Shift+" . buttonName)
        
        ; Record clear execution in CSV stats with button name
        RecordClearDegradationExecution("Shift" . buttonName, startTime)
    } else {
        UpdateStatus("⚠️ No browser for Shift+" . buttonName . " clear")
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

; ===== HOTKEY SETTINGS FUNCTIONS =====
ApplyHotkeySettings(editRecordToggle, editSubmit, editDirectClear, editStats, editBreakMode, editSettings, editLayerPrev, editLayerNext, settingsGui) {
    global hotkeyRecordToggle, hotkeySubmit, hotkeyDirectClear, hotkeyStats, hotkeyBreakMode, hotkeySettings, hotkeyLayerPrev, hotkeyLayerNext
    
    try {
        ; Get new values from edit controls
        newRecordToggle := Trim(editRecordToggle.Text)
        newSubmit := Trim(editSubmit.Text)
        newDirectClear := Trim(editDirectClear.Text)
        newStats := Trim(editStats.Text)
        newBreakMode := Trim(editBreakMode.Text)
        newSettings := Trim(editSettings.Text)
        newLayerPrev := Trim(editLayerPrev.Text)
        newLayerNext := Trim(editLayerNext.Text)
        
        ; Basic validation - ensure no empty values
        if (newRecordToggle = "" || newSubmit = "" || newDirectClear = "" || newStats = "" || newBreakMode = "" || newSettings = "" || newLayerPrev = "" || newLayerNext = "") {
            MsgBox("All hotkey fields must be filled out.", "Invalid Hotkeys", "Icon!")
            return
        }
        
        ; Clear existing hotkeys before applying new ones
        try {
            Hotkey(hotkeyRecordToggle, "Off")
            Hotkey(hotkeySubmit, "Off")
            Hotkey(hotkeyDirectClear, "Off")
            Hotkey(hotkeyStats, "Off")
            Hotkey(hotkeyBreakMode, "Off")
            Hotkey(hotkeySettings, "Off")
            Hotkey(hotkeyLayerPrev, "Off")
            Hotkey(hotkeyLayerNext, "Off")
        } catch {
        }
        
        ; Update global variables
        hotkeyRecordToggle := newRecordToggle
        hotkeySubmit := newSubmit
        hotkeyDirectClear := newDirectClear
        hotkeyStats := newStats
        hotkeyBreakMode := newBreakMode
        hotkeySettings := newSettings
        hotkeyLayerPrev := newLayerPrev
        hotkeyLayerNext := newLayerNext
        
        ; Re-setup hotkeys
        SetupHotkeys()
        
        ; Update emergency button display
        UpdateEmergencyButtonText()
        
        ; Save to config
        SaveConfig()
        
        MsgBox("Hotkeys applied successfully!`n`nNew configuration:`nRecord: " . hotkeyRecordToggle . "`nSubmit: " . hotkeySubmit . "`nDirect Clear: " . hotkeyDirectClear . "`nStats: " . hotkeyStats . "`nBreak: " . hotkeyBreakMode . "`nSettings: " . hotkeySettings . "`nLayer Prev: " . hotkeyLayerPrev . "`nLayer Next: " . hotkeyLayerNext, "Hotkeys Updated", "Icon!")
        
    } catch Error as e {
        MsgBox("Failed to apply hotkeys: " . e.Message, "Error", "Icon!")
    }
}

ResetHotkeySettings(settingsGui) {
    global hotkeyRecordToggle, hotkeySubmit, hotkeyDirectClear, hotkeyStats, hotkeyBreakMode, hotkeySettings, hotkeyLayerPrev, hotkeyLayerNext
    
    result := MsgBox("Reset all hotkeys to defaults?`n`nRecord: F9`nSubmit: NumpadEnter`nDirect Clear: +Enter`nStats: F12`nBreak: ^b`nSettings: ^k`nLayer Prev: NumpadDiv`nLayer Next: NumpadSub", "Reset Hotkeys", "YesNo Icon?")
    
    if (result = "Yes") {
        ; Clear existing hotkeys
        try {
            Hotkey(hotkeyRecordToggle, "Off")
            Hotkey(hotkeySubmit, "Off")
            Hotkey(hotkeyDirectClear, "Off")
            Hotkey(hotkeyStats, "Off")
            Hotkey(hotkeyBreakMode, "Off")
            Hotkey(hotkeySettings, "Off")
            Hotkey(hotkeyLayerPrev, "Off")
            Hotkey(hotkeyLayerNext, "Off")
        } catch {
        }
        
        ; Reset to defaults
        hotkeyRecordToggle := "F9"
        hotkeySubmit := "NumpadEnter"
        hotkeyDirectClear := "+Enter"
        hotkeyStats := "F12"
        hotkeyBreakMode := "^b"
        hotkeySettings := "^k"
        hotkeyLayerPrev := "NumpadDiv"
        hotkeyLayerNext := "NumpadSub"
        
        ; Re-setup hotkeys
        SetupHotkeys()
        
        ; Save to config
        SaveConfig()
        
        ; Refresh settings GUI
        settingsGui.Destroy()
        ShowSettings()
        
        UpdateStatus("🎮 Hotkeys reset to defaults")
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
        ; SaveExecutionData()  ; DISABLED - CSV only approach
        
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
