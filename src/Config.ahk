; ===== PROCESSING FUNCTIONS =====
ProcessLayerColor(key, value) {
    global layerBorderColors

    if (RegExMatch(key, "Layer(\d+)", &match)) {
        layerIndex := Integer(match[1])
        if (layerIndex >= 1 && layerIndex <= layerBorderColors.Length) {
            layerBorderColors[layerIndex] := value
        }
    }
}

ProcessButtonAutoSetting(key, value) {
    global buttonAutoSettings

    parts := StrSplit(value, ",")
    if (parts.Length >= 3) {
        buttonAutoSettings[key] := {
            enabled: (parts[1] = "1"),
            interval: Integer(parts[2]),
            maxCount: Integer(parts[3])
        }
    }
}

ProcessCustomLabel(key, value) {
    global buttonCustomLabels

    if (buttonCustomLabels.Has(key)) {
        buttonCustomLabels[key] := value
    }
}

ProcessMacroLine(key, value) {
    global macroEvents

    if (value = "") {
        return false
    }

    ; Initialize macro events array
    if (!macroEvents.Has(key)) {
        macroEvents[key] := []
    }

    ; Parse event string
    eventStrings := StrSplit(value, "|")

    for eventStr in eventStrings {
        parts := StrSplit(eventStr, ",")
        if (parts.Length = 0)
            continue

        eventType := parts[1]
        event := {type: eventType}

        ; Parse different event types
        validEvent := false
        switch eventType {
            case "boundingBox":
                if (parts.Length >= 5) {
                    event.left := EnsureInteger(parts[2], 0)
                    event.top := EnsureInteger(parts[3], 0)
                    event.right := EnsureInteger(parts[4], 0)
                    event.bottom := EnsureInteger(parts[5], 0)
                    ; Load degradationType for stats tracking (added after isTagged field)
                    if (parts.Length >= 6) {
                        ; Check if part 6 is degradationType (number 1-9) or isTagged (0/1)
                        part6Value := EnsureInteger(parts[6], 1)
                        if (part6Value >= 1 && part6Value <= 9) {
                            event.degradationType := part6Value
                        } else {
                            event.isTagged := (parts[6] = "1")
                            event.degradationType := 1  ; Default to smudge
                        }
                    } else {
                        event.degradationType := 1  ; Default to smudge if not saved
                    }
                    validEvent := true
                }

            case "jsonAnnotation":
                if (parts.Length >= 4) {
                    event.mode := parts[2]
                    event.categoryId := EnsureInteger(parts[3], 1)
                    event.severity := parts[4]
                    if (parts.Length >= 5) {
                        event.isTagged := (parts[5] = "1")
                    }
                    validEvent := true
                }

            case "keyDown", "keyUp":
                if (parts.Length >= 2) {
                    event.key := parts[2]
                    validEvent := true
                }

            case "mouseDown", "mouseUp":
                if (parts.Length >= 4) {
                    event.x := EnsureInteger(parts[2], 0)
                    event.y := EnsureInteger(parts[3], 0)
                    event.button := parts[4]
                    validEvent := true
                }

            default:
                ; Generic event with optional x,y
                if (parts.Length >= 2) {
                    event.x := EnsureInteger(parts[2], 0)
                }
                if (parts.Length >= 3) {
                    event.y := EnsureInteger(parts[3], 0)
                }
                validEvent := true
        }

        if (validEvent) {
            macroEvents[key].Push(event)
        }
    }

    return macroEvents[key].Length > 0
}


; ===== GLOBAL CONFIGURATION VARIABLES =====

; Core application state
global currentLayer := 1
global totalLayers := 5
global annotationMode := "Wide"
global darkMode := true

; Window settings
global windowWidth := 1200
global windowHeight := 800
global scaleFactor := 1.0
global minWindowWidth := 900
global minWindowHeight := 600

; Canvas settings
global canvasWidth := 1920
global canvasHeight := 1080
global canvasType := "Wide"
global canvasAspectRatio := 1.777
global isCanvasCalibrated := false
global isWideCanvasCalibrated := false
global isNarrowCanvasCalibrated := false

; Canvas coordinates
global wideCanvasLeft := 0
global wideCanvasTop := 0
global wideCanvasRight := 1920
global wideCanvasBottom := 1080

global narrowCanvasLeft := 240
global narrowCanvasTop := 0
global narrowCanvasRight := 1680
global narrowCanvasBottom := 1080

global userCanvasLeft := 0
global userCanvasTop := 0
global userCanvasRight := 1920
global userCanvasBottom := 1080

