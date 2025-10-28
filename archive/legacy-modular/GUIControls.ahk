/*
==============================================================================
GUI CONTROLS MODULE - Button controls and appearance management
==============================================================================
Handles button appearance updates, thumbnails, flashing, and visual state
*/

; ===== VISUALIZATION LOGGING =====
LogVisualizationAttempt(buttonName, method, success, errorMsg := "") {
    ; Comprehensive logging for visualization method attempts
    global visualizationLogFile

    ; Initialize log file path if needed
    if (!visualizationLogFile) {
        visualizationLogFile := A_ScriptDir . "\mono\visualization_test_log.txt"
    }

    ; Format log message
    timestamp := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
    status := success ? "SUCCESS" : "FAILED"
    logMsg := "[" . timestamp . "] [VISUALIZATION] Button " . buttonName . " using " . method . " - " . status

    if (errorMsg != "") {
        logMsg .= " (" . errorMsg . ")"
    }

    ; Append to log file
    try {
        FileAppend(logMsg . "`n", visualizationLogFile)
    } catch {
        ; Ignore logging errors
    }

    ; Also output to console for debugging
    OutputDebug(logMsg)
}

; ===== BUTTON APPEARANCE =====
RefreshAllButtonAppearances() {
    global buttonNames
    for buttonName in buttonNames {
        UpdateButtonAppearance(buttonName)
    }
}

