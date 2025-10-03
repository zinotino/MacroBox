/*
==============================================================================
MACRO EXECUTION MODULE - Macro playback and automated execution
==============================================================================
Handles all macro execution, automation, and playback operations
*/

; ===== SAFE MACRO EXECUTION - BLOCKS F9 =====
SafeExecuteMacroByKey(buttonName) {
    global buttonAutoSettings, currentLayer, autoExecutionMode, breakMode, playback, lastExecutionTime

    ; CRITICAL: Block ALL execution during break mode
    if (breakMode) {
        return
    }

    ; CRITICAL: Prevent rapid execution race conditions (minimum 50ms between executions)
    currentTime := A_TickCount
    if (lastExecutionTime && (currentTime - lastExecutionTime) < 50) {
        return
    }
    lastExecutionTime := currentTime

    ; CRITICAL: Double-check playback state before proceeding
    if (playback) {
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
        return
    }

    if (playback) {
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
            ExecuteJsonAnnotation(events[1])
        } else {
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
        UpdateStatus("⚠️ Execution error - State reset")
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
                        return true
                    }

                    ; If not focused, try more aggressive methods
                    WinRestore(browser.exe)  ; Restore if minimized
                    ; Sleep(50) - REMOVED for rapid labeling performance
                    WinActivate(browser.exe)
                    ; Sleep(retryDelay) - REMOVED for rapid labeling performance

                    if (WinActive(browser.exe)) {
                        ; Sleep(focusDelay) - REMOVED for rapid labeling performance
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

; ===== CHROME MEMORY CLEANUP =====
PerformChromeMemoryCleanup() {
    try {
        ; Minimize and restore Chrome to trigger memory cleanup
        if (WinExist("ahk_exe chrome.exe")) {
            WinMinimize("ahk_exe chrome.exe")
            Sleep(50)
            WinRestore("ahk_exe chrome.exe")
            UpdateStatus("🧹 Chrome memory cleanup performed")
        }
    } catch Error as e {
        ; Ignore cleanup errors
    }
}
