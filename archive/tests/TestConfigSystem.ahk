; ===== FORCED SAVE/LOAD TEST =====
; Archived from Config.ahk (2025-10-17)
; Automated test suite for config system validation

TestConfigSystem() {
    global macroEvents, buttonNames

    ; Step 1: Count current macros
    originalCount := 0
    for buttonName in buttonNames {
        if (macroEvents.Has(buttonName) && macroEvents[buttonName].Length > 0) {
            originalCount++
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
    for buttonName in buttonNames {
        if (macroEvents.Has(buttonName)) {
            backupEvents[buttonName] := macroEvents[buttonName].Clone()
        }
    }

    ; Step 4: Clear in-memory data
    for buttonName in buttonNames {
        if (macroEvents.Has(buttonName)) {
            macroEvents.Delete(buttonName)
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
    for buttonName in buttonNames {
        if (macroEvents.Has(buttonName) && macroEvents[buttonName].Length > 0) {
            loadedCount++
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
