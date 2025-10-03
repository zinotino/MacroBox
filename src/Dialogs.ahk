/*
==============================================================================
DIALOGS MODULE - Dialog and settings UI management
==============================================================================
Handles all dialog windows and settings interfaces
*/

; ===== MAIN SETTINGS DIALOG =====
ShowSettings() {
    ; Create settings dialog with tabbed interface
    settingsGui := Gui("+Resize", "⚙️ Configuration")
    settingsGui.SetFont("s9")

    ; Compact header
    settingsGui.Add("Text", "x20 y10 w520 h25 Center", "Configuration")
    settingsGui.SetFont("s10 Bold")

    ; Create tabbed interface
    tabs := settingsGui.Add("Tab3", "x20 y40 w520 h520", ["⚙️ Essential", "⚡ Execution Timing", "🎹 Hotkeys"])

    ; TAB 1: Essential Configuration
    tabs.UseTab(1)
    settingsGui.SetFont("s9")

    ; Canvas configuration section - PRIORITY #1
    settingsGui.Add("Text", "x30 y75 w480 h18", "🖼️ Canvas Calibration")
    settingsGui.SetFont("s8")

    ; Show canvas status based on calibration flags
    global isWideCanvasCalibrated, isNarrowCanvasCalibrated

    wideStatusText := isWideCanvasCalibrated ? "✅ Wide Configured" : "❌ Not Set"
    narrowStatusText := isNarrowCanvasCalibrated ? "✅ Narrow Configured" : "❌ Not Set"

    settingsGui.Add("Text", "x50 y98 w200 h16 " . (isWideCanvasCalibrated ? "cGreen" : "cRed"), wideStatusText)
    settingsGui.Add("Text", "x280 y98 w200 h16 " . (isNarrowCanvasCalibrated ? "cGreen" : "cRed"), narrowStatusText)
    settingsGui.SetFont("s9")

    btnConfigureWide := settingsGui.Add("Button", "x40 y118 w180 h28", "📐 Calibrate Wide")
    btnConfigureWide.OnEvent("Click", (*) => ConfigureWideCanvasFromSettings(settingsGui))

    btnConfigureNarrow := settingsGui.Add("Button", "x240 y118 w180 h28", "📐 Calibrate Narrow")
    btnConfigureNarrow.OnEvent("Click", (*) => ConfigureNarrowCanvasFromSettings(settingsGui))

    ; Macro pack management section
    settingsGui.Add("Text", "x30 y165 w480 h18", "📦 Macro Pack Sharing")

    btnCreatePack := settingsGui.Add("Button", "x40 y188 w180 h28", "📦 Create Pack")
    btnCreatePack.OnEvent("Click", (*) => CreateMacroPack())

    btnImportPack := settingsGui.Add("Button", "x240 y188 w180 h28", "📥 Import Pack")
    btnImportPack.OnEvent("Click", (*) => ImportMacroPack())

    ; System maintenance section
    settingsGui.Add("Text", "x30 y235 w480 h18", "🔧 System Maintenance")

    btnManualSave := settingsGui.Add("Button", "x40 y258 w120 h28", "💾 Save Now")
    btnManualSave.OnEvent("Click", (*) => ManualSaveConfig())

    btnManualRestore := settingsGui.Add("Button", "x175 y258 w120 h28", "📤 Restore Backup")
    btnManualRestore.OnEvent("Click", (*) => ManualRestoreConfig())

    btnClearConfig := settingsGui.Add("Button", "x310 y258 w120 h28", "🗑️ Clear Macros")
    btnClearConfig.OnEvent("Click", (*) => ClearAllMacros(settingsGui))

    ; Stats reset
    settingsGui.Add("Text", "x30 y305 w480 h18", "📊 Statistics")
    btnResetStats := settingsGui.Add("Button", "x40 y328 w180 h28", "📊 Reset All Stats")
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

    ; Preset buttons section (clear spacing from timing controls)
    settingsGui.Add("Text", "x30 y345 w480 h18", "🎚️ Timing Presets")

    btnFast := settingsGui.Add("Button", "x30 y368 w100 h25", "⚡ Fast")
    btnFast.OnEvent("Click", (*) => ApplyTimingPreset("fast", settingsGui))

    btnDefault := settingsGui.Add("Button", "x150 y368 w100 h25", "🎯 Default")
    btnDefault.OnEvent("Click", (*) => ApplyTimingPreset("default", settingsGui))

    btnSafe := settingsGui.Add("Button", "x270 y368 w100 h25", "🛡️ Safe")
    btnSafe.OnEvent("Click", (*) => ApplyTimingPreset("safe", settingsGui))

    btnSlow := settingsGui.Add("Button", "x390 y368 w100 h25", "🐌 Slow")
    btnSlow.OnEvent("Click", (*) => ApplyTimingPreset("slow", settingsGui))

    ; Instructions
    settingsGui.Add("Text", "x30 y405 w480 h50", "💡 Adjust timing delays to optimize macro execution speed vs reliability. Higher values = more reliable but slower execution. Use presets for quick setup.")

    ; TAB 3: Hotkeys
    tabs.UseTab(3)
    global hotkeyProfileActive, wasdHotkeyMap, wasdLabelsEnabled

    ; Header focused on utility functions
    settingsGui.Add("Text", "x30 y95 w480 h20", "🎮 Hotkey & Utility Configuration:")
    settingsGui.Add("Text", "x30 y115 w480 h15 c0x666666", "Configure keyboard shortcuts and utility functions")

    ; WASD Info - show current status
    wasdStatus := wasdLabelsEnabled ? "Enabled" : "Disabled"
    settingsGui.Add("Text", "x30 y140 w480 h15", "🏷️ WASD Labels: " . wasdStatus)

    ; Main Utility Hotkeys Section (clean layout without WASD clutter)
    settingsGui.Add("Text", "x30 y170 w480 h20", "🎮 Main Utility Hotkeys:")
    hotkeyY := 195

    ; Record Toggle
    settingsGui.Add("Text", "x30 y" . hotkeyY . " w130 h20", "Record Toggle:")
    editRecordToggle := settingsGui.Add("Edit", "x165 y" . (hotkeyY-2) . " w90 h20", hotkeyRecordToggle)
    hotkeyY += 25

    ; Submit/Direct Clear keys
    settingsGui.Add("Text", "x30 y" . hotkeyY . " w130 h20", "Submit:")
    editSubmit := settingsGui.Add("Edit", "x165 y" . (hotkeyY-2) . " w90 h20", hotkeySubmit)
    settingsGui.Add("Text", "x275 y" . hotkeyY . " w90 h20", "Direct Clear:")
    editDirectClear := settingsGui.Add("Edit", "x375 y" . (hotkeyY-2) . " w80 h20", hotkeyDirectClear)
    hotkeyY += 25

    ; Stats key (on separate row)
    settingsGui.Add("Text", "x30 y" . hotkeyY . " w130 h20", "Stats:")
    editStats := settingsGui.Add("Edit", "x165 y" . (hotkeyY-2) . " w90 h20", hotkeyStats)
    hotkeyY += 25

    ; Break Mode/Settings keys
    settingsGui.Add("Text", "x30 y" . hotkeyY . " w130 h20", "Break Mode:")
    editBreakMode := settingsGui.Add("Edit", "x165 y" . (hotkeyY-2) . " w90 h20", hotkeyBreakMode)
    settingsGui.Add("Text", "x275 y" . hotkeyY . " w90 h20", "Settings:")
    editSettings := settingsGui.Add("Edit", "x375 y" . (hotkeyY-2) . " w90 h20", hotkeySettings)
    hotkeyY += 25

    ; Layer Navigation
    settingsGui.Add("Text", "x30 y" . hotkeyY . " w130 h20", "Layer Prev:")
    editLayerPrev := settingsGui.Add("Edit", "x165 y" . (hotkeyY-2) . " w90 h20", hotkeyLayerPrev)
    settingsGui.Add("Text", "x275 y" . hotkeyY . " w90 h20", "Layer Next:")
    editLayerNext := settingsGui.Add("Edit", "x375 y" . (hotkeyY-2) . " w90 h20", hotkeyLayerNext)
    hotkeyY += 30

    ; Apply/Reset buttons for hotkeys
    btnApplyHotkeys := settingsGui.Add("Button", "x30 y" . hotkeyY . " w100 h25", "🎮 Apply Keys")
    btnApplyHotkeys.OnEvent("Click", (*) => ApplyHotkeySettings(editRecordToggle, editSubmit, editDirectClear, editStats, editBreakMode, editSettings, editLayerPrev, editLayerNext, settingsGui))

    btnResetHotkeys := settingsGui.Add("Button", "x150 y" . hotkeyY . " w100 h25", "🔄 Reset Keys")
    btnResetHotkeys.OnEvent("Click", (*) => ResetHotkeySettings(settingsGui))

    ; Enhanced Instructions (focused on utility functions)
    instructY := hotkeyY + 40
    settingsGui.Add("Text", "x30 y" . instructY . " w480 h15 c0x0066CC", "📋 Quick Instructions:")
    instructY += 20
    settingsGui.Add("Text", "x30 y" . instructY . " w480 h50", "• 🏷️ WASD labels show key mappings for buttons`n• ⚙️ Configure utility hotkeys above for your workflow`n• 💾 Apply to test changes, save to make permanent`n• ⌨️ All hotkeys work alongside standard numpad keys")
    instructY += 60
    settingsGui.Add("Text", "x30 y" . instructY . " w480 h15 c0x666666", "ℹ️ Focus on utility functions - WASD mapping handled automatically.")

    ; Show settings window
    settingsGui.Show("w580 h580")
}

