/*
==============================================================================
GUI CONTROLS MODULE - Button controls and appearance management
==============================================================================
Handles button appearance updates, thumbnails, flashing, and visual state
*/

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
        jsonInfo := typeName . " " . StrUpper(jsonEvent.severity)

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
            global annotationMode

            ; Both modes use picture control with colored visualization
            buttonSize := GetButtonThumbnailSize()
            hbitmap := DrawJsonWithLetterboxBars(jsonColor, buttonSize, annotationMode, jsonInfo)

            if (hbitmap) {
                button.Visible := false
                picture.Visible := true
                picture.Value := "HBITMAP:" . hbitmap
            } else {
                ; Fallback to button control
                button.Visible := true
                picture.Visible := false
                button.Opt("+Background" . jsonColor)
                button.SetFont("s7 bold", "cBlack")
                button.Text := jsonInfo
            }
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

            ; WASD labels always enabled - no layer text on buttons
            button.Text := ""
        }
    }

    ; Label control - always visible with button name/custom label
    buttonLabels[buttonName].Visible := true
    buttonLabels[buttonName].Text := buttonCustomLabels.Has(buttonName) ? buttonCustomLabels[buttonName] : buttonName
    buttonLabels[buttonName].Redraw()

    ; Apply yellow outline for auto mode buttons
    ApplyYellowOutline(buttonName, hasAutoMode)
}

UpdateAllButtonAppearances() {
    global buttonNames
    for buttonName in buttonNames {
        UpdateButtonAppearance(buttonName)
    }
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
    global gridOutline, currentLayer, layerBorderColors

    if (gridOutline) {
        ; Always use WASD mode color scheme
        gridOutline.Opt("+Background0xFF6B35")  ; Orange-red for WASD mode
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

; ===== STATUS MANAGEMENT =====
UpdateStatus(text) {
    global statusBar
    if (statusBar) {
        statusBar.Text := text
        statusBar.Redraw()
    }
}

; ===== VISUALIZATION HELPER =====
GetButtonThumbnailSize() {
    global buttonGrid, buttonNames

    if (buttonNames.Length = 0 || !buttonGrid.Has(buttonNames[1])) {
        return {width: 120, height: 90}
    }

    firstButton := buttonGrid[buttonNames[1]]
    firstButton.GetPos(, , &w, &h)

    return {
        width: Integer(w),
        height: Integer(h)
    }
}

; ===== YELLOW OUTLINE FOR AUTO MODE =====
ApplyYellowOutline(buttonName, hasAutoMode) {
    global buttonGrid, yellowOutlineButtons

    if (!buttonGrid.Has(buttonName)) {
        return
    }

    button := buttonGrid[buttonName]

    if (hasAutoMode && !yellowOutlineButtons.Has(buttonName)) {
        ; Apply yellow outline
        button.Opt("+Border")
        yellowOutlineButtons[buttonName] := true
    } else if (!hasAutoMode && yellowOutlineButtons.Has(buttonName)) {
        ; Remove yellow outline
        button.Opt("-Border")
        yellowOutlineButtons.Delete(buttonName)
    }
}
