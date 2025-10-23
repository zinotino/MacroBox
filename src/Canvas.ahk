; ===== CANVAS MODULE =====
; Centralized canvas management for MacroMaster
; Handles all canvas calibration, validation, and configuration

; ===== CANVAS STATE OBJECT =====
global CanvasState := {
    wide: {
        left: 0,
        top: 0,
        right: 1920,
        bottom: 1080,
        calibrated: false
    },
    narrow: {
        left: 240,
        top: 0,
        right: 1680,
        bottom: 1080,
        calibrated: false
    },
    user: {
        left: 0,
        top: 0,
        right: 1920,
        bottom: 1080,
        calibrated: false
    }
}

; Legacy global aliases (for backwards compatibility - will be removed in future)
global wideCanvasLeft := 0
global wideCanvasTop := 0
global wideCanvasRight := 1920
global wideCanvasBottom := 1080
global isWideCanvasCalibrated := false

global narrowCanvasLeft := 240
global narrowCanvasTop := 0
global narrowCanvasRight := 1680
global narrowCanvasBottom := 1080
global isNarrowCanvasCalibrated := false

global userCanvasLeft := 0
global userCanvasTop := 0
global userCanvasRight := 1920
global userCanvasBottom := 1080
global isCanvasCalibrated := false

; ===== CANVAS INITIALIZATION =====
Canvas_Initialize() {
    global CanvasState, wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom, isWideCanvasCalibrated
    global narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom, isNarrowCanvasCalibrated
    global userCanvasLeft, userCanvasTop, userCanvasRight, userCanvasBottom, isCanvasCalibrated

    ; Initialize with default values
    CanvasState.wide.left := 0
    CanvasState.wide.top := 0
    CanvasState.wide.right := 1920
    CanvasState.wide.bottom := 1080
    CanvasState.wide.calibrated := false

    CanvasState.narrow.left := 240
    CanvasState.narrow.top := 0
    CanvasState.narrow.right := 1680
    CanvasState.narrow.bottom := 1080
    CanvasState.narrow.calibrated := false

    CanvasState.user.left := 0
    CanvasState.user.top := 0
    CanvasState.user.right := 1920
    CanvasState.user.bottom := 1080
    CanvasState.user.calibrated := false

    ; Sync to legacy globals
    Canvas_SyncToLegacyGlobals()
}

; ===== CANVAS CALIBRATION =====
Canvas_Calibrate(mode) {
    global CanvasState

    if (mode = "wide") {
        return Canvas_CalibrateWide()
    } else if (mode = "narrow") {
        return Canvas_CalibrateNarrow()
    } else if (mode = "user") {
        return Canvas_CalibrateUser()
    }
}

; Calibrate Wide Canvas (16:9)
Canvas_CalibrateWide() {
    global CanvasState

    result := MsgBox("Calibrate 16:9 Wide Canvas Area`n`nThis is for WIDE mode recordings (full screen, widescreen).`n`nClick OK then:`n1. Click TOP-LEFT corner of your 16:9 area`n2. Click BOTTOM-RIGHT corner of your 16:9 area", "Wide Canvas Calibration", "OKCancel")

    if (result = "Cancel") {
        return false
    }

    UpdateStatus("🔦 Wide: Click TOP-LEFT...")

    ; FIX: Add timeouts to prevent infinite hangs (T = timeout in seconds)
    KeyWait("LButton", "U T30")
    if (!KeyWait("LButton", "D T30")) {
        UpdateStatus("⚠️ Calibration timeout")
        return false
    }
    MouseGetPos(&x1, &y1)
    KeyWait("LButton", "U T5")

    UpdateStatus("🔦 Wide: Click BOTTOM-RIGHT...")

    if (!KeyWait("LButton", "D T30")) {
        UpdateStatus("⚠️ Calibration timeout")
        return false
    }
    MouseGetPos(&x2, &y2)
    KeyWait("LButton", "U T5")

    ; Calculate bounds
    left := Min(x1, x2)
    top := Min(y1, y2)
    right := Max(x1, x2)
    bottom := Max(y1, y2)

    canvasW := right - left
    canvasH := bottom - top

    if (canvasH = 0) {
        MsgBox("⚠️ Calibration failed: Selected area has zero height.`n`nPlease try again and select a valid area.", "Calibration Error", "Icon!")
        return false
    }

    aspectRatio := canvasW / canvasH

    ; Show confirmation
    confirmMsg := "Canvas calibrated to:`n`nLeft: " . left . "`nTop: " . top . "`nRight: " . right . "`nBottom: " . bottom . "`nAspect Ratio: " . Round(aspectRatio, 2)

    if (Abs(aspectRatio - 1.777) > 0.1) {
        confirmMsg .= "`n`n⚠️ Aspect ratio is " . Round(aspectRatio, 2) . " (expected ~1.78 for 16:9)"
    } else {
        confirmMsg .= "`n`n✅ Aspect ratio matches 16:9"
    }

    confirmMsg .= "`n`nSave this configuration?"

    result := MsgBox(confirmMsg, "Confirm Wide Canvas Calibration", "YesNo Icon?")

    if (result = "No") {
        UpdateStatus("🔄 Cancelled")
        return false
    }

    ; Save to state
    CanvasState.wide.left := left
    CanvasState.wide.top := top
    CanvasState.wide.right := right
    CanvasState.wide.bottom := bottom
    CanvasState.wide.calibrated := true

    Canvas_SyncToLegacyGlobals()
    SaveConfig()

    UpdateStatus("✅ Wide canvas calibrated")
    RefreshAllButtonAppearances()

    return true
}

