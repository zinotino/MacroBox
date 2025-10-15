/*
==============================================================================
CONFIG I/O MODULE - Configuration file save/load and import/export
==============================================================================
Handles all configuration persistence operations
*/

; ===== CONFIGURATION SAVE FUNCTION =====
SaveConfig() {
    global workDir, configFile
    global currentLayer, totalLayers, annotationMode, darkMode
    global windowWidth, windowHeight, scaleFactor, minWindowWidth, minWindowHeight
    global canvasWidth, canvasHeight, canvasType, canvasAspectRatio
    global wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom, isWideCanvasCalibrated
    global narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom, isNarrowCanvasCalibrated
    global userCanvasLeft, userCanvasTop, userCanvasRight, userCanvasBottom, isCanvasCalibrated
    global hotkeyRecordToggle, hotkeySubmit, hotkeyDirectClear, hotkeyStats, hotkeyBreakMode
    global hotkeySettings, hotkeyLayerPrev, hotkeyLayerNext, hotkeyProfileActive, wasdLabelsEnabled
    global corpVisualizationMethod, corporateEnvironmentDetected
    global layerNames, layerBorderColors
    global boxDrawDelay, mouseClickDelay, menuClickDelay, mouseDragDelay, mouseReleaseDelay
    global betweenBoxDelay, keyPressDelay, focusDelay, mouseHoverDelay
    global smartBoxClickDelay, smartMenuClickDelay
    global macroEvents, buttonNames, buttonCustomLabels
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
        content .= "currentLayer=" . currentLayer . "`n"
        content .= "totalLayers=" . totalLayers . "`n"
        content .= "annotationMode=" . annotationMode . "`n"
        content .= "darkMode=" . (darkMode ? "true" : "false") . "`n"
        content .= "windowWidth=" . windowWidth . "`n"
        content .= "windowHeight=" . windowHeight . "`n"
        content .= "scaleFactor=" . scaleFactor . "`n"
        content .= "minWindowWidth=" . minWindowWidth . "`n"
        content .= "minWindowHeight=" . minWindowHeight . "`n"
        settingsSaved += 9

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
        content .= "hotkeyLayerPrev=" . hotkeyLayerPrev . "`n"
        content .= "hotkeyLayerNext=" . hotkeyLayerNext . "`n"
        settingsSaved += 8

        ; WASD settings
        content .= "hotkeyProfileActive=" . (hotkeyProfileActive ? "true" : "false") . "`n"
        content .= "wasdLabelsEnabled=" . (wasdLabelsEnabled ? "true" : "false") . "`n"
        settingsSaved += 2

        ; Visualization settings
        content .= "corpVisualizationMethod=" . corpVisualizationMethod . "`n"
        content .= "corporateEnvironmentDetected=" . (corporateEnvironmentDetected ? "true" : "false") . "`n"
        content .= "visualizationSavePath=" . visualizationSavePath . "`n"
        settingsSaved += 3

        ; Layer settings
        Loop Integer(totalLayers) {
            i := A_Index
            content .= "layerName" . i . "=" . layerNames[i] . "`n"
            content .= "layerBorderColor" . i . "=" . layerBorderColors[i] . "`n"
        }
        settingsSaved += totalLayers * 2

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

        ; Macros section
        content .= "`n[Macros]`n"
        Loop Integer(totalLayers) {
            layer := A_Index
            for buttonName in buttonNames {
                layerMacroName := "L" . layer . "_" . buttonName
                if (macroEvents.Has(layerMacroName) && macroEvents[layerMacroName].Length > 0) {
                    events := macroEvents[layerMacroName]
                    eventString := ""
                    for i, event in events {
                        if (i > 1) {
                            eventString .= "|"
                        }
                        if (event.type = "boundingBox") {
                            eventString .= "boundingBox," . event.left . "," . event.top . "," . event.right . "," . event.bottom
                            ; Include degradationType for stats tracking
                            if (event.HasOwnProp("degradationType")) {
                                eventString .= "," . event.degradationType
                            } else {
                                eventString .= ",1"  ; Default to smudge (1) if not set
                            }
                        } else if (event.type = "jsonAnnotation") {
                            eventString .= "jsonAnnotation," . event.mode . "," . event.categoryId . "," . event.severity
                        } else if (event.type = "keyDown") {
                            eventString .= "keyDown," . event.key
                        } else if (event.type = "keyUp") {
                            eventString .= "keyUp," . event.key
                        }
                    }
                    content .= layerMacroName . "=" . eventString . "`n"

                    ; Save recordedMode property if it exists (critical for letterboxing persistence)
                    if (events.HasOwnProp("recordedMode")) {
                        content .= layerMacroName . "_RecordedMode=" . events.recordedMode . "`n"
                    }

                    macrosSaved++
                }
            }
        }

        ; Labels section
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

        ; Write to file with verification
        try {
            ; Write to temp file first for atomic save
            tempFile := configFile . ".tmp"
            file := FileOpen(tempFile, "w", "UTF-8")
            if (!file) {
                throw Error("Failed to open temp file for writing: " . tempFile)
            }
            file.Write(content)
            file.Close()

            ; Verify temp file was written
            if (!FileExist(tempFile)) {
                throw Error("Temp file was not created: " . tempFile)
            }

            ; Atomic replace: backup old config, move temp to config
            if (FileExist(configFile)) {
                backupFile := configFile . ".backup"
                try {
                    FileDelete(backupFile)
                } catch {
                    ; Ignore if backup doesn't exist
                }
                FileCopy(configFile, backupFile, 1)
            }

            FileMove(tempFile, configFile, 1)

            ; Verify final file
            if (!FileExist(configFile)) {
                throw Error("Config file was not created after move: " . configFile)
            }

            UpdateStatus("💾 Saved")

            ; Log successful save
            try {
                logFile := workDir . "\save_log.txt"
                logContent := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . " - Config saved: " . macrosSaved . " macros, " . settingsSaved . " settings`n"
                FileAppend(logContent, logFile, "UTF-8")
            } catch {
                ; Ignore logging errors
            }

        } catch Error as writeError {
            UpdateStatus("❌ Save error: " . writeError.Message)
            throw writeError  ; Re-throw to catch in outer handler
        }

    } catch Error as e {
        UpdateStatus("❌ Save failed: " . e.Message)
        ; Log critical save failure
        try {
            logFile := workDir . "\save_log.txt"
            logContent := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . " - SAVE FAILED: " . e.Message . "`n"
            FileAppend(logContent, logFile, "UTF-8")
        } catch {
            ; Can't even log - show message box
            MsgBox("CRITICAL: Failed to save configuration and couldn't write to log!`n`nError: " . e.Message, "Save Error", "Icon!")
        }
        throw e  ; Re-throw so caller knows save failed
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

        ; Validate config content
        if (!ValidateConfigData(content)) {
            UpdateStatus("⚠️ Config validation failed - using defaults")
            return
        }
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
                            case "currentLayer": currentLayer := EnsureInteger(value, 1)
                            case "totalLayers": totalLayers := EnsureInteger(value, 5)
                            case "annotationMode": annotationMode := value
                            case "darkMode": darkMode := (value = "true")
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
                            case "hotkeyLayerPrev": hotkeyLayerPrev := value
                            case "hotkeyLayerNext": hotkeyLayerNext := value
                            case "hotkeyProfileActive": hotkeyProfileActive := (value = "true")
                            case "wasdLabelsEnabled": wasdLabelsEnabled := (value = "true")
                            case "corpVisualizationMethod": corpVisualizationMethod := EnsureInteger(value, 1)
                            case "corporateEnvironmentDetected": corporateEnvironmentDetected := (value = "true")
                            case "visualizationSavePath": visualizationSavePath := value
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
                            case "layerName1": layerNames[1] := value
                            case "layerName2": layerNames[2] := value
                            case "layerName3": layerNames[3] := value
                            case "layerName4": layerNames[4] := value
                            case "layerName5": layerNames[5] := value
                            case "layerName6": layerNames[6] := value
                            case "layerName7": layerNames[7] := value
                            case "layerName8": layerNames[8] := value
                            case "layerName9": layerNames[9] := value
                            case "layerName10": layerNames[10] := value
                            case "layerBorderColor1": layerBorderColors[1] := value
                            case "layerBorderColor2": layerBorderColors[2] := value
                            case "layerBorderColor3": layerBorderColors[3] := value
                            case "layerBorderColor4": layerBorderColors[4] := value
                            case "layerBorderColor5": layerBorderColors[5] := value
                            case "layerBorderColor6": layerBorderColors[6] := value
                            case "layerBorderColor7": layerBorderColors[7] := value
                            case "layerBorderColor8": layerBorderColors[8] := value
                            case "layerBorderColor9": layerBorderColors[9] := value
                            case "layerBorderColor10": layerBorderColors[10] := value
                        }

                    case "Macros":
                        ; Check if this is a recordedMode property
                        if (InStr(key, "_RecordedMode")) {
                            ; Extract the macro name (remove "_RecordedMode" suffix)
                            macroName := StrReplace(key, "_RecordedMode", "")
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

        ; VALIDATE LOADED CANVAS VALUES - ensure they are valid to prevent visualization failures
        try {
            ValidateAndFixCanvasValues()
            ; Sync canvas state from legacy globals
            Canvas_SyncFromLegacyGlobals()
        } catch Error as canvasError {
            UpdateStatus("⚠️ Canvas validation failed")
            throw canvasError
        }

        UpdateStatus("📚 Loaded")

        ; DEFER GUI settings application until GUI is confirmed ready
        ; ApplyLoadedSettingsToGUI() will be called separately after GUI initialization

    } catch Error as e {
        UpdateStatus("❌ Load failed: " . e.Message)
        throw e  ; Re-throw to catch in Main()
    }
}

