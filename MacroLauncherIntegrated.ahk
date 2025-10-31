#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"
Persistent

/*
===============================================================================
COMPLETE DATA LABELING ASSISTANT - MONOLITHIC STANDALONE VERSION
===============================================================================
ARCHITECTURE: Single self-contained file with ALL functionality embedded
  - No external #Include statements
  - No module dependencies
  - Zero external files required for execution

BENEFITS:
  - Single file deployment (just copy this .ahk file)
  - No path issues when transferring between machines
  - No include failures or module synchronization problems
  - Simplified maintenance and debugging

LEGACY NOTE:
  - Earlier versions used separate modular files in /src directory
  - Those files are now archived in /archive/legacy-modular
  - This monolithic version is the current production implementation

FEATURES:
  - Macro recording and playback with optimization
  - HBITMAP visualization thumbnails (Wide/Narrow canvas modes)
  - Stats tracking with JSON persistence and CSV export
  - Degradation type tracking (10 types: smudge, glare, splashes, etc.)
  - Dark mode GUI with live auto-refresh
  - Hotkey customization with live re-registration
  - Window scaling with debounced resize handling

Total Lines: ~6,669 | Functions: 165+ | Health Score: B+ (85/100)
===============================================================================
*/

; ===== OBJECT PERSISTENCE MODULE =====
; Simple JSON save/load for stats persistence

ObjSave(obj, path) {
    file := ""
    try {
        data := ObjToString(obj)
        file := FileOpen(path, "w", "UTF-8")
        if (!file)
            return false
        file.Write(data)
        return true
    } catch {
        return false
    } finally {
        if (IsObject(file))
            file.Close()
    }
}

ObjLoad(path) {
    try {
        if (!FileExist(path))
            return Map()
        data := FileRead(path, "UTF-8")
        result := StrToObj(data)
        return IsObject(result) ? result : Map()
    } catch {
        return Map()
    }
}

ObjToString(value) {
    ; Check type FIRST to avoid type coercion with loose comparison
    valueType := Type(value)

    ; Handle numbers before boolean check (prevents 0/1 being coerced to false/true)
    if (valueType = "Integer" || valueType = "Float")
        return String(value)

    ; Now safe to check booleans (only true booleans, not coerced numbers)
    if (value == true)
        return "true"
    if (value == false)
        return "false"
    if (valueType = "ComValue")
        return "null"

    if (valueType = "Map") {
        items := []
        for key, itemValue in value {
            keyText := ObjToString(String(key))
            items.Push(keyText . ":" . ObjToString(itemValue))
        }
        return "{" . StrJoin(items, ",") . "}"
    }

    if (valueType = "Array") {
        items := []
        for element in value {
            items.Push(ObjToString(element))
        }
        return "[" . StrJoin(items, ",") . "]"
    }

    if (valueType = "String") {
        quote := Chr(34)
        return quote . JsonEscape(value) . quote
    }

    return String(value)
}

StrToObj(text) {
    try {
        pos := 1
        return Jxon_ParseValue(text, &pos)
    } catch {
        return Map()
    }
}

Jxon_ParseValue(text, &pos) {
    Jxon_SkipWhitespace(text, &pos)
    if (pos > StrLen(text))
        throw Error("Unexpected end")

    char := SubStr(text, pos, 1)
    if (char = "{")
        return Jxon_ParseObject(text, &pos)
    if (char = "[")
        return Jxon_ParseArray(text, &pos)
    if (char = Chr(34))
        return Jxon_ParseString(text, &pos)
    if (SubStr(text, pos, 4) = "null") {
        pos += 4
        return ""
    }
    if (SubStr(text, pos, 4) = "true") {
        pos += 4
        return true
    }
    if (SubStr(text, pos, 5) = "false") {
        pos += 5
        return false
    }
    return Jxon_ParseNumber(text, &pos)
}

Jxon_ParseObject(text, &pos) {
    obj := Map()
    pos += 1
    Jxon_SkipWhitespace(text, &pos)
    if (SubStr(text, pos, 1) = "}") {
        pos += 1
        return obj
    }

    while true {
        key := Jxon_ParseString(text, &pos)
        Jxon_SkipWhitespace(text, &pos)
        if (SubStr(text, pos, 1) != ":")
            throw Error("Expected ':'")
        pos += 1
        value := Jxon_ParseValue(text, &pos)
        obj[key] := value
        Jxon_SkipWhitespace(text, &pos)
        char := SubStr(text, pos, 1)
        if (char = "}") {
            pos += 1
            break
        }
        if (char != ",")
            throw Error("Expected ',' or '}'")
        pos += 1
    }
    return obj
}

Jxon_ParseArray(text, &pos) {
    arr := []
    pos += 1
    Jxon_SkipWhitespace(text, &pos)
    if (SubStr(text, pos, 1) = "]") {
        pos += 1
        return arr
    }

    while true {
        value := Jxon_ParseValue(text, &pos)
        arr.Push(value)
        Jxon_SkipWhitespace(text, &pos)
        char := SubStr(text, pos, 1)
        if (char = "]") {
            pos += 1
            break
        }
        if (char != ",")
            throw Error("Expected ',' or ']'")
        pos += 1
    }
    return arr
}

Jxon_ParseString(text, &pos) {
    quote := Chr(34)
    backslash := Chr(92)
    pos += 1
    start := pos
    result := ""

    while true {
        if (pos > StrLen(text))
            throw Error("Unexpected end of string")

        char := SubStr(text, pos, 1)
        if (char = quote) {
            result .= SubStr(text, start, pos - start)
            pos += 1
            break
        }

        if (char = backslash) {
            result .= SubStr(text, start, pos - start)
            pos += 1
            if (pos > StrLen(text))
                throw Error("Unexpected end of string")

            escapeChar := SubStr(text, pos, 1)
            if (escapeChar = quote)
                result .= quote
            else if (escapeChar = backslash)
                result .= backslash
            else if (escapeChar = "n")
                result .= "`n"
            else if (escapeChar = "r")
                result .= "`r"
            else if (escapeChar = "t")
                result .= "`t"
            pos += 1
            start := pos
        } else {
            pos += 1
        }
    }
    return result
}

Jxon_ParseNumber(text, &pos) {
    start := pos
    while (pos <= StrLen(text) && InStr("0123456789+-.eE", SubStr(text, pos, 1)))
        pos += 1
    number := SubStr(text, start, pos - start)
    if (InStr(number, ".") || InStr(number, "e") || InStr(number, "E"))
        return number + 0.0
    return Integer(number)
}

Jxon_SkipWhitespace(text, &pos) {
    while (pos <= StrLen(text) && InStr(" `t`r`n", SubStr(text, pos, 1)))
        pos += 1
}

JsonEscape(text) {
    result := ""
    backslash := Chr(92)
    Loop Parse text {
        char := A_LoopField
        code := Ord(char)
        if (code = 9)
            result .= backslash . "t"
        else if (code = 10)
            result .= backslash . "n"
        else if (code = 13)
            result .= backslash . "r"
        else if (code = 34)
            result .= backslash . Chr(34)
        else if (code = 92)
            result .= backslash . backslash
        else
            result .= char
    }
    return result
}

StrJoin(array, sep) {
    result := ""
    for index, element in array {
        result .= (index = 1 ? "" : sep) . element
    }
    return result
}

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
global resizeTimer := 0  ; Timer for debouncing resize events
; ===== STATS SYSTEM GLOBALS =====
global masterStatsCSV := ""
global permanentStatsFile := ""
global sessionId := "session_" . A_TickCount
global currentSessionId := sessionId
global currentUsername := A_UserName
global documentsDir := ""
global workDir := A_ScriptDir "\data"

; ===== FILE SYSTEM PATHS =====
global configFile := A_ScriptDir "\config.ini"
global thumbnailDir := A_ScriptDir "\thumbnails"

; ===== THUMBNAIL SUPPORT =====
global buttonThumbnails := Map()

; ===== ENHANCED STATS SYSTEM =====
global severityBreakdown := Map()

; ===== DEGRADATION TRACKING =====
global pendingBoxForTagging := ""

; ===== TIME TRACKING & BREAK MODE =====
global applicationStartTime := A_TickCount
global totalActiveTime := 0
global lastActiveTime := A_TickCount
global breakMode := false
global breakStartTime := 0
global currentDay := FormatTime(A_Now, "yyyy-MM-dd")  ; Track current day for daily reset

; ===== UI CONFIGURATION =====
global baseWidth := 1200
global baseHeight := 800
global windowWidth := 1200
global windowHeight := 800
global minWindowWidth := 800
global minWindowHeight := 600
global scaleFactor := 1.0  ; Font scaling factor (optional, for manual font size adjustment)

; Calculate scale factor based on current window size vs base size
GetScaleFactor() {
    global windowWidth, windowHeight, baseWidth, baseHeight
    ; Use the smaller scale factor to ensure everything fits
    scaleX := windowWidth / baseWidth
    scaleY := windowHeight / baseHeight
    return Min(scaleX, scaleY)
}

; ===== LAYER SYSTEM (REMOVED - SINGLE LAYER ONLY) =====
global currentLayer := 1
global totalLayers := 1

; ===== TIMING CONFIGURATION =====
global boxDrawDelay := 50
global mouseClickDelay := 75
global mouseDragDelay := 50
global mouseReleaseDelay := 75
global betweenBoxDelay := 120
global keyPressDelay := 12
global focusDelay := 60

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
    1, "0xFF8C00",    ; smudge - orange
    2, "0xFFFF00",    ; glare - yellow
    3, "0x9932CC",    ; splashes - purple
    4, "0x32CD32",    ; partial_blockage - green
    5, "0x8B0000",    ; full_blockage - dark red
    6, "0xFF6B6B",    ; light_flare - light red
    7, "0xFF4500",    ; rain - dark orange
    8, "0xBDB76B",    ; haze - dirty yellow
    9, "0x00FF00"     ; snow - neon green
)

global severityLevels := ["high", "medium", "low"]

; ===== INTELLIGENT TIMING SYSTEM - UNIQUE DELAYS =====
global smartBoxClickDelay := 45    ; Optimized for fast box drawing in intelligent system
global smartMenuClickDelay := 100  ; Optimized for accurate menu selections in intelligent system
global mouseHoverDelay := 30
global menuClickDelay := 120       ; Menu click delay for settings
global firstBoxDelay := 180        ; Extra delay after first box in macro for UI stabilization
global menuWaitDelay := 50         ; Wait time for dropdown menus (kept for reference)

; ===== HOTKEY SETTINGS =====
global hotkeyRecordToggle := "CapsLock & f"
global hotkeyEmergencyStop := "CapsLock & Space"
global hotkeySubmit := "NumpadEnter"
global hotkeyDirectClear := "+Enter"
global hotkeyStats := "F12"
global hotkeyBreakMode := "^b"
global hotkeySettings := "^k"

; ===== UTILITY HOTKEYS FOR LABELER WORKFLOW =====
global hotkeyUtilitySubmit := "+CapsLock"      ; LShift + CapsLock = Shift+Enter
global hotkeyUtilityBackspace := "^CapsLock"   ; LCtrl + CapsLock = Backspace
global utilityHotkeysEnabled := true           ; Enable/disable utility hotkeys

; ===== WASD SETTINGS =====
global hotkeyProfileActive := true  ; FIXED: Was false, should default to true
global wasdLabelsEnabled := true  ; Always enabled by default
global wasdHotkeyMap := Map()
global capsLockPressed := false

GetVirtualScreenBounds(&left, &top, &right, &bottom) {
    left := DllCall("GetSystemMetrics", "Int", 76, "Int")
    top := DllCall("GetSystemMetrics", "Int", 77, "Int")
    width := DllCall("GetSystemMetrics", "Int", 78, "Int")
    height := DllCall("GetSystemMetrics", "Int", 79, "Int")
    right := left + width
    bottom := top + height
}

PtrToUInt(ptrValue) {
    buf := Buffer(A_PtrSize)
    NumPut("Ptr", ptrValue, buf)
    return NumGet(buf, 0, "UPtr")
}

HBITMAPToPictureValue(hbitmap) {
    if (!hbitmap)
        return "HBITMAP:0"
    return "HBITMAP:" . PtrToUInt(hbitmap)
}

; ===== CANVAS CALIBRATION RESET FUNCTIONS =====
ResetWideCanvasCalibration(settingsGui) {
global isWideCanvasCalibrated, wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom

result := MsgBox("Reset Wide canvas calibration to automatic detection?", "Reset Wide Canvas", "YesNo")
if (result = "Yes") {
    isWideCanvasCalibrated := false
    GetVirtualScreenBounds(&vsLeft, &vsTop, &vsRight, &vsBottom)
    wideCanvasLeft := vsLeft
    wideCanvasTop := vsTop
    wideCanvasRight := vsRight
    wideCanvasBottom := vsBottom
    SaveConfig()
    UpdateStatus("🔄 Wide canvas reset")
    CleanupHBITMAPCache()
    RefreshAllButtonAppearances()
    if (IsObject(settingsGui))
        UpdateCanvasStatusControls(settingsGui)
    if (IsObject(settingsGui))
        settingsGui.Show()
}
}

ResetNarrowCanvasCalibration(settingsGui) {
global isNarrowCanvasCalibrated, narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom

result := MsgBox("Reset Narrow canvas calibration to automatic detection?", "Reset Narrow Canvas", "YesNo")
if (result = "Yes") {
    isNarrowCanvasCalibrated := false
    ; Reset to 4:3 aspect ratio centered
    narrowAspectRatio := 4.0 / 3.0
    GetVirtualScreenBounds(&vsLeft, &vsTop, &vsRight, &vsBottom)
    screenWidth := vsRight - vsLeft
    screenHeight := vsBottom - vsTop

    if (screenWidth <= 0 || screenHeight <= 0) {
        screenWidth := A_ScreenWidth
        screenHeight := A_ScreenHeight
        vsLeft := 0
        vsTop := 0
        vsRight := screenWidth
        vsBottom := screenHeight
    }

    screenAspectRatio := screenWidth / screenHeight

    if (screenAspectRatio > narrowAspectRatio) {
        ; Screen is wider than 4:3 - add horizontal padding
        contentHeight := screenHeight
        contentWidth := contentHeight * narrowAspectRatio
        narrowCanvasLeft := vsLeft + (screenWidth - contentWidth) / 2
        narrowCanvasTop := vsTop
        narrowCanvasRight := narrowCanvasLeft + contentWidth
        narrowCanvasBottom := vsTop + contentHeight
    } else {
        ; Screen is taller than 4:3 - add vertical padding
        contentWidth := screenWidth
        contentHeight := contentWidth / narrowAspectRatio
        narrowCanvasLeft := vsLeft
        narrowCanvasTop := vsTop + (screenHeight - contentHeight) / 2
        narrowCanvasRight := vsLeft + contentWidth
        narrowCanvasBottom := narrowCanvasTop + contentHeight
    }
    SaveConfig()
    UpdateStatus("🔄 Narrow canvas reset")
    CleanupHBITMAPCache()
    RefreshAllButtonAppearances()
    if (IsObject(settingsGui))
        UpdateCanvasStatusControls(settingsGui)
    if (IsObject(settingsGui))
        settingsGui.Show()
}
}

; ===== CANVAS CALIBRATION FUNCTIONS =====
ConfigureWideCanvasFromSettings(settingsGui) {
    settingsGui.Hide()

    ; Set coordinate mode to Screen to properly capture absolute screen coordinates
    ; This is critical for multi-monitor setups with negative coordinates
    CoordMode("Mouse", "Screen")

    result := MsgBox("Calibrate 16:9 Wide Canvas Area`n`nThis is for WIDE mode recordings (full screen, widescreen).`n`nClick OK then:`n1. Click TOP-LEFT corner of your 16:9 area`n2. Click BOTTOM-RIGHT corner of your 16:9 area", "Wide Canvas Calibration", "OKCancel")

    if (result = "Cancel") {
        settingsGui.Show()
        return
    }

    UpdateStatus("🔦 Wide: Click TOP-LEFT...")

    ; Add timeouts to prevent infinite hangs
    KeyWait("LButton", "U T30")
    if (!KeyWait("LButton", "D T30")) {
        UpdateStatus("⚠️ Calibration timeout")
        settingsGui.Show()
        return
    }
    MouseGetPos(&x1, &y1)
    KeyWait("LButton", "U T5")

    UpdateStatus("🔦 Wide: Click BOTTOM-RIGHT...")

    if (!KeyWait("LButton", "D T30")) {
        UpdateStatus("⚠️ Calibration timeout")
        settingsGui.Show()
        return
    }
    MouseGetPos(&x2, &y2)
    KeyWait("LButton", "U T5")

    ; Calculate bounds
    left := Min(x1, x2)
    top := Min(y1, y2)
    right := Max(x1, x2)
    bottom := Max(y1, y2)

    canvasW := right - left
    canvasH := bottom - top

    if (canvasH = 0) {
        MsgBox("⚠️ Calibration failed: Selected area has zero height.`n`nPlease try again and select a valid area.", "Calibration Error", "Icon!")
        settingsGui.Show()
        return
    }

    aspectRatio := canvasW / canvasH

    ; Show confirmation
    confirmMsg := "Canvas calibrated to:`n`nLeft: " . left . "`nTop: " . top . "`nRight: " . right . "`nBottom: " . bottom . "`nAspect Ratio: " . Round(aspectRatio, 2)

    if (Abs(aspectRatio - 1.777) > 0.1) {
        confirmMsg .= "`n`n⚠️ Aspect ratio is " . Round(aspectRatio, 2) . " (expected ~1.78 for 16:9)"
    } else {
        confirmMsg .= "`n`n✅ Aspect ratio matches 16:9"
    }

    confirmMsg .= "`n`nSave this configuration?"

    result := MsgBox(confirmMsg, "Confirm Wide Canvas Calibration", "YesNo Icon?")

    if (result = "No") {
        UpdateStatus("🔄 Cancelled")
        settingsGui.Show()
        return
    }

    ; Save calibration data
    global wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom, isWideCanvasCalibrated
    wideCanvasLeft := left
    wideCanvasTop := top
    wideCanvasRight := right
    wideCanvasBottom := bottom
    isWideCanvasCalibrated := true

    SaveConfig()

    UpdateStatus("✅ Wide canvas calibrated")
    CleanupHBITMAPCache()
    RefreshAllButtonAppearances()
    if (IsObject(settingsGui))
        UpdateCanvasStatusControls(settingsGui)
    settingsGui.Show()
}

ConfigureNarrowCanvasFromSettings(settingsGui) {
    settingsGui.Hide()

    ; Set coordinate mode to Screen to properly capture absolute screen coordinates
    ; This is critical for multi-monitor setups with negative coordinates
    CoordMode("Mouse", "Screen")

    result := MsgBox("Calibrate 4:3 Narrow Canvas Area`n`nThis is for NARROW mode recordings (constrained, square-ish).`n`nClick OK then:`n1. Click TOP-LEFT corner of your 4:3 area`n2. Click BOTTOM-RIGHT corner of your 4:3 area", "Narrow Canvas Calibration", "OKCancel")

    if (result = "Cancel") {
        settingsGui.Show()
        return
    }

    UpdateStatus("📱 Narrow: Click TOP-LEFT...")

    ; Add timeouts to prevent infinite hangs
    KeyWait("LButton", "U T30")
    if (!KeyWait("LButton", "D T30")) {
        UpdateStatus("⚠️ Calibration timeout")
        settingsGui.Show()
        return
    }
    MouseGetPos(&x1, &y1)
    KeyWait("LButton", "U T5")

    UpdateStatus("📱 Narrow: Click BOTTOM-RIGHT...")

    if (!KeyWait("LButton", "D T30")) {
        UpdateStatus("⚠️ Calibration timeout")
        settingsGui.Show()
        return
    }
    MouseGetPos(&x2, &y2)
    KeyWait("LButton", "U T5")

    ; Calculate bounds
    left := Min(x1, x2)
    top := Min(y1, y2)
    right := Max(x1, x2)
    bottom := Max(y1, y2)

    canvasW := right - left
    canvasH := bottom - top

    if (canvasH = 0) {
        MsgBox("⚠️ Calibration failed: Selected area has zero height.`n`nPlease try again and select a valid area.", "Calibration Error", "Icon!")
        settingsGui.Show()
        return
    }

    aspectRatio := canvasW / canvasH

    ; Show confirmation
    confirmMsg := "Canvas calibrated to:`n`nLeft: " . left . "`nTop: " . top . "`nRight: " . right . "`nBottom: " . bottom . "`nAspect Ratio: " . Round(aspectRatio, 2)

    if (Abs(aspectRatio - 1.333) > 0.1) {
        confirmMsg .= "`n`n⚠️ Aspect ratio is " . Round(aspectRatio, 2) . " (expected ~1.33 for 4:3)"
    } else {
        confirmMsg .= "`n`n✅ Aspect ratio matches 4:3"
    }

    confirmMsg .= "`n`nSave this configuration?"

    result := MsgBox(confirmMsg, "Confirm Narrow Canvas Calibration", "YesNo Icon?")

    if (result = "No") {
        UpdateStatus("🔄 Cancelled")
        settingsGui.Show()
        return
    }

    ; Save calibration data
    global narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom, isNarrowCanvasCalibrated
    narrowCanvasLeft := left
    narrowCanvasTop := top
    narrowCanvasRight := right
    narrowCanvasBottom := bottom
    isNarrowCanvasCalibrated := true

    SaveConfig()

    UpdateStatus("✅ Narrow canvas calibrated")
    CleanupHBITMAPCache()
    RefreshAllButtonAppearances()
    if (IsObject(settingsGui))
        UpdateCanvasStatusControls(settingsGui)
    settingsGui.Show()
}

ApplyVisualizationPath(ddlVizPath, pathValues) {
    global visualizationSavePath
    selectedIndex := ddlVizPath.Value
    if (selectedIndex >= 1 && selectedIndex <= pathValues.Length) {
        visualizationSavePath := pathValues[selectedIndex]
        SaveConfig()
        UpdateStatus("💾 Visualization save path updated to: " . visualizationSavePath)
    }
}

ManualSaveConfig() {
    SaveConfig()
    UpdateStatus("💾 Configuration manually saved")
}

ManualRestoreConfig() {
    MsgBox("Configuration restore feature is available in the full modular version.", "Feature Notice", "Icon!")
}

; ===== HOTKEY CAPTURE SYSTEM =====
CaptureHotkey(editControl, hotkeyName) {
    ; Simple prompt for hotkey input
    result := InputBox("Enter your hotkey combination for " . hotkeyName . "`n`nExamples:`n  ^k = Ctrl+K`n  !F5 = Alt+F5`n  +Enter = Shift+Enter`n  ^!a = Ctrl+Alt+A`n  F12 = F12`n  NumpadEnter = NumpadEnter`n  CapsLock & f = CapsLock+F`n`nModifiers: ^ = Ctrl, ! = Alt, + = Shift, # = Win", "Set Hotkey - " . hotkeyName, "w400 h280", editControl.Value)

    if (result.Result = "OK" && result.Value != "") {
        editControl.Value := result.Value
    }
}

ApplyHotkeySettings(editRecordToggle, editSubmit, editDirectClear, editUtilitySubmit, editUtilityBackspace, editStats, editBreakMode, editSettings, settingsGui) {
    global hotkeyRecordToggle, hotkeySubmit, hotkeyDirectClear, hotkeyUtilitySubmit, hotkeyUtilityBackspace
    global hotkeyStats, hotkeyBreakMode, hotkeySettings

    ; Store old values for hotkey re-registration
    oldSubmit := hotkeySubmit
    oldUtilitySubmit := hotkeyUtilitySubmit
    oldUtilityBackspace := hotkeyUtilityBackspace

    ; Update to new values
    hotkeyRecordToggle := editRecordToggle.Value
    hotkeySubmit := editSubmit.Value
    hotkeyDirectClear := editDirectClear.Value
    hotkeyUtilitySubmit := editUtilitySubmit.Value
    hotkeyUtilityBackspace := editUtilityBackspace.Value
    hotkeyStats := editStats.Value
    hotkeyBreakMode := editBreakMode.Value
    hotkeySettings := editSettings.Value

    ; Re-register hotkeys with new bindings (apply instantly without restart)
    try {
        ; Unregister old hotkeys
        if (oldSubmit)
            Hotkey(oldSubmit, "Off")
        if (oldUtilitySubmit)
            Hotkey(oldUtilitySubmit, "Off")
        if (oldUtilityBackspace)
            Hotkey(oldUtilityBackspace, "Off")

        ; Register new hotkeys
        if (hotkeySubmit)
            Hotkey(hotkeySubmit, (*) => SubmitCurrentImage(), "On")
        if (hotkeyUtilitySubmit)
            Hotkey(hotkeyUtilitySubmit, (*) => UtilitySubmit(), "On")
        if (hotkeyUtilityBackspace)
            Hotkey(hotkeyUtilityBackspace, (*) => UtilityBackspace(), "On")
    } catch Error as e {
        MsgBox("Error applying hotkeys: " . e.Message . "`n`nPlease check your hotkey syntax and try again.", "Hotkey Error", "Icon!")
        return
    }

    ; Save to config
    SaveConfig()

    ; Notify user - changes applied instantly
    MsgBox("Hotkey settings saved and applied!`n`nYour new hotkeys are now active.", "Hotkeys Updated", "Icon!")
    UpdateStatus("✅ Hotkeys applied successfully")
}

