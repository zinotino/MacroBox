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

; ===== LIVE STATS SYSTEM =====
global liveStatsGui := 0
global liveStatsTimer := 0
global liveStatsLastUpdate := 0

; ===== PERFORMANCE OPTIMIZATION =====
global hbitmapCache := Map()  ; Cache for HBITMAP visualizations

ClearHBitmapCacheForMacro(macroName) {
    global hbitmapCache
    ; Remove cache entries that contain the macro name
    keysToDelete := []
    for cacheKey, hbitmap in hbitmapCache {
        if (InStr(cacheKey, macroName)) {
            keysToDelete.Push(cacheKey)
            ; Clean up the HBITMAP
            if (hbitmap) {
                DllCall("DeleteObject", "Ptr", hbitmap)
            }
        }
    }
    for key in keysToDelete {
        hbitmapCache.Delete(key)
    }
}

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
; Store config in Documents\MacroMaster\data to match user requirement
global workDir := A_MyDocuments . "\MacroMaster\data"
global configFile := workDir . "\config.ini"
global documentsDir := A_MyDocuments . "\MacroMaster"  ; For thumbnails
global thumbnailDir := documentsDir . "\thumbnails"
global masterStatsCSV := workDir . "\master_stats.csv"

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
; Canvas variables are declared in Config.ahk

; Narrow mode: 4:3 aspect ratio (1440x1080 centered in 1920x1080)
; Legacy canvas (for backwards compatibility)
global lastCanvasDetection := ""

; ===== STREAMLINED STATS SYSTEM =====
; Legacy macroExecutionLog removed - using CSV-only approach
global macroStats := Map()
global severityBreakdown := Map()
global executionTimeLog := []
global totalExecutionTime := 0
global persistentStatsFile := documentsDir . "\persistent_stats.json"

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

; ===== CSV STATS SYSTEM - OPTIMIZED FOR PORTABLE EXECUTION =====
; Configure for Documents folder to work from zipped state
global sessionId := "sess_" . FormatTime(A_Now, "yyyyMMdd_HHmmss")
global currentUsername := A_UserName
global dailyResetActive := false
global sessionStartTime := 0
global clearDegradationCount := 0

; ===== CANVAS CALIBRATION FUNCTIONS =====
CalibrateCanvasArea() {
    global userCanvasLeft, userCanvasTop, userCanvasRight, userCanvasBottom, isCanvasCalibrated

    ; Prompt user to define canvas area
    result := MsgBox("Define your canvas area for accurate macro visualization.`n`nClick OK then:`n1. Click TOP-LEFT corner of your canvas`n2. Click BOTTOM-RIGHT corner of your canvas", "Canvas Calibration", "OKCancel")

    if (result = "Cancel") {
        return
    }

    UpdateStatus("📐 Canvas Calibration: Click TOP-LEFT corner...")

    ; Ensure mouse button is released before waiting for click
    KeyWait("LButton", "U")
    KeyWait("LButton", "D")
    MouseGetPos(&x1, &y1)

    ; Wait for button release to prevent double-detection
    KeyWait("LButton", "U")
    Sleep(200)  ; Brief pause between clicks

    UpdateStatus("📐 Canvas Calibration: Click BOTTOM-RIGHT corner...")

    ; Wait for second click
    KeyWait("LButton", "D")
    MouseGetPos(&x2, &y2)
    KeyWait("LButton", "U")

    ; Set canvas bounds
    userCanvasLeft := Min(x1, x2)
    userCanvasTop := Min(y1, y2)
    userCanvasRight := Max(x1, x2)
    userCanvasBottom := Max(y1, y2)

    canvasW := userCanvasRight - userCanvasLeft
    canvasH := userCanvasBottom - userCanvasTop

    if (canvasH = 0) {
        MsgBox("⚠️ Calibration failed: Selected area has zero height.`n`nPlease try again and select a valid area.", "Calibration Error", "Icon!")
        return
    }

    canvasAspect := Round(canvasW / canvasH, 2)

    ; Show confirmation dialog
    confirmMsg := "Canvas calibrated to:`n`nLeft: " . userCanvasLeft . "`nTop: " . userCanvasTop . "`nRight: " . userCanvasRight . "`nBottom: " . userCanvasBottom . "`nSize: " . canvasW . "x" . canvasH . "`nAspect Ratio: " . canvasAspect . ":1`n`nSave this configuration?"

    result := MsgBox(confirmMsg, "Confirm Canvas Calibration", "YesNo Icon?")

    if (result = "No") {
        UpdateStatus("🔄 Canvas calibration cancelled by user")
        return
    }

    ; Set calibration flag and save
    isCanvasCalibrated := true
    SaveConfig()

    UpdateStatus("✅ Canvas calibrated and saved: " . canvasW . "x" . canvasH . " (ratio: " . canvasAspect . ":1)")

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
        ; Save configuration to persist the reset
        SaveConfig()
    }
}

