; ===== STATS DATA MODULE =====
; Handles statistics persistence, aggregation, and CSV writing
; STREAMLINED: Async queue system only - no duplicate direct write functions

; ObjSave and ObjLoad are defined in ObjPersistence.ahk (included in Main.ahk)
; Suppress warnings for these external functions
#Warn VarUnset, Off

Stats_GetCsvHeader() {
    return "timestamp,session_id,username,execution_type,button_key,layer,execution_time_ms,total_boxes,degradation_assignments,severity_level,canvas_mode,session_active_time_ms,break_mode_active,smudge_count,glare_count,splashes_count,partial_blockage_count,full_blockage_count,light_flare_count,rain_count,haze_count,snow_count,clear_count,annotation_details,execution_success,error_details`n"
}

Stats_EnsureStatsFile(filePath, encoding := "") {
    if (!FileExist(filePath)) {
        header := Stats_GetCsvHeader()

        if (encoding != "")
            FileAppend(header, filePath, encoding)
        else
            FileAppend(header, filePath)
    }
}

Stats_BuildCsvRow(executionData) {
    global currentSessionId, currentUsername

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
    row .= (executionData.Has("annotation_details") ? executionData["annotation_details"] : "") . ","
    row .= (executionData.Has("execution_success") ? executionData["execution_success"] : "true") . ","
    row .= (executionData.Has("error_details") ? executionData["error_details"] : "") . "`n"

    return row
}

InitializeStatsSystem() {
    global masterStatsCSV, workDir, sessionId, currentUsername, permanentStatsFile

    ; Ensure CSV file exists
    if (!FileExist(masterStatsCSV)) {
        InitializeCSVFile()
    }

    ; Initialize permanent master stats file (NEVER gets reset)
    InitializePermanentStatsFile()

    ; Prepare temp staging area for async disk writes
}

InitializeCSVFile() {
    global masterStatsCSV, documentsDir, workDir, sessionId

    try {
        if (!DirExist(documentsDir)) {
            DirCreate(documentsDir)
        }

        if (!DirExist(workDir)) {
            DirCreate(workDir)
        }

        Stats_EnsureStatsFile(masterStatsCSV, "UTF-8")
    } catch as e {
        UpdateStatus("CSV setup failed")
    }
}

InitializePermanentStatsFile() {
    global workDir, permanentStatsFile

    try {
        permanentStatsFile := workDir . "\\master_stats_permanent.csv"
        Stats_EnsureStatsFile(permanentStatsFile, "UTF-8")
    } catch as e {
        ; Silent fail - don't break execution if permanent file can't be created
    }
}

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

; ===== STATS INITIALIZATION HELPER =====
Stats_CreateEmptyStatsMap() {
    global currentUsername, totalActiveTime

    stats := Map()

    ; Core metrics
    stats["current_username"] := currentUsername
    stats["total_executions"] := 0
    stats["macro_executions_count"] := 0
    stats["json_profile_executions_count"] := 0
    stats["clear_executions_count"] := 0
    stats["total_boxes"] := 0
    stats["total_execution_time"] := 0
    stats["average_execution_time"] := 0
    stats["session_active_time"] := totalActiveTime
    stats["boxes_per_hour"] := 0
    stats["user_summary"] := Map()
    stats["distinct_user_count"] := 0
    stats["executions_per_hour"] := 0
    stats["most_used_button"] := ""
    stats["most_active_layer"] := ""
    stats["degradation_totals"] := Map()

    ; Degradation totals (all execution types)
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

    ; Macro degradations (box count per type)
    stats["macro_smudge"] := 0
    stats["macro_glare"] := 0
    stats["macro_splashes"] := 0
    stats["macro_partial"] := 0
    stats["macro_full"] := 0
    stats["macro_flare"] := 0
    stats["macro_rain"] := 0
    stats["macro_haze"] := 0
    stats["macro_snow"] := 0
    stats["macro_clear"] := 0

    ; JSON degradations (1 selection per execution)
    stats["json_smudge"] := 0
    stats["json_glare"] := 0
    stats["json_splashes"] := 0
    stats["json_partial"] := 0
    stats["json_full"] := 0
    stats["json_flare"] := 0
    stats["json_rain"] := 0
    stats["json_haze"] := 0
    stats["json_snow"] := 0
    stats["json_clear"] := 0

    ; Severity levels
    stats["severity_low"] := 0
    stats["severity_medium"] := 0
    stats["severity_high"] := 0

    return stats
}

