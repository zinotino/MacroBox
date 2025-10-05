; ===== STATS.AHK - Statistics and Analytics System =====
; This module contains all statistics-related functionality

; ===== STATS MODULE FOR MODULAR SYSTEM =====
; This module expects global variables to be defined in Core.ahk:
; - workDir (data directory)
; - documentsDir
; - thumbnailDir
; - sessionId
; - currentUsername
; - masterStatsCSV (reset-able display stats)
; - permanentStatsFile (PERMANENT master stats - NEVER reset)
; And functions: UpdateStatus, RunWaitOne

; ===== PERMANENT STATS PERSISTENCE SYSTEM =====
; Two-tier stats storage system:
; 1. masterStatsCSV - Display stats (Today/All-Time shown in GUI) - CAN be reset by user
; 2. permanentStatsFile - PERMANENT master archive - NEVER gets reset
;
; This ensures user data is NEVER lost even if they visually "reset" their stats.
; The permanent file preserves complete historical data forever.

; ===== DEGRADATION TRACKING ACCURACY IMPROVEMENTS =====
; Enhanced degradation tracking to directly extract degradationType from bounding box events.
; This ensures accurate per-box degradation counts across all execution types.

; ===== STATISTICS SYSTEM INITIALIZATION =====
InitializeStatsSystem() {
    global masterStatsCSV, workDir, sessionId, currentUsername, permanentStatsFile

    ; Ensure CSV file exists
    if (!FileExist(masterStatsCSV)) {
        InitializeCSVFile()
    }

    ; Initialize permanent master stats file (NEVER gets reset)
    InitializePermanentStatsFile()
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

; ===== PERMANENT STATS FILE INITIALIZATION =====
; This file NEVER gets reset - it's the permanent archive of ALL user data
InitializePermanentStatsFile() {
    global workDir, permanentStatsFile

    try {
        ; Create permanent stats file in Documents/MacroMaster/data/
        permanentStatsFile := workDir . "\master_stats_permanent.csv"

        if (!FileExist(permanentStatsFile)) {
            header := "timestamp,session_id,username,execution_type,button_key,layer,execution_time_ms,total_boxes,degradation_assignments,severity_level,canvas_mode,session_active_time_ms,break_mode_active,smudge_count,glare_count,splashes_count,partial_blockage_count,full_blockage_count,light_flare_count,rain_count,haze_count,snow_count,clear_count,annotation_details,execution_success,error_details`n"
            FileAppend(header, permanentStatsFile, "UTF-8")
        }
    } catch as e {
        ; Silent fail - don't break execution if permanent file can't be created
    }
}

LoadStatsData() {
    ; Load statistics data from CSV
    return ReadStatsFromCSV(false)
}

; ===== STATISTICS DISPLAY FUNCTIONS =====
; Global variables for live stats GUI
global statsGui := ""
global statsGuiOpen := false
global statsControls := Map()

ShowStatsMenu() {
    global masterStatsCSV, darkMode, currentSessionId, permanentStatsFile
    global statsGui, statsGuiOpen, statsControls

    ; Close existing if open
    if (statsGuiOpen) {
        CloseStatsMenu()
        return
    }

    ; Create horizontal-optimized stats display
    statsGui := Gui("+AlwaysOnTop", "📊 MacroMaster Statistics")
    statsGui.BackColor := darkMode ? "0x1E1E1E" : "0xF5F5F5"
    statsGui.SetFont("s9", "Consolas")
    statsGui.OnEvent("Close", (*) => CloseStatsMenu())

    ; Clear controls map
    statsControls := Map()

    ; Layout parameters
    leftCol := 20
    midCol := 250
    rightCol := 480
    y := 15

    ; === TITLE & DATE ===
    todayDate := FormatTime(A_Now, "MMMM d, yyyy (dddd)")
    titleText := statsGui.Add("Text", "x" . leftCol . " y" . y . " w660 Center", todayDate)
    titleText.SetFont("s10 bold")
    titleText.Opt("c" . (darkMode ? "0xFFFFFF" : "0x000000"))
    y += 35

    ; === COLUMN HEADERS ===
    AddStatsHeader(statsGui, y, "ALL-TIME (Since Reset)", leftCol, 210)
    AddStatsHeader(statsGui, y, "TODAY", rightCol, 210)
    y += 25

    ; === GENERAL STATS ===
    AddSectionDivider(statsGui, y, "GENERAL STATISTICS", 660)
    y += 25

    AddHorizontalStatRowLive(statsGui, y, "Executions:", "all_exec", "today_exec")
    y += 18
    AddHorizontalStatRowLive(statsGui, y, "Boxes:", "all_boxes", "today_boxes")
    y += 18
    AddHorizontalStatRowLive(statsGui, y, "Active Time:", "all_active_time", "today_active_time")
    y += 18
    AddHorizontalStatRowLive(statsGui, y, "Avg Time:", "all_avg_time", "today_avg_time")
    y += 18
    AddHorizontalStatRowLive(statsGui, y, "Boxes/Hour:", "all_box_rate", "today_box_rate")
    y += 18
    AddHorizontalStatRowLive(statsGui, y, "Exec/Hour:", "all_exec_rate", "today_exec_rate")
    y += 25

    ; === MACRO DEGRADATION BREAKDOWN ===
    AddSectionDivider(statsGui, y, "MACRO DEGRADATION BREAKDOWN", 660)
    y += 25

    degradationTypes := [
        ["Smudge", "smudge"],
        ["Glare", "glare"],
        ["Splashes", "splashes"],
        ["Partial Block", "partial"],
        ["Full Block", "full"],
        ["Light Flare", "flare"],
        ["Rain", "rain"],
        ["Haze", "haze"],
        ["Snow", "snow"],
        ["Clear", "clear"]
    ]

    for degInfo in degradationTypes {
        AddHorizontalStatRowLive(statsGui, y, degInfo[1] . ":", "all_macro_" . degInfo[2], "today_macro_" . degInfo[2])
        y += 18
    }
    y += 15

    ; === JSON DEGRADATION BREAKDOWN ===
    AddSectionDivider(statsGui, y, "JSON DEGRADATION SELECTION COUNT", 660)
    y += 25

    for degInfo in degradationTypes {
        AddHorizontalStatRowLive(statsGui, y, degInfo[1] . ":", "all_json_" . degInfo[2], "today_json_" . degInfo[2])
        y += 18
    }
    y += 15

    ; === EXECUTION TYPE BREAKDOWN ===
    AddSectionDivider(statsGui, y, "EXECUTION TYPE BREAKDOWN", 660)
    y += 25

    AddHorizontalStatRowLive(statsGui, y, "Macro Executions:", "all_macro_exec", "today_macro_exec")
    y += 18
    AddHorizontalStatRowLive(statsGui, y, "JSON Executions:", "all_json_exec", "today_json_exec")
    y += 25

    ; === JSON SEVERITY TRACKING ===
    AddSectionDivider(statsGui, y, "JSON SEVERITY BREAKDOWN", 660)
    y += 25

    severityTypes := [
        ["Low Severity", "severity_low"],
        ["Medium Severity", "severity_medium"],
        ["High Severity", "severity_high"]
    ]

    for sevInfo in severityTypes {
        AddHorizontalStatRowLive(statsGui, y, sevInfo[1] . ":", "all_" . sevInfo[2], "today_" . sevInfo[2])
        y += 18
    }
    y += 25

    ; === MACRO DETAILS ===
    AddSectionDivider(statsGui, y, "MACRO DETAILS", 660)
    y += 25

    AddHorizontalStatRowLive(statsGui, y, "Most Used Button:", "most_used_btn", "")
    y += 18
    AddHorizontalStatRowLive(statsGui, y, "Most Active Layer:", "most_active_layer", "")
    y += 25

    ; === FILE LOCATIONS ===
    AddSectionDivider(statsGui, y, "DATA FILES", 660)
    y += 25

    infoText := statsGui.Add("Text", "x" . leftCol . " y" . y . " w660", "Display Stats: " . masterStatsCSV)
    infoText.SetFont("s8")
    infoText.Opt("c" . (darkMode ? "0x888888" : "0x666666"))
    y += 18

    infoText2 := statsGui.Add("Text", "x" . leftCol . " y" . y . " w660", "Permanent Master: " . permanentStatsFile)
    infoText2.SetFont("s8")
    infoText2.Opt("c" . (darkMode ? "0x888888" : "0x666666"))
    y += 30

    ; === BUTTONS ===
    btnExport := statsGui.Add("Button", "x" . leftCol . " y" . y . " w120 h30", "💾 Export")
    btnExport.SetFont("s9")
    btnExport.OnEvent("Click", (*) => ExportStatsData(statsGui))

    btnReset := statsGui.Add("Button", "x" . (leftCol + 130) . " y" . y . " w120 h30", "🗑️ Reset")
    btnReset.SetFont("s9")
    btnReset.OnEvent("Click", (*) => ResetAllStats())

    btnClose := statsGui.Add("Button", "x" . (leftCol + 260) . " y" . y . " w120 h30", "❌ Close")
    btnClose.SetFont("s9")
    btnClose.OnEvent("Click", (*) => CloseStatsMenu())

    ; Show GUI and start live refresh
    statsGui.Show("w700 h" . (y + 50))
    statsGuiOpen := true

    ; Initial update and start refresh timer (500ms)
    UpdateStatsDisplay()
    SetTimer(UpdateStatsDisplay, 500)
}

; Add horizontal stat row with live updating
AddHorizontalStatRowLive(gui, y, label, allKey, todayKey) {
    global darkMode, statsControls

    ; Label
    labelCtrl := gui.Add("Text", "x20 y" . y . " w140", label)
    labelCtrl.SetFont("s9", "Consolas")
    labelCtrl.Opt("c" . (darkMode ? "0xCCCCCC" : "0x555555"))

    ; All-time value control (store for live updates)
    allCtrl := gui.Add("Text", "x170 y" . y . " w70 Right", "0")
    allCtrl.SetFont("s9 bold", "Consolas")
    allCtrl.Opt("c" . (darkMode ? "0xFFFFFF" : "0x000000"))
    statsControls[allKey] := allCtrl

    ; Today value control (if provided)
    if (todayKey != "") {
        todayCtrl := gui.Add("Text", "x480 y" . y . " w70 Right", "0")
        todayCtrl.SetFont("s9 bold", "Consolas")
        todayCtrl.Opt("c" . (darkMode ? "0xFFFFFF" : "0x000000"))
        statsControls[todayKey] := todayCtrl
    }
}

; Add section divider
AddSectionDivider(gui, y, text, width) {
    global darkMode
    divider := gui.Add("Text", "x20 y" . y . " w" . width, "═══ " . text . " ═══")
    divider.SetFont("s9 bold", "Consolas")
    divider.Opt("c" . (darkMode ? "0xFFFFFF" : "0x000000"))
}

; Helper function to add column headers
AddStatsHeader(gui, y, text, x, width) {
    global darkMode
    header := gui.Add("Text", "x" . x . " y" . y . " w" . width . " Center", text)
    header.SetFont("s9 bold", "Consolas")
    header.Opt("c" . (darkMode ? "0xFFFFFF" : "0x000000"))
}

; ===== LIVE STATS UPDATE FUNCTION =====
UpdateStatsDisplay() {
    global statsGuiOpen, statsControls

    if (!statsGuiOpen) {
        SetTimer(UpdateStatsDisplay, 0)
        return
    }

    try {
        ; Get fresh stats data
        allStats := ReadStatsFromCSV(false)
        todayStats := GetTodayStats()

        ; CRITICAL: Recalculate hourly rates with LIVE active time for ALL-TIME
        currentActiveTime := GetCurrentSessionActiveTime()
        if (currentActiveTime > 5000) { ; At least 5 seconds
            activeTimeHours := currentActiveTime / 3600000
            allStats["boxes_per_hour"] := Round(allStats["total_boxes"] / activeTimeHours, 1)
            allStats["executions_per_hour"] := Round(allStats["total_executions"] / activeTimeHours, 1)
            allStats["session_active_time"] := currentActiveTime
        }

        ; CRITICAL: Recalculate hourly rates with LIVE active time for TODAY
        ; Today's active time is same as current session (resets daily)
        if (currentActiveTime > 5000) {
            activeTimeHours := currentActiveTime / 3600000
            todayStats["boxes_per_hour"] := Round(todayStats["total_boxes"] / activeTimeHours, 1)
            todayStats["executions_per_hour"] := Round(todayStats["total_executions"] / activeTimeHours, 1)
            todayStats["session_active_time"] := currentActiveTime
        }

        ; Update general stats
        if (statsControls.Has("all_exec"))
            statsControls["all_exec"].Value := allStats["total_executions"]
        if (statsControls.Has("today_exec"))
            statsControls["today_exec"].Value := todayStats["total_executions"]

        if (statsControls.Has("all_boxes"))
            statsControls["all_boxes"].Value := allStats["total_boxes"]
        if (statsControls.Has("today_boxes"))
            statsControls["today_boxes"].Value := todayStats["total_boxes"]

        if (statsControls.Has("all_active_time"))
            statsControls["all_active_time"].Value := FormatMilliseconds(allStats["session_active_time"])
        if (statsControls.Has("today_active_time"))
            statsControls["today_active_time"].Value := FormatMilliseconds(todayStats["session_active_time"])

        if (statsControls.Has("all_avg_time"))
            statsControls["all_avg_time"].Value := allStats["average_execution_time"] . " ms"
        if (statsControls.Has("today_avg_time"))
            statsControls["today_avg_time"].Value := todayStats["average_execution_time"] . " ms"

        if (statsControls.Has("all_box_rate"))
            statsControls["all_box_rate"].Value := allStats["boxes_per_hour"]
        if (statsControls.Has("today_box_rate"))
            statsControls["today_box_rate"].Value := todayStats["boxes_per_hour"]

        if (statsControls.Has("all_exec_rate"))
            statsControls["all_exec_rate"].Value := allStats["executions_per_hour"]
        if (statsControls.Has("today_exec_rate"))
            statsControls["today_exec_rate"].Value := todayStats["executions_per_hour"]

        ; Update macro degradations
        degradationKeys := ["smudge", "glare", "splashes", "partial", "full", "flare", "rain", "haze", "snow", "clear"]

        for key in degradationKeys {
            ; Macro degradations
            if (statsControls.Has("all_macro_" . key))
                statsControls["all_macro_" . key].Value := allStats["macro_" . key]
            if (statsControls.Has("today_macro_" . key))
                statsControls["today_macro_" . key].Value := todayStats["macro_" . key]

            ; JSON degradations
            if (statsControls.Has("all_json_" . key))
                statsControls["all_json_" . key].Value := allStats["json_" . key]
            if (statsControls.Has("today_json_" . key))
                statsControls["today_json_" . key].Value := todayStats["json_" . key]
        }

        ; Update execution type breakdown
        if (statsControls.Has("all_macro_exec"))
            statsControls["all_macro_exec"].Value := allStats["macro_executions_count"]
        if (statsControls.Has("today_macro_exec")) {
            todayMacroExec := todayStats.Has("macro_executions_count") ? todayStats["macro_executions_count"] : Max(0, allStats["macro_executions_count"] - (allStats["total_executions"] - todayStats["total_executions"]))
            statsControls["today_macro_exec"].Value := Max(0, todayMacroExec)
        }
        if (statsControls.Has("all_json_exec"))
            statsControls["all_json_exec"].Value := allStats["json_profile_executions_count"]
        if (statsControls.Has("today_json_exec")) {
            todayJsonExec := todayStats.Has("json_profile_executions_count") ? todayStats["json_profile_executions_count"] : Max(0, allStats["json_profile_executions_count"] - (allStats["total_executions"] - todayStats["total_executions"]))
            statsControls["today_json_exec"].Value := Max(0, todayJsonExec)
        }

        ; Update severity tracking
        if (statsControls.Has("all_severity_low"))
            statsControls["all_severity_low"].Value := allStats["severity_low"]
        if (statsControls.Has("today_severity_low"))
            statsControls["today_severity_low"].Value := todayStats["severity_low"]
        if (statsControls.Has("all_severity_medium"))
            statsControls["all_severity_medium"].Value := allStats["severity_medium"]
        if (statsControls.Has("today_severity_medium"))
            statsControls["today_severity_medium"].Value := todayStats["severity_medium"]
        if (statsControls.Has("all_severity_high"))
            statsControls["all_severity_high"].Value := allStats["severity_high"]
        if (statsControls.Has("today_severity_high"))
            statsControls["today_severity_high"].Value := todayStats["severity_high"]

        ; Update macro details
        if (statsControls.Has("most_used_btn"))
            statsControls["most_used_btn"].Value := allStats["most_used_button"]
        if (statsControls.Has("most_active_layer"))
            statsControls["most_active_layer"].Value := allStats["most_active_layer"]

    } catch as err {
        ; Silently handle errors
    }
}

; ===== CLOSE STATS MENU =====
CloseStatsMenu() {
    global statsGui, statsGuiOpen

    SetTimer(UpdateStatsDisplay, 0)

    if (statsGui) {
        try statsGui.Destroy()
        statsGui := ""
    }

    statsGuiOpen := false
}

; Get today's stats only
GetTodayStats() {
    global masterStatsCSV

    stats := Map()
    stats["total_executions"] := 0
    stats["macro_executions_count"] := 0
    stats["json_profile_executions_count"] := 0
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
    stats["severity_low"] := 0
    stats["severity_medium"] := 0
    stats["severity_high"] := 0

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

                    if (session_active_time > stats["session_active_time"]) {
                        stats["session_active_time"] := session_active_time
                    }

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
                            switch StrLower(degradation_name) {
                                case "smudge", "1":
                                    stats["json_smudge"]++
                                case "glare", "2":
                                    stats["json_glare"]++
                                case "splashes", "3":
                                    stats["json_splashes"]++
                                case "partial_blockage", "4":
                                    stats["json_partial"]++
                                case "full_blockage", "5":
                                    stats["json_full"]++
                                case "light_flare", "6":
                                    stats["json_flare"]++
                                case "rain", "7":
                                    stats["json_rain"]++
                                case "haze", "8":
                                    stats["json_haze"]++
                                case "snow", "9":
                                    stats["json_snow"]++
                                case "clear", "none":
                                    stats["json_clear"]++
                            }
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

    ; Initialize MACRO degradation counters
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

    ; Initialize JSON degradation counters
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

    ; Initialize severity counters
    stats["severity_low"] := 0
    stats["severity_medium"] := 0
    stats["severity_high"] := 0

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
                    severity_level := Trim(fields[10])
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
                            switch StrLower(degradation_name) {
                                case "smudge", "1":
                                    stats["json_smudge"]++
                                case "glare", "2":
                                    stats["json_glare"]++
                                case "splashes", "3":
                                    stats["json_splashes"]++
                                case "partial_blockage", "4":
                                    stats["json_partial"]++
                                case "full_blockage", "5":
                                    stats["json_full"]++
                                case "light_flare", "6":
                                    stats["json_flare"]++
                                case "rain", "7":
                                    stats["json_rain"]++
                                case "haze", "8":
                                    stats["json_haze"]++
                                case "snow", "9":
                                    stats["json_snow"]++
                                case "clear", "none":
                                    stats["json_clear"]++
                            }
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
        ; IMPROVED: Always extract degradation types directly from bounding box events
        bbox_count := 0
        degradation_counts_map := Map(1, 0, 2, 0, 3, 0, 4, 0, 5, 0, 6, 0, 7, 0, 8, 0, 9, 0, 0, 0)

        for event in events {
            if (event.type = "boundingBox") {
                bbox_count++
                ; Extract degradation type directly from the box event
                if (event.HasOwnProp("degradationType")) {
                    degType := event.degradationType
                    if (degradation_counts_map.Has(degType)) {
                        degradation_counts_map[degType]++
                    }
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


; ===== CSV FUNCTIONS =====
; NOTE: InitializeCSVFile function is defined earlier in this file

AppendToCSV(executionData) {
    global permanentStatsFile

    ; Write to CSV (backup)
    csvSuccess := AppendToCSVFile(executionData)

    ; CRITICAL: Also write to permanent master stats file (NEVER gets reset)
    try {
        AppendToPermanentStatsFile(executionData)
    } catch {
        ; Silent fail - don't break execution
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

; ===== APPEND TO PERMANENT STATS FILE =====
; This function writes to the permanent master stats file that NEVER gets reset
AppendToPermanentStatsFile(executionData) {
    global permanentStatsFile, currentSessionId, currentUsername

    try {
        ; Ensure permanent stats file exists
        if (!FileExist(permanentStatsFile)) {
            header := "timestamp,session_id,username,execution_type,button_key,layer,execution_time_ms,total_boxes,degradation_assignments,severity_level,canvas_mode,session_active_time_ms,break_mode_active,smudge_count,glare_count,splashes_count,partial_blockage_count,full_blockage_count,light_flare_count,rain_count,haze_count,snow_count,clear_count,annotation_details,execution_success,error_details`n"
            FileAppend(header, permanentStatsFile, "UTF-8")
        }

        ; Build CSV row with all required fields (identical to AppendToCSVFile)
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

        FileAppend(row, permanentStatsFile, "UTF-8")
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

; ===== RESET STATS FUNCTION =====
ResetAllStats() {
    global masterStatsCSV, permanentStatsFile

    result := MsgBox("This will reset the DISPLAY statistics (Today and All-Time shown in the stats menu).`n`n⚠️ Your permanent master stats file will NOT be deleted - all your historical data is safe!`n`nReset display stats?", "Reset Statistics", "YesNo Icon!")

    if (result = "Yes") {
        try {
            ; Delete the CSV file (display stats)
            if FileExist(masterStatsCSV) {
                FileDelete(masterStatsCSV)
            }

            ; Reinitialize CSV file
            InitializeCSVFile()

            ; NOTE: We do NOT delete permanentStatsFile - it persists forever!
            MsgBox("Display statistics reset complete!`n`n✅ Your permanent master stats file is safe at:`n" . permanentStatsFile . "`n`nAll historical data is preserved!", "Reset Complete", "Icon!")

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