; Hotkey settings
global hotkeyRecordToggle := "F9"
global hotkeySubmit := "+Enter"
global hotkeyDirectClear := "NumpadEnter"
global hotkeyStats := ""
global hotkeyBreakMode := "^b"
global hotkeySettings := ""
global hotkeyLayerPrev := "NumpadDiv"
global hotkeyLayerNext := "NumpadSub"

; WASD settings
global hotkeyProfileActive := false
global wasdLabelsEnabled := false

; Visualization settings
global corpVisualizationMethod := 1
global corporateEnvironmentDetected := false

; Auto execution settings
global autoExecutionMode := false
global autoExecutionButton := ""
global autoExecutionInterval := 5000
global autoExecutionMaxCount := 0

; Layer settings
global layerNames := ["Layer 1", "Layer 2", "Layer 3", "Layer 4", "Layer 5"]
global layerBorderColors := ["0x404040", "0x505050", "0x606060", "0x707070", "0x808080"]

; Timing settings
global boxDrawDelay := 75
global mouseClickDelay := 85
global menuClickDelay := 150
global mouseDragDelay := 90

; ===== INTELLIGENT TIMING SYSTEM - UNIQUE DELAYS =====
global smartBoxClickDelay := 35    ; Optimized for fast box drawing in intelligent system
global smartMenuClickDelay := 120  ; Optimized for accurate menu selections in intelligent system
global mouseReleaseDelay := 90
global betweenBoxDelay := 200
global keyPressDelay := 20
global focusDelay := 80
global mouseHoverDelay := 35

; Macro and button data
global macroEvents := Map()
global buttonNames := ["Num7", "Num8", "Num9", "Num4", "Num5", "Num6", "Num1", "Num2", "Num3", "Num0", "NumDot", "NumMult"]
global buttonCustomLabels := Map()
global buttonAutoSettings := Map()


; ===== CONFIG DIAGNOSTICS =====
DiagnoseConfigSystem() {
    global configFile, workDir, macroEvents, buttonNames, totalLayers
    
    diagnostic := "🔍 CONFIG SYSTEM DIAGNOSTICS`n"
    diagnostic .= "═══════════════════════════════════════`n`n"
    
    ; File paths
    diagnostic .= "📁 PATHS:`n"
    diagnostic .= "Work Directory: " . workDir . "`n"
    diagnostic .= "Config File: " . configFile . "`n"
    diagnostic .= "Config Exists: " . (FileExist(configFile) ? "✅ YES" : "❌ NO") . "`n"
    
    if (FileExist(configFile)) {
        fileSize := FileGetSize(configFile)
        diagnostic .= "File Size: " . fileSize . " bytes`n"
        
        ; Check backup
        backupFile := configFile . ".backup"
        diagnostic .= "Backup Exists: " . (FileExist(backupFile) ? "✅ YES" : "❌ NO") . "`n"
        
        ; Read and validate
        try {
            content := FileRead(configFile, "UTF-8")
            diagnostic .= "Read Status: ✅ SUCCESS`n"
            diagnostic .= "Content Length: " . StrLen(content) . " chars`n"
            diagnostic .= "Has [Settings]: " . (InStr(content, "[Settings]") ? "✅" : "❌") . "`n"
            diagnostic .= "Has [Macros]: " . (InStr(content, "[Macros]") ? "✅" : "❌") . "`n"
        } catch Error as e {
            diagnostic .= "Read Status: ❌ FAILED - " . e.Message . "`n"
        }
    }
    
    diagnostic .= "`n📊 IN-MEMORY STATE:`n"
    
    ; Count macros
    macroCount := 0
    Loop Integer(totalLayers) {
        layer := A_Index
        for buttonName in buttonNames {
            layerMacroName := "L" . layer . "_" . buttonName
            if (macroEvents.Has(layerMacroName) && macroEvents[layerMacroName].Length > 0) {
                macroCount++
            }
        }
    }
    
    diagnostic .= "Macros in Memory: " . macroCount . "`n"
    diagnostic .= "Current Layer: " . currentLayer . "`n"
    diagnostic .= "Total Layers: " . totalLayers . "`n"
    
    ; Lock status
    lockFile := workDir . "\config.lock"
    diagnostic .= "`n🔒 LOCK STATUS:`n"
    diagnostic .= "Lock File Exists: " . (FileExist(lockFile) ? "⚠️ YES (may be stuck)" : "✅ NO") . "`n"
    
    ; Old config files
    diagnostic .= "`n🗑️ OLD FILES:`n"
    oldPaths := [
        A_MyDocuments . "\config.ini",
        A_MyDocuments . "\MacroLauncherX44\config.ini",
        workDir . "\..\config.ini"
    ]
    
    oldFound := false
    for oldPath in oldPaths {
        if (FileExist(oldPath)) {
            diagnostic .= "⚠️ FOUND: " . oldPath . "`n"
            oldFound := true
        }
    }
    
    if (!oldFound) {
        diagnostic .= "✅ No old config files found`n"
    }
    
    diagnostic .= "`n═══════════════════════════════════════`n"
    diagnostic .= "💡 RECOMMENDATIONS:`n"
    
    if (!FileExist(configFile)) {
        diagnostic .= "❌ Config file missing - will create on next save`n"
    }
    
    if (FileExist(lockFile)) {
        diagnostic .= "⚠️ Remove stuck lock file and restart`n"
    }
    
    if (oldFound) {
        diagnostic .= "⚠️ Delete old config files to prevent conflicts`n"
    }
    
    if (macroCount = 0 && FileExist(configFile)) {
        diagnostic .= "⚠️ Config exists but no macros loaded - check file format`n"
    }
    
    ; Show results
    result := MsgBox(diagnostic, "Config System Diagnostics", "OKCancel Icon!")
    
    if (result = "Cancel") {
        ; Copy to clipboard
        A_Clipboard := diagnostic
        UpdateStatus("📋 Diagnostics copied to clipboard")
    }
}