; ===== DEGRADATION STAT INCREMENT HELPER =====
Stats_IncrementDegradationCount(stats, degradation_name, prefix := "json_") {
    ; Increment the appropriate degradation counter in stats map
    ; prefix: "json_" for JSON executions, "macro_" for macro executions (not used here but kept for consistency)

    switch StrLower(degradation_name) {
        case "smudge", "1":
            stats[prefix . "smudge"]++
        case "glare", "2":
            stats[prefix . "glare"]++
        case "splashes", "3":
            stats[prefix . "splashes"]++
        case "partial_blockage", "4":
            stats[prefix . "partial"]++
        case "full_blockage", "5":
            stats[prefix . "full"]++
        case "light_flare", "6":
            stats[prefix . "flare"]++
        case "rain", "7":
            stats[prefix . "rain"]++
        case "haze", "8":
            stats[prefix . "haze"]++
        case "snow", "9":
            stats[prefix . "snow"]++
        case "clear", "none":
            stats[prefix . "clear"]++
    }
}

; ===== DEGRADATION COUNT INCREMENT (for executionData maps) =====
Stats_IncrementDegradationCountDirect(executionData, degradation_name) {
    ; For use with executionData maps that use "_count" suffix

    switch StrLower(degradation_name) {
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

; ===== IN-MEMORY STATS READER =====
ReadStatsFromMemory(filterBySession := false) {
    global macroExecutionLog, sessionId, totalActiveTime, currentUsername

    ; Initialize stats using helper function
    stats := Stats_CreateEmptyStatsMap()

    ; Process in-memory execution log
    sessionActiveMap := Map()
    executionTimes := []
    buttonCount := Map()
    layerCount := Map()

    for executionData in macroExecutionLog {
        try {
            ; Filter by session if requested
            sessionKey := sessionId
            if (!filterBySession || sessionKey = sessionId) {
                ; Parse execution data
                execution_type := executionData["execution_type"]
                macro_name := executionData.Has("button_key") ? executionData["button_key"] : ""
                layer := executionData.Has("layer") ? executionData["layer"] : 1
                execution_time := executionData.Has("execution_time_ms") ? executionData["execution_time_ms"] : 0
                total_boxes := executionData.Has("total_boxes") ? executionData["total_boxes"] : 0
                severity_level := executionData.Has("severity_level") ? executionData["severity_level"] : ""
                session_active_time := executionData.Has("session_active_time_ms") ? executionData["session_active_time_ms"] : 0

                ; Track latest active time
                if (!sessionActiveMap.Has(sessionKey) || session_active_time > sessionActiveMap[sessionKey]) {
                    sessionActiveMap[sessionKey] := session_active_time
                }

                ; Track user
                username := currentUsername
                UpdateUserSummary(stats["user_summary"], username, total_boxes, sessionKey)

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
                if (macro_name != "") {
                    if (!buttonCount.Has(macro_name)) {
                        buttonCount[macro_name] := 0
                    }
                    buttonCount[macro_name]++
                }

                if (!layerCount.Has(layer)) {
                    layerCount[layer] := 0
                }
                layerCount[layer]++

                ; Track severity levels (JSON executions)
                if (execution_type = "json_profile" && severity_level != "") {
                    switch StrLower(severity_level) {
                        case "low":
                            stats["severity_low"]++
                        case "medium":
                            stats["severity_medium"]++
                        case "high":
                            stats["severity_high"]++
                    }
                }

                ; Read degradation counts
                smudge := executionData.Has("smudge_count") ? executionData["smudge_count"] : 0
                glare := executionData.Has("glare_count") ? executionData["glare_count"] : 0
                splashes := executionData.Has("splashes_count") ? executionData["splashes_count"] : 0
                partial := executionData.Has("partial_blockage_count") ? executionData["partial_blockage_count"] : 0
                full := executionData.Has("full_blockage_count") ? executionData["full_blockage_count"] : 0
                flare := executionData.Has("light_flare_count") ? executionData["light_flare_count"] : 0
                rain := executionData.Has("rain_count") ? executionData["rain_count"] : 0
                haze := executionData.Has("haze_count") ? executionData["haze_count"] : 0
                snow := executionData.Has("snow_count") ? executionData["snow_count"] : 0
                clear := executionData.Has("clear_count") ? executionData["clear_count"] : 0

                ; Add to totals
                stats["smudge_total"] += smudge
                stats["glare_total"] += glare
                stats["splashes_total"] += splashes
                stats["partial_blockage_total"] += partial
                stats["full_blockage_total"] += full
                stats["light_flare_total"] += flare
                stats["rain_total"] += rain
                stats["haze_total"] += haze
                stats["snow_total"] += snow
                stats["clear_total"] += clear

                ; Separate by execution type
                if (execution_type = "json_profile") {
                    degradation_name := executionData.Has("degradation_assignments") ? executionData["degradation_assignments"] : ""
                    Stats_IncrementDegradationCount(stats, degradation_name, "json_")
                } else if (execution_type = "macro") {
                    stats["macro_smudge"] += smudge
                    stats["macro_glare"] += glare
                    stats["macro_splashes"] += splashes
                    stats["macro_partial"] += partial
                    stats["macro_full"] += full
                    stats["macro_flare"] += flare
                    stats["macro_rain"] += rain
                    stats["macro_haze"] += haze
                    stats["macro_snow"] += snow
                    stats["macro_clear"] += clear
                }
            }
        } catch {
            continue ; Skip malformed entries
        }
    }

    ; Calculate session active time
    totalSessionActive := 0
    for _, activeMs in sessionActiveMap {
        if (activeMs > 0) {
            totalSessionActive += activeMs
        }
    }

    if (sessionActiveMap.Has(sessionId)) {
        stats["current_session_active_time"] := sessionActiveMap[sessionId]
    } else {
        stats["current_session_active_time"] := 0
    }

    if (totalSessionActive > 0) {
        stats["session_active_time"] := totalSessionActive
    }

    stats["session_active_time_map"] := sessionActiveMap

    stats["distinct_user_count"] := stats["user_summary"].Count
    for username, userData in stats["user_summary"] {
        if (userData.Has("sessions")) {
            userData["session_count"] := userData["sessions"].Count
        } else {
            userData["session_count"] := 0
        }
    }

    ; Calculate derived stats
    if (stats["total_executions"] > 0) {
        stats["average_execution_time"] := Round(stats["total_execution_time"] / stats["total_executions"], 1)
    }

    ; Calculate hourly rates
    if (stats["session_active_time"] > 5000) {
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

    return stats
}

; ===== CSV-BASED STATS READER (Legacy/Fallback) =====
ReadStatsFromCSV(filterBySession := false) {
    global masterStatsCSV, sessionId, totalActiveTime, currentUsername

    ; Initialize stats using helper function
    stats := Stats_CreateEmptyStatsMap()

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
        sessionActiveMap := Map()

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
                    severity_level := Trim(fields[10])
                    session_active_time := IsNumber(fields[12]) ? Integer(fields[12]) : 0

                    ; Track latest active time for rate calculations
                    sessionKey := Trim(fields[2])
                    if (!sessionActiveMap.Has(sessionKey) || session_active_time > sessionActiveMap[sessionKey]) {
                        sessionActiveMap[sessionKey] := session_active_time
                    }

                    username := Trim(fields[3])
                    UpdateUserSummary(stats["user_summary"], username, total_boxes, sessionKey)

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

                    ; Track severity levels (JSON executions)
                    if (execution_type = "json_profile" && severity_level != "") {
                        switch StrLower(severity_level) {
                            case "low":
                                stats["severity_low"]++
                            case "medium":
                                stats["severity_medium"]++
                            case "high":
                                stats["severity_high"]++
                        }
                    }

                    ; Read degradation counts directly from CSV fields (14-23)
                    ; Headers: ...break_mode_active,smudge_count,glare_count,splashes_count,partial_blockage_count,full_blockage_count,light_flare_count,rain_count,haze_count,snow_count,clear_count...
                    if (fields.Length >= 23) {
                        smudge := IsNumber(fields[14]) ? Integer(fields[14]) : 0
                        glare := IsNumber(fields[15]) ? Integer(fields[15]) : 0
                        splashes := IsNumber(fields[16]) ? Integer(fields[16]) : 0
                        partial := IsNumber(fields[17]) ? Integer(fields[17]) : 0
                        full := IsNumber(fields[18]) ? Integer(fields[18]) : 0
                        flare := IsNumber(fields[19]) ? Integer(fields[19]) : 0
                        rain := IsNumber(fields[20]) ? Integer(fields[20]) : 0
                        haze := IsNumber(fields[21]) ? Integer(fields[21]) : 0
                        snow := IsNumber(fields[22]) ? Integer(fields[22]) : 0
                        clear := IsNumber(fields[23]) ? Integer(fields[23]) : 0

                        ; Add to totals
                        stats["smudge_total"] += smudge
                        stats["glare_total"] += glare
                        stats["splashes_total"] += splashes
                        stats["partial_blockage_total"] += partial
                        stats["full_blockage_total"] += full
                        stats["light_flare_total"] += flare
                        stats["rain_total"] += rain
                        stats["haze_total"] += haze
                        stats["snow_total"] += snow
                        stats["clear_total"] += clear

                        ; Separate by execution type
                        if (execution_type = "json_profile") {
                            ; For JSON: just count which degradation type was selected (1 per execution)
                            degradation_name := Trim(fields[9])  ; degradation_assignments field
                            Stats_IncrementDegradationCount(stats, degradation_name, "json_")
                        } else if (execution_type = "macro") {
                            stats["macro_smudge"] += smudge
                            stats["macro_glare"] += glare
                            stats["macro_splashes"] += splashes
                            stats["macro_partial"] += partial
                            stats["macro_full"] += full
                            stats["macro_flare"] += flare
                            stats["macro_rain"] += rain
                            stats["macro_haze"] += haze
                            stats["macro_snow"] += snow
                            stats["macro_clear"] += clear
                        }
                    }
                } catch {
                    continue ; Skip malformed rows
                }
            }
        }

        ; Update session active time
        totalSessionActive := 0
        for _, activeMs in sessionActiveMap {
            if (activeMs > 0) {
                totalSessionActive += activeMs
            }
        }

        if (sessionActiveMap.Has(sessionId)) {
            stats["current_session_active_time"] := sessionActiveMap[sessionId]
        } else {
            stats["current_session_active_time"] := 0
        }

        if (totalSessionActive > 0) {
            stats["session_active_time"] := totalSessionActive
        }

        stats["session_active_time_map"] := sessionActiveMap

        stats["distinct_user_count"] := stats["user_summary"].Count
        for username, userData in stats["user_summary"] {
            if (userData.Has("sessions")) {
                userData["session_count"] := userData["sessions"].Count
            } else {
                userData["session_count"] := 0
            }
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
    } catch {
        ; Handle file read errors gracefully
    }

    return stats
}