ShowConfigMenu() {
    ShowSettings()
}

; ===== SETTINGS APPLY FUNCTIONS =====
ApplyLayerSettings(ddlCurrentLayer, ddlTotalLayers, settingsGui) {
    global currentLayer, totalLayers

    newCurrentLayer := Integer(ddlCurrentLayer.Text)
    newTotalLayers := Integer(ddlTotalLayers.Text)

    if (newCurrentLayer < 1 || newCurrentLayer > 5 || newTotalLayers < 1 || newTotalLayers > 5) {
        MsgBox("Layer values must be between 1 and 5.", "Invalid Layers", "Icon!")
        return
    }

    global currentLayer, totalLayers
    currentLayer := newCurrentLayer
    totalLayers := newTotalLayers

    ; Update UI
    SwitchLayer("")
    RefreshAllButtonAppearances()

    ; Save config
    SaveConfig()

    UpdateStatus("📚 Layer settings updated")
}

SaveSettings(settingsGui) {
    ; Apply current settings and save
    SaveConfig()
    settingsGui.Destroy()
    UpdateStatus("💾 Settings saved")
}

ApplyHotkeySettings(editRecordToggle, editSubmit, editDirectClear, editStats, editBreakMode, editSettings, editLayerPrev, editLayerNext, settingsGui) {
    global hotkeyRecordToggle, hotkeySubmit, hotkeyDirectClear, hotkeyStats, hotkeyBreakMode, hotkeySettings, hotkeyLayerPrev, hotkeyLayerNext

    try {
        ; Get new values from edit controls
        newRecordToggle := Trim(editRecordToggle.Text)
        newSubmit := Trim(editSubmit.Text)
        newDirectClear := Trim(editDirectClear.Text)
        newStats := Trim(editStats.Text)
        newBreakMode := Trim(editBreakMode.Text)
        newSettings := Trim(editSettings.Text)
        newLayerPrev := Trim(editLayerPrev.Text)
        newLayerNext := Trim(editLayerNext.Text)

        ; Basic validation - ensure no empty values
        if (newRecordToggle = "" || newSubmit = "" || newDirectClear = "" || newStats = "" || newBreakMode = "" || newSettings = "" || newLayerPrev = "" || newLayerNext = "") {
            MsgBox("All hotkey fields must be filled out.", "Invalid Hotkeys", "Icon!")
            return
        }

        ; Clear existing hotkeys before applying new ones
        try {
            Hotkey(hotkeyRecordToggle, "Off")
            Hotkey(hotkeySubmit, "Off")
            Hotkey(hotkeyDirectClear, "Off")
            Hotkey(hotkeyStats, "Off")
            Hotkey(hotkeyBreakMode, "Off")
            Hotkey(hotkeySettings, "Off")
            Hotkey(hotkeyLayerPrev, "Off")
            Hotkey(hotkeyLayerNext, "Off")
        } catch {
        }

        ; Update global variables
        hotkeyRecordToggle := newRecordToggle
        hotkeySubmit := newSubmit
        hotkeyDirectClear := newDirectClear
        hotkeyStats := newStats
        hotkeyBreakMode := newBreakMode
        hotkeySettings := newSettings
        hotkeyLayerPrev := newLayerPrev
        hotkeyLayerNext := newLayerNext

        ; Re-setup hotkeys
        SetupHotkeys()

        ; Update emergency button display
        UpdateEmergencyButtonText()

        ; Save to config
        SaveConfig()

        MsgBox("Hotkeys applied successfully!`n`nNew configuration:`nRecord: " . hotkeyRecordToggle . "`nSubmit: " . hotkeySubmit . "`nDirect Clear: " . hotkeyDirectClear . "`nStats: " . hotkeyStats . "`nBreak: " . hotkeyBreakMode . "`nSettings: " . hotkeySettings . "`nLayer Prev: " . hotkeyLayerPrev . "`nLayer Next: " . hotkeyLayerNext, "Hotkeys Updated", "Icon!")

    } catch Error as e {
        MsgBox("Failed to apply hotkeys: " . e.Message, "Error", "Icon!")
    }
}

