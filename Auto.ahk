#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"
Persistent

; === ERROR HANDLING ===
OnError(GlobalErrorHandler)

GlobalErrorHandler(err, *) {
    global workDir
    LogError("Unhandled exception: " err.Message " at " err.File ":" err.Line)
    MsgBox "Critical error: " err.Message "`nCheck " workDir "\debug.log for details.", "Error", 16
    StopAll()
    return -1
}

; === CONFIG ===
configFile := A_ScriptDir "\MacroLauncherX34.ini"
LoadConfig()

; === SETUP ===
workDir := config.workDir
try {
    if !DirExist(workDir)
        DirCreate workDir
    SetWorkingDir workDir
} catch as err {
    LogError("Failed to set working directory: " err.Message)
    MsgBox "Failed to set working directory: " err.Message
    ExitApp
}

; === GLOBALS ===
mainGui := 0
statusCtrl := ""
pauseBtn := ""
startBtn := ""
detectionModeCtrl := ""
continuous := false
paused := false
runCount := 0
currentAnnotation := ""
currentAnnotationType := ""
lastFilenameSeen := ""
lastTimerSeen := ""
hasExecutedThisCycle := false
retryCount := 0
maxRetries := config.maxRetries
lastDetectionTime := A_TickCount
lastExecutionTime := A_TickCount
lastClipboardAttempt := A_TickCount
lastSuccessfulExecution := A_TickCount
consecutiveRefreshes := 0

; === JSON ANNOTATIONS ===
wideAnnotation := config.wideAnnotation
narrowAnnotation := config.narrowAnnotation

; === INITIALIZE ===
try {
    InitGui()
    Hotkey(config.wideHotkey, (*) => StartContinuous(wideAnnotation, "Wide"))
    Hotkey(config.narrowHotkey, (*) => StartContinuous(narrowAnnotation, "Narrow"))
    Hotkey(config.emergencyHotkey, (*) => StopAll())
    UpdateStatus("Ready: Press " config.wideHotkey " for Wide, " config.narrowHotkey " for Narrow, or Start Auto (Run " runCount ")")
} catch as err {
    LogError("Init failed: " err.Message)
    MsgBox "Init failed: " err.Message
    ExitApp
}

; === LOAD CONFIG ===
LoadConfig() {
    global config := Map()
    config.workDir := IniRead(configFile, "Settings", "WorkDir", A_ScriptDir "\SegmentsAutoLabeler")
    config.wideHotkey := IniRead(configFile, "Settings", "WideHotkey", "F9")
    config.narrowHotkey := IniRead(configFile, "Settings", "NarrowHotkey", "F10")
    config.emergencyHotkey := IniRead(configFile, "Settings", "EmergencyHotkey", "F12")
    config.interval := IniRead(configFile, "Settings", "Interval", 50)
    config.pageLoadDelay := IniRead(configFile, "Settings", "PageLoadDelay", 800)
    config.maxRetries := IniRead(configFile, "Settings", "MaxRetries", 5)
    config.stuckTimeout := IniRead(configFile, "Settings", "StuckTimeout", 15000)
    config.refreshDelay := IniRead(configFile, "Settings", "RefreshDelay", 2000)
    config.executionTimeout := IniRead(configFile, "Settings", "ExecutionTimeout", 5000)
    config.stallTimeout := IniRead(configFile, "Settings", "StallTimeout", 20000)
    config.detectionMode := IniRead(configFile, "Settings", "DetectionMode", "Filename")
    config.defaultAnnotation := IniRead(configFile, "Settings", "DefaultAnnotation", "Wide")
    config.wideAnnotation := IniRead(configFile, "Annotations", "Wide", '{"is3DObject":false,"segmentsAnnotation":{"attributes":{"severity":"high"},"track_id":1,"type":"bbox","category_id":5,"points":[[-22.18,-22.57],[3808.41,2130.71]]}}')
    config.narrowAnnotation := IniRead(configFile, "Annotations", "Narrow", '{"is3DObject":false,"segmentsAnnotation":{"attributes":{"severity":"high"},"track_id":1,"type":"bbox","category_id":5,"points":[[-23.54,-23.12],[1891.76,1506.66]]}}')
    try {
        if !IsValidJson(config.wideAnnotation) || !IsValidJson(config.narrowAnnotation) {
            throw Error("Invalid JSON in annotations")
        }
        if !FileExist(configFile) {
            IniWrite(config.workDir, configFile, "Settings", "WorkDir")
            IniWrite(config.wideHotkey, configFile, "Settings", "WideHotkey")
            IniWrite(config.narrowHotkey, configFile, "Settings", "NarrowHotkey")
            IniWrite(config.emergencyHotkey, configFile, "Settings", "EmergencyHotkey")
            IniWrite(config.interval, configFile, "Settings", "Interval")
            IniWrite(config.pageLoadDelay, configFile, "Settings", "PageLoadDelay")
            IniWrite(config.maxRetries, configFile, "Settings", "MaxRetries")
            IniWrite(config.stuckTimeout, configFile, "Settings", "StuckTimeout")
            IniWrite(config.refreshDelay, configFile, "Settings", "RefreshDelay")
            IniWrite(config.executionTimeout, configFile, "Settings", "ExecutionTimeout")
            IniWrite(config.stallTimeout, configFile, "Settings", "StallTimeout")
            IniWrite(config.detectionMode, configFile, "Settings", "DetectionMode")
            IniWrite(config.defaultAnnotation, configFile, "Settings", "DefaultAnnotation")
            IniWrite(config.wideAnnotation, configFile, "Annotations", "Wide")
            IniWrite(config.narrowAnnotation, configFile, "Annotations", "Narrow")
        }
    } catch as err {
        LogError("Failed to create or validate config: " err.Message)
    }
}