; ===== APPLY SETTINGS TO GUI =====
ApplyLoadedSettingsToGUI() {
    ; Apply loaded settings to GUI controls after initialization
    global wasdLabelsEnabled, annotationMode, modeToggleBtn

    try {
        ; CRITICAL: Update mode toggle button text to match loaded state
        if (modeToggleBtn) {
            if (annotationMode = "Wide") {
                modeToggleBtn.Text := "🔦 Wide"
            } else {
                modeToggleBtn.Text := "📱 Narrow"
            }
        }

        ; Update button labels with WASD if enabled
        if (wasdLabelsEnabled) {
            UpdateButtonLabelsWithWASD()
        }

        ; Refresh all button appearances
        RefreshAllButtonAppearances()

        ; Settings applied silently
    } catch Error as e {
        UpdateStatus("⚠️ GUI settings error: " . e.Message)
    }
}

; ===== EMERGENCY CONFIG REPAIR =====
RepairConfigSystem() {
    global configFile, workDir

    result := MsgBox("⚠️ EMERGENCY CONFIG REPAIR`n`nThis will:`n• Remove stuck lock files`n• Delete old config files`n• Rebuild config from memory`n• Create fresh backup`n`nContinue?", "Repair Config", "YesNo Icon!")

    if (result = "No") {
        return
    }

    try {
        ; Remove lock file
        lockFile := workDir . "\config.lock"
        if (FileExist(lockFile)) {
            FileDelete(lockFile)
        }

        ; Delete old config files
        CleanupOldConfigFiles()

        ; Create fresh backup of current config
        if (FileExist(configFile)) {
            backupFile := configFile . ".pre-repair." . FormatTime(A_Now, "yyyyMMdd_HHmmss")
            FileCopy(configFile, backupFile, 0)
        }

        ; Force save current state
        SaveConfig()
        UpdateStatus("✅ Config system repaired")

        ; Verify
        if (FileExist(configFile)) {
            content := FileRead(configFile, "UTF-8")
            if (ValidateConfigData(content)) {
                MsgBox("✅ Config system repaired successfully!`n`nYour configuration has been rebuilt and validated.", "Repair Complete", "Icon!")
            } else {
                MsgBox("⚠️ Config was rebuilt but validation failed.`n`nCheck the diagnostics for details.", "Repair Warning", "Icon!")
            }
        } else {
            MsgBox("❌ Config repair failed!`n`nFile was not created.", "Repair Failed", "Icon!")
        }

    } catch Error as e {
        MsgBox("❌ Repair failed!`n`n" . e.Message, "Repair Error", "Icon!")
    }
}

