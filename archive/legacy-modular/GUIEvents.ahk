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
    global macroEvents, buttonThumbnails, degradationTypes, severityLevels

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
    if (macroEvents.Has(buttonName) && macroEvents[buttonName].Length > 0) {
        contextMenu.Add("🗑️ Clear Macro", (*) => ClearMacro(buttonName))
        contextMenu.Add()  ; Separator
    }

    ; Visual customization section
    if (buttonThumbnails.Has(buttonName)) {
        contextMenu.Add("🖼️ Remove Thumbnail", (*) => RemoveThumbnail(buttonName))
    } else {
        contextMenu.Add("🖼️ Add Thumbnail", (*) => AddThumbnail(buttonName))
    }

    ; Show menu
    contextMenu.Show()
}

; ===== JSON ANNOTATION ASSIGNMENT =====
AssignJsonAnnotation(buttonName, presetName, *) {
    global macroEvents, jsonAnnotations, degradationTypes, annotationMode

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
            macroEvents[buttonName] := [{
                type: "jsonAnnotation",
                annotation: jsonAnnotations[fullPresetName],
                mode: currentMode,
                categoryId: categoryId,
                severity: severity
            }]
            ; CRITICAL FIX: Set recordedMode for JSON annotations too
            macroEvents[buttonName].recordedMode := currentMode
            UpdateButtonAppearance(buttonName)
            SaveConfig()
            UpdateStatus("🏷️ Assigned " . presetName . " to " . buttonName)
        }
    } else {
        UpdateStatus("❌ Annotation not found")
    }
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
        ; No need for Redraw() - button updates automatically
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
            ; No need to call Redraw() - buttons update automatically
        }
    }

    ; Update main GUI appearance
    if (mainGui) {
        mainGui.BackColor := "0x8B0000"  ; Dark red
        ; GUI redraws automatically when BackColor changes
    }
}

RestoreNormalUI() {
    global mainGui, buttonGrid, buttonNames, darkMode

    ; Re-enable all buttons
    for buttonName in buttonNames {
        if (buttonGrid.Has(buttonName)) {
            button := buttonGrid[buttonName]
            button.Opt("-Disabled")
            ; No need to call Redraw() - buttons update automatically
        }
    }

    ; Restore main GUI appearance
    if (mainGui) {
        mainGui.BackColor := darkMode ? "0x2D2D2D" : "0xF0F0F0"
        ; GUI redraws automatically when BackColor changes
    }

    ; Refresh button appearances
    RefreshAllButtonAppearances()
}

; ===== WELCOME MESSAGE =====
ShowWelcomeMessage() {
    UpdateStatus("🚀 Ready - " . (annotationMode = "Wide" ? "WIDE" : "NARROW") . " mode")
}

; ===== UTILITY FUNCTIONS =====
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