; ===== WIDE CANVAS CALIBRATION =====
CalibrateWideCanvasArea() {
    global wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom, isWideCanvasCalibrated

    ; Prompt user to define wide canvas area
    result := MsgBox("Calibrate 16:9 Wide Canvas Area`n`nThis is for WIDE mode recordings (full screen, widescreen).`n`nClick OK then:`n1. Click TOP-LEFT corner of your 16:9 area`n2. Click BOTTOM-RIGHT corner of your 16:9 area", "Wide Canvas Calibration", "OKCancel")

    if (result = "Cancel") {
        return
    }

    UpdateStatus("🔦 Wide Canvas (16:9): Click TOP-LEFT corner...")

    ; Ensure mouse button is released before waiting for click
    KeyWait("LButton", "U")
    KeyWait("LButton", "D")
    MouseGetPos(&x1, &y1)

    ; Wait for button release to prevent double-detection
    KeyWait("LButton", "U")
    Sleep(200)  ; Brief pause between clicks

    UpdateStatus("🔦 Wide Canvas (16:9): Click BOTTOM-RIGHT corner...")

    ; Get bottom-right corner
    KeyWait("LButton", "D")
    MouseGetPos(&x2, &y2)
    KeyWait("LButton", "U")

    ; Set wide canvas bounds
    wideCanvasLeft := Min(x1, x2)
    wideCanvasTop := Min(y1, y2)
    wideCanvasRight := Max(x1, x2)
    wideCanvasBottom := Max(y1, y2)
    isWideCanvasCalibrated := true

    ; Validate aspect ratio with divide-by-zero protection
    canvasW := wideCanvasRight - wideCanvasLeft
    canvasH := wideCanvasBottom - wideCanvasTop

    if (canvasH = 0) {
        MsgBox("⚠️ Calibration failed: Selected area has zero height.`n`nPlease try again and select a valid area.", "Calibration Error", "Icon!")
        return
    }

    aspectRatio := canvasW / canvasH

    ; Show confirmation dialog
    confirmMsg := "Canvas calibrated to:`n`nLeft: " . wideCanvasLeft . "`nTop: " . wideCanvasTop . "`nRight: " . wideCanvasRight . "`nBottom: " . wideCanvasBottom . "`nAspect Ratio: " . Round(aspectRatio, 2)

    if (Abs(aspectRatio - 1.777) > 0.1) {
        confirmMsg .= "`n`n⚠️ Aspect ratio is " . Round(aspectRatio, 2) . " (expected ~1.78 for 16:9)"
    } else {
        confirmMsg .= "`n`n✅ Aspect ratio matches 16:9"
    }

    confirmMsg .= "`n`nSave this configuration?"

    result := MsgBox(confirmMsg, "Confirm Wide Canvas Calibration", "YesNo Icon?")

    if (result = "No") {
        UpdateStatus("🔄 Wide canvas calibration cancelled by user")
        return
    }

    ; Set calibration flag and save
    isWideCanvasCalibrated := true
    SaveConfig()

    UpdateStatus("✅ Wide canvas (16:9) calibrated and saved: " . wideCanvasLeft . "," . wideCanvasTop . " to " . wideCanvasRight . "," . wideCanvasBottom)

    ; Refresh all button visualizations with new canvas
    RefreshAllButtonAppearances()
}

