#Requires AutoHotkey v2.0
; Test canvas configuration loading

; Simulate the config loading
narrowCanvasLeft := 240  ; Default
narrowCanvasTop := 0
narrowCanvasRight := 1680
narrowCanvasBottom := 1080
isNarrowCanvasCalibrated := false

; Load from file (simulate)
narrowCanvasLeft := 415
narrowCanvasTop := 199
narrowCanvasRight := 1283
narrowCanvasBottom := 999
isNarrowCanvasCalibrated := true

; Test the check
narrowConfigured := (narrowCanvasLeft != 240 || narrowCanvasTop != 0 || narrowCanvasRight != 1680 || narrowCanvasBottom != 1080) || isNarrowCanvasCalibrated

MsgBox("Narrow Canvas Loaded Values:`n`n" .
       "Left: " . narrowCanvasLeft . " (expected 415)`n" .
       "Top: " . narrowCanvasTop . " (expected 199)`n" .
       "Right: " . narrowCanvasRight . " (expected 1283)`n" .
       "Bottom: " . narrowCanvasBottom . " (expected 999)`n" .
       "IsCalibrated: " . isNarrowCanvasCalibrated . " (expected 1)`n`n" .
       "narrowConfigured check result: " . narrowConfigured . " (should be TRUE/1)")
