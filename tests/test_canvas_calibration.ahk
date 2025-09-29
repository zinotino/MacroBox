#Requires AutoHotkey v2.0
; Test script to verify canvas calibration persistence

; Include the necessary modules
#Include "../src/Core.ahk"
#Include "../src/Utils.ahk"
#Include "../src/Config.ahk"

TestCanvasCalibration() {
    UpdateStatus("🧪 Starting canvas calibration test...")

    ; Backup original values
    originalWideCalibrated := isWideCanvasCalibrated
    originalNarrowCalibrated := isNarrowCanvasCalibrated
    originalWideLeft := wideCanvasLeft
    originalWideTop := wideCanvasTop
    originalWideRight := wideCanvasRight
    originalWideBottom := wideCanvasBottom
    originalNarrowLeft := narrowCanvasLeft
    originalNarrowTop := narrowCanvasTop
    originalNarrowRight := narrowCanvasRight
    originalNarrowBottom := narrowCanvasBottom

    try {
        ; Test 1: Direct flag setting and saving
        UpdateStatus("🧪 Testing direct canvas flag setting...")

        ; Set test values
        isWideCanvasCalibrated := true
        isNarrowCanvasCalibrated := true
        wideCanvasLeft := 100
        wideCanvasTop := 200
        wideCanvasRight := 1800
        wideCanvasBottom := 1000
        narrowCanvasLeft := 150
        narrowCanvasTop := 250
        narrowCanvasRight := 1750
        narrowCanvasBottom := 950

        ; Save config
        SaveConfig()
        UpdateStatus("✅ Saved test canvas settings")

        ; Clear in-memory values
        isWideCanvasCalibrated := false
        isNarrowCanvasCalibrated := false
        wideCanvasLeft := 0
        wideCanvasTop := 0
        wideCanvasRight := 1920
        wideCanvasBottom := 1080
        narrowCanvasLeft := 240
        narrowCanvasTop := 0
        narrowCanvasRight := 1680
        narrowCanvasBottom := 1080

        ; Load config
        LoadConfig()
        UpdateStatus("✅ Loaded config back from file")

        ; Verify values were restored
        if (isWideCanvasCalibrated && isNarrowCanvasCalibrated &&
            wideCanvasLeft = 100 && wideCanvasTop = 200 &&
            wideCanvasRight = 1800 && wideCanvasBottom = 1000 &&
            narrowCanvasLeft = 150 && narrowCanvasTop = 250 &&
            narrowCanvasRight = 1750 && narrowCanvasBottom = 950) {
            UpdateStatus("✅ Canvas calibration persistence test PASSED")
        } else {
            UpdateStatus("❌ Canvas calibration persistence test FAILED")
            MsgBox("Canvas calibration test failed!`nExpected: Wide=true, Narrow=true`nActual: Wide=" . isWideCanvasCalibrated . ", Narrow=" . isNarrowCanvasCalibrated . "`nWide coords: " . wideCanvasLeft . "," . wideCanvasTop . "," . wideCanvasRight . "," . wideCanvasBottom . "`nNarrow coords: " . narrowCanvasLeft . "," . narrowCanvasTop . "," . narrowCanvasRight . "," . narrowCanvasBottom)
        }

        ; Test 2: Check config file directly
        UpdateStatus("🧪 Checking config file contents...")
        if (FileExist(configFile)) {
            content := FileRead(configFile, "UTF-8")
            hasWideCalibrated := InStr(content, "isWideCanvasCalibrated=true")
            hasNarrowCalibrated := InStr(content, "isNarrowCanvasCalibrated=true")
            hasWideCoords := InStr(content, "wideCanvasLeft=100") && InStr(content, "wideCanvasTop=200")

            if (hasWideCalibrated && hasNarrowCalibrated && hasWideCoords) {
                UpdateStatus("✅ Config file contains correct canvas settings")
            } else {
                UpdateStatus("❌ Config file missing canvas settings")
                MsgBox("Config file check failed!`nWide calibrated: " . hasWideCalibrated . "`nNarrow calibrated: " . hasNarrowCalibrated . "`nWide coords: " . hasWideCoords)
            }
        } else {
            UpdateStatus("❌ Config file not found")
        }

        ; Restore original values
        isWideCanvasCalibrated := originalWideCalibrated
        isNarrowCanvasCalibrated := originalNarrowCalibrated
        wideCanvasLeft := originalWideLeft
        wideCanvasTop := originalWideTop
        wideCanvasRight := originalWideRight
        wideCanvasBottom := originalWideBottom
        narrowCanvasLeft := originalNarrowLeft
        narrowCanvasTop := originalNarrowTop
        narrowCanvasRight := originalNarrowRight
        narrowCanvasBottom := originalNarrowBottom

        ; Final save to restore original state
        SaveConfig()
        UpdateStatus("✅ Restored original canvas configuration")

        MsgBox("Canvas calibration tests completed! Check the status messages above for results.")

    } catch Error as e {
        UpdateStatus("❌ Canvas calibration test failed with error: " . e.Message)
        MsgBox("Test failed: " . e.Message)
    }
}

; Run the test
TestCanvasCalibration()