; ===== RESET WIDE CANVAS CALIBRATION =====
ResetWideCanvasCalibration() {
    global isWideCanvasCalibrated

    result := MsgBox("Reset Wide canvas calibration to automatic detection?", "Reset Wide Canvas", "YesNo")
    if (result = "Yes") {
        isWideCanvasCalibrated := false
        UpdateStatus("🔄 Wide canvas calibration reset - using automatic detection")
        RefreshAllButtonAppearances()
        ; Save configuration to persist the reset
        SaveConfig()
    }
}

; ===== RESET NARROW CANVAS CALIBRATION =====
ResetNarrowCanvasCalibration() {
    global isNarrowCanvasCalibrated

    result := MsgBox("Reset Narrow canvas calibration to automatic detection?", "Reset Narrow Canvas", "YesNo")
    if (result = "Yes") {
        isNarrowCanvasCalibrated := false
        UpdateStatus("🔄 Narrow canvas calibration reset - using automatic detection")
        RefreshAllButtonAppearances()
        ; Save configuration to persist the reset
        SaveConfig()
    }
}

; ===== NARROW CANVAS CALIBRATION =====
CalibrateNarrowCanvasArea() {
    global narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom, isNarrowCanvasCalibrated

    ; Prompt user to define narrow canvas area
    result := MsgBox("Calibrate 4:3 Narrow Canvas Area`n`nThis is for NARROW mode recordings (constrained, square-ish).`n`nClick OK then:`n1. Click TOP-LEFT corner of your 4:3 area`n2. Click BOTTOM-RIGHT corner of your 4:3 area", "Narrow Canvas Calibration", "OKCancel")

    if (result = "Cancel") {
        return
    }

    UpdateStatus("📱 Narrow Canvas (4:3): Click TOP-LEFT corner...")

    ; Ensure mouse button is released before waiting for click
    KeyWait("LButton", "U")
    KeyWait("LButton", "D")
    MouseGetPos(&x1, &y1)

    ; Wait for button release to prevent double-detection
    KeyWait("LButton", "U")
    Sleep(200)  ; Brief pause between clicks

    UpdateStatus("📱 Narrow Canvas (4:3): Click BOTTOM-RIGHT corner...")

    ; Get bottom-right corner
    KeyWait("LButton", "D")
    MouseGetPos(&x2, &y2)
    KeyWait("LButton", "U")

    ; Set narrow canvas bounds
    narrowCanvasLeft := Min(x1, x2)
    narrowCanvasTop := Min(y1, y2)
    narrowCanvasRight := Max(x1, x2)
    narrowCanvasBottom := Max(y1, y2)
    isNarrowCanvasCalibrated := true

    ; Validate aspect ratio with divide-by-zero protection
    canvasW := narrowCanvasRight - narrowCanvasLeft
    canvasH := narrowCanvasBottom - narrowCanvasTop

    if (canvasH = 0) {
        MsgBox("⚠️ Calibration failed: Selected area has zero height.`n`nPlease try again and select a valid area.", "Calibration Error", "Icon!")
        return
    }

    aspectRatio := canvasW / canvasH

    ; Show confirmation dialog
    confirmMsg := "Canvas calibrated to:`n`nLeft: " . narrowCanvasLeft . "`nTop: " . narrowCanvasTop . "`nRight: " . narrowCanvasRight . "`nBottom: " . narrowCanvasBottom . "`nAspect Ratio: " . Round(aspectRatio, 2)

    if (Abs(aspectRatio - 1.333) > 0.1) {
        confirmMsg .= "`n`n⚠️ Aspect ratio is " . Round(aspectRatio, 2) . " (expected ~1.33 for 4:3)"
    } else {
        confirmMsg .= "`n`n✅ Aspect ratio matches 4:3"
    }

    confirmMsg .= "`n`nSave this configuration?"

    result := MsgBox(confirmMsg, "Confirm Narrow Canvas Calibration", "YesNo Icon?")

    if (result = "No") {
        UpdateStatus("🔄 Narrow canvas calibration cancelled by user")
        return
    }

    ; Set calibration flag and save
    isNarrowCanvasCalibrated := true
    SaveConfig()

    UpdateStatus("✅ Narrow canvas (4:3) calibrated and saved: " . narrowCanvasLeft . "," . narrowCanvasTop . " to " . narrowCanvasRight . "," . narrowCanvasBottom)

    ; Refresh all button visualizations with new canvas
    RefreshAllButtonAppearances()
}