; === VALIDATE JSON ===
IsValidJson(str) {
    try {
        parsed := JSON.Parse(str)
        return IsObject(parsed)
    } catch {
        return false
    }
}

; === GUI ===
InitGui() {
    global mainGui, statusCtrl, pauseBtn, startBtn, detectionModeCtrl
    try {
        mainGui := Gui("+Resize +AlwaysOnTop", "Segments.ai Annotation Paster")
        mainGui.SetFont("s10")
        mainGui.Add("GroupBox", "x10 y10 w460 h80", "Annotation Controls")
        mainGui.Add("Button", "x20 y30 w210 h45", "Wide (" config.wideHotkey ")").OnEvent("Click", (*) => StartContinuous(wideAnnotation, "Wide"))
        mainGui.Add("Button", "x250 y30 w210 h45", "Narrow (" config.narrowHotkey ")").OnEvent("Click", (*) => StartContinuous(narrowAnnotation, "Narrow"))
        mainGui.Add("GroupBox", "x10 y100 w460 h50", "Mode Controls")
        detectionModeCtrl := mainGui.Add("DropDownList", "x20 y120 w200 Choose" (config.detectionMode = "Timer" ? 1 : 2), ["Timer Detection", "Filename Detection"])
        detectionModeCtrl.OnEvent("Change", (*) => UpdateDetectionMode())
        startBtn := mainGui.Add("Button", "x230 y120 w120 h30 +BackgroundGreen", "Start Auto").OnEvent("Click", (*) => StartContinuous(config.defaultAnnotation = "Narrow" ? narrowAnnotation : wideAnnotation, config.defaultAnnotation = "Narrow" ? "Narrow" : "Wide"))
        pauseBtn := mainGui.Add("Button", "x360 y120 w100 h30", "Pause").OnEvent("Click", (*) => TogglePause())
        mainGui.Add("GroupBox", "x10 y160 w460 h50", "Status")
        statusCtrl := mainGui.Add("Text", "x20 y180 w440", "Ready")
        mainGui.Add("Button", "x160 y220 w140 h30 +Background990000", "EMERGENCY STOP (" config.emergencyHotkey ")").OnEvent("Click", (*) => StopAll())
        mainGui.OnEvent("Close", (*) => StopAll())
        mainGui.Show("w480 h260")
    } catch as err {
        LogError("GUI initialization failed: " err.Message)
        MsgBox "GUI initialization failed: " err.Message
        ExitApp
    }
}

; === UPDATE DETECTION MODE ===
UpdateDetectionMode(*) {
    global config, detectionModeCtrl, continuous
    try {
        config.detectionMode := detectionModeCtrl.Text = "Timer Detection" ? "Timer" : "Filename"
        IniWrite(config.detectionMode, configFile, "Settings", "DetectionMode")
        LogInfo("Detection mode changed to: " config.detectionMode)
        UpdateStatus("Detection mode: " config.detectionMode (continuous ? " (Auto, Run " runCount ")" : " (Run " runCount ")"))
        if (continuous) {
            SetTimer ContLoop, config.interval
        }
    } catch as err {
        LogError("Failed to update detection mode: " err.Message)
    }
}

