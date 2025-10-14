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
global pngFileCache := Map()  ; Track PNG files for cleanup

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

; ===== PNG FILE CLEANUP SYSTEM =====
CleanupOldPNGFiles() {
    global pngFileCache

    ; Delete old PNG files that are no longer in use
    filesToDelete := []
    for buttonKey, pngPath in pngFileCache {
        if (FileExist(pngPath)) {
            try {
                FileDelete(pngPath)
            } catch {
                ; File in use, skip
            }
        }
    }

    ; Clear cache
    pngFileCache := Map()
}

RegisterPNGFile(buttonKey, pngPath) {
    global pngFileCache

    ; Delete old PNG for this button if exists
    if (pngFileCache.Has(buttonKey) && FileExist(pngFileCache[buttonKey])) {
        try {
            FileDelete(pngFileCache[buttonKey])
        } catch {
            ; File in use, will be cleaned up later
        }
    }

    ; Register new PNG
    pngFileCache[buttonKey] := pngPath
}

; ===== HOTKEY CONFIGURATION =====
global hotkeyRecordToggle := "F9"
global hotkeySubmit := "+Enter"
global hotkeyDirectClear := "NumpadEnter"
global hotkeyEmergency := "RCtrl"
global hotkeyBreakMode := "^b"
global hotkeyLayerPrev := "NumpadDiv"
global hotkeyLayerNext := "NumpadSub"
global hotkeySettings := ""
global hotkeyStats := ""

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
global permanentStatsFile := workDir . "\master_stats_permanent.csv"  ; NEVER gets reset

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

; Canvas calibration flags
global isCanvasCalibrated := false  ; Start as false until calibrated
global isWideCanvasCalibrated := false
global isNarrowCanvasCalibrated := false
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
; Legacy wrappers for backwards compatibility
CalibrateCanvasArea() {
    Canvas_Calibrate("user")
}

ResetCanvasCalibration() {
    Canvas_Reset("user")
}

; Legacy wrappers for canvas calibration
CalibrateWideCanvasArea() {
    Canvas_Calibrate("wide")
}

ResetWideCanvasCalibration() {
    Canvas_Reset("wide")
}

ResetNarrowCanvasCalibration() {
    Canvas_Reset("narrow")
}

