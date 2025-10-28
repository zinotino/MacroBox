; ===== CORE VARIABLES & CONFIGURATION =====
global mainGui := 0
global statusBar := 0
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
global buttonDisplayedHBITMAPs := Map()  ; Track which HBITMAP is currently displayed on each button

ClearHBitmapCacheForMacro(macroName) {
    global hbitmapCache, buttonDisplayedHBITMAPs
    ; Clear cache entries for this macro
    ; The displayed HBITMAP will be replaced when UpdateButtonAppearance runs

    keysToDelete := []
    for cacheKey, hbitmap in hbitmapCache {
        if (InStr(cacheKey, macroName)) {
            keysToDelete.Push(cacheKey)
        }
    }
    for key in keysToDelete {
        hbitmapCache.Delete(key)
    }

    ; Mark that this button needs its HBITMAP cleaned up
    ; It will be replaced with a new one in UpdateButtonAppearance
    if (buttonDisplayedHBITMAPs.Has(macroName)) {
        buttonDisplayedHBITMAPs[macroName] := 0  ; Mark for cleanup
    }
}

; ===== HOTKEY CONFIGURATION =====
global hotkeyRecordToggle := "F9"
global hotkeySubmit := "+Enter"
global hotkeyDirectClear := "NumpadEnter"
global hotkeyEmergency := "RCtrl"
global hotkeyBreakMode := "^b"
global hotkeySettings := ""
global hotkeyStats := ""

; ===== VISUAL INDICATOR SYSTEM =====
global yellowOutlineButtons := Map()  ; Track buttons with yellow outlines

; ===== WASD LABEL TOGGLE SYSTEM =====
global wasdLabelsEnabled := false  ; Track if WASD labels should be shown
global wasdToggleBtn := 0  ; Reference to the WASD toggle button

; ===== FILE SYSTEM PATHS =====
global workDir := A_MyDocuments . "\MacroMaster\data"
global configFile := workDir . "\config.ini"
global documentsDir := A_MyDocuments . "\MacroMaster"
global thumbnailDir := documentsDir . "\thumbnails"
global masterStatsCSV := workDir . "\master_stats.csv"
global permanentStatsFile := workDir . "\master_stats_permanent.csv"

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
global macroExecutionLog := []  ; In-memory execution data
global macroStats := Map()
global severityBreakdown := Map()
global executionTimeLog := []
global totalExecutionTime := 0

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


; ===== SESSION TRACKING =====
global currentSessionId := "sess_" . FormatTime(A_Now, "yyyyMMdd_HHmmss")

; ===== UI CONFIGURATION =====
global windowWidth := 1200
global windowHeight := 800
global scaleFactor := 1.0
global minWindowWidth := 900
global minWindowHeight := 600

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



; ===== VISUALIZATION SYSTEM =====
; Using HBITMAP-only approach (memory-based, no file I/O)

; STANDARD MENU DIMENSIONS (both config and stats)
global standardMenuWidth := 900
global standardMenuHeight := 650

; ===== HOTKEY PROFILE SYSTEM =====
global hotkeyProfileActive := true  ; Enable WASD hotkeys by default
global capsLockPressed := false
global wasdHotkeyMap := Map()








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

        ; Config system is now simple - no initialization needed

        try {
            InitializeVariables()
        } catch Error as e {
            UpdateStatus("❌ Variable initialization failed: " . e.Message)
            throw e
        }

        try {
            Canvas_Initialize()
            InitializeStatsSystem()
            LoadStatsFromJson()  ; Load persisted stats
            InitializeJsonAnnotations()
            InitializeVisualizationSystem()
            InitializeWASDHotkeys()
        } catch Error as e {
            UpdateStatus("❌ Initialization error: " . e.Message)
            throw e
        }

        ; Setup UI and interactions
        InitializeGui()
        SetupHotkeys()

        ; Load configuration
        LoadConfig()

        ; Count loaded macros
        loadedCount := LoadMacroState()
        if (loadedCount > 0) {
            UpdateStatus("✅ Loaded " . loadedCount . " macros")
        }

        ; Apply loaded settings to GUI
        ApplyLoadedSettingsToGUI()

        ; Sync canvas based on annotation mode
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

        ; Setup WASD hotkeys if enabled
        if (hotkeyProfileActive) {
            SetupWASDHotkeys()
        }

        ; Check canvas configuration
        Canvas_CheckConfiguration()

        ; Refresh all button appearances after loading config
        RefreshAllButtonAppearances()

        ; Show GUI now that everything is loaded and configured
        ShowGui()

        ; Setup time tracking only
        SetTimer(UpdateActiveTime, 30000)

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

    ; NOTE: JSON profile assignment removed with layer system - macros can be recorded manually
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


