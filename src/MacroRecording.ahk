/*
==============================================================================
MACRO RECORDING MODULE - Macro recording and assignment system
==============================================================================
Handles all macro recording, hooks, and assignment operations
*/

; ===== RECORDING HOOKS =====
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
        ; Debug: Log keypresses during recording
        try {
            global workDir
            FileAppend("RECORDING KeyDown: key='" . keyName . "' vkCode=" . vkCode . "`n", workDir . "\degradation_debug.log", "UTF-8")
        }
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

    ; Process degradation assignments - this modifies the events in-place
    local degradationAnalysis := GetDegradationData(events)

    ; Debug: Verify degradation types were assigned
    try {
        global workDir
        debugMsg := "RECORDING ANALYSIS for " . macroKey . ":`n"
        for event in events {
            if (event.type = "boundingBox") {
                boundingBoxCount++
                if (event.HasOwnProp("degradationType")) {
                    debugMsg .= "  Box has degradationType=" . event.degradationType . "`n"
                } else {
                    debugMsg .= "  Box MISSING degradationType!`n"
                }
            }
        }
        FileAppend(debugMsg, workDir . "\degradation_debug.log", "UTF-8")
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
    global degradationTypes, workDir

    try {
        FileAppend("`n=== GetDegradationData CALLED ===`n", workDir . "\degradation_debug.log", "UTF-8")
        FileAppend("Total events to analyze: " . events.Length . "`n", workDir . "\degradation_debug.log", "UTF-8")
    }

    local boxes := []
    local keyPresses := []

    ; Collect boxes and keypresses
    for event in events {
        if (event.type = "boundingBox") {
            boxes.Push({
                index: boxes.Length + 1,
                time: event.time,
                event: event,
                degradationType: 1,
                assignedBy: "default"
            })
        } else if (event.type = "keyDown") {
            ; Debug: Log ALL keyDown events to see what we're getting
            try {
                FileAppend("  RAW KeyDown: key='" . event.key . "' at time=" . event.time . "`n", workDir . "\degradation_debug.log", "UTF-8")
            }

            if (IsNumberKey(event.key)) {
                local keyNum := GetNumberFromKey(event.key)
                if (keyNum >= 1 && keyNum <= 9) {
                    keyPresses.Push({
                        time: event.time,
                        degradationType: keyNum,
                        key: event.key
                    })
                    try {
                        FileAppend("    -> MATCHED as number key! keyNum=" . keyNum . "`n", workDir . "\degradation_debug.log", "UTF-8")
                    }
                } else {
                    try {
                        FileAppend("    -> IsNumberKey=true but keyNum out of range: " . keyNum . "`n", workDir . "\degradation_debug.log", "UTF-8")
                    }
                }
            }
        }
    }

    ; Debug logging
    try {
        FileAppend("GetDegradationData: Found " . boxes.Length . " boxes and " . keyPresses.Length . " keypresses`n", workDir . "\degradation_debug.log", "UTF-8")
        for kp in keyPresses {
            FileAppend("  Keypress: " . kp.key . " -> degType=" . kp.degradationType . " at time=" . kp.time . "`n", workDir . "\degradation_debug.log", "UTF-8")
        }
    }

    local currentDegradationType := 1
    local degradationCounts := Map()

    for id, typeName in degradationTypes {
        degradationCounts[id] := 0
    }

    ; Assign degradation types to boxes
    for boxIndex, box in boxes {
        local nextBoxTime := (boxIndex < boxes.Length) ? Integer(boxes[boxIndex + 1].time) : 999999999

        try {
            FileAppend("  Matching Box #" . boxIndex . " (time=" . box.time . ", nextBoxTime=" . nextBoxTime . ")`n", workDir . "\degradation_debug.log", "UTF-8")
        }

        local closestKeyPress := ""
        local closestTime := 9999999999  ; Larger number to ensure first match works

        ; Find closest keypress AFTER this box
        for keyPress in keyPresses {
            local kpTime := Integer(keyPress.time)
            local boxTime := Integer(box.time)
            local nbtTime := Integer(nextBoxTime)

            ; Check each condition separately
            local cond1 := (kpTime > boxTime)
            local cond2 := (kpTime < nbtTime)
            local cond3 := (kpTime < closestTime)

            try {
                FileAppend("    KP=" . kpTime . " Box=" . boxTime . " Next=" . nbtTime . " Closest=" . closestTime . " | " . cond1 . " && " . cond2 . " && " . cond3 . "`n", workDir . "\degradation_debug.log", "UTF-8")
            }

            if (cond1 && cond2 && cond3) {
                closestKeyPress := keyPress
                closestTime := kpTime
                try {
                    FileAppend("      -> MATCHED! Setting closestTime=" . closestTime . " degType=" . keyPress.degradationType . "`n", workDir . "\degradation_debug.log", "UTF-8")
                }
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

        ; CRITICAL: Assign to the actual event object
        box.event.degradationType := box.degradationType
        box.event.degradationName := degradationTypes[box.degradationType]
        box.event.assignedBy := box.assignedBy

        ; Debug logging
        try {
            FileAppend("  -> Box #" . boxIndex . " FINAL: degType=" . box.degradationType . " (" . box.assignedBy . ")`n", workDir . "\degradation_debug.log", "UTF-8")
            ; Verify the assignment worked
            if (box.event.HasOwnProp("degradationType")) {
                FileAppend("     VERIFIED: box.event.degradationType = " . box.event.degradationType . "`n", workDir . "\degradation_debug.log", "UTF-8")
            } else {
                FileAppend("     ERROR: box.event does NOT have degradationType property!`n", workDir . "\degradation_debug.log", "UTF-8")
            }
        }
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
        return
    }

    recording := false
    SafeUninstallMouseHook()
    SafeUninstallKeyboardHook()
    pendingBoxForTagging := ""

    ResetRecordingUI()

    eventCount := macroEvents.Has(currentMacro) ? macroEvents[currentMacro].Length : 0
    if (eventCount = 0) {
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