; === START CONTINUOUS ===
StartContinuous(annotation, type, *) {
    global continuous, currentAnnotation, currentAnnotationType, runCount, lastFilenameSeen, lastTimerSeen, hasExecutedThisCycle, lastDetectionTime, lastExecutionTime, lastClipboardAttempt, lastSuccessfulExecution, consecutiveRefreshes, startBtn
    if (continuous)
        return
    continuous := true
    currentAnnotation := annotation
    currentAnnotationType := type
    runCount := 0
    lastFilenameSeen := ""
    lastTimerSeen := ""
    hasExecutedThisCycle := false
    lastDetectionTime := A_TickCount
    lastExecutionTime := A_TickCount
    lastClipboardAttempt := A_TickCount
    lastSuccessfulExecution := A_TickCount
    consecutiveRefreshes := 0
    try {
        FileDelete(workDir "\debug.log")
        FileAppend("=== AUTO MODE STARTED " A_Now " ===`nDetection Mode: " config.detectionMode "`n", workDir "\debug.log")
    } catch as err {
        LogError("Failed to initialize log: " err.Message)
    }
    try {
        startBtn.Text := "Stop Auto"
        startBtn.Opt("+BackgroundRed")
        pauseBtn.Enabled := true
        mainGui["Wide (" config.wideHotkey ")"].Enabled := false
        mainGui["Narrow (" config.narrowHotkey ")"].Enabled := false
    } catch as err {
        LogError("Failed to update GUI: " err.Message)
    }
    UpdateStatus("🔍 AUTO MODE: " type " annotation - scanning (" config.detectionMode ", Run " runCount ")...")
    SetTimer ContLoop, config.interval
}

; === PASTE AND SUBMIT ===
PasteAndSubmit() {
    global statusCtrl, currentAnnotation, currentAnnotationType, runCount, retryCount, maxRetries, lastExecutionTime, lastSuccessfulExecution
    if (!FocusBrowser()) {
        UpdateStatus("Browser not focused (Run " runCount ")")
        LogError("Browser not focused")
        return false
    }
    runCount++
    retryCount := 0
    while (retryCount < maxRetries) {
        oldClipboard := ClipboardAll()
        try {
            A_Clipboard := ""
            Sleep(10)
            A_Clipboard := currentAnnotation
            if (ClipWait(0.3)) {
                Send("{Esc}")
                Send("^v")
                Sleep(50)
                Send("+{Enter}")
                Sleep(config.pageLoadDelay)
                Send("{Esc}")
                A_Clipboard := oldClipboard
                UpdateStatus("✅ " currentAnnotationType " annotation pasted and submitted (Run " runCount ")")
                LogInfo("Pasted and submitted: " currentAnnotationType " (Run " runCount ")")
                lastExecutionTime := A_TickCount
                lastSuccessfulExecution := A_TickCount
                return true
            } else {
                retryCount++
                LogError("Clipboard set failed for annotation: " SubStr(currentAnnotation, 1, 50) "... , retry " retryCount "/" maxRetries)
                Sleep(100 * (retryCount + 1))
            }
        } catch as err {
            retryCount++
            LogError("PasteAndSubmit error: " err.Message ", retry " retryCount "/" maxRetries)
            Sleep(100 * (retryCount + 1))
        } finally {
            try {
                A_Clipboard := oldClipboard
                Sleep(10)
            } catch {
            }
        }
    }
    UpdateStatus("❌ Failed to paste after " maxRetries " retries (Run " runCount ")")
    LogError("Failed to paste after " maxRetries " retries")
    return false
}

