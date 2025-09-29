#Requires AutoHotkey v2.0
; Test script to verify persistence functionality

; Include the necessary modules
#Include "../src/Core.ahk"
#Include "../src/Utils.ahk"
#Include "../src/Config.ahk"

; Test persistence system
TestPersistence() {
    UpdateStatus("🧪 Starting persistence test...")

    ; Backup original values
    originalWideCalibrated := isWideCanvasCalibrated
    originalNarrowCalibrated := isNarrowCanvasCalibrated
    originalAnnotationMode := annotationMode

    try {
        ; Test 1: Canvas calibration flags
        UpdateStatus("🧪 Testing canvas calibration persistence...")

        ; Set test values
        isWideCanvasCalibrated := true
        isNarrowCanvasCalibrated := true
        annotationMode := "Narrow"

        ; Save config
        SaveConfig()
        UpdateStatus("✅ Saved test canvas calibration settings")

        ; Clear in-memory values
        isWideCanvasCalibrated := false
        isNarrowCanvasCalibrated := false
        annotationMode := "Wide"

        ; Load config
        LoadConfig()
        UpdateStatus("✅ Loaded config back from file")

        ; Verify values were restored
        if (isWideCanvasCalibrated && isNarrowCanvasCalibrated && annotationMode = "Narrow") {
            UpdateStatus("✅ Canvas calibration persistence test PASSED")
        } else {
            UpdateStatus("❌ Canvas calibration persistence test FAILED")
            MsgBox("Canvas calibration test failed!`nExpected: Wide=true, Narrow=true, Mode=Narrow`nActual: Wide=" . isWideCanvasCalibrated . ", Narrow=" . isNarrowCanvasCalibrated . ", Mode=" . annotationMode)
        }

        ; Test 2: Macro persistence
        UpdateStatus("🧪 Testing macro persistence...")

        ; Create test macro
        testMacroKey := "L1_TestButton"
        testEvents := [
            {type: "boundingBox", left: 100, top: 100, right: 200, bottom: 200},
            {type: "keyDown", key: "a"},
            {type: "keyUp", key: "a"}
        ]

        ; Save original macro if it exists
        originalMacro := macroEvents.Has(testMacroKey) ? macroEvents[testMacroKey] : ""

        ; Set test macro
        macroEvents[testMacroKey] := testEvents
        SaveConfig()
        UpdateStatus("✅ Saved test macro")

        ; Clear test macro
        macroEvents.Delete(testMacroKey)

        ; Load config
        LoadConfig()
        UpdateStatus("✅ Loaded config with macro")

        ; Check if macro was restored
        if (macroEvents.Has(testMacroKey) && macroEvents[testMacroKey].Length >= 3) {
            UpdateStatus("✅ Macro persistence test PASSED")
        } else {
            UpdateStatus("❌ Macro persistence test FAILED")
            MsgBox("Macro persistence test failed! Test macro was not restored.")
        }

        ; Restore original values
        isWideCanvasCalibrated := originalWideCalibrated
        isNarrowCanvasCalibrated := originalNarrowCalibrated
        annotationMode := originalAnnotationMode

        if (originalMacro) {
            macroEvents[testMacroKey] := originalMacro
        } else {
            macroEvents.Delete(testMacroKey)
        }

        ; Final save to restore original state
        SaveConfig()
        UpdateStatus("✅ Restored original configuration")

        MsgBox("Persistence tests completed! Check the status messages above for results.")

    } catch Error as e {
        UpdateStatus("❌ Persistence test failed with error: " . e.Message)
        MsgBox("Test failed: " . e.Message)
    }
}

; Run the test
TestPersistence()