ResetHotkeySettings(settingsGui) {
    global hotkeyRecordToggle, hotkeySubmit, hotkeyDirectClear, hotkeyStats, hotkeyBreakMode, hotkeySettings, hotkeyLayerPrev, hotkeyLayerNext

    result := MsgBox("Reset all hotkeys to defaults?`n`nRecord: F9`nSubmit: NumpadEnter`nDirect Clear: +Enter`nStats: F12`nBreak: ^b`nSettings: ^k`nLayer Prev: NumpadDiv`nLayer Next: NumpadSub", "Reset Hotkeys", "YesNo Icon?")

    if (result = "Yes") {
        ; Clear existing hotkeys
        try {
            Hotkey(hotkeyRecordToggle, "Off")
            Hotkey(hotkeySubmit, "Off")
            Hotkey(hotkeyDirectClear, "Off")
            Hotkey(hotkeyStats, "Off")
            Hotkey(hotkeyBreakMode, "Off")
            Hotkey(hotkeySettings, "Off")
            Hotkey(hotkeyLayerPrev, "Off")
            Hotkey(hotkeyLayerNext, "Off")
        } catch {
        }

        ; Reset to defaults
        hotkeyRecordToggle := "F9"
        hotkeySubmit := "NumpadEnter"
        hotkeyDirectClear := "+Enter"
        hotkeyStats := "F12"
        hotkeyBreakMode := "^b"
        hotkeySettings := "^k"
        hotkeyLayerPrev := "NumpadDiv"
        hotkeyLayerNext := "NumpadSub"

        ; Re-setup hotkeys
        SetupHotkeys()

        ; Save to config
        SaveConfig()

        ; Refresh settings GUI
        settingsGui.Destroy()
        ShowSettings()

        UpdateStatus("🎮 Hotkeys reset to defaults")
    }
}

