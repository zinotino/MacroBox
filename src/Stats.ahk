; ===== STATS MODULE =====
; Provides statistics data I/O and GUI aggregation for MacroMaster
;
; Expected globals (defined in Core.ahk):
;   workDir, documentsDir, thumbnailDir
;   sessionId, currentUsername
;   masterStatsCSV (display stats)
;   permanentStatsFile (permanent archive)
; Required helper functions: UpdateStatus, RunWaitOne

#Include "StatsData.ahk"
#Include "StatsGui.ahk"
