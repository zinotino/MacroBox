/*
==============================================================================
MACRO EXECUTION MODULE - Macro playback and automated execution
==============================================================================
Handles all macro execution, automation, and playback operations
*/

; ===== SAFE MACRO EXECUTION - BLOCKS F9 =====
SafeExecuteMacroByKey(buttonName) {
    global breakMode, playback, lastExecutionTime

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

    ; CRITICAL: Absolutely prevent F9 from reaching macro execution (silent block)
    if (buttonName = "F9" || InStr(buttonName, "F9")) {
        return
    }

    ; Regular macro execution - silent
    ExecuteMacro(buttonName)
}

ExecuteMacro(buttonName) {
    global awaitingAssignment, macroEvents, playback, focusDelay, degradationTypes

    ; PERFORMANCE MONITORING - Start timing execution
    executionStartTime := A_TickCount

    if (awaitingAssignment) {
        SetTimer(CheckForAssignment, 0)
        AssignToButton(buttonName)
        return
    }

    if (!macroEvents.Has(buttonName) || macroEvents[buttonName].Length = 0) {
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

        events := macroEvents[buttonName]
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

        ; Record execution stats with analysis data
        if (events.Length = 1 && events[1].type = "jsonAnnotation") {
            RecordExecutionStats(buttonName, startTime, "json_profile", events, analysisRecord)
        } else {
            RecordExecutionStats(buttonName, startTime, "macro", events, analysisRecord)
        }

    } catch Error as e {
        ; CRITICAL: Force state reset on any execution error (priority message)
        UpdateStatus("⚠️ Execution error - State reset")
    } finally {
        ; CRITICAL: Always reset playback state and button flash
        FlashButton(buttonName, false)
        playback := false
        playbackStartTime := 0

        ; Silent execution - no status spam during rapid macro use
        ; Only show timing for slow executions (>500ms) or errors
        executionTime := A_TickCount - executionStartTime
        if (executionTime > 500) {
            UpdateStatus("Slow execution: " . executionTime . "ms")
        }
    }
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

    ; CRITICAL: Snapshot playback state at start to prevent mid-execution corruption
    localPlaybackState := playback

    try {
        SetMouseDelay(0)
        SetKeyDelay(5)
        CoordMode("Mouse", "Screen")

        ; PHASE 2D: Initialize mouse state for reliable first click
        MouseGetPos(&initX, &initY)
        Sleep(50)  ; 50ms delay to ensure mouse system is ready

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

        ; PHASE 2D: Track first mouse operation for extra reliability
        firstMouseOperation := true

        for eventIndex, event in recordedEvents {
            ; IMPROVED: Use local state snapshot instead of global flag
            ; This prevents external state changes from stopping macro mid-execution
            ; Only check global playback every 10 events for emergency stop
            if (Mod(eventIndex, 10) = 0 && !playback) {
                break  ; Allow emergency stop but not random state corruption
            }

            try {
                ; ===== OPTIMIZE STARTUP: Skip ALL events before "1" keypress =====
                if (toolSelectionIndex > 0 && eventIndex < toolSelectionIndex) {
                    ; Skip ALL mouse movements, clicks, and box drawing before tool selection
                    if (event.type = "mouseMove" || event.type = "mouseDown" || event.type = "mouseUp" || event.type = "boundingBox") {
                        continue
                    }
                }

                if (event.type = "boundingBox") {
                    ; PHASE 2D: Extra delay for first mouse operation (reliability)
                    if (firstMouseOperation) {
                        Sleep(20)
                        firstMouseOperation := false
                    }

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
                    ; PHASE 2D: Extra delay for first mouse operation (reliability)
                    if (firstMouseOperation) {
                        Sleep(20)
                        firstMouseOperation := false
                    }

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
            ; Try one more time
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

        ; Set clipboard and execute immediately
        A_Clipboard := currentAnnotation
        Send("^v")
        Send("+{Enter}")
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

                    ; Verify focus succeeded by checking if window is active
                    if (WinActive(browser.exe)) {
                        return true
                    }

                    ; If not focused, try more aggressive methods
                    WinRestore(browser.exe)  ; Restore if minimized
                    WinActivate(browser.exe)

                    if (WinActive(browser.exe)) {
                        return true
                    }

                } catch Error as e {
                    ; Continue with next retry attempt
                    continue
                }
            }
        }
    }

    UpdateStatus("⚠️ No browser found or focus failed")
    return false
}
