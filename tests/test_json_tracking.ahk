#Requires AutoHotkey v2.0
; Test script to create JSON profile executions for testing

; Add some test JSON profile entries to the CSV file
csvPath := "C:\Users\ajnef\Documents\MacroMaster\data\master_stats.csv"

; Create test JSON profile execution entries
testEntries := [
    "2025-09-18 08:20:01,test_json_session,ajnef,json_profile,Num7,2,234,1,glare,high,wide,120000,False",
    "2025-09-18 08:20:30,test_json_session,ajnef,json_profile,Num4,2,189,1,smudge,medium,wide,149000,False",
    "2025-09-18 08:21:15,test_json_session,ajnef,json_profile,Num1,2,267,1,partial_blockage,high,wide,194000,False"
]

; Append test entries to CSV
try {
    file := FileOpen(csvPath, "a", "UTF-8")
    for entry in testEntries {
        file.WriteLine(entry)
    }
    file.Close()
    MsgBox("Added " . testEntries.Length . " test JSON profile executions to CSV")
} catch Error as e {
    MsgBox("Error writing to CSV: " . e.Message)
}