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
}

; ===== CSV FILE INITIALIZATION =====
InitializeCSVFile() {
    global masterStatsCSV, documentsDir, workDir, sessionId

    try {
        ; Create full directory structure in Documents for portable execution
        if (!DirExist(documentsDir)) {
            DirCreate(documentsDir)
        }

        if (!DirExist(workDir)) {
            DirCreate(workDir)
        }

        ; Create CSV with streamlined header optimized for tracking and display
        if (!FileExist(masterStatsCSV)) {
            header := "timestamp,session_id,username,execution_type,button_key,layer,execution_time_ms,total_boxes,degradation_assignments,severity_level,canvas_mode,session_active_time_ms,break_mode_active,smudge_count,glare_count,splashes_count,partial_blockage_count,full_blockage_count,light_flare_count,rain_count,haze_count,snow_count,clear_count,annotation_details,execution_success,error_details`n"
            FileAppend(header, masterStatsCSV, "UTF-8")
        }
    } catch as e {
        UpdateStatus("⚠️ CSV setup failed")
    }
}

InitializeRealtimeSession() {
    ; Start a new session with the real-time service
    sessionData := Map()
    sessionData["session_id"] := currentSessionId
    sessionData["username"] := currentUsername
    sessionData["canvas_mode"] := annotationMode

    if (!SendDataToIngestionService("/session/start", sessionData)) {
        realtimeEnabled := false
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

        return true
    } catch Error as e {
        UpdateStatus("⚠️ Error initializing offline storage")
        return false
    }
}