CalibrateNarrowCanvasArea() {
    Canvas_Calibrate("narrow")
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
global layerBorderColors := ["0x404040", "0x505050", "0x606060", "0x707070", "0x808080"]

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

; ===== CANVAS VARIABLE INITIALIZATION =====
InitializeCanvasVariables() {
    Canvas_Initialize()
}

; ===== MAIN INITIALIZATION =====
Main() {
    try {
        ; Initialize core systems with debugging
        try {
            InitializeDirectories()
        } catch Error as e {
            UpdateStatus("❌ Directory initialization failed: " . e.Message)
            throw e
        }

        try {
            InitializeConfigSystem()  ; Initialize config system and clean up locks
        } catch Error as e {
            UpdateStatus("❌ Config system initialization failed: " . e.Message)
            throw e
        }

        try {
            InitializeVariables()
        } catch Error as e {
            UpdateStatus("❌ Variable initialization failed: " . e.Message)
            throw e
        }

        try {
            InitializeCanvasVariables()
            InitializeStatsSystem()  ; Handles CSV initialization internally
            InitializeJsonAnnotations()
            InitializeVisualizationSystem()
            InitializeWASDHotkeys()
        } catch Error as e {
            UpdateStatus("❌ Initialization error: " . e.Message)
            throw e
        }

        ; Initialize real-time session
        ; InitializeRealtimeSession() removed - was unused placeholder

        ; Setup UI and interactions
        InitializeGui()
        SetupHotkeys()

        ; Load configuration (after GUI is created so mode toggle button can be updated)
        LoadConfig()

        ; Apply loaded settings to GUI now that it's fully initialized
        ApplyLoadedSettingsToGUI()

        ; Switch active canvas based on loaded annotation mode
        global annotationMode, userCanvasLeft, userCanvasTop, userCanvasRight, userCanvasBottom
        global wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom
        global narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom

        if (annotationMode = "Narrow") {
            userCanvasLeft := narrowCanvasLeft
            userCanvasTop := narrowCanvasTop
            userCanvasRight := narrowCanvasRight
            userCanvasBottom := narrowCanvasBottom
        } else {
            userCanvasLeft := wideCanvasLeft
            userCanvasTop := wideCanvasTop
            userCanvasRight := wideCanvasRight
            userCanvasBottom := wideCanvasBottom
        }

        ; Ensure totalLayers is always a valid integer after loading config
        global totalLayers := EnsureInteger(totalLayers, 5)
        if (totalLayers < 1 || totalLayers > 10) {
            global totalLayers := 5
        }

        ; Setup WASD hotkeys if profile is active (now enabled by default)
        if (hotkeyProfileActive) {
            SetupWASDHotkeys()
            ; Reminder: WASD hotkeys use CapsLock modifier (CapsLock + key)
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

        ; Show GUI now that everything is loaded and configured
        ShowGui()

        ; Setup time tracking, auto-save, and state monitoring
        SetTimer(UpdateActiveTime, 30000)
        SetTimer(AutoSave, 30000)  ; Auto-save every 30 seconds for better persistence
        SetTimer(MonitorExecutionState, 15000)  ; Check for stuck states every 15 seconds
        SetTimer(ValidateConfigIntegrity, 120000)  ; Validate config integrity every 2 minutes
        SetTimer(CleanupOldPNGFiles, 60000)  ; CRITICAL: Cleanup PNG files every 60 seconds to prevent accumulation

        ; Setup cleanup - use proper function reference for reliable exit handling
        OnExit((exitReason, exitCode) => CleanupAndExit())

        ; Show welcome message
        UpdateStatus("🚀 Ready - " . (annotationMode = "Wide" ? "WIDE" : "NARROW") . " mode - F9 to record")
        SetTimer(ShowWelcomeMessage, -2000)

    } catch Error as e {
        MsgBox("Initialization failed: " e.Message, "Startup Error", "Icon!")
        ExitApp
    }
}

CheckCanvasConfiguration() {
    Canvas_CheckConfiguration()
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
}

; ===== CLEANUP AND EXIT FUNCTIONS =====
CleanupAndExit() {
    global mouseHook, keyboardHook, liveStatsTimer

    try {
        ; Stop all timers
        SetTimer(UpdateActiveTime, 0)
        SetTimer(AutoSave, 0)
        SetTimer(MonitorExecutionState, 0)
        if (liveStatsTimer) {
            SetTimer(liveStatsTimer, 0)
        }

        ; CRITICAL: Flush any pending stats before exit
        try {
            FlushStatsQueue()
        } catch {
            ; Continue even if flush fails
        }

        ; CRITICAL: Cleanup PNG files to prevent accumulation
        try {
            CleanupOldPNGFiles()
        } catch {
            ; Continue even if cleanup fails
        }

        ; Uninstall hooks
        SafeUninstallMouseHook()
        SafeUninstallKeyboardHook()

        ; Clean up HBITMAP cache
        try {
            CleanupHBITMAPCache()
        } catch {
            ; Silently continue if HBITMAP cleanup fails
        }

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
        ReadStatsFromCSV(false)  ; Direct call instead of AggregateMetrics() wrapper

    } catch Error as e {
        ; Silently continue on cleanup errors
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
        } catch {
            ; Silently continue if auto-save fails
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
    global recording, playback, awaitingAssignment, lastExecutionTime, playbackStartTime

    ; Force reset all execution states
    recording := false
    playback := false
    awaitingAssignment := false
    lastExecutionTime := 0
    playbackStartTime := 0

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
            return
        }

        ; Check for basic structure
        if (!InStr(content, "[Settings]") && !InStr(content, "[Macros]")) {
            return
        }

        ; Check file size (too small or too large might indicate corruption)
        fileSize := FileGetSize(configFile)
        if (fileSize < 100) {
            return
        }

        if (fileSize > 10485760) { ; 10MB limit
            return
        }

    } catch {
        ; Silently continue if integrity check fails
    }
}

; ===== EMERGENCY STOP =====
EmergencyStop() {
    global recording, playback, awaitingAssignment, mainGui

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
        ; REMOVED: Send("{Esc}") - was blocking normal Esc key usage during labeling
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
        RecordExecutionStats("NumpadEnter", startTime, "clear", [], "")
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
        RecordExecutionStats("Shift" . buttonName, startTime, "clear", [], "")
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
        RecordExecutionStats("ShiftEnter", startTime, "clear", [], "")
    } else {
        UpdateStatus("⚠️ No browser for direct clear")
    }
}

; ===== PERSISTENCE SYSTEM TEST FUNCTION =====
; TestPersistenceSystem() removed - was debug function, never used in production