; ===== FORCED SAVE/LOAD TEST =====
TestConfigSystem() {
    global macroEvents, buttonNames, currentLayer, totalLayers
    
    ; Step 1: Count current macros
    originalCount := 0
    Loop Integer(totalLayers) {
        layer := A_Index
        for buttonName in buttonNames {
            layerMacroName := "L" . layer . "_" . buttonName
            if (macroEvents.Has(layerMacroName) && macroEvents[layerMacroName].Length > 0) {
                originalCount++
            }
        }
    }

    ; Step 2: Force save
    try {
        SaveConfig()
    } catch Error as e {
        MsgBox("Save test FAILED!`n`n" . e.Message, "Test Failed", "Icon!")
        return
    }
    
    Sleep(500)
    
    ; Step 3: Backup in-memory data
    backupEvents := Map()
    Loop Integer(totalLayers) {
        layer := A_Index
        for buttonName in buttonNames {
            layerMacroName := "L" . layer . "_" . buttonName
            if (macroEvents.Has(layerMacroName)) {
                backupEvents[layerMacroName] := macroEvents[layerMacroName].Clone()
            }
        }
    }
    
    ; Step 4: Clear in-memory data
    Loop Integer(totalLayers) {
        layer := A_Index
        for buttonName in buttonNames {
            layerMacroName := "L" . layer . "_" . buttonName
            if (macroEvents.Has(layerMacroName)) {
                macroEvents.Delete(layerMacroName)
            }
        }
    }

    RefreshAllButtonAppearances()

    Sleep(500)

    ; Step 5: Force load
    try {
        LoadConfig()
    } catch Error as e {
        MsgBox("Load test FAILED!`n`n" . e.Message, "Test Failed", "Icon!")
        return
    }
    
    Sleep(500)
    
    ; Step 6: Count loaded macros
    loadedCount := 0
    Loop Integer(totalLayers) {
        layer := A_Index
        for buttonName in buttonNames {
            layerMacroName := "L" . layer . "_" . buttonName
            if (macroEvents.Has(layerMacroName) && macroEvents[layerMacroName].Length > 0) {
                loadedCount++
            }
        }
    }
    
    RefreshAllButtonAppearances()
    
    ; Step 7: Report results
    testResult := "CONFIG SYSTEM TEST RESULTS`n"
    testResult .= "═══════════════════════════`n`n"
    testResult .= "Original Macros: " . originalCount . "`n"
    testResult .= "Loaded Macros: " . loadedCount . "`n`n"
    
    if (loadedCount = originalCount) {
        testResult .= "✅ TEST PASSED!`n`n"
        testResult .= "All macros were successfully saved and restored."
    } else {
        testResult .= "❌ TEST FAILED!`n`n"
        testResult .= "Macro count mismatch!`n"
        testResult .= "Data loss: " . (originalCount - loadedCount) . " macros`n`n"
        testResult .= "Run diagnostics for more details."
    }
    
    MsgBox(testResult, "Config Test Complete", "Icon!")
    UpdateStatus("🔬 Config test complete: " . loadedCount . "/" . originalCount . " macros")
}

LoadWASDMappingsFromFile() {
    ; Placeholder - implement as needed
}

