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

; ===== RECORDING HANDLERS =====
F9_RecordingOnly(*) {
    global recording, awaitingAssignment, breakMode, playback, annotationMode

    ; CRITICAL: Block ALL F9 operations during break mode
    if (breakMode) {
        UpdateStatus("🔴 BREAK MODE - Recording blocked")
        return
    }

    if (playback) {
        UpdateStatus("⏸️ Playback active")
        return
    }

    if (awaitingAssignment) {
        UpdateStatus("🎯 Assignment pending - ESC to cancel")
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
            ForceStopRecording()
        } else {
            ForceStartRecording()
        }
    } catch Error as e {
        UpdateStatus("❌ Recording error: " . e.Message)
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
