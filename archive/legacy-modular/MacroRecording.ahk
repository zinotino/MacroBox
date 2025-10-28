/*
==============================================================================
MACRO RECORDING MODULE - Macro recording and assignment system
==============================================================================
Handles all macro recording, hooks, and assignment operations
*/

; ===== RECORDING HOOKS =====
global macroEvents  ; Declare global to access the macro events map

InitializeMacroRecordingModule()

InitializeMacroRecordingModule() {
    global macroEvents, mouseMoveThreshold, mouseMoveInterval, boxDragMinDistance
    global annotationMode, degradationTypes, breakMode, playback
    global mainGui, buttonGrid, yellowOutlineButtons, buttonNames

    if (!IsSet(macroEvents) || Type(macroEvents) != "Map") {
        macroEvents := Map()
    }
    if (!IsSet(mouseMoveThreshold)) {
        mouseMoveThreshold := 3
    }
    if (!IsSet(mouseMoveInterval)) {
        mouseMoveInterval := 12
    }
    if (!IsSet(boxDragMinDistance)) {
        boxDragMinDistance := 5
    }
    if (!IsSet(annotationMode)) {
        annotationMode := "Wide"
    }
    if (!IsSet(degradationTypes) || Type(degradationTypes) != "Map") {
        degradationTypes := Map(
            1, "smudge",
            2, "glare",
            3, "splashes",
            4, "partial_blockage",
            5, "full_blockage",
            6, "light_flare",
            7, "rain",
            8, "haze",
            9, "snow"
        )
    }
    if (!IsSet(breakMode)) {
        breakMode := false
    }
    if (!IsSet(playback)) {
        playback := false
    }
    if (!IsSet(mainGui)) {
        mainGui := 0
    }
    if (!IsSet(buttonGrid) || Type(buttonGrid) != "Map") {
        buttonGrid := Map()
    }
    if (!IsSet(yellowOutlineButtons) || Type(yellowOutlineButtons) != "Map") {
        yellowOutlineButtons := Map()
    }
    if (!IsSet(buttonNames) || buttonNames.Length = 0) {
        buttonNames := ["Num7", "Num8", "Num9", "Num4", "Num5", "Num6", "Num1", "Num2", "Num3", "Num0", "NumDot", "NumMult"]
    }
}

CallMacroSupport(funcName, defaultValue := "", args*) {
    try {
        return %funcName%(args*)
    } catch {
        return defaultValue
    }
}

RecordingStatus(message) {
    CallMacroSupport("UpdateStatus", "", message)
}

RecordingSaveState() {
    CallMacroSupport("SaveMacroState")
}

RecordingSaveConfig() {
    CallMacroSupport("SaveConfig")
}

RecordingClearCache(buttonName) {
    CallMacroSupport("ClearHBitmapCacheForMacro", "", buttonName)
}

RecordingUpdateButton(buttonName) {
    CallMacroSupport("UpdateButtonAppearance", "", buttonName)
}

RecordingJoin(items, delimiter := ", ") {
    return CallMacroSupport("JoinArray", "", items, delimiter)
}

RecordingIsNumberKey(keyName) {
    return CallMacroSupport("IsNumberKey", false, keyName)
}

RecordingGetNumberFromKey(keyName) {
    return CallMacroSupport("GetNumberFromKey", 0, keyName)
}

InstallMouseHook() {
    global mouseHook
    if (!mouseHook) {
        hMod := DllCall("GetModuleHandle", "Ptr", 0, "Ptr")
        mouseHook := DllCall("SetWindowsHookEx", "Int", 14  ; WH_MOUSE_LL
            , "Ptr", CallbackCreate(MouseProc)
            , "Ptr", hMod
            , "UInt", 0
            , "Ptr")
    }
}

SafeUninstallMouseHook() {
    global mouseHook
    if (mouseHook) {
        try {
            ; CRITICAL FIX: Only clear handle if unhook succeeds
            result := DllCall("UnhookWindowsHookEx", "Ptr", mouseHook)
            if (result) {
                ; Unhook succeeded - safe to clear handle
                mouseHook := 0
            } else {
                ; First attempt failed - try once more
                result := DllCall("UnhookWindowsHookEx", "Ptr", mouseHook)
                if (result) {
                    mouseHook := 0
                }
            }
        } catch {
            ; Exception occurred - don't clear handle as hook may still be active
        }
    }
}