; ===== REAL-TIME DASHBOARD INTEGRATION =====
global ingestionServiceUrl := "http://localhost:5001"  ; Data ingestion service URL
global currentSessionId := "sess_" . FormatTime(A_Now, "yyyyMMdd_HHmmss")
global realtimeEnabled := true  ; Enable real-time data sending

; ===== PRODUCTION STATS SYSTEM GLOBALS =====
global statsQueue := []
global statsWorkerActive := false
global statsErrorCount := 0
global lastHealthCheck := 0
global systemHealthStatus := "healthy"

; ===== OFFLINE DATA STORAGE GLOBALS =====
global persistentDataFile := workDir . "\persistent_data.json"
global dailyStatsFile := workDir . "\daily_stats.json"
global offlineLogFile := workDir . "\offline_log.txt"
global dataQueue := []

; ===== UI CONFIGURATION =====
global windowWidth := 1200
global windowHeight := 800
global scaleFactor := 1.0
global minWindowWidth := 900
global minWindowHeight := 600

; ===== LAYER SYSTEM =====
global currentLayer := 1
global totalLayers := 5  ; Always ensure this is an integer
global layerNames := ["Base", "Advanced", "Tools", "Custom", "AUTO", "JSON", "Thumbnails", "Settings", "Layer9", "Layer10"]
global layerBorderColors := ["0x2D2D30", "0x505050", "0x6D6D70", "0x8D8D90", "0xA5A5A5", "0xADADAD", "0xBDBDBD", "0xCDCDCD", "0xDDDDDD", "0xEDEDED"]

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
global hotkeyProfileActive := true  ; Enable WASD hotkeys by default
global capsLockPressed := false
global wasdHotkeyMap := Map()








; ===== MACRO COUNTING =====
CountLoadedMacros() {
    global macroEvents, buttonNames, totalLayers

    macroCount := 0
    Loop Integer(totalLayers) {
        layer := A_Index
        for buttonName in buttonNames {
            layerMacroName := "L" . layer . "_" . buttonName
            if (macroEvents.Has(layerMacroName) && macroEvents[layerMacroName].Length > 0) {
                macroCount++
            }
        }
    }
    return macroCount
}

; ===== MAIN INITIALIZATION =====
Main() {
    try {
        ; Initialize core systems
        InitializeDirectories()
        InitializeConfigSystem()  ; Initialize config system and clean up locks
        InitializeVariables()
        InitializeCSVFile()
        InitializeStatsSystem()
        InitializeOfflineDataFiles()  ; Initialize offline data storage
        ; Legacy execution data loading removed - CSV system handles all stats
        InitializeJsonAnnotations()
        InitializeVisualizationSystem()  ; Initialize GDI+ BEFORE GUI creation
        InitializeWASDHotkeys()  ; Initialize WASD hotkey mappings

        ; Initialize real-time session
        InitializeRealtimeSession()

        ; Setup UI and interactions
        InitializeGui()
        SetupHotkeys()

        ; Load configuration (after GUI is created so mode toggle button can be updated)
        LoadConfig()

        ; Ensure totalLayers is always a valid integer after loading config
        global totalLayers := EnsureInteger(totalLayers, 5)
        if (totalLayers < 1 || totalLayers > 10) {
            global totalLayers := 5
        }

        ; Setup WASD hotkeys if profile is active (now enabled by default)
        if (hotkeyProfileActive) {
            SetupWASDHotkeys()
        }

        ; Check for canvas configuration and prompt new users
        CheckCanvasConfiguration()

        ; Count loaded macros
        loadedMacros := CountLoadedMacros()

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
        SetTimer(AutoSave, 30000)  ; Auto-save every 30 seconds for better persistence
        SetTimer(MonitorExecutionState, 15000)  ; Check for stuck states every 15 seconds
        SetTimer(ValidateConfigIntegrity, 120000)  ; Validate config integrity every 2 minutes

        ; Setup cleanup - use proper function reference for reliable exit handling
        OnExit((exitReason, exitCode) => CleanupAndExit())

        ; Show welcome message
        UpdateStatus("🚀 Ready - WASD hotkeys active (CapsLock+123qweasdzxc) - Real-time dashboard enabled - Currently in " . (annotationMode = "Wide" ? "🔦 WIDE MODE" : "📱 NARROW MODE") . " - F9 to record, F12 for dashboard")
        SetTimer(ShowWelcomeMessage, -2000)

    } catch Error as e {
        MsgBox("Initialization failed: " e.Message, "Startup Error", "Icon!")
        ExitApp
    }
}

