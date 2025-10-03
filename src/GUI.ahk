; ===== GUI MANAGEMENT MODULE =====
; Contains all GUI creation, management, and interaction functions

; ===== MISSING FUNCTION DEFINITIONS =====
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

; ===== VISUALIZATION FUNCTIONS FOR GUI =====

GetButtonThumbnailSize() {
    global windowWidth, windowHeight, scaleFactor

    ; ✅ Use EXACT same values as CreateButtonGrid for consistency
    margin := 8           ; Changed from 12 to match CreateButtonGrid
    padding := 4
    toolbarHeight := Round(35 * scaleFactor)  ; Changed from 45
    gridTopPadding := 4       ; Changed from 8
    gridBottomPadding := 30   ; Changed from 50

    gridWidth := windowWidth - 2 * margin
    gridHeight := windowHeight - toolbarHeight - gridTopPadding - gridBottomPadding

    buttonWidth := Floor((gridWidth - padding * 2) / 3)
    buttonHeight := Floor((gridHeight - padding * 3) / 4)
    labelHeight := Round(18 * scaleFactor)
    thumbHeight := buttonHeight - labelHeight - 2

    ; Return actual thumbnail dimensions (not minimum) to fill the area properly
    return {width: buttonWidth, height: thumbHeight}
}

; ExtractBoxEvents function is defined in Visualization.ahk - no need to duplicate

TestHBITMAPSupport() {
    ; Test if we can create and use HBITMAP objects
    try {
        bitmap := 0
        result := DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", 32, "Int", 32, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bitmap)
        if (result = 0 && bitmap) {
            DllCall("gdiplus\GdipDisposeImage", "Ptr", bitmap)
            return true
        }
    } catch {
        ; GDI+ not available or access denied
    }
    return false
}

TestFileAccess() {
    ; Test if we can create files in temp directory
    try {
        testFile := A_Temp . "\macro_test_" . A_TickCount . ".tmp"
        FileAppend("test", testFile)
        if (FileExist(testFile)) {
            FileDelete(testFile)
            return true
        }
    } catch {
        ; File access blocked
    }
    return false
}


CreateMemoryStreamVisualization(macroEvents, buttonSize) {
    ; IStream interface visualization (no file system access)
    ; This is a placeholder - would need IStream implementation
    return CreateASCIIVisualization(macroEvents, buttonSize)  ; Fallback to ASCII for now
}

CreateASCIIVisualization(macroEvents, buttonSize) {
    ; ASCII art visualization as final fallback
    boxes := ExtractBoxEvents(macroEvents)
    if (boxes.Length = 0) {
        return ""
    }

    ; Create simple ASCII representation
    ascii := "MACRO`n" . boxes.Length . " boxes"

    ; For now, just return empty string to indicate no visualization
    ; Could be extended to create actual ASCII art
    return ""
}

CreateAltPathVisualization(macroEvents, buttonSize) {
    ; Try user directories instead of temp directory
    altPaths := [
        A_MyDocuments . "\MacroMaster\viz\",
        A_Desktop . "\MacroMaster_tmp\",
        EnvGet("USERPROFILE") . "\MacroMaster\"
    ]

    for path in altPaths {
        try {
            ; Ensure directory exists
            if (!DirExist(path)) {
                DirCreate(path)
            }

            ; Try creating visualization in this path
            testFile := path . "macro_viz_" . A_TickCount . ".png"
            if (CreateVisualizationInPath(macroEvents, buttonSize, testFile)) {
                return testFile
            }
        } catch {
            continue  ; Try next path
        }
    }

    ; All paths failed, fallback to ASCII
    return CreateASCIIVisualization(macroEvents, buttonSize)
}

CreateVisualizationInPath(macroEvents, buttonSize, filePath) {
    ; Create visualization using existing logic but in specified path
    global gdiPlusInitialized, degradationColors

    if (!gdiPlusInitialized) {
        return false
    }

    boxes := ExtractBoxEvents(macroEvents)
    if (boxes.Length = 0) {
        return false
    }

    ; Handle button size format
    if (IsObject(buttonSize)) {
        buttonWidth := buttonSize.width
        buttonHeight := buttonSize.height
    } else {
        buttonWidth := buttonSize
        buttonHeight := buttonSize
    }

    try {
        bitmap := 0
        DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", buttonWidth, "Int", buttonHeight, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bitmap)

        graphics := 0
        DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bitmap, "Ptr*", &graphics)

        ; Black background for letterboxing contrast
        DllCall("gdiplus\GdipGraphicsClear", "Ptr", graphics, "UInt", 0xFF000000)

        ; Draw macro boxes optimized for button dimensions
        recordedMode := macroEvents.HasOwnProp("recordedMode") ? macroEvents.recordedMode : "unknown"
        DrawMacroBoxesOnButton(graphics, buttonWidth, buttonHeight, boxes, recordedMode)

        ; Save to specified path
        success := SaveVisualizationPNG(bitmap, filePath)
        actualPath := success ? filePath : ""

        ; Cleanup
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", bitmap)

        return actualPath != ""

    } catch Error as e {
        return false
    }
}

