; ===== HOTKEYS MODULE =====
; Contains all hotkey setup and management functions
; Dependencies: Core.ahk (for global variables), GUI.ahk (for UpdateButtonLabelsWithWASD, UpdateButtonAppearance)

; ===== HOTKEY PROFILE SYSTEM =====

; Initialize WASD hotkey mappings
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

    ; Try to load custom mappings from file
    LoadWASDMappingsFromFile()

    ; Update button labels to show WASD keys
    UpdateButtonLabelsWithWASD()
}

; ===== UPDATE BUTTON LABELS WITH WASD KEYS =====
UpdateButtonLabelsWithWASD() {
    global buttonCustomLabels, wasdHotkeyMap, buttonNames

    ; Create reverse mapping from numpad to WASD
    numpadToWASD := Map()
    for wasdKey, numpadKey in wasdHotkeyMap {
        numpadToWASD[numpadKey] := StrUpper(wasdKey)
    }

    ; Always show both numpad and WASD keys for buttons that have WASD mapping
    for buttonName in buttonNames {
        if (numpadToWASD.Has(buttonName)) {
            wasdKey := numpadToWASD[buttonName]
            buttonCustomLabels[buttonName] := buttonName . " / " . wasdKey
        } else {
            ; Show only numpad name for buttons without WASD mapping
            buttonCustomLabels[buttonName] := buttonName
        }
    }
}





SetupWASDHotkeys() {
    global wasdHotkeyMap

    try {
        ; Setup CapsLock as modifier with improved logic
        Hotkey("CapsLock", (*) => CapsLockDown(), "On")
        Hotkey("CapsLock Up", (*) => CapsLockUp(), "On")

        ; Setup all mapped keys with CapsLock modifier
        ; Enhanced to include 123qweasdzxc combinations
        for wasdKey, numpadKey in wasdHotkeyMap {
            try {
                hotkeyCombo := "CapsLock & " . wasdKey
                Hotkey(hotkeyCombo, ExecuteWASDMacro.Bind(numpadKey), "On")
            } catch {
                ; Skip individual key conflicts but continue with others
            }
        }


    } catch {
        ; Silent fail
    }
}


CapsLockDown() {
    global capsLockPressed

    ; Always register CapsLock press for WASD macros
    capsLockPressed := true
    ; Prevent CapsLock state change in system
    SetCapsLockState("Off")
}

CapsLockUp() {
    global capsLockPressed

    ; Always clear the pressed state
    capsLockPressed := false

    ; Ensure CapsLock state remains off when using as modifier
    SetCapsLockState("Off")
}

ExecuteWASDMacro(buttonName, *) {
    ; CapsLock modifier is enforced by "CapsLock & key" syntax
    ; No need to check capsLockPressed state since hotkey won't trigger without CapsLock

    SafeExecuteMacroByKey(buttonName)
}

; ===== HOTKEY SETUP - FIXED F9 SYSTEM =====
SetupHotkeys() {
    global hotkeyRecordToggle, hotkeySubmit, hotkeyDirectClear, hotkeyEmergency, hotkeyBreakMode
    global hotkeyLayerPrev, hotkeyLayerNext, hotkeySettings, hotkeyStats

    local hotkeyCombo

    try {
        ; CRITICAL: Clear any existing configured hotkey to prevent conflicts
        try {
            Hotkey(hotkeyRecordToggle, "Off")
        } catch {
        }

        ; Sleep(50) - REMOVED for rapid labeling performance

        ; Recording control - use configured key (default F9)
        if (hotkeyRecordToggle != "") {
            Hotkey(hotkeyRecordToggle, F9_RecordingOnly, "On")
        }

        ; Stats display - use configured key (default F12)
        if (hotkeyStats != "") {
            Hotkey(hotkeyStats, (*) => ShowStatsMenu())
        }

        ; Break mode toggle - use configured key (default Ctrl+B)
        if (hotkeyBreakMode != "") {
            Hotkey(hotkeyBreakMode, (*) => ToggleBreakMode())
        }


        ; Configuration menu access - use configured key (default Ctrl+K)
        if (hotkeySettings != "") {
            Hotkey(hotkeySettings, (*) => ShowSettings())
        }

        ; Manual state reset (not configurable - keep as Ctrl+Shift+R)
        Hotkey("^+r", (*) => ForceStateReset())

        ; Debug (not configurable - keep as F11)
        Hotkey("F11", (*) => ShowRecordingDebug())

        ; Test stats recording (removed - use external test files)
        ; Hotkey("^t", (*) => TestStatsRecording())

        ; Layer navigation - use configured keys
        if (hotkeyLayerPrev != "") {
            Hotkey(hotkeyLayerPrev, (*) => SwitchLayer("prev"))
        }
        if (hotkeyLayerNext != "") {
            Hotkey(hotkeyLayerNext, (*) => SwitchLayer("next"))
        }

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

        ; Shift+Numpad for clear degradation executions
        Hotkey("+Numpad7", (*) => ShiftNumpadClearExecution("Num7"))
        Hotkey("+Numpad8", (*) => ShiftNumpadClearExecution("Num8"))
        Hotkey("+Numpad9", (*) => ShiftNumpadClearExecution("Num9"))
        Hotkey("+Numpad4", (*) => ShiftNumpadClearExecution("Num4"))
        Hotkey("+Numpad5", (*) => ShiftNumpadClearExecution("Num5"))
        Hotkey("+Numpad6", (*) => ShiftNumpadClearExecution("Num6"))
        Hotkey("+Numpad1", (*) => ShiftNumpadClearExecution("Num1"))
        Hotkey("+Numpad2", (*) => ShiftNumpadClearExecution("Num2"))
        Hotkey("+Numpad3", (*) => ShiftNumpadClearExecution("Num3"))
        Hotkey("+Numpad0", (*) => ShiftNumpadClearExecution("Num0"))
        Hotkey("+NumpadDot", (*) => ShiftNumpadClearExecution("NumDot"))
        Hotkey("+NumpadMult", (*) => ShiftNumpadClearExecution("NumMult"))

        ; CapsLock combination hotkeys for layer switching
        Hotkey("CapsLock & 1", (*) => SwitchToLayer(1))
        Hotkey("CapsLock & 2", (*) => SwitchToLayer(2))
        Hotkey("CapsLock & 3", (*) => SwitchToLayer(3))
        Hotkey("CapsLock & 4", (*) => SwitchToLayer(4))

        ; WASD hotkeys for macro execution (always active)
        SetupWASDHotkeys()

        ; Utility - use configured keys
        if (hotkeySubmit != "") {
            Hotkey(hotkeySubmit, (*) => SubmitCurrentImage())
        }
        if (hotkeyDirectClear != "") {
            Hotkey(hotkeyDirectClear, (*) => DirectClearExecution())
        }
        if (hotkeyEmergency != "") {
            Hotkey(hotkeyEmergency, (*) => EmergencyStop())
        }

    } catch Error as e {
        UpdateStatus("⚠️ Hotkey setup failed")
        MsgBox("Hotkey error: " . e.Message, "Setup Error", "Icon!")
    }
}