; === FOCUS BROWSER ===
FocusBrowser() {
    retryCount := 0
    maxChromeRetries := maxRetries + 2
    while (retryCount < maxChromeRetries) {
        if (WinExist("Segments.ai ahk_exe chrome.exe")) {
            try {
                WinActivate("Segments.ai ahk_exe chrome.exe")
                WinWaitActive("Segments.ai ahk_exe chrome.exe", , 0.5)
                if (WinActive("Segments.ai ahk_exe chrome.exe")) {
                    Sleep(50) ; Stabilize focus
                    LogInfo("Focused Chrome browser (Segments.ai)")
                    return true
                }
            } catch as err {
                LogError("Failed to focus Chrome (Segments.ai): " err.Message)
            }
        }
        retryCount++
        LogError("Chrome focus attempt " retryCount "/" maxChromeRetries " failed")
        Sleep(100 * (retryCount + 1))
    }
    LogError("Could not focus Chrome (Segments.ai) after " maxChromeRetries " retries")
    return false
}

; === CONTINUOUS LOOP ===
ContLoop() {
    global continuous, paused, runCount, statusCtrl, lastFilenameSeen, lastTimerSeen, hasExecutedThisCycle, workDir, lastDetectionTime, lastExecutionTime, lastClipboardAttempt, lastSuccessfulExecution, consecutiveRefreshes
    static last := 0
    if (!continuous || paused) {
        return
    }
    if (A_TickCount - last >= config.interval) {
        if (A_TickCount - lastSuccessfulExecution > config.stallTimeout) {
            LogError("No successful execution for " (config.stallTimeout / 1000) " seconds, resetting...")
            UpdateStatus("⚠️ Prolonged stall detected, resetting and refreshing browser (Run " runCount ")...")
            ResetAndRefresh()
            consecutiveRefreshes++
            if (consecutiveRefreshes >= 3) {
                UpdateStatus("⚠️ Too many refreshes, stopping auto mode (Run " runCount ")...")
                LogError("Too many consecutive refreshes (" consecutiveRefreshes "), stopping auto mode")
                StopAll()
            }
        } else if (config.detectionMode = "Timer") {
            if (A_TickCount - lastExecutionTime > config.executionTimeout) {
                LogInfo("Forcing execution after " (config.executionTimeout / 1000) " seconds...")
                UpdateStatus("⚠️ Forcing execution after " (config.executionTimeout / 1000) " seconds (Run " runCount ")...")
                hasExecutedThisCycle := false
                PasteAndSubmit()
                lastDetectionTime := A_TickCount
            } else {
                currentTimer := DetectTimer()
                if (currentTimer != "") {
                    lastDetectionTime := A_TickCount
                    consecutiveRefreshes := 0
                    if (IsNewCycleTimer(currentTimer, lastTimerSeen)) {
                        hasExecutedThisCycle := false
                        LogInfo("NEW CYCLE (Timer): " lastTimerSeen " → " currentTimer " (READY TO EXECUTE)")
                        UpdateStatus("🔄 NEW CYCLE: " currentTimer " - ready to execute (Run " runCount ")!")
                    }
                    if (hasExecutedThisCycle && IsEarlyTimer(currentTimer)) {
                        hasExecutedThisCycle := false
                        LogInfo("FORCE RESET: Timer " currentTimer " is early, resetting execution flag")
                        UpdateStatus("🔄 Auto-reset: Timer " currentTimer " - ready to execute (Run " runCount ")!")
                    }
                    lastTimerSeen := currentTimer
                    if (IsExecutionTime(currentTimer) && !hasExecutedThisCycle) {
                        UpdateStatus("🎯 EXECUTING at " currentTimer " (Run " runCount ")...")
                        LogInfo("EXECUTING: " currentTimer " (first execution this cycle)")
                        hasExecutedThisCycle := true
                        if (PasteAndSubmit()) {
                            Sleep(100) ; Stabilize webpage
                        }
                    } else if (IsExecutionTime(currentTimer) && hasExecutedThisCycle) {
                        UpdateStatus("Timer: " currentTimer " (✅ completed - waiting for reset, Run " runCount ")")
                    } else {
                        status := hasExecutedThisCycle ? " (✅ completed)" : " (⏳ ready)"
                        UpdateStatus("Timer: " currentTimer status " (Run " runCount ")")
                    }
                } else {
                    if (A_TickCount - lastDetectionTime > config.stuckTimeout) {
                        LogError("No timer detected for " (config.stuckTimeout / 1000) " seconds, attempting to advance...")
                        UpdateStatus("⚠️ Stuck detected, attempting to advance (Run " runCount ")...")
                        Send("{Right}")
                        Sleep(100)
                        lastDetectionTime := A_TickCount
                        consecutiveRefreshes++
                        if (consecutiveRefreshes >= 3) {
                            UpdateStatus("⚠️ Too many refreshes, stopping auto mode (Run " runCount ")...")
                            LogError("Too many consecutive refreshes (" consecutiveRefreshes "), stopping auto mode")
                            StopAll()
                        }
                    } else {
                        UpdateStatus("🔍 Scanning for timer (Run " runCount ")...")
                    }
                }
            }
        } else {
            if (A_TickCount - lastExecutionTime > config.executionTimeout) {
                LogInfo("Forcing execution after " (config.executionTimeout / 1000) " seconds...")
                UpdateStatus("⚠️ Forcing execution after " (config.executionTimeout / 1000) " seconds (Run " runCount ")...")
                hasExecutedThisCycle := false
                PasteAndSubmit()
                lastDetectionTime := A_TickCount
                lastFilenameSeen := "" ; Reset to force new cycle
            } else {
                currentFilename := DetectFilename()
                if (currentFilename != "") {
                    lastDetectionTime := A_TickCount
                    consecutiveRefreshes := 0
                    if (IsNewCycleFilename(currentFilename, lastFilenameSeen)) {
                        hasExecutedThisCycle := false
                        LogInfo("NEW CYCLE (Filename): " lastFilenameSeen " → " currentFilename " (READY TO EXECUTE)")
                        UpdateStatus("🔄 NEW CYCLE: " currentFilename " - ready to execute (Run " runCount ")!")
                    }
                    lastFilenameSeen := currentFilename
                    if (!hasExecutedThisCycle) {
                        UpdateStatus("🎯 EXECUTING for " currentFilename " (Run " runCount ")...")
                        LogInfo("EXECUTING: " currentFilename " (first execution this cycle)")
                        hasExecutedThisCycle := true
                        if (PasteAndSubmit()) {
                            Sleep(100) ; Stabilize webpage
                        }
                    } else {
                        UpdateStatus("Filename: " currentFilename " (✅ completed - waiting for new file, Run " runCount ")")
                    }
                } else {
                    if (A_TickCount - lastDetectionTime > config.stuckTimeout) {
                        LogError("No filename detected for " (config.stuckTimeout / 1000) " seconds, attempting to advance...")
                        UpdateStatus("⚠️ Stuck detected, attempting to advance (Run " runCount ")...")
                        Send("{Right}")
                        Sleep(100)
                        lastDetectionTime := A_TickCount
                        lastFilenameSeen := "" ; Reset to force new cycle
                        consecutiveRefreshes++
                        if (consecutiveRefreshes >= 3) {
                            UpdateStatus("⚠️ Too many refreshes, stopping auto mode (Run " runCount ")...")
                            LogError("Too many consecutive refreshes (" consecutiveRefreshes "), stopping auto mode")
                            StopAll()
                        }
                    } else {
                        UpdateStatus("🔍 Scanning for filename (Run " runCount ")...")
                        Sleep(100) ; Allow webpage to load
                    }
                }
            }
        }
        last := A_TickCount
    }
}