ApplyAutomationSettings(chkAutoExecutionMode, editAutoInterval, editAutoMaxCount, settingsGui) {
    global autoExecutionMode, autoExecutionInterval, autoExecutionMaxCount

    ; Validate inputs
    interval := Integer(editAutoInterval.Text)
    maxCount := Integer(editAutoMaxCount.Text)

    if (interval < 1 || interval > 300) {
        MsgBox("Interval must be between 1 and 300 seconds.", "Invalid Interval", "Icon!")
        return
    }

    if (maxCount < 0) {
        MsgBox("Max executions cannot be negative.", "Invalid Max Count", "Icon!")
        return
    }

    ; Apply settings
    autoExecutionMode := chkAutoExecutionMode.Value
    autoExecutionInterval := interval * 1000  ; Convert to milliseconds
    autoExecutionMaxCount := maxCount

    ; Save configuration
    SaveConfig()

    status := autoExecutionMode ? "✅ Auto execution enabled" : "❌ Auto execution disabled"
    UpdateStatus(status . " (interval: " . interval . "s, max: " . (maxCount = 0 ? "infinite" : maxCount) . ")")
}

ApplyWASDSettings(chkWASDProfile, chkWASDLabels, settingsGui) {
    global hotkeyProfileActive, wasdLabelsEnabled

    newProfileActive := chkWASDProfile.Value
    newLabelsEnabled := chkWASDLabels.Value

    ; Check if settings changed
    if (newProfileActive != hotkeyProfileActive || newLabelsEnabled != wasdLabelsEnabled) {
        hotkeyProfileActive := newProfileActive
        wasdLabelsEnabled := newLabelsEnabled

        ; Apply WASD profile changes
        if (hotkeyProfileActive) {
            SetupWASDHotkeys()
            UpdateStatus("🎹 WASD Hotkey Profile ACTIVATED")
        } else {
            DisableWASDHotkeys()
            UpdateStatus("🎹 WASD Hotkey Profile DEACTIVATED")
        }

        ; Update button labels
        UpdateButtonLabelsWithWASD()
        RefreshAllButtonAppearances()

        ; Save configuration
        SaveConfig()
    }

    UpdateStatus("🎹 WASD settings applied")
}