; ===== STATISTICS DISPLAY FUNCTIONS =====
ShowStatsMenu() {
    global masterStatsCSV, darkMode, currentSessionId

    ; Create simple text-based stats display
    statsGui := Gui("+Resize", "📊 MacroMaster Statistics")
    statsGui.BackColor := darkMode ? "0x1E1E1E" : "0xF5F5F5"
    statsGui.SetFont("s9", "Consolas")

    ; Get all-time and today's stats
    allStats := ReadStatsFromCSV(false)
    todayStats := GetTodayStats()

    ; Build text display
    y := 10

    ; === ALL-TIME STATS ===
    AddStatsHeader(statsGui, y, "═══ ALL-TIME STATISTICS ═══")
    y += 30

    AddStatsLine(statsGui, y, "Total Executions:", allStats["total_executions"])
    y += 20
    AddStatsLine(statsGui, y, "Total Boxes:", allStats["total_boxes"])
    y += 20
    AddStatsLine(statsGui, y, "Avg Execution Time:", allStats["average_execution_time"] . " ms")
    y += 20

    ; Session info
    sessionTime := FormatMilliseconds(allStats["session_active_time"])
    AddStatsLine(statsGui, y, "Active Time:", sessionTime)
    y += 20

    ; Hourly rates
    AddStatsLine(statsGui, y, "Boxes/Hour:", allStats["boxes_per_hour"])
    y += 20
    AddStatsLine(statsGui, y, "Executions/Hour:", allStats["executions_per_hour"])
    y += 30

    ; === DEGRADATION BREAKDOWN (ALL-TIME) ===
    AddStatsHeader(statsGui, y, "═══ DEGRADATION TOTALS (ALL-TIME) ═══")
    y += 30

    AddStatsLine(statsGui, y, "Smudge:", allStats["smudge_total"])
    y += 20
    AddStatsLine(statsGui, y, "Glare:", allStats["glare_total"])
    y += 20
    AddStatsLine(statsGui, y, "Splashes:", allStats["splashes_total"])
    y += 20
    AddStatsLine(statsGui, y, "Partial Blockage:", allStats["partial_blockage_total"])
    y += 20
    AddStatsLine(statsGui, y, "Full Blockage:", allStats["full_blockage_total"])
    y += 20
    AddStatsLine(statsGui, y, "Light Flare:", allStats["light_flare_total"])
    y += 20
    AddStatsLine(statsGui, y, "Rain:", allStats["rain_total"])
    y += 20
    AddStatsLine(statsGui, y, "Haze:", allStats["haze_total"])
    y += 20
    AddStatsLine(statsGui, y, "Snow:", allStats["snow_total"])
    y += 20
    AddStatsLine(statsGui, y, "Clear:", allStats["clear_total"])
    y += 30

    ; === TODAY'S STATS ===
    AddStatsHeader(statsGui, y, "═══ TODAY'S STATISTICS ═══")
    y += 30

    AddStatsLine(statsGui, y, "Executions:", todayStats["total_executions"])
    y += 20
    AddStatsLine(statsGui, y, "Boxes:", todayStats["total_boxes"])
    y += 20
    AddStatsLine(statsGui, y, "Avg Execution Time:", todayStats["average_execution_time"] . " ms")
    y += 20
    AddStatsLine(statsGui, y, "Active Time:", FormatMilliseconds(todayStats["session_active_time"]))
    y += 20
    AddStatsLine(statsGui, y, "Boxes/Hour:", todayStats["boxes_per_hour"])
    y += 20
    AddStatsLine(statsGui, y, "Executions/Hour:", todayStats["executions_per_hour"])
    y += 30

    ; === TODAY'S DEGRADATIONS ===
    AddStatsHeader(statsGui, y, "═══ DEGRADATION TOTALS (TODAY) ═══")
    y += 30

    AddStatsLine(statsGui, y, "Smudge:", todayStats["smudge_total"])
    y += 20
    AddStatsLine(statsGui, y, "Glare:", todayStats["glare_total"])
    y += 20
    AddStatsLine(statsGui, y, "Splashes:", todayStats["splashes_total"])
    y += 20
    AddStatsLine(statsGui, y, "Partial Blockage:", todayStats["partial_blockage_total"])
    y += 20
    AddStatsLine(statsGui, y, "Full Blockage:", todayStats["full_blockage_total"])
    y += 20
    AddStatsLine(statsGui, y, "Light Flare:", todayStats["light_flare_total"])
    y += 20
    AddStatsLine(statsGui, y, "Rain:", todayStats["rain_total"])
    y += 20
    AddStatsLine(statsGui, y, "Haze:", todayStats["haze_total"])
    y += 20
    AddStatsLine(statsGui, y, "Snow:", todayStats["snow_total"])
    y += 20
    AddStatsLine(statsGui, y, "Clear:", todayStats["clear_total"])
    y += 30

    ; === MACRO DETAILS ===
    AddStatsHeader(statsGui, y, "═══ MACRO DETAILS ═══")
    y += 30

    AddStatsLine(statsGui, y, "Most Used Button:", allStats["most_used_button"])
    y += 20
    AddStatsLine(statsGui, y, "Most Active Layer:", allStats["most_active_layer"])
    y += 20

    ; Calculate efficiency metrics
    if (allStats["total_executions"] > 0 && allStats["session_active_time"] > 0) {
        activeTimeSeconds := allStats["session_active_time"] / 1000.0
        totalExecTimeSeconds := allStats["total_execution_time"] / 1000.0
        efficiency := Round((totalExecTimeSeconds / activeTimeSeconds) * 100, 1)
        AddStatsLine(statsGui, y, "Efficiency Ratio:", efficiency . "%")
        y += 20

        avgBoxesPerExec := Round(allStats["total_boxes"] / allStats["total_executions"], 1)
        AddStatsLine(statsGui, y, "Avg Boxes/Execution:", avgBoxesPerExec)
        y += 20
    }

    AddStatsLine(statsGui, y, "Macro Executions:", allStats["macro_executions_count"])
    y += 20
    AddStatsLine(statsGui, y, "JSON Executions:", allStats["json_profile_executions_count"])
    y += 20
    AddStatsLine(statsGui, y, "Session ID:", SubStr(currentSessionId, 6))
    y += 30

    ; Buttons
    btnExport := statsGui.Add("Button", "x20 y" . (y + 10) . " w120 h30", "💾 Export")
    btnExport.SetFont("s9")
    btnExport.OnEvent("Click", (*) => ExportStatsData(statsGui))

    btnReset := statsGui.Add("Button", "x150 y" . (y + 10) . " w120 h30", "🗑️ Reset")
    btnReset.SetFont("s9")
    btnReset.OnEvent("Click", (*) => ResetAllStats())

    btnClose := statsGui.Add("Button", "x280 y" . (y + 10) . " w120 h30", "❌ Close")
    btnClose.SetFont("s9")
    btnClose.OnEvent("Click", (*) => statsGui.Destroy())

    statsGui.Show("w420 h" . (y + 60))
}