; === DETECT TIMER ===
DetectTimer() {
    global workDir, retryCount, maxRetries, lastClipboardAttempt
    if (!FocusBrowser() || A_TickCount - lastClipboardAttempt < 1000) {
        LogInfo("Timer detection skipped: Browser not focused or clipboard cooldown active")
        return ""
    }
    lastClipboardAttempt := A_TickCount
    retryCount := 0
    while (retryCount < maxRetries) {
        oldClipboard := ClipboardAll()
        try {
            if (!WinActive("Segments.ai ahk_exe chrome.exe")) {
                LogInfo("Chrome (Segments.ai) not active, attempting to refocus")
                if (!FocusBrowser()) {
                    retryCount++
                    LogError("Failed to refocus Chrome (Segments.ai), retry " retryCount "/" maxRetries)
                    Sleep(50)
                    continue
                }
            }
            A_Clipboard := ""
            Sleep(10)
            Send("^a")
            Sleep(50)
            Send("^c")
            Sleep(50)
            if (ClipWait(0.3)) {
                content := A_Clipboard
                A_Clipboard := oldClipboard
                LogInfo("Timer clipboard content (length " StrLen(content) "): " (content != "" ? content : "EMPTY"))
                if (content != "" && RegExMatch(content, "(\d{2}:\d{2}:\d{2})", &match)) {
                    return match[1]
                }
                retryCount++
                LogError("Timer detection failed, retry " retryCount "/" maxRetries " Content: " (content != "" ? content : "EMPTY"))
                Sleep(50)
            } else {
                retryCount++
                LogError("Clipboard retrieve failed (Timer), retry " retryCount "/" maxRetries)
                Sleep(50)
            }
        } catch as err {
            retryCount++
            LogError("DetectTimer error: " err.Message ", retry " retryCount "/" maxRetries)
            Sleep(50)
        } finally {
            try {
                A_Clipboard := oldClipboard
                Sleep(10)
            } catch {
            }
        }
    }
    LogError("Failed to detect timer after " maxRetries " retries, attempting to advance")
    Send("{Right}")
    Sleep(100)
    return ""
}

