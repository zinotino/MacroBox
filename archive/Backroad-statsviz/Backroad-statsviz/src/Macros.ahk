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
    global macroEvents

    savedMacros := 0

    try {
        ; Count total macros
        for layer in 1..5 {
            for buttonName in buttonNames {
                layerMacroName := "L" . layer . "_" . buttonName
                if (macroEvents.Has(layerMacroName) && macroEvents[layerMacroName].Length > 0) {
                    savedMacros++
                }
            }
        }

        ; CRITICAL: Actually save the config now
        SaveConfig()
        ; Silent save - removed excessive status update
        return savedMacros

    } catch Error as e {
        UpdateStatus("⚠️ Error saving macro state: " . e.Message)
        return 0
    }
}

; ===== CLEAR MACRO FUNCTION =====
ClearMacro(buttonName) {
    global currentLayer, macroEvents, buttonThumbnails, buttonCustomLabels, buttonAutoSettings

    layerMacroName := "L" . currentLayer . "_" . buttonName

    if (MsgBox("Clear macro for " . buttonName . " on Layer " . currentLayer . "?`n`nThis will remove:`n• Macro events`n• Visualizations`n• Thumbnails`n• Auto settings`n• Custom labels", "Confirm Clear", "YesNo Icon!") = "Yes") {
        ; Clear macro events
        if (macroEvents.Has(layerMacroName)) {
            macroEvents.Delete(layerMacroName)
        }

        ; Clear thumbnails
        if (buttonThumbnails.Has(layerMacroName)) {
            buttonThumbnails.Delete(layerMacroName)
        }

        ; Clear custom labels (restore to default)
        if (buttonCustomLabels.Has(buttonName)) {
            buttonCustomLabels.Delete(buttonName)
        }

        ; Clear auto settings
        if (buttonAutoSettings.Has(layerMacroName)) {
            buttonAutoSettings.Delete(layerMacroName)
        }

        ; Clear HBITMAP cache
        ClearHBitmapCacheForMacro(layerMacroName)

        ; Update button appearance to show empty state
        UpdateButtonAppearance(buttonName)

        ; Save changes
        SaveConfig()

        UpdateStatus("🗑️ Cleared " . buttonName . " - all data removed")
    }
}