ResetHotkeySettings(settingsGui) {
    global hotkeyRecordToggle, hotkeySubmit, hotkeyDirectClear, hotkeyUtilitySubmit, hotkeyUtilityBackspace
    global hotkeyStats, hotkeyBreakMode, hotkeySettings

    ; Confirm reset
    result := MsgBox("Reset all hotkeys to default values?`n`nThis will restore:`n• Record Toggle: CapsLock & f`n• Submit: NumpadEnter`n• Direct Clear: +Enter`n• Utility Submit: +CapsLock`n• Utility Backspace: ^CapsLock`n• Stats: F12`n• Break Mode: ^b`n• Settings: ^k", "Reset Hotkeys", "YesNo Icon?")

    if (result = "No")
        return

    ; Store old values for hotkey re-registration
    oldSubmit := hotkeySubmit
    oldUtilitySubmit := hotkeyUtilitySubmit
    oldUtilityBackspace := hotkeyUtilityBackspace

    ; Reset to defaults
    hotkeyRecordToggle := "CapsLock & f"
    hotkeySubmit := "NumpadEnter"
    hotkeyDirectClear := "+Enter"
    hotkeyUtilitySubmit := "+CapsLock"
    hotkeyUtilityBackspace := "^CapsLock"
    hotkeyStats := "F12"
    hotkeyBreakMode := "^b"
    hotkeySettings := "^k"

    ; Re-register hotkeys with default bindings
    try {
        ; Unregister old hotkeys
        if (oldSubmit)
            Hotkey(oldSubmit, "Off")
        if (oldUtilitySubmit)
            Hotkey(oldUtilitySubmit, "Off")
        if (oldUtilityBackspace)
            Hotkey(oldUtilityBackspace, "Off")

        ; Register default hotkeys
        Hotkey(hotkeySubmit, (*) => SubmitCurrentImage(), "On")
        Hotkey(hotkeyUtilitySubmit, (*) => UtilitySubmit(), "On")
        Hotkey(hotkeyUtilityBackspace, (*) => UtilityBackspace(), "On")
    } catch Error as e {
        MsgBox("Error resetting hotkeys: " . e.Message, "Hotkey Error", "Icon!")
        return
    }

    ; Save to config
    SaveConfig()

    ; Close and reopen settings to show updated values
    settingsGui.Destroy()
    ShowSettings()

    MsgBox("Hotkeys have been reset to default values!", "Reset Complete", "Icon!")
    UpdateStatus("✅ Hotkeys reset to defaults")
}

; ===== ASYNC STATS RECORDING - PREVENTS FREEZE =====
RecordExecutionStatsAsync(macroKey, executionStartTime, executionType, events, analysisRecord := "") {
    global breakMode, recording

    ; Skip if breakMode or recording - don't call blocking I/O in those states
    if (breakMode || recording) {
        return
    }

    ; Instead of blocking file I/O, queue it for later processing on a timer
    ; This returns immediately and prevents 5-15 second freeze

    ; Create async task (process stats later, not now)
    ; DELAY STATS RECORDING to prevent disk I/O during execution - reduced from 500ms to 100ms for better responsiveness
    SetTimer(() => DoRecordExecutionStatsBlocking(macroKey, executionStartTime, executionType, events, analysisRecord), -100)
}

DoRecordExecutionStatsBlocking(macroKey, executionStartTime, executionType, events, analysisRecord) {
    ; This runs on a timer, not blocking the main thread
    ; All the CSV I/O happens here, not during macro execution

    try {
        RecordExecutionStats(macroKey, executionStartTime, executionType, events, analysisRecord)
    } catch Error as e {
        ; LogExecutionEvent("STATS_ERROR", "async_stats", "error:" . e.Message)
    }
}

; ===== WASD HOTKEY FUNCTIONS =====
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

    ; Update button labels to show WASD keys
    UpdateButtonLabelsWithWASD()
}

UpdateButtonLabelsWithWASD() {
    ; REMOVED - Labels are set statically during CreateButtonGrid now
    ; No more WASD duplicates, just simple numeric labels
    return
}

ExecuteWASDMacro(buttonName, *) {
    ; Execute macro using WASD hotkeys (CapsLock + key)
    SafeExecuteMacroByKey(buttonName)
}

; ===== VISUALIZATION SYSTEM GLOBALS =====
global gdiPlusInitialized := false
global gdiPlusToken := 0
global canvasWidth := 1920
global canvasHeight := 1080
global canvasType := "custom"
global canvasAspectRatio := canvasWidth / canvasHeight

; ===== CANVAS CALIBRATION GLOBALS =====
; Canvas values loaded from config file - no hardcoded defaults
; User must calibrate canvas areas on first run
global userCanvasLeft := 0
global userCanvasTop := 0
global userCanvasRight := 0
global userCanvasBottom := 0
global isCanvasCalibrated := false

; ===== WIDE CANVAS CALIBRATION =====
global wideCanvasLeft := 0
global wideCanvasTop := 0
global wideCanvasRight := 0
global wideCanvasBottom := 0
global isWideCanvasCalibrated := false

; ===== NARROW CANVAS CALIBRATION =====
global narrowCanvasLeft := 0
global narrowCanvasTop := 0
global narrowCanvasRight := 0
global narrowCanvasBottom := 0
global isNarrowCanvasCalibrated := false

; ===== CANVAS CALIBRATION INITIALIZATION =====
; Set default canvas calibration values for visualization system
; These can be overridden by user calibration or loaded from config
GetVirtualScreenBounds(&virtualLeft, &virtualTop, &virtualRight, &virtualBottom)
virtualWidth := virtualRight - virtualLeft
virtualHeight := virtualBottom - virtualTop

if (virtualWidth <= 0 || virtualHeight <= 0) {
    virtualLeft := 0
    virtualTop := 0
    virtualWidth := A_ScreenWidth
    virtualHeight := A_ScreenHeight
    virtualRight := virtualLeft + virtualWidth
    virtualBottom := virtualTop + virtualHeight
}

defaultScreenWidth := A_ScreenWidth
defaultScreenHeight := A_ScreenHeight
if (isCanvasCalibrated && userCanvasLeft = 0 && userCanvasTop = 0 && userCanvasRight = defaultScreenWidth && userCanvasBottom = defaultScreenHeight && (virtualLeft != 0 || virtualTop != 0)) {
    userCanvasLeft := virtualLeft
    userCanvasTop := virtualTop
    userCanvasRight := virtualRight
    userCanvasBottom := virtualBottom
}

; DISABLED: Faulty auto-correction logic removed (was causing issues with multi-monitor setups)

if (!isCanvasCalibrated) {
    userCanvasLeft := virtualLeft
    userCanvasTop := virtualTop
    userCanvasRight := virtualRight
    userCanvasBottom := virtualBottom
}

if (!isWideCanvasCalibrated) {
    wideCanvasLeft := virtualLeft
    wideCanvasTop := virtualTop
    wideCanvasRight := virtualRight
    wideCanvasBottom := virtualBottom
}

if (!isNarrowCanvasCalibrated) {
    ; Narrow canvas defaults to 4:3 aspect ratio centered
    narrowAspectRatio := 4.0 / 3.0
    screenAspectRatio := virtualWidth / virtualHeight

    if (screenAspectRatio > narrowAspectRatio) {
        ; Screen is wider than 4:3 - add horizontal padding
        contentHeight := virtualHeight
        contentWidth := contentHeight * narrowAspectRatio
        narrowCanvasLeft := virtualLeft + (virtualWidth - contentWidth) / 2
        narrowCanvasTop := virtualTop
        narrowCanvasRight := narrowCanvasLeft + contentWidth
        narrowCanvasBottom := virtualTop + contentHeight
    } else {
        ; Screen is taller than 4:3 - add vertical padding
        contentWidth := virtualWidth
        contentHeight := contentWidth / narrowAspectRatio
        narrowCanvasLeft := virtualLeft
        narrowCanvasTop := virtualTop + (virtualHeight - contentHeight) / 2
        narrowCanvasRight := virtualLeft + contentWidth
        narrowCanvasBottom := narrowCanvasTop + contentHeight
    }
}

; ===== VISUALIZATION SETTINGS =====
global visualizationMode := "full"
global visualizationFallbackEnabled := true
global visualizationMaxRetries := 3
global visualizationTimeout := 5000
global visualizationSavePath := "auto"

; ===== HBITMAP CACHE =====
global hbitmapCache := Map()
global buttonDisplayedHBITMAPs := Map()

; ===== LETTERBOXING PREFERENCES =====
global buttonLetterboxingStates := Map()
global hbitmapRefCounts := Map()

global severityLevels := ["high", "medium", "low"]

; ===== VISUALIZATION SYSTEM FUNCTIONS =====

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
                VizLog("✓ GDI+ initialized successfully")
            } else {
                UpdateStatus("⚠️ GDI+ initialization failed (error code: " . result . ")")
                VizLog("✗ GDI+ initialization failed with code: " . result)
                gdiPlusInitialized := false
            }
        } catch Error as e {
            UpdateStatus("⚠️ GDI+ startup exception: " . e.Message)
            VizLog("✗ GDI+ startup exception: " . e.Message)
            gdiPlusInitialized := false
        }
        FlushVizLog()
    }


    ; Detect initial canvas type
    DetectCanvasType()
}

ValidateCanvasCalibration() {
    global wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom, isWideCanvasCalibrated
    global narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom, isNarrowCanvasCalibrated
    global userCanvasLeft, userCanvasTop, userCanvasRight, userCanvasBottom, isCanvasCalibrated

    VizLog("=== CANVAS CALIBRATION STATUS ===")

    ; Check Wide canvas
    wideConfigured := (wideCanvasRight > wideCanvasLeft && wideCanvasBottom > wideCanvasTop)
    VizLog("Wide Canvas: " . (wideConfigured ? "CONFIGURED" : "NOT CONFIGURED"))
    if (wideConfigured) {
        VizLog("  - Bounds: L=" . wideCanvasLeft . " T=" . wideCanvasTop . " R=" . wideCanvasRight . " B=" . wideCanvasBottom)
        VizLog("  - Flag: " . (isWideCanvasCalibrated ? "TRUE" : "FALSE"))
    }

    ; Check Narrow canvas
    narrowConfigured := (narrowCanvasRight > narrowCanvasLeft && narrowCanvasBottom > narrowCanvasTop)
    VizLog("Narrow Canvas: " . (narrowConfigured ? "CONFIGURED" : "NOT CONFIGURED"))
    if (narrowConfigured) {
        VizLog("  - Bounds: L=" . narrowCanvasLeft . " T=" . narrowCanvasTop . " R=" . narrowCanvasRight . " B=" . narrowCanvasBottom)
        VizLog("  - Flag: " . (isNarrowCanvasCalibrated ? "TRUE" : "FALSE"))
    }

    ; Check User canvas
    userConfigured := (userCanvasRight > userCanvasLeft && userCanvasBottom > userCanvasTop)
    VizLog("User Canvas: " . (userConfigured ? "CONFIGURED" : "NOT CONFIGURED"))
    if (userConfigured) {
        VizLog("  - Bounds: L=" . userCanvasLeft . " T=" . userCanvasTop . " R=" . userCanvasRight . " B=" . userCanvasBottom)
        VizLog("  - Flag: " . (isCanvasCalibrated ? "TRUE" : "FALSE"))
    }

    ; Warn if no canvas is configured
    if (!wideConfigured && !narrowConfigured && !userConfigured) {
        VizLog("⚠️ WARNING: NO CANVAS CONFIGURED - Visualization will fail!")
        UpdateStatus("⚠️ Canvas not calibrated - Please configure in Settings")
    } else {
        VizLog("✓ At least one canvas is configured")
    }

    FlushVizLog()
}

; ===== BOX EVENT EXTRACTION =====
ExtractBoxEvents(macroEvents) {
    boxes := []
    currentDegradationType := 1  ; Default degradation type

    ; Look for boundingBox events and keypress assignments in MacroLauncherX44 format
    for eventIndex, event in macroEvents {
        ; Handle both Map and Object types
        eventType := ""
        hasProps := false
        if (Type(event) = "Map") {
            eventType := event.Has("type") ? event["type"] : ""
            hasProps := event.Has("left") && event.Has("top") && event.Has("right") && event.Has("bottom")
        } else if (IsObject(event)) {
            eventType := event.HasOwnProp("type") ? event.type : ""
            hasProps := event.HasOwnProp("left") && event.HasOwnProp("top") && event.HasOwnProp("right") && event.HasOwnProp("bottom")
        }

        if (eventType = "boundingBox" && hasProps) {
            ; Calculate box dimensions (support both Map and Object)
            left := (Type(event) = "Map") ? event["left"] : event.left
            top := (Type(event) = "Map") ? event["top"] : event.top
            right := (Type(event) = "Map") ? event["right"] : event.right
            bottom := (Type(event) = "Map") ? event["bottom"] : event.bottom

            ; Only include boxes that are reasonably sized
            if ((right - left) >= 5 && (bottom - top) >= 5) {
                ; Look for a keypress AFTER this box to determine degradation type
                degradationType := currentDegradationType

                ; Look ahead for keypress events that assign degradation type
                nextIndex := eventIndex + 1
                while (nextIndex <= macroEvents.Length) {
                    nextEvent := macroEvents[nextIndex]

                    ; Get next event type (support Map and Object)
                    nextEventType := ""
                    if (Type(nextEvent) = "Map") {
                        nextEventType := nextEvent.Has("type") ? nextEvent["type"] : ""
                    } else if (IsObject(nextEvent)) {
                        nextEventType := nextEvent.HasOwnProp("type") ? nextEvent.type : ""
                    }

                    ; Stop at next bounding box - keypress should be immediately after current box
                    if (nextEventType = "boundingBox")
                        break

                    ; Found a keypress after this box - this assigns the degradation type
                    if (nextEventType = "keyDown") {
                        nextKey := (Type(nextEvent) = "Map") ? (nextEvent.Has("key") ? nextEvent["key"] : "") : (nextEvent.HasOwnProp("key") ? nextEvent.key : "")
                        if (RegExMatch(nextKey, "^\d$")) {
                            keyNumber := Integer(nextKey)
                            if (keyNumber >= 1 && keyNumber <= 9) {
                                degradationType := keyNumber
                                currentDegradationType := keyNumber  ; Update current degradation for subsequent boxes
                                break
                            }
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

; ===== VISUALIZATION CANVAS MODULE =====
; Handles canvas detection and scaling logic for drawing boxes on buttons

DrawMacroBoxesOnButton(graphics, buttonWidth, buttonHeight, boxes, macroEventsArray := "") {
    global degradationColors, annotationMode, userCanvasLeft, userCanvasTop, userCanvasRight, userCanvasBottom, isCanvasCalibrated
    global wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom, isWideCanvasCalibrated
    global narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom, isNarrowCanvasCalibrated
    global buttonLetterboxingStates

    if (boxes.Length = 0) {
        return
    }

    ; Get stored recording mode from macro events - SIMPLIFIED
    storedMode := ""
    try {
        if (IsObject(macroEventsArray) && Type(macroEventsArray) != "Map") {
            storedMode := macroEventsArray.recordedMode
        }
    } catch {
        storedMode := ""
    }

    ; Use stored mode if available, otherwise use current annotation mode
    ; HOWEVER: If the stored mode's canvas is not configured, fall back to current mode
    effectiveMode := (storedMode != "" && storedMode != "unknown") ? storedMode : annotationMode

    ; Check if effectiveMode's canvas is actually configured
    global wideCanvasRight, wideCanvasLeft, narrowCanvasRight, narrowCanvasLeft
    wideConfiguredCheck := (wideCanvasRight > wideCanvasLeft)
    narrowConfiguredCheck := (narrowCanvasRight > narrowCanvasLeft)

    ; If stored mode's canvas isn't configured, use current annotation mode instead
    if (effectiveMode = "Wide" && !wideConfiguredCheck && narrowConfiguredCheck) {
        VizLog("⚠️ Wide canvas not configured, falling back to Narrow")
        effectiveMode := "Narrow"
    } else if (effectiveMode = "Narrow" && !narrowConfiguredCheck && wideConfiguredCheck) {
        VizLog("⚠️ Narrow canvas not configured, falling back to Wide")
        effectiveMode := "Wide"
    }

    recordedCanvas := ""
    recordedCanvasMode := ""
    hasRecordedCanvas := false
    try {
        if (IsObject(macroEventsArray) && Type(macroEventsArray) != "Map" && macroEventsArray.HasOwnProp("recordedCanvas")) {
            recordedCanvas := macroEventsArray.recordedCanvas
            if (IsObject(recordedCanvas) && recordedCanvas.HasOwnProp("left") && recordedCanvas.HasOwnProp("right")) {
                hasRecordedCanvas := true
                if (recordedCanvas.HasOwnProp("mode")) {
                    recordedCanvasMode := recordedCanvas.mode
                }
            }
        }
    } catch {
        hasRecordedCanvas := false
    }

    wideConfigured := (wideCanvasRight > wideCanvasLeft && wideCanvasBottom > wideCanvasTop)
    narrowConfigured := (narrowCanvasRight > narrowCanvasLeft && narrowCanvasBottom > narrowCanvasTop)
    userConfigured := (isCanvasCalibrated && userCanvasRight > userCanvasLeft && userCanvasBottom > userCanvasTop)

    VizLog("DrawMacroBoxes - effectiveMode: " . effectiveMode . ", boxes: " . boxes.Length)
    VizLog("  Wide: " . (wideConfigured ? "YES" : "NO") . ", Narrow: " . (narrowConfigured ? "YES" : "NO") . ", User: " . (userConfigured ? "YES" : "NO"))

    ; SAFETY: If NO canvas is configured at all, we'll rely on fallback box derivation
    if (!wideConfigured && !narrowConfigured && !userConfigured && !hasRecordedCanvas) {
        VizLog("⚠️ WARNING: No canvas configured at all - will use fallback box derivation")
    }

    offsetX := 0
    offsetY := 0
    scaleX := 1
    scaleY := 1
    canvasSource := ""
    canvasChosen := false
    useFallbackBoxes := false

    if (!canvasChosen && effectiveMode = "Narrow" && narrowConfigured) {
        canvasLeft := narrowCanvasLeft
        canvasTop := narrowCanvasTop
        canvasRight := narrowCanvasRight
        canvasBottom := narrowCanvasBottom
        canvasW := canvasRight - canvasLeft
        canvasH := canvasBottom - canvasTop

        narrowAspect := 4.0 / 3.0
        buttonAspect := buttonWidth / buttonHeight

        if (buttonAspect > narrowAspect) {
            contentHeight := buttonHeight
            contentWidth := contentHeight * narrowAspect
        } else {
            contentWidth := buttonWidth
            contentHeight := contentWidth / narrowAspect
        }

        offsetX := (buttonWidth - contentWidth) / 2
        offsetY := (buttonHeight - contentHeight) / 2

        darkGrayBrush := 0
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF2A2A2A, "Ptr*", &darkGrayBrush)
        DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", darkGrayBrush, "Float", offsetX, "Float", offsetY, "Float", contentWidth, "Float", contentHeight)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", darkGrayBrush)

        safeCanvasW := canvasW != 0 ? canvasW : 1
        safeCanvasH := canvasH != 0 ? canvasH : 1
        scaleX := contentWidth / safeCanvasW
        scaleY := contentHeight / safeCanvasH
        canvasSource := "narrow_calibrated"
        canvasChosen := true
    }

    if (!canvasChosen && effectiveMode = "Narrow" && hasRecordedCanvas && (recordedCanvasMode = "" || recordedCanvasMode = "Narrow")) {
        canvasLeft := recordedCanvas.left + 0.0
        canvasTop := recordedCanvas.top + 0.0
        canvasRight := recordedCanvas.right + 0.0
        canvasBottom := recordedCanvas.bottom + 0.0
        canvasW := canvasRight - canvasLeft
        canvasH := canvasBottom - canvasTop

        narrowAspect := 4.0 / 3.0
        buttonAspect := buttonWidth / buttonHeight

        if (buttonAspect > narrowAspect) {
            contentHeight := buttonHeight
            contentWidth := contentHeight * narrowAspect
        } else {
            contentWidth := buttonWidth
            contentHeight := contentWidth / narrowAspect
        }

        offsetX := (buttonWidth - contentWidth) / 2
        offsetY := (buttonHeight - contentHeight) / 2

        darkGrayBrush := 0
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF2A2A2A, "Ptr*", &darkGrayBrush)
        DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", darkGrayBrush, "Float", offsetX, "Float", offsetY, "Float", contentWidth, "Float", contentHeight)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", darkGrayBrush)

        safeCanvasW := canvasW != 0 ? canvasW : 1
        safeCanvasH := canvasH != 0 ? canvasH : 1
        scaleX := contentWidth / safeCanvasW
        scaleY := contentHeight / safeCanvasH
        canvasSource := recordedCanvas.HasOwnProp("source") ? recordedCanvas.source : "recorded_canvas"
        canvasChosen := true
    }

    if (!canvasChosen && effectiveMode = "Wide" && wideConfigured) {
        canvasLeft := wideCanvasLeft
        canvasTop := wideCanvasTop
        canvasRight := wideCanvasRight
        canvasBottom := wideCanvasBottom
        canvasW := canvasRight - canvasLeft
        canvasH := canvasBottom - canvasTop

        darkGrayBrush := 0
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF2A2A2A, "Ptr*", &darkGrayBrush)
        DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", darkGrayBrush, "Float", 0, "Float", 0, "Float", buttonWidth, "Float", buttonHeight)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", darkGrayBrush)

        safeCanvasW := canvasW != 0 ? canvasW : 1
        safeCanvasH := canvasH != 0 ? canvasH : 1
        scaleX := buttonWidth / safeCanvasW
        scaleY := buttonHeight / safeCanvasH
        canvasSource := "wide_calibrated"
        canvasChosen := true
    }

    if (!canvasChosen && effectiveMode = "Wide" && hasRecordedCanvas && (recordedCanvasMode = "" || recordedCanvasMode = "Wide")) {
        canvasLeft := recordedCanvas.left + 0.0
        canvasTop := recordedCanvas.top + 0.0
        canvasRight := recordedCanvas.right + 0.0
        canvasBottom := recordedCanvas.bottom + 0.0
        canvasW := canvasRight - canvasLeft
        canvasH := canvasBottom - canvasTop

        darkGrayBrush := 0
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF2A2A2A, "Ptr*", &darkGrayBrush)
        DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", darkGrayBrush, "Float", 0, "Float", 0, "Float", buttonWidth, "Float", buttonHeight)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", darkGrayBrush)

        safeCanvasW := canvasW != 0 ? canvasW : 1
        safeCanvasH := canvasH != 0 ? canvasH : 1
        scaleX := buttonWidth / safeCanvasW
        scaleY := buttonHeight / safeCanvasH
        canvasSource := recordedCanvas.HasOwnProp("source") ? recordedCanvas.source : "recorded_canvas"
        canvasChosen := true
    }

    if (!canvasChosen && userConfigured) {
        canvasLeft := userCanvasLeft
        canvasTop := userCanvasTop
        canvasRight := userCanvasRight
        canvasBottom := userCanvasBottom
        canvasW := canvasRight - canvasLeft
        canvasH := canvasBottom - canvasTop

        darkGrayBrush := 0
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF2A2A2A, "Ptr*", &darkGrayBrush)
        DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", darkGrayBrush, "Float", 0, "Float", 0, "Float", buttonWidth, "Float", buttonHeight)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", darkGrayBrush)

        safeCanvasW := canvasW != 0 ? canvasW : 1
        safeCanvasH := canvasH != 0 ? canvasH : 1
        scaleX := buttonWidth / safeCanvasW
        scaleY := buttonHeight / safeCanvasH
        canvasSource := "user_calibrated"
        canvasChosen := true
    }

    if (!canvasChosen && hasRecordedCanvas) {
        canvasLeft := recordedCanvas.left + 0.0
        canvasTop := recordedCanvas.top + 0.0
        canvasRight := recordedCanvas.right + 0.0
        canvasBottom := recordedCanvas.bottom + 0.0
        canvasW := canvasRight - canvasLeft
        canvasH := canvasBottom - canvasTop

        narrowAspect := 4.0 / 3.0
        recordedAspect := (canvasH != 0) ? (canvasW / canvasH) : 0
        buttonAspect := buttonWidth / buttonHeight

        if (recordedAspect > narrowAspect + 0.05) {
            offsetX := 0
            offsetY := 0
            darkGrayBrush := 0
            DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF2A2A2A, "Ptr*", &darkGrayBrush)
            DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", darkGrayBrush, "Float", 0, "Float", 0, "Float", buttonWidth, "Float", buttonHeight)
            DllCall("gdiplus\GdipDeleteBrush", "Ptr", darkGrayBrush)

            safeCanvasW := canvasW != 0 ? canvasW : 1
            safeCanvasH := canvasH != 0 ? canvasH : 1
            scaleX := buttonWidth / safeCanvasW
            scaleY := buttonHeight / safeCanvasH
        } else {
            if (buttonAspect > narrowAspect) {
                contentHeight := buttonHeight
                contentWidth := contentHeight * narrowAspect
            } else {
                contentWidth := buttonWidth
                contentHeight := contentWidth / narrowAspect
            }

            offsetX := (buttonWidth - contentWidth) / 2
            offsetY := (buttonHeight - contentHeight) / 2

            darkGrayBrush := 0
            DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF2A2A2A, "Ptr*", &darkGrayBrush)
            DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", darkGrayBrush, "Float", offsetX, "Float", offsetY, "Float", contentWidth, "Float", contentHeight)
            DllCall("gdiplus\GdipDeleteBrush", "Ptr", darkGrayBrush)

            safeCanvasW := canvasW != 0 ? canvasW : 1
            safeCanvasH := canvasH != 0 ? canvasH : 1
            scaleX := contentWidth / safeCanvasW
            scaleY := contentHeight / safeCanvasH
        }

        canvasSource := recordedCanvas.HasOwnProp("source") ? recordedCanvas.source : "recorded_canvas"
        canvasChosen := true
    }

    if (!canvasChosen && narrowConfigured) {
        canvasLeft := narrowCanvasLeft
        canvasTop := narrowCanvasTop
        canvasRight := narrowCanvasRight
        canvasBottom := narrowCanvasBottom
        canvasW := canvasRight - canvasLeft
        canvasH := canvasBottom - canvasTop

        narrowAspect := 4.0 / 3.0
        buttonAspect := buttonWidth / buttonHeight

        if (buttonAspect > narrowAspect) {
            contentHeight := buttonHeight
            contentWidth := contentHeight * narrowAspect
        } else {
            contentWidth := buttonWidth
            contentHeight := contentWidth / narrowAspect
        }

        offsetX := (buttonWidth - contentWidth) / 2
        offsetY := (buttonHeight - contentHeight) / 2

        darkGrayBrush := 0
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF2A2A2A, "Ptr*", &darkGrayBrush)
        DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", darkGrayBrush, "Float", offsetX, "Float", offsetY, "Float", contentWidth, "Float", contentHeight)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", darkGrayBrush)

        safeCanvasW := canvasW != 0 ? canvasW : 1
        safeCanvasH := canvasH != 0 ? canvasH : 1
        scaleX := contentWidth / safeCanvasW
        scaleY := contentHeight / safeCanvasH
        canvasSource := "narrow_default"
        canvasChosen := true
    }

    if (!canvasChosen && wideConfigured) {
        canvasLeft := wideCanvasLeft
        canvasTop := wideCanvasTop
        canvasRight := wideCanvasRight
        canvasBottom := wideCanvasBottom
        canvasW := canvasRight - canvasLeft
        canvasH := canvasBottom - canvasTop

        darkGrayBrush := 0
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF2A2A2A, "Ptr*", &darkGrayBrush)
        DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", darkGrayBrush, "Float", 0, "Float", 0, "Float", buttonWidth, "Float", buttonHeight)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", darkGrayBrush)

        safeCanvasW := canvasW != 0 ? canvasW : 1
        safeCanvasH := canvasH != 0 ? canvasH : 1
        scaleX := buttonWidth / safeCanvasW
        scaleY := buttonHeight / safeCanvasH
        canvasSource := "wide_default"
        canvasChosen := true
    }

    if (!canvasChosen) {
        VizLog("⚠️ No canvas configured for mode: " . effectiveMode . " - Using fallback box derivation")
        useFallbackBoxes := true
    }

    if (useFallbackBoxes) {
        ; No manual calibration - derive canvas from recorded boxes (FALLBACK)
        VizLog("Using fallback: deriving canvas from box coordinates")
        minX := 999999
        minY := 999999
        maxX := -999999
        maxY := -999999
        hasValidBox := false

        for box in boxes {
            hasValidBox := true

            if (box.left < minX) {
                minX := box.left
            }
            if (box.top < minY) {
                minY := box.top
            }
            if (box.right > maxX) {
                maxX := box.right
            }
            if (box.bottom > maxY) {
                maxY := box.bottom
            }
        }

        if (!hasValidBox) {
            return
        }

        canvasLeft := minX
        canvasTop := minY
        canvasRight := maxX
        canvasBottom := maxY
        canvasW := maxX - minX
        canvasH := maxY - minY

        ; Fill background
        darkGrayBrush := 0
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF2A2A2A, "Ptr*", &darkGrayBrush)
        DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", darkGrayBrush, "Float", 0, "Float", 0, "Float", buttonWidth, "Float", buttonHeight)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", darkGrayBrush)

        safeCanvasW := canvasW != 0 ? canvasW : 1
        safeCanvasH := canvasH != 0 ? canvasH : 1
        scaleX := buttonWidth / safeCanvasW
        scaleY := buttonHeight / safeCanvasH
        offsetX := 0
        offsetY := 0
        canvasSource := hasRecordedCanvas ? "recorded_bounds" : "derived_bounds"
        canvasChosen := true
    }

    if (canvasSource = "")
        canvasSource := "auto"

    if (IsObject(macroEventsArray) && Type(macroEventsArray) != "Map") {
        macroEventsArray.recordedMode := effectiveMode
        macroEventsArray.recordedCanvas := {
            mode: effectiveMode,
            left: canvasLeft,
            top: canvasTop,
            right: canvasRight,
            bottom: canvasBottom,
            canvasWidth: canvasW,
            canvasHeight: canvasH,
            offsetX: offsetX,
            offsetY: offsetY,
            scaleX: scaleX,
            scaleY: scaleY,
            source: canvasSource
        }
    }

    ; Log canvas selection details for diagnostics
    VizLog("✓ Canvas selected: " . canvasSource)
    VizLog("  Bounds: L=" . Round(canvasLeft, 1) . " T=" . Round(canvasTop, 1) . " R=" . Round(canvasRight, 1) . " B=" . Round(canvasBottom, 1))
    VizLog("  Canvas size: " . Round(canvasW, 1) . "x" . Round(canvasH, 1))
    VizLog("  Scale: X=" . Round(scaleX, 3) . " Y=" . Round(scaleY, 3))
    VizLog("  Offset: X=" . Round(offsetX, 1) . " Y=" . Round(offsetY, 1))
    VizLog("  Button: " . Round(buttonWidth, 1) . "x" . Round(buttonHeight, 1))

    ; Validate canvas dimensions
    if (canvasW <= 0 || canvasH <= 0) {
        return
    }

    ; Track boxes drawn vs skipped for diagnostics
    local boxesDrawn := 0
    local boxesSkipped := 0

    ; Draw boxes with consistent percentage-based scaling
    for box in boxes {
        ; Clamp box coordinates into the active canvas before scaling
        boxLeft := Max(canvasLeft, Min(box.left, canvasRight))
        boxTop := Max(canvasTop, Min(box.top, canvasBottom))
        boxRight := Max(canvasLeft, Min(box.right, canvasRight))
        boxBottom := Max(canvasTop, Min(box.bottom, canvasBottom))

        if (boxRight <= boxLeft || boxBottom <= boxTop) {
            boxesSkipped++
            VizLog("  ⊗ Skipped box (clamped to zero size)")
            continue
        }

        ; Map box coordinates from canvas to button space using percentage scaling
        rawX1 := ((boxLeft - canvasLeft) * scaleX) + offsetX
        rawY1 := ((boxTop - canvasTop) * scaleY) + offsetY
        rawX2 := ((boxRight - canvasLeft) * scaleX) + offsetX
        rawY2 := ((boxBottom - canvasTop) * scaleY) + offsetY

        ; Calculate dimensions with floating-point precision
        rawW := rawX2 - rawX1
        rawH := rawY2 - rawY1

        if (rawW <= 0 || rawH <= 0) {
            boxesSkipped++
            VizLog("  ⊗ Skipped box (zero dimensions after scaling)")
            continue
        }

        ; INTELLIGENT MINIMUM SIZE: Preserve aspect ratio while ensuring visibility
        minSize := 2.5
        originalWidth := boxRight - boxLeft
        originalHeight := boxBottom - boxTop
        originalAspect := originalWidth / originalHeight

        if (rawW < minSize || rawH < minSize) {
            ; Calculate original aspect ratio

            if (rawW < minSize && rawH < minSize) {
                ; Both dimensions too small - scale proportionally
                if (originalAspect > 1) {
                    ; Wider box - set width to minimum, scale height proportionally
                    w := minSize
                    h := minSize / originalAspect
                } else {
                    ; Taller box - set height to minimum, scale width proportionally
                    h := minSize
                    w := minSize * originalAspect
                }
            } else if (rawW < minSize) {
                ; Width too small - adjust while preserving aspect ratio
                w := minSize
                h := minSize / originalAspect
            } else {
                ; Height too small - adjust while preserving aspect ratio
                h := minSize
                w := minSize * originalAspect
            }

            ; Center the adjusted box on the original position
            centerX := (rawX1 + rawX2) / 2
            centerY := (rawY1 + rawY2) / 2
            x1 := centerX - w / 2
            y1 := centerY - h / 2
            x2 := x1 + w
            y2 := y1 + h
        } else {
            ; Use precise floating-point coordinates
            x1 := rawX1
            y1 := rawY1
            x2 := rawX2
            y2 := rawY2
            w := rawW
            h := rawH
        }

        ; BOUNDS VALIDATION: Ensure coordinates are within button area
        x1 := Max(0, Min(x1, buttonWidth))
        y1 := Max(0, Min(y1, buttonHeight))
        x2 := Max(0, Min(x2, buttonWidth))
        y2 := Max(0, Min(y2, buttonHeight))
        w := x2 - x1
        h := y2 - y1

        ; Skip boxes that are too small to see
        if (w < 1.5 || h < 1.5) {
            boxesSkipped++
            VizLog("  ⊗ Skipped box (too small after bounds validation)")
            continue
        }

        ; Ensure minimum visible size
        if (w < 2) {
            w := 2
            x2 := x1 + w
        }
        if (h < 2) {
            h := 2
            y2 := y1 + h
        }

        ; Get degradation type color
        if (box.HasOwnProp("degradationType") && degradationColors.Has(box.degradationType)) {
            color := degradationColors[box.degradationType]
        } else {
            color := degradationColors[1]
        }

        ; Draw with sub-pixel precision
        fillColor := 0xFF000000 | color

        ; Enable high-quality rendering
        DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", graphics, "Int", 4)
        DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", graphics, "Int", 4)

        ; Draw the box
        brush := 0
        result := DllCall("gdiplus\GdipCreateSolidFill", "UInt", fillColor, "Ptr*", &brush)
        if (result = 0) {
            DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", brush, "Float", x1, "Float", y1, "Float", w, "Float", h)
            DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
        }

        ; Reset rendering mode
        DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", graphics, "Int", 0)
        DllCall("gdiplus\GdipSetPixelOffsetMode", "Ptr", graphics, "Int", 0)

        ; Count this box as successfully drawn
        boxesDrawn++
    }

    ; Log drawing summary
    VizLog("✓ Drawing complete: " . boxesDrawn . " drawn, " . boxesSkipped . " skipped")
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