MouseProc(nCode, wParam, lParam) {
    global recording, currentMacro, macroEvents, mouseMoveThreshold, mouseMoveInterval, boxDragMinDistance

    if (nCode < 0 || !recording || currentMacro = "")
        return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "UInt", wParam, "Ptr", lParam)

    static WM_LBUTTONDOWN := 0x0201, WM_LBUTTONUP := 0x0202, WM_MOUSEMOVE := 0x0200
    static lastX := 0, lastY := 0, lastMoveTime := 0, isDrawingBox := false, boxStartX := 0, boxStartY := 0
    static lastClickTime := 0

    x := NumGet(lParam, 0, "Int")
    y := NumGet(lParam, 4, "Int")
    ts := A_TickCount

    if (!macroEvents.Has(currentMacro))
        macroEvents[currentMacro] := []
    events := macroEvents[currentMacro]

    if (wParam = WM_LBUTTONDOWN) {
        if (ts - lastClickTime < 50)
            return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "UInt", wParam, "Ptr", lParam)
        lastClickTime := ts

        isDrawingBox := true
        boxStartX := x
        boxStartY := y
        events.Push({type:"mouseDown", button:"left", x:x, y:y, time:ts})

        if (events.Length = 1) {
            ToolTip("First click")
            SetTimer(() => ToolTip(), -600)
        }
    } else if (wParam = WM_LBUTTONUP) {
        if (isDrawingBox) {
            dx := Abs(x - boxStartX)
            dy := Abs(y - boxStartY)
            if (dx > 0 || dy > 0) {
                events.Push({type:"boundingBox", left:Min(boxStartX, x), top:Min(boxStartY, y)
                    , right:Max(boxStartX, x), bottom:Max(boxStartY, y), time:ts
                    , degradationType: 1, degradationName: "smudge", assignedBy: "auto_default"})
                RecordingStatus("Box created - press 1-9 to tag")
            } else {
                events.Push({type:"click", button:"left", x:x, y:y, time:ts})
            }
            isDrawingBox := false
        }
        events.Push({type:"mouseUp", button:"left", x:x, y:y, time:ts})
    } else if (wParam = WM_MOUSEMOVE) {
        dist := Sqrt((x - lastX) ** 2 + (y - lastY) ** 2)
        dt := ts - lastMoveTime
        if (dist >= mouseMoveThreshold && dt >= mouseMoveInterval) {
            events.Push({type:"mouseMove", x:x, y:y, time:ts})
            lastX := x
            lastY := y
            lastMoveTime := ts
        }
    }
    return DllCall("CallNextHookEx", "Ptr", 0, "Int", nCode, "UInt", wParam, "Ptr", lParam)
}

InstallKeyboardHook() {
    global keyboardHook
    if (!keyboardHook) {
        hMod := DllCall("GetModuleHandle", "Ptr", 0, "Ptr")
        keyboardHook := DllCall("SetWindowsHookEx", "Int", 13  ; WH_KEYBOARD_LL
            , "Ptr", CallbackCreate(KeyboardProc)
            , "Ptr", hMod
            , "UInt", 0
            , "Ptr")
    }
}

