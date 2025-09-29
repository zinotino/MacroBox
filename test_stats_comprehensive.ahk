; ===== COMPREHENSIVE STATISTICS VERIFICATION TEST =====
; This test validates all aspects of the redesigned statistics system

#Requires AutoHotkey v2.0
#SingleInstance Force

; Include required modules
#Include "src\Stats.ahk"
#Include "src\Core.ahk"

; Test configuration
global testResults := []
global testsPassed := 0
global testsFailed := 0

; Mock global variables for testing
global breakMode := false
global recording := false
global currentLayer := 1
global annotationMode := "Wide"
global totalActiveTime := 0
global lastActiveTime := A_TickCount
global sessionStartTime := A_TickCount
global currentSessionId := "test_sess_" . FormatTime(A_Now, "yyyyMMdd_HHmmss")
global currentUsername := "test_user"
global masterStatsCSV := A_ScriptDir . "\test_master_stats.csv"

; Test result reporting functions
LogTest(testName, expected, actual, passed) {
    global testResults, testsPassed, testsFailed

    status := passed ? "✅ PASS" : "❌ FAIL"
    result := {
        name: testName,
        expected: expected,
        actual: actual,
        status: status,
        passed: passed
    }

    testResults.Push(result)

    if (passed) {
        testsPassed++
    } else {
        testsFailed++
    }

    ; Console output
    WinSetTitle(status . " " . testName, "A")
    OutputDebug(status . " " . testName . " - Expected: " . expected . ", Actual: " . actual)
}

; Main test function
RunComprehensiveStatsTest() {
    ; Initialize test environment
    InitializeTestEnvironment()

    ; Test 1: CSV File Creation and Headers
    TestCSVInitialization()

    ; Test 2: Basic Macro Execution Recording
    TestBasicMacroRecording()

    ; Test 3: JSON Profile Execution Recording
    TestJSONProfileRecording()

    ; Test 4: Degradation Type Mapping
    TestDegradationTypeMappings()

    ; Test 5: Session Time Tracking
    TestSessionTimeTracking()

    ; Test 6: Clear Execution Recording
    TestClearExecutionRecording()

    ; Test 7: Bounding Box Counting
    TestBoundingBoxCounting()

    ; Test 8: Multiple Degradation Types
    TestMultipleDegradationTypes()

    ; Test 9: Data Consistency and Validation
    TestDataConsistency()

    ; Test 10: Dashboard Data Loading
    TestDashboardDataLoading()

    ; Generate test report
    GenerateTestReport()

    ; Cleanup
    CleanupTestEnvironment()
}

InitializeTestEnvironment() {
    ; Clean up any existing test files
    if FileExist(masterStatsCSV) {
        FileDelete(masterStatsCSV)
    }

    ; Initialize CSV file for testing
    InitializeCSVFile()

    LogTest("Test Environment Initialization", "CSV file created", "CSV file exists: " . FileExist(masterStatsCSV), FileExist(masterStatsCSV))
}

TestCSVInitialization() {
    ; Test that CSV is created with correct headers
    if (!FileExist(masterStatsCSV)) {
        LogTest("CSV File Creation", "File exists", "File missing", false)
        return
    }

    content := FileRead(masterStatsCSV, "UTF-8")
    lines := StrSplit(content, "`n")

    if (lines.Length >= 1) {
        header := Trim(lines[1])
        expectedFields := ["timestamp", "session_id", "username", "execution_type", "button_key", "layer", "execution_time_ms", "total_boxes", "degradation_assignments", "severity_level", "canvas_mode", "session_active_time_ms", "break_mode_active"]

        allFieldsPresent := true
        for field in expectedFields {
            if (!InStr(header, field)) {
                allFieldsPresent := false
                break
            }
        }

        LogTest("CSV Headers Validation", "All required fields present", "Fields check: " . allFieldsPresent, allFieldsPresent)
    } else {
        LogTest("CSV Headers Validation", "Header line exists", "No header found", false)
    }
}