ApplyYellowOutline(buttonName, hasAutoMode) {
    global buttonGrid, buttonPictures, yellowOutlineButtons

    if (!buttonGrid.Has(buttonName))
        return

    button := buttonGrid[buttonName]
    picture := buttonPictures[buttonName]

    ; Determine which control is currently visible
    activeControl := button.Visible ? button : (picture.Visible ? picture : button)

    if (hasAutoMode) {
        ; Add bright yellow outline for auto mode
        try {
            ; Use a combination of approaches for maximum visibility

            ; 1. Add yellow border to the active control
            activeControl.Opt("+Border +0x800000")  ; Thick border style

            ; 2. For better visibility, add yellow accent indicator
            if (button.Visible) {
                ; Modify the existing text to include yellow indicator
                ; This works with the existing orange background and "🤖 AUTO" text
                currentText := button.Text
                if (!InStr(currentText, "⚡")) {
                    ; Add yellow lightning bolt for auto mode indication
                    button.Text := StrReplace(currentText, "🤖 AUTO", "⚡🤖 AUTO")
                }
            }

            ; 3. Use Windows API to set custom border color if possible
            ; This creates a more prominent yellow outline
            hwnd := activeControl.Hwnd

            ; Apply custom window styling for yellow border effect
            ; Use extended window styles for better border control
            currentExStyle := DllCall("GetWindowLong", "Ptr", hwnd, "Int", -20, "UInt")
            newExStyle := currentExStyle | 0x200  ; WS_EX_CLIENTEDGE for raised edge
            DllCall("SetWindowLong", "Ptr", hwnd, "Int", -20, "UInt", newExStyle)

            ; Force window to redraw with new styling
            DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0001 | 0x0002 | 0x0004 | 0x0020)

            ; Track this button as having yellow outline
            yellowOutlineButtons[buttonName] := true

        } catch Error as e {
            ; If advanced styling fails, fall back to simple text indicator
            if (button.Visible) {
                currentText := button.Text
                if (!InStr(currentText, "⚡")) {
                    button.Text := StrReplace(currentText, "🤖 AUTO", "⚡🤖 AUTO")
                    yellowOutlineButtons[buttonName] := true
                }
            }
        }
    } else {
        ; Remove yellow outline if it was previously applied
        if (yellowOutlineButtons.Has(buttonName) && yellowOutlineButtons[buttonName]) {
            try {
                ; Remove border and styling
                activeControl.Opt("-Border")

                ; Remove extended styling
                hwnd := activeControl.Hwnd
                currentExStyle := DllCall("GetWindowLong", "Ptr", hwnd, "Int", -20, "UInt")
                newExStyle := currentExStyle & ~0x200  ; Remove WS_EX_CLIENTEDGE
                DllCall("SetWindowLong", "Ptr", hwnd, "Int", -20, "UInt", newExStyle)

                ; Remove yellow accent from text if present
                if (button.Visible) {
                    currentText := button.Text
                    button.Text := StrReplace(currentText, "⚡🤖 AUTO", "🤖 AUTO")
                }

                ; Force redraw
                DllCall("SetWindowPos", "Ptr", hwnd, "Ptr", 0, "Int", 0, "Int", 0, "Int", 0, "Int", 0, "UInt", 0x0001 | 0x0002 | 0x0004 | 0x0020)

                ; Remove from tracking
                yellowOutlineButtons.Delete(buttonName)

            } catch Error as e {
                ; Ignore removal errors, but still clean up text
                if (button.Visible) {
                    currentText := button.Text
                    button.Text := StrReplace(currentText, "⚡🤖 AUTO", "🤖 AUTO")
                }
                yellowOutlineButtons.Delete(buttonName)
            }
        }
    }
}

; ===== GUI INITIALIZATION =====
InitializeGui() {
    global mainGui, statusBar, darkMode, windowWidth, windowHeight, scaleFactor, minWindowWidth, minWindowHeight

    mainGui := Gui("+Resize +MinSize" . minWindowWidth . "x" . minWindowHeight, "Data Labeling Assistant")
    mainGui.BackColor := darkMode ? "0x2D2D2D" : "0xF0F0F0"
    mainGui.SetFont("s" . Round(10 * scaleFactor), darkMode ? "c0xFFFFFF" : "c0x000000")

    CreateToolbar()
    CreateGridOutline()
    CreateButtonGrid()
    CreateStatusBar()

    mainGui.OnEvent("Size", GuiResize)
    mainGui.OnEvent("Close", (*) => SafeExit())

    ; Don't show GUI yet - will be shown after config is loaded
}

