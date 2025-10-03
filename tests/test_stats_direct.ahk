; ===== DIRECT STATS TEST - NO GUI =====
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

; Console output function
LogResult(message) {
    OutputDebug("TEST: " . message)
    FileAppend(FormatTime(A_Now, "HH:mm:ss") . " - " . message . "`n", A_ScriptDir . "\test_log.txt")
}

LogResult("Starting direct stats test...")
LogResult("CSV Path: " . masterStatsCSV)

; Test 1: Initialize the CSV system
try {
    InitializeCSVFile()
    if FileExist(masterStatsCSV) {
        LogResult("✅ SUCCESS: CSV file created")

        ; Read and log the header
        content := FileRead(masterStatsCSV, "UTF-8")
        lines := StrSplit(content, "`n")
        if (lines.Length > 0) {
            LogResult("CSV Header: " . Trim(lines[1]))
        }
    } else {
        LogResult("❌ FAILED: CSV file not created")
        ExitApp
    }
} catch as e {
    LogResult("❌ ERROR initializing CSV: " . e.Message)
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
    LogResult("Recording test execution...")

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
        LogResult("✅ SUCCESS: " . dataLines . " data lines recorded")

        ; Log the first data line for verification
        if (lines.Length >= 2) {
            LogResult("First data line: " . Trim(lines[2]))
        }
    } else {
        LogResult("❌ FAILED: No data recorded")
        LogResult("CSV content: " . content)
    }

} catch as e {
    LogResult("❌ ERROR recording stats: " . e.Message)
}

; Test 3: Test dashboard loading
try {
    LogResult("Testing dashboard data loading...")
    stats := ReadStatsFromCSV(false)
    if (stats.Has("total_executions") && stats["total_executions"] > 0) {
        LogResult("✅ SUCCESS: Dashboard can load stats - Total executions: " . stats["total_executions"])
    } else {
        LogResult("❌ FAILED: Dashboard cannot load stats or no executions found")
        LogResult("Stats object keys: " . stats.Count)
        for key, value in stats {
            LogResult("  " . key . ": " . value)
        }
    }
} catch as e {
    LogResult("❌ ERROR loading stats for dashboard: " . e.Message)
}

LogResult("Test complete! CSV file location: " . masterStatsCSV)

; Exit without hanging
ExitApp