TestBasicMacroRecording() {
    ; Create mock macro events for testing
    mockEvents := [
        {type: "drag", x1: 100, y1: 100, x2: 200, y2: 200},
        {type: "drag", x1: 300, y1: 300, x2: 400, y2: 400}
    ]

    ; Create mock analysis record
    mockAnalysisRecord := {
        boundingBoxCount: 2,
        degradationAssignments: "smudge,glare"
    }

    startTime := A_TickCount

    ; Record execution stats
    RecordExecutionStats("TestButton", startTime, "macro", mockEvents, mockAnalysisRecord)

    ; Verify recording
    content := FileRead(masterStatsCSV, "UTF-8")
    lines := StrSplit(content, "`n")

    ; Should have header + 1 data row
    expectedLines := 2
    actualLines := 0
    for line in lines {
        if (Trim(line) != "") {
            actualLines++
        }
    }

    LogTest("Basic Macro Recording", expectedLines . " lines", actualLines . " lines", actualLines >= expectedLines)

    ; Check if degradation assignments are recorded
    if (actualLines >= 2) {
        dataLine := Trim(lines[2])
        hasSmudge := InStr(dataLine, "smudge")
        hasGlare := InStr(dataLine, "glare")

        LogTest("Degradation Assignment Recording", "smudge,glare found", "smudge: " . (hasSmudge > 0) . ", glare: " . (hasGlare > 0), hasSmudge > 0 && hasGlare > 0)
    }
}

TestJSONProfileRecording() {
    ; Create mock JSON analysis record
    mockAnalysisRecord := {
        jsonDegradationName: "rain",
        severity: "high",
        annotationDetails: "Heavy rain on windshield"
    }

    startTime := A_TickCount

    ; Record JSON execution stats
    RecordExecutionStats("JSONButton", startTime, "json_profile", [], mockAnalysisRecord)

    ; Verify recording
    content := FileRead(masterStatsCSV, "UTF-8")
    lines := StrSplit(content, "`n")

    ; Find the JSON profile line
    jsonLineFound := false
    for line in lines {
        if (InStr(line, "json_profile") && InStr(line, "rain")) {
            jsonLineFound := true
            break
        }
    }

    LogTest("JSON Profile Recording", "JSON profile line found", "Line found: " . jsonLineFound, jsonLineFound)
}

TestDegradationTypeMappings() {
    ; Test all degradation types
    degradationTypes := ["smudge", "glare", "splashes", "partial_blockage", "full_blockage", "light_flare", "rain", "haze", "snow", "clear"]

    allMappingsWork := true

    for degradationType in degradationTypes {
        mockAnalysisRecord := {
            boundingBoxCount: 1,
            degradationAssignments: degradationType
        }

        startTime := A_TickCount
        RecordExecutionStats("Test_" . degradationType, startTime, "macro", [], mockAnalysisRecord)

        ; Brief delay to ensure timestamp differences
        Sleep(10)
    }

    ; Verify all degradation types are recorded
    content := FileRead(masterStatsCSV, "UTF-8")

    for degradationType in degradationTypes {
        if (!InStr(content, degradationType)) {
            allMappingsWork := false
            break
        }
    }

    LogTest("Degradation Type Mappings", "All types recorded", "All types found: " . allMappingsWork, allMappingsWork)
}

TestSessionTimeTracking() {
    ; Test session active time calculation
    initialTime := GetCurrentSessionActiveTime()

    ; Simulate some activity time
    Sleep(100)
    UpdateActiveTime()

    finalTime := GetCurrentSessionActiveTime()

    timeIncreased := finalTime > initialTime
    LogTest("Session Time Tracking", "Time increased", "Initial: " . initialTime . ", Final: " . finalTime, timeIncreased)
}

TestClearExecutionRecording() {
    startTime := A_TickCount

    ; Record a clear execution
    RecordExecutionStats("ClearButton", startTime, "clear", [], "")

    ; Verify clear execution is recorded
    content := FileRead(masterStatsCSV, "UTF-8")
    clearRecorded := InStr(content, "clear") > 0

    LogTest("Clear Execution Recording", "Clear execution found", "Clear found: " . clearRecorded, clearRecorded)
}

TestBoundingBoxCounting() {
    ; Test different bounding box counts
    testCounts := [1, 5, 10, 0]

    allCountsCorrect := true

    for count in testCounts {
        mockAnalysisRecord := {
            boundingBoxCount: count,
            degradationAssignments: "clear"
        }

        startTime := A_TickCount
        RecordExecutionStats("BoxTest_" . count, startTime, "macro", [], mockAnalysisRecord)

        ; Verify the count is recorded
        content := FileRead(masterStatsCSV, "UTF-8")
        lines := StrSplit(content, "`n")

        ; Find the line with this test
        found := false
        for line in lines {
            if (InStr(line, "BoxTest_" . count)) {
                fields := StrSplit(line, ",")
                if (fields.Length >= 8) {
                    recordedCount := Integer(fields[8])  ; total_boxes field
                    if (recordedCount != count) {
                        allCountsCorrect := false
                    }
                    found := true
                }
                break
            }
        }

        if (!found) {
            allCountsCorrect := false
        }

        Sleep(10)
    }

    LogTest("Bounding Box Counting", "All counts accurate", "Counts correct: " . allCountsCorrect, allCountsCorrect)
}

