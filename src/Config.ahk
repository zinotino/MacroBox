; ===== PROCESSING FUNCTIONS =====
ProcessCustomLabel(key, value) {
    global buttonCustomLabels

    if (buttonCustomLabels.Has(key)) {
        buttonCustomLabels[key] := value
    }
}

ProcessMacroLine(key, value) {
    global macroEvents, degradationTypes

    if (value = "") {
        return false
    }

    ; Initialize macro events array
    if (!macroEvents.Has(key)) {
        macroEvents[key] := []
    }

    ; Parse event string
    eventStrings := StrSplit(value, "|")

    for eventStr in eventStrings {
        parts := StrSplit(eventStr, ",")
        if (parts.Length = 0)
            continue

        eventType := parts[1]
        event := {type: eventType}

        ; Parse different event types
        validEvent := false
        switch eventType {
            case "boundingBox":
                if (parts.Length >= 5) {
                    event.left := EnsureInteger(parts[2], 0)
                    event.top := EnsureInteger(parts[3], 0)
                    event.right := EnsureInteger(parts[4], 0)
                    event.bottom := EnsureInteger(parts[5], 0)
                    ; PHASE 2B: Load ALL degradation properties for complete persistence
                    if (parts.Length >= 6) {
                        ; Check if part 6 is degradationType (number 1-9) or isTagged (0/1)
                        part6Value := EnsureInteger(parts[6], 1)
                        if (part6Value >= 1 && part6Value <= 9) {
                            event.degradationType := part6Value
                        } else {
                            event.isTagged := (parts[6] = "1")
                            event.degradationType := 1  ; Default to smudge
                        }
                    } else {
                        event.degradationType := 1  ; Default to smudge if not saved
                    }
                    ; PHASE 2B: Load degradationName (part 7)
                    if (parts.Length >= 7 && parts[7] != "") {
                        event.degradationName := parts[7]
                    } else {
                        ; Default based on degradationType (with safety check)
                        if (IsSet(degradationTypes) && degradationTypes.Has(event.degradationType)) {
                            event.degradationName := degradationTypes[event.degradationType]
                        } else {
                            event.degradationName := "smudge"
                        }
                    }
                    ; PHASE 2B: Load assignedBy (part 8)
                    if (parts.Length >= 8) {
                        event.assignedBy := parts[8]
                    } else {
                        event.assignedBy := "auto_default"
                    }
                    validEvent := true
                }

            case "jsonAnnotation":
                if (parts.Length >= 4) {
                    event.mode := parts[2]
                    event.categoryId := EnsureInteger(parts[3], 1)
                    event.severity := parts[4]
                    if (parts.Length >= 5) {
                        event.isTagged := (parts[5] = "1")
                    }
                    validEvent := true
                }

            case "keyDown", "keyUp":
                if (parts.Length >= 2) {
                    event.key := parts[2]
                    validEvent := true
                }

            case "mouseDown", "mouseUp":
                if (parts.Length >= 4) {
                    event.x := EnsureInteger(parts[2], 0)
                    event.y := EnsureInteger(parts[3], 0)
                    event.button := parts[4]
                    validEvent := true
                }

            default:
                ; Generic event with optional x,y
                if (parts.Length >= 2) {
                    event.x := EnsureInteger(parts[2], 0)
                }
                if (parts.Length >= 3) {
                    event.y := EnsureInteger(parts[3], 0)
                }
                validEvent := true
        }

        if (validEvent) {
            macroEvents[key].Push(event)
        }
    }

    return macroEvents[key].Length > 0
}


; ===== GLOBAL CONFIGURATION VARIABLES =====

; Core application state
global annotationMode := "Wide"
global darkMode := true
global currentDegradation := 1  ; Intelligent system state (no per-layer)

; Window settings
global windowWidth := 1200
global windowHeight := 800
global scaleFactor := 1.0
global minWindowWidth := 900
global minWindowHeight := 600

; Canvas settings
global canvasWidth := 1920
global canvasHeight := 1080
global canvasType := "Wide"
global canvasAspectRatio := 1.777
global isCanvasCalibrated := false
global isWideCanvasCalibrated := false
global isNarrowCanvasCalibrated := false

; Canvas coordinates
global wideCanvasLeft := 0
global wideCanvasTop := 0
global wideCanvasRight := 1920
global wideCanvasBottom := 1080

