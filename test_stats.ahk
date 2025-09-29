; Test script to verify stats recording
#Requires AutoHotkey v2.0
#SingleInstance Force

; Include the main script
#Include "src/MacroLauncherX45.ahk"

; Test function to execute a macro and check stats recording
TestStatsRecording() {
    UpdateStatus("🧪 Starting stats recording test...")

    ; Load macros from config
    LoadConfig()

    ; Execute the Num7 macro (which has bounding boxes)
    UpdateStatus("🎯 Testing macro execution for Num7...")
    ExecuteMacro("Num7")

    ; Wait a moment
    Sleep(1000)

    ; Check if CSV was updated
    csvPath := dataDir . "\master_stats.csv"
    if FileExist(csvPath) {
        ; Read the file to see if new data was added
        content := FileRead(csvPath, "UTF-8")
        lines := StrSplit(content, "`n")

        if (lines.Length > 1) {
            UpdateStatus("✅ SUCCESS: Stats recorded! CSV has " . (lines.Length - 1) . " data rows")
        } else {
            UpdateStatus("❌ FAILED: No data rows in CSV after execution")
        }
    } else {
        UpdateStatus("❌ FAILED: CSV file not found")
    }
}

; Run the test
TestStatsRecording()