; === DETECT FILENAME ===
DetectFilename() {
    global workDir, retryCount, maxRetries, lastClipboardAttempt
    if (!FocusBrowser() || A_TickCount - lastClipboardAttempt < 1000) {
        LogInfo("Filename detection skipped: Browser not focused or clipboard cooldown active")
        return ""
    }
    lastClipboardAttempt := A_TickCount
    retryCount := 0
    while (retryCount < maxRetries) {
        oldClipboard := ClipboardAll()
        try {
            if (!WinActive("Segments.ai ahk_exe chrome.exe")) {
                LogInfo("Chrome (Segments.ai) not active, attempting to refocus")
                if (!FocusBrowser()) {
                    retryCount++
                    LogError("Failed to refocus Chrome (Segments.ai), retry " retryCount "/" maxRetries)
                    Sleep(50)
                    continue
                }
            }
            A_Clipboard := ""
            Sleep(10)
            Send("^a")
            Sleep(50)
            Send("^c")
            Sleep(50)
            if (ClipWait(0.3)) {
                content := A_Clipboard
                A_Clipboard := oldClipboard
                LogInfo("Filename clipboard content (length " StrLen(content) "): " (content != "" ? content : "EMPTY"))
                if (content != "" && RegExMatch(content, "\w+_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}.*\.jpeg", &match)) {
                    return match[0]
                }
                ; Fallback: Try triple-click to select filename
                MouseClick("left", , , 3) ; Triple-click
                Sleep(50)
                A_Clipboard := ""
                Send("^c")
                Sleep(50)
                if (ClipWait(0.3)) {
                    content := A_Clipboard
                    A_Clipboard := oldClipboard
                    LogInfo("Filename fallback clipboard content (length " StrLen(content) "): " (content != "" ? content : "EMPTY"))
                    if (content != "" && RegExMatch(content, "\w+_\d{4}-\d{2}-\d{2}_\d{2}-\d{2}-\d{2}.*\.jpeg", &match)) {
                        return match[0]
                    }
                }
                retryCount++
                LogError("Filename detection failed, retry " retryCount "/" maxRetries " Content: " (content != "" ? content : "EMPTY"))
                Sleep(50)
            } else {
                retryCount++
                LogError("Clipboard retrieve failed (Filename), retry " retryCount "/" maxRetries)
                Sleep(50)
            }
        } catch as err {
            retryCount++
            LogError("DetectFilename error: " err.Message ", retry " retryCount "/" maxRetries)
            Sleep(50)
        } finally {
            try {
                A_Clipboard := oldClipboard
                Sleep(10)
            } catch {
            }
        }
    }
    LogError("Failed to detect filename after " maxRetries " retries, attempting to advance")
    Send("{Right}")
    Sleep(100)
    return ""
}

; === CHECK IF TIMER IS IN EARLY RANGE ===
IsEarlyTimer(timerStr) {
    if (RegExMatch(timerStr, "^(\d{2}):(\d{2}):(\d{2})$", &match)) {
        minutes := Integer(match[1])
        seconds := Integer(match[2])
        if (minutes <= 16 || (minutes == 17 && seconds <= 30)) {
            return true
        }
    }
    return false
}

; === NEW CYCLE DETECTION (TIMER) ===
IsNewCycleTimer(currentTimer, lastTimer) {
    if (lastTimer == "" || currentTimer == "") {
        return true
    }
    currentSeconds := TimerToSeconds(currentTimer)
    lastSeconds := TimerToSeconds(lastTimer)
    if (currentSeconds == 0 || lastSeconds == 0) {
        return false
    }
    if (currentSeconds < lastSeconds - 60 || (currentSeconds < 17 * 60 && lastSeconds > 18 * 60)) {
        return true
    }
    return false
}

