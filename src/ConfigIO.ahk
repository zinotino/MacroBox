/*
==============================================================================
CONFIG I/O MODULE - Configuration file save/load and import/export
==============================================================================
Handles all configuration persistence operations
*/

; ===== CONFIGURATION SAVE FUNCTION =====
SaveConfig() {
    global workDir, configFile
    global annotationMode, darkMode, currentDegradation
    global windowWidth, windowHeight, scaleFactor, minWindowWidth, minWindowHeight
    global canvasWidth, canvasHeight, canvasType, canvasAspectRatio
    global wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom, isWideCanvasCalibrated
    global narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom, isNarrowCanvasCalibrated
    global userCanvasLeft, userCanvasTop, userCanvasRight, userCanvasBottom, isCanvasCalibrated
    global hotkeyRecordToggle, hotkeySubmit, hotkeyDirectClear, hotkeyStats, hotkeyBreakMode
    global hotkeySettings, hotkeyProfileActive, wasdLabelsEnabled
    global boxDrawDelay, mouseClickDelay, menuClickDelay, mouseDragDelay, mouseReleaseDelay
    global betweenBoxDelay, keyPressDelay, focusDelay, mouseHoverDelay
    global smartBoxClickDelay, smartMenuClickDelay
    global macroEvents, buttonNames, buttonCustomLabels, buttonLetterboxingStates
    local macrosSaved := 0, settingsSaved := 0

    try {
        ; Ensure config directory exists (MacroMaster\data folder in Documents)
        configDir := workDir
        if !DirExist(configDir) {
            DirCreate(configDir)
        }

        ; Build config content
        content := "[Settings]`n"
        settingsSaved := 0

        ; Core settings
        content .= "annotationMode=" . annotationMode . "`n"
        content .= "darkMode=" . (darkMode ? "true" : "false") . "`n"
        content .= "currentDegradation=" . currentDegradation . "`n"
        content .= "windowWidth=" . windowWidth . "`n"
        content .= "windowHeight=" . windowHeight . "`n"
        content .= "scaleFactor=" . scaleFactor . "`n"
        content .= "minWindowWidth=" . minWindowWidth . "`n"
        content .= "minWindowHeight=" . minWindowHeight . "`n"
        settingsSaved += 8

        ; Canvas settings (basic canvas properties only - detailed calibration in [Canvas] section)
        content .= "canvasWidth=" . canvasWidth . "`n"
        content .= "canvasHeight=" . canvasHeight . "`n"
        content .= "canvasType=" . canvasType . "`n"
        content .= "canvasAspectRatio=" . canvasAspectRatio . "`n"
        settingsSaved += 4

        ; Canvas section (separate from Settings to match original implementation)
        content .= "`n[Canvas]`n"
        content .= "WideCanvasLeft=" . wideCanvasLeft . "`n"
        content .= "WideCanvasTop=" . wideCanvasTop . "`n"
        content .= "WideCanvasRight=" . wideCanvasRight . "`n"
        content .= "WideCanvasBottom=" . wideCanvasBottom . "`n"
        content .= "IsWideCanvasCalibrated=" . (isWideCanvasCalibrated ? "1" : "0") . "`n"
        content .= "NarrowCanvasLeft=" . narrowCanvasLeft . "`n"
        content .= "NarrowCanvasTop=" . narrowCanvasTop . "`n"
        content .= "NarrowCanvasRight=" . narrowCanvasRight . "`n"
        content .= "NarrowCanvasBottom=" . narrowCanvasBottom . "`n"
        content .= "IsNarrowCanvasCalibrated=" . (isNarrowCanvasCalibrated ? "1" : "0") . "`n"
        content .= "UserCanvasLeft=" . userCanvasLeft . "`n"
        content .= "UserCanvasTop=" . userCanvasTop . "`n"
        content .= "UserCanvasRight=" . userCanvasRight . "`n"
        content .= "UserCanvasBottom=" . userCanvasBottom . "`n"
        content .= "IsCanvasCalibrated=" . (isCanvasCalibrated ? "1" : "0") . "`n"
        content .= "`n"

        ; Hotkey settings
        content .= "hotkeyRecordToggle=" . hotkeyRecordToggle . "`n"
        content .= "hotkeySubmit=" . hotkeySubmit . "`n"
        content .= "hotkeyDirectClear=" . hotkeyDirectClear . "`n"
        content .= "hotkeyStats=" . hotkeyStats . "`n"
        content .= "hotkeyBreakMode=" . hotkeyBreakMode . "`n"
        content .= "hotkeySettings=" . hotkeySettings . "`n"
        settingsSaved += 6

        ; WASD settings
        content .= "hotkeyProfileActive=" . (hotkeyProfileActive ? "true" : "false") . "`n"
        content .= "wasdLabelsEnabled=" . (wasdLabelsEnabled ? "true" : "false") . "`n"
        settingsSaved += 2

        settingsSaved += 3

        ; Timing settings
        content .= "boxDrawDelay=" . boxDrawDelay . "`n"
        content .= "mouseClickDelay=" . mouseClickDelay . "`n"
        content .= "menuClickDelay=" . menuClickDelay . "`n"
        content .= "mouseDragDelay=" . mouseDragDelay . "`n"
        content .= "mouseReleaseDelay=" . mouseReleaseDelay . "`n"
        content .= "betweenBoxDelay=" . betweenBoxDelay . "`n"
        content .= "keyPressDelay=" . keyPressDelay . "`n"
        content .= "focusDelay=" . focusDelay . "`n"
        content .= "mouseHoverDelay=" . mouseHoverDelay . "`n"
        content .= "smartBoxClickDelay=" . smartBoxClickDelay . "`n"
        content .= "smartMenuClickDelay=" . smartMenuClickDelay . "`n"
        settingsSaved += 10

        ; Macros section - WRITE ACTUAL MACRO DATA
        content .= "`n[Macros]`n"
        macrosSaved := 0
        for buttonName in buttonNames {
            if (macroEvents.Has(buttonName) && macroEvents[buttonName].Length > 0) {
                events := macroEvents[buttonName]
                eventStrings := []

                for event in events {
                    eventStr := event.type

                    switch event.type {
                        case "boundingBox":
                            eventStr .= "," . event.left . "," . event.top . "," . event.right . "," . event.bottom
                            if (event.HasOwnProp("degradationType")) {
                                eventStr .= "," . event.degradationType
                            }
                            if (event.HasOwnProp("degradationName")) {
                                eventStr .= "," . event.degradationName
                            }
                            if (event.HasOwnProp("assignedBy")) {
                                eventStr .= "," . event.assignedBy
                            }

                        case "jsonAnnotation":
                            eventStr .= "," . event.mode . "," . event.categoryId . "," . event.severity
                            if (event.HasOwnProp("isTagged")) {
                                eventStr .= "," . (event.isTagged ? "1" : "0")
                            }

                        case "keyDown", "keyUp":
                            eventStr .= "," . event.key

                        case "mouseDown", "mouseUp":
                            eventStr .= "," . event.x . "," . event.y . "," . event.button

                        default:
                            if (event.HasOwnProp("x")) {
                                eventStr .= "," . event.x
                            }
                            if (event.HasOwnProp("y")) {
                                eventStr .= "," . event.y
                            }
                    }

                    eventStrings.Push(eventStr)
                }

                ; Join all events with pipe separator
                content .= buttonName . "=" . StrJoin(eventStrings, "|") . "`n"
                macrosSaved++

                ; Save recordedMode if available
                if (events.HasOwnProp("recordedMode") && events.recordedMode != "") {
                    content .= buttonName . "_RecordedMode=" . events.recordedMode . "`n"
                }
            }
        }

        content .= "`n[Labels]`n"
        if (IsSet(buttonCustomLabels) && Type(buttonCustomLabels) = "Map") {
            for buttonName, label in buttonCustomLabels {
                try {
                    if (IsSet(label) && label != "") {
                        content .= buttonName . "=" . label . "`n"
                    }
                } catch {
                    continue
                }
            }
        }

        ; Thumbnails section - save custom thumbnails for persistence
        content .= "`n[Thumbnails]`n"
        global buttonThumbnails
        if (IsSet(buttonThumbnails) && Type(buttonThumbnails) = "Map") {
            for buttonKey, thumbnailPath in buttonThumbnails {
                ; Validate entry before accessing
                try {
                    if (IsSet(thumbnailPath) && thumbnailPath != "" && Type(thumbnailPath) = "String" && FileExist(thumbnailPath)) {
                        content .= buttonKey . "=" . thumbnailPath . "`n"
                    }
                } catch {
                    ; Skip entries with no value or invalid type
                    continue
                }
            }
        }

        ; Letterboxing preferences section - save per-button letterboxing states
        content .= "`n[Letterboxing]`n"
        if (IsSet(buttonLetterboxingStates) && Type(buttonLetterboxingStates) = "Map") {
            for buttonKey, letterboxingState in buttonLetterboxingStates {
                ; Validate entry before accessing
                try {
                    if (IsSet(letterboxingState) && letterboxingState != "" && Type(letterboxingState) = "String") {
                        content .= buttonKey . "=" . letterboxingState . "`n"
                    }
                } catch {
                    ; Skip entries with no value or invalid type
                    continue
                }
            }
        }

        ; Write config file directly
        try {
            FileDelete(configFile)
        } catch {
            ; Ignore if file doesn't exist
        }

        FileAppend(content, configFile, "UTF-8")

        UpdateStatus("💾 Saved")

    } catch Error as e {
        UpdateStatus("❌ Save failed: " . e.Message)
        MsgBox("Failed to save configuration!`n`nError: " . e.Message, "Save Error", "Icon!")
        throw e
    }
}

