/*
==============================================================================
GUI LAYOUT MODULE - GUI creation and layout management
==============================================================================
Handles GUI initialization, toolbar, grid, and resize logic
*/

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
    global mainGui, darkMode, modeToggleBtn, windowWidth

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

    ; Right section - repositioned for single-layer layout
    rightSection := Round(windowWidth * 0.5)
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
    global mainGui, gridOutline, scaleFactor, windowWidth, windowHeight

    ; Create grid outline with fixed color - single layer system
    gridOutline := mainGui.Add("Text", "x" . Round(8) . " y" . Round(43 * scaleFactor) . " w" . Round(384 * scaleFactor) . " h" . Round(288 * scaleFactor) . " +Background0x404040")
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

; ===== GUI RESIZE HANDLER =====
GuiResize(GuiObj, MinMax, Width, Height) {
    global mainGui, statusBar, windowWidth, windowHeight, gridOutline, buttonGrid, buttonLabels, buttonPictures, buttonNames, darkMode, scaleFactor

    windowWidth := Width
    windowHeight := Height

    ; Resize toolbar background
    if (mainGui.HasProp("tbBg")) {
        mainGui.tbBg.Move(, , Width)
    }

    ; Reposition right section (no layer navigation in single-layer system)
    if (mainGui.HasProp("btnStats") && mainGui.HasProp("btnSettings") && mainGui.HasProp("btnEmergency")) {
        rightSection := Round(Width * 0.7)
        spacing := 8
        rightWidth := Width - rightSection - spacing
        btnWidth := Round((rightWidth - 20) / 3)
        btnY := (35 - 30) / 2

        mainGui.btnStats.Move(rightSection, btnY, btnWidth)
        mainGui.btnSettings.Move(rightSection + btnWidth + 5, btnY, btnWidth)
        mainGui.btnEmergency.Move(rightSection + (btnWidth * 2) + 10, btnY, btnWidth)
    }

    ; Resize button grid
    margin := 8
    padding := 4
    toolbarHeight := Round(35 * scaleFactor)
    gridTopPadding := 4
    gridBottomPadding := 30

    gridWidth := Width - (margin * 2)
    gridHeight := Height - toolbarHeight - gridTopPadding - gridBottomPadding - (margin * 2)

    buttonWidth := Floor((gridWidth - padding * 2) / 3)
    buttonHeight := Floor((gridHeight - padding * 3) / 4)
    labelHeight := Round(18 * scaleFactor)
    thumbHeight := buttonHeight - labelHeight - 2

    ; Update grid outline
    outlineThickness := 2
    gridOutline.Move(margin - outlineThickness, toolbarHeight + gridTopPadding + margin - outlineThickness,
                    gridWidth + (outlineThickness * 2), gridHeight + (outlineThickness * 2))

    ; Reposition all buttons
    for row in [0, 1, 2, 3] {
        for col in [0, 1, 2] {
            index := row * 3 + col + 1
            if (index > 12)
                continue

            buttonName := buttonNames[index]
            x := margin + col * (buttonWidth + padding)
            y := toolbarHeight + gridTopPadding + margin + row * (buttonHeight + padding)
            labelY := y + thumbHeight + 1

            buttonGrid[buttonName].Move(Floor(x), Floor(y), Floor(buttonWidth), Floor(thumbHeight))
            buttonPictures[buttonName].Move(Floor(x), Floor(y), Floor(buttonWidth), Floor(thumbHeight))
            buttonLabels[buttonName].Move(Floor(x), Floor(labelY), Floor(buttonWidth), Floor(labelHeight))
        }
    }

    ; Reposition status bar
    statusY := Height - 25
    statusBar.Move(8, statusY, Width - 16)

    ; Refresh button appearances after resize
    for buttonName in buttonNames {
        UpdateButtonAppearance(buttonName)
    }
}

