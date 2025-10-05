/*
==============================================================================
GUI EVENTS MODULE - Event handlers and user interactions
==============================================================================
Handles button clicks, context menus, layer switching, and mode toggles
*/

; ===== BUTTON EVENT HANDLERS =====
HandleButtonClick(buttonName, *) {
    ExecuteMacro(buttonName)
}

HandleContextMenu(buttonName, *) {
    ShowContextMenuCleaned(buttonName)
}

; ===== CONTEXT MENU =====
ShowContextMenuCleaned(buttonName) {
    global currentLayer, macroEvents, buttonThumbnails, degradationTypes, severityLevels, buttonAutoSettings

    layerMacroName := "L" . currentLayer . "_" . buttonName

    ; Create context menu
    contextMenu := Menu()

    ; Commands submenu at the top - organized by degradation type
    commandsMenu := Menu()
    for id, typeName in degradationTypes {
        typeMenu := Menu()
        for severity in severityLevels {
            presetName := StrTitle(typeName) . " (" . StrTitle(severity) . ")"
            typeMenu.Add(StrTitle(severity), AssignJsonAnnotation.Bind(buttonName, presetName))
        }
        commandsMenu.Add(StrTitle(typeName), typeMenu)
    }
    contextMenu.Add("⚡ Commands", commandsMenu)
    contextMenu.Add()  ; Separator

    ; Clear macro option (if macro exists)
    if (macroEvents.Has(layerMacroName) && macroEvents[layerMacroName].Length > 0) {
        contextMenu.Add("🗑️ Clear Macro", (*) => ClearMacro(buttonName))
        contextMenu.Add()  ; Separator
    }

    ; Visual customization section
    if (buttonThumbnails.Has(layerMacroName)) {
        contextMenu.Add("🖼️ Remove Thumbnail", (*) => RemoveThumbnail(buttonName))
    } else {
        contextMenu.Add("🖼️ Add Thumbnail", (*) => AddThumbnail(buttonName))
    }

    ; Auto execution section
    buttonKey := "L" . currentLayer . "_" . buttonName
    hasAutoSettings := buttonAutoSettings.Has(buttonKey)
    autoEnabled := hasAutoSettings && buttonAutoSettings[buttonKey].enabled

    if (autoEnabled) {
        contextMenu.Add("❌ Disable Auto Mode", (*) => ToggleAutoEnable(buttonName))
        contextMenu.Add("🔧 Auto Settings", (*) => ConfigureAutoMode(buttonName))
    } else {
        contextMenu.Add("⚙️ Enable Auto Mode", (*) => ToggleAutoEnable(buttonName))
    }

    ; Show menu
    contextMenu.Show()
}

; ===== JSON ANNOTATION ASSIGNMENT =====
AssignJsonAnnotation(buttonName, presetName, *) {
    global currentLayer, macroEvents, jsonAnnotations, degradationTypes, annotationMode

    layerMacroName := "L" . currentLayer . "_" . buttonName

    ; Use current annotation mode
    currentMode := annotationMode
    fullPresetName := presetName . (currentMode = "Narrow" ? " Narrow" : "")

    if (jsonAnnotations.Has(fullPresetName)) {
        parts := StrSplit(presetName, " (")
        typeName := parts[1]
        severity := StrLower(SubStr(parts[2], 1, -1))

        categoryId := 0
        for id, name in degradationTypes {
            if (StrTitle(name) = typeName) {
                categoryId := id
                break
            }
        }

        if (categoryId > 0) {
            macroEvents[layerMacroName] := [{
                type: "jsonAnnotation",
                annotation: jsonAnnotations[fullPresetName],
                mode: currentMode,
                categoryId: categoryId,
                severity: severity
            }]
            UpdateButtonAppearance(buttonName)
            SaveConfig()
            UpdateStatus("🏷️ Assigned " . presetName . " to " . buttonName)
        }
    } else {
        UpdateStatus("❌ Annotation not found")
    }
}