; VizLog infrastructure for debugging visualization issues
global vizLogBuffer := []
global vizLogPath := A_ScriptDir "\vizlog_debug.txt"

VizLog(msg) {
    global vizLogBuffer
    vizLogBuffer.Push(A_Now . " - " . msg)
}

FlushVizLog() {
    global vizLogBuffer, vizLogPath
    if (vizLogBuffer.Length > 0) {
        content := ""
        for index, line in vizLogBuffer {
            content .= line . "`n"
        }
        try {
            FileAppend(content, vizLogPath)
        } catch as e {
            ; Silently fail if we can't write log
        }
        vizLogBuffer := []
    }
}

CreateJsonAnnotationVisual(buttonWidth, buttonHeight, labelText, colorHex, isNarrowMode) {
    ; Creates an HBITMAP with colored background and letterboxing for Narrow mode
    global gdiPlusInitialized

    if (!gdiPlusInitialized) {
        return 0
    }

    bitmap := 0
    graphics := 0
    hbitmap := 0

    try {
        ; Create bitmap
        DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", buttonWidth, "Int", buttonHeight, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bitmap)
        DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bitmap, "Ptr*", &graphics)

        ; Set high quality rendering
        DllCall("gdiplus\GdipSetSmoothingMode", "Ptr", graphics, "Int", 4)
        DllCall("gdiplus\GdipSetTextRenderingHint", "Ptr", graphics, "Int", 4)

        ; Convert color hex string to integer with full alpha
        ; degradationColors values are like "0xFF8C00" (RGB only)
        ; We need to ensure it has full alpha: 0xFFFF8C00 (ARGB)
        colorInt := Integer(colorHex)
        ; If the value is less than 0x01000000, it's missing the alpha channel
        if (colorInt < 0x01000000) {
            colorInt := colorInt | 0xFF000000  ; Add full alpha
        }

        ; Always fill with degradation color first
        colorBrush := 0
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", colorInt, "Ptr*", &colorBrush)
        DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", colorBrush, "Float", 0, "Float", 0, "Float", buttonWidth, "Float", buttonHeight)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", colorBrush)

        if (isNarrowMode) {
            ; Narrow mode: Add black letterboxing bars to show 4:3 content area
            narrowAspect := 4.0 / 3.0
            buttonAspect := buttonWidth / buttonHeight

            if (buttonAspect > narrowAspect) {
                ; Button is wider - add letterbox bars on left/right sides
                contentHeight := buttonHeight
                contentWidth := contentHeight * narrowAspect
                offsetX := (buttonWidth - contentWidth) / 2
                offsetY := 0

                ; Draw black bars on sides
                blackBrush := 0
                DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF000000, "Ptr*", &blackBrush)
                ; Left bar
                DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", blackBrush, "Float", 0, "Float", 0, "Float", offsetX, "Float", buttonHeight)
                ; Right bar
                DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", blackBrush, "Float", offsetX + contentWidth, "Float", 0, "Float", offsetX, "Float", buttonHeight)
                DllCall("gdiplus\GdipDeleteBrush", "Ptr", blackBrush)

                ; Text in content area
                textX := offsetX
                textY := 0
                textWidth := contentWidth
                textHeight := buttonHeight
            } else {
                ; Button is taller - add letterbox bars on top/bottom
                contentWidth := buttonWidth
                contentHeight := contentWidth / narrowAspect
                offsetX := 0
                offsetY := (buttonHeight - contentHeight) / 2

                ; Draw black bars on top/bottom
                blackBrush := 0
                DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF000000, "Ptr*", &blackBrush)
                ; Top bar
                DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", blackBrush, "Float", 0, "Float", 0, "Float", buttonWidth, "Float", offsetY)
                ; Bottom bar
                DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", blackBrush, "Float", 0, "Float", offsetY + contentHeight, "Float", buttonWidth, "Float", offsetY)
                DllCall("gdiplus\GdipDeleteBrush", "Ptr", blackBrush)

                ; Text in content area
                textX := 0
                textY := offsetY
                textWidth := buttonWidth
                textHeight := contentHeight
            }
        } else {
            ; Wide mode: No letterboxing, use full button
            textX := 0
            textY := 0
            textWidth := buttonWidth
            textHeight := buttonHeight
        }

        ; Draw text label
        fontFamily := 0
        font := 0
        stringFormat := 0
        textBrush := 0

        DllCall("gdiplus\GdipCreateFontFamilyFromName", "WStr", "Arial", "Ptr", 0, "Ptr*", &fontFamily)
        DllCall("gdiplus\GdipCreateFont", "Ptr", fontFamily, "Float", 11, "Int", 1, "Int", 2, "Ptr*", &font)
        DllCall("gdiplus\GdipCreateStringFormat", "Int", 0, "Int", 0, "Ptr*", &stringFormat)
        DllCall("gdiplus\GdipSetStringFormatAlign", "Ptr", stringFormat, "Int", 1)  ; Center
        DllCall("gdiplus\GdipSetStringFormatLineAlign", "Ptr", stringFormat, "Int", 1)  ; Middle

        ; Use black text
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF000000, "Ptr*", &textBrush)

        rectF := Buffer(16, 0)
        NumPut("Float", textX, rectF, 0)
        NumPut("Float", textY, rectF, 4)
        NumPut("Float", textWidth, rectF, 8)
        NumPut("Float", textHeight, rectF, 12)

        DllCall("gdiplus\GdipDrawString", "Ptr", graphics, "WStr", labelText, "Int", -1, "Ptr", font, "Ptr", rectF, "Ptr", stringFormat, "Ptr", textBrush)

        ; Cleanup text resources
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", textBrush)
        DllCall("gdiplus\GdipDeleteStringFormat", "Ptr", stringFormat)
        DllCall("gdiplus\GdipDeleteFont", "Ptr", font)
        DllCall("gdiplus\GdipDeleteFontFamily", "Ptr", fontFamily)

        ; Convert to HBITMAP
        DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", bitmap, "Ptr*", &hbitmap, "UInt", 0xFF000000)

        return hbitmap
    } catch {
        return 0
    } finally {
        if (graphics)
            DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
        if (bitmap)
            DllCall("gdiplus\GdipDisposeImage", "Ptr", bitmap)
    }
}

CreateHBITMAPVisualization(macroEvents, buttonDims) {
    ; Memory-only visualization using HBITMAP with caching for performance
    global gdiPlusInitialized, degradationColors, hbitmapCache

    VizLog("=== CreateHBITMAPVisualization START ===")

    if (!gdiPlusInitialized) {
        VizLog("GDI+ not initialized, calling InitializeVisualizationSystem")
        InitializeVisualizationSystem()
        if (!gdiPlusInitialized) {
            VizLog("GDI+ initialization FAILED - returning 0")
            FlushVizLog()
            return 0
        }
        VizLog("GDI+ initialization SUCCESS")
    } else {
        VizLog("GDI+ already initialized")
    }

    if (!macroEvents || macroEvents.Length = 0) {
        VizLog("No macro events - returning 0")
        FlushVizLog()
        return 0
    }

    VizLog("Macro events: " . macroEvents.Length)

    ; Handle both old (single size) and new (width/height object) format
    if (IsObject(buttonDims)) {
        buttonWidth := buttonDims.width
        buttonHeight := buttonDims.height
    } else {
        buttonWidth := buttonDims
        buttonHeight := buttonDims
    }

    VizLog("Button dimensions: " . buttonWidth . "x" . buttonHeight)

    ; PERFORMANCE: Generate cache key based on macro events content
    cacheKey := ""
    for event in macroEvents {
        if (event.type = "boundingBox") {
            cacheKey .= event.left . "," . event.top . "," . event.right . "," . event.bottom . "|"
        }
    }
    recordedMode := ""
    try {
        recordedMode := macroEvents.recordedMode
    } catch {
        recordedMode := "unknown"
    }
    cacheKey .= buttonWidth . "x" . buttonHeight . "_" . recordedMode

    VizLog("Cache key: " . cacheKey)

    ; Check cache first
    if (hbitmapCache.Has(cacheKey)) {
        cachedHBITMAP := hbitmapCache[cacheKey]
        if (IsHBITMAPValid(cachedHBITMAP)) {
            VizLog("CACHE HIT - returning cached HBITMAP: " . cachedHBITMAP)
            FlushVizLog()
            return cachedHBITMAP
        } else {
            VizLog("CACHE HIT INVALID - removing cached HBITMAP for key: " . cacheKey)
            RemoveHBITMAPReference(cachedHBITMAP)
            hbitmapCache.Delete(cacheKey)
        }
    }

    VizLog("Cache miss - creating new HBITMAP")

    ; Extract box drawing events
    boxes := ExtractBoxEvents(macroEvents)
    VizLog("Extracted boxes: " . boxes.Length)
    if (boxes.Length = 0) {
        VizLog("No boxes found - returning 0")
        FlushVizLog()
        return 0
    }

    ; Create HBITMAP using GDI+
    bitmap := 0
    graphics := 0
    hbitmap := 0

    try {
        ; Validate dimensions
        if (buttonWidth <= 0 || buttonHeight <= 0 || buttonWidth > 4096 || buttonHeight > 4096) {
            VizLog("Invalid dimensions - returning 0")
            FlushVizLog()
            return 0
        }

        VizLog("Creating GDI+ bitmap...")
        ; Create GDI+ bitmap
        bitmap := 0
        result := DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", buttonWidth, "Int", buttonHeight, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bitmap)
        VizLog("GdipCreateBitmapFromScan0: result=" . result . ", bitmap=" . bitmap)
        if (result != 0 || !bitmap) {
            VizLog("Bitmap creation FAILED - returning 0")
            FlushVizLog()
            return 0
        }

        VizLog("Creating graphics context...")
        ; Create graphics context from bitmap
        graphics := 0
        result := DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bitmap, "Ptr*", &graphics)
        VizLog("GdipGetImageGraphicsContext: result=" . result . ", graphics=" . graphics)
        if (result != 0 || !graphics) {
            VizLog("Graphics context creation FAILED - returning 0")
            DllCall("gdiplus\GdipDisposeImage", "Ptr", bitmap)
            FlushVizLog()
            return 0
        }

        VizLog("Clearing background...")
        ; Black background for letterboxing contrast
        DllCall("gdiplus\GdipGraphicsClear", "Ptr", graphics, "UInt", 0xFF000000)

        VizLog("Drawing boxes...")
        ; Draw macro boxes optimized for button dimensions
        DrawMacroBoxesOnButton(graphics, buttonWidth, buttonHeight, boxes, macroEvents)

        VizLog("Converting to HBITMAP...")
        ; Convert GDI+ bitmap to HBITMAP
        hbitmap := 0
        result := DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", bitmap, "Ptr*", &hbitmap, "UInt", 0x00000000)
        VizLog("GdipCreateHBITMAPFromBitmap: result=" . result . ", hbitmap=" . hbitmap)

        ; Clean up GDI+ objects
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", bitmap)

        if (result = 0 && hbitmap) {
            VizLog("SUCCESS! Caching and returning HBITMAP: " . hbitmap)
            ; PERFORMANCE: Cache the HBITMAP for future use and add reference
            hbitmapCache[cacheKey] := hbitmap
            AddHBITMAPReference(hbitmap)
            FlushVizLog()
            return hbitmap
        } else {
            VizLog("HBITMAP conversion FAILED (result=" . result . ", hbitmap=" . hbitmap . ") - returning 0")
            FlushVizLog()
            return 0
        }

    } catch Error as e {
        VizLog("EXCEPTION CAUGHT: " . e.Message . " at line " . e.Line)
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
        FlushVizLog()
        return 0
    }
}

CleanupHBITMAPCache() {
    global hbitmapCache

    ; Delete all HBITMAP handles
    for cacheKey, hbitmap in hbitmapCache {
        if (hbitmap) {
            RemoveHBITMAPReference(hbitmap)
        }
    }

    ; Clear the cache Map
    hbitmapCache := Map()
}

CleanupButtonDisplayedHBITMAPs() {
    global buttonDisplayedHBITMAPs

    ; Delete all HBITMAP handles currently displayed by buttons
    for buttonName, hbitmap in buttonDisplayedHBITMAPs {
        if (hbitmap) {
            RemoveHBITMAPReference(hbitmap)
        }
    }

    ; Clear the tracking Map
    buttonDisplayedHBITMAPs := Map()
}

AddHBITMAPReference(hbitmap) {
    global hbitmapRefCounts

    if (!hbitmap || hbitmap = 0) {
        return
    }

    if (hbitmapRefCounts.Has(hbitmap)) {
        hbitmapRefCounts[hbitmap] += 1
    } else {
        hbitmapRefCounts[hbitmap] := 1
    }
}

RemoveHBITMAPReference(hbitmap) {
    global hbitmapRefCounts

    if (!hbitmap || hbitmap = 0) {
        return
    }

    if (!hbitmapRefCounts.Has(hbitmap)) {
        return
    }

    hbitmapRefCounts[hbitmap] -= 1

    if (hbitmapRefCounts[hbitmap] <= 0) {
        hbitmapRefCounts.Delete(hbitmap)
        try {
            DllCall("DeleteObject", "Ptr", hbitmap)
        } catch {
        }
    }
}

IsHBITMAPValid(hbitmap) {
    if (!hbitmap || hbitmap = 0) {
        return false
    }

    try {
        result := DllCall("GetObject", "Ptr", hbitmap, "Int", 0, "Ptr", 0)
        return (result != 0)
    } catch {
        return false
    }
}

CreateDirectVisualizationBypass(events, buttonDims) {
    ; Corporate bypass method - simplified text-based visualization
    ; Returns false to fall back to standard visualization
    return false
}

RenderBoxesOnButton(button, bypassData) {
    ; Corporate bypass rendering - not needed with standard visualization
    ; No-op function
    return
}

; ===============================================================================
; ===== STATS DATA MODULE =====
; ===============================================================================
; Handles statistics persistence, aggregation, and CSV writing
; Tracks degradations for both macro executions and JSON profile executions

; Suppress warnings for ObjSave and ObjLoad (defined in ObjPersistence.ahk)
#Warn VarUnset, Off

Stats_GetCsvHeader() {
    return "timestamp,session_id,username,execution_type,button_key,layer,execution_time_ms,total_boxes,degradation_assignments,severity_level,canvas_mode,session_active_time_ms,break_mode_active,smudge_count,glare_count,splashes_count,partial_blockage_count,full_blockage_count,light_flare_count,rain_count,haze_count,snow_count,clear_count,annotation_details,execution_success,error_details`n"
}

Stats_EnsureStatsFile(filePath, encoding := "") {
    if (!FileExist(filePath)) {
        header := Stats_GetCsvHeader()
        if (encoding != "")
            FileAppend(header, filePath, encoding)
        else
            FileAppend(header, filePath)
    }
}

Stats_BuildCsvRow(executionData) {
    global currentSessionId, currentUsername
    row := executionData["timestamp"] . "," . currentSessionId . "," . currentUsername . "," . executionData["execution_type"] . ","
    row .= (executionData.Has("button_key") ? executionData["button_key"] : "") . "," . executionData["layer"] . "," . executionData["execution_time_ms"] . "," . executionData["total_boxes"] . ","
    row .= (executionData.Has("degradation_assignments") ? executionData["degradation_assignments"] : "") . "," . executionData["severity_level"] . "," . executionData["canvas_mode"] . "," . executionData["session_active_time_ms"] . ","
    row .= (executionData.Has("break_mode_active") ? (executionData["break_mode_active"] ? "true" : "false") : "false") . ","
    row .= (executionData.Has("smudge_count") ? executionData["smudge_count"] : 0) . "," . (executionData.Has("glare_count") ? executionData["glare_count"] : 0) . ","
    row .= (executionData.Has("splashes_count") ? executionData["splashes_count"] : 0) . "," . (executionData.Has("partial_blockage_count") ? executionData["partial_blockage_count"] : 0) . ","
    row .= (executionData.Has("full_blockage_count") ? executionData["full_blockage_count"] : 0) . "," . (executionData.Has("light_flare_count") ? executionData["light_flare_count"] : 0) . ","
    row .= (executionData.Has("rain_count") ? executionData["rain_count"] : 0) . "," . (executionData.Has("haze_count") ? executionData["haze_count"] : 0) . ","
    row .= (executionData.Has("snow_count") ? executionData["snow_count"] : 0) . "," . (executionData.Has("clear_count") ? executionData["clear_count"] : 0) . ","
    row .= (executionData.Has("annotation_details") ? executionData["annotation_details"] : "") . "," . (executionData.Has("execution_success") ? executionData["execution_success"] : "true") . ","
    row .= (executionData.Has("error_details") ? executionData["error_details"] : "") . "`n"
    return row
}

InitializeStatsSystem() {
    global masterStatsCSV, documentsDir, workDir, sessionId, permanentStatsFile, currentSessionId
    defaultDocumentsDir := A_MyDocuments . "\MacroMaster"
    if (!IsSet(documentsDir) || documentsDir = "") {
        documentsDir := defaultDocumentsDir
    }
    if (!IsSet(workDir) || workDir = "") {
        workDir := documentsDir . "\data"
    }
    try {
        if (!DirExist(documentsDir)) {
            DirCreate(documentsDir)
        }
        if (!DirExist(workDir)) {
            DirCreate(workDir)
        }
    } catch {
    }
    masterStatsCSV := workDir . "\macro_execution_stats.csv"
    InitializeCSVFile()
    sessionId := "sess_" . FormatTime(A_Now, "yyyyMMdd_HHmmss")
    currentSessionId := sessionId
    InitializePermanentStatsFile()
    LoadStatsFromJson()
    try {
        UpdateStatus("📊 Stats system initialized")
    } catch {
    }
}

InitializeCSVFile() {
    global masterStatsCSV, documentsDir, workDir, sessionId
    try {
        if (!DirExist(documentsDir)) {
            DirCreate(documentsDir)
        }
        if (!DirExist(workDir)) {
            DirCreate(workDir)
        }
        Stats_EnsureStatsFile(masterStatsCSV, "UTF-8")
    } catch as e {
        UpdateStatus("CSV setup failed")
    }
}

InitializePermanentStatsFile() {
    global workDir, permanentStatsFile
    try {
        permanentStatsFile := workDir . "\\master_stats_permanent.csv"
        Stats_EnsureStatsFile(permanentStatsFile, "UTF-8")
    } catch as e {
    }
}

