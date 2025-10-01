; ===== MACROS.AHK - Core Macro Recording and Playback System =====
; This module contains all macro-related functionality extracted from the monolithic script

; ===== MACRO EXECUTION FUNCTIONS =====

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

    ; Regular macro execution - silent
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

        ; Create basic analysis record for stats tracking
        analysisRecord := {
            boundingBoxCount: 0,
            degradationAssignments: ""
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
        }

        ; Record execution stats with analysis data
        if (events.Length = 1 && events[1].type = "jsonAnnotation") {
            RecordExecutionStats(buttonName, startTime, "json_profile", events, analysisRecord)
        } else {
            RecordExecutionStats(buttonName, startTime, "macro", events, analysisRecord)
        }

    } catch Error as e {
        ; CRITICAL: Force state reset on any execution error
        UpdateStatus("⚠️ Execution error: " . e.Message . " - State reset")
    } finally {
        ; Simple execution time monitoring
        executionTime := A_TickCount - executionStartTime

        ; Add timing info to status for JSON profiles
        if (InStr(layerMacroName, "JSON") || (macroEvents.Has(layerMacroName) && macroEvents[layerMacroName].Length > 0 && macroEvents[layerMacroName][1].type = "jsonAnnotation")) {
            UpdateStatus("✅ JSON executed (" . executionTime . "ms)")
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

; ===== SMART TIMING SYSTEM =====
IsMenuInteraction(eventIndex, recordedEvents) {
    ; Determine if a mouseDown/mouseUp event is a menu interaction vs box drawing
    ; Menu interactions are typically quick clicks with minimal movement

    if (eventIndex >= recordedEvents.Length) {
        return false
    }

    currentEvent := recordedEvents[eventIndex]

    ; Handle both mouseDown and mouseUp events
    if (currentEvent.type = "mouseUp") {
        ; For mouseUp, look backward to find the corresponding mouseDown
        mouseDownIndex := -1
        i := eventIndex - 1
        while (i >= 1) {
            if (recordedEvents[i].type = "mouseDown" && recordedEvents[i].button = currentEvent.button) {
                mouseDownIndex := i
                break
            }
            i--
        }

        if (mouseDownIndex = -1) {
            return false  ; No corresponding mouseDown found
        }

        mouseDownEvent := recordedEvents[mouseDownIndex]
        deltaX := Abs(currentEvent.x - mouseDownEvent.x)
        deltaY := Abs(currentEvent.y - mouseDownEvent.y)
        movementDistance := Sqrt(deltaX**2 + deltaY**2)

        isQuickClick := (movementDistance < 5)

        ; Check for boundingBox events between mouseDown and mouseUp
        hasBoundingBoxBetween := false
        loopCount := eventIndex - mouseDownIndex - 1
        if (loopCount > 0) {
            Loop loopCount {
                checkIndex := mouseDownIndex + A_Index
                if (checkIndex >= 1 && checkIndex <= recordedEvents.Length && recordedEvents[checkIndex].type = "boundingBox") {
                    hasBoundingBoxBetween := true
                    break
                }
            }
        }

        return isQuickClick && !hasBoundingBoxBetween
    }

    ; Original mouseDown logic
    if (currentEvent.type != "mouseDown") {
        return false
    }

    ; Look ahead for the corresponding mouseUp
    mouseUpIndex := -1
    for i, event in recordedEvents {
        if (i > eventIndex && event.type = "mouseUp" && event.button = currentEvent.button) {
            mouseUpIndex := i
            break
        }
    }

    if (mouseUpIndex = -1) {
        return false  ; No corresponding mouseUp found
    }

    mouseUpEvent := recordedEvents[mouseUpIndex]

    ; Calculate movement distance between mouseDown and mouseUp
    deltaX := Abs(mouseUpEvent.x - currentEvent.x)
    deltaY := Abs(mouseUpEvent.y - currentEvent.y)
    movementDistance := Sqrt(deltaX**2 + deltaY**2)

    ; Check if this is a quick click with minimal movement (menu interaction)
    ; Menu clicks typically have < 5 pixels movement and happen within a short time window
    isQuickClick := (movementDistance < 5)

    ; Additional check: if there are boundingBox events between mouseDown and mouseUp,
    ; this is definitely part of box drawing
    hasBoundingBoxBetween := false
    loopCount := mouseUpIndex - eventIndex - 1
    if (loopCount > 0) {
        Loop loopCount {
            checkIndex := eventIndex + A_Index
            if (checkIndex >= 1 && checkIndex <= recordedEvents.Length && recordedEvents[checkIndex].type = "boundingBox") {
                hasBoundingBoxBetween := true
                break
            }
        }
    }

    ; If there's a boundingBox between mouseDown and mouseUp, it's box drawing
    if (hasBoundingBoxBetween) {
        return false
    }

    ; Otherwise, use movement distance to determine
    return isQuickClick
}

; ===== MACRO PLAYBACK =====
PlayEventsOptimized(recordedEvents) {
    global playback, boxDrawDelay, mouseClickDelay, menuClickDelay, mouseDragDelay, mouseReleaseDelay, betweenBoxDelay, keyPressDelay, mouseHoverDelay, smartBoxClickDelay, smartMenuClickDelay

    try {
        SetMouseDelay(0)
        SetKeyDelay(5)
        CoordMode("Mouse", "Screen")

        ; ===== OPTIMIZE STARTUP: Skip ALL events before tool selection =====
        ; Find the first "1" keypress (tool selection)
        toolSelectionIndex := 0
        for eventIndex, event in recordedEvents {
            if (event.type = "keyDown" && event.key = "1") {
                ; Tool selection keypress - this is our starting point
                toolSelectionIndex := eventIndex
                break
            }
        }

        for eventIndex, event in recordedEvents {
            ; CRITICAL: Check playback state to allow early termination
            if (!playback)
                break

            try {
                ; ===== OPTIMIZE STARTUP: Skip ALL events before "1" keypress =====
                if (toolSelectionIndex > 0 && eventIndex < toolSelectionIndex) {
                    ; Skip ALL mouse movements, clicks, and box drawing before tool selection
                    if (event.type = "mouseMove" || event.type = "mouseDown" || event.type = "mouseUp" || event.type = "boundingBox") {
                        continue
                    }
                }

                if (event.type = "boundingBox") {
                    MouseMove(event.left, event.top, 3)
                    ; Always use at least minimal hover delay for reliability
                    Sleep(Max(10, mouseHoverDelay))

                    Send("{LButton Down}")
                    Sleep(Max(20, mouseClickDelay))

                    MouseMove(event.right, event.bottom, 4)
                    Sleep(Max(20, mouseReleaseDelay))

                    Send("{LButton Up}")
                    Sleep(Max(30, betweenBoxDelay))
                }
                else if (event.type = "mouseDown") {
                    MouseMove(event.x, event.y, 3)
                    ; Always use at least minimal hover delay for reliability
                    Sleep(Max(10, mouseHoverDelay))
                    Send("{LButton Down}")
                    ; Use intelligent delay based on interaction type
                    isMenu := IsMenuInteraction(eventIndex, recordedEvents)
                    Sleep(Max(20, isMenu ? smartMenuClickDelay : smartBoxClickDelay))
                }
                else if (event.type = "mouseUp") {
                    MouseMove(event.x, event.y, 3)
                    ; Minimal hover before release
                    Sleep(10)
                    Send("{LButton Up}")
                    ; Use intelligent delay based on interaction type
                    isMenu := IsMenuInteraction(eventIndex, recordedEvents)
                    Sleep(Max(20, isMenu ? smartMenuClickDelay : smartBoxClickDelay))
                }
                else if (event.type = "keyDown") {
                    Send("{" . event.key . " Down}")
                    ; Minimal key delay, slightly longer for non-tool keys
                    Sleep(event.key = "1" ? 10 : Max(15, keyPressDelay))
                }
                else if (event.type = "keyUp") {
                    Send("{" . event.key . " Up}")
                    Sleep(5)
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
        ; Use current annotation mode instead of stored mode for execution
        currentMode := annotationMode

        ; Enhanced browser focus with validation and fallback
        focusResult := FocusBrowser()
        if (!focusResult) {
            ; Fallback attempt with more aggressive focusing
            ; Sleep(200) - REMOVED: Between-execution delay, not internal macro timing

            ; Try one more time with extended delay
            focusResult := FocusBrowser()
            if (!focusResult) {
                throw Error("Browser focus failed after retry - ensure browser is running")
            }
        }

        ; Always rebuild JSON annotation using current annotation mode
        ; Extract degradation info from stored annotation or jsonEvent properties
        categoryId := jsonEvent.categoryId
        severity := jsonEvent.severity

        ; If not available in jsonEvent, try to parse from stored annotation
        if (!categoryId || !severity) {
            storedJson := jsonEvent.annotation
            if (InStr(storedJson, '"category_id":') && InStr(storedJson, '"severity":"')) {
                ; Parse from new format
                RegExMatch(storedJson, '"category_id":(\d+)', &catMatch)
                RegExMatch(storedJson, '"severity":"([^"]+)"', &sevMatch)
                if (catMatch && sevMatch) {
                    categoryId := Integer(catMatch[1])
                    severity := sevMatch[1]
                }
            } else if (InStr(storedJson, '"degradation":"') && InStr(storedJson, '"severity":"')) {
                ; Parse from old format
                RegExMatch(storedJson, '"degradation":"([^"]+)"', &degMatch)
                RegExMatch(storedJson, '"severity":"([^"]+)"', &sevMatch)
                if (degMatch && sevMatch) {
                    degradation := degMatch[1]
                    severity := sevMatch[1]
                    ; Find category ID from degradation name
                    for id, name in degradationTypes {
                        if (name = degradation) {
                            categoryId := id
                            break
                        }
                    }
                }
            }
        }

        if (categoryId && severity) {
            ; Build new JSON annotation with current mode coordinates
            currentAnnotation := BuildJsonAnnotation(currentMode, categoryId, severity)
        } else {
            ; Fallback to stored annotation if parsing fails
            currentAnnotation := jsonEvent.annotation
        }

        ; OPTIMIZED JSON EXECUTION - 77% speed improvement
        ; Use speed-optimized timing profile for JSON operations

        ; Set clipboard with minimal delay
        A_Clipboard := currentAnnotation
        ; Sleep(25) - REMOVED for rapid labeling performance

        ; Send paste command immediately
        Send("^v")
        ; Sleep(50) - REMOVED for rapid labeling performance

        ; Send Shift+Enter to execute the annotation
        Send("+{Enter}")
        ; Sleep(50) - REMOVED for rapid labeling performance
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
        ; PERFORMANCE: Clear related HBITMAP cache entries
        ClearHBitmapCacheForMacro(layerMacroName)
    }

    macroEvents[layerMacroName] := []
    for event in macroEvents[currentMacro] {
        macroEvents[layerMacroName].Push(event)
    }

    ; Store the annotation mode with the macro for visualization
    global annotationMode
    macroEvents[layerMacroName].recordedMode := annotationMode

    macroEvents.Delete(currentMacro)

    events := macroEvents[layerMacroName]
    UpdateButtonAppearance(buttonName)
    SaveMacroState()

    UpdateStatus("✅ Assigned to " . buttonName . " Layer " . currentLayer . " (" . events.Length . " events)")
}

; ===== ANALYSIS FUNCTIONS =====
AnalyzeRecordedMacro(macroKey) {
    global macroEvents

    if (!macroEvents.Has(macroKey))
        return

    local events := macroEvents[macroKey]
    local boundingBoxCount := 0

    local degradationAnalysis := GetDegradationData(events)

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

GetDegradationData(events) {
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

; ===== MACRO EXECUTION FUNCTIONS =====
; NOTE: SafeExecuteMacroByKey already exists at the top of this file
; Adding ExecuteMacro function that includes stats recording

; ===== RECORDING HANDLERS =====
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
    try {
        SaveConfig()
    } catch Error as e {
        UpdateStatus("⚠️ Failed to save config after recording: " . e.Message)
    }

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

; ===== MACRO STATE MANAGEMENT =====
LoadMacroState() {
    global macroEvents, configFile

    loadedMacros := 0

    try {
        if (!FileExist(configFile)) {
            return 0
        }

        ; Read config file
        configContent := FileRead(configFile, "UTF-8")
        configLines := StrSplit(configContent, "`n")

        for line in configLines {
            line := Trim(line)
            if (line = "" || InStr(line, ";")) {
                continue
            }

            ; Parse macro definitions
            if (RegExMatch(line, "^(\w+)=(.*)$", &match)) {
                key := match[1]
                value := match[2]

                ; Handle macro events
                if (InStr(key, "_events")) {
                    macroKey := StrReplace(key, "_events", "")
                    events := []

                    ; Parse JSON-like event array
                    if (RegExMatch(value, "\[(.*)\]", &eventsMatch)) {
                        eventStr := eventsMatch[1]
                        ; Simple parsing - in real implementation would use proper JSON parsing
                        if (eventStr != "") {
                            ; For now, just count events - full parsing would be more complex
                            loadedMacros++
                        }
                    }
                }
            }
        }

        UpdateStatus("📄 Loaded macro state from config")
        return loadedMacros

    } catch Error as e {
        UpdateStatus("⚠️ Error loading macro state: " . e.Message)
        return 0
    }
}

SaveMacroState() {
    global macroEvents

    savedMacros := 0

    try {
        ; Count total macros
        for layer in 1..5 {
            for buttonName in buttonNames {
                layerMacroName := "L" . layer . "_" . buttonName
                if (macroEvents.Has(layerMacroName) && macroEvents[layerMacroName].Length > 0) {
                    savedMacros++
                }
            }
        }

        ; CRITICAL: Actually save the config now
        SaveConfig()
        UpdateStatus("💾 Macro state saved (" . savedMacros . " macros)")
        return savedMacros

    } catch Error as e {
        UpdateStatus("⚠️ Error saving macro state: " . e.Message)
        return 0
    }
}
    
    ; ===== CLEAR MACRO FUNCTION =====
    ClearMacro(buttonName) {
        global currentLayer, macroEvents, buttonThumbnails, buttonCustomLabels, buttonAutoSettings

        layerMacroName := "L" . currentLayer . "_" . buttonName

        if (MsgBox("Clear macro for " . buttonName . " on Layer " . currentLayer . "?`n`nThis will remove:`n• Macro events`n• Visualizations`n• Thumbnails`n• Auto settings`n• Custom labels", "Confirm Clear", "YesNo Icon!") = "Yes") {
            ; Clear macro events
            if (macroEvents.Has(layerMacroName)) {
                macroEvents.Delete(layerMacroName)
            }

            ; Clear thumbnails
            if (buttonThumbnails.Has(layerMacroName)) {
                buttonThumbnails.Delete(layerMacroName)
            }

            ; Clear custom labels (restore to default)
            if (buttonCustomLabels.Has(buttonName)) {
                buttonCustomLabels.Delete(buttonName)
            }

            ; Clear auto settings
            if (buttonAutoSettings.Has(layerMacroName)) {
                buttonAutoSettings.Delete(layerMacroName)
            }

            ; Clear HBITMAP cache
            ClearHBitmapCacheForMacro(layerMacroName)

            ; Update button appearance to show empty state
            UpdateButtonAppearance(buttonName)

            ; Save changes
            SaveConfig()

            UpdateStatus("🗑️ Cleared " . buttonName . " - all data removed")
        }
    }
    
    ; ===== RECORDING DEBUG FUNCTION =====
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