; ===== CONFIG DIAGNOSTICS =====
; Archived from Config.ahk (2025-10-17)
; Developer diagnostic tool for config system troubleshooting

DiagnoseConfigSystem() {
    global configFile, workDir, macroEvents, buttonNames

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
    for buttonName in buttonNames {
        if (macroEvents.Has(buttonName) && macroEvents[buttonName].Length > 0) {
            macroCount++
        }
    }

    diagnostic .= "Macros in Memory: " . macroCount . "`n"
    diagnostic .= "Current Degradation: " . currentDegradation . "`n"

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