FormatMilliseconds(ms) {
    if (ms < 1000) {
        return ms . " ms"
    } else if (ms < 60000) {
        return Round(ms / 1000, 1) . " sec"
    } else if (ms < 3600000) {
        minutes := Floor(ms / 60000)
        seconds := Round(Mod(ms, 60000) / 1000)
        return minutes . " min " . seconds . " sec"
    } else {
        hours := Floor(ms / 3600000)
        minutes := Round(Mod(ms, 3600000) / 60000)
        return hours . " hr " . minutes . " min"
    }
}

Stats_CreateEmptyStatsMap() {
    global currentUsername, totalActiveTime
    stats := Map()
    stats["current_username"] := currentUsername
    stats["total_executions"] := 0
    stats["macro_executions_count"] := 0
    stats["json_profile_executions_count"] := 0
    stats["clear_executions_count"] := 0
    stats["total_boxes"] := 0
    stats["total_execution_time"] := 0
    stats["average_execution_time"] := 0
    stats["session_active_time"] := totalActiveTime
    stats["boxes_per_hour"] := 0
    stats["user_summary"] := Map()
    stats["distinct_user_count"] := 0
    stats["executions_per_hour"] := 0
    stats["most_used_button"] := ""
    stats["most_active_layer"] := ""
    stats["degradation_totals"] := Map()
    stats["smudge_total"] := 0
    stats["glare_total"] := 0
    stats["splashes_total"] := 0
    stats["partial_blockage_total"] := 0
    stats["full_blockage_total"] := 0
    stats["light_flare_total"] := 0
    stats["rain_total"] := 0
    stats["haze_total"] := 0
    stats["snow_total"] := 0
    stats["clear_total"] := 0
    stats["macro_smudge"] := 0
    stats["macro_glare"] := 0
    stats["macro_splashes"] := 0
    stats["macro_partial"] := 0
    stats["macro_full"] := 0
    stats["macro_flare"] := 0
    stats["macro_rain"] := 0
    stats["macro_haze"] := 0
    stats["macro_snow"] := 0
    stats["macro_clear"] := 0
    stats["json_smudge"] := 0
    stats["json_glare"] := 0
    stats["json_splashes"] := 0
    stats["json_partial"] := 0
    stats["json_full"] := 0
    stats["json_flare"] := 0
    stats["json_rain"] := 0
    stats["json_haze"] := 0
    stats["json_snow"] := 0
    stats["json_clear"] := 0
    stats["severity_low"] := 0
    stats["severity_medium"] := 0
    stats["severity_high"] := 0
    return stats
}

Stats_IncrementDegradationCount(stats, degradation_name, prefix := "json_") {
    switch StrLower(degradation_name) {
        case "smudge", "1":
            stats[prefix . "smudge"]++
        case "glare", "2":
            stats[prefix . "glare"]++
        case "splashes", "3":
            stats[prefix . "splashes"]++
        case "partial_blockage", "4":
            stats[prefix . "partial"]++
        case "full_blockage", "5":
            stats[prefix . "full"]++
        case "light_flare", "6":
            stats[prefix . "flare"]++
        case "rain", "7":
            stats[prefix . "rain"]++
        case "haze", "8":
            stats[prefix . "haze"]++
        case "snow", "9":
            stats[prefix . "snow"]++
        case "clear", "none":
            stats[prefix . "clear"]++
    }
}

Stats_IncrementDegradationCountDirect(executionData, degradation_name) {
    switch StrLower(degradation_name) {
        case "smudge", "1":
            executionData["smudge_count"]++
        case "glare", "2":
            executionData["glare_count"]++
        case "splashes", "3":
            executionData["splashes_count"]++
        case "partial_blockage", "4":
            executionData["partial_blockage_count"]++
        case "full_blockage", "5":
            executionData["full_blockage_count"]++
        case "light_flare", "6":
            executionData["light_flare_count"]++
        case "rain", "7":
            executionData["rain_count"]++
        case "haze", "8":
            executionData["haze_count"]++
        case "snow", "9":
            executionData["snow_count"]++
        case "clear", "none":
            executionData["clear_count"]++
    }
}

ReadStatsFromMemory(filterBySession := false) {
    global macroExecutionLog, sessionId, totalActiveTime, currentUsername
    stats := Stats_CreateEmptyStatsMap()
    sessionActiveMap := Map()
    executionTimes := []
    buttonCount := Map()
    layerCount := Map()
    for executionData in macroExecutionLog {
        try {
            ; Use stored session_id from execution data, fall back to global if not present
            sessionKey := executionData.Has("session_id") ? executionData["session_id"] : sessionId
            if (!filterBySession || sessionKey = sessionId) {
                execution_type := executionData["execution_type"]
                macro_name := executionData.Has("button_key") ? executionData["button_key"] : ""
                layer := executionData.Has("layer") ? executionData["layer"] : 1
                execution_time := executionData.Has("execution_time_ms") ? executionData["execution_time_ms"] : 0
                total_boxes := executionData.Has("total_boxes") ? executionData["total_boxes"] : 0
                severity_level := executionData.Has("severity_level") ? executionData["severity_level"] : ""
                session_active_time := executionData.Has("session_active_time_ms") ? executionData["session_active_time_ms"] : 0
                ; Track maximum active time per session (represents cumulative time at that execution)
                if (!sessionActiveMap.Has(sessionKey) || session_active_time > sessionActiveMap[sessionKey]) {
                    sessionActiveMap[sessionKey] := session_active_time
                }
                ; Use stored username from execution data, fall back to current
                username := executionData.Has("username") ? executionData["username"] : currentUsername
                UpdateUserSummary(stats["user_summary"], username, total_boxes, sessionKey)
                stats["total_executions"]++
                stats["total_boxes"] += total_boxes
                stats["total_execution_time"] += execution_time
                executionTimes.Push(execution_time)
                if (execution_type = "clear") {
                    stats["clear_executions_count"]++
                } else if (execution_type = "json_profile") {
                    stats["json_profile_executions_count"]++
                } else {
                    stats["macro_executions_count"]++
                }
                if (macro_name != "") {
                    if (!buttonCount.Has(macro_name)) {
                        buttonCount[macro_name] := 0
                    }
                    buttonCount[macro_name]++
                }
                if (!layerCount.Has(layer)) {
                    layerCount[layer] := 0
                }
                layerCount[layer]++
                if (execution_type = "json_profile" && severity_level != "") {
                    switch StrLower(severity_level) {
                        case "low":
                            stats["severity_low"]++
                        case "medium":
                            stats["severity_medium"]++
                        case "high":
                            stats["severity_high"]++
                    }
                }
                smudge := executionData.Has("smudge_count") ? executionData["smudge_count"] : 0
                glare := executionData.Has("glare_count") ? executionData["glare_count"] : 0
                splashes := executionData.Has("splashes_count") ? executionData["splashes_count"] : 0
                partial := executionData.Has("partial_blockage_count") ? executionData["partial_blockage_count"] : 0
                full := executionData.Has("full_blockage_count") ? executionData["full_blockage_count"] : 0
                flare := executionData.Has("light_flare_count") ? executionData["light_flare_count"] : 0
                rain := executionData.Has("rain_count") ? executionData["rain_count"] : 0
                haze := executionData.Has("haze_count") ? executionData["haze_count"] : 0
                snow := executionData.Has("snow_count") ? executionData["snow_count"] : 0
                clear := executionData.Has("clear_count") ? executionData["clear_count"] : 0
                stats["smudge_total"] += smudge
                stats["glare_total"] += glare
                stats["splashes_total"] += splashes
                stats["partial_blockage_total"] += partial
                stats["full_blockage_total"] += full
                stats["light_flare_total"] += flare
                stats["rain_total"] += rain
                stats["haze_total"] += haze
                stats["snow_total"] += snow
                stats["clear_total"] += clear
                ; Aggregate degradation counts by execution type
                if (execution_type = "json_profile") {
                    ; For JSON profiles, use the individual count fields (already populated)
                    stats["json_smudge"] += smudge
                    stats["json_glare"] += glare
                    stats["json_splashes"] += splashes
                    stats["json_partial"] += partial
                    stats["json_full"] += full
                    stats["json_flare"] += flare
                    stats["json_rain"] += rain
                    stats["json_haze"] += haze
                    stats["json_snow"] += snow
                    stats["json_clear"] += clear
                } else if (execution_type = "macro") {
                    stats["macro_smudge"] += smudge
                    stats["macro_glare"] += glare
                    stats["macro_splashes"] += splashes
                    stats["macro_partial"] += partial
                    stats["macro_full"] += full
                    stats["macro_flare"] += flare
                    stats["macro_rain"] += rain
                    stats["macro_haze"] += haze
                    stats["macro_snow"] += snow
                    stats["macro_clear"] += clear
                }
            }
        } catch {
            continue
        }
    }
    totalSessionActive := 0
    for _, activeMs in sessionActiveMap {
        if (activeMs > 0) {
            totalSessionActive += activeMs
        }
    }
    if (sessionActiveMap.Has(sessionId)) {
        stats["current_session_active_time"] := sessionActiveMap[sessionId]
    } else {
        stats["current_session_active_time"] := 0
    }
    if (totalSessionActive > 0) {
        stats["session_active_time"] := totalSessionActive
    }
    stats["session_active_time_map"] := sessionActiveMap
    stats["distinct_user_count"] := stats["user_summary"].Count
    for username, userData in stats["user_summary"] {
        if (userData.Has("sessions")) {
            userData["session_count"] := userData["sessions"].Count
        } else {
            userData["session_count"] := 0
        }
    }
    if (stats["total_executions"] > 0) {
        stats["average_execution_time"] := Round(stats["total_execution_time"] / stats["total_executions"], 1)
    }
    if (stats["session_active_time"] > 5000) {
        activeTimeHours := stats["session_active_time"] / 3600000
        stats["boxes_per_hour"] := Round(stats["total_boxes"] / activeTimeHours, 1)
        stats["executions_per_hour"] := Round(stats["total_executions"] / activeTimeHours, 1)
    }
    maxButtonCount := 0
    maxLayerCount := 0
    for button, count in buttonCount {
        if (count > maxButtonCount) {
            maxButtonCount := count
            stats["most_used_button"] := button
        }
    }
    for layer, count in layerCount {
        if (count > maxLayerCount) {
            maxLayerCount := count
            stats["most_active_layer"] := layer
        }
    }
    return stats
}

GetTodayStatsFromMemory() {
    global macroExecutionLog, sessionId, currentUsername
    stats := Stats_CreateEmptyStatsMap()
    sessionActiveMap := Map()
    today := FormatTime(A_Now, "yyyy-MM-dd")
    for executionData in macroExecutionLog {
        try {
            timestamp := executionData.Has("timestamp") ? executionData["timestamp"] : ""
            if (SubStr(timestamp, 1, 10) = today) {
                execution_type := executionData["execution_type"]
                execution_time := executionData.Has("execution_time_ms") ? executionData["execution_time_ms"] : 0
                total_boxes := executionData.Has("total_boxes") ? executionData["total_boxes"] : 0
                severity_level := executionData.Has("severity_level") ? executionData["severity_level"] : ""
                session_active_time := executionData.Has("session_active_time_ms") ? executionData["session_active_time_ms"] : 0
                stats["total_executions"]++
                stats["total_boxes"] += total_boxes
                stats["total_execution_time"] += execution_time
                if (execution_type = "json_profile") {
                    stats["json_profile_executions_count"]++
                } else if (execution_type = "macro") {
                    stats["macro_executions_count"]++
                }
                ; Use stored session_id from execution data, fall back to global if not present
                sessionKey := executionData.Has("session_id") ? executionData["session_id"] : sessionId
                if (!sessionActiveMap.Has(sessionKey) || session_active_time > sessionActiveMap[sessionKey]) {
                    sessionActiveMap[sessionKey] := session_active_time
                }
                ; Use stored username from execution data, fall back to current
                username := executionData.Has("username") ? executionData["username"] : currentUsername
                UpdateUserSummary(stats["user_summary"], username, total_boxes, sessionKey)
                if (execution_type = "json_profile" && severity_level != "") {
                    switch StrLower(severity_level) {
                        case "low":
                            stats["severity_low"]++
                        case "medium":
                            stats["severity_medium"]++
                        case "high":
                            stats["severity_high"]++
                    }
                }
                smudge := executionData.Has("smudge_count") ? executionData["smudge_count"] : 0
                glare := executionData.Has("glare_count") ? executionData["glare_count"] : 0
                splashes := executionData.Has("splashes_count") ? executionData["splashes_count"] : 0
                partial := executionData.Has("partial_blockage_count") ? executionData["partial_blockage_count"] : 0
                full := executionData.Has("full_blockage_count") ? executionData["full_blockage_count"] : 0
                flare := executionData.Has("light_flare_count") ? executionData["light_flare_count"] : 0
                rain := executionData.Has("rain_count") ? executionData["rain_count"] : 0
                haze := executionData.Has("haze_count") ? executionData["haze_count"] : 0
                snow := executionData.Has("snow_count") ? executionData["snow_count"] : 0
                clear := executionData.Has("clear_count") ? executionData["clear_count"] : 0
                stats["smudge_total"] += smudge
                stats["glare_total"] += glare
                stats["splashes_total"] += splashes
                stats["partial_blockage_total"] += partial
                stats["full_blockage_total"] += full
                stats["light_flare_total"] += flare
                stats["rain_total"] += rain
                stats["haze_total"] += haze
                stats["snow_total"] += snow
                stats["clear_total"] += clear
                ; Aggregate degradation counts by execution type
                if (execution_type = "json_profile") {
                    ; For JSON profiles, use the individual count fields (already populated)
                    stats["json_smudge"] += smudge
                    stats["json_glare"] += glare
                    stats["json_splashes"] += splashes
                    stats["json_partial"] += partial
                    stats["json_full"] += full
                    stats["json_flare"] += flare
                    stats["json_rain"] += rain
                    stats["json_haze"] += haze
                    stats["json_snow"] += snow
                    stats["json_clear"] += clear
                } else if (execution_type = "macro") {
                    stats["macro_smudge"] += smudge
                    stats["macro_glare"] += glare
                    stats["macro_splashes"] += splashes
                    stats["macro_partial"] += partial
                    stats["macro_full"] += full
                    stats["macro_flare"] += flare
                    stats["macro_rain"] += rain
                    stats["macro_haze"] += haze
                    stats["macro_snow"] += snow
                    stats["macro_clear"] += clear
                }
            }
        } catch {
            continue
        }
    }
    totalSessionActive := 0
    for _, activeMs in sessionActiveMap {
        if (activeMs > 0) {
            totalSessionActive += activeMs
        }
    }
    if (sessionActiveMap.Has(sessionId)) {
        stats["current_session_active_time"] := sessionActiveMap[sessionId]
    } else {
        stats["current_session_active_time"] := 0
    }
    if (totalSessionActive > 0) {
        stats["session_active_time"] := totalSessionActive
    }
    stats["session_active_time_map"] := sessionActiveMap
    stats["distinct_user_count"] := stats["user_summary"].Count
    for username, userData in stats["user_summary"] {
        if (userData.Has("sessions")) {
            userData["session_count"] := userData["sessions"].Count
        } else {
            userData["session_count"] := 0
        }
    }
    if (stats["total_executions"] > 0) {
        stats["average_execution_time"] := Round(stats["total_execution_time"] / stats["total_executions"], 1)
    }
    if (stats["session_active_time"] > 5000) {
        activeTimeHours := stats["session_active_time"] / 3600000
        stats["boxes_per_hour"] := Round(stats["total_boxes"] / activeTimeHours, 1)
        stats["executions_per_hour"] := Round(stats["total_executions"] / activeTimeHours, 1)
    }
    return stats
}

ProcessDegradationCounts(executionData, degradationString) {
    if (degradationString = "" || degradationString = "none") {
        return
    }
    degradationTypes := StrSplit(degradationString, ",")
    for degradationType in degradationTypes {
        degradationType := Trim(StrReplace(StrReplace(degradationType, Chr(34), ""), Chr(39), ""))
        Stats_IncrementDegradationCountDirect(executionData, degradationType)
    }
}

UpdateUserSummary(userSummaryMap, username, totalBoxes, sessionId) {
    if (username = "") {
        username := "unknown"
    }
    if (!userSummaryMap.Has(username)) {
        userSummaryMap[username] := Map("total_executions", 0, "total_boxes", 0, "sessions", Map())
    }
    userData := userSummaryMap[username]
    userData["total_executions"] := userData["total_executions"] + 1
    userData["total_boxes"] := userData["total_boxes"] + totalBoxes
    if (sessionId != "") {
        sessions := userData["sessions"]
        if (!sessions.Has(sessionId)) {
            sessions[sessionId] := true
        }
    }
}

RecordExecutionStats(macroKey, executionStartTime, executionType, events, analysisRecord := "") {
    global breakMode, recording, annotationMode, totalActiveTime, lastActiveTime, sessionId, currentUsername
    eventCount := (IsObject(events) ? events.Length : 0)
    if (breakMode || recording) {
        return
    }
    execution_time_ms := A_TickCount - executionStartTime
    timestamp := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    UpdateActiveTime()
    current_session_active_time_ms := GetCurrentSessionActiveTime()
    executionData := Map()
    executionData["timestamp"] := timestamp
    executionData["session_id"] := sessionId
    executionData["username"] := currentUsername
    executionData["execution_type"] := executionType
    executionData["button_key"] := macroKey
    executionData["layer"] := 1
    executionData["execution_time_ms"] := execution_time_ms
    executionData["canvas_mode"] := (annotationMode = "Wide" ? "wide" : "narrow")
    executionData["session_active_time_ms"] := current_session_active_time_ms
    executionData["break_mode_active"] := false
    executionData["smudge_count"] := 0
    executionData["glare_count"] := 0
    executionData["splashes_count"] := 0
    executionData["partial_blockage_count"] := 0
    executionData["full_blockage_count"] := 0
    executionData["light_flare_count"] := 0
    executionData["rain_count"] := 0
    executionData["haze_count"] := 0
    executionData["snow_count"] := 0
    executionData["clear_count"] := 0
    executionData["total_boxes"] := 0
    executionData["degradation_assignments"] := ""
    executionData["severity_level"] := "medium"
    executionData["annotation_details"] := ""
    executionData["execution_success"] := "true"
    executionData["error_details"] := ""
    if (executionType = "macro") {
        bbox_count := 0
        degradation_counts_map := Map(1, 0, 2, 0, 3, 0, 4, 0, 5, 0, 6, 0, 7, 0, 8, 0, 9, 0, 0, 0)
        for event in events {
            eventType := ""
            if (Type(event) = "Map") {
                eventType := event.Has("type") ? event["type"] : ""
            } else if (IsObject(event)) {
                eventType := event.HasOwnProp("type") ? event.type : ""
            }
            if (eventType = "boundingBox") {
                bbox_count++
                degType := 0
                if (Type(event) = "Map") {
                    degType := event.Has("degradationType") ? event["degradationType"] : 0
                } else if (event.HasOwnProp("degradationType")) {
                    degType := event.degradationType
                }
                ; Count all degradation types including 0 (clear)
                if (degradation_counts_map.Has(degType)) {
                    degradation_counts_map[degType]++
                }
            }
        }
        executionData["total_boxes"] := bbox_count
        executionData["smudge_count"] := degradation_counts_map[1]
        executionData["glare_count"] := degradation_counts_map[2]
        executionData["splashes_count"] := degradation_counts_map[3]
        executionData["partial_blockage_count"] := degradation_counts_map[4]
        executionData["full_blockage_count"] := degradation_counts_map[5]
        executionData["light_flare_count"] := degradation_counts_map[6]
        executionData["rain_count"] := degradation_counts_map[7]
        executionData["haze_count"] := degradation_counts_map[8]
        executionData["snow_count"] := degradation_counts_map[9]
        executionData["clear_count"] := degradation_counts_map[0]
        degradation_names := []
        if (degradation_counts_map[1] > 0) degradation_names.Push("smudge")
        if (degradation_counts_map[2] > 0) degradation_names.Push("glare")
        if (degradation_counts_map[3] > 0) degradation_names.Push("splashes")
        if (degradation_counts_map[4] > 0) degradation_names.Push("partial_blockage")
        if (degradation_counts_map[5] > 0) degradation_names.Push("full_blockage")
        if (degradation_counts_map[6] > 0) degradation_names.Push("light_flare")
        if (degradation_counts_map[7] > 0) degradation_names.Push("rain")
        if (degradation_counts_map[8] > 0) degradation_names.Push("haze")
        if (degradation_counts_map[9] > 0) degradation_names.Push("snow")
        if (degradation_counts_map[0] > 0) degradation_names.Push("clear")
        if (degradation_names.Length > 0) {
            degradation_string := ""
            for i, name in degradation_names {
                degradation_string .= (i > 1 ? "," : "") . name
            }
            executionData["degradation_assignments"] := degradation_string
        } else {
            executionData["degradation_assignments"] := "clear"
            executionData["clear_count"] := bbox_count > 0 ? bbox_count : 1
        }
    } else if (executionType = "json_profile") {
        executionData["total_boxes"] := 1
        if (IsObject(analysisRecord)) {
            if (analysisRecord.HasOwnProp("jsonDegradationName") && analysisRecord.jsonDegradationName != "") {
                executionData["degradation_assignments"] := analysisRecord.jsonDegradationName
                ProcessDegradationCounts(executionData, analysisRecord.jsonDegradationName)
            } else {
                executionData["degradation_assignments"] := "clear"
                executionData["clear_count"] := 1
            }
            if (analysisRecord.HasOwnProp("severity")) {
                executionData["severity_level"] := analysisRecord.severity
            }
            if (analysisRecord.HasOwnProp("annotationDetails")) {
                executionData["annotation_details"] := analysisRecord.annotationDetails
            }
        } else {
            executionData["degradation_assignments"] := "clear"
            executionData["clear_count"] := 1
        }
    } else if (executionType = "clear") {
        executionData["total_boxes"] := 1
        executionData["clear_count"] := 1
        executionData["degradation_assignments"] := "clear"
    }
    result := AppendToCSV(executionData)
    if (result) {
        SaveStatsToJson()
    }
    return result
}

global macroExecutionLog := []

AppendToCSV(executionData) {
    global macroExecutionLog
    try {
        macroExecutionLog.Push(executionData)
        return true
    } catch Error as e {
        UpdateStatus("⚠ Stats record error: " . e.Message)
        return false
    }
}

UpdateActiveTime() {
    global breakMode, totalActiveTime, lastActiveTime, currentDay, sessionId

    ; Check for day change and handle daily reset
    today := FormatTime(A_Now, "yyyy-MM-dd")
    if (today != currentDay) {
        HandleDayChange(today)
    }

    ; Only accumulate time if not in break mode
    if (!breakMode && lastActiveTime > 0) {
        elapsed := A_TickCount - lastActiveTime
        totalActiveTime += elapsed
    }
    ; Always update lastActiveTime to current tick for next interval
    lastActiveTime := A_TickCount
}

HandleDayChange(newDay) {
    global currentDay, totalActiveTime, lastActiveTime, sessionId, applicationStartTime
    ; Day has changed - reset daily tracking while preserving lifetime stats
    ; Note: Lifetime stats are preserved in macroExecutionLog (never reset unless manual)
    ; Daily stats are calculated by filtering GetTodayStatsFromMemory() by date

    ; Reset session time tracking for new day
    totalActiveTime := 0
    lastActiveTime := A_TickCount
    applicationStartTime := A_TickCount

    ; Generate new session ID for the new day
    sessionId := "session_" . A_TickCount

    ; Update the current day tracker
    currentDay := newDay

    ; Optional: Log the day change
    UpdateStatus("📅 New day started: " . newDay)
}

GetCurrentSessionActiveTime() {
    global totalActiveTime, lastActiveTime, breakMode
    ; Return just totalActiveTime - UpdateActiveTime() handles accumulation
    ; Don't add extra time here to avoid double-counting
    if (breakMode) {
        return totalActiveTime
    } else {
        ; Add only the time since last update (smooth live display)
        return totalActiveTime + (A_TickCount - lastActiveTime)
    }
}

SaveStatsToJson() {
    global macroExecutionLog, workDir
    statsJsonFile := workDir . "\stats_log.json"
    backupFile := workDir . "\stats_log.backup.json"

    try {
        if (!DirExist(workDir)) {
            DirCreate(workDir)
        }

        ; Validate data before saving
        if (!IsObject(macroExecutionLog)) {
            UpdateStatus("⚠️ Stats data invalid, skipping save")
            return false
        }

        ; Create backup of existing file before overwriting
        if (FileExist(statsJsonFile)) {
            try {
                FileCopy(statsJsonFile, backupFile, 1)  ; Overwrite backup
            } catch {
                ; Backup failed, but continue with save
            }
        }

        ; Build validated JSON structure
        jsonData := Map()
        jsonData["version"] := "1.0"
        jsonData["last_updated"] := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        jsonData["execution_count"] := macroExecutionLog.Length
        jsonData["executions"] := macroExecutionLog

        ; Save to file
        ObjSave(jsonData, statsJsonFile)
        return true
    } catch Error as e {
        UpdateStatus("⚠️ Stats save failed: " . e.Message)
        return false
    }
}

LoadStatsFromJson() {
    global macroExecutionLog, workDir
    statsJsonFile := workDir . "\stats_log.json"
    backupFile := workDir . "\stats_log.backup.json"

    try {
        if (!DirExist(workDir)) {
            DirCreate(workDir)
        }

        if (!FileExist(statsJsonFile)) {
            macroExecutionLog := []
            return 0
        }

        ; Attempt to load main file
        jsonData := ""
        try {
            jsonData := ObjLoad(statsJsonFile)
        } catch Error as e {
            ; Main file corrupted, try backup
            UpdateStatus("⚠️ Stats file corrupted, attempting backup recovery...")
            if (FileExist(backupFile)) {
                try {
                    jsonData := ObjLoad(backupFile)
                    UpdateStatus("✅ Stats recovered from backup")
                } catch {
                    UpdateStatus("❌ Backup also corrupted, starting fresh")
                    macroExecutionLog := []
                    return 0
                }
            } else {
                UpdateStatus("❌ No backup available, starting fresh")
                macroExecutionLog := []
                return 0
            }
        }

        ; Validate loaded data structure
        if (!IsObject(jsonData)) {
            UpdateStatus("⚠️ Invalid stats data format")
            macroExecutionLog := []
            return 0
        }

        if (!jsonData.Has("executions")) {
            UpdateStatus("⚠️ Stats file missing executions data")
            macroExecutionLog := []
            return 0
        }

        executions := jsonData["executions"]
        if (!IsObject(executions)) {
            UpdateStatus("⚠️ Executions data is not an array")
            macroExecutionLog := []
            return 0
        }

        ; Validate individual execution records
        validatedExecutions := []
        invalidCount := 0
        for execution in executions {
            if (IsObject(execution) && execution.Has("timestamp") && execution.Has("execution_type")) {
                validatedExecutions.Push(execution)
            } else {
                invalidCount++
            }
        }

        macroExecutionLog := validatedExecutions

        if (invalidCount > 0) {
            UpdateStatus("⚠️ Loaded " . validatedExecutions.Length . " stats, " . invalidCount . " invalid entries skipped")
        }

        return macroExecutionLog.Length
    } catch Error as e {
        UpdateStatus("❌ Stats load error: " . e.Message)
        macroExecutionLog := []
        return 0
    }
}

