; ===== STATS GUI MODULE =====

; Handles statistics display and user interactions

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

    y += 20

    ; === COLUMN HEADERS ===

    AddStatsHeader(statsGui, y, "ALL-TIME (Since Reset)", leftCol, 210)

    AddStatsHeader(statsGui, y, "TODAY", rightCol, 210)

    y += 15

    ; === GENERAL STATS ===

    AddSectionDivider(statsGui, y, "GENERAL STATISTICS", 660)

    y += 15

    AddHorizontalStatRowLive(statsGui, y, "Executions:", "all_exec", "today_exec")

    y += 18

    AddHorizontalStatRowLive(statsGui, y, "Boxes:", "all_boxes", "today_boxes")

    y += 18

    AddHorizontalStatRowLive(statsGui, y, "Active Time:", "all_active_time", "today_active_time")

    y += 18

    AddHorizontalStatRowLive(statsGui, y, "Avg Time:", "all_avg_time", "today_avg_time")

    y += 18

    AddHorizontalStatRowLive(statsGui, y, "Boxes/Hour:", "all_box_rate", "today_box_rate")

    y += 12

    AddHorizontalStatRowLive(statsGui, y, "Exec/Hour:", "all_exec_rate", "today_exec_rate")

    y += 15

    ; === MACRO DEGRADATION BREAKDOWN ===

    AddSectionDivider(statsGui, y, "MACRO DEGRADATION BREAKDOWN", 660)

    y += 15

    degradationTypes := [

        ["Smudge", "smudge"],

        ["Glare", "glare"],

        ["Splashes", "splashes"],

        ["Partial Block", "partial"],

        ["Full Block", "full"],

        ["Light Flare", "flare"],

        ["Rain", "rain"],

        ["Haze", "haze"],

        ["Snow", "snow"]

    ]

    for degInfo in degradationTypes {

        AddHorizontalStatRowLive(statsGui, y, degInfo[1] . ":", "all_macro_" . degInfo[2], "today_macro_" . degInfo[2])

        y += 12

    }

    y += 10

    ; === JSON DEGRADATION BREAKDOWN ===

    AddSectionDivider(statsGui, y, "JSON DEGRADATION SELECTION COUNT", 660)

    y += 15

    for degInfo in degradationTypes {

        AddHorizontalStatRowLive(statsGui, y, degInfo[1] . ":", "all_json_" . degInfo[2], "today_json_" . degInfo[2])

        y += 12

    }

    y += 10

    ; === EXECUTION TYPE BREAKDOWN ===

    AddSectionDivider(statsGui, y, "EXECUTION TYPE BREAKDOWN", 660)

    y += 15

    AddHorizontalStatRowLive(statsGui, y, "Macro Executions:", "all_macro_exec", "today_macro_exec")

    y += 12

    AddHorizontalStatRowLive(statsGui, y, "JSON Executions:", "all_json_exec", "today_json_exec")

    y += 15

    ; === JSON SEVERITY TRACKING ===

    AddSectionDivider(statsGui, y, "JSON SEVERITY BREAKDOWN", 660)

    y += 15

    severityTypes := [

        ["Low Severity", "severity_low"],

        ["Medium Severity", "severity_medium"],

        ["High Severity", "severity_high"]

    ]

    for sevInfo in severityTypes {

        AddHorizontalStatRowLive(statsGui, y, sevInfo[1] . ":", "all_" . sevInfo[2], "today_" . sevInfo[2])

        y += 12

    }

    y += 15

    ; === MACRO DETAILS ===

    AddSectionDivider(statsGui, y, "MACRO DETAILS", 660)

    y += 15

    AddHorizontalStatRowLive(statsGui, y, "Most Used Button:", "most_used_btn", "")

    y += 12

    AddHorizontalStatRowLive(statsGui, y, "Most Active Layer:", "most_active_layer", "")

    y += 15

    ; === FILE LOCATIONS ===

    AddSectionDivider(statsGui, y, "DATA FILES", 660)

    y += 15

    infoText := statsGui.Add("Text", "x" . leftCol . " y" . y . " w660", "Display Stats: " . masterStatsCSV)

    infoText.SetFont("s8")

    infoText.Opt("c" . (darkMode ? "0x888888" : "0x666666"))

    y += 18

    infoText2 := statsGui.Add("Text", "x" . leftCol . " y" . y . " w660", "Permanent Master: " . permanentStatsFile)

    infoText2.SetFont("s8")

    infoText2.Opt("c" . (darkMode ? "0x888888" : "0x666666"))

    y += 20

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

    statsGui.Show("w700 h" . (y + 40))

    statsGuiOpen := true

    ; Refresh stats frequently - in-memory aggregation keeps this lightweight
    ; Update once per second for near real-time feedback without UI stalls

    UpdateStatsDisplay()

    SetTimer(UpdateStatsDisplay, 1000)

}

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

AddSectionDivider(gui, y, text, width) {

    global darkMode

    divider := gui.Add("Text", "x20 y" . y . " w" . width, "═══ " . text . " ═══")

    divider.SetFont("s9 bold", "Consolas")

    divider.Opt("c" . (darkMode ? "0xFFFFFF" : "0x000000"))

}

AddStatsHeader(gui, y, text, x, width) {

    global darkMode

    header := gui.Add("Text", "x" . x . " y" . y . " w" . width . " Center", text)

    header.SetFont("s9 bold", "Consolas")

    header.Opt("c" . (darkMode ? "0xFFFFFF" : "0x000000"))

}

