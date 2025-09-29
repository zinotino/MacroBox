#Requires AutoHotkey v2.0
; Simple test to verify canvas calibration flags can be set and saved

; Include necessary modules
#Include "../src/Config.ahk"
#Include "../src/Utils.ahk"

TestCanvasFlags() {
    UpdateStatus("🧪 Testing canvas calibration flag persistence...")

    ; Set test values
    global isWideCanvasCalibrated := true
    global isNarrowCanvasCalibrated := true
    global wideCanvasLeft := 100
    global wideCanvasTop := 200
    global wideCanvasRight := 1800
    global wideCanvasBottom := 1000
    global narrowCanvasLeft := 150
    global narrowCanvasTop := 250
    global narrowCanvasRight := 1750
    global narrowCanvasBottom := 950

    UpdateStatus("✅ Set canvas flags to true and coordinates to test values")

    ; Save config
    SaveConfig()
    UpdateStatus("✅ Called SaveConfig()")

    ; Verify flags are set
    if (isWideCanvasCalibrated && isNarrowCanvasCalibrated) {
        UpdateStatus("✅ Canvas flags are set correctly in memory")
    } else {
        UpdateStatus("❌ Canvas flags not set correctly in memory")
    }

    ; Check if [Canvas] section was created in config file
    configContent := FileRead(configFile, "UTF-8")
    if (InStr(configContent, "[Canvas]")) {
        UpdateStatus("✅ [Canvas] section found in config file")
        if (InStr(configContent, "IsWideCanvasCalibrated=1") && InStr(configContent, "IsNarrowCanvasCalibrated=1")) {
            UpdateStatus("✅ Canvas calibration flags saved correctly in [Canvas] section")
        } else {
            UpdateStatus("❌ Canvas calibration flags not found in [Canvas] section")
        }
    } else {
        UpdateStatus("❌ [Canvas] section not found in config file")
    }

    MsgBox("Canvas flag test completed!`n`nCheck the status messages and config file to see if the flags were saved correctly.`n`nLook for '[Canvas]' section and 'IsWideCanvasCalibrated=1' in the config file.")
}

; Run the test
TestCanvasFlags()