SaveAllSettings(settingsGui, editBoxDrawDelay, editMouseClickDelay, editMenuClickDelay, editMouseDragDelay, editMouseReleaseDelay, editBetweenBoxDelay, editKeyPressDelay, editFocusDelay, editMouseHoverDelay) {
    global boxDrawDelay, mouseClickDelay, menuClickDelay, mouseDragDelay, mouseReleaseDelay, betweenBoxDelay, keyPressDelay, focusDelay, mouseHoverDelay, smartBoxClickDelay, smartMenuClickDelay

    ; Apply timing settings
    boxDrawDelay := Integer(editBoxDrawDelay.Text)
    mouseClickDelay := Integer(editMouseClickDelay.Text)
    menuClickDelay := Integer(editMenuClickDelay.Text)
    mouseDragDelay := Integer(editMouseDragDelay.Text)
    mouseReleaseDelay := Integer(editMouseReleaseDelay.Text)
    betweenBoxDelay := Integer(editBetweenBoxDelay.Text)
    keyPressDelay := Integer(editKeyPressDelay.Text)
    focusDelay := Integer(editFocusDelay.Text)
    mouseHoverDelay := Integer(editMouseHoverDelay.Text)

    ; Save all configuration
    SaveConfig()

    ; Close dialog
    settingsGui.Destroy()

    UpdateStatus("💾 All settings saved successfully")
}

; ===== CLEAR DIALOG =====
ShowClearDialog() {
    global currentLayer, macroEvents, buttonNames

    result := MsgBox("Clear all macros on Layer " . currentLayer . "?", "Clear Layer", "YesNo Icon!")

    if (result = "Yes") {
        ; Clear all macros on current layer
        clearedCount := 0
        for buttonName in buttonNames {
            layerMacroName := "L" . currentLayer . "_" . buttonName
            if (macroEvents.Has(layerMacroName)) {
                macroEvents.Delete(layerMacroName)
                clearedCount++
            }
        }

        ; Update UI
        RefreshAllButtonAppearances()
        SaveMacroState()

        UpdateStatus("🗑️ Cleared " . clearedCount . " macros from Layer " . currentLayer)
    }
}

; ===== TIMING FUNCTIONS =====
UpdateTimingFromEdit(timingVar, editControl, *) {
    global
    ; Use proper AHK v2 syntax for dynamic variable assignment
    newValue := Integer(editControl.Text)
    Switch timingVar {
        Case "boxDrawDelay": boxDrawDelay := newValue
        Case "mouseClickDelay": mouseClickDelay := newValue
        Case "menuClickDelay": menuClickDelay := newValue
        Case "mouseDragDelay": mouseDragDelay := newValue
        Case "mouseReleaseDelay": mouseReleaseDelay := newValue
        Case "betweenBoxDelay": betweenBoxDelay := newValue
        Case "keyPressDelay": keyPressDelay := newValue
        Case "focusDelay": focusDelay := newValue
        Case "mouseHoverDelay": mouseHoverDelay := newValue
        Case "smartBoxClickDelay": smartBoxClickDelay := newValue
        Case "smartMenuClickDelay": smartMenuClickDelay := newValue
    }
}

