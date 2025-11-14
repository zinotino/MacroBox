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
  - Condition type tracking (9 customizable condition types)
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
    if (valueType == "Integer" || valueType == "Float")
        return String(value)

    ; Now safe to check booleans (only true booleans, not coerced numbers)
    if (value == true)
        return "true"
    if (value == false)
        return "false"
    if (valueType == "ComValue")
        return "null"

    if (valueType == "Map") {
        items := []
        for key, itemValue in value {
            keyText := ObjToString(String(key))
            items.Push(keyText . ":" . ObjToString(itemValue))
        }
        return "{" . StrJoin(items, ",") . "}"
    }

    if (valueType == "Array") {
        items := []
        for element in value {
            items.Push(ObjToString(element))
        }
        return "[" . StrJoin(items, ",") . "]"
    }

    if (valueType == "String") {
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
    if (char == "{")
        return Jxon_ParseObject(text, &pos)
    if (char == "[")
        return Jxon_ParseArray(text, &pos)
    if (char == Chr(34))
        return Jxon_ParseString(text, &pos)
    if (SubStr(text, pos, 4) == "null") {
        pos += 4
        return ""
    }
    if (SubStr(text, pos, 4) == "true") {
        pos += 4
        return true
    }
    if (SubStr(text, pos, 5) == "false") {
        pos += 5
        return false
    }
    return Jxon_ParseNumber(text, &pos)
}

