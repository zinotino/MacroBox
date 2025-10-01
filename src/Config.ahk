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
                    if (parts.Length >= 6) {
                        event.isTagged := (parts[6] = "1")
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
global autoExecutionInterval := 2000
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
global buttonNames := ["Num0", "Num1", "Num2", "Num3", "Num4", "Num5", "Num6", "Num7", "Num8", "Num9", "NumDot", "NumMult"]
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
    
    UpdateStatus("🔬 Starting config system test...")
    
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
    
    UpdateStatus("🔬 Original macro count: " . originalCount)
    
    ; Step 2: Force save
    try {
        SaveConfig()
        UpdateStatus("✅ Save completed")
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
    UpdateStatus("🗑️ Cleared in-memory macros")
    
    Sleep(500)
    
    ; Step 5: Force load
    try {
        LoadConfig()
        UpdateStatus("✅ Load completed")
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
            UpdateStatus("🔓 Removed stuck lock file")
        }
        
        ; Delete old config files
        CleanupOldConfigFiles()
        
        ; Create fresh backup of current config
        if (FileExist(configFile)) {
            backupFile := configFile . ".pre-repair." . FormatTime(A_Now, "yyyyMMdd_HHmmss")
            FileCopy(configFile, backupFile, 0)
            UpdateStatus("💾 Created pre-repair backup")
        }
        
        ; Force save current state
        SaveConfig()
        UpdateStatus("✅ Rebuilt config from memory")
        
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


; ===== QUICK SAVE/LOAD SLOTS =====
SaveToSlot(slotNumber) {
    global workDir, configFile
    
    try {
        SaveConfig()
        
        slotDir := workDir . "\slots\slot_" . slotNumber
        if !DirExist(slotDir) {
            DirCreate(slotDir)
        }
        
        ; Copy current config to slot
        FileCopy(configFile, slotDir . "\config.ini", true)
        
        ; Save slot info
        slotInfo := "Slot " . slotNumber . " - Saved: " . FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        FileAppend(slotInfo, slotDir . "\slot_info.txt")
        
        UpdateStatus("💾 Saved to slot " . slotNumber)
        
    } catch Error as e {
        UpdateStatus("⚠️ Save to slot failed: " . e.Message)
    }
}

LoadFromSlot(slotNumber) {
    global workDir, configFile, buttonNames
    
    try {
        slotDir := workDir . "\slots\slot_" . slotNumber
        
        if (!DirExist(slotDir) || !FileExist(slotDir . "\config.ini")) {
            UpdateStatus("⚠️ Slot " . slotNumber . " is empty")
            return false
        }
        
        ; Copy slot config to current
        FileCopy(slotDir . "\config.ini", configFile, true)
        
        LoadConfig()
        
        ; Refresh UI
        for buttonName in buttonNames {
            UpdateButtonAppearance(buttonName)
        }
        SwitchLayer("")
        
        UpdateStatus("📂 Loaded from slot " . slotNumber)
        return true
        
    } catch Error as e {
        UpdateStatus("⚠️ Load from slot failed: " . e.Message)
        return false
    }
}

; ===== EXPORT/IMPORT CONFIGURATION =====
ExportConfiguration() {
    global configFile, workDir
    
    try {
        ; Create export filename with timestamp
        exportFile := FileSelect("S", workDir . "\MacroConfig_Export_" . FormatTime(A_Now, "yyyyMMdd_HHmmss") . ".ini", "Export Configuration", "Config Files (*.ini)")
        
        if (exportFile = "") {
            return ; User cancelled
        }
        
        ; Ensure .ini extension
        if (!InStr(exportFile, ".ini")) {
            exportFile .= ".ini"
        }
        
        ; Copy current config to export location
        FileCopy(configFile, exportFile, 1)
        
        MsgBox("✅ Configuration exported successfully!`n`nFile: " . exportFile, "Export Complete", "Icon!")
        UpdateStatus("📤 Configuration exported")
        
    } catch Error as e {
        MsgBox("❌ Export failed: " . e.Message, "Export Error", "Icon!")
        UpdateStatus("⚠️ Export failed: " . e.Message)
    }
}

ImportConfiguration() {
    global configFile, workDir
    
    try {
        ; Select file to import
        importFile := FileSelect("3", workDir, "Import Configuration", "Config Files (*.ini)")
        
        if (importFile = "") {
            return ; User cancelled
        }
        
        ; Confirm import
        result := MsgBox("Import configuration from:`n`n" . importFile . "`n`nThis will replace your current configuration!`n`nContinue?", "Confirm Import", "YesNo Icon!")
        
        if (result != "Yes") {
            return
        }
        
        ; Backup current config
        backupFile := configFile . ".pre-import." . FormatTime(A_Now, "yyyyMMdd_HHmmss")
        FileCopy(configFile, backupFile, 0)
        
        ; Import new config
        FileCopy(importFile, configFile, 1)
        
        ; Load new config
        LoadConfig()
        RefreshAllButtonAppearances()
        
        MsgBox("✅ Configuration imported successfully!`n`nBackup saved to:`n" . backupFile, "Import Complete", "Icon!")
        UpdateStatus("📥 Configuration imported")
        
    } catch Error as e {
        MsgBox("❌ Import failed: " . e.Message, "Import Error", "Icon!")
        UpdateStatus("⚠️ Import failed: " . e.Message)
    }
}

; ===== MACRO PACK MANAGEMENT =====
CreateMacroPack() {
    global macroEvents, buttonNames, buttonCustomLabels, buttonAutoSettings, currentLayer, totalLayers, workDir
    
    try {
        ; Prompt for pack name
        packName := InputBox("Enter a name for your macro pack:", "Create Macro Pack", "w300 h150")
        
        if (packName.Result != "OK" || packName.Value = "") {
            return
        }
        
        ; Create pack directory
        packDir := workDir . "\packs\" . RegExReplace(packName.Value, "[^\w\s-]", "") ; Sanitize filename
        if (!DirExist(packDir)) {
            DirCreate(packDir)
        }
        
        ; Create pack metadata
        packInfo := "{"
        packInfo .= '`n  "name": "' . packName.Value . '",'
        packInfo .= '`n  "created": "' . FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . '",'
        packInfo .= '`n  "version": "1.0",'
        
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
        
        packInfo .= '`n  "macros": ' . macroCount
        packInfo .= '`n}'
        
        ; Save pack metadata
        FileAppend(packInfo, packDir . "\pack.json", "UTF-8")
        
        ; Save macros to pack
        macrosContent := "; Macro Pack: " . packName.Value . "`n`n"
        macrosContent .= "[Macros]`n"
        
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
                        } else if (event.type = "jsonAnnotation") {
                            eventString .= "jsonAnnotation," . event.mode . "," . event.categoryId . "," . event.severity
                        } else if (event.type = "keyDown") {
                            eventString .= "keyDown," . event.key
                        } else if (event.type = "keyUp") {
                            eventString .= "keyUp," . event.key
                        }
                    }
                    
                    macrosContent .= layerMacroName . "=" . eventString . "`n"
                }
            }
        }
        
        ; Add custom labels
        macrosContent .= "`n[Labels]`n"
        for buttonName, label in buttonCustomLabels {
            if (label != "") {
                macrosContent .= buttonName . "=" . label . "`n"
            }
        }
        
        ; Add auto settings
        macrosContent .= "`n[AutoSettings]`n"
        for buttonKey, settings in buttonAutoSettings {
            if (settings.enabled) {
                macrosContent .= buttonKey . "=" . (settings.enabled ? "1" : "0") . "," . settings.interval . "," . settings.maxCount . "`n"
            }
        }
        
        FileAppend(macrosContent, packDir . "\macros.ini", "UTF-8")
        
        MsgBox("✅ Macro pack created successfully!`n`nPack: " . packName.Value . "`nMacros: " . macroCount . "`n`nLocation: " . packDir, "Pack Created", "Icon!")
        UpdateStatus("📦 Created macro pack: " . packName.Value)
        
    } catch Error as e {
        MsgBox("❌ Failed to create macro pack: " . e.Message, "Pack Error", "Icon!")
        UpdateStatus("⚠️ Pack creation failed: " . e.Message)
    }
}