global narrowCanvasLeft := 240
global narrowCanvasTop := 0
global narrowCanvasRight := 1680
global narrowCanvasBottom := 1080

global userCanvasLeft := 0
global userCanvasTop := 0
global userCanvasRight := 1920
global userCanvasBottom := 1080

; Hotkey settings
global hotkeyRecordToggle := "F9"
global hotkeySubmit := "+Enter"
global hotkeyDirectClear := "NumpadEnter"
global hotkeyStats := ""
global hotkeyBreakMode := "^b"
global hotkeySettings := ""

; WASD settings
global hotkeyProfileActive := true  ; FIXED: Was false, should default to true
global wasdLabelsEnabled := false


; Timing settings
global boxDrawDelay := 75
global mouseClickDelay := 85
global menuClickDelay := 150
global mouseDragDelay := 90

; ===== INTELLIGENT TIMING SYSTEM - UNIQUE DELAYS =====
global smartBoxClickDelay := 35    ; Optimized for fast box drawing in intelligent system
global smartMenuClickDelay := 120  ; Optimized for accurate menu selections in intelligent system
global mouseReleaseDelay := 90
global betweenBoxDelay := 200
global keyPressDelay := 20
global focusDelay := 80
global mouseHoverDelay := 35

; Macro and button data
global macroEvents := Map()
global buttonNames := ["Num7", "Num8", "Num9", "Num4", "Num5", "Num6", "Num1", "Num2", "Num3", "Num0", "NumDot", "NumMult"]
global buttonCustomLabels := Map()
global buttonThumbnails := Map()  ; Custom thumbnail file paths (kept per user request)


; ===== CANVAS VALIDATION =====
ValidateAndFixCanvasValues() {
    global wideCanvasLeft, wideCanvasTop, wideCanvasRight, wideCanvasBottom, isWideCanvasCalibrated
    global narrowCanvasLeft, narrowCanvasTop, narrowCanvasRight, narrowCanvasBottom, isNarrowCanvasCalibrated
    global userCanvasLeft, userCanvasTop, userCanvasRight, userCanvasBottom, isCanvasCalibrated
    global hbitmapCache

    ; Track if any canvas values were reset
    canvasReset := false

    ; Validate wide canvas
    if (!IsNumber(wideCanvasLeft) || !IsNumber(wideCanvasTop) || !IsNumber(wideCanvasRight) || !IsNumber(wideCanvasBottom) ||
        wideCanvasRight <= wideCanvasLeft || wideCanvasBottom <= wideCanvasTop) {
        wideCanvasLeft := 0
        wideCanvasTop := 0
        wideCanvasRight := 1920
        wideCanvasBottom := 1080
        isWideCanvasCalibrated := false
        canvasReset := true
    }

    ; Validate narrow canvas
    if (!IsNumber(narrowCanvasLeft) || !IsNumber(narrowCanvasTop) || !IsNumber(narrowCanvasRight) || !IsNumber(narrowCanvasBottom) ||
        narrowCanvasRight <= narrowCanvasLeft || narrowCanvasBottom <= narrowCanvasTop) {
        narrowCanvasLeft := 240
        narrowCanvasTop := 0
        narrowCanvasRight := 1680
        narrowCanvasBottom := 1080
        isNarrowCanvasCalibrated := false
        canvasReset := true
    }

    ; Validate user canvas
    if (!IsNumber(userCanvasLeft) || !IsNumber(userCanvasTop) || !IsNumber(userCanvasRight) || !IsNumber(userCanvasBottom) ||
        userCanvasRight <= userCanvasLeft || userCanvasBottom <= userCanvasTop) {
        userCanvasLeft := 0
        userCanvasTop := 0
        userCanvasRight := 1920
        userCanvasBottom := 1080
        isCanvasCalibrated := false
        canvasReset := true
    }

    ; If any canvas values were reset, clear the HBITMAP cache since cached visualizations may be invalid
    if (canvasReset && IsObject(hbitmapCache)) {
        for cacheKey, hbitmap in hbitmapCache {
            if (hbitmap && hbitmap != 0) {
                try {
                    DllCall("DeleteObject", "Ptr", hbitmap)
                } catch {
                    ; Ignore cleanup errors
                }
            }
        }
        hbitmapCache := Map()
    }

    if (canvasReset) {
        UpdateStatus("⚠️ Canvas values were reset")
    }
}

