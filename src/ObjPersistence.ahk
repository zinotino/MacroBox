#Requires AutoHotkey v2.0

ObjSave(obj, path) {
    try {
        json := ObjToJson(obj)
        file := FileOpen(path, "w", "UTF-8")
        if (!file)
            return false
        file.Write(json)
        file.Close()
        return true
    } catch {
        return false
    }
}

ObjLoad(path) {
    try {
        if (!FileExist(path))
            return Map()
        json := FileRead(path, "UTF-8")
        data := JsonToObj(json)
        return (Type(data) = "Map") ? data : Map()
    } catch {
        return Map()
    }
}

ObjToJson(value) {
    if (value === true)
        return "true"
    if (value === false)
        return "false"

    valueType := Type(value)

    if (valueType = "Map") {
        parts := []
        for key, item in value {
            keyJson := JsonString(String(key))
            parts.Push(keyJson . ":" . ObjToJson(item))
        }
        return "{" . StrJoin(parts, ",") . "}"
    }

    if (valueType = "Array") {
        parts := []
        for item in value {
            parts.Push(ObjToJson(item))
        }
        return "[" . StrJoin(parts, ",") . "]"
    }

    if (valueType = "String")
        return JsonString(value)

    if (valueType = "Integer" || valueType = "Float")
        return String(value)

    if (valueType = "ComValue")
        return "null"

    try {
        return JsonString(String(value))
    } catch {
        return "null"
    }
}

JsonString(text) {
    quote := Chr(34)
    return quote . JsonEscape(text) . quote
}

JsonEscape(text) {
    result := ""
    backslash := Chr(92)
    quote := Chr(34)
    Loop Parse text {
        ch := A_LoopField
        code := Ord(ch)
        if (code = 8) {
            result .= backslash . "b"
        } else if (code = 9) {
            result .= backslash . "t"
        } else if (code = 10) {
            result .= backslash . "n"
        } else if (code = 12) {
            result .= backslash . "f"
        } else if (code = 13) {
            result .= backslash . "r"
        } else if (code = 34) {
            result .= backslash . quote
        } else if (code = 92) {
            result .= backslash . backslash
        } else if (code < 0x20) {
            result .= Format("\\u{:04X}", code)
        } else {
            result .= ch
        }
    }
    return result
}

JsonToObj(jsonText) {
    state := Map(
        "text", jsonText,
        "pos", 1,
        "len", StrLen(jsonText)
    )
    value := JsonParseValue(state)
    JsonSkipWhitespace(state)
    return value
}

JsonParseValue(state) {
    JsonSkipWhitespace(state)
    text := state["text"]
    pos := state["pos"]
    len := state["len"]

    if (pos > len)
        throw Error("Unexpected end of JSON input")

    char := SubStr(text, pos, 1)

    if (char = "{")
        return JsonParseObject(state)
    if (char = "[")
        return JsonParseArray(state)
    if (char = Chr(34))
        return JsonParseString(state)

    if (SubStr(text, pos, 4) = "null") {
        state["pos"] := pos + 4
        return ComValue(1, 0)
    }
    if (SubStr(text, pos, 4) = "true") {
        state["pos"] := pos + 4
        return true
    }
    if (SubStr(text, pos, 5) = "false") {
        state["pos"] := pos + 5
        return false
    }

    return JsonParseNumber(state)
}

JsonParseObject(state) {
    obj := Map()
    state["pos"]++
    JsonSkipWhitespace(state)
    text := state["text"]
    pos := state["pos"]

    if (SubStr(text, pos, 1) = "}") {
        state["pos"] := pos + 1
        return obj
    }

    while true {
        key := JsonParseString(state)
        JsonSkipWhitespace(state)
        text := state["text"]
        pos := state["pos"]
        if (SubStr(text, pos, 1) != ":")
            throw Error("Expected ':' in object")
        state["pos"] := pos + 1
        value := JsonParseValue(state)
        obj[key] := value
        JsonSkipWhitespace(state)
        text := state["text"]
        pos := state["pos"]
        char := SubStr(text, pos, 1)
        if (char = "}") {
            state["pos"] := pos + 1
            break
        }
        if (char != ",")
            throw Error("Expected ',' or '}' in object")
        state["pos"] := pos + 1
    }
    return obj
}

JsonParseArray(state) {
    arr := []
    state["pos"]++
    JsonSkipWhitespace(state)
    text := state["text"]
    pos := state["pos"]

    if (SubStr(text, pos, 1) = "]") {
        state["pos"] := pos + 1
        return arr
    }

    while true {
        arr.Push(JsonParseValue(state))
        JsonSkipWhitespace(state)
        text := state["text"]
        pos := state["pos"]
        char := SubStr(text, pos, 1)
        if (char = "]") {
            state["pos"] := pos + 1
            break
        }
        if (char != ",")
            throw Error("Expected ',' or ']' in array")
        state["pos"] := pos + 1
    }
    return arr
}

JsonParseString(state) {
    text := state["text"]
    pos := state["pos"] + 1
    len := state["len"]
    quote := Chr(34)
    backslash := Chr(92)
    result := ""

    while pos <= len {
        char := SubStr(text, pos, 1)
        if (char = quote) {
            state["pos"] := pos + 1
            return result
        }
        if (char = backslash) {
            pos++
            if (pos > len)
                throw Error("Unexpected end of string")
            escapeChar := SubStr(text, pos, 1)
            if (escapeChar = quote || escapeChar = "/") {
                result .= escapeChar
            } else if (escapeChar = "b") {
                result .= Chr(8)
            } else if (escapeChar = "f") {
                result .= Chr(12)
            } else if (escapeChar = "n") {
                result .= "`n"
            } else if (escapeChar = "r") {
                result .= "`r"
            } else if (escapeChar = "t") {
                result .= "`t"
            } else if (escapeChar = "u") {
                hex := SubStr(text, pos + 1, 4)
                if (StrLen(hex) < 4)
                    throw Error("Invalid unicode escape")
                result .= Chr("0x" . hex)
                pos += 4
            } else if (escapeChar = backslash) {
                result .= backslash
            } else {
                throw Error("Invalid escape sequence")
            }
        } else {
            result .= char
        }
        pos++
    }

    throw Error("Unterminated string")
}

JsonParseNumber(state) {
    text := state["text"]
    pos := state["pos"]
    len := state["len"]
    start := pos
    validChars := "0123456789+-.eE"
    while (pos <= len && InStr(validChars, SubStr(text, pos, 1)))
        pos++
    numberText := SubStr(text, start, pos - start)
    if (numberText = "")
        throw Error("Invalid number")
    state["pos"] := pos
    if (InStr(numberText, ".") || InStr(numberText, "e") || InStr(numberText, "E"))
        return numberText + 0.0
    return Integer(numberText)
}

JsonSkipWhitespace(state) {
    text := state["text"]
    pos := state["pos"]
    len := state["len"]
    while (pos <= len && InStr(" `t`r`n", SubStr(text, pos, 1)))
        pos++
    state["pos"] := pos
}


StrJoin(array, sep) {
    result := ""
    for index, element in array
        result .= (index = 1 ? "" : sep) . element
    return result
}