ImportMacroPack() {
    global macroEvents, buttonNames, buttonCustomLabels, buttonAutoSettings, workDir
    
    try {
        ; File selection dialog for pack.json
        selectedFile := FileSelect("3", workDir . "\packs", "Select Macro Pack to Import", "JSON files (*.json)")
        
        if (selectedFile = "") {
            return ; User cancelled
        }
        
        ; Validate that it's a pack.json file
        if (!InStr(selectedFile, "pack.json")) {
            MsgBox("Please select a valid pack.json file from a macro pack folder.", "Invalid File", "Icon!")
            return
        }
        
        ; Read pack metadata
        packDir := StrReplace(selectedFile, "\pack.json", "")
        metadataFile := packDir . "\pack.json"
        macrosFile := packDir . "\macros.ini"
        
        if (!FileExist(metadataFile) || !FileExist(macrosFile)) {
            MsgBox("Invalid macro pack - missing required files.", "Invalid Pack", "Icon!")
            return
        }
        
        ; Read and parse metadata
        metadataContent := FileRead(metadataFile)
        packName := "Unknown Pack"
        packMacros := 0
        
        ; Simple JSON parsing for key fields
        if (RegExMatch(metadataContent, '"name":"([^"]+)"', &nameMatch)) {
            packName := nameMatch[1]
        }
        if (RegExMatch(metadataContent, '"macros":(\d+)', &macroMatch)) {
            packMacros := Integer(macroMatch[1])
        }
        
        ; Confirm import
        result := MsgBox("Import macro pack '" . packName . "'?`n`nMacros: " . packMacros . "`n`nThis will add macros to your current configuration.`nExisting macros with the same button assignments will be overwritten.", "Import Pack", "YesNo Icon?")
        
        if (result != "Yes") {
            return
        }
        
        ; Read and parse macros file
        macrosContent := FileRead(macrosFile)
        lines := StrSplit(macrosContent, "`n")
        currentSection := ""
        importedMacros := 0
        
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
                
                if (currentSection = "Macros" && InStr(key, "L") = 1 && value != "") {
                    if (ProcessMacroLine(key, value)) {
                        importedMacros++
                    }
                } else if (currentSection = "Labels") {
                    buttonCustomLabels[key] := value
                }
            }
        }
        
        ; Save imported configuration
        SaveConfig()
        
        ; Refresh UI
        RefreshAllButtonAppearances()
        
        MsgBox("✅ Macro pack imported successfully!`n`nPack: " . packName . "`nMacros imported: " . importedMacros, "Import Complete", "Icon!")
        UpdateStatus("📥 Imported pack: " . packName)
        
    } catch Error as e {
        MsgBox("❌ Failed to import macro pack: " . e.Message, "Import Error", "Icon!")
        UpdateStatus("⚠️ Pack import failed: " . e.Message)
    }
}