; ===== INITIALIZATION =====
InitializeConfigSystem() {
    global workDir, configFile

    InitConfigLock()
    VerifyConfigPaths()

    ; Clean up any stuck locks from previous crashes
    lockFile := workDir . "\config.lock"
    if (FileExist(lockFile)) {
        try {
            FileDelete(lockFile)
        } catch {
            ; Ignore
        }
    }
}

SetupConfigTestHotkeys() {
    ; F10 - Diagnostics
    Hotkey("F10", (*) => DiagnoseConfigSystem())

    ; F11 - Test Save/Load
    Hotkey("F11", (*) => TestConfigSystem())

    ; Ctrl+Shift+F12 - Emergency Repair
    Hotkey("^+F12", (*) => RepairConfigSystem())
}

; ===== HELPER FUNCTIONS =====
InitConfigLock() {
    ; Placeholder - implement as needed
}

CleanupOldConfigFiles() {
    ; Placeholder - implement as needed
}

VerifyConfigPaths() {
    ; Placeholder - implement as needed
}

ValidateConfigData(content) {
    ; Basic validation of config content
    try {
        ; Check for required sections
        hasSettings := InStr(content, "[Settings]") > 0
        hasMacros := InStr(content, "[Macros]") > 0

        ; Check for basic structure
        if (!hasSettings && !hasMacros) {
            return false
        }

        ; Check for reasonable content length
        if (StrLen(content) < 10) {
            return false
        }

        ; Check for balanced brackets
        openBrackets := 0
        closeBrackets := 0
        for char in StrSplit(content) {
            if (char = "[") {
                openBrackets++
            } else if (char = "]") {
                closeBrackets++
            }
        }
        if (openBrackets != closeBrackets) {
            return false
        }

        return true
    } catch {
        return false
    }
}
