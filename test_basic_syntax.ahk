; ===== BASIC SYNTAX TEST =====
#Requires AutoHotkey v2.0
#SingleInstance Force

; Test basic functionality
MsgBox("Basic test starting...")

; Test CSV creation
csvPath := A_MyDocuments . "\MacroMaster\data\master_stats.csv"
MsgBox("CSV path: " . csvPath)

; Test directory creation
dataDir := A_MyDocuments . "\MacroMaster\data"
if (!DirExist(dataDir)) {
    DirCreate(dataDir)
}

; Test file creation
header := "timestamp,session_id,username,execution_type,button_key,layer,execution_time_ms,total_boxes`n"
FileAppend(header, csvPath)

if FileExist(csvPath) {
    MsgBox("✅ CSV created successfully!")
} else {
    MsgBox("❌ CSV creation failed!")
}

ExitApp