UpdateStatsDisplay() {

    global statsGuiOpen, statsControls

    if (!statsGuiOpen) {

        SetTimer(UpdateStatsDisplay, 0)

        return

    }

    try {

        ; Get fresh stats data from MEMORY (not CSV)
        allStats := ReadStatsFromMemory(false)

        todayStats := GetTodayStatsFromMemory()

        ; CRITICAL FIX: Always include LIVE active time from current session
        ; The timer UpdateActiveTime() runs every 30 seconds and accumulates time in totalActiveTime
        ; This time is only saved to CSV when macros execute, so we need to add the live accumulated time

        currentSessionStats := ReadStatsFromMemory(true)
        recordedSessionActive := (currentSessionStats.Has("session_active_time") ? currentSessionStats["session_active_time"] : 0)

        ; Get LIVE active time (includes time since last save to CSV)
        currentActiveTime := GetCurrentSessionActiveTime()

        ; Calculate effective ALL-TIME active time (CSV saved time + live unsaved time)
        effectiveAllActiveTime := (allStats.Has("session_active_time") ? allStats["session_active_time"] : 0)

        ; CRITICAL FIX: Always add current session live time, not just when it's greater than recorded
        ; This ensures that time accumulated before any macros are executed is counted
        effectiveAllActiveTime += currentActiveTime - recordedSessionActive

        if (effectiveAllActiveTime > 5000) {
            activeTimeHours := effectiveAllActiveTime / 3600000
            allStats["boxes_per_hour"] := Round(allStats["total_boxes"] / activeTimeHours, 1)
            allStats["executions_per_hour"] := Round(allStats["total_executions"] / activeTimeHours, 1)
        }

        allStats["session_active_time"] := effectiveAllActiveTime

        ; Calculate effective TODAY active time (CSV saved time + live unsaved time)
        effectiveTodayActiveTime := (todayStats.Has("session_active_time") ? todayStats["session_active_time"] : 0)

        ; CRITICAL FIX: Always add current session live time for today as well
        effectiveTodayActiveTime += currentActiveTime - recordedSessionActive

        if (effectiveTodayActiveTime > 5000) {
            activeTimeHours := effectiveTodayActiveTime / 3600000
            todayStats["boxes_per_hour"] := Round(todayStats["total_boxes"] / activeTimeHours, 1)
            todayStats["executions_per_hour"] := Round(todayStats["total_executions"] / activeTimeHours, 1)
        }

        todayStats["session_active_time"] := effectiveTodayActiveTime

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

        degradationKeys := ["smudge", "glare", "splashes", "partial", "full", "flare", "rain", "haze", "snow"]

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

CloseStatsMenu() {

    global statsGui, statsGuiOpen

    SetTimer(UpdateStatsDisplay, 0)

    if (statsGui) {

        try statsGui.Destroy()

        statsGui := ""

    }

    statsGuiOpen := false

}

ExportStatsData(statsMenuGui := "") {

    global macroExecutionLog, documentsDir

    if (!macroExecutionLog || macroExecutionLog.Length = 0) {

        MsgBox("📊 No data to export yet`n`nStart using macros to generate performance data!", "Info", "Icon!")

        return

    }

    ; Export to Documents folder for accessibility

    exportPath := documentsDir . "\MacroMaster_Stats_Export_" . FormatTime(A_Now, "yyyyMMdd_HHmmss") . ".csv"

    try {

        ; Write header
        csvContent := Stats_GetCsvHeader()

        ; Write all in-memory execution data
        for executionData in macroExecutionLog {
            csvContent .= Stats_BuildCsvRow(executionData)
        }

        ; Write to file
        FileAppend(csvContent, exportPath, "UTF-8")

        MsgBox("✅ Stats exported successfully!`n`nFile: " . exportPath . "`n`nExecutions: " . macroExecutionLog.Length . "`n`nYou can open this file in Excel or other tools.", "Export Complete", "Icon!")

    } catch Error as e {

        MsgBox("❌ Export failed: " . e.Message, "Error", "Icon!")

    }

}

ResetAllStats() {

    global macroExecutionLog, masterStatsCSV, permanentStatsFile, workDir

    result := MsgBox("This will reset ALL statistics (Today and All-Time).`n`nAll execution data will be permanently deleted.`n`n⚠️ Export your stats first if you want to keep them!`n`nReset all stats?", "Reset Statistics", "YesNo Icon!")

    if (result = "Yes") {

        try {

            ; Clear in-memory log
            macroExecutionLog := []

            ; Delete JSON stats file
            statsJsonFile := workDir . "\stats_log.json"
            if FileExist(statsJsonFile) {
                FileDelete(statsJsonFile)
            }

            ; Delete CSV file if it exists
            if FileExist(masterStatsCSV) {
                FileDelete(masterStatsCSV)
            }

            UpdateStatus("🗑️ Stats reset complete")

            MsgBox("Statistics reset complete!`n`n✅ All execution data cleared.`n`nStart using macros to build new stats!", "Reset Complete", "Icon!")

        } catch Error as e {

            UpdateStatus("⚠️ Failed to reset statistics")

            MsgBox("Failed to reset statistics: " . e.Message, "Error", "Icon!")

        }

    }

}