; Helper function to add section headers
AddStatsHeader(gui, y, text) {
    global darkMode
    header := gui.Add("Text", "x20 y" . y . " w380", text)
    header.SetFont("s9 bold", "Consolas")
    header.Opt("c" . (darkMode ? "0xFFFFFF" : "0x000000"))
}

; Helper function to add stat lines
AddStatsLine(gui, y, label, value) {
    global darkMode
    labelCtrl := gui.Add("Text", "x40 y" . y . " w200", label)
    labelCtrl.SetFont("s9", "Consolas")
    labelCtrl.Opt("c" . (darkMode ? "0xCCCCCC" : "0x333333"))

    valueCtrl := gui.Add("Text", "x250 y" . y . " w150 Right", String(value))
    valueCtrl.SetFont("s9 bold", "Consolas")
    valueCtrl.Opt("c" . (darkMode ? "0xFFFFFF" : "0x000000"))
}

; Get today's stats only
GetTodayStats() {
    global masterStatsCSV

    stats := Map()
    stats["total_executions"] := 0
    stats["total_boxes"] := 0
    stats["total_execution_time"] := 0
    stats["average_execution_time"] := 0
    stats["session_active_time"] := 0
    stats["boxes_per_hour"] := 0
    stats["executions_per_hour"] := 0
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
            return stats
        }

        ; Get today's date in YYYY-MM-DD format
        today := FormatTime(A_Now, "yyyy-MM-dd")

        Loop lines.Length - 1 {
            lineIndex := A_Index + 1
            if (lineIndex > lines.Length || Trim(lines[lineIndex]) = "") {
                continue
            }

            fields := StrSplit(lines[lineIndex], ",")
            if (fields.Length < 14) {
                continue
            }

            ; Check if timestamp starts with today's date
            timestamp := Trim(fields[1])
            if (SubStr(timestamp, 1, 10) = today) {
                try {
                    execution_time := IsNumber(fields[7]) ? Integer(fields[7]) : 0
                    total_boxes := IsNumber(fields[8]) ? Integer(fields[8]) : 0
                    session_active_time := IsNumber(fields[12]) ? Integer(fields[12]) : 0

                    stats["total_executions"]++
                    stats["total_boxes"] += total_boxes
                    stats["total_execution_time"] += execution_time

                    if (session_active_time > stats["session_active_time"]) {
                        stats["session_active_time"] := session_active_time
                    }

                    ; Parse degradations from fields 14-23
                    if (fields.Length >= 23) {
                        stats["smudge_total"] += IsNumber(fields[14]) ? Integer(fields[14]) : 0
                        stats["glare_total"] += IsNumber(fields[15]) ? Integer(fields[15]) : 0
                        stats["splashes_total"] += IsNumber(fields[16]) ? Integer(fields[16]) : 0
                        stats["partial_blockage_total"] += IsNumber(fields[17]) ? Integer(fields[17]) : 0
                        stats["full_blockage_total"] += IsNumber(fields[18]) ? Integer(fields[18]) : 0
                        stats["light_flare_total"] += IsNumber(fields[19]) ? Integer(fields[19]) : 0
                        stats["rain_total"] += IsNumber(fields[20]) ? Integer(fields[20]) : 0
                        stats["haze_total"] += IsNumber(fields[21]) ? Integer(fields[21]) : 0
                        stats["snow_total"] += IsNumber(fields[22]) ? Integer(fields[22]) : 0
                        stats["clear_total"] += IsNumber(fields[23]) ? Integer(fields[23]) : 0
                    }
                } catch {
                    continue
                }
            }
        }

        ; Calculate average
        if (stats["total_executions"] > 0) {
            stats["average_execution_time"] := Round(stats["total_execution_time"] / stats["total_executions"], 1)
        }

        ; Calculate hourly rates based on active time
        if (stats["session_active_time"] > 5000) { ; At least 5 seconds
            activeTimeHours := stats["session_active_time"] / 3600000
            stats["boxes_per_hour"] := Round(stats["total_boxes"] / activeTimeHours, 1)
            stats["executions_per_hour"] := Round(stats["total_executions"] / activeTimeHours, 1)
        }

    } catch {
        ; Return empty stats on error
    }

    return stats
}