; Calibrate Narrow Canvas (4:3)
Canvas_CalibrateNarrow() {
    global CanvasState

    result := MsgBox("Calibrate 4:3 Narrow Canvas Area`n`nThis is for NARROW mode recordings (constrained, square-ish).`n`nClick OK then:`n1. Click TOP-LEFT corner of your 4:3 area`n2. Click BOTTOM-RIGHT corner of your 4:3 area", "Narrow Canvas Calibration", "OKCancel")

    if (result = "Cancel") {
        return false
    }

    UpdateStatus("📱 Narrow: Click TOP-LEFT...")

    ; FIX: Add timeouts to prevent infinite hangs (T = timeout in seconds)
    KeyWait("LButton", "U T30")
    if (!KeyWait("LButton", "D T30")) {
        UpdateStatus("⚠️ Calibration timeout")
        return false
    }
    MouseGetPos(&x1, &y1)
    KeyWait("LButton", "U T5")

    UpdateStatus("📱 Narrow: Click BOTTOM-RIGHT...")

    if (!KeyWait("LButton", "D T30")) {
        UpdateStatus("⚠️ Calibration timeout")
        return false
    }
    MouseGetPos(&x2, &y2)
    KeyWait("LButton", "U T5")

    ; Calculate bounds
    left := Min(x1, x2)
    top := Min(y1, y2)
    right := Max(x1, x2)
    bottom := Max(y1, y2)

    canvasW := right - left
    canvasH := bottom - top

    if (canvasH = 0) {
        MsgBox("⚠️ Calibration failed: Selected area has zero height.`n`nPlease try again and select a valid area.", "Calibration Error", "Icon!")
        return false
    }

    aspectRatio := canvasW / canvasH

    ; Show confirmation
    confirmMsg := "Canvas calibrated to:`n`nLeft: " . left . "`nTop: " . top . "`nRight: " . right . "`nBottom: " . bottom . "`nAspect Ratio: " . Round(aspectRatio, 2)

    if (Abs(aspectRatio - 1.333) > 0.1) {
        confirmMsg .= "`n`n⚠️ Aspect ratio is " . Round(aspectRatio, 2) . " (expected ~1.33 for 4:3)"
    } else {
        confirmMsg .= "`n`n✅ Aspect ratio matches 4:3"
    }

    confirmMsg .= "`n`nSave this configuration?"

    result := MsgBox(confirmMsg, "Confirm Narrow Canvas Calibration", "YesNo Icon?")

    if (result = "No") {
        UpdateStatus("🔄 Cancelled")
        return false
    }

    ; Save to state
    CanvasState.narrow.left := left
    CanvasState.narrow.top := top
    CanvasState.narrow.right := right
    CanvasState.narrow.bottom := bottom
    CanvasState.narrow.calibrated := true

    Canvas_SyncToLegacyGlobals()
    SaveConfig()

    UpdateStatus("✅ Narrow canvas calibrated")
    RefreshAllButtonAppearances()

    return true
}

