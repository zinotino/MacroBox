; ===== STATS.AHK - Statistics and Analytics System =====
; This module contains all statistics-related functionality

; ===== STATS MODULE FOR MODULAR SYSTEM =====
; This module expects global variables to be defined in Core.ahk:
; - workDir (data directory)
; - documentsDir
; - thumbnailDir
; - sessionId
; - currentUsername
; - masterStatsCSV
; And functions: UpdateStatus, RunWaitOne

; ===== STATISTICS SYSTEM INITIALIZATION =====
InitializeStatsSystem() {
    global masterStatsCSV, workDir, sessionId, currentUsername

    ; Ensure CSV file exists
    if (!FileExist(masterStatsCSV)) {
        InitializeCSVFile()
    }

    UpdateStatus("📊 Stats system initialized")
}

; ===== CSV FILE INITIALIZATION =====
InitializeCSVFile() {
    global masterStatsCSV, documentsDir, workDir, sessionId

    try {
        ; Create full directory structure in Documents for portable execution
        if (!DirExist(documentsDir)) {
            DirCreate(documentsDir)
            UpdateStatus("💾 Created MacroMaster folder in Documents")
        }

        if (!DirExist(workDir)) {
            DirCreate(workDir)
            UpdateStatus("💾 Created data directory in Documents")
        }

        ; Create CSV with streamlined header optimized for tracking and display
        if (!FileExist(masterStatsCSV)) {
            header := "timestamp,session_id,username,execution_type,button_key,layer,execution_time_ms,total_boxes,degradation_assignments,severity_level,canvas_mode,session_active_time_ms,break_mode_active,smudge_count,glare_count,splashes_count,partial_blockage_count,full_blockage_count,light_flare_count,rain_count,haze_count,snow_count,clear_count,annotation_details,execution_success,error_details`n"
            FileAppend(header, masterStatsCSV, "UTF-8")
            UpdateStatus("📊 CSV stats file initialized")
        }
    } catch as e {
        UpdateStatus("⚠️ CSV setup failed: " . e.Message)
    }
}

InitializeRealtimeSession() {
    ; Start a new session with the real-time service
    sessionData := Map()
    sessionData["session_id"] := currentSessionId
    sessionData["username"] := currentUsername
    sessionData["canvas_mode"] := annotationMode

    if (!SendDataToIngestionService("/session/start", sessionData)) {
        UpdateStatus("⚠️ Real-time service unavailable - using fallback mode")
        realtimeEnabled := false
    } else {
        UpdateStatus("🔗 Real-time session started: " . currentSessionId)
    }
}

LoadStatsData() {
    ; Load statistics data from CSV
    return ReadStatsFromCSV(false)
}