UpdateButtonAppearance(buttonName) {
    global buttonGrid, buttonPictures, buttonThumbnails, macroEvents, buttonCustomLabels, darkMode, degradationTypes, degradationColors, buttonLabels, wasdLabelsEnabled, hbitmapCache, annotationMode, buttonDisplayedHBITMAPs, buttonLetterboxingStates

    ; Early return for invalid button names
    if (!buttonGrid.Has(buttonName)) {
        return
    }

    button := buttonGrid[buttonName]
    picture := buttonPictures[buttonName]

    ; Clean up old HBITMAP if this button had one displayed
    if (buttonDisplayedHBITMAPs.Has(buttonName) && buttonDisplayedHBITMAPs[buttonName] != 0) {
        oldHbitmap := buttonDisplayedHBITMAPs[buttonName]
        ; DEBUG: Log HBITMAP cleanup
        FileAppend("=== UpdateButtonAppearance: Cleaning up old HBITMAP " . oldHbitmap . " for button " . buttonName . " ===`n", "mono/visualization_test_log.txt")
        ; Remove reference instead of deleting directly
        RemoveHBITMAPReference(oldHbitmap)
        buttonDisplayedHBITMAPs[buttonName] := 0
    }

    ; Check macro existence (simple button name, no layer prefix)
    hasMacro := macroEvents.Has(buttonName) && macroEvents[buttonName].Length > 0

    ; Early return for empty buttons
    if (!hasMacro) {
        buttonLabels[buttonName].Text := buttonCustomLabels.Has(buttonName) ? buttonCustomLabels[buttonName] : buttonName
        picture.Visible := false
        button.Visible := true
        button.Opt("+Background" . (darkMode ? "0x2A2A2A" : "0xF8F8F8"))
        button.SetFont("s8", "cGray")
        button.Text := ""
        return
    }

    buttonLabels[buttonName].Text := buttonCustomLabels.Has(buttonName) ? buttonCustomLabels[buttonName] : buttonName

    ; Check for thumbnail
    thumbnailValue := buttonThumbnails.Has(buttonName) ? buttonThumbnails[buttonName] : ""
    hasThumbnail := thumbnailValue != "" && (Type(thumbnailValue) = "Integer" || FileExist(thumbnailValue))

    ; Check for JSON annotation
    isJsonAnnotation := false
    jsonInfo := ""
    jsonColor := "0xFFD700"
    jsonMode := ""

    if (hasMacro && macroEvents[buttonName].Length = 1 && macroEvents[buttonName][1].type = "jsonAnnotation") {
        isJsonAnnotation := true
        jsonEvent := macroEvents[buttonName][1]
        typeName := StrTitle(degradationTypes[jsonEvent.categoryId])
        ; CRITICAL: Use stored mode from event for correct letterboxing
        if (Type(jsonEvent) = "Map") {
            jsonMode := jsonEvent.Has("mode") && jsonEvent["mode"] != "" ? jsonEvent["mode"] : annotationMode
        } else {
            jsonMode := (jsonEvent.HasOwnProp("mode") && jsonEvent.mode != "") ? jsonEvent.mode : annotationMode
        }
        jsonInfo := typeName . "`n" . StrUpper(jsonEvent.severity)

        if (degradationColors.Has(jsonEvent.categoryId)) {
            jsonColor := Format("0x{:X}", degradationColors[jsonEvent.categoryId])
        }
    }

    ; Check for visualizable macro
    hasVisualizableMacro := hasMacro && !isJsonAnnotation && macroEvents[buttonName].Length > 1

    if (hasVisualizableMacro) {
        ; HBITMAP IN-MEMORY VISUALIZATION: Use the proven working method from stable snapshot
        FileAppend("=== UpdateButtonAppearance: Getting button size for " . buttonName . " ===`n", "mono/visualization_test_log.txt")
        buttonSize := GetButtonThumbnailSize()
        FileAppend("=== UpdateButtonAppearance: Extracted " . boxes.Length . " boxes for " . buttonName . " ===`n", "mono/visualization_test_log.txt")
        boxes := ExtractBoxEvents(macroEvents[buttonName])

        if (boxes.Length > 0) {
            ; Check per-button letterboxing preference first
            buttonLetterboxingPref := ""
            if (IsSet(buttonLetterboxingStates) && Type(buttonLetterboxingStates) = "Map" && buttonLetterboxingStates.Has(buttonName)) {
                buttonLetterboxingPref := buttonLetterboxingStates[buttonName]
            }

            ; Override recorded mode if user has set a specific preference
            if (buttonLetterboxingPref = "wide") {
                macroEvents[buttonName].recordedMode := "Wide"
            } else if (buttonLetterboxingPref = "narrow") {
                macroEvents[buttonName].recordedMode := "Narrow"
            } else if (buttonLetterboxingPref = "auto") {
                ; Auto mode - keep existing recorded mode
            }

            FileAppend("=== UpdateButtonAppearance: About to call CreateHBITMAPVisualization for " . buttonName . " ===`n", "mono/visualization_test_log.txt")
            ; Create HBITMAP visualization directly (no PNG fallback)
            hbitmap := CreateHBITMAPVisualization(macroEvents[buttonName], buttonSize)
            FileAppend("=== UpdateButtonAppearance: CreateHBITMAPVisualization returned " . hbitmap . " for " . buttonName . " ===`n", "mono/visualization_test_log.txt")

            if (hbitmap && hbitmap != 0) {
                ; HBITMAP creation succeeded - use picture control
                button.Visible := false
                picture.Visible := true
                try {
                    picture.Value := "HBITMAP:" . hbitmap
                    ; Track this HBITMAP as displayed on this button and add reference
                    buttonDisplayedHBITMAPs[buttonName] := hbitmap
                    AddHBITMAPReference(hbitmap)
                    FileAppend("=== UpdateButtonAppearance: HBITMAP " . hbitmap . " assigned to button " . buttonName . " ===`n", "mono/visualization_test_log.txt")
                    LogVisualizationAttempt(buttonName, "HBITMAP in-memory visualization", true)
                } catch as e {
                    ; HBITMAP assignment failed - fallback to text
                    LogVisualizationAttempt(buttonName, "HBITMAP assignment", false, "Exception: " . e.Message)
                    button.Visible := true
                    picture.Visible := false
                    button.Opt("+Background0x404040")
                    button.SetFont("s7 bold", "cWhite")
                    button.Text := "MACRO`n" . boxes.Length . " boxes"
                }
            } else {
                ; HBITMAP creation failed - use text display
                LogVisualizationAttempt(buttonName, "HBITMAP in-memory visualization", false, "CreateHBITMAPVisualization returned invalid handle")
                button.Visible := true
                picture.Visible := false
                button.Opt("+Background0x404040")
                button.SetFont("s7 bold", "cWhite")
                button.Text := "MACRO`n" . boxes.Length . " boxes"
            }
        } else {
            FileAppend("=== UpdateButtonAppearance: No boxes found for " . buttonName . " - using text display ===`n", "mono/visualization_test_log.txt")
        }
        ; If no boxes found, button stays as text display
    } else if (isJsonAnnotation) {
        ; JSON annotation with HBITMAP visualization (simplified to match stable snapshot)
        buttonSize := GetButtonThumbnailSize()

        ; Create HBITMAP visualization directly for JSON annotations
        hbitmap := CreateJsonHBITMAPVisualization(jsonColor, buttonSize, jsonMode, jsonInfo)

        if (hbitmap && hbitmap != 0) {
            ; HBITMAP creation succeeded - use picture control
            button.Visible := false
            picture.Visible := true
            try {
                picture.Value := "HBITMAP:" . hbitmap
                ; Track this HBITMAP as displayed on this button and add reference
                buttonDisplayedHBITMAPs[buttonName] := hbitmap
                AddHBITMAPReference(hbitmap)
                FileAppend("=== UpdateButtonAppearance: JSON HBITMAP " . hbitmap . " assigned to button " . buttonName . " ===`n", "mono/visualization_test_log.txt")
            } catch {
                ; HBITMAP assignment failed - fallback to text
                picture.Visible := false
                button.Visible := true
                button.Opt("+Background" . jsonColor)
                button.SetFont("s7 bold", "cBlack")
                button.Text := jsonInfo
            }
        } else {
            ; HBITMAP creation failed - use text display
            picture.Visible := false
            button.Visible := true
            button.Opt("+Background" . jsonColor)
            button.SetFont("s7 bold", "cBlack")
            button.Text := jsonInfo
        }
    } else if (hasThumbnail) {
        ; Static thumbnail
        button.Visible := false
        picture.Visible := true
        picture.Text := ""
        try {
            thumbnailValue := buttonThumbnails[buttonName]
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

        if (hasMacro) {
            events := macroEvents[buttonName]
            ; Regular macro - fixed color for single-layer system
            button.Opt("+Background0x404040")
            button.SetFont("s7 bold", "cWhite")
            button.Text := "MACRO`n" . events.Length . " events"
        } else {
            button.Opt("+Background" . (darkMode ? "0x2A2A2A" : "0xF8F8F8"))
            button.SetFont("s8", "cGray")
            button.Text := ""  ; No layer indicator in single-layer system
        }
    }

    ; Label control - always visible with button name/custom label
    buttonLabels[buttonName].Visible := true
    buttonLabels[buttonName].Text := buttonCustomLabels.Has(buttonName) ? buttonCustomLabels[buttonName] : buttonName
}

; ===== THUMBNAIL OPERATIONS =====
AddThumbnail(buttonName) {
    global buttonThumbnails

    ; File selection dialog
    selectedFile := FileSelect("3", , "Select Thumbnail Image", "Images (*.png; *.jpg; *.jpeg; *.bmp; *.gif)")

    if (selectedFile != "") {
        buttonThumbnails[buttonName] := selectedFile
        UpdateButtonAppearance(buttonName)
        SaveMacroState()
        UpdateStatus("🖼️ Thumbnail added")
    }
}

RemoveThumbnail(buttonName) {
    global buttonThumbnails

    if (buttonThumbnails.Has(buttonName)) {
        buttonThumbnails.Delete(buttonName)
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
        ; No need for Redraw() - button updates automatically
    } else {
        ; Stop flashing - restore normal appearance
        UpdateButtonAppearance(buttonName)
    }
}

; ===== GRID OUTLINE COLOR UPDATE =====
UpdateGridOutlineColor() {
    global gridOutline, wasdLabelsEnabled

    if (gridOutline) {
        ; Update grid outline color based on WASD mode
        if (wasdLabelsEnabled) {
            ; WASD mode - use a different color scheme
            gridOutline.Opt("+Background0xFF6B35")  ; Orange-red for WASD mode
        } else {
            ; Normal mode - use fixed color for single-layer system
            gridOutline.Opt("+Background0x404040")
        }
        ; No need for Redraw() - outline updates automatically
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