ApplyTimingPreset(preset, settingsGui, *) {
    global boxDrawDelay, mouseClickDelay, menuClickDelay, mouseDragDelay, mouseReleaseDelay, betweenBoxDelay, keyPressDelay, focusDelay, mouseHoverDelay, smartBoxClickDelay, smartMenuClickDelay

    switch preset {
        case "fast":
            boxDrawDelay := 50
            mouseClickDelay := 60
            menuClickDelay := 100
            mouseDragDelay := 65
            mouseReleaseDelay := 65
            betweenBoxDelay := 150
            keyPressDelay := 15
            focusDelay := 60
            mouseHoverDelay := 25
            smartBoxClickDelay := 25  ; Ultra-fast for intelligent system
            smartMenuClickDelay := 80  ; Fast but reliable for menus
        case "default":
            boxDrawDelay := 75
            mouseClickDelay := 85
            menuClickDelay := 150
            mouseDragDelay := 90
            mouseReleaseDelay := 90
            betweenBoxDelay := 200
            keyPressDelay := 20
            focusDelay := 80
            mouseHoverDelay := 35
            smartBoxClickDelay := 35  ; Optimized for smooth box drawing
            smartMenuClickDelay := 120  ; Balanced for menu reliability
        case "safe":
            boxDrawDelay := 100
            mouseClickDelay := 110
            menuClickDelay := 200
            mouseDragDelay := 115
            mouseReleaseDelay := 115
            betweenBoxDelay := 250
            keyPressDelay := 25
            focusDelay := 100
            mouseHoverDelay := 45
            smartBoxClickDelay := 50  ; Slower but very smooth
            smartMenuClickDelay := 180  ; Conservative for maximum reliability
        case "slow":
            boxDrawDelay := 150
            mouseClickDelay := 160
            menuClickDelay := 250
            mouseDragDelay := 165
            mouseReleaseDelay := 165
            betweenBoxDelay := 350
            keyPressDelay := 35
            focusDelay := 120
            mouseHoverDelay := 60
            smartBoxClickDelay := 75  ; Very slow but extremely smooth
            smartMenuClickDelay := 220  ; Maximum reliability for menus
    }

    ; Update the edit controls in the GUI
    if (settingsGui.HasProp("boxDelayEdit")) {
        settingsGui.boxDelayEdit.Value := boxDrawDelay
    }
    if (settingsGui.HasProp("clickDelayEdit")) {
        settingsGui.clickDelayEdit.Value := mouseClickDelay
    }
    if (settingsGui.HasProp("menuClickDelayEdit")) {
        settingsGui.menuClickDelayEdit.Value := menuClickDelay
    }
    if (settingsGui.HasProp("dragDelayEdit")) {
        settingsGui.dragDelayEdit.Value := mouseDragDelay
    }
    if (settingsGui.HasProp("releaseDelayEdit")) {
        settingsGui.releaseDelayEdit.Value := mouseReleaseDelay
    }
    if (settingsGui.HasProp("betweenDelayEdit")) {
        settingsGui.betweenDelayEdit.Value := betweenBoxDelay
    }
    if (settingsGui.HasProp("keyDelayEdit")) {
        settingsGui.keyDelayEdit.Value := keyPressDelay
    }
    if (settingsGui.HasProp("focusDelayEdit")) {
        settingsGui.focusDelayEdit.Value := focusDelay
    }
    if (settingsGui.HasProp("hoverDelayEdit")) {
        settingsGui.hoverDelayEdit.Value := mouseHoverDelay
    }
    if (settingsGui.HasProp("smartBoxClickDelayEdit")) {
        settingsGui.smartBoxClickDelayEdit.Value := smartBoxClickDelay
    }
    if (settingsGui.HasProp("smartMenuClickDelayEdit")) {
        settingsGui.smartMenuClickDelayEdit.Value := smartMenuClickDelay
    }

    SaveConfig()
    UpdateStatus("⏱️ " . preset . " preset applied")
}