; ===== VALIDATE LOADED CANVAS VALUES =====
ValidateLoadedCanvasValues() {
    global wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom, isWideCanvasCalibrated
    global narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom, isNarrowCanvasCalibrated
    global userCanvasLeft, userCanvasTop, userCanvasRight, userCanvasBottom, isCanvasCalibrated
    global hbitmapCache

    ; Track if any canvas values were reset
    canvasReset := false

    ; Validate wide canvas
    if (!IsNumber(wideCanvasLeft) || !IsNumber(wideCanvasTop) || !IsNumber(wideCanvasRight) || !IsNumber(wideCanvasBottom) ||
        wideCanvasRight <= wideCanvasLeft || wideCanvasBottom <= wideCanvasTop) {
        wideCanvasLeft := 0
        wideCanvasTop := 0
        wideCanvasRight := 1920
        wideCanvasBottom := 1080
        isWideCanvasCalibrated := false
        canvasReset := true
    }

    ; Validate narrow canvas
    if (!IsNumber(narrowCanvasLeft) || !IsNumber(narrowCanvasTop) || !IsNumber(narrowCanvasRight) || !IsNumber(narrowCanvasBottom) ||
        narrowCanvasRight <= narrowCanvasLeft || narrowCanvasBottom <= narrowCanvasTop) {
        narrowCanvasLeft := 240
        narrowCanvasTop := 0
        narrowCanvasRight := 1680
        narrowCanvasBottom := 1080
        isNarrowCanvasCalibrated := false
        canvasReset := true
    }

    ; Validate user canvas
    if (!IsNumber(userCanvasLeft) || !IsNumber(userCanvasTop) || !IsNumber(userCanvasRight) || !IsNumber(userCanvasBottom) ||
        userCanvasRight <= userCanvasLeft || userCanvasBottom <= userCanvasTop) {
        userCanvasLeft := 0
        userCanvasTop := 0
        userCanvasRight := 1920
        userCanvasBottom := 1080
        isCanvasCalibrated := false
        canvasReset := true
    }

    ; If any canvas values were reset, clear the HBITMAP cache since cached visualizations may be invalid
    if (canvasReset && IsObject(hbitmapCache)) {
        for cacheKey, hbitmap in hbitmapCache {
            if (hbitmap && hbitmap != 0) {
                try {
                    DllCall("DeleteObject", "Ptr", hbitmap)
                } catch {
                    ; Ignore cleanup errors
                }
            }
        }
        hbitmapCache := Map()
    }
}

; ===== CANVAS VALIDATION =====
ValidateAndFixCanvasValues() {
    global wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom, isWideCanvasCalibrated
    global narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom, isNarrowCanvasCalibrated
    global userCanvasLeft, userCanvasTop, userCanvasRight, userCanvasBottom, isCanvasCalibrated
    global hbitmapCache

    ; Track if any canvas values were reset
    canvasReset := false

    ; Validate wide canvas
    if (!IsNumber(wideCanvasLeft) || !IsNumber(wideCanvasTop) || !IsNumber(wideCanvasRight) || !IsNumber(wideCanvasBottom) ||
        wideCanvasRight <= wideCanvasLeft || wideCanvasBottom <= wideCanvasTop) {
        wideCanvasLeft := 0
        wideCanvasTop := 0
        wideCanvasRight := 1920
        wideCanvasBottom := 1080
        isWideCanvasCalibrated := false
        canvasReset := true
    }

    ; Validate narrow canvas
    if (!IsNumber(narrowCanvasLeft) || !IsNumber(narrowCanvasTop) || !IsNumber(narrowCanvasRight) || !IsNumber(narrowCanvasBottom) ||
        narrowCanvasRight <= narrowCanvasLeft || narrowCanvasBottom <= narrowCanvasTop) {
        narrowCanvasLeft := 240
        narrowCanvasTop := 0
        narrowCanvasRight := 1680
        narrowCanvasBottom := 1080
        isNarrowCanvasCalibrated := false
        canvasReset := true
    }

    ; Validate user canvas
    if (!IsNumber(userCanvasLeft) || !IsNumber(userCanvasTop) || !IsNumber(userCanvasRight) || !IsNumber(userCanvasBottom) ||
        userCanvasRight <= userCanvasLeft || userCanvasBottom <= userCanvasTop) {
        userCanvasLeft := 0
        userCanvasTop := 0
        userCanvasRight := 1920
        userCanvasBottom := 1080
        isCanvasCalibrated := false
        canvasReset := true
    }

    ; If any canvas values were reset, clear the HBITMAP cache since cached visualizations may be invalid
    if (canvasReset && IsObject(hbitmapCache)) {
        for cacheKey, hbitmap in hbitmapCache {
            if (hbitmap && hbitmap != 0) {
                try {
                    DllCall("DeleteObject", "Ptr", hbitmap)
                } catch {
                    ; Ignore cleanup errors
                }
            }
        }
        hbitmapCache := Map()
    }

    if (canvasReset) {
        UpdateStatus("⚠️ Canvas values were reset")
    }
}