CheckCanvasConfiguration() {
    global wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom
    global narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom
    global userCanvasLeft, userCanvasTop, userCanvasRight, userCanvasBottom
    global isWideCanvasCalibrated, isNarrowCanvasCalibrated

    ; Check if canvas coordinates are actually configured (not default values) or flags are set
    wideConfigured := (wideCanvasLeft != 0 || wideCanvasTop != 0 || wideCanvasRight != 1920 || wideCanvasBottom != 1080) || isWideCanvasCalibrated
    narrowConfigured := (narrowCanvasLeft != 240 || narrowCanvasTop != 0 || narrowCanvasRight != 1680 || narrowCanvasBottom != 1080) || isNarrowCanvasCalibrated
    userConfigured := (userCanvasLeft != 0 || userCanvasTop != 0 || userCanvasRight != 1920 || userCanvasBottom != 1080)

    ; Check if neither canvas is actually configured
    if (!wideConfigured && !narrowConfigured && !userConfigured) {
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
    global buttonNames
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
    global workDir, thumbnailDir, documentsDir

    ; Critical: Ensure work directory exists
    if !DirExist(workDir) {
        try {
            DirCreate(workDir)
            if !DirExist(workDir) {
                throw Error("Failed to create work directory: " . workDir)
            }
        } catch Error as e {
            MsgBox("CRITICAL ERROR: Cannot create data directory in Documents folder.`n`nPath: " . workDir . "`n`nError: " . e.Message . "`n`nThe program cannot store configuration data.", "Directory Creation Failed", "Icon!")
            ExitApp
        }
    }

    ; Verify Documents folder is accessible
    if !DirExist(documentsDir) {
        MsgBox("WARNING: Documents folder not found at: " . documentsDir . "`n`nUsing fallback path.", "Documents Folder Warning", "Icon!")
    }

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


; ===== JSON ANNOTATION SYSTEM =====
InitializeJsonAnnotations() {
    global jsonAnnotations, degradationTypes, severityLevels

    ; Clear any existing annotations
    jsonAnnotations := Map()

    ; Create annotations for all degradation types and severity levels in both modes
    for id, typeName in degradationTypes {
        for severity in severityLevels {
            ; Create Wide mode annotation
            presetName := StrTitle(typeName) . " (" . StrTitle(severity) . ")"
            jsonAnnotations[presetName] := BuildJsonAnnotation("Wide", id, severity)

            ; Create Narrow mode annotation
            jsonAnnotations[presetName . " Narrow"] := BuildJsonAnnotation("Narrow", id, severity)
        }
    }

    ; Assign JSON profiles to layer 6 buttons for immediate access
    AssignJsonProfilesToLayer6()

    UpdateStatus("📋 JSON annotations initialized for " . jsonAnnotations.Count . " presets")
}

BuildJsonAnnotation(mode, categoryId, severity) {
    global degradationTypes

    ; Map category ID to degradation type name
    degradationName := degradationTypes.Has(categoryId) ? degradationTypes[categoryId] : "unknown"

    ; Define preset coordinate values for wide and narrow modes based on actual labeling system format
    if (mode = "Wide") {
        ; Wide mode coordinates (larger canvas)
        x1 := -22.18
        y1 := -22.57
        x2 := 3808.41
        y2 := 2130.71
    } else {
        ; Narrow mode coordinates (smaller canvas)
        x1 := -23.54
        y1 := -23.12
        x2 := 1891.76
        y2 := 1506.66
    }

    ; Build JSON annotation in the actual labeling system format
    return '{"is3DObject":false,"segmentsAnnotation":{"attributes":{"severity":"' . severity . '"},"track_id":1,"type":"bbox","category_id":' . categoryId . ',"points":[[' . x1 . ',' . y1 . '],[' . x2 . ',' . y2 . ']]}}'
}

; ===== ASSIGN JSON PROFILES TO LAYER 6 =====
AssignJsonProfilesToLayer6() {
    global macroEvents, jsonAnnotations, degradationTypes

    ; Assign high severity JSON profiles to layer 6 buttons
    assignments := Map(
        "L6_Num7", "Smudge (high)",
        "L6_Num8", "Glare (high)",
        "L6_Num9", "Splashes (high)",
        "L6_Num4", "Partial_blockage (high)",
        "L6_Num5", "Full_blockage (high)",
        "L6_Num6", "Light_flare (high)",
        "L6_Num1", "Rain (high)",
        "L6_Num2", "Haze (high)",
        "L6_Num3", "Snow (high)",
        "L6_Num0", "Smudge (medium)",
        "L6_NumDot", "Glare (medium)",
        "L6_NumMult", "Splashes (medium)"
    )

    for layerButton, presetName in assignments {
        if (jsonAnnotations.Has(presetName)) {
            ; Parse categoryId and severity from presetName
            if (RegExMatch(presetName, "^(.+) \((.+)\)$", &match)) {
                typeName := StrLower(match[1])
                severity := StrLower(match[2])

                ; Find categoryId from typeName
                categoryId := 0
                for id, name in degradationTypes {
                    if (name = typeName) {
                        categoryId := id
                        break
                    }
                }

                if (categoryId > 0) {
                    macroEvents[layerButton] := [{
                        type: "jsonAnnotation",
                        annotation: jsonAnnotations[presetName],
                        mode: "Wide",
                        categoryId: categoryId,
                        severity: severity
                    }]
                }
            }
        }
    }

    UpdateStatus("✅ JSON profiles assigned to layer 6 buttons")
}

; ===== CLEANUP AND EXIT FUNCTIONS =====
CleanupAndExit() {
    global mouseHook, keyboardHook, liveStatsTimer, autoExecutionTimer

    try {
        ; Stop all timers
        SetTimer(UpdateActiveTime, 0)
        SetTimer(AutoSave, 0)
        SetTimer(MonitorExecutionState, 0)
        if (liveStatsTimer) {
            SetTimer(liveStatsTimer, 0)
        }
        if (autoExecutionTimer) {
            SetTimer(autoExecutionTimer, 0)
        }

        ; Uninstall hooks
        SafeUninstallMouseHook()
        SafeUninstallKeyboardHook()

        ; Save final state - CRITICAL: Ensure config saves before exit
        try {
            SaveConfig()
            UpdateStatus("✅ Configuration saved successfully on exit")
        } catch Error as saveError {
            ; CRITICAL: Show save errors instead of silent failure
            MsgBox("❌ CRITICAL: Failed to save configuration on exit: " . saveError.Message . "`n`nYour macros and settings may not persist.", "Save Error", "Icon!")
            ; Try one more time with minimal error handling
            try {
                SaveConfig()
            } catch {
                ; Final fallback - at least show the error
            }
        }

        ; Final stats update
        UpdateActiveTime()
        AggregateMetrics()

    } catch Error as e {
        MsgBox("⚠️ Error during cleanup: " . e.Message, "Cleanup Error", "Icon!")
    }
}

SafeExit() {
    CleanupAndExit()
    ExitApp
}

; ===== AUTO SAVE FUNCTION =====
AutoSave() {
    global breakMode, recording

    if (!recording && !breakMode) {
        try {
            SaveConfig()
        } catch Error as e {
            UpdateStatus("⚠️ Auto-save failed: " . e.Message)
        }
    }
}

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

; ===== STATE RESET FUNCTION =====
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

; ===== CONFIGURATION INTEGRITY VALIDATION =====
ValidateConfigIntegrity() {
    global configFile, workDir

    try {
        ; Only validate if config file exists
        if (!FileExist(configFile)) {
            return
        }

        ; Read config content
        content := FileRead(configFile, "UTF-8")

        ; Basic validation
        if (content = "") {
            UpdateStatus("⚠️ Configuration file is empty - will use defaults on next load")
            return
        }

        ; Check for basic structure
        if (!InStr(content, "[Settings]") && !InStr(content, "[Macros]")) {
            UpdateStatus("⚠️ Configuration file structure is invalid - will attempt recovery on next load")
            return
        }

        ; Check file size (too small or too large might indicate corruption)
        fileSize := FileGetSize(configFile)
        if (fileSize < 100) {
            UpdateStatus("⚠️ Configuration file is too small - may be corrupted")
            return
        }

        if (fileSize > 10485760) { ; 10MB limit
            UpdateStatus("⚠️ Configuration file is unusually large - may be corrupted")
            return
        }

        ; If we get here, config appears valid
        ; UpdateStatus("✅ Configuration integrity check passed")

    } catch Error as e {
        UpdateStatus("⚠️ Configuration integrity check failed: " . e.Message)
    }
}

; ===== EMERGENCY STOP =====
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

; ===== SUBMIT CURRENT IMAGE =====
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

; ===== SHIFT NUMPAD CLEAR EXECUTION =====
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

; ===== DIRECT CLEAR EXECUTION =====
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

; ===== PERSISTENCE SYSTEM TEST FUNCTION =====
TestPersistenceSystem() {
    global configFile, macroEvents, buttonNames, currentLayer, totalLayers

    UpdateStatus("🧪 Testing persistence system...")

    try {
        ; Create test macro data
        testMacroKey := "L1_Num7"
        testEvents := [
            {type: "boundingBox", left: 100, top: 100, right: 200, bottom: 200},
            {type: "keyDown", key: "a"},
            {type: "keyUp", key: "a"}
        ]

        ; Save original state
        originalEvents := []
        if (macroEvents.Has(testMacroKey)) {
            originalEvents := macroEvents[testMacroKey]
        }

        ; Set test data
        macroEvents[testMacroKey] := testEvents

        ; Test save
        SaveConfig()
        UpdateStatus("💾 Test save completed")

        ; Clear test data
        macroEvents.Delete(testMacroKey)

        ; Verify data was cleared
        if (!macroEvents.Has(testMacroKey)) {
            UpdateStatus("✅ Test data cleared successfully")
        } else {
            UpdateStatus("⚠️ Test data not cleared properly")
        }

        ; Test load
        LoadConfig()
        UpdateStatus("📚 Test load completed")

        ; Check if test data was restored
        if (macroEvents.Has(testMacroKey) && macroEvents[testMacroKey].Length >= 3) {
            UpdateStatus("✅ Persistence test PASSED - data saved and restored correctly")
        } else {
            UpdateStatus("⚠️ Persistence test FAILED - data not restored properly")
        }

        ; Restore original state
        if (originalEvents.Length > 0) {
            macroEvents[testMacroKey] := originalEvents
        } else {
            macroEvents.Delete(testMacroKey)
        }

        ; Final save to restore original state
        SaveConfig()
        UpdateStatus("💾 Original state restored")

    } catch Error as e {
        UpdateStatus("❌ Persistence test FAILED: " . e.Message)
    }
}