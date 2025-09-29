; ===== SIMPLE STATS TEST TO DEBUG ISSUE =====
#Requires AutoHotkey v2.0
#SingleInstance Force

; Include Stats module
#Include "src\Stats.ahk"

; Initialize required globals that Stats.ahk expects
global breakMode := false
global recording := false
global currentLayer := 1
global annotationMode := "Wide"
global totalActiveTime := 0
global lastActiveTime := A_TickCount
global sessionStartTime := A_TickCount
global currentSessionId := "test_" . FormatTime(A_Now, "yyyyMMdd_HHmmss")
global currentUsername := A_UserName

; Set up the CSV path according to the system design
global documentsDir := A_MyDocuments . "\MacroMaster"
global dataDir := documentsDir . "\data"
global masterStatsCSV := dataDir . "\master_stats.csv"

; Test the stats system
MsgBox("Starting simple stats test...`n`nCSV Path: " . masterStatsCSV, "Debug Info")

; Test 1: Initialize the CSV system
try {
    InitializeCSVFile()
    if FileExist(masterStatsCSV) {
        MsgBox("✅ SUCCESS: CSV file created at: " . masterStatsCSV, "Test Result")
    } else {
        MsgBox("❌ FAILED: CSV file not created", "Test Result")
        ExitApp
    }
} catch as e {
    MsgBox("❌ ERROR initializing CSV: " . e.Message, "Test Result")
    ExitApp
}

; Test 2: Record a simple macro execution
try {
    ; Create mock data for testing
    mockEvents := [{type: "drag", x1: 100, y1: 100, x2: 200, y2: 200}]
    mockAnalysisRecord := {
        boundingBoxCount: 1,
        degradationAssignments: "smudge"
    }

    startTime := A_TickCount

    ; Record the execution
    RecordExecutionStats("TestButton", startTime, "macro", mockEvents, mockAnalysisRecord)

    ; Check if it was recorded
    content := FileRead(masterStatsCSV, "UTF-8")
    lines := StrSplit(content, "`n")

    dataLines := 0
    for line in lines {
        if (Trim(line) != "" && !InStr(line, "timestamp")) {
            dataLines++
        }
    }

    if (dataLines > 0) {
        MsgBox("✅ SUCCESS: " . dataLines . " data lines recorded`n`nCSV Contents:`n" . content, "Test Result")
    } else {
        MsgBox("❌ FAILED: No data recorded`n`nCSV Contents:`n" . content, "Test Result")
    }

} catch as e {
    MsgBox("❌ ERROR recording stats: " . e.Message, "Test Result")
}

; Test 3: Test dashboard loading
try {
    stats := ReadStatsFromCSV(false)
    if (stats.Has("total_executions") && stats["total_executions"] > 0) {
        MsgBox("✅ SUCCESS: Dashboard can load stats`nTotal executions: " . stats["total_executions"], "Test Result")
    } else {
        MsgBox("❌ FAILED: Dashboard cannot load stats or no executions found", "Test Result")
    }
} catch as e {
    MsgBox("❌ ERROR loading stats for dashboard: " . e.Message, "Test Result")
}

MsgBox("Test complete! Check the CSV file at:`n" . masterStatsCSV, "Test Complete")