SafeUninstallKeyboardHook() {
    global keyboardHook
    if (keyboardHook) {
        try {
            ; CRITICAL FIX: Only clear handle if unhook succeeds
            result := DllCall("UnhookWindowsHookEx", "Ptr", keyboardHook)
            if (result) {
                ; Unhook succeeded - safe to clear handle
                keyboardHook := 0
            } else {
                ; First attempt failed - try once more
                result := DllCall("UnhookWindowsHookEx", "Ptr", keyboardHook)
                if (result) {
                    keyboardHook := 0
                }
            }
        } catch {
            ; Exception occurred - don't clear handle as hook may still be active
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

}

CancelAssignmentProcess() {
    global currentMacro, macroEvents, awaitingAssignment
    awaitingAssignment := false
    if (macroEvents.Has(currentMacro)) {
        macroEvents.Delete(currentMacro)
    }
    RecordingStatus("⚠️ Assignment cancelled")
}


FinalizeRecording(macroKey, eventCount) {
    global macroEvents

    if (!macroEvents.Has(macroKey))
        return

    if (eventCount > 0) {
        AnalyzeRecordedMacro(macroKey)
    }

    RecordingSaveState()
    RecordingSaveConfig()
}

AssignToButton(buttonName) {
    global currentMacro, macroEvents, awaitingAssignment

    awaitingAssignment := false

    if (!macroEvents.Has(currentMacro) || macroEvents[currentMacro].Length = 0) {
        RecordingStatus("⚠️ No macro to assign")
        return
    }

    if (macroEvents.Has(buttonName)) {
        macroEvents.Delete(buttonName)
        ; PERFORMANCE: Clear related HBITMAP cache entries
        RecordingClearCache(buttonName)
    }

    macroEvents[buttonName] := []
    for event in macroEvents[currentMacro] {
        macroEvents[buttonName].Push(event)
    }

    ; Store the annotation mode with the macro for visualization
    global annotationMode
    macroEvents[buttonName].recordedMode := annotationMode

    macroEvents.Delete(currentMacro)

    events := macroEvents[buttonName]
    RecordingUpdateButton(buttonName)
    RecordingSaveState()
    RecordingSaveConfig()

    RecordingStatus("✅ Assigned to " . buttonName . " (" . events.Length . " events)")
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

        RecordingStatus(statusMsg)
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
        } else if (event.type = "keyDown" && RecordingIsNumberKey(event.key)) {
            local keyNum := RecordingGetNumberFromKey(event.key)
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
        summary: summary.Length > 0 ? RecordingJoin(summary, ", ") : "",
        counts: degradationCounts,
        boxes: boxes
    }
}

; ===== RECORDING HANDLERS =====
F9_RecordingOnly(*) {
    global recording, awaitingAssignment, breakMode, playback, annotationMode

    ; CRITICAL: Block ALL F9 operations during break mode
    if (breakMode) {
        RecordingStatus("🔴 BREAK MODE - Recording blocked")
        return
    }

    if (playback) {
        RecordingStatus("⏸️ Playback active")
        return
    }

    if (awaitingAssignment) {
        RecordingStatus("🎯 Assignment pending - ESC to cancel")
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
        RecordingStatus("❌ Recording error: " . e.Message)
        ; Emergency state reset
        recording := false
        SafeUninstallMouseHook()
        SafeUninstallKeyboardHook()
        ResetRecordingUI()
    }
}

ForceStartRecording() {
    global recording, currentMacro, macroEvents, mainGui, pendingBoxForTagging

    ; Force clean state
    recording := false
    SafeUninstallMouseHook()
    SafeUninstallKeyboardHook()

    ; PHASE 2D: Initialize mouse state
    CoordMode("Mouse", "Screen")  ; Ensure screen coordinates

    ; PHASE 2D: Get current mouse position to initialize tracking
    MouseGetPos(&initX, &initY)

    ; PHASE 2D: Small delay to ensure hooks are ready (50ms)
    Sleep(50)

    ; Start fresh
    recording := true
    currentMacro := "temp_recording_" . A_TickCount
    macroEvents[currentMacro] := []
    pendingBoxForTagging := ""

    InstallMouseHook()
    InstallKeyboardHook()

    ; PHASE 2D: Verify hooks installed successfully
    global mouseHook, keyboardHook
    if (!mouseHook || !keyboardHook) {
        recording := false
        RecordingStatus("❌ Failed to install hooks")
        return
    }

    ; Update UI
    if (mainGui && mainGui.HasProp("btnRecord")) {
        mainGui.btnRecord.Text := "🔴 Stop (F9)"
        mainGui.btnRecord.Opt("+Background0xDC143C")
    }

    RecordingStatus("🎥 RECORDING ACTIVE - Draw boxes, F9 to stop")
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
    awaitingAssignment := true
    RecordingStatus("Recording ready - press a numpad key to assign")
    ; FIX: Reduce timer frequency from 25ms to 100ms to lower CPU usage
    SetTimer(CheckForAssignment, 100)

    macroKey := currentMacro
    SetTimer(FinalizeRecording.Bind(macroKey, eventCount), -1)

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
        RecordingUpdateButton(buttonName)
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
    RecordingUpdateButton(buttonName)
}

; ===== RECORDING DEBUG FUNCTION =====
ShowRecordingDebug() {
    global recording, currentMacro, macroEvents, buttonNames

    debugInfo := "=== F9 DEBUG INFO ===`n"
    debugInfo .= "Recording: " . (recording ? "ACTIVE" : "INACTIVE") . "`n"
    debugInfo .= "Current Macro: " . currentMacro . "`n`n"

    totalMacros := 0
    for buttonName in buttonNames {
        if (macroEvents.Has(buttonName) && macroEvents[buttonName].Length > 0) {
            totalMacros++
        }
    }

    debugInfo .= "Total Macros: " . totalMacros . "`n"

    if (macroEvents.Has(currentMacro) && currentMacro != "") {
        debugInfo .= "Current Recording Events: " . macroEvents[currentMacro].Length . "`n"
    }

    MsgBox(debugInfo, "F9 Debug", "Icon!")
}