; Format milliseconds to readable time
FormatMilliseconds(ms) {
    if (ms < 1000) {
        return ms . " ms"
    } else if (ms < 60000) {
        return Round(ms / 1000, 1) . " sec"
    } else if (ms < 3600000) {
        minutes := Floor(ms / 60000)
        seconds := Round(Mod(ms, 60000) / 1000)
        return minutes . " min " . seconds . " sec"
    } else {
        hours := Floor(ms / 3600000)
        minutes := Round(Mod(ms, 3600000) / 60000)
        return hours . " hr " . minutes . " min"
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
                    session_active_time := IsNumber(fields[12]) ? Integer(fields[12]) : 0

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

                    ; Read degradation counts directly from CSV fields (14-23)
                    ; Headers: ...break_mode_active,smudge_count,glare_count,splashes_count,partial_blockage_count,full_blockage_count,light_flare_count,rain_count,haze_count,snow_count,clear_count...
                    if (fields.Length >= 23) {
                        stats["smudge_total"] += IsNumber(fields[14]) ? Integer(fields[14]) : 0
                        stats["glare_total"] += IsNumber(fields[15]) ? Integer(fields[15]) : 0
                        stats["splashes_total"] += IsNumber(fields[16]) ? Integer(fields[16]) : 0
                        stats["partial_blockage_total"] += IsNumber(fields[17]) ? Integer(fields[17]) : 0
                        stats["full_blockage_total"] += IsNumber(fields[18]) ? Integer(fields[18]) : 0
                        stats["light_flare_total"] += IsNumber(fields[19]) ? Integer(fields[19]) : 0
                        stats["rain_total"] += IsNumber(fields[20]) ? Integer(fields[20]) : 0
                        stats["haze_total"] += IsNumber(fields[21]) ? Integer(fields[21]) : 0
                        stats["snow_total"] += IsNumber(fields[22]) ? Integer(fields[22]) : 0
                        stats["clear_total"] += IsNumber(fields[23]) ? Integer(fields[23]) : 0
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

    } catch {
        ; Handle file read errors gracefully
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
    global currentSessionId, currentUsername, documentsDir

    ; Write to CSV (backup)
    csvSuccess := AppendToCSVFile(executionData)

    ; Also write to SQLite database
    try {
        ; Build JSON for Python script
        jsonData := "{"
        jsonData .= '`n  "timestamp": "' . executionData["timestamp"] . '",'
        jsonData .= '`n  "session_id": "' . currentSessionId . '",'
        jsonData .= '`n  "username": "' . currentUsername . '",'
        jsonData .= '`n  "execution_type": "' . executionData["execution_type"] . '",'
        jsonData .= '`n  "button_key": "' . (executionData.Has("button_key") ? executionData["button_key"] : "") . '",'
        jsonData .= '`n  "layer": ' . executionData["layer"] . ','
        jsonData .= '`n  "execution_time_ms": ' . executionData["execution_time_ms"] . ','
        jsonData .= '`n  "total_boxes": ' . executionData["total_boxes"] . ','
        jsonData .= '`n  "degradation_assignments": "' . (executionData.Has("degradation_assignments") ? executionData["degradation_assignments"] : "") . '",'
        jsonData .= '`n  "severity_level": "' . executionData["severity_level"] . '",'
        jsonData .= '`n  "canvas_mode": "' . executionData["canvas_mode"] . '",'
        jsonData .= '`n  "session_active_time_ms": ' . executionData["session_active_time_ms"] . ','
        jsonData .= '`n  "break_mode_active": ' . (executionData.Has("break_mode_active") ? (executionData["break_mode_active"] ? "true" : "false") : "false") . ','
        jsonData .= '`n  "smudge_count": ' . (executionData.Has("smudge_count") ? executionData["smudge_count"] : 0) . ','
        jsonData .= '`n  "glare_count": ' . (executionData.Has("glare_count") ? executionData["glare_count"] : 0) . ','
        jsonData .= '`n  "splashes_count": ' . (executionData.Has("splashes_count") ? executionData["splashes_count"] : 0) . ','
        jsonData .= '`n  "partial_blockage_count": ' . (executionData.Has("partial_blockage_count") ? executionData["partial_blockage_count"] : 0) . ','
        jsonData .= '`n  "full_blockage_count": ' . (executionData.Has("full_blockage_count") ? executionData["full_blockage_count"] : 0) . ','
        jsonData .= '`n  "light_flare_count": ' . (executionData.Has("light_flare_count") ? executionData["light_flare_count"] : 0) . ','
        jsonData .= '`n  "rain_count": ' . (executionData.Has("rain_count") ? executionData["rain_count"] : 0) . ','
        jsonData .= '`n  "haze_count": ' . (executionData.Has("haze_count") ? executionData["haze_count"] : 0) . ','
        jsonData .= '`n  "snow_count": ' . (executionData.Has("snow_count") ? executionData["snow_count"] : 0) . ','
        jsonData .= '`n  "clear_count": ' . (executionData.Has("clear_count") ? executionData["clear_count"] : 0)
        jsonData .= '`n}'

        ; Write JSON to temp file (safer than command line escaping)
        tempJsonFile := documentsDir . "\MacroMaster\data\temp_execution.json"
        try FileDelete(tempJsonFile)  ; Remove if exists
        FileAppend(jsonData, tempJsonFile, "UTF-8")

        ; Call Python record script with file
        ; A_ScriptDir points to src/, so stats folder is in parent directory
        pythonScript := A_ScriptDir . "\..\stats\record_execution.py"
        if (FileExist(pythonScript) && FileExist(tempJsonFile)) {
            RunWait('python "' . pythonScript . '" --file "' . tempJsonFile . '"', A_ScriptDir . "\..", "Hide")
            ; Clean up temp file
            try FileDelete(tempJsonFile)
        }
    } catch Error as e {
        ; Silent fail - CSV backup ensures no data loss
    }

    return csvSuccess
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

    } catch {
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
    } catch {
        ; Log error but don't break execution
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

            MsgBox("Statistics reset complete!`n`nAll execution data has been cleared.", "Reset Complete", "Icon!")

        } catch Error as e {
            UpdateStatus("⚠️ Failed to reset statistics")
            MsgBox("Failed to reset statistics: " . e.Message, "Error", "Icon!")
        }
    }
}

; ===== TEST STATS RECORDING =====
; NOTE: TestStatsRecording function removed as it depends on ExecuteMacro which is defined in the main application
; Use external test files for comprehensive testing


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