; Show GUI after everything is initialized
ShowGui() {
    global mainGui, windowWidth, windowHeight
    mainGui.Show("w" . windowWidth . " h" . windowHeight)
}

CreateToolbar() {
    global mainGui, layerIndicator, darkMode, currentLayer, layerNames, modeToggleBtn, windowWidth, layerBorderColors

    toolbarHeight := 35  ; Match original fixed height
    btnHeight := 30      ; Match original fixed height
    btnY := (toolbarHeight - btnHeight) / 2

    ; Background
    tbBg := mainGui.Add("Text", "x0 y0 w" . windowWidth . " h" . toolbarHeight)
    tbBg.BackColor := darkMode ? "0x1E1E1E" : "0xE8E8E8"
    mainGui.tbBg := tbBg

    ; Left section - match original MacroLauncherX44.ahk layout
    spacing := 8
    x := spacing

    ; Record button
    btnRecord := mainGui.Add("Button", "x" . x . " y" . btnY . " w75 h" . btnHeight, "🎥 Record")
    btnRecord.OnEvent("Click", (*) => F9_RecordingOnly())  ; Direct call to F9 handler
    btnRecord.SetFont("s9 bold")
    mainGui.btnRecord := btnRecord
    x += 80

    ; Break mode toggle - positioned right after record button
    btnBreakMode := mainGui.Add("Button", "x" . x . " y" . btnY . " w70 h" . btnHeight, "☕ Break")
    btnBreakMode.OnEvent("Click", (*) => ToggleBreakMode())
    btnBreakMode.SetFont("s8 bold")
    btnBreakMode.Opt("+Background0x4CAF50")
    mainGui.btnBreakMode := btnBreakMode
    x += 75

    ; Clear button - positioned right after break mode button
    btnClear := mainGui.Add("Button", "x" . x . " y" . btnY . " w55 h" . btnHeight, "🗑️ Clear")
    btnClear.OnEvent("Click", (*) => ShowClearDialog())
    btnClear.SetFont("s7 bold")
    btnClear.Opt("+Background0xFF6347")
    x += 60

    ; Mode toggle - positioned right after clear button
    modeToggleBtn := mainGui.Add("Button", "x" . x . " y" . btnY . " w" . Round(90 * scaleFactor) . " h" . btnHeight, (annotationMode = "Wide" ? "🔦 WIDE MODE" : "📱 NARROW MODE"))
    modeToggleBtn.OnEvent("Click", (*) => ToggleAnnotationMode())
    modeToggleBtn.SetFont("s9 bold")
    modeToggleBtn.Opt("+Background" . (annotationMode = "Wide" ? "0x4169E1" : "0xFF8C00"))
    modeToggleBtn.SetFont(, "cWhite")

    ; Store reference in main GUI for global access
    mainGui.modeToggleBtn := modeToggleBtn
    x += Round(95 * scaleFactor)

    ; Center section - Layer navigation (match original positioning)
    centerStart := Round(windowWidth * 0.35)
    layerWidth := Round(windowWidth * 0.3)

    btnPrevLayer := mainGui.Add("Button", "x" . centerStart . " y" . btnY . " w30 h" . btnHeight, "◀")
    btnPrevLayer.OnEvent("Click", (*) => SwitchLayer("prev"))
    btnPrevLayer.SetFont("s9 bold")
    mainGui.btnPrevLayer := btnPrevLayer

    layerIndicator := mainGui.Add("Text", "x" . (centerStart + 35) . " y" . (btnY + 2) . " w" . (layerWidth - 70) . " h" . (btnHeight - 4) . " Center +Border", "Layer " . currentLayer)
    layerIndicator.Opt("c" . (darkMode ? "White" : "Black"))
    layerIndicator.SetFont("s9 bold")
    layerIndicator.Opt("+Background" . layerBorderColors[currentLayer])

    btnNextLayer := mainGui.Add("Button", "x" . (centerStart + layerWidth - 30) . " y" . btnY . " w30 h" . btnHeight, "▶")
    btnNextLayer.OnEvent("Click", (*) => SwitchLayer("next"))
    btnNextLayer.SetFont("s9 bold")
    mainGui.btnNextLayer := btnNextLayer

    ; Right section - match original positioning
    rightSection := Round(windowWidth * 0.7)
    rightWidth := windowWidth - rightSection - spacing
    btnWidth := Round((rightWidth - 20) / 3)

    btnStats := mainGui.Add("Button", "x" . rightSection . " y" . btnY . " w" . btnWidth . " h" . btnHeight, "📊 Stats")
    btnStats.OnEvent("Click", (*) => ShowStatsMenu())
    btnStats.SetFont("s8 bold")
    mainGui.btnStats := btnStats

    btnSettings := mainGui.Add("Button", "x" . (rightSection + btnWidth + 5) . " y" . btnY . " w" . btnWidth . " h" . btnHeight, "⚙️ Config")
    btnSettings.OnEvent("Click", (*) => ShowSettings())
    btnSettings.SetFont("s8 bold")
    mainGui.btnSettings := btnSettings

    btnEmergency := mainGui.Add("Button", "x" . (rightSection + (btnWidth * 2) + 10) . " y" . btnY . " w" . btnWidth . " h" . btnHeight, "🚨 " . hotkeyEmergency)
    btnEmergency.OnEvent("Click", (*) => EmergencyStop())
    btnEmergency.SetFont("s8 bold")
    btnEmergency.Opt("+Background0xDC143C")
    mainGui.btnEmergency := btnEmergency
}