; === NEW CYCLE DETECTION (FILENAME) ===
IsNewCycleFilename(currentFilename, lastFilename) {
    if (lastFilename == "" || currentFilename == "") {
        return true
    }
    return currentFilename != lastFilename
}

; === CONVERT TIMER TO SECONDS ===
TimerToSeconds(timerStr) {
    if (RegExMatch(timerStr, "^(\d{2}):(\d{2}):(\d{2})$", &match)) {
        minutes := Integer(match[1])
        seconds := Integer(match[2])
        subseconds := Integer(match[3])
        return (minutes * 60) + seconds + (subseconds / 100)
    }
    return 0
}

; === EXECUTION CHECK ===
IsExecutionTime(timerStr) {
    executionTimes := ["17:00:01", "17:00:02", "17:00:03", "17:00:04", "17:00:05"]
    for execTime in executionTimes {
        if (timerStr == execTime) {
            return true
        }
    }
    return false
}

; === RESET AND REFRESH ===
ResetAndRefresh() {
    global hasExecutedThisCycle, lastFilenameSeen, lastTimerSeen, lastDetectionTime, lastExecutionTime, lastClipboardAttempt, lastSuccessfulExecution, consecutiveRefreshes
    hasExecutedThisCycle := false
    lastFilenameSeen := ""
    lastTimerSeen := ""
    lastDetectionTime := A_TickCount
    lastExecutionTime := A_TickCount
    lastClipboardAttempt := A_TickCount
    lastSuccessfulExecution := A_TickCount
    if (FocusBrowser()) {
        Send("{F5}")
        Sleep(config.refreshDelay)
        LogInfo("Browser refreshed")
    } else {
        LogError("Failed to refresh browser, no focus")
    }
}

; === TOGGLE CONTINUOUS ===
ToggleContinuous(*) {
    global continuous, paused, runCount, hasExecutedThisCycle, lastFilenameSeen, lastTimerSeen, lastDetectionTime, lastExecutionTime, lastClipboardAttempt, lastSuccessfulExecution, consecutiveRefreshes, startBtn, mainGui
    continuous := !continuous
    paused := false
    lastFilenameSeen := ""
    lastTimerSeen := ""
    hasExecutedThisCycle := false
    lastDetectionTime := A_TickCount
    lastExecutionTime := A_TickCount
    lastClipboardAttempt := A_TickCount
    lastSuccessfulExecution := A_TickCount
    consecutiveRefreshes := 0
    try {
        startBtn.Text := continuous ? "Stop Auto" : "Start Auto"
        startBtn.Opt(continuous ? "+BackgroundRed" : "+BackgroundGreen")
        pauseBtn.Text := "Pause"
        pauseBtn.Opt("-BackgroundYellow")
        pauseBtn.Enabled := continuous
        mainGui["Wide (" config.wideHotkey ")"].Enabled := !continuous
        mainGui["Narrow (" config.narrowHotkey ")"].Enabled := !continuous
        LogInfo(continuous ? "AUTO MODE STARTED (Mode: " config.detectionMode ")" : "AUTO MODE STOPPED")
    } catch as err {
        LogError("Toggle continuous failed: " err.Message)
    }
    UpdateStatus(continuous ? "🔍 AUTO MODE: " currentAnnotationType " annotation - scanning (" config.detectionMode ", Run " runCount ")..." : "Auto mode stopped (Run " runCount ")")
    SetTimer ContLoop, continuous ? config.interval : 0
}