; ===== CONFIGURATION LOAD FUNCTION =====
LoadConfig() {
    global wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom, isWideCanvasCalibrated
    global narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom, isNarrowCanvasCalibrated
    global userCanvasLeft, userCanvasTop, userCanvasRight, userCanvasBottom, isCanvasCalibrated
    global workDir

    try {
        ; Ensure config directory exists (MacroMaster\data folder in Documents)
        configDir := workDir
        if !DirExist(configDir) {
            DirCreate(configDir)
            if !DirExist(configDir) {
                UpdateStatus("❌ Failed to create config directory")
                throw Error("Failed to create config directory: " . configDir)
            }
        }

        ; Check if config file exists
        if !FileExist(configFile) {
            return
        }

        ; Read and parse the config file
        content := FileRead(configFile, "UTF-8")
        lines := StrSplit(content, "`n")

        currentSection := ""
        local macrosLoaded := 0, settingsLoaded := 0
        for line in lines {
            line := Trim(line)
            if (line = "" || SubStr(line, 1, 1) = ";")
                continue

            if (SubStr(line, 1, 1) = "[" && SubStr(line, -1) = "]") {
                currentSection := SubStr(line, 2, -1)
                continue
            }

            if (InStr(line, "=")) {
                parts := StrSplit(line, "=", , 2)
                if (parts.Length != 2)
                    continue

                key := Trim(parts[1])
                value := Trim(parts[2])

                ; Process based on section
                switch currentSection {
                    case "Settings":
                        ; Process core settings
                        switch key {
                            case "annotationMode": annotationMode := value
                            case "darkMode": darkMode := (value = "true")
                            case "currentDegradation": currentDegradation := EnsureInteger(value, 1)
                            case "windowWidth": windowWidth := EnsureInteger(value, 1200)
                            case "windowHeight": windowHeight := EnsureInteger(value, 800)
                            case "scaleFactor": scaleFactor := Number(value)
                            case "minWindowWidth": minWindowWidth := EnsureInteger(value, 900)
                            case "minWindowHeight": minWindowHeight := EnsureInteger(value, 600)
                            case "canvasWidth": canvasWidth := EnsureInteger(value, 1920)
                            case "canvasHeight": canvasHeight := EnsureInteger(value, 1080)
                            case "canvasType": canvasType := value
                            case "canvasAspectRatio": canvasAspectRatio := Number(value)
                            case "hotkeyRecordToggle": hotkeyRecordToggle := value
                            case "hotkeySubmit": hotkeySubmit := value
                            case "hotkeyDirectClear": hotkeyDirectClear := value
                            case "hotkeyStats": hotkeyStats := value
                            case "hotkeyBreakMode": hotkeyBreakMode := value
                            case "hotkeySettings": hotkeySettings := value
                            case "hotkeyProfileActive": hotkeyProfileActive := (value = "true")
                            case "wasdLabelsEnabled": wasdLabelsEnabled := (value = "true")
                            case "boxDrawDelay": boxDrawDelay := EnsureInteger(value, 75)
                            case "mouseClickDelay": mouseClickDelay := EnsureInteger(value, 85)
                            case "menuClickDelay": menuClickDelay := EnsureInteger(value, 150)
                            case "mouseDragDelay": mouseDragDelay := EnsureInteger(value, 90)
                            case "mouseReleaseDelay": mouseReleaseDelay := EnsureInteger(value, 90)
                            case "betweenBoxDelay": betweenBoxDelay := EnsureInteger(value, 200)
                            case "keyPressDelay": keyPressDelay := EnsureInteger(value, 20)
                            case "focusDelay": focusDelay := EnsureInteger(value, 80)
                            case "mouseHoverDelay": mouseHoverDelay := EnsureInteger(value, 35)
                            case "smartBoxClickDelay": smartBoxClickDelay := EnsureInteger(value, 35)
                            case "smartMenuClickDelay": smartMenuClickDelay := EnsureInteger(value, 120)
                        }

                    case "Macros":
                        ; Check if this is a recordedMode property
                        if (InStr(key, "_RecordedMode")) {
                            ; Extract the macro name (remove "_RecordedMode" suffix)
                            macroName := StrReplace(key, "_RecordedMode", "")
                            ; Apply immediately if macro already loaded
                            if (macroEvents.Has(macroName)) {
                                macroEvents[macroName].recordedMode := value
                            }
                        } else {
                            ProcessMacroLine(key, value)
                        }

                    case "Labels":
                        ProcessCustomLabel(key, value)

                    case "Thumbnails":
                        ; Restore thumbnails (only file paths, not HBITMAP handles)
                        global buttonThumbnails
                        if (FileExist(value)) {
                            buttonThumbnails[key] := value
                        }

                    case "Letterboxing":
                        ; Restore letterboxing preferences
                        global buttonLetterboxingStates
                        if (value = "wide" || value = "narrow" || value = "auto") {
                            buttonLetterboxingStates[key] := value
                        }

                    case "Canvas":
                        ; Process canvas section (matches original implementation)
                        switch key {
                            case "WideCanvasLeft": wideCanvasLeft := EnsureInteger(value, 0)
                            case "WideCanvasTop": wideCanvasTop := EnsureInteger(value, 0)
                            case "WideCanvasRight": wideCanvasRight := EnsureInteger(value, 1920)
                            case "WideCanvasBottom": wideCanvasBottom := EnsureInteger(value, 1080)
                            case "IsWideCanvasCalibrated": isWideCanvasCalibrated := (value = "1")
                            case "NarrowCanvasLeft": narrowCanvasLeft := EnsureInteger(value, 240)
                            case "NarrowCanvasTop": narrowCanvasTop := EnsureInteger(value, 0)
                            case "NarrowCanvasRight": narrowCanvasRight := EnsureInteger(value, 1680)
                            case "NarrowCanvasBottom": narrowCanvasBottom := EnsureInteger(value, 1080)
                            case "IsNarrowCanvasCalibrated": isNarrowCanvasCalibrated := (value = "1")
                            case "UserCanvasLeft": userCanvasLeft := EnsureInteger(value, 0)
                            case "UserCanvasTop": userCanvasTop := EnsureInteger(value, 0)
                            case "UserCanvasRight": userCanvasRight := EnsureInteger(value, 1920)
                            case "UserCanvasBottom": userCanvasBottom := EnsureInteger(value, 1080)
                            case "IsCanvasCalibrated": isCanvasCalibrated := (value = "1")
                        }
                }
            }
        }

        ; Validate canvas values and sync
        ValidateAndFixCanvasValues()
        Canvas_SyncFromLegacyGlobals()

        UpdateStatus("📚 Loaded")

    } catch Error as e {
        UpdateStatus("❌ Load failed: " . e.Message)
        throw e
    }
}

; ===== APPLY SETTINGS TO GUI =====
ApplyLoadedSettingsToGUI() {
    global wasdLabelsEnabled, annotationMode, modeToggleBtn
    global gdiPlusInitialized, hbitmapCache

    try {
        ; Update mode toggle button text
        if (modeToggleBtn) {
            modeToggleBtn.Text := (annotationMode = "Wide") ? "🔦 Wide" : "📱 Narrow"
        }

        ; Update WASD labels if enabled
        if (wasdLabelsEnabled) {
            UpdateButtonLabelsWithWASD()
        }

        ; Initialize GDI+ if needed
        if (!gdiPlusInitialized) {
            InitializeVisualizationSystem()
        }

        ; Clear and reset HBITMAP cache
        CleanupHBITMAPCache()
        hbitmapCache := Map()

        ; Refresh button appearances
        RefreshAllButtonAppearances()

    } catch Error as e {
        UpdateStatus("⚠️ GUI settings error: " . e.Message)
    }
}





