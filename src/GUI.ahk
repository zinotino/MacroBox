; ===== GUI MANAGEMENT MODULE =====
; Contains all GUI creation, management, and interaction functions

; ===== MISSING FUNCTION DEFINITIONS =====
AssignJsonAnnotation(buttonName, presetName, *) {
    global currentLayer, macroEvents, jsonAnnotations, degradationTypes, annotationMode

    layerMacroName := "L" . currentLayer . "_" . buttonName

    ; Use current annotation mode
    currentMode := annotationMode
    fullPresetName := presetName . (currentMode = "Narrow" ? " Narrow" : "")

    ; Debug logging
    UpdateStatus("🎨 Assigning " . fullPresetName . " in " . currentMode . " mode")

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
            UpdateStatus("🏷️ Assigned " . currentMode . " " . presetName . " to " . buttonName)
        } else {
            UpdateStatus("❌ Could not find category ID for " . typeName)
        }
    } else {
        UpdateStatus("❌ Could not find JSON annotation for " . fullPresetName)

        ; Debug: Show what's available
        UpdateStatus("🔍 Available modes: Wide=" . jsonAnnotations.Has(presetName) . ", Narrow=" . jsonAnnotations.Has(presetName . " Narrow"))
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
        status := buttonAutoSettings[buttonKey].enabled ? "✅ Auto mode enabled for " : "❌ Auto mode disabled for "
        UpdateStatus(status . buttonName)
    } else {
        ; No settings exist - create with global defaults and enable
        buttonAutoSettings[buttonKey] := {
            enabled: true,
            interval: autoExecutionInterval,  ; Use global default
            maxCount: 0                        ; infinite default
        }
        UpdateStatus("✅ Auto mode enabled for " . buttonName . " (default settings)")
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

    ; Calculate based on CreateButtonGrid logic
    margin := 12
    padding := 4
    toolbarHeight := Round(45 * scaleFactor)
    gridTopPadding := 8
    gridBottomPadding := 50

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

CreateHBITMAPVisualization(macroEvents, buttonSize) {
    ; Memory-only visualization using HBITMAP with caching for performance
    global gdiPlusInitialized, degradationColors, hbitmapCache

    ; Early validation
    if (!gdiPlusInitialized) {
        ; Attempt to initialize if not already done
        InitializeVisualizationSystem()
        if (!gdiPlusInitialized) {
            return 0
        }
    }

    if (!macroEvents || macroEvents.Length = 0) {
        return 0
    }

    ; PERFORMANCE: Generate cache key based on macro events content AND recorded mode
    cacheKey := ""
    for event in macroEvents {
        if (event.type = "boundingBox") {
            cacheKey .= event.left . "," . event.top . "," . event.right . "," . event.bottom . "|"
        }
    }
    ; Include recorded mode in cache key so narrow/wide are cached separately
    recordedMode := macroEvents.HasOwnProp("recordedMode") ? macroEvents.recordedMode : "unknown"
    cacheKey .= buttonSize.width . "x" . buttonSize.height . "_" . recordedMode

    ; Check cache first
    if (hbitmapCache.Has(cacheKey)) {
        return hbitmapCache[cacheKey]
    }

    ; Extract box drawing events
    boxes := ExtractBoxEvents(macroEvents)
    if (boxes.Length = 0) {
        return 0
    }

    ; Handle button size format
    if (IsObject(buttonSize)) {
        buttonWidth := buttonSize.width
        buttonHeight := buttonSize.height
    } else {
        buttonWidth := buttonSize
        buttonHeight := buttonSize
    }

    ; Create HBITMAP using GDI+
    bitmap := 0
    graphics := 0
    hbitmap := 0

    try {
        ; Validate dimensions
        if (buttonWidth <= 0 || buttonHeight <= 0 || buttonWidth > 4096 || buttonHeight > 4096) {
            return 0
        }

        ; Create GDI+ bitmap
        result := DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", buttonWidth, "Int", buttonHeight, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &bitmap)
        if (result != 0 || !bitmap) {
            return 0
        }

        ; Create graphics context from bitmap
        result := DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", bitmap, "Ptr*", &graphics)
        if (result != 0 || !graphics) {
            DllCall("gdiplus\GdipDisposeImage", "Ptr", bitmap)
            return 0
        }

        ; Fill with black background
        blackBrush := 0
        DllCall("gdiplus\GdipCreateSolidFill", "UInt", 0xFF000000, "Ptr*", &blackBrush)
        DllCall("gdiplus\GdipFillRectangle", "Ptr", graphics, "Ptr", blackBrush, "Float", 0, "Float", 0, "Float", buttonWidth, "Float", buttonHeight)
        DllCall("gdiplus\GdipDeleteBrush", "Ptr", blackBrush)

        ; Draw boxes using same logic as PNG version (pass macroEvents for mode detection)
        DrawMacroBoxesOnButton(graphics, buttonWidth, buttonHeight, boxes, macroEvents)

        ; Convert GDI+ bitmap to HBITMAP
        result := DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", bitmap, "Ptr*", &hbitmap, "UInt", 0x00000000)

        ; Clean up GDI+ objects
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", bitmap)

        if (result = 0 && hbitmap) {
            ; PERFORMANCE: Cache the HBITMAP for future use
            hbitmapCache[cacheKey] := hbitmap
            return hbitmap
        } else {
            return 0
        }

    } catch Error as e {
        ; Clean up on error
        if (graphics) {
            DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
        }
        if (bitmap) {
            DllCall("gdiplus\GdipDisposeImage", "Ptr", bitmap)
        }
        return 0
    }
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

        ; Draw macro boxes (pass macroEvents for mode detection)
        DrawMacroBoxesOnButton(graphics, buttonWidth, buttonHeight, boxes, macroEvents)

        ; Save to specified path
        result := SaveVisualizationPNG(bitmap, filePath)

        ; Cleanup
        DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", bitmap)

        return result && FileExist(filePath)

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
    btnStats.OnEvent("Click", (*) => ShowPythonStats())
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
    if (!buttonGrid.Has(buttonName))
        return

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
            ; Try HBITMAP first (memory-only, no file I/O)
            hBitmapHandle := CreateHBITMAPVisualization(macroEvents[layerMacroName], buttonSize)

            if (hBitmapHandle) {
                ; HBITMAP worked - assign directly to picture control
                button.Visible := false
                picture.Visible := true
                picture.Text := ""
                picture.Value := "HBITMAP:*" . hBitmapHandle
                ; Cache the HBITMAP for performance
                buttonThumbnails[layerMacroName] := hBitmapHandle
            } else {
                ; HBITMAP failed - fall back to PNG file approach
                pngFile := CreateMacroVisualization(macroEvents[layerMacroName], buttonSize)

                if (pngFile && FileExist(pngFile)) {
                    ; PNG created successfully - assign to picture control
                    button.Visible := false
                    picture.Visible := true
                    picture.Text := ""
                    picture.Value := pngFile
                    ; Schedule cleanup of temporary PNG file after a delay
                    SetTimer(() => FileDelete(pngFile), -5000)
                }
                ; If PNG also fails, button stays as text display
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
            if (Type(thumbnailValue) = "Integer" && thumbnailValue > 0) {
                ; HBITMAP handle - assign directly
                picture.Value := "HBITMAP:*" . thumbnailValue
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

    if (button.Visible)
        button.Redraw()
    if (picture.Visible)
        picture.Redraw()
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
    UpdateStatus("🖱️ Button: " . buttonName)
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

; ===== COMPREHENSIVE CONFIGURATION SYSTEM =====

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
        UpdateStatus("☕ Break mode active")
    } else {
        ; Restore normal UI
        RestoreNormalUI()
        UpdateStatus("✅ Back from break")
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
        mainGui.Redraw()
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
        UpdateStatus("🖼️ Added thumbnail for " . buttonName . " on Layer " . currentLayer)
    }
}

RemoveThumbnail(buttonName) {
    global currentLayer, buttonThumbnails

    layerMacroName := "L" . currentLayer . "_" . buttonName

    if (buttonThumbnails.Has(layerMacroName)) {
        buttonThumbnails.Delete(layerMacroName)
        UpdateButtonAppearance(buttonName)
        SaveMacroState()
        UpdateStatus("🗑️ Removed thumbnail for " . buttonName . " on Layer " . currentLayer)
    }
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
        UpdateStatus("✅ Auto mode enabled for " . buttonName)
        UpdateButtonAppearance(buttonName)
    }
}

DisableAutoMode(buttonName) {
    global buttonAutoSettings, currentLayer

    layerKey := "L" . currentLayer . "_" . buttonName

    if (buttonAutoSettings.Has(layerKey)) {
        buttonAutoSettings[layerKey].enabled := false
        UpdateStatus("❌ Auto mode disabled for " . buttonName)
        UpdateButtonAppearance(buttonName)
    }
}

; ===== EMERGENCY BUTTON TEXT UPDATE =====
UpdateEmergencyButtonText() {
    global mainGui, hotkeyEmergency

    if (mainGui.HasProp("btnEmergency") && mainGui.btnEmergency) {
        mainGui.btnEmergency.Text := "🚨 " . hotkeyEmergency
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

    UpdateStatus("🔥 Layer " . currentLayer)
}

; ===== SETTINGS APPLY FUNCTIONS =====
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

; ===== WELCOME MESSAGE =====
ShowWelcomeMessage() {
    UpdateStatus("🚀 Ready - WASD hotkeys active (CapsLock+123qweasdzxc) - Real-time dashboard enabled - Currently in " . (annotationMode = "Wide" ? "🔦 WIDE MODE" : "📱 NARROW MODE") . " - F9 to record, F12 for dashboard")
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


; ===== AUTOMATION SETTINGS =====
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



; ===== SAVE ALL SETTINGS =====
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

; ===== NEW SETTINGS FUNCTIONS =====

; Update timing value when edit control changes
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
    UpdateStatus("⚡ Updated " . timingVar . " to " . newValue . "ms")
}

; Apply timing preset
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
    UpdateStatus("⏱️ Applied " . preset . " timing preset")
}

; Browse macro packs
BrowseMacroPacks(*) {
    global workDir

    try {
        packDir := workDir . "\packs"

        if (!DirExist(packDir)) {
            UpdateStatus("📚 No macro packs found - create your first pack first")
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
            UpdateStatus("📚 No macro packs found in directory")
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

        UpdateStatus("📚 Found " . packCount . " macro packs")

    } catch Error as e {
        UpdateStatus("⚠️ Browse packs failed: " . e.Message)
        MsgBox("Failed to browse macro packs: " . e.Message, "Browse Error", "Icon!")
    }
}


; Configure wide canvas from settings
ConfigureWideCanvasFromSettings(settingsGui) {
    settingsGui.Hide()
    CalibrateWideCanvasArea()
    settingsGui.Destroy()
    ShowSettings()  ; Refresh the settings dialog
}

; Configure narrow canvas from settings
ConfigureNarrowCanvasFromSettings(settingsGui) {
    settingsGui.Hide()
    CalibrateNarrowCanvasArea()
    settingsGui.Destroy()
    ShowSettings()  ; Refresh the settings dialog
}


; Clear all macros from settings
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

; Manual save configuration
ManualSaveConfig(*) {
    try {
        SaveConfig()
        MsgBox("Configuration saved successfully!", "Manual Save", "Icon!")
    } catch Error as e {
        MsgBox("Failed to save configuration: " . e.Message, "Save Error", "Icon!")
    }
}

; Manual restore from backup
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

; Reset stats from settings
ResetStatsFromSettings(settingsGui, *) {
    result := MsgBox("Reset all statistics and performance data?`n`nThis will clear execution history and performance metrics.", "Reset Statistics", "YesNo Icon!")

    if (result = "Yes") {
        try {
            ; Call the reset function from Stats.ahk
            ResetAllStats()
            UpdateStatus("📊 All statistics have been reset successfully")
        } catch Error as e {
            UpdateStatus("⚠️ Error resetting statistics: " . e.Message)
        }
        settingsGui.Destroy()
    }
}