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

; ===== TOGGLE WASD LABELS =====
ToggleWASDLabels() {
    global wasdLabelsEnabled, wasdToggleBtn, wasdHotkeyMap, buttonNames

    ; Toggle the state (visual only - no standalone hotkeys)
    wasdLabelsEnabled := !wasdLabelsEnabled

    ; REMOVED: Standalone key hotkeys to prevent typing interference
    ; WASD hotkeys now ONLY work with CapsLock modifier (CapsLock & key)
    ; This ensures zero interference with normal typing

    ; Update grid outline color to show WASD mode state
    UpdateGridOutlineColor()

    ; Clear any potentially conflicting labels and rebuild properly
    UpdateButtonLabelsWithWASD()

    ; Force visual update of all buttons to show new labels
    for buttonName in buttonNames {
        UpdateButtonAppearance(buttonName)
    }

    ; Save configuration immediately to persist state
    SaveConfig()

    UpdateStatus(wasdLabelsEnabled ? "WASD mode enabled - button labels show key mappings" : "WASD mode disabled - numpad labels restored")
}



; ===== HOTKEY PROFILE FUNCTIONS =====
ToggleHotkeyProfile() {
    global hotkeyProfileActive, buttonNames

    local buttonName

    hotkeyProfileActive := !hotkeyProfileActive

    if (hotkeyProfileActive) {
        SetupWASDHotkeys()
        UpdateStatus("🎹 WASD Hotkey Profile ACTIVATED")
    } else {
        DisableWASDHotkeys()
        UpdateStatus("🎹 WASD Hotkey Profile DEACTIVATED")
    }

    ; Update labels immediately when profile state changes
    UpdateButtonLabelsWithWASD()

    ; Force visual update of all buttons to show new labels
    for buttonName in buttonNames {
        UpdateButtonAppearance(buttonName)
    }

    ; Save the state for persistence
    SaveConfig()
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

        ; Regular standalone keys are only enabled when WASD mode is toggled on
        ; This prevents accidental macro execution when typing normally

    } catch {
        ; Silent fail
    }
}

DisableWASDHotkeys() {
    global wasdHotkeyMap, capsLockPressed

    local wasdKey, hotkeyCombo, keyError

    try {
        ; Disable CapsLock modifier
        Hotkey("CapsLock", "Off")
        Hotkey("CapsLock Up", "Off")

        ; Clear the pressed state
        capsLockPressed := false

        ; Disable all mapped key combinations
        for wasdKey, buttonName in wasdHotkeyMap {
            try {
                hotkeyCombo := "CapsLock & " . wasdKey
                Hotkey(hotkeyCombo, "Off")
            } catch Error as keyError {
                ; Skip individual key errors but continue with others
            }
        }

        ; Restore normal CapsLock functionality when profile is disabled
        SetCapsLockState("Off")

    } catch {
        ; Silent fail
    }
}

CapsLockDown() {
    global capsLockPressed, hotkeyProfileActive

    ; Only register CapsLock press if hotkey profile is active
    if (hotkeyProfileActive) {
        capsLockPressed := true
        ; Prevent CapsLock state change in system
        SetCapsLockState("Off")
    }
}

CapsLockUp() {
    global capsLockPressed, hotkeyProfileActive

    ; Always clear the pressed state
    capsLockPressed := false

    ; Ensure CapsLock state remains off when using as modifier
    if (hotkeyProfileActive) {
        SetCapsLockState("Off")
    }
}

ExecuteWASDMacro(buttonName, *) {
    global hotkeyProfileActive

    ; Enhanced validation with better user feedback
    if (!hotkeyProfileActive) {
        return
    }

    ; Note: CapsLock modifier is already enforced by "CapsLock & key" syntax
    ; No need to check capsLockPressed state since hotkey won't trigger without CapsLock

    SafeExecuteMacroByKey(buttonName)
}

; ===== HOTKEY SETUP - FIXED F9 SYSTEM =====
SetupHotkeys() {
    global hotkeyRecordToggle, hotkeySubmit, hotkeyDirectClear, hotkeyEmergency, hotkeyBreakMode
    global hotkeySettings, hotkeyStats

    local hotkeyCombo

    try {
        ; CRITICAL: Clear any existing configured hotkey to prevent conflicts
        try {
            Hotkey(hotkeyRecordToggle, "Off")
        } catch {
        }

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

        ; Hotkey profile toggle (not configurable - keep as Ctrl+H)
        Hotkey("^h", (*) => ToggleHotkeyProfile())

        ; Configuration menu access - use configured key (default Ctrl+K)
        if (hotkeySettings != "") {
            Hotkey(hotkeySettings, (*) => ShowSettings())
        }

        ; Manual state reset (not configurable - keep as Ctrl+Shift+R)
        Hotkey("^+r", (*) => EmergencyStop())

        ; Debug (not configurable - keep as F11)
        Hotkey("F11", (*) => ShowRecordingDebug())

        ; Test stats recording (removed - use external test files)
        ; Hotkey("^t", (*) => TestStatsRecording())

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

        ; WASD hotkeys for macro execution (only if profile will be active)
        ; NOTE: SetupWASDHotkeys() will be called later in LoadConfig if needed

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