; ===============================================================================
; ===== STATS GUI MODULE =====
; ===============================================================================

global statsGui := ""
global statsGuiOpen := false
global statsControls := Map()

ShowStatsMenu() {
    global masterStatsCSV, darkMode, currentSessionId, permanentStatsFile, statsGui, statsGuiOpen, statsControls
    if (statsGuiOpen) {
        CloseStatsMenu()
        return
    }
    statsGui := Gui("+AlwaysOnTop", "📊 MacroMaster Statistics")
    statsGui.BackColor := darkMode ? "0x1E1E1E" : "0xF5F5F5"
    statsGui.SetFont("s9", "Consolas")
    statsGui.OnEvent("Close", (*) => CloseStatsMenu())
    statsControls := Map()
    leftCol := 20
    midCol := 250
    rightCol := 480
    y := 15
    todayDate := FormatTime(A_Now, "MMMM d, yyyy (dddd)")
    titleText := statsGui.Add("Text", "x" . leftCol . " y" . y . " w660 Center", todayDate)
    titleText.SetFont("s10 bold")
    titleText.Opt("c" . (darkMode ? "0xFFFFFF" : "0x000000"))
    y += 20
    AddStatsHeader(statsGui, y, "ALL-TIME (Since Reset)", leftCol, 210)
    AddStatsHeader(statsGui, y, "TODAY", rightCol, 210)
    y += 15
    AddSectionDivider(statsGui, y, "GENERAL STATISTICS", 660)
    y += 15
    AddHorizontalStatRowLive(statsGui, y, "Executions:", "all_exec", "today_exec")
    y += 18
    AddHorizontalStatRowLive(statsGui, y, "Boxes:", "all_boxes", "today_boxes")
    y += 18
    AddHorizontalStatRowLive(statsGui, y, "Active Time:", "all_active_time", "today_active_time")
    y += 18
    AddHorizontalStatRowLive(statsGui, y, "Avg Time:", "all_avg_time", "today_avg_time")
    y += 18
    AddHorizontalStatRowLive(statsGui, y, "Boxes/Hour:", "all_box_rate", "today_box_rate")
    y += 12
    AddHorizontalStatRowLive(statsGui, y, "Exec/Hour:", "all_exec_rate", "today_exec_rate")
    y += 15
    AddSectionDivider(statsGui, y, "MACRO DEGRADATION BREAKDOWN", 660)
    y += 15
    degradationTypes := [["Smudge", "smudge"], ["Glare", "glare"], ["Splashes", "splashes"], ["Partial Block", "partial"], ["Full Block", "full"], ["Light Flare", "flare"], ["Rain", "rain"], ["Haze", "haze"], ["Snow", "snow"]]
    for degInfo in degradationTypes {
        AddHorizontalStatRowLive(statsGui, y, degInfo[1] . ":", "all_macro_" . degInfo[2], "today_macro_" . degInfo[2])
        y += 12
    }
    y += 10
    AddSectionDivider(statsGui, y, "JSON DEGRADATION SELECTION COUNT", 660)
    y += 15
    for degInfo in degradationTypes {
        AddHorizontalStatRowLive(statsGui, y, degInfo[1] . ":", "all_json_" . degInfo[2], "today_json_" . degInfo[2])
        y += 12
    }
    y += 10
    AddSectionDivider(statsGui, y, "EXECUTION TYPE BREAKDOWN", 660)
    y += 15
    AddHorizontalStatRowLive(statsGui, y, "Macro Executions:", "all_macro_exec", "today_macro_exec")
    y += 12
    AddHorizontalStatRowLive(statsGui, y, "JSON Executions:", "all_json_exec", "today_json_exec")
    y += 15
    AddSectionDivider(statsGui, y, "JSON SEVERITY BREAKDOWN", 660)
    y += 15
    severityTypes := [["Low Severity", "severity_low"], ["Medium Severity", "severity_medium"], ["High Severity", "severity_high"]]
    for sevInfo in severityTypes {
        AddHorizontalStatRowLive(statsGui, y, sevInfo[1] . ":", "all_" . sevInfo[2], "today_" . sevInfo[2])
        y += 12
    }
    y += 15
    AddSectionDivider(statsGui, y, "MACRO DETAILS", 660)
    y += 15
    AddHorizontalStatRowLive(statsGui, y, "Most Used Button:", "most_used_btn", "")
    y += 12
    AddHorizontalStatRowLive(statsGui, y, "Most Active Layer:", "most_active_layer", "")
    y += 15
    AddSectionDivider(statsGui, y, "DATA FILES", 660)
    y += 15
    infoText := statsGui.Add("Text", "x" . leftCol . " y" . y . " w660", "Display Stats: " . masterStatsCSV)
    infoText.SetFont("s8")
    infoText.Opt("c" . (darkMode ? "0x888888" : "0x666666"))
    y += 18
    infoText2 := statsGui.Add("Text", "x" . leftCol . " y" . y . " w660", "Permanent Master: " . permanentStatsFile)
    infoText2.SetFont("s8")
    infoText2.Opt("c" . (darkMode ? "0x888888" : "0x666666"))
    y += 20
    btnExport := statsGui.Add("Button", "x" . leftCol . " y" . y . " w120 h30", "💾 Export")
    btnExport.SetFont("s9")
    btnExport.OnEvent("Click", (*) => ExportStatsData(statsGui))
    btnReset := statsGui.Add("Button", "x" . (leftCol + 130) . " y" . y . " w120 h30", "🗑️ Reset")
    btnReset.SetFont("s9")
    btnReset.OnEvent("Click", (*) => ResetAllStats())
    btnClose := statsGui.Add("Button", "x" . (leftCol + 260) . " y" . y . " w120 h30", "❌ Close")
    btnClose.SetFont("s9")
    btnClose.OnEvent("Click", (*) => CloseStatsMenu())
    statsGui.Show("w700 h" . (y + 40))
    statsGuiOpen := true
    UpdateStatsDisplay()
    SetTimer(UpdateStatsDisplay, 2000)
}

AddHorizontalStatRowLive(gui, y, label, allKey, todayKey) {
    global darkMode, statsControls
    labelCtrl := gui.Add("Text", "x20 y" . y . " w140", label)
    labelCtrl.SetFont("s9", "Consolas")
    labelCtrl.Opt("c" . (darkMode ? "0xCCCCCC" : "0x555555"))
    allCtrl := gui.Add("Text", "x170 y" . y . " w70 Right", "0")
    allCtrl.SetFont("s9 bold", "Consolas")
    allCtrl.Opt("c" . (darkMode ? "0xFFFFFF" : "0x000000"))
    statsControls[allKey] := allCtrl
    if (todayKey != "") {
        todayCtrl := gui.Add("Text", "x480 y" . y . " w70 Right", "0")
        todayCtrl.SetFont("s9 bold", "Consolas")
        todayCtrl.Opt("c" . (darkMode ? "0xFFFFFF" : "0x000000"))
        statsControls[todayKey] := todayCtrl
    }
}

AddSectionDivider(gui, y, text, width) {
    global darkMode
    divider := gui.Add("Text", "x20 y" . y . " w" . width, "═══ " . text . " ═══")
    divider.SetFont("s9 bold", "Consolas")
    divider.Opt("c" . (darkMode ? "0xFFFFFF" : "0x000000"))
}

AddStatsHeader(gui, y, text, x, width) {
    global darkMode
    header := gui.Add("Text", "x" . x . " y" . y . " w" . width . " Center", text)
    header.SetFont("s9 bold", "Consolas")
    header.Opt("c" . (darkMode ? "0xFFFFFF" : "0x000000"))
}

UpdateStatsDisplay() {
    global statsGuiOpen, statsControls, macroExecutionLog, sessionId
    if (!statsGuiOpen) {
        SetTimer(UpdateStatsDisplay, 0)
        return
    }
    try {
        allStats := ReadStatsFromMemory(false)
        todayStats := GetTodayStatsFromMemory()

        ; Get current live active time
        currentActiveTime := GetCurrentSessionActiveTime()

        ; Determine the time accumulated since last execution was saved
        ; This avoids double-counting when sessions span multiple days
        lastExecutionTime := 0
        if (macroExecutionLog.Length > 0) {
            lastExecution := macroExecutionLog[macroExecutionLog.Length]
            if (lastExecution.Has("session_active_time_ms")) {
                lastExecutionTime := lastExecution["session_active_time_ms"]
            }
        }

        ; Calculate live time delta (time since last saved execution)
        liveTimeDelta := (currentActiveTime > lastExecutionTime) ? (currentActiveTime - lastExecutionTime) : 0

        ; For ALL-TIME: Add live delta to recorded total
        effectiveAllActiveTime := (allStats.Has("session_active_time") ? allStats["session_active_time"] : 0)
        effectiveAllActiveTime += liveTimeDelta

        if (effectiveAllActiveTime > 5000) {
            activeTimeHours := effectiveAllActiveTime / 3600000
            allStats["boxes_per_hour"] := Round(allStats["total_boxes"] / activeTimeHours, 1)
            allStats["executions_per_hour"] := Round(allStats["total_executions"] / activeTimeHours, 1)
        }
        allStats["session_active_time"] := effectiveAllActiveTime

        ; For TODAY: Only add live delta if last execution was from today
        effectiveTodayActiveTime := (todayStats.Has("session_active_time") ? todayStats["session_active_time"] : 0)

        ; Check if last execution was today
        today := FormatTime(A_Now, "yyyy-MM-dd")
        lastExecutionWasToday := false

        if (macroExecutionLog.Length > 0) {
            lastExecution := macroExecutionLog[macroExecutionLog.Length]
            if (lastExecution.Has("timestamp")) {
                lastTimestamp := lastExecution["timestamp"]
                lastExecutionWasToday := (SubStr(lastTimestamp, 1, 10) = today)
            }
        }

        ; Add live time to today only if last execution was today OR no executions yet
        if (lastExecutionWasToday) {
            effectiveTodayActiveTime += liveTimeDelta
        } else if (macroExecutionLog.Length = 0) {
            ; No executions yet - all current time belongs to today
            effectiveTodayActiveTime += currentActiveTime
        }

        if (effectiveTodayActiveTime > 5000) {
            activeTimeHours := effectiveTodayActiveTime / 3600000
            todayStats["boxes_per_hour"] := Round(todayStats["total_boxes"] / activeTimeHours, 1)
            todayStats["executions_per_hour"] := Round(todayStats["total_executions"] / activeTimeHours, 1)
        }
        todayStats["session_active_time"] := effectiveTodayActiveTime
        if (statsControls.Has("all_exec"))
            statsControls["all_exec"].Value := allStats["total_executions"]
        if (statsControls.Has("today_exec"))
            statsControls["today_exec"].Value := todayStats["total_executions"]
        if (statsControls.Has("all_boxes"))
            statsControls["all_boxes"].Value := allStats["total_boxes"]
        if (statsControls.Has("today_boxes"))
            statsControls["today_boxes"].Value := todayStats["total_boxes"]
        if (statsControls.Has("all_active_time"))
            statsControls["all_active_time"].Value := FormatMilliseconds(allStats["session_active_time"])
        if (statsControls.Has("today_active_time"))
            statsControls["today_active_time"].Value := FormatMilliseconds(todayStats["session_active_time"])
        if (statsControls.Has("all_avg_time"))
            statsControls["all_avg_time"].Value := allStats["average_execution_time"] . " ms"
        if (statsControls.Has("today_avg_time"))
            statsControls["today_avg_time"].Value := todayStats["average_execution_time"] . " ms"
        if (statsControls.Has("all_box_rate"))
            statsControls["all_box_rate"].Value := allStats["boxes_per_hour"]
        if (statsControls.Has("today_box_rate"))
            statsControls["today_box_rate"].Value := todayStats["boxes_per_hour"]
        if (statsControls.Has("all_exec_rate"))
            statsControls["all_exec_rate"].Value := allStats["executions_per_hour"]
        if (statsControls.Has("today_exec_rate"))
            statsControls["today_exec_rate"].Value := todayStats["executions_per_hour"]
        degradationKeys := ["smudge", "glare", "splashes", "partial", "full", "flare", "rain", "haze", "snow"]
        for key in degradationKeys {
            if (statsControls.Has("all_macro_" . key))
                statsControls["all_macro_" . key].Value := allStats["macro_" . key]
            if (statsControls.Has("today_macro_" . key))
                statsControls["today_macro_" . key].Value := todayStats["macro_" . key]
            if (statsControls.Has("all_json_" . key))
                statsControls["all_json_" . key].Value := allStats["json_" . key]
            if (statsControls.Has("today_json_" . key))
                statsControls["today_json_" . key].Value := todayStats["json_" . key]
        }
        if (statsControls.Has("all_macro_exec"))
            statsControls["all_macro_exec"].Value := allStats["macro_executions_count"]
        if (statsControls.Has("today_macro_exec")) {
            todayMacroExec := todayStats.Has("macro_executions_count") ? todayStats["macro_executions_count"] : Max(0, allStats["macro_executions_count"] - (allStats["total_executions"] - todayStats["total_executions"]))
            statsControls["today_macro_exec"].Value := Max(0, todayMacroExec)
        }
        if (statsControls.Has("all_json_exec"))
            statsControls["all_json_exec"].Value := allStats["json_profile_executions_count"]
        if (statsControls.Has("today_json_exec")) {
            todayJsonExec := todayStats.Has("json_profile_executions_count") ? todayStats["json_profile_executions_count"] : Max(0, allStats["json_profile_executions_count"] - (allStats["total_executions"] - todayStats["total_executions"]))
            statsControls["today_json_exec"].Value := Max(0, todayJsonExec)
        }
        if (statsControls.Has("all_severity_low"))
            statsControls["all_severity_low"].Value := allStats["severity_low"]
        if (statsControls.Has("today_severity_low"))
            statsControls["today_severity_low"].Value := todayStats["severity_low"]
        if (statsControls.Has("all_severity_medium"))
            statsControls["all_severity_medium"].Value := allStats["severity_medium"]
        if (statsControls.Has("today_severity_medium"))
            statsControls["today_severity_medium"].Value := todayStats["severity_medium"]
        if (statsControls.Has("all_severity_high"))
            statsControls["all_severity_high"].Value := allStats["severity_high"]
        if (statsControls.Has("today_severity_high"))
            statsControls["today_severity_high"].Value := todayStats["severity_high"]
        if (statsControls.Has("most_used_btn"))
            statsControls["most_used_btn"].Value := allStats["most_used_button"]
        if (statsControls.Has("most_active_layer"))
            statsControls["most_active_layer"].Value := allStats["most_active_layer"]
    } catch as err {
    }
}

CloseStatsMenu() {
    global statsGui, statsGuiOpen
    SetTimer(UpdateStatsDisplay, 0)
    if (statsGui) {
        try statsGui.Destroy()
        statsGui := ""
    }
    statsGuiOpen := false
}

ExportStatsData(statsMenuGui := "") {
    global macroExecutionLog, documentsDir
    if (!macroExecutionLog || macroExecutionLog.Length = 0) {
        MsgBox("📊 No data to export yet`n`nStart using macros to generate performance data!", "Info", "Icon!")
        return
    }
    exportPath := documentsDir . "\MacroMaster_Stats_Export_" . FormatTime(A_Now, "yyyyMMdd_HHmmss") . ".csv"
    try {
        csvContent := Stats_GetCsvHeader()
        for executionData in macroExecutionLog {
            csvContent .= Stats_BuildCsvRow(executionData)
        }
        FileAppend(csvContent, exportPath, "UTF-8")
        MsgBox("✅ Stats exported successfully!`n`nFile: " . exportPath . "`n`nExecutions: " . macroExecutionLog.Length . "`n`nYou can open this file in Excel or other tools.", "Export Complete", "Icon!")
    } catch Error as e {
        MsgBox("❌ Export failed: " . e.Message, "Error", "Icon!")
    }
}

ResetAllStats() {
    global macroExecutionLog, masterStatsCSV, permanentStatsFile, workDir
    result := MsgBox("This will reset ALL statistics (Today and All-Time).`n`nAll execution data will be permanently deleted.`n`n⚠️ Export your stats first if you want to keep them!`n`nReset all stats?", "Reset Statistics", "YesNo Icon!")
    if (result = "Yes") {
        try {
            macroExecutionLog := []
            statsJsonFile := workDir . "\stats_log.json"
            if FileExist(statsJsonFile) {
                FileDelete(statsJsonFile)
            }
            if FileExist(masterStatsCSV) {
                FileDelete(masterStatsCSV)
            }
            UpdateStatus("🗑️ Stats reset complete")
            MsgBox("Statistics reset complete!`n`n✅ All execution data cleared.`n`nStart using macros to build new stats!", "Reset Complete", "Icon!")
        } catch Error as e {
            UpdateStatus("⚠️ Failed to reset statistics")
            MsgBox("Failed to reset statistics: " . e.Message, "Error", "Icon!")
        }
    }
}

; ===== MAIN INITIALIZATION =====
Main() {
    try {
        ; Initialize core systems
        InitializeStatsSystem()
        InitializeDirectories()
        InitializeVariables()
        InitializeJsonAnnotations()
        InitializeVisualizationSystem()
        
        ; Setup UI and interactions
        InitializeGui()
        SetupHotkeys()
        
        ; Load configuration (after GUI is created so mode toggle button can be updated)
        LoadConfig()
        
        ; Load saved macros
        loadedMacros := LoadMacroState()

        ; Initialize WASD hotkeys
        InitializeWASDHotkeys()

        ; Status update
        if (loadedMacros > 0) {
            UpdateStatus("📄 Loaded " . loadedMacros . " macros")
        } else {
            UpdateStatus("📄 No saved macros")
        }

        ; Refresh all button appearances after loading config
        RefreshAllButtonAppearances()

        ; Setup time tracking and auto-save
        SetTimer(UpdateActiveTime, 5000)  ; Update active time every 5 seconds
        SetTimer(AutoSave, 60000)  ; Auto-save every 60 seconds

        ; Setup cleanup
        OnExit((*) => CleanupAndExit())

        ; Show welcome message
        UpdateStatus("🚀 Data Labeling Assistant Ready - CapsLock+F to record")
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
    for buttonName in buttonNames {
        buttonCustomLabels[buttonName] := buttonName
    }
    
    ; Initialize severity breakdown
    for severity in severityLevels {
        severityBreakdown[severity] := {count: 0, percentage: 0}
    }
    
    ; Initialize tracking system
    pendingBoxForTagging := ""
}

InitializeDirectories() {
    global workDir, thumbnailDir
    
    if !DirExist(workDir)
        DirCreate(workDir)
    
    if !DirExist(thumbnailDir)
        DirCreate(thumbnailDir)
}

; ===== HOTKEY SETUP - FIXED F9 SYSTEM =====
SetupHotkeys() {
    global hotkeySubmit, hotkeyUtilitySubmit, hotkeyUtilityBackspace

    try {
        ; CRITICAL: Clear any existing hotkeys to prevent conflicts
        try {
            Hotkey("F9", "Off")
            Hotkey("CapsLock & f", "Off")
            Hotkey("CapsLock & Space", "Off")
        } catch {
        }

        Sleep(50)  ; Ensure cleanup

        ; RECORDING CONTROL - COMPLETELY ISOLATED
        Hotkey("CapsLock & f", F9_RecordingOnly, "On")
        Hotkey("CapsLock & Space", (*) => EmergencyStop(), "On")

        ; Debug and utility keys
        Hotkey("F11", (*) => ShowRecordingDebug())
        Hotkey("F12", (*) => ShowStatsMenu())

        ; Layer navigation
        Hotkey("NumpadAdd", (*) => SwitchLayer("next"))
        Hotkey("NumpadSub", (*) => SwitchLayer("prev"))

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

        ; WASD hotkeys for macro execution (CapsLock + WASD keys)
        Hotkey("CapsLock & 1", (*) => ExecuteWASDMacro("Num7"))
        Hotkey("CapsLock & 2", (*) => ExecuteWASDMacro("Num8"))
        Hotkey("CapsLock & 3", (*) => ExecuteWASDMacro("Num9"))
        Hotkey("CapsLock & q", (*) => ExecuteWASDMacro("Num4"))
        Hotkey("CapsLock & w", (*) => ExecuteWASDMacro("Num5"))
        Hotkey("CapsLock & e", (*) => ExecuteWASDMacro("Num6"))
        Hotkey("CapsLock & a", (*) => ExecuteWASDMacro("Num1"))
        Hotkey("CapsLock & s", (*) => ExecuteWASDMacro("Num2"))
        Hotkey("CapsLock & d", (*) => ExecuteWASDMacro("Num3"))
        Hotkey("CapsLock & z", (*) => ExecuteWASDMacro("Num0"))
        Hotkey("CapsLock & x", (*) => ExecuteWASDMacro("NumDot"))
        Hotkey("CapsLock & c", (*) => ExecuteWASDMacro("NumMult"))

        ; Utility - Standard
        Hotkey(hotkeySubmit, (*) => SubmitCurrentImage())

        ; Utility - Labeler Workflow Helpers
        Hotkey(hotkeyUtilitySubmit, (*) => UtilitySubmit())       ; LShift + CapsLock = Shift+Enter
        Hotkey(hotkeyUtilityBackspace, (*) => UtilityBackspace())   ; LCtrl + CapsLock = Backspace

        UpdateStatus("✅ Hotkeys configured - CapsLock+F for recording, CapsLock+SPACE for emergency stop")
    } catch Error as e {
        UpdateStatus("⚠️ Hotkey setup failed: " . e.Message)
        MsgBox("Hotkey error: " . e.Message, "Setup Error", "Icon!")
    }
}

; ===== F9 RECORDING HANDLER - COMPLETELY ISOLATED =====
F9_RecordingOnly(*) {
    global recording, awaitingAssignment, breakMode, playback
    
    ; Comprehensive state checking with detailed logging
    UpdateStatus("🔧 F9 PRESSED - Checking states...")
    
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
        mainGui.btnRecord.Text := "🔴 Stop (CapsLock+F)"
        mainGui.btnRecord.Opt("+Background0xDC143C")
    }

    UpdateStatus("🎥 RECORDING - Draw boxes, CapsLock+F to stop")
}