; Calibrate User Canvas (custom)
Canvas_CalibrateUser() {
    global CanvasState

    result := MsgBox("Define your canvas area for accurate macro visualization.`n`nClick OK then:`n1. Click TOP-LEFT corner of your canvas`n2. Click BOTTOM-RIGHT corner of your canvas", "Canvas Calibration", "OKCancel")

    if (result = "Cancel") {
        return false
    }

    UpdateStatus("📐 Click TOP-LEFT...")

    ; FIX: Add timeouts to prevent infinite hangs (T = timeout in seconds)
    KeyWait("LButton", "U T30")
    if (!KeyWait("LButton", "D T30")) {
        UpdateStatus("⚠️ Calibration timeout")
        return false
    }
    MouseGetPos(&x1, &y1)
    KeyWait("LButton", "U T5")

    UpdateStatus("📐 Click BOTTOM-RIGHT...")

    if (!KeyWait("LButton", "D T30")) {
        UpdateStatus("⚠️ Calibration timeout")
        return false
    }
    MouseGetPos(&x2, &y2)
    KeyWait("LButton", "U T5")

    ; Calculate bounds
    left := Min(x1, x2)
    top := Min(y1, y2)
    right := Max(x1, x2)
    bottom := Max(y1, y2)

    canvasW := right - left
    canvasH := bottom - top

    if (canvasH = 0) {
        MsgBox("⚠️ Calibration failed: Selected area has zero height.`n`nPlease try again and select a valid area.", "Calibration Error", "Icon!")
        return false
    }

    canvasAspect := Round(canvasW / canvasH, 2)

    ; Show confirmation
    confirmMsg := "Canvas calibrated to:`n`nLeft: " . left . "`nTop: " . top . "`nRight: " . right . "`nBottom: " . bottom . "`nSize: " . canvasW . "x" . canvasH . "`nAspect Ratio: " . canvasAspect . ":1`n`nSave this configuration?"

    result := MsgBox(confirmMsg, "Confirm Canvas Calibration", "YesNo Icon?")

    if (result = "No") {
        UpdateStatus("🔄 Cancelled")
        return false
    }

    ; Save to state
    CanvasState.user.left := left
    CanvasState.user.top := top
    CanvasState.user.right := right
    CanvasState.user.bottom := bottom
    CanvasState.user.calibrated := true

    Canvas_SyncToLegacyGlobals()
    SaveConfig()

    UpdateStatus("✅ Canvas calibrated: " . canvasW . "x" . canvasH)
    RefreshAllButtonAppearances()

    return true
}

; ===== CANVAS RESET =====
Canvas_Reset(mode) {
    global CanvasState

    if (mode = "wide") {
        result := MsgBox("Reset Wide canvas calibration to automatic detection?", "Reset Wide Canvas", "YesNo")
        if (result = "Yes") {
            CanvasState.wide.calibrated := false
            Canvas_SyncToLegacyGlobals()
            UpdateStatus("🔄 Wide canvas reset")
            RefreshAllButtonAppearances()
            SaveConfig()
            return true
        }
    } else if (mode = "narrow") {
        result := MsgBox("Reset Narrow canvas calibration to automatic detection?", "Reset Narrow Canvas", "YesNo")
        if (result = "Yes") {
            CanvasState.narrow.calibrated := false
            Canvas_SyncToLegacyGlobals()
            UpdateStatus("🔄 Narrow canvas reset")
            RefreshAllButtonAppearances()
            SaveConfig()
            return true
        }
    } else if (mode = "user") {
        result := MsgBox("Reset canvas calibration to automatic detection?", "Reset Canvas", "YesNo")
        if (result = "Yes") {
            CanvasState.user.calibrated := false
            Canvas_SyncToLegacyGlobals()
            UpdateStatus("🔄 Canvas reset")
            RefreshAllButtonAppearances()
            SaveConfig()
            return true
        }
    }

    return false
}