; ===== AUTO MODE FUNCTIONS =====
ToggleAutoEnable(buttonName, *) {
    global buttonAutoSettings, currentLayer, macroEvents, autoExecutionInterval

    buttonKey := "L" . currentLayer . "_" . buttonName

    ; Check if button has a macro
    if (!macroEvents.Has(buttonKey) || macroEvents[buttonKey].Length = 0) {
        MsgBox("No macro recorded for " . buttonName . " on Layer " . currentLayer . ". Record a macro first!", "Auto Mode", "Icon!")
        return
    }

    ; Toggle enable state
    if (buttonAutoSettings.Has(buttonKey)) {
        ; Settings exist - toggle enable state
        buttonAutoSettings[buttonKey].enabled := !buttonAutoSettings[buttonKey].enabled
        status := buttonAutoSettings[buttonKey].enabled ? "✅ Auto enabled: " : "❌ Auto disabled: "
        UpdateStatus(status . buttonName)
    } else {
        ; No settings exist - create with global defaults and enable
        buttonAutoSettings[buttonKey] := {
            enabled: true,
            interval: autoExecutionInterval,  ; Use global default
            maxCount: 0                        ; infinite default
        }
        UpdateStatus("✅ Auto enabled: " . buttonName)
    }

    ; Update button appearance and save
    UpdateButtonAppearance(buttonName)
    SaveConfig()
}

ConfigureAutoMode(buttonName, *) {
    global buttonAutoSettings, currentLayer, macroEvents, mainGui, autoExecutionInterval

    buttonKey := "L" . currentLayer . "_" . buttonName

    ; Check if button has a macro
    if (!macroEvents.Has(buttonKey) || macroEvents[buttonKey].Length = 0) {
        MsgBox("No macro recorded for " . buttonName . " on Layer " . currentLayer . ". Record a macro first!", "Auto Mode Setup", "Icon!")
        return
    }

    ; Get existing settings or use global defaults
    currentSettings := buttonAutoSettings.Has(buttonKey) ? buttonAutoSettings[buttonKey] : {enabled: false, interval: autoExecutionInterval, maxCount: 0}

    ; Create configuration dialog
    configDialog := Gui("+Owner" . mainGui.Hwnd, "Auto Mode Setup - " . buttonName)

    configDialog.Add("Text", "x10 y10", "Auto Mode Configuration for " . buttonName . " (Layer " . currentLayer . ")")

    ; Enable checkbox
    enableCheck := configDialog.Add("Checkbox", "x10 y35", "Enable Auto Mode")
    enableCheck.Value := currentSettings.enabled

    configDialog.Add("Text", "x10 y65", "Interval (seconds):")
    intervalEdit := configDialog.Add("Edit", "x120 y63 w60", String(currentSettings.interval / 1000))

    configDialog.Add("Text", "x10 y95", "Max executions (0 = infinite):")
    countEdit := configDialog.Add("Edit", "x160 y93 w60", String(currentSettings.maxCount))

    configDialog.Add("Text", "x10 y125 w320 h40", "Note: Use numpad hotkeys or right-click → Auto Mode to trigger execution")

    btnSave := configDialog.Add("Button", "x10 y170 w100 h30", "Save Settings")
    btnCancel := configDialog.Add("Button", "x120 y170 w100 h30", "Cancel")

    btnSave.OnEvent("Click", SaveAutoSettings.Bind(configDialog, buttonKey, enableCheck, intervalEdit, countEdit, buttonName))
    btnCancel.OnEvent("Click", (*) => configDialog.Destroy())

    configDialog.Show("w340 h210")
}

