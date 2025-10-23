; ===== MACROS.AHK - Macro State Management =====
; This module handles macro state persistence and basic utilities
; Execution and recording functionality has been extracted to separate modules

; SIMPLIFIED: No complex JSON - macros stored in INI config file
; LoadMacroState and SaveMacroState moved to ConfigIO.ahk

LoadMacroState() {
    ; This is now handled by LoadConfig() in ConfigIO.ahk
    ; Just count and return loaded macros
    global macroEvents, buttonNames

    loadedMacros := 0
    for buttonName in buttonNames {
        if (macroEvents.Has(buttonName) && Type(macroEvents[buttonName]) = "Array" && macroEvents[buttonName].Length > 0) {
            loadedMacros++
        }
    }

    return loadedMacros
}

SaveMacroState() {
    ; This is now handled by SaveConfig() in ConfigIO.ahk
    ; Just count and return saved macros
    global macroEvents, buttonNames

    savedMacros := 0
    for buttonName in buttonNames {
        if (macroEvents.Has(buttonName) && Type(macroEvents[buttonName]) = "Array" && macroEvents[buttonName].Length > 0) {
            savedMacros++
        }
    }

    return savedMacros
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
        SaveMacroState()
        SaveConfig()

        UpdateStatus("🗑️ Cleared " . buttonName . " - all data removed")
    }
}