TestMultipleDegradationTypes() {
    ; Test multiple degradation types in one execution
    mockAnalysisRecord := {
        boundingBoxCount: 3,
        degradationAssignments: "smudge,glare,rain"
    }

    startTime := A_TickCount
    RecordExecutionStats("MultiDegradation", startTime, "macro", [], mockAnalysisRecord)

    ; Verify all degradation types are recorded
    content := FileRead(masterStatsCSV, "UTF-8")

    hasSmudge := InStr(content, "smudge") > 0
    hasGlare := InStr(content, "glare") > 0
    hasRain := InStr(content, "rain") > 0

    allTypesRecorded := hasSmudge && hasGlare && hasRain

    LogTest("Multiple Degradation Types", "All types recorded", "smudge: " . hasSmudge . ", glare: " . hasGlare . ", rain: " . hasRain, allTypesRecorded)
}

TestDataConsistency() {
    ; Verify data consistency in CSV
    content := FileRead(masterStatsCSV, "UTF-8")
    lines := StrSplit(content, "`n")

    ; Check that all data lines have the same number of fields as header
    if (lines.Length < 2) {
        LogTest("Data Consistency", "Sufficient data", "Not enough lines", false)
        return
    }

    headerFields := StrSplit(Trim(lines[1]), ",").Length
    allLinesConsistent := true

    for i in 2..lines.Length {
        line := Trim(lines[i])
        if (line == "") continue

        dataFields := StrSplit(line, ",").Length
        if (dataFields != headerFields) {
            allLinesConsistent := false
            break
        }
    }

    LogTest("Data Consistency", "All lines match header", "Consistency: " . allLinesConsistent, allLinesConsistent)
}

TestDashboardDataLoading() {
    ; Test that dashboard can load the generated data
    try {
        stats := ReadStatsFromCSV(false)

        hasValidStats := stats.Has("total_executions") && stats["total_executions"] > 0
        LogTest("Dashboard Data Loading", "Stats loaded successfully", "Valid stats: " . hasValidStats, hasValidStats)

        ; Test specific metrics
        hasTotalBoxes := stats.Has("total_boxes")
        hasAverageTime := stats.Has("average_execution_time")
        hasExecutionTypes := stats.Has("macro_executions_count") && stats.Has("json_profile_executions_count")

        metricsComplete := hasTotalBoxes && hasAverageTime && hasExecutionTypes
        LogTest("Dashboard Metrics", "All metrics available", "Metrics complete: " . metricsComplete, metricsComplete)

    } catch as e {
        LogTest("Dashboard Data Loading", "No errors", "Error: " . e.Message, false)
    }
}

GenerateTestReport() {
    global testResults, testsPassed, testsFailed

    ; Create test report
    report := "===== MACROMASTER STATISTICS SYSTEM TEST REPORT =====`n"
    report .= "Test Date: " . FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss") . "`n"
    report .= "Total Tests: " . (testsPassed + testsFailed) . "`n"
    report .= "Passed: " . testsPassed . "`n"
    report .= "Failed: " . testsFailed . "`n"
    report .= "Success Rate: " . Round((testsPassed / (testsPassed + testsFailed)) * 100, 1) . "%`n`n"

    ; Individual test results
    for result in testResults {
        report .= result.status . " " . result.name . "`n"
        report .= "  Expected: " . result.expected . "`n"
        report .= "  Actual: " . result.actual . "`n`n"
    }

    ; Overall assessment
    if (testsFailed = 0) {
        report .= "🎉 ALL TESTS PASSED! Statistics system is working correctly.`n"
    } else {
        report .= "⚠️ " . testsFailed . " TESTS FAILED. Review the issues above.`n"
    }

    ; Save report to file
    reportFile := A_ScriptDir . "\stats_test_report.txt"
    FileAppend(report, reportFile)

    ; Display results
    MsgBox(report, "Statistics Test Results", "Icon!")

    ; Show CSV file location
    if FileExist(masterStatsCSV) {
        MsgBox("Test CSV generated at:`n" . masterStatsCSV . "`n`nTest report saved at:`n" . reportFile, "Test Files", "Icon!")
    }
}

CleanupTestEnvironment() {
    ; Note: Keeping test files for inspection
    ; User can manually delete if desired
}

; Run the comprehensive test
RunComprehensiveStatsTest()