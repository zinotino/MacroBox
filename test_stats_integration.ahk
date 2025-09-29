; ===== STATS INTEGRATION TEST =====
#Requires AutoHotkey v2.0
#SingleInstance Force

; Set up minimal required globals for Stats.ahk
global breakMode := false
global recording := false
global currentLayer := 1
global annotationMode := "Wide"
global totalActiveTime := 0
global lastActiveTime := A_TickCount
global sessionStartTime := A_TickCount
global currentSessionId := "integration_test_" . FormatTime(A_Now, "yyyyMMdd_HHmmss")
global currentUsername := A_UserName
global documentsDir := A_MyDocuments . "\MacroMaster"
global dataDir := documentsDir . "\data"
global masterStatsCSV := dataDir . "\master_stats.csv"

; Define required functions for Stats.ahk
UpdateStatus(message) {
    OutputDebug("STATUS: " . message)
}

RunWaitOne(command) {
    try {
        return RunWait(command, , "Hide")
    } catch {
        return ""
    }
}

; Now include Stats.ahk
#Include "src\Stats.ahk"

; Test the integration
OutputDebug("Starting stats integration test...")

try {
    ; Initialize CSV
    InitializeCSVFile()

    if FileExist(masterStatsCSV) {
        OutputDebug("✅ CSV file created successfully: " . masterStatsCSV)

        ; Test recording a stat
        mockAnalysisRecord := {
            boundingBoxCount: 2,
            degradationAssignments: "smudge,glare"
        }

        RecordExecutionStats("IntegrationTest", A_TickCount, "macro", [], mockAnalysisRecord)

        ; Check if data was recorded
        content := FileRead(masterStatsCSV, "UTF-8")
        lines := StrSplit(content, "`n")

        if (lines.Length >= 2) {
            OutputDebug("✅ Stats recorded successfully - " . (lines.Length - 1) . " data lines")
        } else {
            OutputDebug("❌ No stats recorded")
        }
    } else {
        OutputDebug("❌ CSV file not created")
    }
} catch as e {
    OutputDebug("❌ Error: " . e.Message)
}

OutputDebug("Integration test complete")
ExitApp