; ===== EXPORT FUNCTIONS (to be called from other modules) =====

; Call this during application initialization
InitializeConfigSystem() {
    global workDir, configFile
    
    InitConfigLock()
    VerifyConfigPaths()
    
    ; Clean up any stuck locks from previous crashes
    lockFile := workDir . "\config.lock"
    if (FileExist(lockFile)) {
        try {
            FileDelete(lockFile)
            UpdateStatus("🔓 Cleaned up stuck lock from previous session")
        } catch {
            ; Ignore
        }
    }
}

; Call this to add config test hotkeys
SetupConfigTestHotkeys() {
    ; F10 - Diagnostics
    Hotkey("F10", (*) => DiagnoseConfigSystem())

    ; F11 - Test Save/Load
    Hotkey("F11", (*) => TestConfigSystem())

    ; Ctrl+Shift+F12 - Emergency Repair
    Hotkey("^+F12", (*) => RepairConfigSystem())

    UpdateStatus("🔧 Config test hotkeys enabled: F10=Diagnostics, F11=Test, Ctrl+Shift+F12=Repair")
}

; ===== CONFIGURATION LOAD/SAVE FUNCTIONS =====
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
                throw Error("Failed to create config directory: " . configDir)
            }
        }

        ; Check if config file exists
        if !FileExist(configFile) {
            UpdateStatus("📚 No config file found, using defaults")
            return
        }

        ; Read and parse the config file
        content := FileRead(configFile, "UTF-8")

        ; Validate config content
        if (!ValidateConfigData(content)) {
            UpdateStatus("⚠️ Config file validation failed - using defaults")
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
                            case "autoExecutionMode": autoExecutionMode := (value = "true")
                            case "autoExecutionButton": autoExecutionButton := value
                            case "autoExecutionInterval": autoExecutionInterval := EnsureInteger(value, 2000)
                            case "autoExecutionMaxCount": autoExecutionMaxCount := EnsureInteger(value, 0)
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

                    case "AutoSettings":
                        ProcessButtonAutoSetting(key, value)

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

        UpdateStatus("📚 Configuration loaded from " . configFile . " - " . macrosLoaded . " macros, " . settingsLoaded . " settings")

        ; Apply loaded settings to GUI
        ApplyLoadedSettingsToGUI()

    } catch Error as e {
        UpdateStatus("❌ Configuration load failed: " . e.Message)
    }
}