SaveAutoSettings(configDialog, buttonKey, enableCheck, intervalEdit, countEdit, buttonName, *) {
    global buttonAutoSettings

    ; Read values before destroying dialog
    isEnabled := enableCheck.Value
    intervalValue := Integer(intervalEdit.Text) * 1000
    maxCountValue := Integer(countEdit.Text)

    ; Save settings
    buttonAutoSettings[buttonKey] := {
        enabled: isEnabled,
        interval: intervalValue,
        maxCount: maxCountValue
    }

    configDialog.Destroy()

    ; Update button appearance and save
    UpdateButtonAppearance(buttonName)
    SaveConfig()

    status := isEnabled ? "✅ Auto mode enabled for " : "❌ Auto mode disabled for "
    UpdateStatus(status . buttonName)
}

; ===== LAYER MANAGEMENT =====
SwitchLayer(direction) {
    global currentLayer, totalLayers, layerIndicator, layerNames, buttonNames, gridOutline, layerBorderColors

    if (direction = "next") {
        currentLayer++
        if (currentLayer > totalLayers)
            currentLayer := 1
    } else if (direction = "prev") {
        currentLayer--
        if (currentLayer < 1)
            currentLayer := totalLayers
    }

    layerIndicator.Text := "Layer " . currentLayer
    layerIndicator.Opt("+Background" . layerBorderColors[currentLayer])
    UpdateGridOutlineColor()  ; Use the new function that considers WASD mode

    gridOutline.Redraw()
    layerIndicator.Redraw()

    for name in buttonNames {
        UpdateButtonAppearance(name)
    }

    UpdateStatus("Layer " . currentLayer)
}

SwitchToLayer(layerNum) {
    global currentLayer, totalLayers, layerIndicator, layerBorderColors

    ; Match original MacroLauncherX44.ahk layer switching logic
    if (layerNum < 1 || layerNum > totalLayers) {
        UpdateStatus("❌ Invalid layer: " . layerNum)
        return
    }

    currentLayer := layerNum

    ; Update layer indicator display
    if (layerIndicator) {
        layerIndicator.Text := "Layer " . currentLayer
        layerIndicator.Opt("+Background" . layerBorderColors[currentLayer])
        layerIndicator.Redraw()
    }

    ; Update grid outline
    if (gridOutline) {
        gridOutline.Opt("+Background" . layerBorderColors[currentLayer])
        gridOutline.Redraw()
    }

    RefreshAllButtonAppearances()
    UpdateStatus("📚 Switched to Layer " . layerNum)
}

SwitchLayerMenu(buttonName) {
    global currentLayer, totalLayers

    ; Create layer menu
    layerMenu := Menu()

    Loop totalLayers {
        layerNum := A_Index
        layerMenu.Add("Layer " . layerNum, (*) => SwitchToLayer(layerNum))
    }

    layerMenu.Show()
}

; ===== ANNOTATION MODE TOGGLE =====
ToggleAnnotationMode() {
    global annotationMode, modeToggleBtn

    annotationMode := (annotationMode = "Wide") ? "Narrow" : "Wide"

    ; Update button appearance
    if (modeToggleBtn) {
        if (annotationMode = "Wide") {
            modeToggleBtn.Text := "🔦 Wide"
            modeToggleBtn.Opt("+Background0x4169E1")
        } else {
            modeToggleBtn.Text := "📱 Narrow"
            modeToggleBtn.Opt("+Background0xFF8C00")
        }
        modeToggleBtn.SetFont(, "cWhite")
        modeToggleBtn.Redraw()
    }

    ; Switch active canvas based on annotation mode
    global userCanvasLeft, userCanvasTop, userCanvasRight, userCanvasBottom
    global wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom
    global narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom

    if (annotationMode = "Narrow") {
        userCanvasLeft := narrowCanvasLeft
        userCanvasTop := narrowCanvasTop
        userCanvasRight := narrowCanvasRight
        userCanvasBottom := narrowCanvasBottom
    } else {
        userCanvasLeft := wideCanvasLeft
        userCanvasTop := wideCanvasTop
        userCanvasRight := wideCanvasRight
        userCanvasBottom := wideCanvasBottom
    }

    ; Save configuration
    SaveConfig()

    ; Refresh button appearances to update JSON annotations for new mode
    RefreshAllButtonAppearances()

    UpdateStatus("🔄 Switched to " . annotationMode . " mode")
}