; ===== IN-MEMORY TODAY STATS =====
GetTodayStatsFromMemory() {
    global macroExecutionLog, sessionId, currentUsername

    ; Initialize stats using helper function
    stats := Stats_CreateEmptyStatsMap()
    sessionActiveMap := Map()

    ; Get today's date in YYYY-MM-DD format
    today := FormatTime(A_Now, "yyyy-MM-dd")

    ; Process in-memory execution log
    for executionData in macroExecutionLog {
        try {
            ; Check if timestamp starts with today's date
            timestamp := executionData.Has("timestamp") ? executionData["timestamp"] : ""

            if (SubStr(timestamp, 1, 10) = today) {
                execution_type := executionData["execution_type"]
                execution_time := executionData.Has("execution_time_ms") ? executionData["execution_time_ms"] : 0
                total_boxes := executionData.Has("total_boxes") ? executionData["total_boxes"] : 0
                severity_level := executionData.Has("severity_level") ? executionData["severity_level"] : ""
                session_active_time := executionData.Has("session_active_time_ms") ? executionData["session_active_time_ms"] : 0

                stats["total_executions"]++
                stats["total_boxes"] += total_boxes
                stats["total_execution_time"] += execution_time

                ; Count execution types
                if (execution_type = "json_profile") {
                    stats["json_profile_executions_count"]++
                } else if (execution_type = "macro") {
                    stats["macro_executions_count"]++
                }

                sessionKey := sessionId
                if (!sessionActiveMap.Has(sessionKey) || session_active_time > sessionActiveMap[sessionKey]) {
                    sessionActiveMap[sessionKey] := session_active_time
                }

                username := currentUsername
                UpdateUserSummary(stats["user_summary"], username, total_boxes, sessionKey)

                ; Track severity levels (JSON executions)
                if (execution_type = "json_profile" && severity_level != "") {
                    switch StrLower(severity_level) {
                        case "low":
                            stats["severity_low"]++
                        case "medium":
                            stats["severity_medium"]++
                        case "high":
                            stats["severity_high"]++
                    }
                }

                ; Parse degradations
                smudge := executionData.Has("smudge_count") ? executionData["smudge_count"] : 0
                glare := executionData.Has("glare_count") ? executionData["glare_count"] : 0
                splashes := executionData.Has("splashes_count") ? executionData["splashes_count"] : 0
                partial := executionData.Has("partial_blockage_count") ? executionData["partial_blockage_count"] : 0
                full := executionData.Has("full_blockage_count") ? executionData["full_blockage_count"] : 0
                flare := executionData.Has("light_flare_count") ? executionData["light_flare_count"] : 0
                rain := executionData.Has("rain_count") ? executionData["rain_count"] : 0
                haze := executionData.Has("haze_count") ? executionData["haze_count"] : 0
                snow := executionData.Has("snow_count") ? executionData["snow_count"] : 0
                clear := executionData.Has("clear_count") ? executionData["clear_count"] : 0

                stats["smudge_total"] += smudge
                stats["glare_total"] += glare
                stats["splashes_total"] += splashes
                stats["partial_blockage_total"] += partial
                stats["full_blockage_total"] += full
                stats["light_flare_total"] += flare
                stats["rain_total"] += rain
                stats["haze_total"] += haze
                stats["snow_total"] += snow
                stats["clear_total"] += clear

                ; Separate by execution type
                if (execution_type = "json_profile") {
                    degradation_name := executionData.Has("degradation_assignments") ? executionData["degradation_assignments"] : ""
                    Stats_IncrementDegradationCount(stats, degradation_name, "json_")
                } else if (execution_type = "macro") {
                    stats["macro_smudge"] += smudge
                    stats["macro_glare"] += glare
                    stats["macro_splashes"] += splashes
                    stats["macro_partial"] += partial
                    stats["macro_full"] += full
                    stats["macro_flare"] += flare
                    stats["macro_rain"] += rain
                    stats["macro_haze"] += haze
                    stats["macro_snow"] += snow
                    stats["macro_clear"] += clear
                }
            }
        } catch {
            continue
        }
    }

    totalSessionActive := 0
    for _, activeMs in sessionActiveMap {
        if (activeMs > 0) {
            totalSessionActive += activeMs
        }
    }

    if (sessionActiveMap.Has(sessionId)) {
        stats["current_session_active_time"] := sessionActiveMap[sessionId]
    } else {
        stats["current_session_active_time"] := 0
    }

    if (totalSessionActive > 0) {
        stats["session_active_time"] := totalSessionActive
    }

    stats["session_active_time_map"] := sessionActiveMap

    stats["distinct_user_count"] := stats["user_summary"].Count
    for username, userData in stats["user_summary"] {
        if (userData.Has("sessions")) {
            userData["session_count"] := userData["sessions"].Count
        } else {
            userData["session_count"] := 0
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

    return stats
}

; ===== CSV-BASED TODAY STATS (Legacy/Fallback) =====
GetTodayStats() {
    global masterStatsCSV, sessionId, currentUsername

    ; Initialize stats using helper function
    stats := Stats_CreateEmptyStatsMap()
    sessionActiveMap := Map()

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
                    execution_type := Trim(fields[4])
                    execution_time := IsNumber(fields[7]) ? Integer(fields[7]) : 0
                    total_boxes := IsNumber(fields[8]) ? Integer(fields[8]) : 0
                    severity_level := Trim(fields[10])
                    session_active_time := IsNumber(fields[12]) ? Integer(fields[12]) : 0

                    stats["total_executions"]++
                    stats["total_boxes"] += total_boxes
                    stats["total_execution_time"] += execution_time

                    ; Count execution types
                    if (execution_type = "json_profile") {
                        stats["json_profile_executions_count"]++
                    } else if (execution_type = "macro") {
                        stats["macro_executions_count"]++
                    }

                    sessionKey := Trim(fields[2])
                    if (!sessionActiveMap.Has(sessionKey) || session_active_time > sessionActiveMap[sessionKey]) {
                        sessionActiveMap[sessionKey] := session_active_time
                    }

                    username := Trim(fields[3])
                    UpdateUserSummary(stats["user_summary"], username, total_boxes, sessionKey)

                    ; Track severity levels (JSON executions)
                    if (execution_type = "json_profile" && severity_level != "") {
                        switch StrLower(severity_level) {
                            case "low":
                                stats["severity_low"]++
                            case "medium":
                                stats["severity_medium"]++
                            case "high":
                                stats["severity_high"]++
                        }
                    }

                    ; Parse degradations from fields 14-23
                    if (fields.Length >= 23) {
                        smudge := IsNumber(fields[14]) ? Integer(fields[14]) : 0
                        glare := IsNumber(fields[15]) ? Integer(fields[15]) : 0
                        splashes := IsNumber(fields[16]) ? Integer(fields[16]) : 0
                        partial := IsNumber(fields[17]) ? Integer(fields[17]) : 0
                        full := IsNumber(fields[18]) ? Integer(fields[18]) : 0
                        flare := IsNumber(fields[19]) ? Integer(fields[19]) : 0
                        rain := IsNumber(fields[20]) ? Integer(fields[20]) : 0
                        haze := IsNumber(fields[21]) ? Integer(fields[21]) : 0
                        snow := IsNumber(fields[22]) ? Integer(fields[22]) : 0
                        clear := IsNumber(fields[23]) ? Integer(fields[23]) : 0

                        stats["smudge_total"] += smudge
                        stats["glare_total"] += glare
                        stats["splashes_total"] += splashes
                        stats["partial_blockage_total"] += partial
                        stats["full_blockage_total"] += full
                        stats["light_flare_total"] += flare
                        stats["rain_total"] += rain
                        stats["haze_total"] += haze
                        stats["snow_total"] += snow
                        stats["clear_total"] += clear

                        ; Separate by execution type
                        if (execution_type = "json_profile") {
                            ; For JSON: just count which degradation type was selected (1 per execution)
                            degradation_name := Trim(fields[9])  ; degradation_assignments field
                            Stats_IncrementDegradationCount(stats, degradation_name, "json_")
                        } else if (execution_type = "macro") {
                            stats["macro_smudge"] += smudge
                            stats["macro_glare"] += glare
                            stats["macro_splashes"] += splashes
                            stats["macro_partial"] += partial
                            stats["macro_full"] += full
                            stats["macro_flare"] += flare
                            stats["macro_rain"] += rain
                            stats["macro_haze"] += haze
                            stats["macro_snow"] += snow
                            stats["macro_clear"] += clear
                        }
                    }
                } catch {
                    continue
                }
            }
        }

        totalSessionActive := 0
        for _, activeMs in sessionActiveMap {
            if (activeMs > 0) {
                totalSessionActive += activeMs
            }
        }

        if (sessionActiveMap.Has(sessionId)) {
            stats["current_session_active_time"] := sessionActiveMap[sessionId]
        } else {
            stats["current_session_active_time"] := 0
        }

        if (totalSessionActive > 0) {
            stats["session_active_time"] := totalSessionActive
        }

        stats["session_active_time_map"] := sessionActiveMap

        stats["distinct_user_count"] := stats["user_summary"].Count
        for username, userData in stats["user_summary"] {
            if (userData.Has("sessions")) {
                userData["session_count"] := userData["sessions"].Count
            } else {
                userData["session_count"] := 0
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

ProcessDegradationCounts(executionData, degradationString) {
    if (degradationString = "" || degradationString = "none") {
        return
    }

    ; Split by comma and process each degradation type
    degradationTypes := StrSplit(degradationString, ",")

    for degradationType in degradationTypes {
        degradationType := Trim(StrReplace(StrReplace(degradationType, Chr(34), ""), Chr(39), ""))
        Stats_IncrementDegradationCountDirect(executionData, degradationType)
    }
}

UpdateUserSummary(userSummaryMap, username, totalBoxes, sessionId) {
    if (username = "") {
        username := "unknown"
    }

    if (!userSummaryMap.Has(username)) {
        userSummaryMap[username] := Map(
            "total_executions", 0,
            "total_boxes", 0,
            "sessions", Map()
        )
    }

    userData := userSummaryMap[username]
    userData["total_executions"] := userData["total_executions"] + 1
    userData["total_boxes"] := userData["total_boxes"] + totalBoxes

    if (sessionId != "") {
        sessions := userData["sessions"]
        if (!sessions.Has(sessionId)) {
            sessions[sessionId] := true
        }
    }
}

RecordExecutionStats(macroKey, executionStartTime, executionType, events, analysisRecord := "") {
    global breakMode, recording, annotationMode, totalActiveTime, lastActiveTime, sessionStartTime
    eventCount := (IsObject(events) ? events.Length : 0)

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
    executionData["layer"] := 1  ; Single-layer system
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
        ; IMPROVED: Always extract degradation types directly from bounding box events
        bbox_count := 0
        degradation_counts_map := Map(1, 0, 2, 0, 3, 0, 4, 0, 5, 0, 6, 0, 7, 0, 8, 0, 9, 0, 0, 0)

        for event in events {
            ; Handle both Map and Object types
            eventType := ""
            if (Type(event) = "Map") {
                eventType := event.Has("type") ? event["type"] : ""
            } else if (IsObject(event)) {
                eventType := event.HasOwnProp("type") ? event.type : ""
            }

            if (eventType = "boundingBox") {
                bbox_count++

                ; Extract degradation type directly from the box event
                degType := 0
                if (Type(event) = "Map") {
                    degType := event.Has("degradationType") ? event["degradationType"] : 0
                } else if (event.HasOwnProp("degradationType")) {
                    degType := event.degradationType
                }

                if (degType != 0 && degradation_counts_map.Has(degType)) {
                    degradation_counts_map[degType]++
                }
            }
        }

        executionData["total_boxes"] := bbox_count

        ; Convert degradation type IDs to counts
        executionData["smudge_count"] := degradation_counts_map[1]
        executionData["glare_count"] := degradation_counts_map[2]
        executionData["splashes_count"] := degradation_counts_map[3]
        executionData["partial_blockage_count"] := degradation_counts_map[4]
        executionData["full_blockage_count"] := degradation_counts_map[5]
        executionData["light_flare_count"] := degradation_counts_map[6]
        executionData["rain_count"] := degradation_counts_map[7]
        executionData["haze_count"] := degradation_counts_map[8]
        executionData["snow_count"] := degradation_counts_map[9]
        executionData["clear_count"] := degradation_counts_map[0]

        ; Build degradation assignments string
        degradation_names := []
        if (degradation_counts_map[1] > 0) degradation_names.Push("smudge")
        if (degradation_counts_map[2] > 0) degradation_names.Push("glare")
        if (degradation_counts_map[3] > 0) degradation_names.Push("splashes")
        if (degradation_counts_map[4] > 0) degradation_names.Push("partial_blockage")
        if (degradation_counts_map[5] > 0) degradation_names.Push("full_blockage")
        if (degradation_counts_map[6] > 0) degradation_names.Push("light_flare")
        if (degradation_counts_map[7] > 0) degradation_names.Push("rain")
        if (degradation_counts_map[8] > 0) degradation_names.Push("haze")
        if (degradation_counts_map[9] > 0) degradation_names.Push("snow")
        if (degradation_counts_map[0] > 0) degradation_names.Push("clear")

        if (degradation_names.Length > 0) {
            degradation_string := ""
            for i, name in degradation_names {
                degradation_string .= (i > 1 ? "," : "") . name
            }
            executionData["degradation_assignments"] := degradation_string
        } else {
            executionData["degradation_assignments"] := "clear"
            executionData["clear_count"] := bbox_count > 0 ? bbox_count : 1
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

    ; Record to CSV with comprehensive data (removed excessive UpdateStatus call)
    return AppendToCSV(executionData)
}

; ===== IN-MEMORY STATS LOG =====
global macroExecutionLog := []  ; Array of execution data maps

; ===== STATS CSV WRITER =====
AppendToCSV(executionData) {
    ; INTEGRATED SYSTEM: Store in memory only (saves on exit)
    global macroExecutionLog

    try {
        ; Store in memory for immediate access
        macroExecutionLog.Push(executionData)
        return true
    } catch Error as e {
        UpdateStatus("⚠ Stats record error: " . e.Message)
        return false
    }
}

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

GetCurrentSessionActiveTime() {
    global totalActiveTime, lastActiveTime, breakMode

    if (breakMode) {
        return totalActiveTime
    } else {
        return totalActiveTime + (A_TickCount - lastActiveTime)
    }
}

; ===== JSON PERSISTENCE SYSTEM =====
; Simple save/load aligned with config system - saves on exit, loads on startup
SaveStatsToJson() {
    global macroExecutionLog, workDir

    statsJsonFile := workDir . "\stats_log.json"

    try {
        jsonData := Map()
        jsonData["version"] := "1.0"
        jsonData["last_updated"] := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")
        jsonData["executions"] := macroExecutionLog

        ObjSave(jsonData, statsJsonFile)
        return true
    } catch Error as e {
        return false
    }
}

LoadStatsFromJson() {
    global macroExecutionLog, workDir

    statsJsonFile := workDir . "\stats_log.json"

    try {
        if (!FileExist(statsJsonFile)) {
            macroExecutionLog := []
            return 0
        }

        jsonData := ObjLoad(statsJsonFile)

        if (!IsObject(jsonData) || !jsonData.Has("executions")) {
            macroExecutionLog := []
            return 0
        }

        macroExecutionLog := jsonData["executions"]
        return macroExecutionLog.Length
    } catch Error as e {
        macroExecutionLog := []
        return 0
    }
}