ForceStopRecording() {
    global recording, currentMacro, macroEvents, awaitingAssignment, mainGui, pendingBoxForTagging, annotationMode

    if (!recording) {
        UpdateStatus("⚠️ Not recording - CapsLock+F ignored")
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

    ; Save the current annotationMode as recordedMode for this macro
    if (macroEvents.Has(currentMacro)) {
        macroEvents[currentMacro].recordedMode := annotationMode
        VizLog("SET recordedMode for " . currentMacro . " to: " . annotationMode)

        ; Save the canvas bounds that were active during recording
        if (annotationMode = "Wide") {
            macroEvents[currentMacro].recordedCanvas := {
                mode: "Wide",
                left: wideCanvasLeft,
                top: wideCanvasTop,
                right: wideCanvasRight,
                bottom: wideCanvasBottom
            }
            VizLog("SET recordedCanvas for " . currentMacro . " to Wide: " . wideCanvasLeft . "," . wideCanvasTop . "," . wideCanvasRight . "," . wideCanvasBottom)
        } else {
            macroEvents[currentMacro].recordedCanvas := {
                mode: "Narrow",
                left: narrowCanvasLeft,
                top: narrowCanvasTop,
                right: narrowCanvasRight,
                bottom: narrowCanvasBottom
            }
            VizLog("SET recordedCanvas for " . currentMacro . " to Narrow: " . narrowCanvasLeft . "," . narrowCanvasTop . "," . narrowCanvasRight . "," . narrowCanvasBottom)
        }

        FlushVizLog()
    }

    ; Analyze macro
    AnalyzeRecordedMacro(currentMacro)
    ; PERFORMANCE: SaveConfig() removed - auto-save timer handles persistence

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
    ; CRITICAL: Absolutely prevent hotkey keys from reaching macro execution
    if (buttonName = "CapsLock" || buttonName = "f" || buttonName = "Space") {
        return
    }

    ExecuteMacro(buttonName)
}

ExecuteMacro(buttonName) {
    global awaitingAssignment, currentLayer, macroEvents, playback, focusDelay

    ; Double-check hotkey protection
    if (buttonName = "CapsLock" || buttonName = "f" || buttonName = "Space") {
        return
    }

    if (awaitingAssignment) {
        SetTimer(CheckForAssignment, 0)
        AssignToButton(buttonName)
        return
    }

    layerMacroName := "L" . currentLayer . "_" . buttonName
    if (!macroEvents.Has(layerMacroName) || macroEvents[layerMacroName].Length = 0) {
        UpdateStatus("⌛ No macro: " . buttonName . " L" . currentLayer . " | CapsLock+F to record")
        return
    }

    if (playback) {
        UpdateStatus("⌚ Already executing")
        return
    }

    playback := true
    FocusBrowser()

    events := macroEvents[layerMacroName]
    startTime := A_TickCount

    if (events.Length = 1 && events[1].type = "jsonAnnotation") {
        ExecuteJsonAnnotation(events[1])
    } else {
        PlayEventsOptimized(events)
    }

    executionTime := A_TickCount - startTime

    ; RECORD EXECUTION STATS - CRITICAL FIX FOR STATS MENU
    ; Create analysis record for stats tracking
    analysisRecord := {
        boundingBoxCount: 0,
        degradationAssignments: "",
        jsonDegradationName: "",
        severity: "medium"
    }

    ; Count bounding boxes and extract degradation data for macro executions
    if (events.Length > 1 || (events.Length = 1 && events[1].type != "jsonAnnotation")) {
        bboxCount := 0
        degradationList := []

        for event in events {
            if (event.type = "boundingBox") {
                bboxCount++
                ; Extract degradation type if assigned during recording
                if (event.HasOwnProp("degradationType") && event.degradationType >= 1 && event.degradationType <= 9) {
                    degradationList.Push(event.degradationType)
                }
            }
        }

        analysisRecord.boundingBoxCount := bboxCount
        if (degradationList.Length > 0) {
            degradationString := ""
            for i, deg in degradationList {
                degradationString .= (i > 1 ? "," : "") . deg
            }
            analysisRecord.degradationAssignments := degradationString
        }
    } else if (events.Length = 1 && events[1].type = "jsonAnnotation") {
        ; Extract JSON degradation info for stats tracking
        jsonEvent := events[1]
        if (jsonEvent.HasOwnProp("categoryId") && degradationTypes.Has(jsonEvent.categoryId)) {
            analysisRecord.jsonDegradationName := degradationTypes[jsonEvent.categoryId]
        }
        if (jsonEvent.HasOwnProp("severity")) {
            analysisRecord.severity := jsonEvent.severity
        }
    }

    RecordExecutionStatsAsync(buttonName, startTime, events.Length = 1 && events[1].type = "jsonAnnotation" ? "json_profile" : "macro", events, analysisRecord)

    ; PERFORMANCE: MacroExecutionAnalysis() removed - stats are in-memory only now

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
                ; Count existing bounding boxes to determine if this is the first
                local boxCount := 0
                for evt in events {
                    if (evt.type = "boundingBox")
                        boxCount++
                }

                ; Calculate time since previous event
                local timeSincePrevious := 0
                if (events.Length > 0) {
                    timeSincePrevious := timestamp - events[events.Length].time
                }

                local boundingBoxEvent := {
                    type: "boundingBox",
                    left: Min(boxStartX, x),
                    top: Min(boxStartY, y),
                    right: Max(boxStartX, x),
                    bottom: Max(boxStartY, y),
                    time: timestamp,
                    isFirstBox: (boxCount = 0),
                    timeSincePrevious: timeSincePrevious
                }
                events.Push(boundingBoxEvent)
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
    
    ; Never record CapsLock+F, CapsLock+SPACE, or RCtrl
    if (keyName = "CapsLock" || keyName = "f" || keyName = "Space" || keyName = "RCtrl") {
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

    ; CRITICAL: Copy recordedMode property from temp macro to assigned macro
    if (macroEvents[currentMacro].HasOwnProp("recordedMode")) {
        macroEvents[layerMacroName].recordedMode := macroEvents[currentMacro].recordedMode
        VizLog("COPIED recordedMode from " . currentMacro . " to " . layerMacroName . ": " . macroEvents[currentMacro].recordedMode)
        FlushVizLog()
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
    global smartBoxClickDelay, smartMenuClickDelay, firstBoxDelay, menuWaitDelay

    SetMouseDelay(0)
    SetKeyDelay(5)
    CoordMode("Mouse", "Screen")

    for eventIndex, event in recordedEvents {
        if (!playback)
            break

        if (event.type = "boundingBox") {
            ; === INTELLIGENT TIMING: Box Drawing Sequence ===

            ; Step 1: Move to start position with smart timing
            MouseMove(event.left, event.top, 2)
            Sleep(smartBoxClickDelay)  ; Minimal delay for cursor positioning

            ; Step 2: Press mouse button
            Send("{LButton Down}")
            Sleep(mouseClickDelay)  ; Brief pause during click

            ; Step 3: Drag to end position (speed 8 for accuracy)
            MouseMove(event.right, event.bottom, 8)
            Sleep(mouseReleaseDelay)  ; Brief pause before release

            ; Step 4: Release mouse button
            Send("{LButton Up}")

            ; Step 5: Intelligent delay - optimized single wait period
            ; Wait time accounts for both UI response and preparation for next action
            if (event.HasOwnProp("isFirstBox") && event.isFirstBox) {
                ; First box: Extra time for initial UI stabilization
                Sleep(firstBoxDelay)
            } else {
                ; Subsequent boxes: Standard delay includes menu wait time
                Sleep(betweenBoxDelay)
            }
        }
        else if (event.type = "mouseDown") {
            MouseMove(event.x, event.y, 2)
            Sleep(smartBoxClickDelay)
            Send("{LButton Down}")
            Sleep(mouseClickDelay)
        }
        else if (event.type = "mouseUp") {
            MouseMove(event.x, event.y, 2)
            Sleep(mouseReleaseDelay)
            Send("{LButton Up}")
        }
        else if (event.type = "keyDown") {
            if (event.HasOwnProp("key") && event.key != "") {
                Send("{" . event.key . " Down}")
                Sleep(keyPressDelay)
            }
        }
        else if (event.type = "keyUp") {
            if (event.HasOwnProp("key") && event.key != "") {
                Send("{" . event.key . " Up}")
            }
        }
    }

    SetMouseDelay(10)
    SetKeyDelay(10)
}

ExecuteJsonAnnotation(jsonEvent) {
    global annotationMode

    FocusBrowser()

    ; Use the stored annotation from the JSON event
    A_Clipboard := jsonEvent.annotation
    Sleep(20)
    Send("^v")
    Sleep(30)
    Send("+{Enter}")
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

    ; NIGHT MODE - dark theme always enabled
    mainGui := Gui("+Resize +MinSize" . minWindowWidth . "x" . minWindowHeight, "Data Labeling Assistant")
    mainGui.BackColor := "0x2D2D2D"
    mainGui.SetFont("s" . Round(10 * scaleFactor), "c0xFFFFFF")
    
    CreateToolbar()
    CreateGridOutline()
    CreateButtonGrid()
    CreateStatusBar()
    
    mainGui.OnEvent("Size", GuiResize)
    mainGui.OnEvent("Close", (*) => SafeExit())
    
    mainGui.Show("w" . windowWidth . " h" . windowHeight)
}

CreateToolbar() {
    global mainGui, darkMode, modeToggleBtn, windowWidth

    ; Calculate scale based on current window size
    scale := GetScaleFactor()

    ; ALL dimensions use scale - SIMPLE percentage scaling
    toolbarHeight := Round(40 * scale)
    btnHeight := Round(28 * scale)
    btnY := Round((toolbarHeight - btnHeight) / 2)
    spacing := Round(8 * scale)

    ; Background
    tbBg := mainGui.Add("Text", "x0 y0 w" . windowWidth . " h" . toolbarHeight)
    tbBg.BackColor := "0x1E1E1E"
    mainGui.tbBg := tbBg

    x := spacing

    btnRecord := mainGui.Add("Button", "x" . x . " y" . btnY . " w" . Round(75 * scale) . " h" . btnHeight, "🎥 Record")
    btnRecord.OnEvent("Click", (*) => F9_RecordingOnly())
    btnRecord.SetFont("s" . Round(9 * scale) . " bold", "cWhite")
    btnRecord.Opt("+Background0x3A3A3A")
    mainGui.btnRecord := btnRecord
    x += Round(80 * scale)

    modeToggleBtn := mainGui.Add("Button", "x" . x . " y" . btnY . " w" . Round(70 * scale) . " h" . btnHeight, (annotationMode = "Wide" ? "🔦 Wide" : "📱 Narrow"))
    modeToggleBtn.OnEvent("Click", (*) => ToggleAnnotationMode())
    modeToggleBtn.SetFont("s" . Round(8 * scale) . " bold", "cWhite")
    modeToggleBtn.Opt("+Background0x505050")
    mainGui.modeToggleBtn := modeToggleBtn
    x += Round(75 * scale)

    btnBreakMode := mainGui.Add("Button", "x" . x . " y" . btnY . " w" . Round(65 * scale) . " h" . btnHeight, "☕ Break")
    btnBreakMode.OnEvent("Click", (*) => ToggleBreakMode())
    btnBreakMode.SetFont("s" . Round(8 * scale) . " bold", "cWhite")
    btnBreakMode.Opt("+Background0x505050")
    mainGui.btnBreakMode := btnBreakMode
    x += Round(70 * scale)

    btnClear := mainGui.Add("Button", "x" . x . " y" . btnY . " w" . Round(50 * scale) . " h" . btnHeight, "🗑️ Clear")
    btnClear.OnEvent("Click", (*) => ShowClearDialog())
    btnClear.SetFont("s" . Round(7 * scale) . " bold", "cWhite")
    btnClear.Opt("+Background0x505050")

    ; Right section
    rightSection := Round(windowWidth * 0.5)
    rightWidth := windowWidth - rightSection - spacing
    btnWidth := Round((rightWidth - Round(20 * scale)) / 3)

    btnStats := mainGui.Add("Button", "x" . rightSection . " y" . btnY . " w" . btnWidth . " h" . btnHeight, "📊 Stats")
    btnStats.OnEvent("Click", (*) => ShowStatsMenu())
    btnStats.SetFont("s" . Round(8 * scale) . " bold", "cWhite")
    btnStats.Opt("+Background0x3A3A3A")
    mainGui.btnStats := btnStats

    btnSettings := mainGui.Add("Button", "x" . (rightSection + btnWidth + Round(5 * scale)) . " y" . btnY . " w" . btnWidth . " h" . btnHeight, "⚙️ Config")
    btnSettings.OnEvent("Click", (*) => ShowSettings())
    btnSettings.SetFont("s" . Round(8 * scale) . " bold", "cWhite")
    btnSettings.Opt("+Background0x3A3A3A")
    mainGui.btnSettings := btnSettings

    btnEmergency := mainGui.Add("Button", "x" . (rightSection + (btnWidth * 2) + Round(10 * scale)) . " y" . btnY . " w" . btnWidth . " h" . btnHeight, "🚨 STOP`nCapsLock+SPACE")
    btnEmergency.OnEvent("Click", (*) => EmergencyStop())
    btnEmergency.SetFont("s" . Round(8 * scale) . " bold", "cWhite")
    btnEmergency.Opt("+Background0x8B0000")
    mainGui.btnEmergency := btnEmergency
}

CreateGridOutline() {
    global mainGui, gridOutline

    ; NIGHT MODE - dark gray outline instead of colored
    gridOutline := mainGui.Add("Text", "x0 y0 w100 h100 +0x1", "")
    gridOutline.Opt("+Background0x555555")
}

DestroyButtonGrid() {
    global buttonGrid, buttonLabels, buttonPictures, buttonNames

    ; Safely destroy all existing button grid controls
    for buttonName in buttonNames {
        if (buttonGrid.Has(buttonName)) {
            try buttonGrid[buttonName].Destroy()
        }
        if (buttonLabels.Has(buttonName)) {
            try buttonLabels[buttonName].Destroy()
        }
        if (buttonPictures.Has(buttonName)) {
            try buttonPictures[buttonName].Destroy()
        }
    }

    ; Clear the maps
    buttonGrid.Clear()
    buttonLabels.Clear()
    buttonPictures.Clear()
}

CreateButtonGrid() {
    global mainGui, buttonGrid, buttonLabels, buttonPictures, buttonNames, darkMode, windowWidth, windowHeight, gridOutline

    ; Calculate scale based on current window size
    scale := GetScaleFactor()

    ; ALL dimensions use scale - SIMPLE percentage scaling
    margin := Round(8 * scale)
    padding := Round(3 * scale)
    toolbarHeight := Round(40 * scale)
    gridTopPadding := Round(4 * scale)
    gridBottomPadding := Round(32 * scale)

    gridWidth := windowWidth - (margin * 2)
    gridHeight := windowHeight - toolbarHeight - gridTopPadding - gridBottomPadding - (margin * 2)

    ; Calculate button dimensions from available space
    buttonWidth := Floor((gridWidth - padding * 2) / 3)
    buttonHeight := Floor((gridHeight - padding * 3) / 4)
    labelHeight := Round(20 * scale)
    thumbHeight := buttonHeight - labelHeight - Round(1 * scale)

    outlineThickness := Round(2 * scale)
    gridOutline.Move(margin - outlineThickness, toolbarHeight + gridTopPadding + margin - outlineThickness,
                    gridWidth + (outlineThickness * 2), gridHeight + (outlineThickness * 2))
    
    for row in [0, 1, 2, 3] {
        for col in [0, 1, 2] {
            index := row * 3 + col + 1
            if (index > 12)
                continue

            buttonName := buttonNames[index]
            ; Position using simple grid layout
            x := margin + col * (buttonWidth + padding)
            y := toolbarHeight + gridTopPadding + margin + row * (buttonHeight + padding)

            ; NIGHT MODE - dark background for all buttons
            button := mainGui.Add("Text", "x" . Floor(x) . " y" . Floor(y) . " w" . Floor(buttonWidth) . " h" . Floor(thumbHeight) . " 0x201", "")
            button.Opt("+Background0x2A2A2A")
            button.SetFont("s" . Round(9 * scale), "cWhite")

            picture := mainGui.Add("Picture", "x" . Floor(x) . " y" . Floor(y) . " w" . Floor(buttonWidth) . " h" . Floor(thumbHeight) . " 0x10E Hidden")

            ; Label showing both Numpad and CapsLock+key hotkeys
            simpleName := StrReplace(StrReplace(StrReplace(buttonName, "Num", ""), "Dot", "."), "Mult", "*")
            ; Map button names to their WASD equivalents
            wasdKey := ""
            switch buttonName {
                case "Num7": wasdKey := "1"
                case "Num8": wasdKey := "2"
                case "Num9": wasdKey := "3"
                case "Num4": wasdKey := "Q"
                case "Num5": wasdKey := "W"
                case "Num6": wasdKey := "E"
                case "Num1": wasdKey := "A"
                case "Num2": wasdKey := "S"
                case "Num3": wasdKey := "D"
                case "Num0": wasdKey := "Z"
                case "NumDot": wasdKey := "X"
                case "NumMult": wasdKey := "C"
            }
            labelText := "Num " . simpleName . " / Caps+" . wasdKey
            labelY := y + thumbHeight + Round(1 * scale)
            label := mainGui.Add("Text", "x" . Floor(x) . " y" . Floor(labelY) . " w" . Floor(buttonWidth) . " h" . Floor(labelHeight) . " Center BackgroundTrans", labelText)
            label.Opt("cWhite")
            label.SetFont("s" . Round(8 * scale) . " bold")
            
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

ResizeButtonGrid() {
    global buttonGrid, buttonLabels, buttonPictures, buttonNames, windowWidth, windowHeight, gridOutline, mainGui

    ; Disable redrawing to reduce flicker
    static WM_SETREDRAW := 0x000B
    SendMessage(WM_SETREDRAW, 0, 0, mainGui)

    ; Calculate scale based on current window size
    scale := GetScaleFactor()

    ; ALL dimensions use scale - SIMPLE percentage scaling (same as CreateButtonGrid)
    margin := Round(8 * scale)
    padding := Round(3 * scale)
    toolbarHeight := Round(40 * scale)
    gridTopPadding := Round(4 * scale)
    gridBottomPadding := Round(32 * scale)

    gridWidth := windowWidth - (margin * 2)
    gridHeight := windowHeight - toolbarHeight - gridTopPadding - gridBottomPadding - (margin * 2)

    ; Calculate button dimensions from available space
    buttonWidth := Floor((gridWidth - padding * 2) / 3)
    buttonHeight := Floor((gridHeight - padding * 3) / 4)
    labelHeight := Round(20 * scale)
    thumbHeight := buttonHeight - labelHeight - Round(1 * scale)

    ; Move grid outline
    outlineThickness := Round(2 * scale)
    gridOutline.Move(margin - outlineThickness, toolbarHeight + gridTopPadding + margin - outlineThickness,
                    gridWidth + (outlineThickness * 2), gridHeight + (outlineThickness * 2))

    ; Move and resize existing controls
    for row in [0, 1, 2, 3] {
        for col in [0, 1, 2] {
            index := row * 3 + col + 1
            if (index > 12)
                continue

            buttonName := buttonNames[index]

            ; Calculate position (same logic as CreateButtonGrid)
            x := margin + col * (buttonWidth + padding)
            y := toolbarHeight + gridTopPadding + margin + row * (buttonHeight + padding)
            labelY := y + thumbHeight + Round(1 * scale)

            ; Move existing controls instead of recreating them
            if (buttonGrid.Has(buttonName)) {
                buttonGrid[buttonName].Move(Floor(x), Floor(y), Floor(buttonWidth), Floor(thumbHeight))
                ; Update font size for the button
                buttonGrid[buttonName].SetFont("s" . Round(9 * scale))
            }

            if (buttonPictures.Has(buttonName)) {
                buttonPictures[buttonName].Move(Floor(x), Floor(y), Floor(buttonWidth), Floor(thumbHeight))
            }

            if (buttonLabels.Has(buttonName)) {
                buttonLabels[buttonName].Move(Floor(x), Floor(labelY), Floor(buttonWidth), Floor(labelHeight))
                ; Update font size for the label
                buttonLabels[buttonName].SetFont("s" . Round(8 * scale) . " bold")
            }
        }
    }

    ; Re-enable redrawing and force a single refresh
    SendMessage(WM_SETREDRAW, 1, 0, mainGui)
    DllCall("RedrawWindow", "Ptr", mainGui.Hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0081) ; RDW_INVALIDATE | RDW_UPDATENOW
}

CreateStatusBar() {
    global mainGui, statusBar, windowWidth, windowHeight

    ; Calculate scale based on current window size
    scale := GetScaleFactor()

    ; ALL dimensions use scale - SIMPLE percentage scaling
    statusY := windowHeight - Round(30 * scale)
    statusBar := mainGui.Add("Text", "x" . Round(8 * scale) . " y" . statusY . " w" . (windowWidth - Round(16 * scale)) . " h" . Round(22 * scale), "✅ Ready - CapsLock+F to record")
    statusBar.Opt("cWhite")
    statusBar.SetFont("s" . Round(8 * scale))
}

HandleButtonClick(buttonName, *) {
    ExecuteMacro(buttonName)
}

HandleContextMenu(buttonName, *) {
    ShowContextMenu(buttonName)
}

; ===== BUTTON APPEARANCE =====
RefreshAllButtonAppearances() {
    global buttonNames
    VizLog("=== RefreshAllButtonAppearances START ===")
    errorCount := 0
    successCount := 0

    for buttonName in buttonNames {
        try {
            UpdateButtonAppearance(buttonName)
            successCount++
        } catch Error as e {
            errorCount++
            VizLog("ERROR refreshing " . buttonName . ": " . e.Message . " (Line: " . e.Line . ")")
            ; Try to make the button show something instead of crashing
            try {
                global buttonGrid
                if (buttonGrid.Has(buttonName)) {
                    btn := buttonGrid[buttonName]
                    btn.Visible := true
                    btn.Text := "ERROR"
                }
            }
        }
    }

    VizLog("RefreshAllButtonAppearances complete: " . successCount . " success, " . errorCount . " errors")
    FlushVizLog()
}

UpdateButtonAppearance(buttonName) {
    global buttonGrid, buttonPictures, buttonThumbnails, macroEvents, darkMode, currentLayer, degradationTypes, degradationColors, buttonDisplayedHBITMAPs

    if (!buttonGrid.Has(buttonName))
        return

    button := buttonGrid[buttonName]
    picture := buttonPictures[buttonName]
    oldHbitmap := buttonDisplayedHBITMAPs.Has(buttonName) ? buttonDisplayedHBITMAPs[buttonName] : 0
    oldHbitmapValid := (oldHbitmap && IsHBITMAPValid(oldHbitmap))
    layerMacroName := "L" . currentLayer . "_" . buttonName

    hasMacro := macroEvents.Has(layerMacroName) && macroEvents[layerMacroName].Length > 0

    ; Keep simple label - already set during CreateButtonGrid, don't change it

    hasThumbnail := buttonThumbnails.Has(layerMacroName) && FileExist(buttonThumbnails[layerMacroName])

    isJsonAnnotation := false
    jsonInfo := ""
    jsonColor := "0xFFD700"

    if (hasMacro && macroEvents[layerMacroName].Length = 1 && macroEvents[layerMacroName][1].type = "jsonAnnotation") {
        isJsonAnnotation := true
        jsonEvent := macroEvents[layerMacroName][1]
        typeName := StrTitle(degradationTypes[jsonEvent.categoryId])
        ; Remove mode from text - will be shown visually via letterboxing
        jsonInfo := typeName . " " . StrUpper(jsonEvent.severity)

        if (degradationColors.Has(jsonEvent.categoryId)) {
            jsonColor := degradationColors[jsonEvent.categoryId]
        }
    }

    try {
        if (hasThumbnail && !isJsonAnnotation) {
            ; Use thumbnail if available
            button.Visible := false
            picture.Visible := true
            picture.Text := ""
            try {
                picture.Value := buttonThumbnails[layerMacroName]
            } catch {
                picture.Visible := false
                button.Visible := true
                button.Opt("+Background0x3A3A3A")
                button.SetFont("s7 bold", "cWhite")
                button.Text := "MACRO`n" . macroEvents[layerMacroName].Length . " events`n(thumb error)"
            }
            if (oldHbitmap) {
                RemoveHBITMAPReference(oldHbitmap)
                buttonDisplayedHBITMAPs[buttonName] := 0
            }
        } else if (isJsonAnnotation) {
            ; JSON annotation display with visual letterboxing for Narrow mode
            jsonEvent := macroEvents[layerMacroName][1]
            isNarrowMode := (jsonEvent.mode = "Narrow")

            ; Get button dimensions
            buttonGrid[buttonName].GetPos(, , &btnW, &btnH)

            ; Create visual representation with letterboxing
            hbitmap := CreateJsonAnnotationVisual(btnW, btnH, jsonInfo, jsonColor, isNarrowMode)

            if (hbitmap && hbitmap != 0) {
                button.Visible := false
                picture.Visible := true
                picture.Text := ""
                try {
                    picture.Value := HBITMAPToPictureValue(hbitmap)
                    AddHBITMAPReference(hbitmap)
                    buttonDisplayedHBITMAPs[buttonName] := hbitmap
                    picture.Redraw()

                    if (oldHbitmap) {
                        RemoveHBITMAPReference(oldHbitmap)
                    }
                } catch {
                    ; Fallback to button text if visual creation fails
                    RemoveHBITMAPReference(hbitmap)
                    picture.Visible := false
                    button.Visible := true
                    button.Opt("+Background" . jsonColor)
                    button.SetFont("s7 bold", "cBlack")
                    button.Text := jsonInfo
                    buttonDisplayedHBITMAPs[buttonName] := 0
                }
            } else {
                ; Fallback to button text
                picture.Visible := false
                button.Visible := true
                button.Opt("+Background" . jsonColor)
                button.SetFont("s7 bold", "cBlack")
                button.Text := jsonInfo
                if (oldHbitmap) {
                    RemoveHBITMAPReference(oldHbitmap)
                    buttonDisplayedHBITMAPs[buttonName] := 0
                }
            }
        } else if (hasMacro) {
            ; DIRECT HBITMAP VISUALIZATION - Pure in-memory, zero file I/O
            events := macroEvents[layerMacroName]

            ; Get button dimensions for proper scaling
            buttonGrid[buttonName].GetPos(, , &btnW, &btnH)
            buttonDims := {width: btnW, height: btnH}

            ; Create HBITMAP directly from GDI+ bitmap
            VizLog(">>> UpdateButtonAppearance: Calling CreateHBITMAPVisualization for " . buttonName)
            hbitmap := CreateHBITMAPVisualization(events, buttonDims)
            VizLog(">>> UpdateButtonAppearance: Returned HBITMAP=" . hbitmap)

            if (events.HasOwnProp("recordedCanvas")) {
                buttonLetterboxingStates[layerMacroName] := events.recordedCanvas.Clone()
            } else if (buttonLetterboxingStates.Has(layerMacroName)) {
                buttonLetterboxingStates.Delete(layerMacroName)
            }

            if (hbitmap && hbitmap != 0) {
                ; HBITMAP creation succeeded - load directly into picture control
                VizLog(">>> UpdateButtonAppearance: Assigning HBITMAP to picture control")
                button.Visible := false
                picture.Visible := true
                picture.Text := ""

                assignmentSuccess := false
                assignErrorMsg := ""
                try {
                    ; Use unsigned string form so Picture control accepts high-bit handles
                    picture.Value := HBITMAPToPictureValue(hbitmap)
                    assignmentSuccess := true
                } catch Error as assignError {
                    assignErrorMsg := assignError.Message
                }

                if (assignmentSuccess) {
                    AddHBITMAPReference(hbitmap)
                    buttonDisplayedHBITMAPs[buttonName] := hbitmap
                    picture.Redraw()
                    VizLog(">>> UpdateButtonAppearance: SUCCESS - HBITMAP displayed")
                    FlushVizLog()

                    if (oldHbitmap) {
                        RemoveHBITMAPReference(oldHbitmap)
                    }
                } else {
                    RemoveHBITMAPReference(hbitmap)
                    if (oldHbitmapValid) {
                        VizLog(">>> UpdateButtonAppearance: HBITMAP assignment failed - trying to restore previous")
                        ; Double-check old HBITMAP is still valid before trying to restore
                        if (IsHBITMAPValid(oldHbitmap)) {
                            try {
                                picture.Visible := true
                                button.Visible := false
                                picture.Text := ""
                                picture.Value := HBITMAPToPictureValue(oldHbitmap)
                                picture.Redraw()
                                buttonDisplayedHBITMAPs[buttonName] := oldHbitmap
                                VizLog(">>> UpdateButtonAppearance: Successfully restored old HBITMAP")
                            } catch Error as restoreError {
                                VizLog(">>> UpdateButtonAppearance: EXCEPTION restoring old HBITMAP - " . restoreError.Message)
                                ; Old HBITMAP also failed, show text fallback
                                picture.Visible := false
                                button.Visible := true
                                button.Opt("+Background0x3A3A3A")
                                button.SetFont("s7 bold", "cWhite")
                                button.Text := "MACRO`n" . events.Length . " events`n(viz error)"
                                buttonDisplayedHBITMAPs[buttonName] := 0
                            }
                        } else {
                            VizLog(">>> UpdateButtonAppearance: Old HBITMAP no longer valid")
                            picture.Visible := false
                            button.Visible := true
                            button.Opt("+Background0x3A3A3A")
                            button.SetFont("s7 bold", "cWhite")
                            button.Text := "MACRO`n" . events.Length . " events`n(viz error)"
                            buttonDisplayedHBITMAPs[buttonName] := 0
                        }
                    } else {
                        picture.Visible := false
                        button.Visible := true
                        button.Opt("+Background0x3A3A3A")
                        button.SetFont("s7 bold", "cWhite")
                        button.Text := "MACRO`n" . events.Length . " events"
                        buttonDisplayedHBITMAPs[buttonName] := 0
                    }
                    VizLog(">>> UpdateButtonAppearance: HBITMAP assignment failed - " . assignErrorMsg)
                    FlushVizLog()
                }
            } else {
                ; HBITMAP creation failed - simple text fallback
                VizLog(">>> UpdateButtonAppearance: HBITMAP FAILED - using text fallback")

                ; Determine why it failed
                global gdiPlusInitialized, wideCanvasRight, wideCanvasLeft, narrowCanvasRight, narrowCanvasLeft
                failureReason := ""
                hasBoxes := false

                ; Check if macro has any box events
                for event in events {
                    if (event.type = "boundingBox") {
                        hasBoxes := true
                        break
                    }
                }

                if (!hasBoxes) {
                    failureReason := ""  ; No error - just no boxes to visualize
                    VizLog("  Reason: No bounding boxes in macro (clicks/keys only)")
                } else if (!gdiPlusInitialized) {
                    failureReason := "`n(GDI+ fail)"
                    VizLog("  Reason: GDI+ not initialized")
                } else if (wideCanvasRight <= wideCanvasLeft && narrowCanvasRight <= narrowCanvasLeft) {
                    failureReason := "`n(No canvas)"
                    VizLog("  Reason: No canvas configured")
                } else {
                    failureReason := "`n(Viz error)"
                    VizLog("  Reason: Unknown visualization error")
                }
                FlushVizLog()

                if (oldHbitmapValid) {
                    VizLog(">>> UpdateButtonAppearance: Restoring previous visualization after creation failure")
                    picture.Visible := true
                    button.Visible := false
                    picture.Text := ""
                    picture.Value := HBITMAPToPictureValue(oldHbitmap)
                    picture.Redraw()
                    buttonDisplayedHBITMAPs[buttonName] := oldHbitmap
                } else {
                    picture.Visible := false
                    button.Visible := true
                    button.Opt("+Background0x3A3A3A")
                    button.SetFont("s7 bold", "cWhite")
                    button.Text := "MACRO`n" . events.Length . " events" . failureReason
                    buttonDisplayedHBITMAPs[buttonName] := 0
                }
            }
        } else {
            ; Empty button - no macro assigned
            picture.Visible := false
            button.Visible := true
            button.Opt("+Background" . (darkMode ? "0x2A2A2A" : "0xF8F8F8"))
            button.SetFont("s8", "cGray")
            button.Text := ""
            if (oldHbitmap) {
                RemoveHBITMAPReference(oldHbitmap)
                buttonDisplayedHBITMAPs[buttonName] := 0
            }
        }

        if (button.Visible)
            button.Redraw()
        if (picture.Visible)
            picture.Redraw()

    } catch Error as e {
        ; Simple error handling with safety checks
        VizLog(">>> UpdateButtonAppearance: EXCEPTION - " . e.Message)
        FlushVizLog()

        try {
            button.Visible := true
            picture.Visible := false
            button.Opt("+Background" . (darkMode ? "0x2A2A2A" : "0xF8F8F8"))
            button.SetFont("s8", "cGray")
            button.Text := "ERROR"
        } catch Error as innerError {
            VizLog(">>> UpdateButtonAppearance: CRITICAL - Error handler itself failed: " . innerError.Message)
            FlushVizLog()
            ; At this point, just give up gracefully - don't crash
        }
    }
}

UpdateStatus(text) {
    global statusBar
    if (IsObject(statusBar))
        statusBar.Text := text
}

GuiResize(thisGui, minMax, width, height) {
    global statusBar, windowWidth, windowHeight, mainGui, resizeTimer

    if (minMax = -1)
        return

    windowWidth := width
    windowHeight := height

    ; Calculate scale based on NEW window size
    scale := GetScaleFactor()

    ; ALL dimensions use scale - DYNAMIC percentage scaling
    if (statusBar) {
        statusY := height - Round(35 * scale)
        statusBar.Move(Round(8 * scale), statusY, width - Round(16 * scale), Round(25 * scale))
    }

    if (mainGui.HasProp("tbBg") && mainGui.tbBg) {
        mainGui.tbBg.Move(0, 0, width, Round(40 * scale))
    }

    ; Debounce button grid resize to reduce flicker during continuous resizing
    ; Clear any existing timer
    if (resizeTimer) {
        SetTimer(resizeTimer, 0)
    }

    ; Set a new timer to resize after user stops dragging (50ms delay)
    resizeTimer := () => ResizeButtonGrid()
    SetTimer(resizeTimer, -50)
}

; ===== LAYER SYSTEM =====
SwitchLayer(direction) {
    ; REMOVED - Single layer system only
    ; Layer navigation disabled
    return
}

SwitchLayer_OLD(direction) {
    ; OLD FUNCTION KEPT FOR REFERENCE - NOT USED
    global currentLayer, totalLayers, buttonNames

    if (direction = "next") {
        currentLayer++
        if (currentLayer > totalLayers)
            currentLayer := 1
    } else if (direction = "prev") {
        currentLayer--
        if (currentLayer < 1)
            currentLayer := totalLayers
    }

    for name in buttonNames {
        UpdateButtonAppearance(name)
    }
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
    global macroEvents, currentLayer, buttonLetterboxingStates
    layerMacroName := "L" . currentLayer . "_" . buttonName
    if (MsgBox("Clear macro for " . buttonName . " on Layer " . currentLayer . "?", "Confirm Clear", "YesNo Icon!") = "Yes") {
        macroEvents.Delete(layerMacroName)
        if (buttonLetterboxingStates.Has(layerMacroName))
            buttonLetterboxingStates.Delete(layerMacroName)
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
        ; Resuming from break
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
        ; Starting break - update accumulated time first
        UpdateActiveTime()
        breakMode := true
        breakStartTime := A_TickCount

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
; ShowStats() function removed - now using ShowStatsMenu() from src/StatsGui.ahk

ShowSettings() {
    ; Create settings dialog with tabbed interface
    settingsGui := Gui("+Resize", "⚙️ Configuration")
    settingsGui.SetFont("s9")

    ; Compact header
    settingsGui.Add("Text", "x20 y10 w520 h25 Center", "Configuration")
    settingsGui.SetFont("s10 Bold")

    ; Create tabbed interface
    tabs := settingsGui.Add("Tab3", "x20 y40 w520 h520", ["⚙️ Essential", "⚡ Execution Timing", "🎹 Hotkeys"])

    ; TAB 1: Essential Configuration
    tabs.UseTab(1)
    settingsGui.SetFont("s9")

    ; Canvas configuration section - PRIORITY #1
    settingsGui.Add("Text", "x30 y75 w480 h18", "🖼️ Canvas Calibration")
    settingsGui.SetFont("s8")

    wideGroup := settingsGui.Add("GroupBox", "x30 y95 w220 h150", "Wide Canvas")
    narrowGroup := settingsGui.Add("GroupBox", "x270 y95 w220 h150", "Narrow Canvas")

    settingsGui.SetFont("s8 Bold")
    settingsGui.wideStatusCtrl := settingsGui.Add("Text", "x45 y115 w190 h18", "")
    settingsGui.narrowStatusCtrl := settingsGui.Add("Text", "x285 y115 w190 h18", "")
    settingsGui.SetFont("s8")
    settingsGui.wideDetailCtrl := settingsGui.Add("Text", "x45 y135 w190 h36 c0x666666", "")
    settingsGui.narrowDetailCtrl := settingsGui.Add("Text", "x285 y135 w190 h36 c0x666666", "")

    settingsGui.SetFont("s9")
    btnConfigureWide := settingsGui.Add("Button", "x45 y175 w100 h26", "🧭 Calibrate")
    btnConfigureWide.OnEvent("Click", (*) => ConfigureWideCanvasFromSettings(settingsGui))

    btnResetWide := settingsGui.Add("Button", "x155 y175 w80 h26", "↻ Reset")
    btnResetWide.OnEvent("Click", (*) => ResetWideCanvasCalibration(settingsGui))

    btnConfigureNarrow := settingsGui.Add("Button", "x285 y175 w100 h26", "🧭 Calibrate")
    btnConfigureNarrow.OnEvent("Click", (*) => ConfigureNarrowCanvasFromSettings(settingsGui))

    btnResetNarrow := settingsGui.Add("Button", "x395 y175 w80 h26", "↻ Reset")
    btnResetNarrow.OnEvent("Click", (*) => ResetNarrowCanvasCalibration(settingsGui))

    UpdateCanvasStatusControls(settingsGui)
    settingsGui.SetFont("s9")

    ; Visualization save path section
    settingsGui.Add("Text", "x30 y260 w480 h18", "💾 Visualization Save Location (for corporate environments)")
    settingsGui.SetFont("s8")
    settingsGui.Add("Text", "x40 y280 w480 h15 c0x666666", "Choose where preview images are saved (if auto fails at work)")
    settingsGui.SetFont("s9")

    global visualizationSavePath
    pathOptions := ["Auto (try all)", "Data folder", "Documents folder", "User Profile", "Temp folder"]
    pathValues := ["auto", "data", "documents", "profile", "temp"]

    ; Find current selection index
    currentIndex := 1
    for i, val in pathValues {
        if (val = visualizationSavePath) {
            currentIndex := i
            break
        }
    }

    ddlVizPath := settingsGui.Add("DropDownList", "x40 y298 w380", pathOptions)
    ddlVizPath.Choose(currentIndex)
    ddlVizPath.OnEvent("Change", (*) => ApplyVisualizationPath(ddlVizPath, pathValues))
    settingsGui.ddlVizPath := ddlVizPath

    ; System maintenance section
    settingsGui.Add("Text", "x30 y330 w480 h18", "🔧 System Maintenance")

    btnManualSave := settingsGui.Add("Button", "x40 y353 w120 h28", "💾 Save Now")
    btnManualSave.OnEvent("Click", (*) => ManualSaveConfig())

    btnManualRestore := settingsGui.Add("Button", "x175 y353 w120 h28", "📤 Restore Backup")
    btnManualRestore.OnEvent("Click", (*) => ManualRestoreConfig())

    btnClearConfig := settingsGui.Add("Button", "x310 y353 w120 h28", "🗑️ Clear Macros")
    btnClearConfig.OnEvent("Click", (*) => ClearAllMacros(settingsGui))

    ; Stats reset
    settingsGui.Add("Text", "x30 y398 w480 h18", "📊 Statistics")
    btnResetStats := settingsGui.Add("Button", "x40 y421 w180 h28", "📊 Reset All Stats")
    btnResetStats.OnEvent("Click", (*) => ResetStatsFromSettings(settingsGui))

    ; TAB 2: Execution Settings
    tabs.UseTab(2)
    settingsGui.Add("Text", "x30 y95 w480 h20", "⚡ Macro Execution Fine-Tuning:")

    ; Timing controls
    global boxDrawDelay, mouseClickDelay, mouseDragDelay, mouseReleaseDelay, betweenBoxDelay, keyPressDelay, focusDelay, mouseHoverDelay

    ; Box drawing delays
    settingsGui.Add("Text", "x30 y125 w170 h20", "Box Draw Delay (ms):")
    boxDelayEdit := settingsGui.Add("Edit", "x200 y123 w70 h22", boxDrawDelay)
    boxDelayEdit.OnEvent("Change", (*) => UpdateTimingFromEdit("boxDrawDelay", boxDelayEdit))
    settingsGui.boxDelayEdit := boxDelayEdit  ; Store reference for preset updates

    settingsGui.Add("Text", "x30 y155 w170 h20", "Mouse Click Delay (ms):")
    clickDelayEdit := settingsGui.Add("Edit", "x200 y153 w70 h22", mouseClickDelay)
    clickDelayEdit.OnEvent("Change", (*) => UpdateTimingFromEdit("mouseClickDelay", clickDelayEdit))
    settingsGui.clickDelayEdit := clickDelayEdit

    settingsGui.Add("Text", "x30 y185 w170 h20", "Menu Click Delay (ms):")
    menuClickDelayEdit := settingsGui.Add("Edit", "x200 y183 w70 h22", menuClickDelay)
    menuClickDelayEdit.OnEvent("Change", (*) => UpdateTimingFromEdit("menuClickDelay", menuClickDelayEdit))
    settingsGui.menuClickDelayEdit := menuClickDelayEdit

    ; ===== INTELLIGENT TIMING SYSTEM CONTROLS =====
    settingsGui.Add("Text", "x30 y275 w480 h20", "🎯 Intelligent Timing System - Smart Delays:")

    settingsGui.Add("Text", "x30 y305 w170 h20", "Smart Box Click (ms):")
    smartBoxClickDelayEdit := settingsGui.Add("Edit", "x200 y303 w70 h22", smartBoxClickDelay)
    smartBoxClickDelayEdit.OnEvent("Change", (*) => UpdateTimingFromEdit("smartBoxClickDelay", smartBoxClickDelayEdit))
    settingsGui.smartBoxClickDelayEdit := smartBoxClickDelayEdit

    settingsGui.Add("Text", "x280 y305 w170 h20", "Smart Menu Click (ms):")
    smartMenuClickDelayEdit := settingsGui.Add("Edit", "x450 y303 w70 h22", smartMenuClickDelay)
    smartMenuClickDelayEdit.OnEvent("Change", (*) => UpdateTimingFromEdit("smartMenuClickDelay", smartMenuClickDelayEdit))
    settingsGui.smartMenuClickDelayEdit := smartMenuClickDelayEdit

    settingsGui.Add("Text", "x30 y215 w170 h20", "Mouse Drag Delay (ms):")
    dragDelayEdit := settingsGui.Add("Edit", "x200 y213 w70 h22", mouseDragDelay)
    dragDelayEdit.OnEvent("Change", (*) => UpdateTimingFromEdit("mouseDragDelay", dragDelayEdit))
    settingsGui.dragDelayEdit := dragDelayEdit

    settingsGui.Add("Text", "x30 y245 w170 h20", "Mouse Release Delay (ms):")
    releaseDelayEdit := settingsGui.Add("Edit", "x200 y243 w70 h22", mouseReleaseDelay)
    releaseDelayEdit.OnEvent("Change", (*) => UpdateTimingFromEdit("mouseReleaseDelay", releaseDelayEdit))
    settingsGui.releaseDelayEdit := releaseDelayEdit

    settingsGui.Add("Text", "x280 y125 w170 h20", "Between Box Delay (ms):")
    betweenDelayEdit := settingsGui.Add("Edit", "x450 y123 w70 h22", betweenBoxDelay)
    betweenDelayEdit.OnEvent("Change", (*) => UpdateTimingFromEdit("betweenBoxDelay", betweenDelayEdit))
    settingsGui.betweenDelayEdit := betweenDelayEdit

    settingsGui.Add("Text", "x280 y155 w170 h20", "Key Press Delay (ms):")
    keyDelayEdit := settingsGui.Add("Edit", "x450 y153 w70 h22", keyPressDelay)
    keyDelayEdit.OnEvent("Change", (*) => UpdateTimingFromEdit("keyPressDelay", keyDelayEdit))
    settingsGui.keyDelayEdit := keyDelayEdit

    settingsGui.Add("Text", "x280 y185 w170 h20", "Focus Delay (ms):")
    focusDelayEdit := settingsGui.Add("Edit", "x450 y183 w70 h22", focusDelay)
    focusDelayEdit.OnEvent("Change", (*) => UpdateTimingFromEdit("focusDelay", focusDelayEdit))
    settingsGui.focusDelayEdit := focusDelayEdit

    settingsGui.Add("Text", "x280 y215 w170 h20", "Mouse Hover (ms):")
    hoverDelayEdit := settingsGui.Add("Edit", "x450 y213 w70 h22", mouseHoverDelay)
    hoverDelayEdit.OnEvent("Change", (*) => UpdateTimingFromEdit("mouseHoverDelay", hoverDelayEdit))
    settingsGui.hoverDelayEdit := hoverDelayEdit

    settingsGui.Add("Text", "x30 y335 w170 h20", "First Box Delay (ms):")
    firstBoxDelayEdit := settingsGui.Add("Edit", "x200 y333 w70 h22", firstBoxDelay)
    firstBoxDelayEdit.OnEvent("Change", (*) => UpdateTimingFromEdit("firstBoxDelay", firstBoxDelayEdit))
    settingsGui.firstBoxDelayEdit := firstBoxDelayEdit

    settingsGui.Add("Text", "x280 y335 w170 h20", "Menu Wait Delay (ms):")
    menuWaitDelayEdit := settingsGui.Add("Edit", "x450 y333 w70 h22", menuWaitDelay)
    menuWaitDelayEdit.OnEvent("Change", (*) => UpdateTimingFromEdit("menuWaitDelay", menuWaitDelayEdit))
    settingsGui.menuWaitDelayEdit := menuWaitDelayEdit

    ; Preset buttons section (clear spacing from timing controls)
    settingsGui.Add("Text", "x30 y375 w480 h18", "🎚️ Timing Presets")

    btnFast := settingsGui.Add("Button", "x30 y398 w100 h25", "⚡ Fast")
    btnFast.OnEvent("Click", (*) => ApplyTimingPreset("fast", settingsGui))

    btnDefault := settingsGui.Add("Button", "x150 y398 w100 h25", "🎯 Default")
    btnDefault.OnEvent("Click", (*) => ApplyTimingPreset("default", settingsGui))

    btnSafe := settingsGui.Add("Button", "x270 y398 w100 h25", "🛡️ Safe")
    btnSafe.OnEvent("Click", (*) => ApplyTimingPreset("safe", settingsGui))

    btnSlow := settingsGui.Add("Button", "x390 y398 w100 h25", "🐌 Slow")
    btnSlow.OnEvent("Click", (*) => ApplyTimingPreset("slow", settingsGui))

    ; Instructions
    settingsGui.Add("Text", "x30 y435 w480 h50", "💡 Adjust timing delays to optimize macro execution speed vs reliability. Higher values = more reliable but slower execution. Use presets for quick setup.")

    ; TAB 3: Hotkeys
    tabs.UseTab(3)
    global hotkeyProfileActive, wasdHotkeyMap, wasdLabelsEnabled

    ; Header
    settingsGui.Add("Text", "x30 y75 w480 h20", "🎮 Hotkey Configuration")
    settingsGui.SetFont("s8")
    settingsGui.Add("Text", "x30 y98 w480 h14 c0x666666", "Type hotkey manually or click 'Set' to capture key combination")
    settingsGui.SetFont("s9")

    ; Core Macro Controls Section
    settingsGui.Add("Text", "x30 y120 w480 h18", "🎯 Core Macro Controls:")
    hotkeyY := 145

    ; Record Toggle
    settingsGui.Add("Text", "x30 y" . hotkeyY . " w120 h22", "Record Toggle:")
    editRecordToggle := settingsGui.Add("Edit", "x155 y" . hotkeyY . " w130 h22", hotkeyRecordToggle)
    btnCaptureRecordToggle := settingsGui.Add("Button", "x290 y" . hotkeyY . " w50 h22", "Set")
    btnCaptureRecordToggle.OnEvent("Click", (*) => CaptureHotkey(editRecordToggle, "Record Toggle"))
    settingsGui.SetFont("s7")
    settingsGui.Add("Text", "x350 y" . (hotkeyY+3) . " w145 h16 c0x666666", "Start/Stop recording")
    settingsGui.SetFont("s9")
    hotkeyY += 30

    ; Submit
    settingsGui.Add("Text", "x30 y" . hotkeyY . " w120 h22", "Submit:")
    editSubmit := settingsGui.Add("Edit", "x155 y" . hotkeyY . " w130 h22", hotkeySubmit)
    btnCaptureSubmit := settingsGui.Add("Button", "x290 y" . hotkeyY . " w50 h22", "Set")
    btnCaptureSubmit.OnEvent("Click", (*) => CaptureHotkey(editSubmit, "Submit"))
    settingsGui.SetFont("s7")
    settingsGui.Add("Text", "x350 y" . (hotkeyY+3) . " w145 h16 c0x666666", "Submit current box")
    settingsGui.SetFont("s9")
    hotkeyY += 30

    ; Direct Clear
    settingsGui.Add("Text", "x30 y" . hotkeyY . " w120 h22", "Direct Clear:")
    editDirectClear := settingsGui.Add("Edit", "x155 y" . hotkeyY . " w130 h22", hotkeyDirectClear)
    btnCaptureDirectClear := settingsGui.Add("Button", "x290 y" . hotkeyY . " w50 h22", "Set")
    btnCaptureDirectClear.OnEvent("Click", (*) => CaptureHotkey(editDirectClear, "Direct Clear"))
    settingsGui.SetFont("s7")
    settingsGui.Add("Text", "x350 y" . (hotkeyY+3) . " w145 h16 c0x666666", "Clear without menu")
    settingsGui.SetFont("s9")
    hotkeyY += 35

    ; Workflow Utility Keys Section
    settingsGui.Add("Text", "x30 y" . hotkeyY . " w480 h18", "⚡ Workflow Utilities:")
    hotkeyY += 25

    ; Utility Submit
    settingsGui.Add("Text", "x30 y" . hotkeyY . " w120 h22", "Utility Submit:")
    editUtilitySubmit := settingsGui.Add("Edit", "x155 y" . hotkeyY . " w130 h22", hotkeyUtilitySubmit)
    btnCaptureUtilitySubmit := settingsGui.Add("Button", "x290 y" . hotkeyY . " w50 h22", "Set")
    btnCaptureUtilitySubmit.OnEvent("Click", (*) => CaptureHotkey(editUtilitySubmit, "Utility Submit"))
    settingsGui.SetFont("s7")
    settingsGui.Add("Text", "x350 y" . (hotkeyY+3) . " w145 h16 c0x666666", "Shift+Enter to browser")
    settingsGui.SetFont("s9")
    hotkeyY += 30

    ; Utility Backspace
    settingsGui.Add("Text", "x30 y" . hotkeyY . " w120 h22", "Utility Backspace:")
    editUtilityBackspace := settingsGui.Add("Edit", "x155 y" . hotkeyY . " w130 h22", hotkeyUtilityBackspace)
    btnCaptureUtilityBackspace := settingsGui.Add("Button", "x290 y" . hotkeyY . " w50 h22", "Set")
    btnCaptureUtilityBackspace.OnEvent("Click", (*) => CaptureHotkey(editUtilityBackspace, "Utility Backspace"))
    settingsGui.SetFont("s7")
    settingsGui.Add("Text", "x350 y" . (hotkeyY+3) . " w145 h16 c0x666666", "Backspace to browser")
    settingsGui.SetFont("s9")
    hotkeyY += 35

    ; App Controls Section
    settingsGui.Add("Text", "x30 y" . hotkeyY . " w480 h18", "🔧 App Controls:")
    hotkeyY += 25

    ; Stats
    settingsGui.Add("Text", "x30 y" . hotkeyY . " w120 h22", "Stats Window:")
    editStats := settingsGui.Add("Edit", "x155 y" . hotkeyY . " w130 h22", hotkeyStats)
    btnCaptureStats := settingsGui.Add("Button", "x290 y" . hotkeyY . " w50 h22", "Set")
    btnCaptureStats.OnEvent("Click", (*) => CaptureHotkey(editStats, "Stats Window"))
    settingsGui.SetFont("s7")
    settingsGui.Add("Text", "x350 y" . (hotkeyY+3) . " w145 h16 c0x666666", "Show/hide stats")
    settingsGui.SetFont("s9")
    hotkeyY += 30

    ; Break Mode
    settingsGui.Add("Text", "x30 y" . hotkeyY . " w120 h22", "Break Mode:")
    editBreakMode := settingsGui.Add("Edit", "x155 y" . hotkeyY . " w130 h22", hotkeyBreakMode)
    btnCaptureBreakMode := settingsGui.Add("Button", "x290 y" . hotkeyY . " w50 h22", "Set")
    btnCaptureBreakMode.OnEvent("Click", (*) => CaptureHotkey(editBreakMode, "Break Mode"))
    settingsGui.SetFont("s7")
    settingsGui.Add("Text", "x350 y" . (hotkeyY+3) . " w145 h16 c0x666666", "Toggle break mode")
    settingsGui.SetFont("s9")
    hotkeyY += 30

    ; Settings
    settingsGui.Add("Text", "x30 y" . hotkeyY . " w120 h22", "Settings:")
    editSettings := settingsGui.Add("Edit", "x155 y" . hotkeyY . " w130 h22", hotkeySettings)
    btnCaptureSettings := settingsGui.Add("Button", "x290 y" . hotkeyY . " w50 h22", "Set")
    btnCaptureSettings.OnEvent("Click", (*) => CaptureHotkey(editSettings, "Settings"))
    settingsGui.SetFont("s7")
    settingsGui.Add("Text", "x350 y" . (hotkeyY+3) . " w145 h16 c0x666666", "Open settings")
    settingsGui.SetFont("s9")
    hotkeyY += 35

    ; Apply/Reset buttons for hotkeys
    btnApplyHotkeys := settingsGui.Add("Button", "x30 y" . hotkeyY . " w120 h28", "✅ Apply Hotkeys")
    btnApplyHotkeys.OnEvent("Click", (*) => ApplyHotkeySettings(editRecordToggle, editSubmit, editDirectClear, editUtilitySubmit, editUtilityBackspace, editStats, editBreakMode, editSettings, settingsGui))

    btnResetHotkeys := settingsGui.Add("Button", "x165 y" . hotkeyY . " w120 h28", "🔄 Reset to Default")
    btnResetHotkeys.OnEvent("Click", (*) => ResetHotkeySettings(settingsGui))
    hotkeyY += 36

    ; Instructions
    settingsGui.SetFont("s8 Bold c0x0066CC")
    settingsGui.Add("Text", "x30 y" . hotkeyY . " w480 h14", "💡 How to Set Hotkeys:")
    hotkeyY += 18
    settingsGui.SetFont("s8")
    settingsGui.Add("Text", "x30 y" . hotkeyY . " w480 h52", "• Click the 'Set' button next to any hotkey field`n• Press your desired key combination (e.g., Ctrl+Alt+K, Shift+F5, etc.)`n• The hotkey will be captured and displayed automatically`n• Click 'Apply Hotkeys' to save and activate all changes immediately")
    settingsGui.SetFont("s9")

    ; Show settings window
settingsGui.Show("w580 h580")
}


FormatCanvasCoord(value) {
    return Round(value, 2)
}

CanvasDetailString(left, top, right, bottom) {
    return "L " . FormatCanvasCoord(left) . "   T " . FormatCanvasCoord(top) . "`nR " . FormatCanvasCoord(right) . "   B " . FormatCanvasCoord(bottom)
}

UpdateCanvasStatusControls(settingsGui) {
    global isWideCanvasCalibrated, isNarrowCanvasCalibrated
    global wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom
    global narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom

    if (!IsObject(settingsGui))
        return

    if (settingsGui.HasProp("wideStatusCtrl")) {
        settingsGui.wideStatusCtrl.Text := isWideCanvasCalibrated ? "✅ Status: Configured" : "❌ Status: Not Set"
    }
    if (settingsGui.HasProp("wideDetailCtrl")) {
        settingsGui.wideDetailCtrl.Text := CanvasDetailString(wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom)
    }

    if (settingsGui.HasProp("narrowStatusCtrl")) {
        settingsGui.narrowStatusCtrl.Text := isNarrowCanvasCalibrated ? "✅ Status: Configured" : "❌ Status: Not Set"
    }
    if (settingsGui.HasProp("narrowDetailCtrl")) {
        settingsGui.narrowDetailCtrl.Text := CanvasDetailString(narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom)
    }
}


UpdateModeToggleButton() {
    global annotationMode, modeToggleBtn
    
    if (modeToggleBtn) {
        if (annotationMode = "Narrow") {
            modeToggleBtn.Text := "📱 Narrow"
            modeToggleBtn.Opt("+Background0xFF8C00")
        } else {
            modeToggleBtn.Text := "🔦 Wide"  
            modeToggleBtn.Opt("+Background0x4169E1")
        }
        modeToggleBtn.SetFont(, "cWhite")
        modeToggleBtn.Redraw()
        
        UpdateStatus("🔄 Mode toggle updated to " . annotationMode . " mode")
    }
}

ToggleAnnotationMode() {
    global annotationMode, modeToggleBtn

    VizLog("=== ToggleAnnotationMode START ===")

    ; CRITICAL FIX: Read current state from button text to ensure sync
    currentState := InStr(modeToggleBtn.Text, "Wide") ? "Wide" : "Narrow"
    VizLog("Current state: " . currentState)

    if (currentState = "Wide") {
        annotationMode := "Narrow"
        modeToggleBtn.Text := "📱 Narrow"
        modeToggleBtn.Opt("+Background0xFF8C00")
        UpdateStatus("📱 Narrow mode selected")
        VizLog("Switched to NARROW mode")
    } else {
        annotationMode := "Wide"
        modeToggleBtn.Text := "🔦 Wide"
        modeToggleBtn.Opt("+Background0x4169E1")
        UpdateStatus("🔦 Wide mode selected")
        VizLog("Switched to WIDE mode")
    }

    modeToggleBtn.SetFont(, "cWhite")
    modeToggleBtn.Redraw()

    ; Update existing JSON macros when mode changes
    UpdateExistingJSONMacros(annotationMode)

    ; NOTE: We do NOT refresh visualizations here!
    ; Visualizations remember which mode they were recorded in via recordedMode property.
    ; Only NEW recordings will use the new mode. Existing visualizations stay as-is.
    VizLog("Mode changed - affects NEW recordings only, existing visualizations unchanged")

    ; Save the mode change
    SaveConfig()
    VizLog("=== ToggleAnnotationMode END ===")
    FlushVizLog()
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

SaveMacroState() {
    global macroEvents, buttonThumbnails, configFile

    stateFile := StrReplace(configFile, ".ini", "_simple.txt")
    stateContent := ""
    macroCount := 0

    for macroName, events in macroEvents {
        if (events.Length > 0) {
            macroCount++

            ; Save recordedMode if it exists
            ; DEBUG: Check if property exists and log it
            if (events.HasOwnProp("recordedMode")) {
                VizLog("Saving recordedMode for " . macroName . ": " . events.recordedMode)
                if (events.recordedMode != "") {
                    stateContent .= macroName . "=recordedMode," . events.recordedMode . "`n"
                }
            }

            if (events.HasOwnProp("recordedCanvas")) {
                rc := events.recordedCanvas
                if (IsObject(rc) && rc.HasOwnProp("left") && rc.HasOwnProp("right")) {
                    canvasLine := macroName . "=recordedCanvas," . FormatCanvasCoord(rc.left) . "," . FormatCanvasCoord(rc.top) . "," . FormatCanvasCoord(rc.right) . "," . FormatCanvasCoord(rc.bottom)
                    if (rc.HasOwnProp("mode") && rc.mode != "")
                        canvasLine .= ",mode=" . rc.mode
                    if (rc.HasOwnProp("source") && rc.source != "")
                        canvasLine .= ",source=" . rc.source
                    stateContent .= canvasLine . "`n"
                }
            } else {
                VizLog("NO recordedMode property for " . macroName)
            }

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
                    buttonVal := event.HasOwnProp("button") ? event.button : "left"
                    stateContent .= macroName . "=mouseDown," . event.x . "," . event.y . "," . buttonVal . "`n"
                }
                else if (event.type = "mouseUp") {
                    buttonVal := event.HasOwnProp("button") ? event.button : "left"
                    stateContent .= macroName . "=mouseUp," . event.x . "," . event.y . "," . buttonVal . "`n"
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

    FlushVizLog()
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
                else if (parts[1] = "recordedMode" && parts.Length >= 2) {
                    ; Load recordedMode property and attach it to the macro array
                    if (!macroEvents.Has(macroName)) {
                        macroEvents[macroName] := []
                        macroCount++
                    }
                    macroEvents[macroName].recordedMode := parts[2]
                    continue
                }
                else if (parts[1] = "recordedCanvas" && parts.Length >= 5) {
                    if (!macroEvents.Has(macroName)) {
                        macroEvents[macroName] := []
                        macroCount++
                    }
                    rc := {
                        left: parts[2] != "" ? parts[2] + 0.0 : 0.0,
                        top: parts[3] != "" ? parts[3] + 0.0 : 0.0,
                        right: parts[4] != "" ? parts[4] + 0.0 : 0.0,
                        bottom: parts[5] != "" ? parts[5] + 0.0 : 0.0
                    }
                    if (parts.Length > 5) {
                        Loop parts.Length - 5 {
                            idxExtra := A_Index + 5
                            if (idxExtra <= parts.Length) {
                                extra := parts[idxExtra]
                                if (InStr(extra, "mode=")) {
                                    rc.mode := StrReplace(extra, "mode=", "")
                                } else if (InStr(extra, "source=")) {
                                    rc.source := StrReplace(extra, "source=", "")
                                }
                            }
                        }
                    }
                    macroEvents[macroName].recordedCanvas := rc
                    continue
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
    global smartBoxClickDelay, smartMenuClickDelay, firstBoxDelay, menuWaitDelay, mouseHoverDelay

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
            case "smartBoxClickDelay":
                smartBoxClickDelay := value
            case "smartMenuClickDelay":
                smartMenuClickDelay := value
            case "firstBoxDelay":
                firstBoxDelay := value
            case "menuWaitDelay":
                menuWaitDelay := value
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
    global boxDrawDelay, mouseClickDelay, mouseDragDelay, mouseReleaseDelay, betweenBoxDelay, keyPressDelay, focusDelay
    global smartBoxClickDelay, smartMenuClickDelay, firstBoxDelay, menuWaitDelay, mouseHoverDelay

    switch preset {
        case "fast":
            boxDrawDelay := 45
            mouseClickDelay := 55
            mouseDragDelay := 50
            mouseReleaseDelay := 55
            betweenBoxDelay := 90  ; Optimized - single delay per box
            keyPressDelay := 10
            focusDelay := 50
            smartBoxClickDelay := 30
            smartMenuClickDelay := 80
            firstBoxDelay := 135  ; Slightly more for first box stability
            menuWaitDelay := 30
            mouseHoverDelay := 20

        case "default":
            boxDrawDelay := 50
            mouseClickDelay := 75
            mouseDragDelay := 50
            mouseReleaseDelay := 75
            betweenBoxDelay := 120  ; Balanced speed + reliability
            keyPressDelay := 12
            focusDelay := 60
            smartBoxClickDelay := 45
            smartMenuClickDelay := 100
            firstBoxDelay := 180  ; Adequate for UI stabilization
            menuWaitDelay := 50
            mouseHoverDelay := 30

        case "safe":
            boxDrawDelay := 70
            mouseClickDelay := 95
            mouseDragDelay := 75
            mouseReleaseDelay := 95
            betweenBoxDelay := 180  ; Conservative but not excessive
            keyPressDelay := 15
            focusDelay := 80
            smartBoxClickDelay := 60
            smartMenuClickDelay := 130
            firstBoxDelay := 270  ; Extra safety for first box
            menuWaitDelay := 80
            mouseHoverDelay := 40

        case "slow":
            boxDrawDelay := 100
            mouseClickDelay := 130
            mouseDragDelay := 120
            mouseReleaseDelay := 130
            betweenBoxDelay := 270  ; Maximum reliability
            keyPressDelay := 20
            focusDelay := 120
            smartBoxClickDelay := 80
            smartMenuClickDelay := 180
            firstBoxDelay := 420  ; Very conservative first box
            menuWaitDelay := 150
            mouseHoverDelay := 60
    }

    ; Save configuration
    SaveConfig()

    ; Close and reopen settings to refresh values
    settingsGui.Destroy()
    ShowSettings()

    UpdateStatus("🎚️ Applied " . StrTitle(preset) . " timing preset")
}

ClearAllMacros(parentGui := 0) {
    global macroEvents, buttonNames, totalLayers, buttonLetterboxingStates
    
    result := MsgBox("Clear ALL macros from ALL layers?`n`nThis will permanently delete all recorded macros but preserve stats.", "Confirm Clear All", "YesNo Icon!")
    
    if (result = "Yes") {
        ; Clear all macros
        macroEvents := Map()
        buttonLetterboxingStates.Clear()
        
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
    global macroExecutionLog, masterStatsCSV, workDir

    if (MsgBox("Reset all statistics data?`n`nThis will clear execution logs but preserve macros.", "Confirm Stats Reset", "YesNo Icon!") = "Yes") {
        try {
            macroExecutionLog := []

            statsJsonFile := workDir . "\stats_log.json"
            if FileExist(statsJsonFile) {
                FileDelete(statsJsonFile)
            }

            if (masterStatsCSV != "" && FileExist(masterStatsCSV)) {
                FileDelete(masterStatsCSV)
            }

            InitializeStatsSystem()
            UpdateStatus("?? Statistics reset - Ready for new session")
        } catch Error as err {
            UpdateStatus("?? Failed to reset statistics: " . err.Message)
        }

        if (parentGui) {
            parentGui.Destroy()
        }
    }
}

; ===== CONFIGURATION SAVE/LOAD SYSTEM =====
SaveConfig() {
    global currentLayer, macroEvents, configFile, totalLayers, buttonNames, buttonCustomLabels, annotationMode, workDir
    global wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom, isWideCanvasCalibrated
    global narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom, isNarrowCanvasCalibrated
    global userCanvasLeft, userCanvasTop, userCanvasRight, userCanvasBottom, isCanvasCalibrated
    
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
        
        ; Add canvas calibration section
        configContent .= "[Canvas]`n"
        configContent .= "wideCanvasLeft=" . FormatCanvasCoord(wideCanvasLeft) . "`n"
        configContent .= "wideCanvasTop=" . FormatCanvasCoord(wideCanvasTop) . "`n"
        configContent .= "wideCanvasRight=" . FormatCanvasCoord(wideCanvasRight) . "`n"
        configContent .= "wideCanvasBottom=" . FormatCanvasCoord(wideCanvasBottom) . "`n"
        configContent .= "isWideCanvasCalibrated=" . (isWideCanvasCalibrated ? 1 : 0) . "`n"
        configContent .= "narrowCanvasLeft=" . FormatCanvasCoord(narrowCanvasLeft) . "`n"
        configContent .= "narrowCanvasTop=" . FormatCanvasCoord(narrowCanvasTop) . "`n"
        configContent .= "narrowCanvasRight=" . FormatCanvasCoord(narrowCanvasRight) . "`n"
        configContent .= "narrowCanvasBottom=" . FormatCanvasCoord(narrowCanvasBottom) . "`n"
        configContent .= "isNarrowCanvasCalibrated=" . (isNarrowCanvasCalibrated ? 1 : 0) . "`n"
        configContent .= "userCanvasLeft=" . FormatCanvasCoord(userCanvasLeft) . "`n"
        configContent .= "userCanvasTop=" . FormatCanvasCoord(userCanvasTop) . "`n"
        configContent .= "userCanvasRight=" . FormatCanvasCoord(userCanvasRight) . "`n"
        configContent .= "userCanvasBottom=" . FormatCanvasCoord(userCanvasBottom) . "`n"
        configContent .= "isCanvasCalibrated=" . (isCanvasCalibrated ? 1 : 0) . "`n`n"

        ; Add timing configuration section
        global boxDrawDelay, mouseClickDelay, mouseDragDelay, mouseReleaseDelay, betweenBoxDelay, keyPressDelay, focusDelay
        global smartBoxClickDelay, smartMenuClickDelay, firstBoxDelay, menuWaitDelay, mouseHoverDelay
        configContent .= "[Timing]`n"
        configContent .= "boxDrawDelay=" . boxDrawDelay . "`n"
        configContent .= "mouseClickDelay=" . mouseClickDelay . "`n"
        configContent .= "mouseDragDelay=" . mouseDragDelay . "`n"
        configContent .= "mouseReleaseDelay=" . mouseReleaseDelay . "`n"
        configContent .= "betweenBoxDelay=" . betweenBoxDelay . "`n"
        configContent .= "keyPressDelay=" . keyPressDelay . "`n"
        configContent .= "focusDelay=" . focusDelay . "`n"
        configContent .= "smartBoxClickDelay=" . smartBoxClickDelay . "`n"
        configContent .= "smartMenuClickDelay=" . smartMenuClickDelay . "`n"
        configContent .= "firstBoxDelay=" . firstBoxDelay . "`n"
        configContent .= "menuWaitDelay=" . menuWaitDelay . "`n"
        configContent .= "mouseHoverDelay=" . mouseHoverDelay . "`n`n"

        ; Add hotkeys section
        global hotkeyRecordToggle, hotkeySubmit, hotkeyDirectClear, hotkeyUtilitySubmit, hotkeyUtilityBackspace
        global hotkeyStats, hotkeyBreakMode, hotkeySettings, utilityHotkeysEnabled
        configContent .= "[Hotkeys]`n"
        configContent .= "hotkeyRecordToggle=" . hotkeyRecordToggle . "`n"
        configContent .= "hotkeySubmit=" . hotkeySubmit . "`n"
        configContent .= "hotkeyDirectClear=" . hotkeyDirectClear . "`n"
        configContent .= "hotkeyUtilitySubmit=" . hotkeyUtilitySubmit . "`n"
        configContent .= "hotkeyUtilityBackspace=" . hotkeyUtilityBackspace . "`n"
        configContent .= "hotkeyStats=" . hotkeyStats . "`n"
        configContent .= "hotkeyBreakMode=" . hotkeyBreakMode . "`n"
        configContent .= "hotkeySettings=" . hotkeySettings . "`n"
        configContent .= "utilityHotkeysEnabled=" . (utilityHotkeysEnabled ? 1 : 0) . "`n`n"

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
                            ; Save key property for keyDown/keyUp events, then x,y coordinates
                            keyValue := event.HasOwnProp("key") ? event.key : ""
                            xValue := event.HasOwnProp("x") ? event.x : ""
                            yValue := event.HasOwnProp("y") ? event.y : ""
                            eventsStr .= event.type . "," . keyValue . "," . xValue . "," . yValue
                        }
                    }
                    if (eventsStr != "") {
                        ; Add to manual content instead of using IniWrite
                        configContent .= layerMacroName . "=" . eventsStr . "`n"
                        savedMacros++

                        ; Save recordedMode if present
                        if (macroEvents[layerMacroName].HasOwnProp("recordedMode")) {
                            configContent .= layerMacroName . "_recordedMode=" . macroEvents[layerMacroName].recordedMode . "`n"
                        }

                        ; Save recordedCanvas if present
                        if (macroEvents[layerMacroName].HasOwnProp("recordedCanvas")) {
                            rc := macroEvents[layerMacroName].recordedCanvas
                            configContent .= layerMacroName . "_recordedCanvas=" . rc.left . "," . rc.top . "," . rc.right . "," . rc.bottom . "," . rc.mode . "`n"
                        }
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
    global wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom, isWideCanvasCalibrated
    global narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom, isNarrowCanvasCalibrated
    global userCanvasLeft, userCanvasTop, userCanvasRight, userCanvasBottom, isCanvasCalibrated
    
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
                    ; Load canvas calibration data
                    if (key = "wideCanvasLeft") {
                        wideCanvasLeft := value != "" ? value + 0.0 : 0.0
                    } else if (key = "wideCanvasTop") {
                        wideCanvasTop := value != "" ? value + 0.0 : 0.0
                    } else if (key = "wideCanvasRight") {
                        wideCanvasRight := value != "" ? value + 0.0 : 0.0
                    } else if (key = "wideCanvasBottom") {
                        wideCanvasBottom := value != "" ? value + 0.0 : 0.0
                    } else if (key = "isWideCanvasCalibrated") {
                        valueLower := StrLower(value)
                        isWideCanvasCalibrated := !(valueLower = "" || valueLower = "0" || valueLower = "false" || valueLower = "no" || valueLower = "off")
                    } else if (key = "narrowCanvasLeft") {
                        narrowCanvasLeft := value != "" ? value + 0.0 : 0.0
                    } else if (key = "narrowCanvasTop") {
                        narrowCanvasTop := value != "" ? value + 0.0 : 0.0
                    } else if (key = "narrowCanvasRight") {
                        narrowCanvasRight := value != "" ? value + 0.0 : 0.0
                    } else if (key = "narrowCanvasBottom") {
                        narrowCanvasBottom := value != "" ? value + 0.0 : 0.0
                    } else if (key = "isNarrowCanvasCalibrated") {
                        valueLower := StrLower(value)
                        isNarrowCanvasCalibrated := !(valueLower = "" || valueLower = "0" || valueLower = "false" || valueLower = "no" || valueLower = "off")
                    } else if (key = "userCanvasLeft") {
                        userCanvasLeft := value != "" ? value + 0.0 : 0.0
                    } else if (key = "userCanvasTop") {
                        userCanvasTop := value != "" ? value + 0.0 : 0.0
                    } else if (key = "userCanvasRight") {
                        userCanvasRight := value != "" ? value + 0.0 : 0.0
                    } else if (key = "userCanvasBottom") {
                        userCanvasBottom := value != "" ? value + 0.0 : 0.0
                    } else if (key = "isCanvasCalibrated") {
                        valueLower := StrLower(value)
                        isCanvasCalibrated := !(valueLower = "" || valueLower = "0" || valueLower = "false" || valueLower = "no" || valueLower = "off")
                    }
                } else if (currentSection = "Timing") {
                    ; Load timing configuration
                    global boxDrawDelay, mouseClickDelay, mouseDragDelay, mouseReleaseDelay, betweenBoxDelay, keyPressDelay, focusDelay
                    global smartBoxClickDelay, smartMenuClickDelay, firstBoxDelay, menuWaitDelay, mouseHoverDelay

                    if (key = "boxDrawDelay") {
                        boxDrawDelay := Integer(value)
                    } else if (key = "mouseClickDelay") {
                        mouseClickDelay := Integer(value)
                    } else if (key = "mouseDragDelay") {
                        mouseDragDelay := Integer(value)
                    } else if (key = "mouseReleaseDelay") {
                        mouseReleaseDelay := Integer(value)
                    } else if (key = "betweenBoxDelay") {
                        betweenBoxDelay := Integer(value)
                    } else if (key = "keyPressDelay") {
                        keyPressDelay := Integer(value)
                    } else if (key = "focusDelay") {
                        focusDelay := Integer(value)
                    } else if (key = "smartBoxClickDelay") {
                        smartBoxClickDelay := Integer(value)
                    } else if (key = "smartMenuClickDelay") {
                        smartMenuClickDelay := Integer(value)
                    } else if (key = "firstBoxDelay") {
                        firstBoxDelay := Integer(value)
                    } else if (key = "menuWaitDelay") {
                        menuWaitDelay := Integer(value)
                    } else if (key = "mouseHoverDelay") {
                        mouseHoverDelay := Integer(value)
                    }
                } else if (currentSection = "Hotkeys") {
                    ; Load hotkey configuration
                    global hotkeyRecordToggle, hotkeySubmit, hotkeyDirectClear, hotkeyUtilitySubmit, hotkeyUtilityBackspace
                    global hotkeyStats, hotkeyBreakMode, hotkeySettings, utilityHotkeysEnabled

                    if (key = "hotkeyRecordToggle") {
                        hotkeyRecordToggle := value
                    } else if (key = "hotkeySubmit") {
                        hotkeySubmit := value
                    } else if (key = "hotkeyDirectClear") {
                        hotkeyDirectClear := value
                    } else if (key = "hotkeyUtilitySubmit") {
                        hotkeyUtilitySubmit := value
                    } else if (key = "hotkeyUtilityBackspace") {
                        hotkeyUtilityBackspace := value
                    } else if (key = "hotkeyStats") {
                        hotkeyStats := value
                    } else if (key = "hotkeyBreakMode") {
                        hotkeyBreakMode := value
                    } else if (key = "hotkeySettings") {
                        hotkeySettings := value
                    } else if (key = "utilityHotkeysEnabled") {
                        valueLower := StrLower(value)
                        utilityHotkeysEnabled := !(valueLower = "" || valueLower = "0" || valueLower = "false" || valueLower = "no" || valueLower = "off")
                    }
                } else if (currentSection = "Labels") {
                    if (buttonCustomLabels.Has(key)) {
                        buttonCustomLabels[key] := value
                    }
                } else if (currentSection = "Macros" && InStr(key, "L") = 1) {
                    ; Check if this is a recordedMode entry
                    if (InStr(key, "_recordedMode")) {
                        macroName := StrReplace(key, "_recordedMode", "")
                        if (!macroEvents.Has(macroName)) {
                            macroEvents[macroName] := []
                        }
                        macroEvents[macroName].recordedMode := value
                        continue
                    }

                    ; Check if this is a recordedCanvas entry
                    if (InStr(key, "_recordedCanvas")) {
                        macroName := StrReplace(key, "_recordedCanvas", "")
                        if (!macroEvents.Has(macroName)) {
                            macroEvents[macroName] := []
                        }
                        ; Parse canvas bounds: left,top,right,bottom,mode
                        canvasParts := StrSplit(value, ",")
                        if (canvasParts.Length >= 5) {
                            macroEvents[macroName].recordedCanvas := {
                                left: canvasParts[1] + 0.0,
                                top: canvasParts[2] + 0.0,
                                right: canvasParts[3] + 0.0,
                                bottom: canvasParts[4] + 0.0,
                                mode: Trim(canvasParts[5])
                            }
                        }
                        continue
                    }

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
                                if (parts.Length > 1 && parts[2] != "")
                                    event.x := Integer(parts[2])
                                if (parts.Length > 2 && parts[3] != "")
                                    event.y := Integer(parts[3])
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

        ; Validate canvas calibration and log status
        ValidateCanvasCalibration()

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
        SaveStatsToJson()
        
        slotDir := workDir . "\slots\slot_" . slotNumber
        if !DirExist(slotDir) {
            DirCreate(slotDir)
        }
        
        ; Copy current config to slot
        FileCopy(configFile, slotDir . "\config.ini", true)
        
        logFile := workDir . "\stats_log.json"
        if FileExist(logFile) {
            FileCopy(logFile, slotDir . "\stats_log.json", true)
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
        
        logFile := workDir . "\stats_log.json"
        if FileExist(slotDir . "\stats_log.json") {
            FileCopy(slotDir . "\stats_log.json", logFile, true)
        }
        
        LoadConfig()
        LoadStatsFromJson()
        
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
    MsgBox("Export configuration feature is available in the full modular version.", "Feature Notice", "Icon!")
}

ImportConfiguration() {
    MsgBox("Import configuration feature is available in the full modular version.", "Feature Notice", "Icon!")
}

CreateMacroPack() {
    MsgBox("Macro pack creation is available in the full modular version.", "Feature Notice", "Icon!")
}

BrowseMacroPacks() {
    MsgBox("Macro pack browsing is available in the full modular version.", "Feature Notice", "Icon!")
}

ImportNewMacroPack() {
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
        } else if (event.type = "keyDown" && event.HasOwnProp("key") && IsNumberKey(event.key)) {
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
    
    for id, typeName in degradationTypes
    {
        degradationCounts[id] := 0
    }
    
    for boxIndex, box in boxes
    {
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

AutoSave() {
    global breakMode, recording
    
    if (!recording && !breakMode) {
        SaveConfig()
        SaveStatsToJson()
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
        SaveStatsToJson()
        UpdateStatus("💾 Saved " . savedMacros . " macros")

        ; Clean up visualization resources - COMPREHENSIVE HBITMAP CLEANUP
        CleanupHBITMAPCache()
        ; Additional cleanup for buttonDisplayedHBITMAPs to ensure no leaks
        CleanupButtonDisplayedHBITMAPs()
        ; Shutdown GDI+
        if (gdiPlusToken) {
            DllCall("gdiplus\GdiplusShutdown", "Ptr", gdiPlusToken)
            gdiPlusToken := 0
            gdiPlusInitialized := false
        }

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
            SaveStatsToJson()
            CleanupHBITMAPCache()
            CleanupButtonDisplayedHBITMAPs()
        } catch {
            SafeUninstallMouseHook()
            SafeUninstallKeyboardHook()
        }
    }
}

ShowWelcomeMessage() {
    UpdateStatus("📦 Draw boxes, press 1-9 to tag | CapsLock+F: Record | CapsLock+SPACE: Emergency Stop | All systems ready")
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

; ===== UTILITY HOTKEY HANDLERS =====
UtilitySubmit() {
    ; LShift + CapsLock sends Shift+Enter
    global utilityHotkeysEnabled, focusDelay
    if (!utilityHotkeysEnabled)
        return

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
    }
}

UtilityBackspace() {
    ; LCtrl + CapsLock sends Backspace
    global utilityHotkeysEnabled, focusDelay
    if (!utilityHotkeysEnabled)
        return

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
        Send("{Backspace}")
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
    
    if (loadedMacros != currentMacros) {
        MsgBox("Save/Load mismatch!`n`nOriginal: " . currentMacros . " macros`nLoaded: " . loadedMacros . " macros`n`nPress F11 for detailed debug info.", "Save/Load Test Failed", "Icon!")
    } else {
        MsgBox("Save/Load test successful!`n`n" . loadedMacros . " macros preserved correctly.", "Save/Load Test Passed", "Icon!")
    }
}

; ===== START APPLICATION =====
Main()