; === PAUSE ===
TogglePause(*) {
    global continuous, paused, pauseBtn, lastFilenameSeen, lastTimerSeen, hasExecutedThisCycle, lastDetectionTime, lastExecutionTime, lastClipboardAttempt, lastSuccessfulExecution, consecutiveRefreshes
    if (!continuous)
        return
    paused := !paused
    if (paused) {
        SetTimer ContLoop, 0
        try {
            pauseBtn.Text := "Resume"
            pauseBtn.Opt("+BackgroundYellow")
            LogInfo("Paused")
        } catch as err {
            LogError("Pause failed: " err.Message)
        }
        UpdateStatus("⏸ Paused (Run " runCount ")")
    } else {
        if (FocusBrowser()) {
            Send("{Esc Up}{Ctrl Up}{Shift Up}{Alt Up}")
            Send("{Esc}")
            Sleep(20)
        }
        lastFilenameSeen := ""
        lastTimerSeen := ""
        hasExecutedThisCycle := false
        lastDetectionTime := A_TickCount
        lastExecutionTime := A_TickCount
        lastClipboardAttempt := A_TickCount
        lastSuccessfulExecution := A_TickCount
        consecutiveRefreshes := 0
        SetTimer ContLoop, -10
        try {
            pauseBtn.Text := "Pause"
            pauseBtn.Opt("-BackgroundYellow")
            LogInfo("Resumed")
        } catch as err {
            LogError("Resume failed: " err.Message)
        }
        UpdateStatus("▶️ Resumed: " currentAnnotationType " annotation - scanning (" config.detectionMode ", Run " runCount ")...")
    }
}

; === STOP ===
StopAll(*) {
    global continuous, paused, runCount, lastFilenameSeen, lastTimerSeen, hasExecutedThisCycle, lastDetectionTime, lastExecutionTime, lastClipboardAttempt, lastSuccessfulExecution, consecutiveRefreshes, startBtn, mainGui
    continuous := false
    paused := false
    lastFilenameSeen := ""
    lastTimerSeen := ""
    hasExecutedThisCycle := false
    lastDetectionTime := A_TickCount
    lastExecutionTime := A_TickCount
    lastClipboardAttempt := A_TickCount
    lastSuccessfulExecution := A_TickCount
    consecutiveRefreshes := 0
    SetTimer ContLoop, 0
    SetTimer ContLoop, 0 ; Double call to ensure timer stops
    try {
        Hotkey(config.wideHotkey, "Off")
        Hotkey(config.narrowHotkey, "Off")
        Hotkey(config.emergencyHotkey, "Off")
        LogInfo("Hotkeys disabled")
        Hotkey(config.wideHotkey, (*) => StartContinuous(wideAnnotation, "Wide"))
        Hotkey(config.narrowHotkey, (*) => StartContinuous(narrowAnnotation, "Narrow"))
        Hotkey(config.emergencyHotkey, (*) => StopAll())
        LogInfo("Hotkeys reset")
    } catch as err {
        LogError("Failed to reset hotkeys: " err.Message)
    }
    if (FocusBrowser()) {
        Send("{Esc Up}{Ctrl Up}{Shift Up}{Alt Up}")
        Send("{Esc}")
        Sleep(100) ; Ensure Chrome processes key sends
        LogInfo("Sent cleanup keys to Chrome")
    }
    Send("{LButton Up}{RButton Up}{MButton Up}")
    try {
        startBtn.Text := "Start Auto"
        startBtn.Opt("+BackgroundGreen")
        pauseBtn.Text := "Pause"
        pauseBtn.Opt("-BackgroundYellow")
        pauseBtn.Enabled := false
        mainGui["Wide (" config.wideHotkey ")"].Enabled := true
        mainGui["Narrow (" config.narrowHotkey ")"].Enabled := true
        LogInfo("EMERGENCY STOPPED")
    } catch as err {
        LogError("StopAll failed: " err.Message)
    }
    UpdateStatus("🚨 EMERGENCY STOPPED: Toggle Auto Mode or use " config.wideHotkey "/" config.narrowHotkey " (Run " runCount ")")
}

; === STATUS ===
UpdateStatus(t) {
    global statusCtrl
    try {
        statusCtrl.Text := t
    } catch as err {
        LogError("UpdateStatus failed: " err.Message)
    }
}

; === LOGGING ===
LogInfo(msg) {
    global workDir
    try {
        FileAppend(A_Now " [INFO]: " msg "`n", workDir "\debug.log")
    } catch {
    }
}

LogError(msg) {
    global workDir
    try {
        FileAppend(A_Now " [ERROR]: " msg "`n", workDir "\debug.log")
    } catch {
    }
}

; === JSON LIBRARY ===
class JSON {
    static Parse(str) {
        str := Trim(str)
        if (SubStr(str, 1, 1) != "{" || SubStr(str, -1) != "}")
            throw Error("Invalid JSON: Not an object")
        return Map()
    }
}