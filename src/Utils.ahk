; ===== UTILITY FUNCTIONS =====
; Extracted utility functions for MacroMaster

; Helper function to get degradation type ID by name
GetDegradationTypeByName(degradationName) {
    global degradationTypes

    ; Search for the name in the degradationTypes map
    for id, name in degradationTypes {
        if (name = degradationName) {
            return id
        }
    }

    ; Default to smudge if not found
    return 1
}

IsNumberKey(keyName) {
    return RegExMatch(keyName, "^[1-9]$")
}

GetNumberFromKey(keyName) {
    if (RegExMatch(keyName, "^([1-9])$", &match)) {
        return Integer(match[1])
    }
    return 0
}

JoinArray(array, delimiter) {
    local result := ""
    for index, item in array {
        if (index > 1)
            result .= delimiter
        result .= item
    }
    return result
}

; Alias for StrJoin (used in ConfigIO.ahk)
StrJoin(array, delimiter) {
    return JoinArray(array, delimiter)
}

; ===== UTILITY FUNCTIONS =====
StrTitle(str) {
    str := StrReplace(str, "_", " ")
    return StrUpper(SubStr(str, 1, 1)) . SubStr(str, 2)
}


; ===== INTEGER VALIDATION FUNCTION =====
; Robust integer conversion for AHK v2 compatibility
EnsureInteger(value, default := 0) {
    if (value = "" || value = "NaN") {
        return default
    }

    ; Try to convert to number safely
    try {
        numericValue := Number(value)
        if (numericValue != Floor(numericValue)) {
            return Floor(numericValue)
        }
        return Integer(numericValue)
    } catch {
        ; If conversion fails, return default
        return default
    }
}