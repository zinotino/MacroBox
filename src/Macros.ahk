; ===== MACROS.AHK - Macro State Management =====
; This module handles macro state persistence and basic utilities
; Execution and recording functionality has been extracted to separate modules

; ===== MACRO STATE MANAGEMENT =====
LoadMacroState() {
    global macroEvents, configFile

    loadedMacros := 0

    try {
        if (!FileExist(configFile)) {
            return 0
        }

        ; Read config file
        configContent := FileRead(configFile, "UTF-8")
        configLines := StrSplit(configContent, "`n")

        for line in configLines {
            line := Trim(line)
            if (line = "" || InStr(line, ";")) {
                continue
            }

            ; Parse macro definitions
            if (RegExMatch(line, "^(\w+)=(.*)$", &match)) {
                key := match[1]
                value := match[2]

                ; Handle macro events
                if (InStr(key, "_events")) {
                    macroKey := StrReplace(key, "_events", "")
                    events := []

                    ; Parse JSON-like event array
                    if (RegExMatch(value, "\[(.*)\]", &eventsMatch)) {
                        eventStr := eventsMatch[1]
                        ; Simple parsing - in real implementation would use proper JSON parsing
                        if (eventStr != "") {
                            ; For now, just count events - full parsing would be more complex
                            loadedMacros++
                        }
                    }
                }
            }
        }

        UpdateStatus("📄 Loaded macro state from config")
        return loadedMacros

    } catch Error as e {
        UpdateStatus("⚠️ Error loading macro state: " . e.Message)
        return 0
    }
}

SaveMacroState() {
    global macroEvents, buttonNames

    savedMacros := 0

    try {
        ; Count total macros (single-layer system)
        for buttonName in buttonNames {
            if (macroEvents.Has(buttonName) && macroEvents[buttonName].Length > 0) {
                savedMacros++
            }
        }

        ; CRITICAL: Actually save the config now
        SaveConfig()
        UpdateStatus("💾 Macro state saved (" . savedMacros . " macros)")
        return savedMacros

    } catch Error as e {
        UpdateStatus("⚠️ Error saving macro state: " . e.Message)
        return 0
    }
}

; ===== CLEAR MACRO FUNCTION =====
ClearMacro(buttonName) {
    global macroEvents, buttonThumbnails, buttonCustomLabels

    if (MsgBox("Clear macro for " . buttonName . "?`n`nThis will remove:`n• Macro events`n• Visualizations`n• Thumbnails`n• Custom labels", "Confirm Clear", "YesNo Icon!") = "Yes") {
        ; Clear macro events
        if (macroEvents.Has(buttonName)) {
            macroEvents.Delete(buttonName)
        }

        ; Clear thumbnails
        if (buttonThumbnails.Has(buttonName)) {
            buttonThumbnails.Delete(buttonName)
        }

        ; Clear custom labels (restore to default)
        if (buttonCustomLabels.Has(buttonName)) {
            buttonCustomLabels.Delete(buttonName)
        }

        ; Clear HBITMAP cache
        ClearHBitmapCacheForMacro(buttonName)

        ; Update button appearance to show empty state
        UpdateButtonAppearance(buttonName)

        ; Save changes
        SaveConfig()

        UpdateStatus("🗑️ Cleared " . buttonName . " - all data removed")
    }
}