Jxon_ParseObject(text, &pos) {
    obj := Map()
    pos += 1
    Jxon_SkipWhitespace(text, &pos)
    if (SubStr(text, pos, 1) == "}") {
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
        if (char == "}") {
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
    if (SubStr(text, pos, 1) == "]") {
        pos += 1
        return arr
    }

    while true {
        value := Jxon_ParseValue(text, &pos)
        arr.Push(value)
        Jxon_SkipWhitespace(text, &pos)
        char := SubStr(text, pos, 1)
        if (char == "]") {
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
        if (char == quote) {
            result .= SubStr(text, start, pos - start)
            pos += 1
            break
        }

        if (char == backslash) {
            result .= SubStr(text, start, pos - start)
            pos += 1
            if (pos > StrLen(text))
                throw Error("Unexpected end of string")

            escapeChar := SubStr(text, pos, 1)
            if (escapeChar == quote)
                result .= quote
            else if (escapeChar == backslash)
                result .= backslash
            else if (escapeChar == "n")
                result .= "`n"
            else if (escapeChar == "r")
                result .= "`r"
            else if (escapeChar == "t")
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
        if (code == 9)
            result .= backslash . "t"
        else if (code == 10)
            result .= backslash . "n"
        else if (code == 13)
            result .= backslash . "r"
        else if (code == 34)
            result .= backslash . Chr(34)
        else if (code == 92)
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
; startupPhase gating removed to ensure full visuals render at startup
global statusBar := 0
global layerIndicator := 0
global modeToggleBtn := 0
global recording := false
global playback := false
global awaitingAssignment := false
global needsMacroStateSave := false
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

; ===== CONDITION TRACKING =====
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

; ===== CONDITION CONFIGURATION SYSTEM =====
; Centralized condition configuration
; Each condition has: name (internal), displayName (UI), color (hex), statKey (for CSV/stats)

; Factory defaults - single source of truth
GetDefaultConditionConfig() {
    return Map(
        1, {name: "condition_1",  displayName: "Condition 1",  color: "0xFF8C00", statKey: "condition_1"},
        2, {name: "condition_2",  displayName: "Condition 2",  color: "0xFFFF00", statKey: "condition_2"},
        3, {name: "condition_3",  displayName: "Condition 3",  color: "0x9932CC", statKey: "condition_3"},
        4, {name: "condition_4",  displayName: "Condition 4",  color: "0x32CD32", statKey: "condition_4"},
        5, {name: "condition_5",  displayName: "Condition 5",  color: "0x8B0000", statKey: "condition_5"},
        6, {name: "condition_6",  displayName: "Condition 6",  color: "0xFF0000", statKey: "condition_6"},
        7, {name: "condition_7",  displayName: "Condition 7",  color: "0xFF4500", statKey: "condition_7"},
        8, {name: "condition_8",  displayName: "Condition 8",  color: "0xADFF2F", statKey: "condition_8"},
        9, {name: "condition_9",  displayName: "Condition 9",  color: "0x00FFFF", statKey: "condition_9"}
    )
}

global conditionConfig := GetDefaultConditionConfig()

; Legacy name compatibility (old -> id)
; Supports older logs/inputs that used named conditions or labelN
global legacyConditionNameToId := Map(
    "smudge", 1,
    "glare", 2,
    "splashes", 3,
    "partial_blockage", 4,
    "full_blockage", 5,
    "light_flare", 6,
    "flare", 6,
    "rain", 7,
    "haze", 8,
    "snow", 9,
    "label1", 1,
    "label2", 2,
    "label3", 3,
    "label4", 4,
    "label5", 5,
    "label6", 6,
    "label7", 7,
    "label8", 8,
    "label9", 9,
    "clear", 0
)

; Legacy per-id count field names used in older executionData
global legacyConditionCountFieldById := Map(
    1, "smudge_count",
    2, "glare_count",
    3, "splashes_count",
    4, "partial_blockage_count",
    5, "full_blockage_count",
    6, "light_flare_count",
    7, "rain_count",
    8, "haze_count",
    9, "snow_count"
)

; Legacy Maps for backward compatibility (these reference conditionConfig)
global conditionTypes := Map(
    1, "smudge", 2, "glare", 3, "splashes", 4, "partial_blockage", 5, "full_blockage",
    6, "light_flare", 7, "rain", 8, "haze", 9, "snow"
)

global conditionColors := Map(
    1, "0xFF8C00",    ; label1 - orange
    2, "0xFFFF00",    ; label2 - yellow
    3, "0x9932CC",    ; label3 - purple
    4, "0x32CD32",    ; label4 - green
    5, "0x8B0000",    ; label5 - dark red
    6, "0xFF0000",    ; label6 - red
    7, "0xFF4500",    ; label7 - dark orange
    8, "0xADFF2F",    ; label8 - yellow-green
    9, "0x00FFFF"     ; label9 - cyan
)

; ===== CONDITION HELPER FUNCTIONS =====
GetConditionName(id) {
    if conditionConfig.Has(id)
        return conditionConfig[id].name
    return ""
}

GetConditionDisplayName(id) {
    if conditionConfig.Has(id)
        return conditionConfig[id].displayName
    return ""
}

GetConditionColor(id) {
    if conditionConfig.Has(id)
        return conditionConfig[id].color
    return "0xFFFFFF"  ; Default white if not found
}

GetConditionStatKey(id) {
    if conditionConfig.Has(id)
        return conditionConfig[id].statKey
    return ""
}

; Get condition ID from name (reverse lookup)
GetConditionIdByName(name) {
    for id, config in conditionConfig {
        if (config.name = name)
            return id
    }
    return 0
}

; Sync legacy Maps with conditionConfig (call after config changes)
SyncLegacyConditionMaps() {
    global conditionTypes, conditionColors, conditionConfig

    conditionTypes := Map()
    conditionColors := Map()

    for id, config in conditionConfig {
        conditionTypes[id] := config.name
        conditionColors[id] := config.color
    }
}

; Initialize legacy maps on startup
SyncLegacyConditionMaps()

; Validate hex color code
ValidateHexColor(colorStr) {
    ; Must match format: 0xRRGGBB (case insensitive)
    if (!RegExMatch(colorStr, "^0x[0-9A-Fa-f]{6}$"))
        return false
    return true
}

; Validate condition name (no special chars, reasonable length)
ValidateConditionName(name) {
    ; Must be 1-30 chars, alphanumeric, underscore, hyphen, space allowed
    if (!RegExMatch(name, "^[A-Za-z0-9_\- ]{1,30}$"))
        return false
    return true
}

; Reset condition definitions to factory defaults
ResetConditionToDefault(id) {
    global conditionConfig

    defaults := GetDefaultConditionConfig()

    if (defaults.Has(id)) {
        ; Create a copy of the default object to avoid reference issues
        conditionConfig[id] := {
            name: defaults[id].name,
            displayName: defaults[id].displayName,
            color: defaults[id].color,
            statKey: defaults[id].statKey
        }
        return true
    }
    return false
}

; Reset all conditions to factory defaults
ResetAllConditionsToDefaults() {
    Loop 9 {
        ResetConditionToDefault(A_Index)
    }
    SyncLegacyConditionMaps()
}

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
if (result == "Yes") {
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
if (result == "Yes") {
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

    if (result == "Cancel") {
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

    if (canvasH == 0) {
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

    if (result == "No") {
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

    if (result == "Cancel") {
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

    if (canvasH == 0) {
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

    if (result == "No") {
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

; ===== FIRST LAUNCH WIZARD =====
ShowFirstLaunchWizard() {
    global isWideCanvasCalibrated, isNarrowCanvasCalibrated

    ; Show custom choice dialog with Wide/Narrow/Skip buttons
    choice := ShowCanvasChoiceDialog()

    if (choice == "Skip") {
        UpdateStatus("Setup skipped - Use config menu to calibrate later")
        SaveConfig()
        return
    }

    ; Calibrate first choice
    if (choice == "Wide") {
        ; Wide first
        if (PromptAndCalibrateWide()) {
            ; Offer to calibrate Narrow too
            if (MsgBox("Add Narrow canvas too?", "Add Second Canvas", "YesNo Icon? 4096") == "Yes") {
                PromptAndCalibrateNarrow()
            }
        }
    } else if (choice == "Narrow") {
        ; Narrow first
        if (PromptAndCalibrateNarrow()) {
            ; Offer to calibrate Wide too
            if (MsgBox("Add Wide canvas too?", "Add Second Canvas", "YesNo Icon? 4096") == "Yes") {
                PromptAndCalibrateWide()
            }
        }
    }

    ; Show completion
    if (isWideCanvasCalibrated && isNarrowCanvasCalibrated) {
        MsgBox("Setup complete! Both canvases calibrated.", "Ready", "Icon! 4096")
    } else if (isWideCanvasCalibrated || isNarrowCanvasCalibrated) {
        MsgBox("Setup complete!`n`nAdd remaining canvas anytime in config menu.", "Ready", "Icon! 4096")
    } else {
        MsgBox("Setup complete!`n`nCalibrate when ready in config menu.", "Ready", "Icon! 4096")
    }

    SaveConfig()
    UpdateStatus("Setup complete")
}

ShowCanvasChoiceDialog() {
    choiceResult := "Skip"

    ; Create custom dialog
    choiceGui := Gui("+AlwaysOnTop", "Canvas Setup")
    choiceGui.SetFont("s10")

    choiceGui.Add("Text", "x20 y20 w360", "Choose canvas to calibrate:")
    choiceGui.Add("Text", "x20 y50 w360", "")
    choiceGui.Add("Text", "x20 y60 w360", "Wide - Horizontal/landscape areas")
    choiceGui.Add("Text", "x20 y85 w360", "Narrow - Vertical/portrait areas")
    choiceGui.Add("Text", "x20 y115 w360", "Pick one to start (you can add the other later).")

    btnWide := choiceGui.Add("Button", "x60 y150 w100 h35 Default", "Wide")
    btnNarrow := choiceGui.Add("Button", "x170 y150 w100 h35", "Narrow")
    btnSkip := choiceGui.Add("Button", "x280 y150 w100 h35", "Skip")

    btnWide.OnEvent("Click", (*) => ChoiceSelected("Wide"))
    btnNarrow.OnEvent("Click", (*) => ChoiceSelected("Narrow"))
    btnSkip.OnEvent("Click", (*) => ChoiceSelected("Skip"))

    ChoiceSelected(selection) {
        choiceResult := selection
        choiceGui.Destroy()
    }

    choiceGui.Show("w400 h200")
    WinWaitClose("ahk_id " . choiceGui.Hwnd)

    return choiceResult
}

PromptAndCalibrateWide() {
    result := MsgBox("Wide Canvas`n`nClick OK, then click:`n1. Top-left corner`n2. Bottom-right corner", "Wide Canvas", "OKCancel Icon? 4096")
    if (result == "OK") {
        CalibrateWideCanvasForWizard()
        return true
    }
    return false
}

PromptAndCalibrateNarrow() {
    result := MsgBox("Narrow Canvas`n`nClick OK, then click:`n1. Top-left corner`n2. Bottom-right corner", "Narrow Canvas", "OKCancel Icon? 4096")
    if (result == "OK") {
        CalibrateNarrowCanvasForWizard()
        return true
    }
    return false
}

CalibrateWideCanvasForWizard() {
    global wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom, isWideCanvasCalibrated

    ; Set coordinate mode to Screen for multi-monitor support
    CoordMode("Mouse", "Screen")

    UpdateStatus("📐 Click top-left corner of WIDE canvas area...")

    ; Wait for button release first, then wait for click
    KeyWait("LButton", "U T30")
    if (!KeyWait("LButton", "D T30")) {
        UpdateStatus("⚠️ Wide canvas calibration timeout")
        return
    }

    MouseGetPos(&x1, &y1)
    KeyWait("LButton", "U T5")

    UpdateStatus("📐 Now click bottom-right corner of WIDE canvas area...")

    if (!KeyWait("LButton", "D T30")) {
        UpdateStatus("⚠️ Wide canvas calibration timeout")
        return
    }

    MouseGetPos(&x2, &y2)
    KeyWait("LButton", "U T5")

    ; Calculate bounds using Min/Max for proper ordering
    global wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom
    wideCanvasLeft := Min(x1, x2)
    wideCanvasTop := Min(y1, y2)
    wideCanvasRight := Max(x1, x2)
    wideCanvasBottom := Max(y1, y2)

    ; Validate
    width := wideCanvasRight - wideCanvasLeft
    height := wideCanvasBottom - wideCanvasTop

    if (width > 0 && height > 0) {
        aspectRatio := Round(width / height, 2)
        isWideCanvasCalibrated := true
        UpdateStatus("✅ Wide canvas calibrated: " . width . "x" . height . " (AR: " . aspectRatio . ")")
        CleanupHBITMAPCache()
    } else {
        UpdateStatus("❌ Wide canvas calibration failed - invalid coordinates")
    }
}

CalibrateNarrowCanvasForWizard() {
    global narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom, isNarrowCanvasCalibrated

    ; Set coordinate mode to Screen for multi-monitor support
    CoordMode("Mouse", "Screen")

    UpdateStatus("📐 Click top-left corner of NARROW canvas area...")

    ; Wait for button release first, then wait for click
    KeyWait("LButton", "U T30")
    if (!KeyWait("LButton", "D T30")) {
        UpdateStatus("⚠️ Narrow canvas calibration timeout")
        return
    }

    MouseGetPos(&x1, &y1)
    KeyWait("LButton", "U T5")

    UpdateStatus("📐 Now click bottom-right corner of NARROW canvas area...")

    if (!KeyWait("LButton", "D T30")) {
        UpdateStatus("⚠️ Narrow canvas calibration timeout")
        return
    }

    MouseGetPos(&x2, &y2)
    KeyWait("LButton", "U T5")

    ; Calculate bounds using Min/Max for proper ordering
    global narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom
    narrowCanvasLeft := Min(x1, x2)
    narrowCanvasTop := Min(y1, y2)
    narrowCanvasRight := Max(x1, x2)
    narrowCanvasBottom := Max(y1, y2)

    ; Validate
    width := narrowCanvasRight - narrowCanvasLeft
    height := narrowCanvasBottom - narrowCanvasTop

    if (width > 0 && height > 0) {
        aspectRatio := Round(width / height, 2)
        isNarrowCanvasCalibrated := true
        UpdateStatus("✅ Narrow canvas calibrated: " . width . "x" . height . " (AR: " . aspectRatio . ")")
        CleanupHBITMAPCache()
    } else {
        UpdateStatus("❌ Narrow canvas calibration failed - invalid coordinates")
    }
}

; ===== HOTKEY CAPTURE SYSTEM =====
CaptureHotkey(editControl, hotkeyName) {
    ; Simple prompt for hotkey input
    result := InputBox("Enter your hotkey combination for " . hotkeyName . "`n`nExamples:`n  ^k = Ctrl+K`n  !F5 = Alt+F5`n  +Enter = Shift+Enter`n  ^!a = Ctrl+Alt+A`n  F12 = F12`n  NumpadEnter = NumpadEnter`n  CapsLock & f = CapsLock+F`n`nModifiers: ^ = Ctrl, ! = Alt, + = Shift, # = Win", "Set Hotkey - " . hotkeyName, "w400 h280", editControl.Value)

    if (result.Result == "OK" && result.Value != "") {
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

    if (result == "No")
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

; ===== CONDITION SETTINGS HANDLERS =====

; Color picker function with common color palette
PickLabelColor(conditionId, conditionEditControls, settingsGui) {
    controls := conditionEditControls[conditionId]

    ; Create color picker dialog as child of settings window
    colorGui := Gui("+Owner" . settingsGui.Hwnd . " +AlwaysOnTop", "Pick Color for Label " . conditionId)
    colorGui.SetFont("s9")

    colorGui.Add("Text", "x10 y10 w280 h20 Center", "Select a color:")

    ; Common color palette
    colors := [
        ["Orange", "0xFF8C00"],
        ["Yellow", "0xFFFF00"],
        ["Purple", "0x9932CC"],
        ["Green", "0x32CD32"],
        ["Dark Red", "0x8B0000"],
        ["Red", "0xFF0000"],
        ["Dark Orange", "0xFF4500"],
        ["Yellow-Green", "0xADFF2F"],
        ["Cyan", "0x00FFFF"],
        ["Blue", "0x4169E1"],
        ["Pink", "0xFF69B4"],
        ["Lime", "0x00FF00"],
        ["Magenta", "0xFF00FF"],
        ["Teal", "0x008080"],
        ["Brown", "0x8B4513"],
        ["Gray", "0x808080"]
    ]

    yPos := 40
    colCount := 0

    for colorInfo in colors {
        colorName := colorInfo[1]
        colorHex := colorInfo[2]

        xPos := 10 + (colCount * 145)

        ; Color preview box
        colorBox := colorGui.Add("Text", "x" . xPos . " y" . yPos . " w60 h30 Center +Border", "")
        colorBox.Opt("+Background" . colorHex)

        ; Click handler using a generated closure to freeze arguments per item
        pickHandler := CreateColorPickHandler(colorGui, colorHex, controls)

        ; Color name button
        btnColor := colorGui.Add("Button", "x" . (xPos + 65) . " y" . yPos . " w70 h30", colorName)
        btnColor.OnEvent("Click", pickHandler)

        ; Make the colored swatch clickable too
        colorBox.OnEvent("Click", pickHandler)

        colCount++
        if (colCount == 2) {
            colCount := 0
            yPos += 35
        }
    }

    ; Custom hex input at bottom
    yPos += 40
    colorGui.Add("Text", "x10 y" . yPos . " w80 h20", "Custom Hex:")
    customHexEdit := colorGui.Add("Edit", "x95 y" . (yPos - 2) . " w120 h24", "0x")
    btnCustom := colorGui.Add("Button", "x220 y" . (yPos - 2) . " w70 h24", "Apply")
    btnCustom.OnEvent("Click", (*) => SelectCustomColor(colorGui, customHexEdit, controls))

    colorGui.Show("w300 h" . (yPos + 40))
}

; Apply selected color from palette
SelectColor(colorGui, colorHex, controls) {
    VizLog("SelectColor called: colorHex=" . colorHex)
    controls.currentColor := colorHex
    controls.colorDisplay.Value := colorHex
    VizLog("Updated colorDisplay.Value to: " . controls.colorDisplay.Value)
    ; Force the control to update visually
    try {
        controls.colorDisplay.Redraw()
        VizLog("Redraw successful")
    } catch as e {
        VizLog("Redraw failed: " . e.Message)
    }
    ; Update live preview swatch if available (no try/catch needed)
    if (controls.HasOwnProp("preview") && IsObject(controls.preview)) {
        controls.preview.Opt("+Background" . colorHex)
        controls.preview.Redraw()
    }
    VizLog("Destroying color picker dialog")
    colorGui.Destroy()
    FlushVizLog()
}

; Apply custom hex color
SelectCustomColor(colorGui, customHexEdit, controls) {
    customColor := Trim(customHexEdit.Value)

    ; Validate hex color
    if (!ValidateHexColor(customColor)) {
        MsgBox("Invalid color format!`n`nPlease use format: 0xRRGGBB`nExample: 0xFF8C00", "Invalid Color", "Icon!")
        return
    }

    controls.currentColor := customColor
    controls.colorDisplay.Value := customColor
    ; Force the control to update visually
    try {
        controls.colorDisplay.Redraw()
    } catch as e {
        ; ignore redraw issues
    }
    ; Update live preview swatch if available (no try/catch needed)
    if (controls.HasOwnProp("preview") && IsObject(controls.preview)) {
        controls.preview.Opt("+Background" . customColor)
        controls.preview.Redraw()
    }
    colorGui.Destroy()
}

; Generate a per-item click handler that freezes the color and control references
CreateColorPickHandler(colorGui, colorHex, controls) {
    return (*) => SelectColor(colorGui, colorHex, controls)
}

; Freeze conditionId for "Pick" button handler in Conditions tab
CreatePickLabelHandler(conditionId, conditionEditControls, settingsGui) {
    return (*) => PickLabelColor(conditionId, conditionEditControls, settingsGui)
}

; Freeze conditionId for hex Edit Change handler in Conditions tab
CreateHexChangeHandler(conditionId, conditionEditControls) {
    return (*) => HandleLabelColorEditChange(conditionId, conditionEditControls)
}

; Live-update handler for hex edit in Conditions tab
HandleLabelColorEditChange(conditionId, conditionEditControls) {
    if (!conditionEditControls.Has(conditionId))
        return
    controls := conditionEditControls[conditionId]
    value := Trim(controls.colorDisplay.Value)
    if (ValidateHexColor(value)) {
        controls.currentColor := value
        if (controls.HasOwnProp("preview") && IsObject(controls.preview)) {
            controls.preview.Opt("+Background" . value)
            controls.preview.Redraw()
        }
    } else {
        ; Show neutral preview when invalid
        if (controls.HasOwnProp("preview") && IsObject(controls.preview)) {
            controls.preview.Opt("+Background0xFFFFFF")
            controls.preview.Redraw()
        }
    }
}

ApplyConditionSettings(conditionEditControls, settingsGui) {
    global conditionConfig

    VizLog("=== ApplyConditionSettings CALLED ===")
    FlushVizLog()

    ; Validate and update all labels
    errorMessages := []

    ; Debug: Track what's being updated
    updatedCount := 0

    for conditionId, controls in conditionEditControls {
        newName := Trim(controls.name.Value)
        newColor := Trim(controls.colorDisplay.Value)

        ; Validate name
        if (StrLen(newName) == 0 || StrLen(newName) > 30) {
            errorMessages.Push("Label " . conditionId . ": Name must be 1-30 characters")
            continue
        }

        if (!ValidateConditionName(newName)) {
            errorMessages.Push("Label " . conditionId . ": Invalid name '" . newName . "' (use alphanumeric, spaces, hyphens, underscores only)")
            continue
        }

        ; Validate color
        if (!ValidateHexColor(newColor)) {
            errorMessages.Push("Label " . conditionId . ": Invalid color '" . newColor . "' (use format 0xRRGGBB)")
            continue
        }

        ; Update configuration - use displayName for both name and displayName
        conditionConfig[conditionId].displayName := newName
        conditionConfig[conditionId].color := newColor
        ; Keep existing internal name and statKey unchanged for compatibility
        updatedCount++
    }

    ; Show validation errors if any
    if (errorMessages.Length > 0) {
        errorText := "Validation Errors:`n`n"
        for msg in errorMessages {
            errorText .= "• " . msg . "`n"
        }
        MsgBox(errorText, "Validation Failed", "Icon! 48")
        return
    }

    ; Debug: Log what's in conditionConfig before sync
    VizLog("=== APPLYING CONDITION SETTINGS ===")
    for id, config in conditionConfig {
        VizLog("Label " . id . ": name=" . config.name . " displayName=" . config.displayName . " color=" . config.color)
    }

    ; Sync legacy maps and save config
    VizLog("=== BEFORE SYNC ===")
    for id, color in conditionColors {
        VizLog("conditionColors[" . id . "] = " . color)
    }

    SyncLegacyConditionMaps()

    ; Debug: Log what's in conditionColors after sync
    VizLog("=== AFTER SYNC ===")
    for id, color in conditionColors {
        VizLog("conditionColors[" . id . "] = " . color)
    }

    ; Verify the global is actually updated
    global conditionColors
    VizLog("=== VERIFYING GLOBAL conditionColors ===")
    VizLog("conditionColors type: " . Type(conditionColors))
    VizLog("conditionColors count: " . conditionColors.Count)

    SaveConfig()

    ; Clear BOTH caches to force complete regeneration with new colors
    VizLog("=== CLEARING HBITMAP CACHE ===")
    VizLog("hbitmapCache size before: " . hbitmapCache.Count)
    CleanupHBITMAPCache()
    VizLog("hbitmapCache size after: " . hbitmapCache.Count)

    VizLog("=== CLEARING DISPLAYED HBITMAPS ===")
    VizLog("buttonDisplayedHBITMAPs size before: " . buttonDisplayedHBITMAPs.Count)
    CleanupButtonDisplayedHBITMAPs()
    VizLog("buttonDisplayedHBITMAPs size after: " . buttonDisplayedHBITMAPs.Count)

    ; Refresh all button visualizations to show new colors
    VizLog("=== REFRESHING ALL BUTTONS ===")
    RefreshAllButtonAppearances()
    FlushVizLog()

    UpdateStatus("✅ Label settings applied (" . updatedCount . " labels)")
}

ResetConditionSettings(settingsGui) {
    ; Confirm reset
    result := MsgBox("Reset all conditions to factory defaults?`n`nThis will restore original names and colors.", "Reset Conditions", "YesNo Icon?")

    if (result == "No")
        return

    ; Reset to defaults
    ResetAllConditionsToDefaults()
    SaveConfig()

    ; Clear BOTH caches to force complete regeneration with default colors
    CleanupHBITMAPCache()
    CleanupButtonDisplayedHBITMAPs()

    ; Refresh all button visualizations to show default colors
    RefreshAllButtonAppearances()

    ; Close and reopen settings to show updated values
    settingsGui.Destroy()
    ShowSettings()

    MsgBox("Conditions have been reset to factory defaults!", "Reset Complete", "Icon!")
    UpdateStatus("✅ Conditions reset to defaults")
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

; Auto-initialize canvases with virtual screen if not calibrated
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

    ; Clear any stale HBITMAP cache from previous sessions
    CleanupHBITMAPCache()

    ; Initialize GDI+
    if (!gdiPlusInitialized) {
        try {
            si := Buffer(24, 0)
            NumPut("UInt", 1, si, 0)
            result := DllCall("gdiplus\GdiplusStartup", "Ptr*", &gdiPlusToken, "Ptr", si, "Ptr", 0)
            if (result == 0) {
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

    ; Warn if no canvas is configured
    if (!wideConfigured && !narrowConfigured) {
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
    currentConditionType := 1  ; Default condition type

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

        if (eventType == "boundingBox" && hasProps) {
            ; Calculate box dimensions (support both Map and Object)
            left := (Type(event) = "Map") ? event["left"] : event.left
            top := (Type(event) = "Map") ? event["top"] : event.top
            right := (Type(event) = "Map") ? event["right"] : event.right
            bottom := (Type(event) = "Map") ? event["bottom"] : event.bottom

            ; Only include boxes that are reasonably sized
            if ((right - left) >= 5 && (bottom - top) >= 5) {
                ; Check if conditionType is already stored in the event (from config load)
                conditionType := currentConditionType
                if ((Type(event) == "Map" && (event.Has("conditionType") || event.Has("conditionType"))) || (IsObject(event) && (event.HasOwnProp("conditionType") || event.HasOwnProp("conditionType")))) {
                    conditionType := (Type(event) = "Map") ? (event.Has("conditionType") ? event["conditionType"] : event["conditionType"]) : (event.HasOwnProp("conditionType") ? event.conditionType : event.conditionType)
                    currentConditionType := conditionType
                } else {
                    ; Look ahead for keypress events that assign condition type
                    nextIndex := eventIndex + 1
                    while (nextIndex <= macroEvents.Length) {
                        nextEvent := macroEvents[nextIndex]

                        ; Get next event type (support Map and Object)
                        nextEventType := ""
                if (Type(nextEvent) == "Map") {
                            nextEventType := nextEvent.Has("type") ? nextEvent["type"] : ""
                        } else if (IsObject(nextEvent)) {
                            nextEventType := nextEvent.HasOwnProp("type") ? nextEvent.type : ""
                        }

                        ; Stop at next bounding box - keypress should be immediately after current box
                        if (nextEventType == "boundingBox")
                            break

                        ; Found a keypress after this box - this assigns the condition type
                        if (nextEventType == "keyDown") {
                            nextKey := (Type(nextEvent) = "Map") ? (nextEvent.Has("key") ? nextEvent["key"] : "") : (nextEvent.HasOwnProp("key") ? nextEvent.key : "")
                            if (RegExMatch(nextKey, "^\d$")) {
                                keyNumber := Integer(nextKey)
                                if (keyNumber >= 1 && keyNumber <= 9) {
                                    conditionType := keyNumber
                                    currentConditionType := keyNumber  ; Update current condition for subsequent boxes
                                    break
                                }
                            }
                        }

                        nextIndex++
                    }
                }

                box := {
                    left: left,
                    top: top,
                    right: right,
                    bottom: bottom,
                    conditionType: conditionType
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
    global conditionColors, annotationMode
    global wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom
    global narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom
    
    if (boxes.Length == 0) {
        return
    }
    
    recordedMode := ""
    recordedCanvas := ""
    if (IsObject(macroEventsArray)) {
        if (macroEventsArray.HasOwnProp("recordedMode"))
            recordedMode := macroEventsArray.recordedMode
        if (macroEventsArray.HasOwnProp("recordedCanvas"))
            recordedCanvas := macroEventsArray.recordedCanvas
    }
    displayMode := (recordedMode != "" ? recordedMode : annotationMode)

    useRecordedCanvas := IsObject(recordedCanvas) && recordedCanvas.HasOwnProp("left") && recordedCanvas.HasOwnProp("right")

    if (useRecordedCanvas) {
        canvasLeft := recordedCanvas.left
        canvasTop := recordedCanvas.top
        canvasRight := recordedCanvas.right
        canvasBottom := recordedCanvas.bottom
    } else if (displayMode == "Narrow") {
        canvasLeft := narrowCanvasLeft
        canvasTop := narrowCanvasTop
        canvasRight := narrowCanvasRight
        canvasBottom := narrowCanvasBottom
    } else {
        canvasLeft := wideCanvasLeft
        canvasTop := wideCanvasTop
        canvasRight := wideCanvasRight
        canvasBottom := wideCanvasBottom
    }
    
    canvasW := canvasRight - canvasLeft
    canvasH := canvasBottom - canvasTop
    
    VizLog("DrawMacroBoxesOnButton: mode=" . displayMode)
    VizLog("  Canvas: L=" . canvasLeft . " T=" . canvasTop . " R=" . canvasRight . " B=" . canvasBottom)
    VizLog("  Canvas size: " . canvasW . "x" . canvasH . " Button: " . buttonWidth . "x" . buttonHeight)
    VizLog("  conditionColors at draw time:")
    for id, color in conditionColors {
        VizLog("    [" . id . "] = " . color)
    }
    
    if (canvasW <= 0 || canvasH <= 0) {
        VizLog("  ERROR: Invalid canvas")
        return
    }
    
    darkBrush := 0
    DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF2A2A2A, "Ptr*", &darkBrush)
    DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", darkBrush, "Float", 0, "Float", 0, "Float", buttonWidth, "Float", buttonHeight)
    DllCall("gdiplus\GdipDeleteBrush", "Ptr", darkBrush)

    letterboxRect := {x:0, y:0, width:buttonWidth, height:buttonHeight}
    useLetterbox := (displayMode == "Narrow")
    if (useLetterbox) {
        desiredRatio := 4.0 / 3.0
        aspect := buttonWidth / buttonHeight
        if (aspect > desiredRatio) {
            letterboxRect.height := buttonHeight - 4
            letterboxRect.width := Round(letterboxRect.height * desiredRatio)
        } else {
            letterboxRect.width := buttonWidth - 4
            letterboxRect.height := Round(letterboxRect.width / desiredRatio)
        }
        if (letterboxRect.width < 16 || letterboxRect.height < 12) {
            useLetterbox := false
        } else {
            letterboxRect.x := Floor((buttonWidth - letterboxRect.width) / 2)
            letterboxRect.y := Floor((buttonHeight - letterboxRect.height) / 2)

            letterboxBrush := 0
            DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF1E1E1E, "Ptr*", &letterboxBrush)
            ; Shade left margin
            if (letterboxRect.x > 0) {
                DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", letterboxBrush, "Float", 0, "Float", 0, "Float", letterboxRect.x, "Float", buttonHeight)
            }
            ; Shade right margin
            rightMargin := buttonWidth - (letterboxRect.x + letterboxRect.width)
            if (rightMargin > 0) {
                DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", letterboxBrush, "Float", letterboxRect.x + letterboxRect.width, "Float", 0, "Float", rightMargin, "Float", buttonHeight)
            }
            DllCall("gdiplus\GdipDeleteBrush", "Ptr", letterboxBrush)

        }
    }

    screenScale := A_ScreenDPI / 96.0
    canvasLeftLogical := canvasLeft / screenScale
    canvasTopLogical := canvasTop / screenScale
    canvasWLogical := (canvasRight / screenScale) - canvasLeftLogical
    canvasHLogical := (canvasBottom / screenScale) - canvasTopLogical

    scaleX := letterboxRect.width / canvasWLogical
    scaleY := letterboxRect.height / canvasHLogical
    offsetX := letterboxRect.x
    offsetY := letterboxRect.y
    
    VizLog("  Uniform scale: X=" . Round(scaleX, 4) . " Y=" . Round(scaleY, 4))
    
    boxCount := 0
    for box in boxes {
        if (box.right <= box.left || box.bottom <= box.top) {
            continue
        }
        
        clampedLeft := Max(box.left, canvasLeft)
        clampedTop := Max(box.top, canvasTop)
        clampedRight := Min(box.right, canvasRight)
        clampedBottom := Min(box.bottom, canvasBottom)

        x1 := (((clampedLeft / screenScale) - canvasLeftLogical) * scaleX) + offsetX
        y1 := (((clampedTop / screenScale) - canvasTopLogical) * scaleY) + offsetY
        x2 := (((clampedRight / screenScale) - canvasLeftLogical) * scaleX) + offsetX
        y2 := (((clampedBottom / screenScale) - canvasTopLogical) * scaleY) + offsetY
        
        w := x2 - x1
        h := y2 - y1

        VizLog("  Box " . A_Index . ": canvas(" . box.left . "," . box.top . "," . box.right . "," . box.bottom . ")")
        VizLog("    clamped canvas=(" . clampedLeft . "," . clampedTop . "," . clampedRight . "," . clampedBottom . ")")
        VizLog("    scaled=(" . Round(x1,1) . "," . Round(y1,1) . "," . Round(x2,1) . "," . Round(y2,1) . ") w=" . Round(w,1) . " h=" . Round(h,1))

        if (w <= 0 || h <= 0) {
            continue
        }
        
        conditionType := box.HasOwnProp("conditionType") ? box.conditionType : 1
        color := conditionColors.Has(conditionType) ? conditionColors[conditionType] : conditionColors[1]
        VizLog("    conditionType=" . conditionType . " color=" . color)
        fillColor := 0xFF000000 | Integer(color)
        
        brush := 0
        result := DllCall("gdiplus\GdipCreateSolidFill", "UInt", fillColor, "Ptr*", &brush)
        if (result == 0) {
            DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", brush, "Float", x1, "Float", y1, "Float", w, "Float", h)
            DllCall("gdiplus\GdipDeleteBrush", "Ptr", brush)
            boxCount++
            VizLog("    DRAWN")
        }
    }
    
    VizLog("  Total drawn: " . boxCount)
    FlushVizLog()
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
global vizLoggingEnabled := false  ; Disable verbose viz logging by default to speed startup

VizLog(msg) {
    global vizLogBuffer, vizLoggingEnabled
    if (!vizLoggingEnabled)
        return
    vizLogBuffer.Push(A_Now . " - " . msg)
}

FlushVizLog() {
    global vizLogBuffer, vizLogPath, vizLoggingEnabled
    if (!vizLoggingEnabled)
        return
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
        ; conditionColors values are like "0xFF8C00" (RGB only)
        ; We need to ensure it has full alpha: 0xFFFF8C00 (ARGB)
        colorInt := Integer(colorHex)
        ; If the value is less than 0x01000000, it's missing the alpha channel
        if (colorInt < 0x01000000) {
            colorInt := colorInt | 0xFF000000  ; Add full alpha
        }

        ; Always fill with condition color first
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
    global gdiPlusInitialized, conditionColors, hbitmapCache

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

    if (!macroEvents || macroEvents.Length == 0) {
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
        if (event.type == "boundingBox") {
            cacheKey .= event.left . "," . event.top . "," . event.right . "," . event.bottom . ","
            ; Include condition type and color in cache key
            if (event.HasOwnProp("conditionType")) {
                cacheKey .= event.conditionType . ":"
                if (conditionColors.Has(event.conditionType)) {
                    cacheKey .= conditionColors[event.conditionType]
                }
            }
            cacheKey .= "|"
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
    if (boxes.Length == 0) {
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

        if (result == 0 && hbitmap) {
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

    for cacheKey, hbitmap in hbitmapCache {
        if (hbitmap) {
            RemoveHBITMAPReference(hbitmap)
        }
    }

    hbitmapCache := Map()
}

CleanupButtonDisplayedHBITMAPs() {
    global buttonDisplayedHBITMAPs

    for buttonName, hbitmap in buttonDisplayedHBITMAPs {
        if (hbitmap) {
            RemoveHBITMAPReference(hbitmap)
        }
    }

    buttonDisplayedHBITMAPs := Map()
}

AddHBITMAPReference(hbitmap) {
    global hbitmapRefCounts

    if (!hbitmap || hbitmap == 0) {
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

    if (!hbitmap || hbitmap == 0) {
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
    if (!hbitmap || hbitmap == 0) {
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
; Tracks conditions for both macro executions and JSON profile executions

; Suppress warnings for ObjSave and ObjLoad (defined in ObjPersistence.ahk)
#Warn VarUnset, Off

Stats_GetCsvHeader() {
    global conditionConfig

    ; Base header columns
    header := "timestamp,session_id,username,execution_type,button_key,layer,execution_time_ms,total_boxes,condition_assignments,severity_level,canvas_mode,session_active_time_ms,break_mode_active,"

    ; Add condition count columns dynamically
    for id, config in conditionConfig {
        header .= config.name . "_count,"
    }

    ; Add clear_count and remaining columns
    header .= "clear_count,annotation_details,execution_success,error_details`n"

    return header
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
    global currentSessionId, currentUsername, conditionConfig

    sessionIdentifier := executionData.Has("session_id") ? executionData["session_id"] : currentSessionId
    usernameValue := executionData.Has("username") ? executionData["username"] : currentUsername

    ; Base columns
    row := executionData["timestamp"] . "," . sessionIdentifier . "," . usernameValue . "," . executionData["execution_type"] . ","
    row .= (executionData.Has("button_key") ? executionData["button_key"] : "") . "," . executionData["layer"] . "," . executionData["execution_time_ms"] . "," . executionData["total_boxes"] . ","
    row .= (executionData.Has("condition_assignments") ? executionData["condition_assignments"] : "") . "," . executionData["severity_level"] . "," . executionData["canvas_mode"] . "," . executionData["session_active_time_ms"] . ","
    row .= (executionData.Has("break_mode_active") ? (executionData["break_mode_active"] ? "true" : "false") : "false") . ","

    ; Add condition count columns dynamically
    for id, config in conditionConfig {
        countFieldName := config.name . "_count"
        row .= (executionData.Has(countFieldName) ? executionData[countFieldName] : 0) . ","
    }

    ; Add clear_count and remaining columns
    row .= (executionData.Has("clear_count") ? executionData["clear_count"] : 0) . ","
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
    ; Defer potentially heavy stats JSON load until after UI shows
    SetTimer(LoadStatsFromJson, -50)
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
    stats["condition_totals"] := Map()

    ; Initialize condition stats dynamically from conditionConfig
    global conditionConfig
    for id, config in conditionConfig {
        ; Total counts (legacy compatibility)
        stats[config.name . "_total"] := 0

        ; Macro-specific counts
        stats["macro_" . config.statKey] := 0

        ; JSON-specific counts
        stats["json_" . config.statKey] := 0
    }

    ; Clear count (special case, not a condition type)
    stats["clear_total"] := 0
    stats["macro_clear"] := 0
    stats["json_clear"] := 0

    ; Severity levels
    stats["severity_low"] := 0
    stats["severity_medium"] := 0
    stats["severity_high"] := 0

    return stats
}

Stats_IncrementConditionCount(stats, condition_name, prefix := "json_") {
    global conditionConfig

    ; Handle clear/none as special case
    if (StrLower(condition_name) == "clear" || StrLower(condition_name) == "none") {
        stats[prefix . "clear"]++
        return
    }

    ; Try as numeric ID first
    if (IsInteger(condition_name)) {
        conditionId := Integer(condition_name)
        if (conditionConfig.Has(conditionId)) {
            statKey := conditionConfig[conditionId].statKey
            stats[prefix . statKey]++
            return
        }
    }

    ; Try as condition name
    for id, config in conditionConfig {
        if (StrLower(config.name) == StrLower(condition_name)) {
            stats[prefix . config.statKey]++
            return
        }
    }

    ; Legacy alias fallback (e.g., "smudge", "glare", etc.)
    global legacyConditionNameToId
    nameLower := StrLower(String(condition_name))
    if (legacyConditionNameToId.Has(nameLower)) {
        conditionId := legacyConditionNameToId[nameLower]
        if (conditionConfig.Has(conditionId)) {
            stats[prefix . conditionConfig[conditionId].statKey]++
            return
        }
    }
}

Stats_IncrementConditionCountDirect(executionData, condition_name) {
    global conditionConfig

    ; Handle clear/none as special case
    if (StrLower(condition_name) == "clear" || StrLower(condition_name) == "none") {
        executionData["clear_count"]++
        return
    }

    ; Try as numeric ID first
    if (IsInteger(condition_name)) {
        conditionId := Integer(condition_name)
        if (conditionConfig.Has(conditionId)) {
            ; Use full name for direct count field (e.g., "light_flare_count")
            fieldName := conditionConfig[conditionId].name . "_count"
            executionData[fieldName]++
            return
        }
    }

    ; Try as condition name
    for id, config in conditionConfig {
        if (StrLower(config.name) == StrLower(condition_name)) {
            fieldName := config.name . "_count"
            executionData[fieldName]++
            return
        }
    }

    ; Legacy alias fallback (e.g., "smudge", "glare", etc.)
    global legacyConditionNameToId
    nameLower := StrLower(String(condition_name))
    if (legacyConditionNameToId.Has(nameLower)) {
        conditionId := legacyConditionNameToId[nameLower]
        if (conditionConfig.Has(conditionId)) {
            fieldName := conditionConfig[conditionId].name . "_count"
            executionData[fieldName]++
            return
        }
    }
}

; =============================================================================
; UNIFIED STATS QUERY SYSTEM
; =============================================================================

; Global cache for today's stats
global todayStatsCache := Map()
global todayStatsCacheDate := ""
global todayStatsCacheInvalidated := true

; Unified stats query function with flexible filtering
; filterOptions := {
;     dateFilter: "all" | "today" | "session"  (default: "all")
;     sessionId: "specific_session_id"          (optional, requires dateFilter="session")
;     username: "specific_username"             (optional)
;     buttonKey: "specific_button"              (optional)
;     layer: layer_number                       (optional)
; }
QueryUserStats(filterOptions := "") {
    global macroExecutionLog, sessionId, totalActiveTime, currentUsername

    ; Initialize default filter options
    if (filterOptions == "") {
        filterOptions := Map()
        filterOptions["dateFilter"] := "all"
    }

    ; Check if we can use cached today stats
    ; IMPORTANT: For real-time display, we still need to update live time even from cache
    if (filterOptions["dateFilter"] == "today") {
        today := FormatTime(A_Now, "yyyy-MM-dd")
        if (!todayStatsCacheInvalidated && todayStatsCacheDate == today && todayStatsCache.Count > 0) {
            ; Clone cached stats to avoid modifying the cache itself
            stats := Map()
            for key, value in todayStatsCache {
                stats[key] := value
            }

            ; CRITICAL: Update live time from current session
            currentLiveTime := GetCurrentSessionActiveTime()
            sessionActiveMap := stats.Has("session_active_time_map") ? stats["session_active_time_map"] : Map()

            ; Recalculate total time with current live delta
            totalSessionActive := 0
            for sessId, activeMs in sessionActiveMap {
                if (activeMs > 0) {
                    totalSessionActive += activeMs
                }
            }

            if (sessionActiveMap.Has(sessionId)) {
                ; Add delta since last saved execution in this session
                timeDelta := currentLiveTime - sessionActiveMap[sessionId]
                if (timeDelta > 0) {
                    totalSessionActive += timeDelta
                }
            } else {
                ; No executions yet today in current session - add all current time
                if (currentLiveTime > 0) {
                    totalSessionActive += currentLiveTime
                }
            }

            stats["session_active_time"] := totalSessionActive

            ; Recalculate rates with updated time
            if (stats["session_active_time"] > 5000) {
                activeTimeHours := stats["session_active_time"] / 3600000
                stats["boxes_per_hour"] := Round(stats["total_boxes"] / activeTimeHours, 1)
                stats["executions_per_hour"] := Round(stats["total_executions"] / activeTimeHours, 1)
            }

            return stats
        }
    }

    ; Build stats from scratch
    stats := Stats_CreateEmptyStatsMap()
    sessionActiveMap := Map()
    executionTimes := []
    buttonCount := Map()
    layerCount := Map()

    ; Determine date filter
    dateFilter := filterOptions.Has("dateFilter") ? filterOptions["dateFilter"] : "all"
    today := (dateFilter == "today") ? FormatTime(A_Now, "yyyy-MM-dd") : ""
    filterSession := (dateFilter == "session")
    targetSessionId := filterOptions.Has("sessionId") ? filterOptions["sessionId"] : sessionId

    ; Optional filters
    filterUsername := filterOptions.Has("username") ? filterOptions["username"] : ""
    filterButton := filterOptions.Has("buttonKey") ? filterOptions["buttonKey"] : ""
    filterLayer := filterOptions.Has("layer") ? filterOptions["layer"] : 0

    ; Process execution log
    for executionData in macroExecutionLog {
        try {
            ; Apply date filter
            if (dateFilter == "today") {
                timestamp := executionData.Has("timestamp") ? executionData["timestamp"] : ""
                if (SubStr(timestamp, 1, 10) != today) {
                    continue
                }
            }

            ; Apply session filter
            if (filterSession) {
                execSessionId := executionData.Has("session_id") ? executionData["session_id"] : sessionId
                if (execSessionId != targetSessionId) {
                    continue
                }
            }

            ; Apply username filter
            if (filterUsername != "") {
                execUsername := executionData.Has("username") ? executionData["username"] : currentUsername
                if (execUsername != filterUsername) {
                    continue
                }
            }

            ; Apply button filter
            if (filterButton != "") {
                execButton := executionData.Has("button_key") ? executionData["button_key"] : ""
                if (execButton != filterButton) {
                    continue
                }
            }

            ; Apply layer filter
            if (filterLayer > 0) {
                execLayer := executionData.Has("layer") ? executionData["layer"] : 1
                if (execLayer != filterLayer) {
                    continue
                }
            }

            ; Extract execution data
            execution_type := executionData["execution_type"]
            macro_name := executionData.Has("button_key") ? executionData["button_key"] : ""
            layer := executionData.Has("layer") ? executionData["layer"] : 1
            execution_time := executionData.Has("execution_time_ms") ? executionData["execution_time_ms"] : 0
            total_boxes := executionData.Has("total_boxes") ? executionData["total_boxes"] : 0
            severity_level := executionData.Has("severity_level") ? executionData["severity_level"] : ""
            session_active_time := executionData.Has("session_active_time_ms") ? executionData["session_active_time_ms"] : 0
            execSessionId := executionData.Has("session_id") ? executionData["session_id"] : sessionId
            username := executionData.Has("username") ? executionData["username"] : currentUsername

            ; Track maximum active time per session
            if (!sessionActiveMap.Has(execSessionId) || session_active_time > sessionActiveMap[execSessionId]) {
                sessionActiveMap[execSessionId] := session_active_time
            }

            ; Update user summary
            UpdateUserSummary(stats["user_summary"], username, total_boxes, execSessionId)

            ; Aggregate basic stats
            stats["total_executions"]++
            stats["total_boxes"] += total_boxes
            stats["total_execution_time"] += execution_time
            executionTimes.Push(execution_time)

            ; Count execution types
            if (execution_type == "clear") {
                stats["clear_executions_count"]++
            } else if (execution_type == "json_profile") {
                stats["json_profile_executions_count"]++
            } else {
                stats["macro_executions_count"]++
            }

            ; Track button usage
            if (macro_name != "") {
                if (!buttonCount.Has(macro_name)) {
                    buttonCount[macro_name] := 0
                }
                buttonCount[macro_name]++
            }

            ; Track layer usage
            if (!layerCount.Has(layer)) {
                layerCount[layer] := 0
            }
            layerCount[layer]++

            ; Track severity levels for JSON profiles
            if (execution_type == "json_profile" && severity_level != "") {
                switch StrLower(severity_level) {
                    case "low":
                        stats["severity_low"]++
                    case "medium":
                        stats["severity_medium"]++
                    case "high":
                        stats["severity_high"]++
                }
            }

            ; Aggregate condition counts dynamically (with legacy fallback)
    global conditionConfig, legacyConditionCountFieldById
            for id, config in conditionConfig {
                fieldName := config.name . "_count"
                count := executionData.Has(fieldName) ? executionData[fieldName] : 0
                if (count = 0 && legacyConditionCountFieldById.Has(id)) {
                    legacyField := legacyConditionCountFieldById[id]
                    if (executionData.Has(legacyField)) {
                        count := executionData[legacyField]
                    }
                }
                stats[config.name . "_total"] := stats[config.name . "_total"] + count
                if (execution_type == "json_profile") {
                    stats["json_" . config.statKey] := stats["json_" . config.statKey] + count
                } else if (execution_type == "macro") {
                    stats["macro_" . config.statKey] := stats["macro_" . config.statKey] + count
                }
            }

            ; Handle clear counts
            clear := executionData.Has("clear_count") ? executionData["clear_count"] : 0
            stats["clear_total"] := stats["clear_total"] + clear
            if (execution_type == "json_profile") {
                stats["json_clear"] := stats["json_clear"] + clear
            } else if (execution_type == "macro") {
                stats["macro_clear"] := stats["macro_clear"] + clear
            }
        } catch {
            continue
        }
    }

    ; Calculate aggregate metrics
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

    ; CRITICAL FIX: For "today" filter, include current active session time
    ; This ensures live time is shown even before first execution today
    if (dateFilter == "today") {
        currentLiveTime := GetCurrentSessionActiveTime()

        ; If current session had executions today, its time is already in sessionActiveMap
        ; But we need to add the delta since last execution
        if (sessionActiveMap.Has(sessionId)) {
            ; Add delta since last saved execution in this session
            timeDelta := currentLiveTime - sessionActiveMap[sessionId]
            if (timeDelta > 0) {
                stats["session_active_time"] += timeDelta
            }
        } else {
            ; No executions yet today in current session - add all current time
            if (currentLiveTime > 0) {
                stats["session_active_time"] += currentLiveTime
            }
        }
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

    ; Find most used button and layer
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

    ; Cache today's stats if applicable
    if (dateFilter == "today") {
        global todayStatsCache, todayStatsCacheDate, todayStatsCacheInvalidated
        todayStatsCache := stats
        todayStatsCacheDate := today
        todayStatsCacheInvalidated := false
    }

    return stats
}

; Invalidate today's stats cache (call after recording new execution)
InvalidateTodayStatsCache() {
    global todayStatsCacheInvalidated, todayStatsCache, todayStatsCacheDate
    todayStatsCacheInvalidated := true
    todayStatsCache := Map()
    todayStatsCacheDate := ""
}

; Legacy wrapper - maintained for backward compatibility
ReadStatsFromMemory(filterBySession := false) {
    filterOptions := Map()
    if (filterBySession) {
        filterOptions["dateFilter"] := "session"
    } else {
        filterOptions["dateFilter"] := "all"
    }
    return QueryUserStats(filterOptions)
}

; Legacy wrapper for today's stats - uses caching via QueryUserStats
GetTodayStatsFromMemory() {
    filterOptions := Map()
    filterOptions["dateFilter"] := "today"
    return QueryUserStats(filterOptions)
}

ProcessConditionCounts(executionData, conditionString) {
    if (conditionString == "" || conditionString == "none") {
        return
    }
    conditionTypesArr := StrSplit(conditionString, ",")
    for condType in conditionTypesArr {
        condType := Trim(StrReplace(StrReplace(condType, Chr(34), ""), Chr(39), ""))
        Stats_IncrementConditionCountDirect(executionData, condType)
    }
}

UpdateUserSummary(userSummaryMap, username, totalBoxes, sessionId) {
    if (username == "") {
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
    ; Initialize dynamic condition counts based on configuration
    global conditionConfig
    for id, config in conditionConfig {
        executionData[config.name . "_count"] := 0
    }
    executionData["clear_count"] := 0
    executionData["total_boxes"] := 0
    executionData["condition_assignments"] := ""
    executionData["severity_level"] := "medium"
    executionData["annotation_details"] := ""
    executionData["execution_success"] := "true"
    executionData["error_details"] := ""
    if (executionType == "macro") {
        bbox_count := 0
        condition_counts_map := Map(1, 0, 2, 0, 3, 0, 4, 0, 5, 0, 6, 0, 7, 0, 8, 0, 9, 0, 0, 0)
        for event in events {
            eventType := ""
            if (Type(event) == "Map") {
                eventType := event.Has("type") ? event["type"] : ""
            } else if (IsObject(event)) {
                eventType := event.HasOwnProp("type") ? event.type : ""
            }
            if (eventType == "boundingBox") {
                bbox_count++
                degType := 0
                if (Type(event) == "Map") {
                    degType := event.Has("conditionType") ? event["conditionType"] : (event.Has("conditionType") ? event["conditionType"] : 0)
                } else if (event.HasOwnProp("conditionType")) {
                    degType := event.HasOwnProp("conditionType") ? event.conditionType : event.conditionType
                }
                ; Count all condition types including 0 (clear)
                if (condition_counts_map.Has(degType)) {
                    condition_counts_map[degType]++
                }
            }
        }
        executionData["total_boxes"] := bbox_count
        ; Map counts into executionData using current config names
        for id, config in conditionConfig {
            fieldName := config.name . "_count"
            executionData[fieldName] := condition_counts_map.Has(id) ? condition_counts_map[id] : 0
        }
        executionData["clear_count"] := condition_counts_map.Has(0) ? condition_counts_map[0] : 0

        ; Build condition assignment list using current config names
        condition_names := []
        for id, config in conditionConfig {
            if (condition_counts_map.Has(id) && condition_counts_map[id] > 0) {
                condition_names.Push(config.name)
            }
        }
        if (condition_counts_map.Has(0) && condition_counts_map[0] > 0) {
            condition_names.Push("clear")
        }
        if (condition_names.Length > 0) {
            condition_string := ""
            for i, name in condition_names {
                condition_string .= (i > 1 ? "," : "") . name
            }
            executionData["condition_assignments"] := condition_string
        } else {
            executionData["condition_assignments"] := "clear"
            executionData["clear_count"] := bbox_count > 0 ? bbox_count : 1
        }
    } else if (executionType = "json_profile") {
        executionData["total_boxes"] := 1
        if (IsObject(analysisRecord)) {
            conditionName := analysisRecord.HasOwnProp("jsonConditionName") ? analysisRecord.jsonConditionName : ""
            if (conditionName != "") {
                executionData["condition_assignments"] := conditionName
                ProcessConditionCounts(executionData, conditionName)
            } else {
                executionData["condition_assignments"] := "clear"
                executionData["clear_count"] := 1
            }
            if (analysisRecord.HasOwnProp("severity")) {
                executionData["severity_level"] := analysisRecord.severity
            }
            if (analysisRecord.HasOwnProp("annotationDetails")) {
                executionData["annotation_details"] := analysisRecord.annotationDetails
            }
        } else {
            executionData["condition_assignments"] := "clear"
            executionData["clear_count"] := 1
        }
    } else if (executionType = "clear") {
        executionData["total_boxes"] := 1
        executionData["clear_count"] := 1
        executionData["condition_assignments"] := "clear"
    }
    result := AppendToCSV(executionData)
    if (result) {
        SaveStatsToJson()
    }
    return result
}

global macroExecutionLog := []

SaveSessionEndMarker() {
    global sessionId, currentUsername, annotationMode

    ; Only save if there's active time to preserve
    currentActiveTime := GetCurrentSessionActiveTime()
    if (currentActiveTime <= 0) {
        return
    }

    ; Create a session end marker to preserve active time
    executionData := Map()
    executionData["timestamp"] := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    executionData["session_id"] := sessionId
    executionData["username"] := currentUsername
    executionData["execution_type"] := "session_end"
    executionData["button_key"] := ""
    executionData["layer"] := 1
    executionData["execution_time_ms"] := 0
    executionData["total_boxes"] := 0
    executionData["condition_assignments"] := ""
    executionData["severity_level"] := ""
    executionData["canvas_mode"] := annotationMode
    executionData["session_active_time_ms"] := currentActiveTime
    executionData["break_mode_active"] := false
    executionData["execution_success"] := true
    executionData["error_details"] := ""

    ; Add condition counts (all zeros)
    for i, name in conditionTypes {
        executionData[name . "_count"] := 0
    }

    ; Append to log (will be saved by SaveStatsToJson)
    macroExecutionLog.Push(executionData)
    InvalidateTodayStatsCache()
}

AppendToCSV(executionData) {
    global macroExecutionLog, masterStatsCSV, permanentStatsFile
    try {
        macroExecutionLog.Push(executionData)
        ; Invalidate today's stats cache when new data is added
        InvalidateTodayStatsCache()

        row := Stats_BuildCsvRow(executionData)

        if (masterStatsCSV != "") {
            if (!FileExist(masterStatsCSV)) {
                Stats_EnsureStatsFile(masterStatsCSV, "UTF-8")
            }
            FileAppend(row, masterStatsCSV, "UTF-8")
        }

        if (permanentStatsFile != "") {
            if (!FileExist(permanentStatsFile)) {
                Stats_EnsureStatsFile(permanentStatsFile, "UTF-8")
            }
            FileAppend(row, permanentStatsFile, "UTF-8")
        }

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
    InvalidateTodayStatsCache()

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
    AddSectionDivider(statsGui, y, "MACRO CONDITION BREAKDOWN", 660)
    y += 15

    ; Build condition types dynamically from conditionConfig
    global conditionConfig
    conditionTypes := []
    for id, config in conditionConfig {
        conditionTypes.Push([config.displayName, config.statKey])
    }

    for degInfo in conditionTypes {
        AddHorizontalStatRowLive(statsGui, y, degInfo[1] . ":", "all_macro_" . degInfo[2], "today_macro_" . degInfo[2])
        y += 12
    }
    y += 10
    AddSectionDivider(statsGui, y, "JSON CONDITION SELECTION COUNT", 660)
    y += 15
    for degInfo in conditionTypes {
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
    infoText := statsGui.Add("Text", "x" . leftCol . " y" . y . " w860 +Wrap", "Display Stats: " . masterStatsCSV)
    infoText.SetFont("s8")
    infoText.Opt("c" . (darkMode ? "0x888888" : "0x666666"))
    y += 18
    infoText2 := statsGui.Add("Text", "x" . leftCol . " y" . y . " w860 +Wrap", "Permanent Master: " . permanentStatsFile)
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
    statsGui.Show("w960 h" . (y + 60))
    statsGuiOpen := true
    UpdateStatsDisplay()
    SetTimer(UpdateStatsDisplay, 500)
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
        ; Query stats - QueryUserStats now handles live time calculation
        allStats := ReadStatsFromMemory(false)
        todayStats := GetTodayStatsFromMemory()

        ; Get current live time for all-time stats
        currentActiveTime := GetCurrentSessionActiveTime()

        ; For ALL-TIME: Add current session's live delta
        effectiveAllActiveTime := (allStats.Has("session_active_time") ? allStats["session_active_time"] : 0)

        ; Calculate delta from last saved execution time in current session
        lastExecutionTime := 0
        if (macroExecutionLog.Length > 0) {
            lastExecution := macroExecutionLog[macroExecutionLog.Length]
            if (lastExecution.Has("session_active_time_ms") && lastExecution.Has("session_id")) {
                ; Only use if it's from current session
                if (lastExecution["session_id"] == sessionId) {
                    lastExecutionTime := lastExecution["session_active_time_ms"]
                }
            }
        }

        liveTimeDelta := (currentActiveTime > lastExecutionTime) ? (currentActiveTime - lastExecutionTime) : 0
        effectiveAllActiveTime += liveTimeDelta

        if (effectiveAllActiveTime > 5000) {
            activeTimeHours := effectiveAllActiveTime / 3600000
            allStats["boxes_per_hour"] := Round(allStats["total_boxes"] / activeTimeHours, 1)
            allStats["executions_per_hour"] := Round(allStats["total_executions"] / activeTimeHours, 1)
        }
        allStats["session_active_time"] := effectiveAllActiveTime

        ; For TODAY: QueryUserStats already includes current session time
        ; Just recalculate rates if needed
        effectiveTodayActiveTime := (todayStats.Has("session_active_time") ? todayStats["session_active_time"] : 0)

        if (effectiveTodayActiveTime > 5000) {
            activeTimeHours := effectiveTodayActiveTime / 3600000
            todayStats["boxes_per_hour"] := Round(todayStats["total_boxes"] / activeTimeHours, 1)
            todayStats["executions_per_hour"] := Round(todayStats["total_executions"] / activeTimeHours, 1)
        }
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
        ; Dynamic condition rows: update any controls with matching prefixes
        for keyName, ctrl in statsControls {
            if (SubStr(keyName, 1, 10) == "all_macro_") {
                suffix := SubStr(keyName, 11)
                ctrl.Value := allStats.Has("macro_" . suffix) ? allStats["macro_" . suffix] : 0
            } else if (SubStr(keyName, 1, 12) == "today_macro_") {
                suffix := SubStr(keyName, 13)
                ctrl.Value := todayStats.Has("macro_" . suffix) ? todayStats["macro_" . suffix] : 0
            } else if (SubStr(keyName, 1, 9) == "all_json_") {
                suffix := SubStr(keyName, 10)
                ctrl.Value := allStats.Has("json_" . suffix) ? allStats["json_" . suffix] : 0
            } else if (SubStr(keyName, 1, 11) == "today_json_") {
                suffix := SubStr(keyName, 12)
                ctrl.Value := todayStats.Has("json_" . suffix) ? todayStats["json_" . suffix] : 0
            }
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
    if (!macroExecutionLog || macroExecutionLog.Length == 0) {
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
    if (result == "Yes") {
        try {
            macroExecutionLog := []
            InvalidateTodayStatsCache()
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
        
        ; Load configuration FIRST (before visualization rendering)
        ; This ensures all config settings are available when buttons render
        isFirstLaunch := !FileExist(configFile)
        LoadConfig()
        
        SetupHotkeys()
        InitializeWASDHotkeys()
        
        ; FAST PATH: Prime macros directly from config + merge simple state, then draw
        ; Config is now loaded, so visualizations will render with correct settings
        try {
            quickFromConfig := 0
            if (FileExist(configFile)) {
                quickFromConfig := ParseMacrosFromConfig()
            }
            quickFromState := LoadMacroState(true)
            quickTotal := quickFromConfig + quickFromState
            if (quickTotal > 0) {
                RefreshAllButtonAppearances()
                UpdateStatus("✅ Loaded " . quickTotal . " macros")
            }
        } catch {
        }

        ; Show first-launch wizard if this is first run
        if (isFirstLaunch) {
            ShowFirstLaunchWizard()
        }

        ; Startup complete

        ; Setup time tracking and auto-save
        SetTimer(UpdateActiveTime, 5000)  ; Update active time every 5 seconds
        SetTimer(AutoSave, 60000)  ; Auto-save every 60 seconds

        ; Setup cleanup
        OnExit((*) => CleanupAndExit())

        ; Show welcome message
        UpdateStatus("🚀 Data Labeling Assistant Ready - CapsLock+F to record")
        SetTimer(ShowWelcomeMessage, -2000)
        
    } catch Error as e {
        MsgBox("Initialization failed: " . e.Message, "Startup Error", "Icon!")
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

        ; Utility keys
        Hotkey("F12", (*) => ShowStatsMenu())

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
    if (eventCount == 0) {
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
        if (annotationMode == "Wide") {
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
    if (buttonName == "CapsLock" || buttonName == "f" || buttonName == "Space") {
        return
    }

    ExecuteMacro(buttonName)
}

ExecuteMacro(buttonName) {
    global awaitingAssignment, currentLayer, macroEvents, playback, focusDelay

    ; Double-check hotkey protection
    if (buttonName == "CapsLock" || buttonName == "f" || buttonName == "Space") {
        return
    }

    if (awaitingAssignment) {
        SetTimer(CheckForAssignment, 0)
        AssignToButton(buttonName)
        return
    }

    layerMacroName := "L" . currentLayer . "_" . buttonName
    if (!macroEvents.Has(layerMacroName) || macroEvents[layerMacroName].Length == 0) {
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

    if (events.Length == 1 && events[1].type == "jsonAnnotation") {
        ExecuteJsonAnnotation(events[1])
    } else {
        PlayEventsOptimized(events)
    }

    executionTime := A_TickCount - startTime

    ; RECORD EXECUTION STATS - CRITICAL FIX FOR STATS MENU
    ; Create analysis record for stats tracking
    analysisRecord := {
        boundingBoxCount: 0,
        conditionAssignments: "",
        jsonConditionName: "",
        severity: "medium"
    }

    ; Count bounding boxes and extract condition data for macro executions
    if (events.Length > 1 || (events.Length == 1 && events[1].type != "jsonAnnotation")) {
        bboxCount := 0
        conditionList := []

        for event in events {
            if (event.type == "boundingBox") {
                bboxCount++
                ; Extract condition type if assigned during recording
                if (event.HasOwnProp("conditionType") && event.conditionType >= 1 && event.conditionType <= 9) {
                    conditionList.Push(event.conditionType)
                }
            }
        }

        analysisRecord.boundingBoxCount := bboxCount
        if (conditionList.Length > 0) {
            conditionString := ""
            for i, deg in conditionList {
                conditionString .= (i > 1 ? "," : "") . deg
            }
            analysisRecord.conditionAssignments := conditionString
        }
    } else if (events.Length == 1 && events[1].type == "jsonAnnotation") {
        ; Extract JSON condition info for stats tracking
        jsonEvent := events[1]
        if (jsonEvent.HasOwnProp("categoryId") && conditionTypes.Has(jsonEvent.categoryId)) {
            analysisRecord.jsonConditionName := conditionTypes[jsonEvent.categoryId]
        }
        if (jsonEvent.HasOwnProp("severity")) {
            analysisRecord.severity := jsonEvent.severity
        }
    }

    RecordExecutionStatsAsync(buttonName, startTime, events.Length == 1 && events[1].type == "jsonAnnotation" ? "json_profile" : "macro", events, analysisRecord)

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
    
    if (nCode < 0 || !recording || currentMacro == "") {
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
    
    if (wParam == WM_LBUTTONDOWN) {
        isDrawingBox := true
        boxStartX := x
        boxStartY := y
        events.Push({type: "mouseDown", button: "left", x: x, y: y, time: timestamp})
        
    } else if (wParam == WM_LBUTTONUP) {
        if (isDrawingBox) {
            local dragDistX := Abs(x - boxStartX)
            local dragDistY := Abs(y - boxStartY)

            if (dragDistX > boxDragMinDistance && dragDistY > boxDragMinDistance) {
                ; Count existing bounding boxes to determine if this is the first
                local boxCount := 0
                for evt in events {
                    if (evt.type == "boundingBox")
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
        
    } else if (wParam == WM_MOUSEMOVE) {
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
    
    if (nCode < 0 || !recording || currentMacro == "") {
        return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "UInt", wParam, "Ptr", lParam)
    }
    
    static WM_KEYDOWN := 0x0100, WM_KEYUP := 0x0101
    local vkCode := NumGet(lParam, 0, "UInt")
    local keyName := GetKeyName("vk" . Format("{:X}", vkCode))
    
    ; Never record CapsLock+F, CapsLock+SPACE, or RCtrl
    if (keyName == "CapsLock" || keyName == "f" || keyName == "Space" || keyName == "RCtrl") {
        return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "UInt", wParam, "Ptr", lParam)
    }
    
    if (!macroEvents.Has(currentMacro))
        macroEvents[currentMacro] := []
    
    local events := macroEvents[currentMacro]
    local timestamp := A_TickCount
    
    if (wParam == WM_KEYDOWN) {
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
    
    if (!macroEvents.Has(currentMacro) || macroEvents[currentMacro].Length == 0) {
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

    if (macroEvents[currentMacro].HasOwnProp("recordedCanvas")) {
        rc := macroEvents[currentMacro].recordedCanvas
        macroEvents[layerMacroName].recordedCanvas := {
            left: rc.left,
            top: rc.top,
            right: rc.right,
            bottom: rc.bottom,
            mode: rc.mode
        }
        VizLog("COPIED recordedCanvas from " . currentMacro . " to " . layerMacroName)
        FlushVizLog()
    }

    macroEvents.Delete(currentMacro)

    events := macroEvents[layerMacroName]

    ; DEBUG: Verify condition types before saving
    VizLog("=== PRE-SAVE CHECK for " . layerMacroName . " ===")
    local boxCount := 0
    for evt in events {
        if (evt.type == "boundingBox") {
            boxCount++
            local degType := evt.HasOwnProp("conditionType") ? evt.conditionType : "MISSING"
            VizLog("  Box #" . boxCount . ": conditionType=" . degType)
        }
    }
    FlushVizLog()

    UpdateButtonAppearance(buttonName)
    SaveConfig()  ; Immediate persist for new macro assignments

    ; Persist an on-disk thumbnail so next startup loads visuals instantly
    try {
        SaveVisualizationThumbnailForButton(buttonName)
    } catch {
    }

    ; PERFORMANCE: Queue async save instead of blocking here
    global needsMacroStateSave
    needsMacroStateSave := true
    SetTimer(DoSaveMacroStateAsync, -200)

    UpdateStatus("✅ Assigned to " . buttonName . " Layer " . currentLayer . " (" . events.Length . " events)")
}

; Async wrapper for SaveMacroState to prevent blocking during assignment
DoSaveMacroStateAsync() {
    global needsMacroStateSave
    if (needsMacroStateSave) {
        needsMacroStateSave := false
        SaveConfig()
        SaveMacroState()
    }
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

        if (event.type == "boundingBox") {
            ; === INTELLIGENT TIMING: Box Drawing Sequence ===

            ; Step 1: Move to start position with smart timing
            MouseMove(event.left, event.top, 2)
            Sleep(smartBoxClickDelay)  ; Minimal delay for cursor positioning

            ; Step 2: Press mouse button using Click API
            Click "Down"
            Sleep(mouseClickDelay)  ; Brief pause during click

            ; Step 3: Drag to end position (speed 8 for accuracy)
            MouseMove(event.right, event.bottom, 8)
            Sleep(mouseReleaseDelay)  ; Brief pause before release

            ; Step 4: Release mouse button using Click API
            Click "Up"

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
        else if (event.type == "mouseDown") {
            ; If the next recorded event is a boundingBox, skip this mouseDown
            ; because the boundingBox handler performs its own press/release.
            nextEvent := (eventIndex < recordedEvents.Length) ? recordedEvents[eventIndex + 1] : ""
            if (IsObject(nextEvent) && nextEvent.HasOwnProp("type") && nextEvent.type == "boundingBox") {
                continue
            }

            if (event.HasOwnProp("x") && event.HasOwnProp("y")) {
                MouseMove(event.x, event.y, 2)
            }
            Sleep(smartBoxClickDelay)
            ; Use Click API for reliability
            Click event.x, event.y, "Down"
            Sleep(mouseClickDelay)
        }
        else if (event.type == "mouseUp") {
            ; If the previous recorded event was a boundingBox, skip this mouseUp
            ; because the boundingBox handler already released the button.
            prevEvent := (eventIndex > 1) ? recordedEvents[eventIndex - 1] : ""
            if (IsObject(prevEvent) && prevEvent.HasOwnProp("type") && prevEvent.type == "boundingBox") {
                continue
            }

            if (event.HasOwnProp("x") && event.HasOwnProp("y")) {
                MouseMove(event.x, event.y, 2)
            }
            Sleep(mouseReleaseDelay)
            ; Use Click API for reliability
            Click event.x, event.y, "Up"

            ; Ensure menu-open readiness between a click and the next action.
            ; Use recorded timing if available, but enforce a minimum smart menu delay.
            nextEvent := (eventIndex < recordedEvents.Length) ? recordedEvents[eventIndex + 1] : ""
            if (IsObject(nextEvent)) {
                try {
                    minMenuDelay := (smartMenuClickDelay > menuWaitDelay) ? smartMenuClickDelay : menuWaitDelay
                    if (event.HasOwnProp("time") && nextEvent.HasOwnProp("time")) {
                        delta := nextEvent.time - event.time
                        extra := delta - mouseReleaseDelay
                        if (extra < (minMenuDelay - mouseReleaseDelay))
                            extra := (minMenuDelay - mouseReleaseDelay)
                        if (extra > 0)
                            Sleep(extra)
                    } else {
                        Sleep(minMenuDelay)
                    }
                } catch {
                    ; Fallback safety
                    Sleep(smartMenuClickDelay)
                }
            }
        }
        else if (event.type == "click") {
            ; Recorded streams include mouseDown + click + mouseUp for simple clicks.
            ; The down/up handlers perform the actual click. Ignore this marker to prevent double-clicks.
            continue
        }
        else if (event.type == "keyDown") {
            if (event.HasOwnProp("key") && event.key != "") {
                Send("{" . event.key . " Down}")
                Sleep(keyPressDelay)
            }
        }
        else if (event.type == "keyUp") {
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

; Fast placeholder render (currently unused). Kept for potential future use.
; Does not create HBITMAPs — only shows simple text/background immediately.
FastRefreshButtonPlaceholders() {
    global buttonGrid, buttonPictures, buttonNames, macroEvents, currentLayer, conditionTypes, conditionColors

    for buttonName in buttonNames {
        try {
            if (!buttonGrid.Has(buttonName))
                continue

            layerMacroName := "L" . currentLayer . "_" . buttonName
            button := buttonGrid[buttonName]
            picture := buttonPictures[buttonName]

            hasMacro := macroEvents.Has(layerMacroName) && macroEvents[layerMacroName].Length > 0
            if (!hasMacro) {
                ; Leave as default empty tile
                button.Visible := true
                if (picture)
                    picture.Visible := false
                continue
            }

            events := macroEvents[layerMacroName]
            if (events.Length == 1 && events[1].type == "jsonAnnotation") {
                jsonEvent := events[1]
                typeName := "JSON"
                try {
                    if (conditionTypes.Has(jsonEvent.categoryId))
                        typeName := StrTitle(conditionTypes[jsonEvent.categoryId])
                } catch {
                }
                jsonInfo := typeName
                try {
                    if (jsonEvent.HasOwnProp("severity"))
                        jsonInfo .= " " . StrUpper(jsonEvent.severity)
                } catch {
                }
                jsonColor := "0xFFD700"
                try {
                    if (conditionColors.Has(jsonEvent.categoryId))
                        jsonColor := conditionColors[jsonEvent.categoryId]
                } catch {
                }

                if (picture)
                    picture.Visible := false
                button.Visible := true
                button.Opt("+Background" . jsonColor)
                button.SetFont("s7 bold", "cBlack")
                button.Text := jsonInfo
            } else {
                if (picture)
                    picture.Visible := false
                button.Visible := true
                button.Opt("+Background0x3A3A3A")
                button.SetFont("s7 bold", "cWhite")
                button.Text := "MACRO`n" . events.Length . " events"
            }
        } catch {
            ; Ignore individual tile errors in fast path
        }
    }
}

; Persist a PNG thumbnail for a button's current macro visualization to enable
; instant startup loading without heavy rendering.
SaveVisualizationThumbnailForButton(buttonName) {
    global currentLayer, macroEvents, buttonGrid, thumbnailDir, buttonThumbnails
    global gdiPlusInitialized

    try {
        if (!gdiPlusInitialized)
            InitializeVisualizationSystem()

        layerMacroName := "L" . currentLayer . "_" . buttonName
        if (!macroEvents.Has(layerMacroName) || macroEvents[layerMacroName].Length = 0)
            return false

        ; Get button dimensions to generate a correctly sized image
        if (!buttonGrid.Has(buttonName))
            return false
        buttonGrid[buttonName].GetPos(, , &btnW, &btnH)
        buttonDims := {width: btnW, height: btnH}
        ; Create an in-memory HBITMAP visualization
        hbm := CreateHBITMAPVisualization(macroEvents[layerMacroName], buttonDims)
        if (!hbm)
            return false

        ; Temporarily increment ref so saving doesn't invalidate cache/active display
        AddHBITMAPReference(hbm)

        ; Convert HBITMAP -> GDI+ Bitmap (does not take ownership)
        bitmap := 0
        DllCall("gdiplus\\GdipCreateBitmapFromHBITMAP", "Ptr", hbm, "Ptr", 0, "Ptr*", &bitmap)
        if (!bitmap) {
            RemoveHBITMAPReference(hbm)
            return false
        }

        ; Prepare PNG encoder CLSID: 557CF406-1A04-11D3-9A73-0000F81EF32E
        pngClsid := Buffer(16, 0)
        NumPut("UInt", 0x557CF406, pngClsid, 0)
        NumPut("UShort", 0x1A04, pngClsid, 4)
        NumPut("UShort", 0x11D3, pngClsid, 6)
        ; Data4 bytes
        NumPut("UChar", 0x9A, pngClsid, 8)
        NumPut("UChar", 0x73, pngClsid, 9)
        NumPut("UChar", 0x00, pngClsid, 10)
        NumPut("UChar", 0x00, pngClsid, 11)
        NumPut("UChar", 0xF8, pngClsid, 12)
        NumPut("UChar", 0x1E, pngClsid, 13)
        NumPut("UChar", 0xF3, pngClsid, 14)
        NumPut("UChar", 0x2E, pngClsid, 15)

        ; Ensure thumbnail dir exists
        try {
            if !DirExist(thumbnailDir)
                DirCreate(thumbnailDir)
        }

        filePath := thumbnailDir . "\\" . layerMacroName . ".png"
        ; Save bitmap to file
        res := DllCall("gdiplus\\GdipSaveImageToFile", "Ptr", bitmap, "WStr", filePath, "Ptr", pngClsid, "Ptr", 0)

        ; Cleanup
        DllCall("gdiplus\\GdipDisposeImage", "Ptr", bitmap)
        RemoveHBITMAPReference(hbm)

        if (res = 0) {
            buttonThumbnails[layerMacroName] := filePath
            ; Persist mapping in simple state for next startup
            try {
                SaveMacroState()
            }
            return true
        }
    } catch {
    }
    return false
}

UpdateButtonAppearance(buttonName) {
    global buttonGrid, buttonPictures, buttonThumbnails, macroEvents, darkMode, currentLayer, conditionTypes, conditionColors, buttonDisplayedHBITMAPs

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
    ; Fallback to default thumbnail path if mapping missing
    if (!hasThumbnail) {
        defaultThumb := thumbnailDir . "\\" . layerMacroName . ".png"
        if (FileExist(defaultThumb)) {
            hasThumbnail := true
            buttonThumbnails[layerMacroName] := defaultThumb
        }
    }

    isJsonAnnotation := false
    jsonInfo := ""
    jsonColor := "0xFFD700"

    if (hasMacro && macroEvents[layerMacroName].Length == 1 && macroEvents[layerMacroName][1].type == "jsonAnnotation") {
        isJsonAnnotation := true
        jsonEvent := macroEvents[layerMacroName][1]
        typeName := StrTitle(conditionTypes[jsonEvent.categoryId])
        ; Remove mode from text - will be shown visually via letterboxing
        jsonInfo := typeName . " " . StrUpper(jsonEvent.severity)

        if (conditionColors.Has(jsonEvent.categoryId)) {
            jsonColor := conditionColors[jsonEvent.categoryId]
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
                ; Check if this HBITMAP is already displayed on this button
                if (oldHbitmap == hbitmap && oldHbitmapValid) {
                    VizLog(">>> UpdateButtonAppearance: HBITMAP already displayed, skipping reassignment")
                    FlushVizLog()
                    return
                }

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
                    if (event.type == "boundingBox") {
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

    if (minMax == -1)
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
; ===== CONTEXT MENUS =====
ShowContextMenu(buttonName, *) {
    global currentLayer, conditionTypes, severityLevels
    
    contextMenu := Menu()
    
    contextMenu.Add("🎥 Record Macro", (*) => F9_RecordingOnly())  ; Use F9 handler
    contextMenu.Add("🗑️ Clear Macro", (*) => ClearMacro(buttonName))
    contextMenu.Add("🏷️ Edit Label", (*) => EditCustomLabel(buttonName))
    contextMenu.Add()
    
    jsonMainMenu := Menu()
    
    for id, typeName in conditionTypes {
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
        InvalidateTodayStatsCache()
        
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
    tabs := settingsGui.Add("Tab3", "x20 y40 w520 h520", ["⚙️ Essential", "⚡ Execution Timing", "🎹 Hotkeys", "🎨 Conditions"])

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

    ; Stats reset
    settingsGui.Add("Text", "x30 y260 w480 h18", "📊 Statistics")
    btnResetStats := settingsGui.Add("Button", "x40 y283 w180 h28", "📊 Reset All Stats")
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

    ; TAB 4: Conditions Configuration
    tabs.UseTab(4)
    settingsGui.SetFont("s9")

    ; Header
    settingsGui.Add("Text", "x30 y75 w480 h20", "🎨 Label Configuration")
    settingsGui.SetFont("s8")
    settingsGui.Add("Text", "x30 y98 w480 h14 c0x666666", "Customize label names and visualization colors")
    settingsGui.SetFont("s9")

    ; Create streamlined list of labels
    global conditionConfig
    conditionY := 125
    conditionEditControls := Map()  ; Store references to edit controls

    Loop 9 {
        conditionId := A_Index
        config := conditionConfig[conditionId]

        ; ID number
        settingsGui.Add("Text", "x30 y" . (conditionY + 5) . " w20 h20", conditionId . ":")

        ; Name Edit
        nameEdit := settingsGui.Add("Edit", "x55 y" . conditionY . " w240 h26", config.displayName)

        ; Color picker button
        btnPickColor := settingsGui.Add("Button", "x305 y" . conditionY . " w80 h26", "🎨 Pick")

    ; Color hex display (editable for manual entry)
    ; Reduce width slightly to fit live preview swatch
    colorDisplay := settingsGui.Add("Edit", "x395 y" . conditionY . " w90 h26 Center", config.color)
    colorDisplay.SetFont("s8")

    ; Live color preview swatch
    preview := settingsGui.Add("Text", "x" . (395 + 95) . " y" . (conditionY + 3) . " w20 h20 +Border", "")
    preview.Opt("+Background" . config.color)

        ; Store controls reference
        conditionEditControls[conditionId] := {
            name: nameEdit,
            colorDisplay: colorDisplay,
            preview: preview,
            currentColor: config.color
        }
        ; Update preview live when hex edit changes (freeze conditionId)
        colorDisplay.OnEvent("Change", CreateHexChangeHandler(conditionId, conditionEditControls))
        ; Open picker for this specific label (freeze conditionId)
        btnPickColor.OnEvent("Click", CreatePickLabelHandler(conditionId, conditionEditControls, settingsGui))

        conditionY += 32
    }

    ; Action buttons
    conditionY += 15
    btnApplyConditions := settingsGui.Add("Button", "x30 y" . conditionY . " w180 h30", "✅ Apply All Changes")
    btnApplyConditions.OnEvent("Click", (*) => ApplyConditionSettings(conditionEditControls, settingsGui))

    btnResetConditions := settingsGui.Add("Button", "x225 y" . conditionY . " w150 h30", "🔄 Reset to Defaults")
    btnResetConditions.OnEvent("Click", (*) => ResetConditionSettings(settingsGui))

    conditionY += 38

    ; Instructions
    settingsGui.SetFont("s8 Bold c0x0066CC")
    settingsGui.Add("Text", "x30 y" . conditionY . " w480 h14", "💡 How to Customize:")
    conditionY += 18
    settingsGui.SetFont("s8")
    settingsGui.Add("Text", "x30 y" . conditionY . " w480 h40", "• Edit the name field to customize how the label appears`n• Click 🎨 Color to pick a visualization color (common colors available)`n• Click 'Apply All Changes' to save and activate your customizations")
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
        if (annotationMode == "Narrow") {
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

    if (currentState == "Wide") {
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
    global macroEvents, conditionTypes, buttonNames, totalLayers, jsonAnnotations, currentLayer
    
    updatedCount := 0
    Loop totalLayers {
        layer := A_Index
        for buttonName in buttonNames {
            layerMacroName := "L" . layer . "_" . buttonName
            if (macroEvents.Has(layerMacroName) && macroEvents[layerMacroName].Length == 1 && macroEvents[layerMacroName][1].type == "jsonAnnotation") {
                jsonEvent := macroEvents[layerMacroName][1]
                typeName := StrTitle(conditionTypes[jsonEvent.categoryId])
                presetName := typeName . " (" . StrTitle(jsonEvent.severity) . ")" . (newMode = "Narrow" ? " Narrow" : "")
                
                if (jsonAnnotations.Has(presetName)) {
                    ; Update the annotation
                    jsonEvent.annotation := jsonAnnotations[presetName]
                    jsonEvent.mode := newMode
                    updatedCount++
                    
                    ; Update button appearance if it's on current layer
                    if (layer == currentLayer) {
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
    global currentLayer, macroEvents, jsonAnnotations, conditionTypes, annotationMode
    
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
        for id, name in conditionTypes {
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

InitializeJsonAnnotations() {
    global jsonAnnotations, conditionTypes, severityLevels
    
    ; Clear any existing annotations
    jsonAnnotations := Map()
    
    ; Create annotations for all condition types and severity levels in both modes
    for id, typeName in conditionTypes {
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
    if (mode == "Wide") {
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
                if (event.type == "boundingBox") {
                    stateContent .= macroName . "=boundingBox," . event.left . "," . event.top . "," . event.right . "," . event.bottom . "`n"
                }
                else if (event.type == "jsonAnnotation") {
                    stateContent .= macroName . "=jsonAnnotation," . event.mode . "," . event.categoryId . "," . event.severity . "`n"
                }
                else if (event.type == "keyDown") {
                    keyVal := event.HasOwnProp("key") ? event.key : ""
                    stateContent .= macroName . "=keyDown," . keyVal . "`n"
                }
                else if (event.type == "keyUp") {
                    keyVal := event.HasOwnProp("key") ? event.key : ""
                    stateContent .= macroName . "=keyUp," . keyVal . "`n"
                }
                else if (event.type == "mouseDown") {
                    buttonVal := event.HasOwnProp("button") ? event.button : "left"
                    xVal := event.HasOwnProp("x") ? event.x : ""
                    yVal := event.HasOwnProp("y") ? event.y : ""
                    stateContent .= macroName . "=mouseDown," . xVal . "," . yVal . "," . buttonVal . "`n"
                }
                else if (event.type == "mouseUp") {
                    buttonVal := event.HasOwnProp("button") ? event.button : "left"
                    xVal := event.HasOwnProp("x") ? event.x : ""
                    yVal := event.HasOwnProp("y") ? event.y : ""
                    stateContent .= macroName . "=mouseUp," . xVal . "," . yVal . "," . buttonVal . "`n"
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

LoadMacroState(preserveExisting := false) {
    global macroEvents, buttonThumbnails, configFile
    
    stateFile := StrReplace(configFile, ".ini", "_simple.txt")
    
    if !FileExist(stateFile)
        return 0
    
    if (!preserveExisting)
        macroEvents := Map()
    buttonThumbnails := Map()
    
    content := FileRead(stateFile)
    lines := StrSplit(content, "`n")
    
    macroCount := 0
    for line in lines {
        line := Trim(line)
        if (line == "")
            continue
            
        if (InStr(line, "=")) {
            equalPos := InStr(line, "=")
            macroName := SubStr(line, 1, equalPos - 1)
            data := SubStr(line, equalPos + 1)
            parts := StrSplit(data, ",")
            
            if (parts.Length >= 1) {
                event := {}
                
                if (parts[1] == "boundingBox" && parts.Length >= 5) {
                    event := {
                        type: "boundingBox",
                        left: Integer(parts[2]),
                        top: Integer(parts[3]),
                        right: Integer(parts[4]),
                        bottom: Integer(parts[5])
                    }
                }
                else if (parts[1] == "jsonAnnotation" && parts.Length >= 4) {
                    event := {
                        type: "jsonAnnotation",
                        mode: parts[2],
                        categoryId: Integer(parts[3]),
                        severity: parts[4],
                        annotation: BuildJsonAnnotation(parts[2], Integer(parts[3]), parts[4])
                    }
                }
                else if (parts[1] == "keyDown" && parts.Length >= 2) {
                    event := {
                        type: "keyDown",
                        key: parts[2]
                    }
                }
                else if (parts[1] == "keyUp" && parts.Length >= 2) {
                    event := {
                        type: "keyUp",
                        key: parts[2]
                    }
                }
                else if (parts[1] == "mouseDown" && parts.Length >= 4) {
                    event := {
                        type: "mouseDown",
                        x: Integer(parts[2]),
                        y: Integer(parts[3]),
                        button: parts[4]
                    }
                }
                else if (parts[1] == "mouseUp" && parts.Length >= 4) {
                    event := {
                        type: "mouseUp",
                        x: Integer(parts[2]),
                        y: Integer(parts[3]),
                        button: parts[4]
                    }
                }
                else if (parts[1] == "recordedMode" && parts.Length >= 2) {
                    ; Load recordedMode property and attach it to the macro array
                    if (!macroEvents.Has(macroName)) {
                        macroEvents[macroName] := []
                        macroCount++
                    }
                    macroEvents[macroName].recordedMode := parts[2]
                    continue
                }
                else if (parts[1] == "recordedCanvas" && parts.Length >= 5) {
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
                else if (parts[1] == "thumbnail" && parts.Length >= 2) {
                    thumbnailPath := parts[2]
                    if (FileExist(thumbnailPath)) {
                        buttonThumbnails[macroName] := thumbnailPath
                    }
                    continue
                }

                    if (!preserveExisting && event.HasOwnProp("type")) {
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

ResetStatsFromSettings(parentGui) {
    global macroExecutionLog, masterStatsCSV, workDir

    if (MsgBox("Reset all statistics data?`n`nThis will clear execution logs but preserve macros.", "Confirm Stats Reset", "YesNo Icon!") = "Yes") {
        try {
            macroExecutionLog := []
            InvalidateTodayStatsCache()

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
        configContent .= "isNarrowCanvasCalibrated=" . (isNarrowCanvasCalibrated ? 1 : 0) . "`n`n"

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

        ; Add conditions section
        global conditionConfig
        configContent .= "[Conditions]`n"
        for id, config in conditionConfig {
            configContent .= "ConditionName_" . id . "=" . config.name . "`n"
            configContent .= "ConditionDisplayName_" . id . "=" . config.displayName . "`n"
            configContent .= "ConditionColor_" . id . "=" . config.color . "`n"
            configContent .= "ConditionStatKey_" . id . "=" . config.statKey . "`n"
        }
        configContent .= "`n"

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
                        if (event.type == "jsonAnnotation") {
                            if (eventCount > 1) eventsStr .= "|"
                            eventsStr .= event.type . ",mode=" . event.mode . ",cat=" . event.categoryId . ",sev=" . event.severity
                        } else if (event.type == "boundingBox") {
                            conditionType := event.HasOwnProp("conditionType") ? event.conditionType : 1
                            conditionName := event.HasOwnProp("conditionName") ? event.conditionName : "condition_1"
                            isTagged := event.HasOwnProp("isTagged") ? event.isTagged : false
                            if (eventCount > 1) eventsStr .= "|"
                            eventsStr .= event.type . "," . event.left . "," . event.top . "," . event.right . "," . event.bottom . ",deg=" . conditionType . ",name=" . conditionName . ",tagged=" . isTagged
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
            if (line == "")
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

                if (currentSection == "General") {
                    if (key == "CurrentLayer") {
                        potentialLayer := Integer(value)
                        if (potentialLayer >= 1 && potentialLayer <= totalLayers)
                            currentLayer := potentialLayer
                        else
                            currentLayer := 1  ; Reset to default if invalid
                    } else if (key == "AnnotationMode") {
                        if (value == "Wide" || value == "Narrow")
                            annotationMode := value
                        else
                            annotationMode := "Wide"  ; Reset to default if invalid
                    }
                } else if (currentSection == "Canvas") {
                    ; Load canvas calibration data
                    if (key == "wideCanvasLeft") {
                        wideCanvasLeft := value != "" ? value + 0.0 : 0.0
                    } else if (key == "wideCanvasTop") {
                        wideCanvasTop := value != "" ? value + 0.0 : 0.0
                    } else if (key == "wideCanvasRight") {
                        wideCanvasRight := value != "" ? value + 0.0 : 0.0
                    } else if (key == "wideCanvasBottom") {
                        wideCanvasBottom := value != "" ? value + 0.0 : 0.0
                    } else if (key == "isWideCanvasCalibrated") {
                        valueLower := StrLower(value)
                        isWideCanvasCalibrated := !(valueLower == "" || valueLower == "0" || valueLower == "false" || valueLower == "no" || valueLower == "off")
                    } else if (key == "narrowCanvasLeft") {
                        narrowCanvasLeft := value != "" ? value + 0.0 : 0.0
                    } else if (key == "narrowCanvasTop") {
                        narrowCanvasTop := value != "" ? value + 0.0 : 0.0
                    } else if (key == "narrowCanvasRight") {
                        narrowCanvasRight := value != "" ? value + 0.0 : 0.0
                    } else if (key == "narrowCanvasBottom") {
                        narrowCanvasBottom := value != "" ? value + 0.0 : 0.0
                    } else if (key == "isNarrowCanvasCalibrated") {
                        valueLower := StrLower(value)
                        isNarrowCanvasCalibrated := !(valueLower == "" || valueLower == "0" || valueLower == "false" || valueLower == "no" || valueLower == "off")
                    }
                } else if (currentSection == "Timing") {
                    ; Load timing configuration
                    global boxDrawDelay, mouseClickDelay, mouseDragDelay, mouseReleaseDelay, betweenBoxDelay, keyPressDelay, focusDelay
                    global smartBoxClickDelay, smartMenuClickDelay, firstBoxDelay, menuWaitDelay, mouseHoverDelay

                    if (key == "boxDrawDelay") {
                        boxDrawDelay := Integer(value)
                    } else if (key == "mouseClickDelay") {
                        mouseClickDelay := Integer(value)
                    } else if (key == "mouseDragDelay") {
                        mouseDragDelay := Integer(value)
                    } else if (key == "mouseReleaseDelay") {
                        mouseReleaseDelay := Integer(value)
                    } else if (key == "betweenBoxDelay") {
                        betweenBoxDelay := Integer(value)
                    } else if (key == "keyPressDelay") {
                        keyPressDelay := Integer(value)
                    } else if (key == "focusDelay") {
                        focusDelay := Integer(value)
                    } else if (key == "smartBoxClickDelay") {
                        smartBoxClickDelay := Integer(value)
                    } else if (key == "smartMenuClickDelay") {
                        smartMenuClickDelay := Integer(value)
                    } else if (key == "firstBoxDelay") {
                        firstBoxDelay := Integer(value)
                    } else if (key == "menuWaitDelay") {
                        menuWaitDelay := Integer(value)
                    } else if (key == "mouseHoverDelay") {
                        mouseHoverDelay := Integer(value)
                    }
                } else if (currentSection == "Hotkeys") {
                    ; Load hotkey configuration
                    global hotkeyRecordToggle, hotkeySubmit, hotkeyDirectClear, hotkeyUtilitySubmit, hotkeyUtilityBackspace
                    global hotkeyStats, hotkeyBreakMode, hotkeySettings, utilityHotkeysEnabled

                    if (key == "hotkeyRecordToggle") {
                        hotkeyRecordToggle := value
                    } else if (key == "hotkeySubmit") {
                        hotkeySubmit := value
                    } else if (key == "hotkeyDirectClear") {
                        hotkeyDirectClear := value
                    } else if (key == "hotkeyUtilitySubmit") {
                        hotkeyUtilitySubmit := value
                    } else if (key == "hotkeyUtilityBackspace") {
                        hotkeyUtilityBackspace := value
                    } else if (key == "hotkeyStats") {
                        hotkeyStats := value
                    } else if (key == "hotkeyBreakMode") {
                        hotkeyBreakMode := value
                    } else if (key == "hotkeySettings") {
                        hotkeySettings := value
                    } else if (key == "utilityHotkeysEnabled") {
                        valueLower := StrLower(value)
                        utilityHotkeysEnabled := !(valueLower = "" || valueLower = "0" || valueLower = "false" || valueLower = "no" || valueLower = "off")
                    }
                } else if (currentSection == "conditions" || currentSection == "Conditions") {
                    ; Load condition configuration (backward compatible with legacy 'conditions')
                    global conditionConfig

                    ; Parse condition settings (ConditionName_1, ConditionColor_1, etc.) and legacy
                    if (RegExMatch(key, "^(?:condition|Condition)Name_(\d+)$", &match)) {
                        conditionId := Integer(match[1])
                        if (!conditionConfig.Has(conditionId)) {
                            conditionConfig[conditionId] := {name: "", displayName: "", color: "0xFFFFFF", statKey: ""}
                        }
                        conditionConfig[conditionId].name := value
                    } else if (RegExMatch(key, "^(?:condition|Condition)DisplayName_(\d+)$", &match)) {
                        conditionId := Integer(match[1])
                        if (!conditionConfig.Has(conditionId)) {
                            conditionConfig[conditionId] := {name: "", displayName: "", color: "0xFFFFFF", statKey: ""}
                        }
                        conditionConfig[conditionId].displayName := value
                    } else if (RegExMatch(key, "^(?:condition|Condition)Color_(\d+)$", &match)) {
                        conditionId := Integer(match[1])
                        if (!conditionConfig.Has(conditionId)) {
                            conditionConfig[conditionId] := {name: "", displayName: "", color: "0xFFFFFF", statKey: ""}
                        }
                        conditionConfig[conditionId].color := value
                    } else if (RegExMatch(key, "^(?:condition|Condition)StatKey_(\d+)$", &match)) {
                        conditionId := Integer(match[1])
                        if (!conditionConfig.Has(conditionId)) {
                            conditionConfig[conditionId] := {name: "", displayName: "", color: "0xFFFFFF", statKey: ""}
                        }
                        conditionConfig[conditionId].statKey := value
                    }
                } else if (currentSection == "Labels") {
                    if (buttonCustomLabels.Has(key)) {
                        buttonCustomLabels[key] := value
                    }
                }
            }
        }
        
        ; Sync legacy condition maps after loading custom config
        SyncLegacyConditionMaps()

        ; Load macros from config file
        macrosLoaded := ParseMacrosFromConfig()

        ; Update mode toggle button to match loaded setting
        if (modeToggleBtn) {
            if (annotationMode == "Narrow") {
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

        ; Merge legacy metadata (thumbnails/canvas) from simple state file
        LoadMacroState(true)

        ; Fallback to legacy macro state if nothing restored yet
        if (macrosLoaded == 0) {
            legacyLoaded := LoadMacroState()
            if (legacyLoaded > 0) {
                macrosLoaded := legacyLoaded
                SaveConfig()
                VizLog("Loaded " . macrosLoaded . " macros from legacy state file")
                FlushVizLog()
            }
        }

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

ParseRecordedCanvasLine(line) {
    if (!line)
        return ""

    parts := StrSplit(line, ",")
    if (parts.Length < 4)
        return ""

    canvas := {
        left: parts[1] != "" ? parts[1] + 0.0 : 0.0,
        top: parts[2] != "" ? parts[2] + 0.0 : 0.0,
        right: parts[3] != "" ? parts[3] + 0.0 : 0.0,
        bottom: parts[4] != "" ? parts[4] + 0.0 : 0.0
    }

    if (parts.Length >= 5) {
        canvas.mode := Trim(parts[5])
    }

    return canvas
}

BuildMacroEventsFromString(serializedEvents) {
    events := []
    if (!serializedEvents)
        return events

    eventLines := StrSplit(serializedEvents, "|")
    for eventLine in eventLines {
        eventLine := Trim(eventLine)
        if (eventLine == "")
            continue

        parts := StrSplit(eventLine, ",")
        if (parts.Length == 0)
            continue

        if (parts[1] == "jsonAnnotation") {
            mode := StrReplace(parts[2], "mode=", "")
            catId := Integer(StrReplace(parts[3], "cat=", ""))
            sev := StrReplace(parts[4], "sev=", "")
            events.Push({
                type: "jsonAnnotation",
                annotation: BuildJsonAnnotation(mode, catId, sev),
                mode: mode,
                categoryId: catId,
                severity: sev
            })
            continue
        }

        if (parts[1] == "boundingBox" && parts.Length >= 5) {
            event := {
                type: "boundingBox",
                left: Integer(parts[2]),
                top: Integer(parts[3]),
                right: Integer(parts[4]),
                bottom: Integer(parts[5])
            }

            ; Parse optional key=value attributes saved by SaveConfig
            if (parts.Length >= 6) {
                Loop (parts.Length - 5) {
                    idx := A_Index + 5
                    if (idx > parts.Length)
                        break
                    token := parts[idx]
                    if (SubStr(token, 1, 4) == "deg=") {
                        val := SubStr(token, 5)
                        if (val != "")
                            event.conditionType := Integer(val)
                    } else if (SubStr(token, 1, 5) == "name=") {
                        val := SubStr(token, 6)
                        if (val != "")
                            event.conditionName := val
                    } else if (SubStr(token, 1, 7) == "tagged=") {
                        val := StrLower(SubStr(token, 8))
                        event.isTagged := !(val == "" || val == "0" || val == "false" || val == "no" || val == "off")
                    }
                }
            }

            ; Defaults for missing fields
            if (!event.HasOwnProp("conditionType"))
                event.conditionType := 1
            if (!event.HasOwnProp("conditionName"))
                event.conditionName := "condition_1"
            if (!event.HasOwnProp("isTagged"))
                event.isTagged := false

            events.Push(event)
            continue
        }

        event := {type: parts[1]}
        if (parts.Length > 1 && parts[2] != "")
            event.key := parts[2]
        if (parts.Length > 2 && parts[3] != "")
            event.x := Integer(parts[3])
        if (parts.Length > 3 && parts[4] != "")
            event.y := Integer(parts[4])

        events.Push(event)
    }

    return events
}

ParseMacrosFromConfig() {
    global configFile, macroEvents, buttonNames, totalLayers

    macrosLoaded := 0
    macroEvents := Map()

    Loop totalLayers {
        layer := A_Index
        for buttonName in buttonNames {
            layerMacroName := "L" . layer . "_" . buttonName
            macroString := IniRead(configFile, "Macros", layerMacroName, "")
            if (macroString == "")
                continue

            events := BuildMacroEventsFromString(macroString)
            if (events.Length == 0)
                continue

            macroEvents[layerMacroName] := events

            recordedMode := IniRead(configFile, "Macros", layerMacroName . "_recordedMode", "")
            if (recordedMode != "")
                macroEvents[layerMacroName].recordedMode := recordedMode

            recordedCanvasLine := IniRead(configFile, "Macros", layerMacroName . "_recordedCanvas", "")
            if (recordedCanvasLine != "") {
                canvas := ParseRecordedCanvasLine(recordedCanvasLine)
                if (canvas)
                    macroEvents[layerMacroName].recordedCanvas := canvas
            }

            macrosLoaded++
        }
    }

    return macrosLoaded
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
        UpdateStatus("📂 Loaded from slot " . slotNumber)
        return true
        
    } catch Error as e {
        UpdateStatus("⚠️ Load from slot failed: " . e.Message)
        return false
    }
}

; ===== ANALYSIS FUNCTIONS =====
AnalyzeRecordedMacro(macroKey) {
    global macroEvents

    VizLog(">>> AnalyzeRecordedMacro called for: " . macroKey)
    FlushVizLog()

    if (!macroEvents.Has(macroKey)) {
        VizLog(">>> ERROR: macroKey not found in macroEvents!")
        FlushVizLog()
        return
    }

    local events := macroEvents[macroKey]
    VizLog(">>> Events count: " . events.Length)
    FlushVizLog()

    local boundingBoxCount := 0

    local conditionAnalysis := AnalyzeconditionPattern(events)
    
    for event in events {
        if (event.type == "boundingBox") {
            boundingBoxCount++
        }
    }
    
    if (boundingBoxCount > 0) {
        local statusMsg := "📦 Recorded " . boundingBoxCount . " boxes"
        
        if (conditionAnalysis.summary != "") {
            statusMsg .= " | " . conditionAnalysis.summary
        }
        
        UpdateStatus(statusMsg)
    }
}

AnalyzeconditionPattern(events) {
    global conditionTypes
    
    local boxes := []
    local keyPresses := []
    
    for event in events {
        if (event.type == "boundingBox") {
            boxes.Push({
                index: boxes.Length + 1,
                time: event.HasOwnProp("time") ? event.time : 0,
                event: event,
                conditionType: 1,
                assignedBy: "default"
            })
        } else if (event.type == "keyDown" && event.HasOwnProp("key") && IsNumberKey(event.key)) {
            local keyNum := GetNumberFromKey(event.key)
            if (keyNum >= 1 && keyNum <= 9) {
                keyPresses.Push({
                    time: event.HasOwnProp("time") ? event.time : 0,
                    conditionType: keyNum,
                    key: event.key
                })
            }
        }
    }

    ; DEBUG: Log what we found
    VizLog("=== condition ANALYSIS ===")
    VizLog("Found " . boxes.Length . " boxes and " . keyPresses.Length . " key presses")
    for kp in keyPresses {
        VizLog("  KeyPress: deg=" . kp.conditionType . " key=" . kp.key . " time=" . kp.time)
    }
    FlushVizLog()

    local currentConditionType := 1
    local conditionCounts := Map()
    
    for id, typeName in conditionTypes
    {
        conditionCounts[id] := 0
    }
    
    for boxIndex, box in boxes
    {
        local nextBoxTime := (boxIndex < boxes.Length) ? boxes[boxIndex + 1].time : 999999999

        VizLog("Box #" . boxIndex . ": time=" . box.time . " nextBoxTime=" . nextBoxTime)

        local closestKeyPress := ""
        local closestTime := 999999999

        for keyPress in keyPresses {
            if (keyPress.time > box.time && keyPress.time < nextBoxTime && keyPress.time < closestTime) {
                closestKeyPress := keyPress
                closestTime := keyPress.time
                VizLog("  MATCHED keyPress deg=" . keyPress.conditionType . " at time=" . keyPress.time)
            }
        }

        if (closestKeyPress != "") {
            currentConditionType := closestKeyPress.conditionType
            box.conditionType := currentConditionType
            box.assignedBy := "user_selection"
            VizLog("  ASSIGNED deg=" . currentConditionType . " (user_selection)")
        } else {
            box.conditionType := currentConditionType
            box.assignedBy := "auto_default"
            VizLog("  ASSIGNED deg=" . currentConditionType . " (auto_default)")
        }
        
        conditionCounts[box.conditionType]++
        
        box.event.conditionType := box.conditionType
        box.event.conditionName := conditionTypes[box.conditionType]
        box.event.assignedBy := box.assignedBy
    }
    
    local totalBoxes := 0
    local summary := []
    
    for id, count in conditionCounts {
        if (count > 0) {
            totalBoxes += count
            local typeName := StrTitle(conditionTypes[id])
            summary.Push(count . "x" . typeName)
        }
    }
    
    return {
        totalBoxes: totalBoxes,
        summary: summary.Length > 0 ? JoinArray(summary, ", ") : "",
        counts: conditionCounts,
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

        ; Save final session time marker to preserve active time
        SaveSessionEndMarker()

        SaveConfig()
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

; ===== START APPLICATION =====
Main()