; ===== MACRO PACK FUNCTIONS =====
BrowseMacroPacks(*) {
    global workDir

    try {
        packDir := workDir . "\packs"

        if (!DirExist(packDir)) {
            MsgBox("No macro packs found. Create a macro pack first using the 'Create Macro Pack' button.", "No Packs Found", "Icon!")
            return
        }

        ; Get list of packs
        packList := ""
        packCount := 0

        Loop Files, packDir . "\*", "D" {
            if (A_LoopFileName != "." && A_LoopFileName != "..") {
                packCount++
                metadataFile := A_LoopFileFullPath . "\metadata.json"
                packInfo := A_LoopFileName

                if (FileExist(metadataFile)) {
                    try {
                        metadata := FileRead(metadataFile)
                        ; Simple JSON parsing for name
                        if (RegExMatch(metadata, '"name":"([^"]+)"', &match)) {
                            packInfo := match[1]
                        }
                    } catch {
                        ; Keep default name if parsing fails
                    }
                }

                packList .= packCount . ". " . packInfo . "`n"
            }
        }

        if (packCount = 0) {
            MsgBox("No macro packs found in the packs directory.", "No Packs Found", "Icon!")
            return
        }

        ; Show pack browser dialog
        browseGui := Gui("+Resize", "📚 Macro Pack Browser")
        browseGui.SetFont("s10")

        browseGui.Add("Text", "x20 y20 w400 h20", "Available Macro Packs (" . packCount . " found):")
        browseGui.Add("Text", "x20 y45 w400 h" . (packCount * 15 + 20), packList)

        browseGui.Add("Text", "x20 y" . (70 + packCount * 15) . " w400 h40", "Macro packs contain saved macros from all layers. To use a pack, copy its contents to your config directory manually.")

        btnClose := browseGui.Add("Button", "x350 y" . (120 + packCount * 15) . " w70 h25", "Close")
        btnClose.OnEvent("Click", (*) => browseGui.Destroy())

        browseGui.Show("w450 h" . (160 + packCount * 15))

    } catch Error as e {
        MsgBox("Failed to browse macro packs: " . e.Message, "Browse Error", "Icon!")
    }
}

; ===== CANVAS CONFIGURATION =====
ConfigureWideCanvasFromSettings(settingsGui) {
    settingsGui.Hide()
    CalibrateWideCanvasArea()
    settingsGui.Destroy()
    ShowSettings()  ; Refresh the settings dialog
}

ConfigureNarrowCanvasFromSettings(settingsGui) {
    settingsGui.Hide()
    CalibrateNarrowCanvasArea()
    settingsGui.Destroy()
    ShowSettings()  ; Refresh the settings dialog
}

; ===== SYSTEM MAINTENANCE =====
ClearAllMacros(settingsGui, *) {
    global macroEvents, buttonNames, currentLayer

    result := MsgBox("⚠️ Clear ALL macros from ALL layers?`n`nThis action cannot be undone!", "Clear All Macros", "YesNo Icon!")

    if (result = "Yes") {
        clearedCount := 0
        for layer in 1..5 {
            for buttonName in buttonNames {
                layerMacroName := "L" . layer . "_" . buttonName
                if (macroEvents.Has(layerMacroName)) {
                    macroEvents.Delete(layerMacroName)
                    clearedCount++
                }
            }
        }

        ; Update UI
        RefreshAllButtonAppearances()
        SaveMacroState()

        settingsGui.Destroy()
        UpdateStatus("🗑️ Cleared " . clearedCount . " macros from all layers")
    }
}

ManualSaveConfig(*) {
    try {
        SaveConfig()
        MsgBox("Configuration saved successfully!", "Manual Save", "Icon!")
    } catch Error as e {
        MsgBox("Failed to save configuration: " . e.Message, "Save Error", "Icon!")
    }
}

ManualRestoreConfig(*) {
    global configFile

    configBackup := configFile . ".backup"
    if (!FileExist(configBackup)) {
        MsgBox("No backup file found at: " . configBackup, "No Backup", "Icon!")
        return
    }

    result := MsgBox("Restore configuration from backup?`n`nThis will replace your current settings with the backup version.", "Restore Backup", "YesNo Icon!")

    if (result = "Yes") {
        try {
            ; Copy backup to main config
            FileCopy(configBackup, configFile, 1)

            ; Reload configuration
            LoadConfig()

            ; Refresh UI
            RefreshAllButtonAppearances()

            MsgBox("Configuration restored from backup successfully!`n`nPlease restart the application for all changes to take effect.", "Restore Complete", "Icon!")
        } catch Error as e {
            MsgBox("Failed to restore from backup: " . e.Message, "Restore Error", "Icon!")
        }
    }
}

ResetStatsFromSettings(settingsGui, *) {
    result := MsgBox("Reset all statistics and performance data?`n`nThis will clear execution history and performance metrics.", "Reset Statistics", "YesNo Icon!")

    if (result = "Yes") {
        try {
            ; Call the reset function from Stats.ahk
            ResetAllStats()
            UpdateStatus("📊 Stats reset")
        } catch Error as e {
            UpdateStatus("⚠️ Error resetting stats")
        }
        settingsGui.Destroy()
    }
}