ApplyLoadedSettingsToGUI() {
    try {
        ; Apply dark mode to main GUI
        if (mainGui) {
            mainGui.BackColor := darkMode ? "0x2D2D2D" : "0xF0F0F0"
            mainGui.SetFont("s" . Round(10 * scaleFactor), darkMode ? "c0xFFFFFF" : "c0x000000")
            mainGui.Redraw()
        }

        ; Update status bar color
        if (statusBar) {
            statusBar.Opt("c" . (darkMode ? "White" : "Black"))
            statusBar.Redraw()
        }

        ; Update toolbar background
        if (mainGui && mainGui.HasOwnProp("tbBg")) {
            mainGui.tbBg.BackColor := darkMode ? "0x1E1E1E" : "0xE8E8E8"
            mainGui.tbBg.Redraw()
        }

        ; Update mode toggle button
        if (modeToggleBtn && IsObject(modeToggleBtn)) {
            if (annotationMode = "Narrow") {
                modeToggleBtn.Text := "📱 Narrow"
                modeToggleBtn.Opt("+Background0xFF8C00")
            } else {
                modeToggleBtn.Text := "🔦 Wide"
                modeToggleBtn.Opt("+Background0x4169E1")
            }
            modeToggleBtn.SetFont(, "cWhite")
            modeToggleBtn.Redraw()
        }

        ; Update layer indicator
        if (layerIndicator) {
            layerIndicator.Opt("c" . (darkMode ? "White" : "Black"))
            layerIndicator.Text := "Layer " . currentLayer
            layerIndicator.Redraw()
        }

        ; Switch to loaded layer
        SwitchLayer("")

        ; Refresh all button appearances
        RefreshAllButtonAppearances()

        ; Restore WASD state
        if (hotkeyProfileActive) {
            SetupWASDHotkeys()
            UpdateStatus("🎹 WASD Hotkey Profile restored from config - CapsLock combinations active")
        }

        ; Update button labels with WASD
        UpdateButtonLabelsWithWASD()

        ; Update grid outline
        UpdateGridOutlineColor()

        ; Refresh again for WASD labels
        RefreshAllButtonAppearances()

        ; Update emergency button text
        UpdateEmergencyButtonText()

    } catch Error as e {
        UpdateStatus("⚠️ Failed to apply loaded settings to GUI: " . e.Message)
    }
}

SaveConfig() {
    global workDir
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
        settingsSaved += 2

        ; Auto execution settings
        content .= "autoExecutionMode=" . (autoExecutionMode ? "true" : "false") . "`n"
        content .= "autoExecutionButton=" . autoExecutionButton . "`n"
        content .= "autoExecutionInterval=" . autoExecutionInterval . "`n"
        content .= "autoExecutionMaxCount=" . autoExecutionMaxCount . "`n"
        settingsSaved += 4

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
        for buttonName, label in buttonCustomLabels {
            if (label != "") {
                content .= buttonName . "=" . label . "`n"
            }
        }

        ; Auto settings section
        content .= "`n[AutoSettings]`n"
        for buttonKey, settings in buttonAutoSettings {
            if (settings.enabled) {
                content .= buttonKey . "=" . (settings.enabled ? "1" : "0") . "," . settings.interval . "," . settings.maxCount . "`n"
            }
        }

        ; Write to file
        file := FileOpen(configFile, "w", "UTF-8")
        file.Write(content)
        file.Close()

        UpdateStatus("💾 Configuration saved to " . configFile . " - " . macrosSaved . " macros, " . settingsSaved . " settings")

    } catch Error as e {
        UpdateStatus("❌ Configuration save failed: " . e.Message)
    }
}

InitConfigLock() {
    ; Placeholder - implement as needed
}

CleanupOldConfigFiles() {
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

VerifyConfigPaths() {
    ; Placeholder - implement as needed
}

LoadWASDMappingsFromFile() {
    ; Placeholder - implement as needed
}