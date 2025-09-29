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

; ===== UTILITY FUNCTIONS =====
StrTitle(str) {
    str := StrReplace(str, "_", " ")
    return StrUpper(SubStr(str, 1, 1)) . SubStr(str, 2)
}

; Format milliseconds to human-readable time
FormatMillisecondsToTime(ms) {
    if (ms < 1000) {
        return ms . " ms"
    }

    seconds := Round(ms / 1000, 1)
    if (seconds < 60) {
        return seconds . " sec"
    }

    minutes := Floor(seconds / 60)
    remainingSeconds := Mod(seconds, 60)

    if (minutes < 60) {
        return minutes . "m " . Round(remainingSeconds) . "s"
    }

    hours := Floor(minutes / 60)
    remainingMinutes := Mod(minutes, 60)

    return hours . "h " . remainingMinutes . "m"
}

DeleteFile(filePath) {
    ; Helper function for safe file deletion
    try {
        if (FileExist(filePath))
            FileDelete(filePath)
    } catch {
        ; Ignore deletion errors for temporary files
    }
}

RunWaitOne(command) {
    ; Simple wrapper to run command and get output
    shell := ComObject("WScript.Shell")
    exec := shell.Exec(command)
    output := ""

    ; Wait for completion and read output
    while !exec.Status {
        Sleep(10)
    }

    if exec.StdOut.AtEndOfStream {
        return ""
    }

    while !exec.StdOut.AtEndOfStream {
        output .= exec.StdOut.ReadLine() . "`n"
    }

    return Trim(output)
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