; ===== OFFLINE DATA MANAGEMENT =====
InitializeOfflineDataFiles() {
    global persistentDataFile, dailyStatsFile, offlineLogFile

    try {
        ; Create data directory in Documents for portable execution
        if (!DirExist(workDir)) {
            DirCreate(workDir)
        }
        if (!DirExist(thumbnailDir)) {
            DirCreate(thumbnailDir)
        }

        ; Initialize persistent data file if it doesn't exist
        if (!FileExist(persistentDataFile)) {
            initialData := "{`n"
            initialData .= "  `"version`": `"1.0.0`",`n"
            initialData .= "  `"created`": `"" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "`",`n"
            initialData .= "  `"users`": {},`n"
            initialData .= "  `"totalStats`": {`n"
            initialData .= "    `"totalBoxCount`": 0,`n"
            initialData .= "    `"totalExecutionTimeMs`": 0,`n"
            initialData .= "    `"totalActiveTimeSeconds`": 0,`n"
            initialData .= "    `"totalExecutionCount`": 0,`n"
            initialData .= "    `"totalSessions`": 0,`n"
            initialData .= "    `"firstSessionDate`": null,`n"
            initialData .= "    `"lastSessionDate`": null`n"
            initialData .= "  }`n"
            initialData .= "}"
            FileAppend(initialData, persistentDataFile)
        }

        ; Initialize daily stats file if it doesn't exist
        if (!FileExist(dailyStatsFile)) {
            currentDay := FormatTime(, "dddd, MMMM d, yyyy")
            initialDaily := "{`n"
            initialDaily .= "  `"lastReset`": `"" . FormatTime(, "yyyy-MM-dd HH:mm:ss") . "`",`n"
            initialDaily .= "  `"currentDay`": `"" . currentDay . "`",`n"
            initialDaily .= "  `"resetTime`": `"18:00:00`",`n"
            initialDaily .= "  `"stats`": {`n"
            initialDaily .= "    `"totalBoxCount`": 0,`n"
            initialDaily .= "    `"totalExecutionTimeMs`": 0,`n"
            initialDaily .= "    `"activeTimeSeconds`": 0,`n"
            initialDaily .= "    `"executionCount`": 0,`n"
            initialDaily .= "    `"sessions`": []`n"
            initialDaily .= "  }`n"
            initialDaily .= "}"
            FileAppend(initialDaily, dailyStatsFile)
        }

        ; Log initialization
        LogOfflineActivity("Offline storage initialized")

        UpdateStatus("💾 Offline data storage initialized successfully")
        return true
    } catch Error as e {
        UpdateStatus("⚠️ Error initializing offline storage: " . e.Message)
        return false
    }
}

; ===== STATISTICS DISPLAY FUNCTIONS =====
ShowPythonStats() {
    static dashboardRunning := false

    ; Prevent multiple dashboard instances
    if (dashboardRunning) {
        UpdateStatus("📊 Dashboard already running - use existing window")
        return
    }

    ; Run the live dashboard server instead of opening static HTML
    dashboardScript := A_ScriptDir . "\..\dashboard\run_live_dashboard.py"
    csvPath := A_ScriptDir . "\..\data\master_stats.csv"
    workingDir := A_ScriptDir . "\..\dashboard"
    htmlPath := A_ScriptDir . "\..\dashboard\output\macromaster_timeline_slider.html"

    try {
        ; Mark dashboard as running
        dashboardRunning := true

        ; Build command string properly
        cmd := 'python "' . dashboardScript . '" --csv "' . csvPath . '"'
        Run(cmd, workingDir)
        UpdateStatus("📊 Live dashboard server starting...")

        ; Reset flag after a delay to allow for multiple launches if needed
        SetTimer(() => dashboardRunning := false, -5000)

    } catch Error as e {
        ; Reset flag on error
        dashboardRunning := false
        UpdateStatus("⚠️ Failed to start live dashboard: " . e.Message)
        ; Fallback to opening static HTML if Python fails
        if FileExist(htmlPath) {
            Run(htmlPath)
            UpdateStatus("📄 Opened static dashboard (fallback)")
        } else {
            UpdateStatus("⚠️ Dashboard file not found: " . htmlPath)
        }
    }
    if (FileExist(htmlPath)) {
        Run htmlPath
        UpdateStatus("📊 Dashboard launched directly")
    } else {
        UpdateStatus("⚠️ Dashboard file not found: " . htmlPath)
    }
}

ShowStatsMenu() {
    global masterStatsCSV, dailyResetActive, darkMode

    ; Create modern stats menu with proper sizing
    statsMenuGui := Gui("+Resize +MinSize450x280", "📊 MacroMaster Analytics")
    statsMenuGui.BackColor := darkMode ? "0x2A2A2A" : "White"
    statsMenuGui.SetFont("s10", "Segoe UI")

    ; Header
    headerText := statsMenuGui.Add("Text", "x20 y20 w410 h30 Center", "📊 Execution Data")
    headerText.SetFont("s12 bold", "Segoe UI")
    headerText.Opt("c" . (darkMode ? "White" : "Black"))

    ; Quick stats overview
    quickStatsY := 60
    quickStats := GetQuickStatsText()
    quickStatsText := statsMenuGui.Add("Text", "x20 y" . quickStatsY . " w410 h70 Center", quickStats)
    quickStatsText.SetFont("s9", "Segoe UI")
    quickStatsText.Opt("c" . (darkMode ? "0xCCCCCC" : "0x333333"))

    ; Dashboard options with proper spacing
    btnY := quickStatsY + 85
    btnWidth := 160
    btnHeight := 35
    btnSpacing := 20

    ; Unified Analytics Dashboard (full width)
    btnAnalytics := statsMenuGui.Add("Button", "x20 y" . btnY . " w410 h" . (btnHeight + 5), "📊 MacroMaster Analytics Dashboard")
    btnAnalytics.SetFont("s11 bold")
    btnAnalytics.OnEvent("Click", (*) => LaunchDashboard("unified", statsMenuGui))

    ; Second row buttons with proper spacing
    btnY2 := btnY + btnHeight + 15

    ; Data Export
    btnExport := statsMenuGui.Add("Button", "x20 y" . btnY2 . " w180 h32", "💾 Export Data")
    btnExport.SetFont("s9")
    btnExport.OnEvent("Click", (*) => ExportStatsData(statsMenuGui))

    ; Close button
    btnClose := statsMenuGui.Add("Button", "x250 y" . btnY2 . " w180 h32", "❌ Close")
    btnClose.SetFont("s9")
    btnClose.OnEvent("Click", (*) => statsMenuGui.Destroy())

    ; Dynamic window height with proper spacing
    windowHeight := btnY2 + 55
    statsMenuGui.Show("w450 h" . windowHeight)
}

GetQuickStatsText() {
    global masterStatsCSV, systemHealthStatus

    if (!FileExist(masterStatsCSV)) {
        return "📊 No data recorded yet`nStart using macros to see raw statistics!"
    }

    try {
        ; Get raw statistical data
        stats := ReadStatsFromCSV(false) ; Get all-time stats

        if (stats["total_executions"] = 0) {
            return "📊 No executions recorded yet`nStart using macros to see raw statistics!"
        }

        ; Raw data display - no AI inference
        totalExecs := stats["total_executions"]
        totalBoxes := stats["total_boxes"]
        avgTime := stats["average_execution_time"]
        execsPerHour := stats["executions_per_hour"]

        ; System status (technical only)
        statusIcon := systemHealthStatus = "healthy" ? "🟢" : systemHealthStatus = "degraded" ? "🟡" : "🔴"

        if (totalExecs = 1) {
            return statusIcon . " System: " . systemHealthStatus . " | Data: " . totalExecs . " record`n📊 " . totalBoxes . " boxes | " . avgTime . "ms avg | " . execsPerHour . "/hr rate"
        } else {
            return statusIcon . " System: " . systemHealthStatus . " | Data: " . totalExecs . " records`n📊 " . totalBoxes . " boxes | " . avgTime . "ms avg | " . execsPerHour . "/hr rate"
        }
    } catch {
        return "📊 Raw data ready | System status: " . systemHealthStatus . "`nView detailed statistics below"
    }
}

LaunchDashboard(filterMode, statsMenuGui) {
    global masterStatsCSV, documentsDir

    ; Validate CSV file exists
    if (!FileExist(masterStatsCSV)) {
        InitializeCSVFile()
    }

    ; Use the unified timeline analytics dashboard for all modes
    timelineScript := A_ScriptDir . "\..\dashboard\timeline_slider_dashboard.py"

    if (FileExist(timelineScript)) {
        try {
            ; Launch the unified timeline analytics dashboard
            pythonCmd := 'python "' . timelineScript . '" "' . masterStatsCSV . '"'

            ; Dashboard launching silently for cleaner UX
            Run(pythonCmd, A_ScriptDir)

            ; Close the menu
            statsMenuGui.Destroy()

            ; Dashboard opened successfully
            return

        } catch Error as e {
            UpdateStatus("⚠️ Analytics dashboard failed, trying built-in fallback...")
        }
    } else {
        UpdateStatus("⚠️ Analytics dashboard not found, using built-in fallback...")
    }

    ; Fallback to built-in GUI for workplace restrictions
    try {
        ; Using fallback display

        ; Read stats data using our CSV function
        stats := ReadStatsFromCSV(filterMode = "today")

        ; Create built-in stats dashboard GUI as fallback
        ShowBuiltInStatsGUI(filterMode, stats)

        ; Close the menu
        statsMenuGui.Destroy()

        ; Built-in display ready

    } catch Error as e {
        MsgBox("❌ Failed to load data: " . e.Message . "`n`nCSV location: " . masterStatsCSV, "Error", "Icon!")
        UpdateStatus("❌ Data display failed: " . e.Message)
    }
}

; ===== CSV STATISTICS FUNCTIONS =====
ReadStatsFromCSV(filterBySession := false) {
    global masterStatsCSV, sessionId, totalActiveTime

    ; Initialize comprehensive stats structure
    stats := Map()
    stats["total_executions"] := 0
    stats["macro_executions_count"] := 0
    stats["json_profile_executions_count"] := 0
    stats["clear_executions_count"] := 0
    stats["total_boxes"] := 0
    stats["total_execution_time"] := 0
    stats["average_execution_time"] := 0
    stats["session_active_time"] := totalActiveTime
    stats["boxes_per_hour"] := 0
    stats["executions_per_hour"] := 0
    stats["most_used_button"] := ""
    stats["most_active_layer"] := ""
    ; Performance grades removed - using raw data only
    stats["degradation_totals"] := Map()

    ; Initialize degradation type counters
    stats["smudge_total"] := 0
    stats["glare_total"] := 0
    stats["splashes_total"] := 0
    stats["partial_blockage_total"] := 0
    stats["full_blockage_total"] := 0
    stats["light_flare_total"] := 0
    stats["rain_total"] := 0
    stats["haze_total"] := 0
    stats["snow_total"] := 0
    stats["clear_total"] := 0

    try {
        if (!FileExist(masterStatsCSV)) {
            return stats
        }

        csvContent := FileRead(masterStatsCSV, "UTF-8")
        lines := StrSplit(csvContent, "`n")

        if (lines.Length <= 1) {
            return stats ; No data rows
        }

        ; Process data rows for new streamlined schema
        ; Headers: timestamp,session_id,username,execution_type,button_key,layer,execution_time_ms,total_boxes,degradation_assignments,severity_level,canvas_mode,session_active_time_ms,break_mode_active,smudge_count,glare_count,splashes_count,partial_blockage_count,full_blockage_count,light_flare_count,rain_count,haze_count,snow_count,clear_count,annotation_details,execution_success,error_details

        executionTimes := []
        buttonCount := Map()
        layerCount := Map()
        gradeCount := Map()
        latestActiveTime := 0

        Loop lines.Length - 1 {
            lineIndex := A_Index + 1 ; Skip header
            if (lineIndex > lines.Length || Trim(lines[lineIndex]) = "") {
                continue
            }

            fields := StrSplit(lines[lineIndex], ",")
            if (fields.Length < 14) { ; Minimum required fields for new schema
                continue
            }

            ; Filter by session if requested
            if (!filterBySession || fields[2] = sessionId) {
                try {
                    ; Parse core fields (1-indexed)
                    execution_type := Trim(fields[4])
                    macro_name := Trim(fields[5])
                    layer := IsNumber(fields[6]) ? Integer(fields[6]) : 1
                    execution_time := IsNumber(fields[7]) ? Integer(fields[7]) : 0
                    total_boxes := IsNumber(fields[8]) ? Integer(fields[8]) : 0
                    ; performance_grade field removed
                    session_active_time := IsNumber(fields[13]) ? Integer(fields[13]) : 0

                    ; Track latest active time for rate calculations
                    if (session_active_time > latestActiveTime) {
                        latestActiveTime := session_active_time
                    }

                    ; Accumulate basic stats
                    stats["total_executions"]++
                    stats["total_boxes"] += total_boxes
                    stats["total_execution_time"] += execution_time
                    executionTimes.Push(execution_time)

                    ; Count execution types
                    if (execution_type = "clear") {
                        stats["clear_executions_count"]++
                    } else if (execution_type = "json_profile") {
                        stats["json_profile_executions_count"]++
                    } else {
                        stats["macro_executions_count"]++
                    }

                    ; Count buttons and layers
                    if (!buttonCount.Has(macro_name)) {
                        buttonCount[macro_name] := 0
                    }
                    buttonCount[macro_name]++

                    if (!layerCount.Has(layer)) {
                        layerCount[layer] := 0
                    }
                    layerCount[layer]++

                    ; Performance grade tracking removed

                    ; Parse degradation assignments from new CSV format (field 9)
                    if (fields.Length >= 9) {
                        degradation_field := Trim(fields[9])
                        ; Remove quotes if present
                        degradation_field := StrReplace(degradation_field, '"', "")
                        degradation_field := StrReplace(degradation_field, "'", "")

                        if (degradation_field != "" && degradation_field != "clear") {
                            ; Split degradation assignments and count each type
                            degradations := StrSplit(degradation_field, ",")
                            for degradation in degradations {
                                degradation := Trim(degradation)
                                switch degradation {
                                    case "smudge":
                                        stats["smudge_total"]++
                                    case "glare":
                                        stats["glare_total"]++
                                    case "splashes":
                                        stats["splashes_total"]++
                                    case "partial_blockage":
                                        stats["partial_blockage_total"]++
                                    case "full_blockage":
                                        stats["full_blockage_total"]++
                                    case "light_flare":
                                        stats["light_flare_total"]++
                                    case "rain":
                                        stats["rain_total"]++
                                    case "haze":
                                        stats["haze_total"]++
                                    case "snow":
                                        stats["snow_total"]++
                                }
                            }
                        } else {
                            stats["clear_total"]++
                        }
                    }

                } catch {
                    continue ; Skip malformed rows
                }
            }
        }

        ; Update session active time
        if (latestActiveTime > 0) {
            stats["session_active_time"] := latestActiveTime
        }

        ; Calculate derived stats
        if (stats["total_executions"] > 0) {
            stats["average_execution_time"] := Round(stats["total_execution_time"] / stats["total_executions"], 1)
        }

        ; Calculate hourly rates if we have active time
        if (stats["session_active_time"] > 5000) { ; At least 5 seconds
            activeTimeHours := stats["session_active_time"] / 3600000
            stats["boxes_per_hour"] := Round(stats["total_boxes"] / activeTimeHours, 1)
            stats["executions_per_hour"] := Round(stats["total_executions"] / activeTimeHours, 1)
        }

        ; Find most used button and layer
        maxButtonCount := 0
        maxLayerCount := 0
        for button, count in buttonCount {
            if (count > maxButtonCount) {
                maxButtonCount := count
                stats["most_used_button"] := button
            }
        }
        for layer, count in layerCount {
            if (count > maxLayerCount) {
                maxLayerCount := count
                stats["most_active_layer"] := layer
            }
        }

        ; Performance grades removed

    } catch as e {
        ; Handle file read errors gracefully
        UpdateStatus("📊 Stats read warning: " . e.Message)
    }

    return stats
}

; ===== UNIFIED STATISTICS RECORDING SYSTEM =====
; This is the single source of truth for all execution statistics
RecordExecutionStats(macroKey, executionStartTime, executionType, events, analysisRecord := "") {
    global breakMode, recording, currentLayer, annotationMode, totalActiveTime, lastActiveTime, sessionStartTime

    ; Skip if breakMode is true (don't track during break)
    if (breakMode) {
        return
    }

    ; Skip if recording to avoid tracking during macro recording
    if (recording) {
        return
    }

    ; Calculate execution metrics
    execution_time_ms := A_TickCount - executionStartTime
    timestamp := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")

    ; Update active time before recording to ensure accuracy
    UpdateActiveTime()

    ; Calculate current session active time in milliseconds
    current_session_active_time_ms := GetCurrentSessionActiveTime()

    ; Initialize comprehensive data structure
    executionData := Map()
    executionData["timestamp"] := timestamp
    executionData["execution_type"] := executionType
    executionData["button_key"] := macroKey
    executionData["layer"] := currentLayer
    executionData["execution_time_ms"] := execution_time_ms
    executionData["canvas_mode"] := (annotationMode = "Wide" ? "wide" : "narrow")
    executionData["session_active_time_ms"] := current_session_active_time_ms
    executionData["break_mode_active"] := false

    ; Initialize all degradation counts to zero
    executionData["smudge_count"] := 0
    executionData["glare_count"] := 0
    executionData["splashes_count"] := 0
    executionData["partial_blockage_count"] := 0
    executionData["full_blockage_count"] := 0
    executionData["light_flare_count"] := 0
    executionData["rain_count"] := 0
    executionData["haze_count"] := 0
    executionData["snow_count"] := 0
    executionData["clear_count"] := 0

    ; Initialize other fields
    executionData["total_boxes"] := 0
    executionData["degradation_assignments"] := ""
    executionData["severity_level"] := "medium"
    executionData["annotation_details"] := ""
    executionData["execution_success"] := "true"
    executionData["error_details"] := ""

    ; Process data based on execution type with improved accuracy
    if (executionType = "macro") {
        ; For macro executions: analyze events and analysis record
        if (IsObject(analysisRecord) && analysisRecord.HasOwnProp("boundingBoxCount")) {
            executionData["total_boxes"] := analysisRecord.boundingBoxCount
            if (analysisRecord.HasOwnProp("degradationAssignments") && analysisRecord.degradationAssignments != "") {
                executionData["degradation_assignments"] := analysisRecord.degradationAssignments
                ProcessDegradationCounts(executionData, analysisRecord.degradationAssignments)
            } else {
                ; No degradation assignments means clear
                executionData["degradation_assignments"] := "clear"
                executionData["clear_count"] := 1
            }
        } else {
            ; Fallback: analyze events directly
            bbox_count := 0
            degradation_list := []

            for event in events {
                if (event.type = "drag" || event.type = "bbox" || event.type = "boundingBox") {
                    bbox_count++
                }
                ; Extract degradation assignments from events if available
                if (event.HasOwnProp("degradation") && event.degradation != "") {
                    degradation_list.Push(event.degradation)
                }
            }

            executionData["total_boxes"] := bbox_count
            if (degradation_list.Length > 0) {
                degradation_string := ""
                for i, deg in degradation_list {
                    degradation_string .= (i > 1 ? "," : "") . deg
                }
                executionData["degradation_assignments"] := degradation_string
                ProcessDegradationCounts(executionData, degradation_string)
            } else {
                ; No degradations found means clear
                executionData["degradation_assignments"] := "clear"
                executionData["clear_count"] := executionData["total_boxes"] > 0 ? executionData["total_boxes"] : 1
            }
        }

    } else if (executionType = "json_profile") {
        ; For JSON executions: extract data from analysis record
        executionData["total_boxes"] := 1  ; JSON profiles count as 1 execution

        if (IsObject(analysisRecord)) {
            if (analysisRecord.HasOwnProp("jsonDegradationName") && analysisRecord.jsonDegradationName != "") {
                executionData["degradation_assignments"] := analysisRecord.jsonDegradationName
                ProcessDegradationCounts(executionData, analysisRecord.jsonDegradationName)
            } else {
                executionData["degradation_assignments"] := "clear"
                executionData["clear_count"] := 1
            }

            if (analysisRecord.HasOwnProp("severity")) {
                executionData["severity_level"] := analysisRecord.severity
            }
            if (analysisRecord.HasOwnProp("annotationDetails")) {
                executionData["annotation_details"] := analysisRecord.annotationDetails
            }
        } else {
            ; Default for JSON without analysis record
            executionData["degradation_assignments"] := "clear"
            executionData["clear_count"] := 1
        }

    } else if (executionType = "clear") {
        ; For clear executions
        executionData["total_boxes"] := 1
        executionData["clear_count"] := 1
        executionData["degradation_assignments"] := "clear"
    }

    ; Visual feedback for successful recording
    UpdateStatus("📊 RECORDED: " . macroKey . " (" . executionType . ") - " . executionData["total_boxes"] . " boxes, " . execution_time_ms . "ms")

    ; Record to CSV with comprehensive data
    AppendToCSV(executionData)
}

; Helper function to process degradation assignments and update counts
ProcessDegradationCounts(executionData, degradationString) {
    if (degradationString = "" || degradationString = "none") {
        return
    }

    ; Split by comma and process each degradation type
    degradationTypes := StrSplit(degradationString, ",")
    for degradationType in degradationTypes {
        degradationType := Trim(StrReplace(StrReplace(degradationType, Chr(34), ""), Chr(39), ""))

        ; Map degradation types to counts (1=smudge, 2=glare, etc.)
        switch StrLower(degradationType) {
            case "smudge", "1":
                executionData["smudge_count"]++
            case "glare", "2":
                executionData["glare_count"]++
            case "splashes", "3":
                executionData["splashes_count"]++
            case "partial_blockage", "4":
                executionData["partial_blockage_count"]++
            case "full_blockage", "5":
                executionData["full_blockage_count"]++
            case "light_flare", "6":
                executionData["light_flare_count"]++
            case "rain", "7":
                executionData["rain_count"]++
            case "haze", "8":
                executionData["haze_count"]++
            case "snow", "9":
                executionData["snow_count"]++
            case "clear", "none":
                executionData["clear_count"]++
        }
    }
}

; ===== OFFLINE DATA MANAGEMENT =====
AggregateMetrics() {
    global applicationStartTime, totalActiveTime, lastActiveTime, masterStatsCSV

    ; Use CSV data for metrics aggregation
    if (!FileExist(masterStatsCSV)) {
        return {}
    }

    ; Get CSV stats for aggregation
    csvStats := ReadStatsFromCSV(false)
    totalBoxCount := csvStats["total_boxes"]
    totalExecutionTimeMs := csvStats["average_execution_time"] * csvStats["total_executions"]
    executionCount := csvStats["total_executions"]

    ; Use CSV degradation data
    degradationSummaryStr := "CSV-based degradation summary"

    ; Calculate active time in seconds
    currentActiveTime := totalActiveTime
    if (lastActiveTime > 0) {
        currentActiveTime += (A_TickCount - lastActiveTime)
    }
    activeTimeSeconds := Round(currentActiveTime / 1000, 2)

    ; Generate safe taskId - applicationStartTime is A_TickCount (number), not a timestamp
    safeTaskId := "session_" . (IsSet(currentSessionId) ? StrReplace(currentSessionId, "sess_", "") : FormatTime(A_Now, "yyyyMMdd_HHmmss"))

    return {
        timestamp: FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss"),
        taskId: safeTaskId,
        totalBoxCount: totalBoxCount,
        totalExecutionTimeMs: totalExecutionTimeMs,
        activeTimeSeconds: activeTimeSeconds,
        executionCount: executionCount,
        degradationSummary: degradationSummaryStr
    }
}

SaveMetricsToFile(metrics) {
    global currentUsername, persistentDataFile, dailyStatsFile, offlineLogFile

    try {
        ; For simplified implementation, append to log files
        ; In a full JSON implementation, you'd parse and update the JSON objects

        timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")

        ; Append to persistent log
        persistentLog := A_ScriptDir . "\data\persistent_log.txt"
        logEntry := timestamp . " - " . currentUsername . " - Boxes:" . metrics.totalBoxCount . " Time:" . metrics.totalExecutionTimeMs . "ms Sessions:" . metrics.executionCount . "`n"
        FileAppend(logEntry, persistentLog)

        ; Append to daily log
        dailyLog := A_ScriptDir . "\data\daily_log.txt"
        FileAppend(logEntry, dailyLog)

        ; Log successful save
        LogOfflineActivity("Saved metrics for " . currentUsername . ": " . metrics.totalBoxCount . " boxes")

    } catch Error as e {
        throw Error("Failed to save metrics: " . e.Message)
    }
}

GetDailyStats() {
    dailyLog := A_ScriptDir . "\data\daily_log.txt"

    stats := {
        totalBoxes: 0,
        totalTime: 0,
        totalSessions: 0
    }

    if (FileExist(dailyLog)) {
        try {
            content := FileRead(dailyLog)

            ; Count sessions (lines in log)
            Loop Parse, content, "`n", "`r" {
                if (Trim(A_LoopField) != "") {
                    stats.totalSessions++

                    ; Extract boxes and time from each line
                    ; Format: timestamp - username - Boxes:X Time:Yms Sessions:Z
                    if (RegExMatch(A_LoopField, "Boxes:(\d+)", &boxMatch)) {
                        stats.totalBoxes += Integer(boxMatch[1])
                    }
                    if (RegExMatch(A_LoopField, "Time:(\d+)ms", &timeMatch)) {
                        stats.totalTime += Integer(timeMatch[1])
                    }
                }
            }
        } catch {
            ; If reading fails, return zeros
        }
    }

    return stats
}

GetLifetimeStats() {
    persistentLog := A_ScriptDir . "\data\persistent_log.txt"

    stats := {
        totalBoxes: 0,
        totalTime: 0,
        totalSessions: 0
    }

    if (FileExist(persistentLog)) {
        try {
            content := FileRead(persistentLog)

            ; Count sessions (lines in log)
            Loop Parse, content, "`n", "`r" {
                if (Trim(A_LoopField) != "") {
                    stats.totalSessions++

                    ; Extract boxes and time from each line
                    if (RegExMatch(A_LoopField, "Boxes:(\d+)", &boxMatch)) {
                        stats.totalBoxes += Integer(boxMatch[1])
                    }
                    if (RegExMatch(A_LoopField, "Time:(\d+)ms", &timeMatch)) {
                        stats.totalTime += Integer(timeMatch[1])
                    }
                }
            }
        } catch {
            ; If reading fails, return zeros
        }
    }

    return stats
}

; ===== CSV FUNCTIONS =====
; NOTE: InitializeCSVFile function is defined earlier in this file

AppendToCSV(executionData) {
    ; Use CSV-only approach - no real-time ingestion
    return AppendToCSVFile(executionData)
}

AppendToCSVFile(executionData) {
    global masterStatsCSV, currentSessionId, currentUsername

    try {
        ; Ensure CSV file exists with headers
        if (!FileExist(masterStatsCSV)) {
            header := "timestamp,session_id,username,execution_type,button_key,layer,execution_time_ms,total_boxes,degradation_assignments,severity_level,canvas_mode,session_active_time_ms,break_mode_active,smudge_count,glare_count,splashes_count,partial_blockage_count,full_blockage_count,light_flare_count,rain_count,haze_count,snow_count,clear_count,annotation_details,execution_success,error_details`n"
            FileAppend(header, masterStatsCSV)
        }

        ; Build CSV row with all required fields
        row := executionData["timestamp"] . ","
        row .= currentSessionId . ","
        row .= currentUsername . ","
        row .= executionData["execution_type"] . ","
        row .= (executionData.Has("button_key") ? executionData["button_key"] : "") . ","
        row .= executionData["layer"] . ","
        row .= executionData["execution_time_ms"] . ","
        row .= executionData["total_boxes"] . ","
        row .= (executionData.Has("degradation_assignments") ? executionData["degradation_assignments"] : "") . ","
        row .= executionData["severity_level"] . ","
        row .= executionData["canvas_mode"] . ","
        row .= executionData["session_active_time_ms"] . ","
        row .= (executionData.Has("break_mode_active") ? (executionData["break_mode_active"] ? "true" : "false") : "false") . ","

        ; Degradation counts (ensure all are included)
        row .= (executionData.Has("smudge_count") ? executionData["smudge_count"] : 0) . ","
        row .= (executionData.Has("glare_count") ? executionData["glare_count"] : 0) . ","
        row .= (executionData.Has("splashes_count") ? executionData["splashes_count"] : 0) . ","
        row .= (executionData.Has("partial_blockage_count") ? executionData["partial_blockage_count"] : 0) . ","
        row .= (executionData.Has("full_blockage_count") ? executionData["full_blockage_count"] : 0) . ","
        row .= (executionData.Has("light_flare_count") ? executionData["light_flare_count"] : 0) . ","
        row .= (executionData.Has("rain_count") ? executionData["rain_count"] : 0) . ","
        row .= (executionData.Has("haze_count") ? executionData["haze_count"] : 0) . ","
        row .= (executionData.Has("snow_count") ? executionData["snow_count"] : 0) . ","
        row .= (executionData.Has("clear_count") ? executionData["clear_count"] : 0) . ","

        ; Additional fields
        row .= (executionData.Has("annotation_details") ? executionData["annotation_details"] : "") . ","
        row .= (executionData.Has("execution_success") ? executionData["execution_success"] : "true") . ","
        row .= (executionData.Has("error_details") ? executionData["error_details"] : "") . "`n"

        FileAppend(row, masterStatsCSV)
        return true

    } catch Error as e {
        UpdateStatus("⚠️ CSV write failed: " . e.Message)
        return false
    }
}

; ===== EXPORT FUNCTIONS =====
ExportStatsData(statsMenuGui := "") {
    global masterStatsCSV

    if (!FileExist(masterStatsCSV)) {
        MsgBox("📊 No data to export yet`n`nStart using macros to generate performance data!", "Info", "Icon!")
        return
    }

    ; Export to Documents folder for accessibility from zipped execution
    exportPath := documentsDir . "\MacroMaster_Stats_Export_" . FormatTime(A_Now, "yyyyMMdd_HHmmss") . ".csv"

    try {
        FileCopy(masterStatsCSV, exportPath)
        MsgBox("✅ Stats exported successfully!`n`nFile: " . exportPath . "`n`nYou can open this file in Excel or other tools.", "Export Complete", "Icon!")
        UpdateStatus("💾 Stats data exported to " . exportPath)
    } catch Error as e {
        MsgBox("❌ Export failed: " . e.Message, "Error", "Icon!")
    }
}

; ===== HELPER FUNCTIONS =====
UpdateActiveTime() {
    global breakMode, totalActiveTime, lastActiveTime

    if (!breakMode && lastActiveTime > 0) {
        totalActiveTime += A_TickCount - lastActiveTime
        lastActiveTime := A_TickCount
    } else if (breakMode) {
        ; During break mode, don't accumulate active time but keep lastActiveTime updated
        lastActiveTime := A_TickCount
    }
}

; Get current session active time in milliseconds
GetCurrentSessionActiveTime() {
    global totalActiveTime, lastActiveTime, breakMode

    if (breakMode) {
        return totalActiveTime
    } else {
        return totalActiveTime + (A_TickCount - lastActiveTime)
    }
}

; ===== REAL-TIME DATA INGESTION =====
SendDataToIngestionService(endpoint, data) {
    global ingestionServiceUrl, realtimeEnabled

    if (!realtimeEnabled) {
        return false
    }

    try {
        ; Convert data to JSON
        jsonData := ""
        for key, value in data {
            if (jsonData != "") {
                jsonData .= ","
            }
            ; Escape quotes in values
            escapedValue := StrReplace(StrReplace(value, "\", "\\"), '"', '\"')
            jsonData .= '"' . key . '":"' . escapedValue . '"'
        }
        jsonData := "{" . jsonData . "}"

        ; Use curl or similar to send HTTP POST
        ; For Windows, we'll use a simple COM object approach or PowerShell
        result := SendHttpPost(ingestionServiceUrl . endpoint, jsonData)

        return (result != "")
    } catch Error as e {
        ; Log error but don't break execution
        UpdateStatus("⚠️ Data send failed: " . e.Message)
        return false
    }
}

SendHttpPost(url, jsonData) {
    ; Use PowerShell to send HTTP request (most reliable on Windows)
    ; Run silently without showing command prompt
    psCommand := 'powershell -WindowStyle Hidden -Command "& {'
    psCommand .= '$headers = @{\"Content-Type\"=\"application/json\"}; '
    psCommand .= '$body = @\"' . jsonData . '\"@; '
    psCommand .= 'try { $response = Invoke-WebRequest -Uri \"' . url . '\" -Method POST -Headers $headers -Body $body -TimeoutSec 5; $response.StatusCode } catch { \"ERROR\" }'
    psCommand .= '}"'

    ; Execute PowerShell command silently
    execResult := RunWaitOne(psCommand)
    return execResult
}

; ===== RESET STATS FUNCTION =====
ResetAllStats() {
    global masterStatsCSV

    result := MsgBox("This will permanently delete all macro execution statistics!`n`nAre you sure you want to reset all stats?", "Reset Statistics", "YesNo Icon!")

    if (result = "Yes") {
        try {
            ; Delete the CSV file
            if FileExist(masterStatsCSV) {
                FileDelete(masterStatsCSV)
            }

            ; Reinitialize CSV file
            InitializeCSVFile()

            UpdateStatus("📊 All statistics have been reset")
            MsgBox("Statistics reset complete!`n`nAll execution data has been cleared.", "Reset Complete", "Icon!")

        } catch Error as e {
            UpdateStatus("⚠️ Failed to reset statistics: " . e.Message)
            MsgBox("Failed to reset statistics: " . e.Message, "Error", "Icon!")
        }
    }
}

; ===== TEST STATS RECORDING =====
; NOTE: TestStatsRecording function removed as it depends on ExecuteMacro which is defined in the main application
; Use external test files for comprehensive testing

; ===== BUILT-IN STATS GUI =====
ShowBuiltInStatsGUI(filterMode, stats) {
    ; Create a simple built-in stats display
    statsGui := Gui("+Resize", "📊 MacroMaster Statistics")
    statsGui.BackColor := "0xF0F0F0"
    statsGui.SetFont("s10")

    statsGui.Add("Text", "x20 y20 w400 h30 Center", "📊 Execution Statistics")

    ; Display basic stats
    y := 60
    statsGui.Add("Text", "x20 y" . y, "Total Executions: " . stats["total_executions"])
    y += 25
    statsGui.Add("Text", "x20 y" . y, "Total Boxes: " . stats["total_boxes"])
    y += 25
    statsGui.Add("Text", "x20 y" . y, "Average Time: " . stats["average_execution_time"] . "ms")
    y += 25
    statsGui.Add("Text", "x20 y" . y, "Boxes/Hour: " . stats["boxes_per_hour"])
    y += 25
    statsGui.Add("Text", "x20 y" . y, "Executions/Hour: " . stats["executions_per_hour"])

    ; Close button
    statsGui.Add("Button", "x150 y" . (y + 30) . " w100 h30", "Close").OnEvent("Click", (*) => statsGui.Destroy())

    statsGui.Show("w450 h" . (y + 80))
}

; ===== RECORD CLEAR DEGRADATION EXECUTION =====
RecordClearDegradationExecution(buttonName, executionStartTime) {
    global breakMode, currentLayer, canvasType, clearDegradationCount, annotationMode

    ; Skip if breakMode is true (don't track during break)
    if (breakMode) {
        return
    }

    ; Calculate execution_time_ms
    execution_time_ms := A_TickCount - executionStartTime

    ; Get current timestamp
    timestamp := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")

    ; Create execution data structure for clear degradation execution
    executionData := Map()
    executionData["timestamp"] := timestamp
    executionData["execution_type"] := "macro"  ; This is a macro execution with clear degradation
    executionData["button_key"] := buttonName
    executionData["layer"] := currentLayer
    executionData["execution_time_ms"] := execution_time_ms
    executionData["total_boxes"] := 1  ; Count as 1 box with clear degradation
    executionData["degradation_assignments"] := "clear"  ; Clear degradation type
    executionData["degradation_summary"] := "No degradation present"
    executionData["status"] := "submitted"
    executionData["severity_level"] := "none"
    executionData["canvas_mode"] := (annotationMode = "Wide" ? "wide" : "narrow")

    ; Clear degradation counts (all zeros except clear count)
    executionData["smudge_count"] := 0
    executionData["glare_count"] := 0
    executionData["splashes_count"] := 0

    ; Increment session clear degradation count
    clearDegradationCount++

    ; Update active time before recording to CSV to ensure accurate time tracking
    UpdateActiveTime()

    ; Call AppendToCSV with clear execution data
    AppendToCSV(executionData)
}

; ===== OFFLINE ACTIVITY LOGGING =====
LogOfflineActivity(message) {
    global offlineLogFile
    timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
    logEntry := timestamp . " - " . message . "`n"
    try {
        FileAppend(logEntry, offlineLogFile)
    } catch {
        ; Silent fail for logging to prevent cascading errors
    }
}