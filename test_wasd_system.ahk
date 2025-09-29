; ===== TEST WASD SYSTEM FUNCTIONALITY =====
#Requires AutoHotkey v2.0
#SingleInstance Force

; Test if the modular system starts and creates CSV
OutputDebug("Starting WASD system test...")

; Start the main application in the background
try {
    Run('"C:\Program Files\AutoHotkey\v2\AutoHotkey.exe" "src\Main.ahk"')

    ; Wait a moment for initialization
    Sleep(2000)

    ; Check if CSV was created
    csvPath := A_MyDocuments . "\MacroMaster\data\master_stats.csv"
    if FileExist(csvPath) {
        OutputDebug("✅ SUCCESS: CSV file created at " . csvPath)

        ; Read the header to verify it's correct
        content := FileRead(csvPath, "UTF-8")
        lines := StrSplit(content, "`n")
        if (lines.Length >= 1) {
            OutputDebug("CSV Header: " . Trim(lines[1]))
        }
    } else {
        OutputDebug("❌ FAILED: CSV file not created")

        ; Check if directory exists
        dataDir := A_MyDocuments . "\MacroMaster\data"
        if DirExist(dataDir) {
            OutputDebug("Data directory exists but no CSV")
        } else {
            OutputDebug("Data directory does not exist")
        }
    }

} catch as e {
    OutputDebug("❌ ERROR: " . e.Message)
}

OutputDebug("Test complete - Check DebugView or OutputDebug for results")
ExitApp