CreateGridOutline() {
    global mainGui, gridOutline, currentLayer, layerBorderColors, scaleFactor, windowWidth, windowHeight

    ; Create grid outline without border stroke - clean design
    gridOutline := mainGui.Add("Text", "x" . Round(8) . " y" . Round(43 * scaleFactor) . " w" . Round(384 * scaleFactor) . " h" . Round(288 * scaleFactor) . " +Background" . layerBorderColors[currentLayer])
    mainGui.gridOutline := gridOutline
}

CreateButtonGrid() {
    global mainGui, buttonGrid, buttonLabels, buttonPictures, buttonNames, darkMode, windowWidth, windowHeight, gridOutline, scaleFactor

    ; Match original MacroLauncherX44.ahk button grid layout exactly
    margin := 8
    padding := 4
    toolbarHeight := Round(35 * scaleFactor)
    gridTopPadding := 4
    gridBottomPadding := 30

    gridWidth := windowWidth - (margin * 2)
    gridHeight := windowHeight - toolbarHeight - gridTopPadding - gridBottomPadding - (margin * 2)

    buttonWidth := Floor((gridWidth - padding * 2) / 3)
    buttonHeight := Floor((gridHeight - padding * 3) / 4)
    labelHeight := Round(18 * scaleFactor)
    thumbHeight := buttonHeight - labelHeight - 2

    outlineThickness := 2
    gridOutline.Move(margin - outlineThickness, toolbarHeight + gridTopPadding + margin - outlineThickness,
                    gridWidth + (outlineThickness * 2), gridHeight + (outlineThickness * 2))

    ; Create 4x3 grid of buttons with original styling
    for row in [0, 1, 2, 3] {
        for col in [0, 1, 2] {
            index := row * 3 + col + 1
            if (index > 12)
                continue

            buttonName := buttonNames[index]
            x := margin + col * (buttonWidth + padding)
            y := toolbarHeight + gridTopPadding + margin + row * (buttonHeight + padding)

            ; Create button without stroke/border to match original clean design
            button := mainGui.Add("Text", "x" . Floor(x) . " y" . Floor(y) . " w" . Floor(buttonWidth) . " h" . Floor(thumbHeight) . " 0x201", "")
            if (darkMode) {
                button.Opt("+Background0x2A2A2A")  ; Match dark background exactly
                button.SetFont("s" . Round(9 * scaleFactor), "cWhite")
            } else {
                button.Opt("+Background0xF8F8F8")  ; Match light background exactly
                button.SetFont("s" . Round(9 * scaleFactor), "cBlack")
            }

            ; Create picture control for thumbnails
            picture := mainGui.Add("Picture", "x" . Floor(x) . " y" . Floor(y) . " w" . Floor(buttonWidth) . " h" . Floor(thumbHeight) . " Hidden")

            ; Create label positioned under button
            labelY := y + thumbHeight + 1
            label := mainGui.Add("Text", "x" . Floor(x) . " y" . Floor(labelY) . " w" . Floor(buttonWidth) . " h" . Floor(labelHeight) . " Center BackgroundTrans", buttonName)
            label.Opt("c" . (darkMode ? "White" : "Black"))
            label.SetFont("s" . Round(8 * scaleFactor) . " bold")

            ; Store references
            buttonGrid[buttonName] := button
            buttonLabels[buttonName] := label
            buttonPictures[buttonName] := picture

            ; Setup event handlers
            button.OnEvent("Click", HandleButtonClick.Bind(buttonName))
            button.OnEvent("ContextMenu", HandleContextMenu.Bind(buttonName))
            picture.OnEvent("Click", HandleButtonClick.Bind(buttonName))
            picture.OnEvent("ContextMenu", HandleContextMenu.Bind(buttonName))

            ; Initialize button appearance
            UpdateButtonAppearance(buttonName)
        }
    }
}

