/*
==============================================================================
VISUALIZATION UTILS MODULE - Helper functions for visualization
==============================================================================
Handles event extraction, background colors, and visual indicators
*/

; ===== BOX EVENT EXTRACTION =====
ExtractBoxEvents(macroEvents) {
    boxes := []
    currentDegradationType := 1  ; Default degradation type

    ; DEBUG: Log what we're looking for
    ; UpdateStatus("🔍 DEBUG: ExtractBoxEvents called with " . macroEvents.Length . " events")

    ; Look for boundingBox events and keypress assignments in MacroLauncherX44 format
    for eventIndex, event in macroEvents {
        ; DEBUG: Check event types
        ; if (eventIndex <= 5) {
        ;     UpdateStatus("🔍 DEBUG: Event " . eventIndex . ": type=" . event.type)
        ; }

        if (event.type = "boundingBox" && event.HasOwnProp("left") && event.HasOwnProp("top") && event.HasOwnProp("right") && event.HasOwnProp("bottom")) {
            ; Calculate box dimensions
            left := event.left
            top := event.top
            right := event.right
            bottom := event.bottom

            ; Only include boxes that are reasonably sized
            if ((right - left) >= 5 && (bottom - top) >= 5) {
                ; Look for a keypress AFTER this box to determine degradation type
                degradationType := currentDegradationType

                ; Look ahead for keypress events that assign degradation type
                nextIndex := eventIndex + 1
                while (nextIndex <= macroEvents.Length) {
                    nextEvent := macroEvents[nextIndex]

                    ; Stop at next bounding box - keypress should be immediately after current box
                    if (nextEvent.type = "boundingBox")
                        break

                    ; Found a keypress after this box - this assigns the degradation type
                    if (nextEvent.type = "keyDown" && RegExMatch(nextEvent.key, "^\d$")) {
                        keyNumber := Integer(nextEvent.key)
                        if (keyNumber >= 1 && keyNumber <= 9) {
                            degradationType := keyNumber
                            currentDegradationType := keyNumber  ; Update current degradation for subsequent boxes
                            break
                        }
                    }

                    nextIndex++
                }

                box := {
                    left: left,
                    top: top,
                    right: right,
                    bottom: bottom,
                    degradationType: degradationType
                }
                boxes.Push(box)
                ; DEBUG: Log found box
                ; UpdateStatus("🔍 DEBUG: Found box: " . left . "," . top . " to " . right . "," . bottom . " (type: " . degradationType . ")")
            }
        }
    }

    ; DEBUG: Log result
    ; UpdateStatus("🔍 DEBUG: ExtractBoxEvents returning " . boxes.Length . " boxes")

    return boxes
}

; ===== BACKGROUND COLOR SELECTION =====

; ===== CANVAS TYPE INDICATOR =====