; ===== BREAK MODE TOGGLE =====
ToggleBreakMode() {
    global breakMode, mainGui

    breakMode := !breakMode

    if (breakMode) {
        ; Apply break mode UI changes
        ApplyBreakModeUI()
        UpdateStatus("☕ Break active")
    } else {
        ; Restore normal UI
        RestoreNormalUI()
        UpdateStatus("✅ Back")
    }

    ; Save state
    SaveConfig()
}

ApplyBreakModeUI() {
    global mainGui, buttonGrid, buttonNames

    ; Disable all buttons
    for buttonName in buttonNames {
        if (buttonGrid.Has(buttonName)) {
            button := buttonGrid[buttonName]
            button.Opt("+Disabled")
            button.Redraw()
        }
    }

    ; Update main GUI appearance
    if (mainGui) {
        mainGui.BackColor := "0x8B0000"  ; Dark red
    }
}

RestoreNormalUI() {
    global mainGui, buttonGrid, buttonNames, darkMode

    ; Re-enable all buttons
    for buttonName in buttonNames {
        if (buttonGrid.Has(buttonName)) {
            button := buttonGrid[buttonName]
            button.Opt("-Disabled")
            button.Redraw()
        }
    }

    ; Restore main GUI appearance
    if (mainGui) {
        mainGui.BackColor := darkMode ? "0x2D2D2D" : "0xF0F0F0"
        mainGui.Redraw()
    }

    ; Refresh button appearances
    RefreshAllButtonAppearances()
}

; ===== WELCOME MESSAGE =====
ShowWelcomeMessage() {
    UpdateStatus("🚀 Ready - WASD hotkeys active (CapsLock+123qweasdzxc) - Live stats tracking active - Currently in " . (annotationMode = "Wide" ? "🔦 WIDE MODE" : "📱 NARROW MODE") . " - F9 to record, F12 for stats")
}

; ===== UTILITY FUNCTIONS =====
GetWASDMappingsText() {
    global wasdHotkeyMap

    if (!wasdHotkeyMap || wasdHotkeyMap.Count = 0) {
        return "No WASD mappings configured"
    }

    text := ""
    for wasdKey, numpadKey in wasdHotkeyMap {
        text .= wasdKey . " → " . numpadKey . "`n"
    }

    return RTrim(text, "`n")
}

GetStatsSummary() {
    global totalActiveTime

    ; Get stats from CSV-based system instead of macroExecutionLog
    stats := ReadStatsFromCSV(false)

    ; Format active time safely - totalActiveTime is milliseconds, not a timestamp
    if (totalActiveTime > 0) {
        totalSeconds := Floor(totalActiveTime / 1000)
        minutes := Floor(totalSeconds / 60)
        seconds := Mod(totalSeconds, 60)
        activeTimeStr := Format("{:02d}:{:02d}", minutes, seconds)
    } else {
        activeTimeStr := "00:00"
    }

    if (stats["total_executions"] = 0) {
        return "No execution data available`n`nTotal Active Time: " . activeTimeStr . "`nBoxes/Hour: 0`nExecutions/Hour: 0"
    }

    totalBoxes := stats["total_boxes"]
    executionCount := stats["total_executions"]
    avgTime := stats["average_execution_time"]
    boxesPerHour := stats["boxes_per_hour"]
    executionsPerHour := stats["executions_per_hour"]

    return "Total Executions: " . executionCount . "`nTotal Boxes: " . totalBoxes . "`nAvg Time: " . avgTime . "ms`n`nActive Time: " . activeTimeStr . "`nBoxes/Hour: " . boxesPerHour . "`nExecutions/Hour: " . executionsPerHour
}