; ===== CLEANUP AND EXIT FUNCTIONS =====
CleanupAndExit() {
    global mouseHook, keyboardHook, liveStatsTimer, gdiPlusInitialized, gdiPlusToken

    try {
        ; Stop timers
        SetTimer(UpdateActiveTime, 0)
        if (liveStatsTimer) {
            SetTimer(liveStatsTimer, 0)
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

        ; CRITICAL FIX: Shutdown GDI+ to prevent memory leak
        if (gdiPlusInitialized && gdiPlusToken) {
            try {
                DllCall("gdiplus\GdiplusShutdown", "Ptr", gdiPlusToken)
                gdiPlusInitialized := false
                gdiPlusToken := 0
            } catch {
                ; Continue if GDI+ shutdown fails
            }
        }

        ; Save final state - CRITICAL: Ensure config saves before exit
        try {
            SaveConfig()
            SaveStatsToJson()  ; Save stats on exit
            UpdateStatus("✅ Configuration saved on exit")
        } catch Error as saveError {
            ; CRITICAL: Show save errors instead of silent failure
            MsgBox("❌ CRITICAL: Failed to save configuration on exit: " . saveError.Message . "`n`nYour macros and settings may not persist.", "Save Error", "Icon!")
        }

        ; Final active time update
        UpdateActiveTime()

    } catch Error as e {
        ; Silently continue on cleanup errors
    }
}

SafeExit() {
    CleanupAndExit()
    ExitApp
}

; ===== EMERGENCY STOP =====
EmergencyStop() {
    global recording, playback, awaitingAssignment, mainGui

    UpdateStatus("🚨 EMERGENCY STOP")

    ; Force reset all execution states
    recording := false
    playback := false
    awaitingAssignment := false

    ; Clean up hooks
    SafeUninstallMouseHook()
    SafeUninstallKeyboardHook()

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
    } catch {
    }

    SetMouseDelay(10)
    SetKeyDelay(10)

    UpdateStatus("🚨 Emergency Stop complete")
}

; ===== UNIFIED BROWSER FOCUS & SUBMIT =====
FocusBrowserAndSubmit(buttonName := "NumpadEnter", statusLabel := "Submitted") {
    startTime := A_TickCount

    ; Try browsers in priority order
    browsers := ["chrome.exe", "firefox.exe", "msedge.exe"]
    browserFocused := false

    for browser in browsers {
        if (WinExist("ahk_exe " . browser)) {
            WinActivate("ahk_exe " . browser)
            browserFocused := true
            break
        }
    }

    if (browserFocused) {
        Send("+{Enter}")
        UpdateStatus("📤 " . statusLabel)
        RecordExecutionStats(buttonName, startTime, "clear", [], "")
        return true
    } else {
        UpdateStatus("⚠️ No browser: " . buttonName)
        return false
    }
}

; ===== WRAPPER FUNCTIONS (maintain API compatibility) =====
SubmitCurrentImage() {
    FocusBrowserAndSubmit("NumpadEnter", "Submitted")
}

ShiftNumpadClearExecution(buttonName) {
    FocusBrowserAndSubmit("Shift" . buttonName, "Clear: Shift+" . buttonName)
}

DirectClearExecution() {
    FocusBrowserAndSubmit("ShiftEnter", "Direct Clear Submitted")
}


UpdateStatus(text) {
    global statusBar
    if (!statusBar) {
        return
    }
    try {
        statusBar.Text := text
        ; No need for Redraw() - text updates automatically in AHK v2
    } catch {
        ; ignore UI update failures
    }
}

UpdateEmergencyButtonText() {
    global mainGui, hotkeyEmergency
    if (mainGui.HasProp("btnEmergency") && mainGui.btnEmergency) {
        mainGui.btnEmergency.Text := "Emergency: " . hotkeyEmergency
    }
}