; ===== CHECK CANVAS CONFIGURATION =====
Canvas_CheckConfiguration() {
    global CanvasState

    ; Check if canvas coordinates are actually configured (not default values) or flags are set
    wideConfigured := (CanvasState.wide.left != 0 || CanvasState.wide.top != 0 || CanvasState.wide.right != 1920 || CanvasState.wide.bottom != 1080) || CanvasState.wide.calibrated
    narrowConfigured := (CanvasState.narrow.left != 240 || CanvasState.narrow.top != 0 || CanvasState.narrow.right != 1680 || CanvasState.narrow.bottom != 1080) || CanvasState.narrow.calibrated
    userConfigured := (CanvasState.user.left != 0 || CanvasState.user.top != 0 || CanvasState.user.right != 1920 || CanvasState.user.bottom != 1080) || CanvasState.user.calibrated

    ; Check if neither canvas is actually configured
    if (!wideConfigured && !narrowConfigured && !userConfigured) {
        result := MsgBox("🖼️ THUMBNAIL CANVAS CONFIGURATION`n`n" .
                        "Would you like to configure your canvas areas for picture-perfect thumbnails?`n`n" .
                        "⚡ RECOMMENDED: Configure both Wide and Narrow canvas areas`n" .
                        "• Wide canvas: For landscape/widescreen recordings`n" .
                        "• Narrow canvas: For portrait/square recordings`n`n" .
                        "⚠️ WITHOUT configuration: Thumbnails will auto-detect but may not be pixel-perfect`n`n" .
                        "Configure now?", "Thumbnail Integration Setup", "YesNo Icon?")

        if (result = "Yes") {
            ShowSettings()
            UpdateStatus("🖼️ Configure both Wide and Narrow canvas areas in Settings → Configuration tab")
        } else {
            UpdateStatus("⚠️ Thumbnail auto-detection active - Configure canvas areas in Settings for pixel-perfect thumbnails")
        }
    }
}

; ===== SYNC TO LEGACY GLOBALS =====
; Maintains backwards compatibility with existing code
Canvas_SyncToLegacyGlobals() {
    global CanvasState
    global wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom, isWideCanvasCalibrated
    global narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom, isNarrowCanvasCalibrated
    global userCanvasLeft, userCanvasTop, userCanvasRight, userCanvasBottom, isCanvasCalibrated

    ; Wide canvas
    wideCanvasLeft := CanvasState.wide.left
    wideCanvasTop := CanvasState.wide.top
    wideCanvasRight := CanvasState.wide.right
    wideCanvasBottom := CanvasState.wide.bottom
    isWideCanvasCalibrated := CanvasState.wide.calibrated

    ; Narrow canvas
    narrowCanvasLeft := CanvasState.narrow.left
    narrowCanvasTop := CanvasState.narrow.top
    narrowCanvasRight := CanvasState.narrow.right
    narrowCanvasBottom := CanvasState.narrow.bottom
    isNarrowCanvasCalibrated := CanvasState.narrow.calibrated

    ; User canvas
    userCanvasLeft := CanvasState.user.left
    userCanvasTop := CanvasState.user.top
    userCanvasRight := CanvasState.user.right
    userCanvasBottom := CanvasState.user.bottom
    isCanvasCalibrated := CanvasState.user.calibrated
}

; ===== SYNC FROM LEGACY GLOBALS =====
; Called when loading config to update CanvasState from legacy globals
Canvas_SyncFromLegacyGlobals() {
    global CanvasState
    global wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom, isWideCanvasCalibrated
    global narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom, isNarrowCanvasCalibrated
    global userCanvasLeft, userCanvasTop, userCanvasRight, userCanvasBottom, isCanvasCalibrated

    ; Wide canvas
    CanvasState.wide.left := wideCanvasLeft
    CanvasState.wide.top := wideCanvasTop
    CanvasState.wide.right := wideCanvasRight
    CanvasState.wide.bottom := wideCanvasBottom
    CanvasState.wide.calibrated := isWideCanvasCalibrated

    ; Narrow canvas
    CanvasState.narrow.left := narrowCanvasLeft
    CanvasState.narrow.top := narrowCanvasTop
    CanvasState.narrow.right := narrowCanvasRight
    CanvasState.narrow.bottom := narrowCanvasBottom
    CanvasState.narrow.calibrated := isNarrowCanvasCalibrated

    ; User canvas
    CanvasState.user.left := userCanvasLeft
    CanvasState.user.top := userCanvasTop
    CanvasState.user.right := userCanvasRight
    CanvasState.user.bottom := userCanvasBottom
    CanvasState.user.calibrated := isCanvasCalibrated
}
