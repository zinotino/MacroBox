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

    ; Look for boundingBox events and keypress assignments in MacroLauncherX44 format
    for eventIndex, event in macroEvents {
        ; Handle both Map and Object types
        eventType := ""
        hasProps := false
        if (Type(event) = "Map") {
            eventType := event.Has("type") ? event["type"] : ""
            hasProps := event.Has("left") && event.Has("top") && event.Has("right") && event.Has("bottom")
        } else if (IsObject(event)) {
            eventType := event.HasOwnProp("type") ? event.type : ""
            hasProps := event.HasOwnProp("left") && event.HasOwnProp("top") && event.HasOwnProp("right") && event.HasOwnProp("bottom")
        }

        if (eventType = "boundingBox" && hasProps) {
            ; Calculate box dimensions (support both Map and Object)
            left := (Type(event) = "Map") ? event["left"] : event.left
            top := (Type(event) = "Map") ? event["top"] : event.top
            right := (Type(event) = "Map") ? event["right"] : event.right
            bottom := (Type(event) = "Map") ? event["bottom"] : event.bottom

            ; Only include boxes that are reasonably sized
            if ((right - left) >= 5 && (bottom - top) >= 5) {
                ; Check if box already has degradationType property
                degradationType := currentDegradationType
                if (Type(event) = "Map") {
                    if (event.Has("degradationType")) {
                        degradationType := event["degradationType"]
                        currentDegradationType := degradationType
                    }
                } else if (IsObject(event)) {
                    if (event.HasOwnProp("degradationType")) {
                        degradationType := event.degradationType
                        currentDegradationType := degradationType
                    }
                }

                ; If no degradationType in box, look for keypress AFTER this box
                if (degradationType = currentDegradationType) {
                    nextIndex := eventIndex + 1
                    while (nextIndex <= macroEvents.Length) {
                        nextEvent := macroEvents[nextIndex]

                        ; Get next event type (support Map and Object)
                        nextEventType := ""
                        if (Type(nextEvent) = "Map") {
                            nextEventType := nextEvent.Has("type") ? nextEvent["type"] : ""
                        } else if (IsObject(nextEvent)) {
                            nextEventType := nextEvent.HasOwnProp("type") ? nextEvent.type : ""
                        }

                        ; Stop at next bounding box - keypress should be immediately after current box
                        if (nextEventType = "boundingBox")
                            break

                        ; Found a keypress after this box - this assigns the degradation type
                        if (nextEventType = "keyDown") {
                            nextKey := (Type(nextEvent) = "Map") ? (nextEvent.Has("key") ? nextEvent["key"] : "") : (nextEvent.HasOwnProp("key") ? nextEvent.key : "")
                            if (RegExMatch(nextKey, "^\d$")) {
                                keyNumber := Integer(nextKey)
                                if (keyNumber >= 1 && keyNumber <= 9) {
                                    degradationType := keyNumber
                                    currentDegradationType := keyNumber
                                    break
                                }
                            }
                        }

                        nextIndex++
                    }
                }

                box := {
                    left: left,
                    top: top,
                    right: right,
                    bottom: bottom,
                    degradationType: degradationType
                }
                boxes.Push(box)
            }
        }
    }

    return boxes
}