CreateStatusBar() {
    global mainGui, statusBar, darkMode, windowWidth, windowHeight

    statusY := windowHeight - 25
    statusBar := mainGui.Add("Text", "x8 y" . statusY . " w" . (windowWidth - 16) . " h20", "✅ Ready - F9 to record")
    statusBar.Opt("c" . (darkMode ? "White" : "Black"))
    statusBar.SetFont("s9")
}

; ===== BUTTON APPEARANCE =====
RefreshAllButtonAppearances() {
    global buttonNames
    for buttonName in buttonNames {
        UpdateButtonAppearance(buttonName)
    }
}

UpdateButtonAppearance(buttonName) {
    global buttonGrid, buttonPictures, buttonThumbnails, macroEvents, buttonCustomLabels, darkMode, currentLayer, layerBorderColors, degradationTypes, degradationColors, buttonAutoSettings, yellowOutlineButtons, buttonLabels, wasdLabelsEnabled, hbitmapCache

    ; Early return for invalid button names
    if (!buttonGrid.Has(buttonName)) {
        return
    }

    button := buttonGrid[buttonName]
    picture := buttonPictures[buttonName]
    layerMacroName := "L" . currentLayer . "_" . buttonName

    ; Check macro existence
    hasMacro := macroEvents.Has(layerMacroName) && macroEvents[layerMacroName].Length > 0

    ; Early return for empty buttons
    if (!hasMacro) {
        buttonLabels[buttonName].Text := buttonCustomLabels.Has(buttonName) ? buttonCustomLabels[buttonName] : buttonName
        picture.Visible := false
        button.Visible := true
        button.Opt("+Background" . (darkMode ? "0x2A2A2A" : "0xF8F8F8"))
        button.SetFont("s8", "cGray")
        button.Text := ""  ; Remove "L" + layer number display
        return
    }

    hasAutoMode := buttonAutoSettings.Has(layerMacroName) && buttonAutoSettings[layerMacroName].enabled
    buttonLabels[buttonName].Text := buttonCustomLabels.Has(buttonName) ? buttonCustomLabels[buttonName] : buttonName

    ; Check for thumbnail
    thumbnailValue := buttonThumbnails.Has(layerMacroName) ? buttonThumbnails[layerMacroName] : ""
    hasThumbnail := thumbnailValue != "" && (Type(thumbnailValue) = "Integer" || FileExist(thumbnailValue))

    ; Check for JSON annotation
    isJsonAnnotation := false
    jsonInfo := ""
    jsonColor := "0xFFD700"

    if (hasMacro && macroEvents[layerMacroName].Length = 1 && macroEvents[layerMacroName][1].type = "jsonAnnotation") {
        isJsonAnnotation := true
        jsonEvent := macroEvents[layerMacroName][1]
        typeName := StrTitle(degradationTypes[jsonEvent.categoryId])
        jsonInfo := annotationMode . "`n" . typeName . " " . StrUpper(jsonEvent.severity)

        if (degradationColors.Has(jsonEvent.categoryId)) {
            jsonColor := Format("0x{:X}", degradationColors[jsonEvent.categoryId])
        }
    }

    ; Check for visualizable macro
    hasVisualizableMacro := hasMacro && !isJsonAnnotation && macroEvents[layerMacroName].Length > 1

    if (hasVisualizableMacro) {
        ; Generate live macro visualization
        buttonSize := GetButtonThumbnailSize()
        boxes := ExtractBoxEvents(macroEvents[layerMacroName])

        if (boxes.Length > 0) {

            ; Use PNG visualization (matches working MacroLauncherX45.ahk)
            pngFile := CreateMacroVisualization(macroEvents[layerMacroName], buttonSize)

            if (pngFile && FileExist(pngFile)) {
                ; PNG succeeded - use picture control
                button.Visible := false
                picture.Visible := true
                picture.Value := pngFile
            } else {
                ; PNG failed - use text display
                button.Visible := true
                picture.Visible := false
                button.Opt("+Background" . layerBorderColors[currentLayer])
                button.SetFont("s7 bold", "cWhite")
                button.Text := "MACRO`n" . boxes.Length . " boxes"
            }
        }
        ; If no boxes found, button stays as text display
    } else if (hasThumbnail && !isJsonAnnotation) {
        ; Static thumbnail
        button.Visible := false
        picture.Visible := true
        picture.Text := ""
        try {
            thumbnailValue := buttonThumbnails[layerMacroName]
            if (Type(thumbnailValue) = "Integer" && thumbnailValue > 0 && thumbnailValue != 1594174808 && thumbnailValue != 520429950) {
                ; HBITMAP handle - assign directly (validate it's not the invalid handle)
                picture.Value := "HBITMAP:" . thumbnailValue
            } else {
                ; File path - use existing method
                picture.Value := thumbnailValue
            }
        } catch {
            ; Thumbnail loading failed - no fallback available
        }
    } else {
        ; Text display
        picture.Visible := false
        button.Visible := true
        button.Opt("-Background")

        if (isJsonAnnotation) {
            button.Opt("+Background" . jsonColor)
            button.SetFont("s7 bold", "cBlack")
            button.Text := jsonInfo
        } else if (hasMacro) {
            events := macroEvents[layerMacroName]
            if (hasAutoMode) {
                ; Auto mode enabled - bright yellow background
                button.Opt("+Background0xFFFF00")
                button.SetFont("s7 bold", "cBlack")
                button.Text := "🤖 AUTO`n" . events.Length . " events"
            } else {
                ; Regular macro - layer color
                button.Opt("+Background" . layerBorderColors[currentLayer])
                button.SetFont("s7 bold", "cWhite")
                button.Text := "MACRO`n" . events.Length . " events"
            }
        } else {
            button.Opt("+Background" . (darkMode ? "0x2A2A2A" : "0xF8F8F8"))
            button.SetFont("s8", "cGray")

            if (wasdLabelsEnabled) {
                button.Text := ""
            } else {
                button.Text := "L" . currentLayer
            }
        }
    }

    ; Label control - always visible with button name/custom label
    buttonLabels[buttonName].Visible := true
    buttonLabels[buttonName].Text := buttonCustomLabels.Has(buttonName) ? buttonCustomLabels[buttonName] : buttonName

    ; Apply yellow outline for auto mode buttons
    ApplyYellowOutline(buttonName, hasAutoMode)
}

; ===== VISUALIZATION SYSTEM FUNCTIONS =====

; DrawMacroBoxesOnButton function is defined in Visualization.ahk - no need to duplicate

; InitializeVisualizationSystem and DetectCanvasType functions are defined in Visualization.ahk - no need to duplicate

; ===== STATUS MANAGEMENT =====
UpdateStatus(text) {
    global statusBar
    if (statusBar) {
        statusBar.Text := text
        statusBar.Redraw()
    }

}


; ===== BUTTON EVENT HANDLERS =====
HandleButtonClick(buttonName, *) {
    ExecuteMacro(buttonName)
}

HandleContextMenu(buttonName, *) {
    ShowContextMenuCleaned(buttonName)
}


; ===== GUI RESIZE HANDLER =====
GuiResize(GuiObj, MinMax, Width, Height) {
    global windowWidth, windowHeight, scaleFactor, mainGui, statusBar, gridOutline, buttonGrid, buttonLabels, buttonPictures

    if (MinMax = -1) {  ; Window is being minimized
        return
    }

    ; Add bounds checking
    if (Width < 800 || Height < 600) {
        return  ; Don't resize below minimum
    }

    ; Update global dimensions
    windowWidth := Width
    windowHeight := Height

    ; Recalculate scale factor based on new size
    scaleFactor := Min(Width / 1200, Height / 800)

    ; Update status bar position and size
    if (statusBar) {
        statusBarHeight := Round(25 * scaleFactor)
        statusBarY := Height - statusBarHeight - Round(10 * scaleFactor)
        statusBar.Move(, statusBarY, Width - Round(20 * scaleFactor))
    }

    ; Move toolbar background
    if (mainGui.HasProp("tbBg") && mainGui.tbBg) {
        mainGui.tbBg.Move(0, 0, Width, Round(45 * scaleFactor))
    }

    ; Move and resize button grid with enhanced layout
    MoveButtonGridFast()

    ; Debounce appearance updates to reduce flickering
    static resizeTimer := 0
    if (resizeTimer) {
        SetTimer(resizeTimer, 0)  ; Cancel previous timer
    }
    resizeTimer := () => UpdateAllButtonAppearances()
    SetTimer(resizeTimer, -150)  ; Update appearances 150ms after resize stops
}

; FAST FUNCTION - Move controls without appearance updates (no flicker)
MoveButtonGridFast() {
    global buttonGrid, buttonLabels, buttonPictures, buttonNames, windowWidth, windowHeight, scaleFactor, gridOutline

    ; Calculate new positions (same math as CreateButtonGrid)
    margin := 8
    padding := 4
    toolbarHeight := Round(35 * scaleFactor)
    gridTopPadding := 4
    gridBottomPadding := 30

    gridWidth := windowWidth - (margin * 2)
    gridHeight := windowHeight - toolbarHeight - gridTopPadding - gridBottomPadding - (margin * 2)

    ; Add safety bounds
    if (gridWidth < 300 || gridHeight < 200) {
        return  ; Don't resize if too small
    }

    buttonWidth := Floor((gridWidth - padding * 2) / 3)
    buttonHeight := Floor((gridHeight - padding * 3) / 4)
    labelHeight := Round(18 * scaleFactor)
    thumbHeight := buttonHeight - labelHeight - 2

    ; Move grid outline
    outlineThickness := 2
    gridOutline.Move(margin - outlineThickness, toolbarHeight + gridTopPadding + margin - outlineThickness,
                    gridWidth + (outlineThickness * 2), gridHeight + (outlineThickness * 2))

    ; Move existing button controls (fast - no appearance updates)
    for row in [0, 1, 2, 3] {
        for col in [0, 1, 2] {
            index := row * 3 + col + 1
            if (index > 12)
                continue

            buttonName := buttonNames[index]
            x := margin + col * (buttonWidth + padding)
            y := toolbarHeight + gridTopPadding + margin + row * (buttonHeight + padding)

            ; Move existing controls if they exist (positions only)
            if (buttonGrid.Has(buttonName) && buttonGrid[buttonName]) {
                buttonGrid[buttonName].Move(Floor(x), Floor(y), Floor(buttonWidth), Floor(thumbHeight))
            }
            if (buttonPictures.Has(buttonName) && buttonPictures[buttonName]) {
                buttonPictures[buttonName].Move(Floor(x), Floor(y), Floor(buttonWidth), Floor(thumbHeight))
            }
            if (buttonLabels.Has(buttonName) && buttonLabels[buttonName]) {
                buttonLabels[buttonName].Move(Floor(x), Floor(y + thumbHeight + 1), Floor(buttonWidth), Floor(labelHeight))
            }
        }
    }
}

; BATCH UPDATE - Refresh all button appearances (called after resize stops)
UpdateAllButtonAppearances() {
    global buttonNames

    for buttonName in buttonNames {
        UpdateButtonAppearance(buttonName)
    }
}

; ===== WELCOME MESSAGE =====
ShowWelcomeMessage() {
    UpdateStatus("🚀 Ready - WASD hotkeys active (CapsLock+123qweasdzxc) - Real-time dashboard enabled - Currently in " . (annotationMode = "Wide" ? "🔦 WIDE MODE" : "📱 NARROW MODE") . " - F9 to record, F12 for dashboard")
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

; ===== SWITCH TO LAYER =====
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

; ===== LAYER MENU =====
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

; ===== THUMBNAIL OPERATIONS =====
AddThumbnail(buttonName) {
    global currentLayer, buttonThumbnails

    ; File selection dialog
    selectedFile := FileSelect("3", , "Select Thumbnail Image", "Images (*.png; *.jpg; *.jpeg; *.bmp; *.gif)")

    if (selectedFile != "") {
        layerMacroName := "L" . currentLayer . "_" . buttonName
        buttonThumbnails[layerMacroName] := selectedFile
        UpdateButtonAppearance(buttonName)
        SaveMacroState()
        UpdateStatus("🖼️ Thumbnail added")
    }
}

RemoveThumbnail(buttonName) {
    global currentLayer, buttonThumbnails

    layerMacroName := "L" . currentLayer . "_" . buttonName

    if (buttonThumbnails.Has(layerMacroName)) {
        buttonThumbnails.Delete(layerMacroName)
        UpdateButtonAppearance(buttonName)
        SaveMacroState()
        UpdateStatus("🗑️ Thumbnail removed")
    }
}

; ===== BUTTON FLASHING =====
FlashButton(buttonName, enable) {
    global buttonGrid

    if (!buttonGrid.Has(buttonName)) {
        return
    }

    button := buttonGrid[buttonName]

    if (enable) {
        ; Start flashing - change to a bright color
        button.Opt("+Background0x00FF00")  ; Bright green for execution
        button.Redraw()
    } else {
        ; Stop flashing - restore normal appearance
        UpdateButtonAppearance(buttonName)
    }
}

; ===== GRID OUTLINE COLOR UPDATE =====
UpdateGridOutlineColor() {
    global gridOutline, wasdLabelsEnabled, currentLayer, layerBorderColors

    if (gridOutline) {
        ; Update grid outline color based on WASD mode and current layer
        if (wasdLabelsEnabled) {
            ; WASD mode - use a different color scheme
            gridOutline.Opt("+Background0xFF6B35")  ; Orange-red for WASD mode
        } else {
            ; Normal mode - use layer color
            gridOutline.Opt("+Background" . layerBorderColors[currentLayer])
        }
        gridOutline.Redraw()
    }
}

; ===== EMERGENCY BUTTON TEXT UPDATE =====
UpdateEmergencyButtonText() {
    global mainGui, hotkeyEmergency

    if (mainGui.HasProp("btnEmergency") && mainGui.btnEmergency) {
        mainGui.btnEmergency.Text := "🚨 " . hotkeyEmergency
    }
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

; ===== AUTO EXECUTION SETTINGS =====
ShowAutoSettings(buttonName) {
    global currentLayer, buttonAutoSettings

    layerKey := "L" . currentLayer . "_" . buttonName

    ; Create auto settings dialog
    autoGui := Gui("+Owner" . mainGui.Hwnd, "Auto Execution Settings - " . buttonName)
    autoGui.BackColor := darkMode ? "0x2D2D2D" : "0xF0F0F0"
    autoGui.SetFont("s10", darkMode ? "c0xFFFFFF" : "c0x000000")

    autoGui.Add("Text", "x20 y20", "Button: " . buttonName . " (Layer " . currentLayer . ")")

    ; Enable/disable checkbox
    chkEnabled := autoGui.Add("CheckBox", "x20 y50", "Enable Auto Execution")
    chkEnabled.Value := buttonAutoSettings.Has(layerKey) ? buttonAutoSettings[layerKey].enabled : false

    ; Interval setting
    autoGui.Add("Text", "x20 y80", "Interval (seconds):")
    editInterval := autoGui.Add("Edit", "x150 y75 w100", buttonAutoSettings.Has(layerKey) ? buttonAutoSettings[layerKey].interval / 1000 : 2)

    ; Max count setting
    autoGui.Add("Text", "x20 y110", "Max Executions (0 = unlimited):")
    editMaxCount := autoGui.Add("Edit", "x200 y105 w100", buttonAutoSettings.Has(layerKey) ? buttonAutoSettings[layerKey].maxCount : 0)

    ; Buttons
    btnApply := autoGui.Add("Button", "x20 y150 w80 h30", "Apply")
    btnApply.OnEvent("Click", (*) => ApplyAutoSettings(buttonName, chkEnabled, editInterval, editMaxCount, autoGui))

    btnCancel := autoGui.Add("Button", "x110 y150 w80 h30", "Cancel")
    btnCancel.OnEvent("Click", (*) => autoGui.Destroy())

    autoGui.Show("w300 h200")
}

ApplyAutoSettings(buttonName, chkEnabled, editInterval, editMaxCount, autoGui) {
    global currentLayer, buttonAutoSettings

    layerKey := "L" . currentLayer . "_" . buttonName

    ; Validate inputs
    interval := Integer(editInterval.Text)
    maxCount := Integer(editMaxCount.Text)

    if (interval < 1 || interval > 300) {
        MsgBox("Interval must be between 1 and 300 seconds.", "Invalid Interval", "Icon!")
        return
    }

    if (maxCount < 0) {
        MsgBox("Max executions cannot be negative.", "Invalid Max Count", "Icon!")
        return
    }

    ; Update settings
    if (!buttonAutoSettings.Has(layerKey)) {
        buttonAutoSettings[layerKey] := Map()
    }

    buttonAutoSettings[layerKey].enabled := chkEnabled.Value
    buttonAutoSettings[layerKey].interval := interval * 1000  ; Convert to milliseconds
    buttonAutoSettings[layerKey].maxCount := maxCount

    ; Apply changes
    if (chkEnabled.Value) {
        EnableAutoMode(buttonName)
    } else {
        DisableAutoMode(buttonName)
    }

    ; Save config
    SaveConfig()

    autoGui.Destroy()
    UpdateStatus("🤖 Auto settings updated for " . buttonName)
}

EnableAutoMode(buttonName) {
    global buttonAutoSettings, currentLayer

    layerKey := "L" . currentLayer . "_" . buttonName

    if (buttonAutoSettings.Has(layerKey) && buttonAutoSettings[layerKey].enabled) {
        UpdateButtonAppearance(buttonName)
    }
}

DisableAutoMode(buttonName) {
    global buttonAutoSettings, currentLayer

    layerKey := "L" . currentLayer . "_" . buttonName

    if (buttonAutoSettings.Has(layerKey)) {
        buttonAutoSettings[layerKey].enabled := false
        UpdateButtonAppearance(buttonName)
    }
}

; ===== WASD FUNCTIONS =====
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

; ===== STATS FUNCTIONS =====
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