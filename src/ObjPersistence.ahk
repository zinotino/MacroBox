; ===== OBJECT PERSISTENCE MODULE =====
; Simple JSON save/load for stats persistence

ObjSave(obj, path) {
    file := ""
    try {
        data := ObjToString(obj)
        file := FileOpen(path, "w", "UTF-8")
        if (!file)
            return false
        file.Write(data)
        return true
    } catch {
        return false
    } finally {
        if (IsObject(file))
            file.Close()
    }
}

ObjLoad(path) {
    try {
        if (!FileExist(path))
            return Map()
        data := FileRead(path, "UTF-8")
        result := StrToObj(data)
        return IsObject(result) ? result : Map()
    } catch {
        return Map()
    }
}

ObjToString(value) {
    if (value == true)
        return "true"
    if (value == false)
        return "false"

    valueType := Type(value)
    if (valueType = "ComValue")
        return "null"

    if (valueType = "Map") {
        items := []
        for key, itemValue in value {
            keyText := ObjToString(String(key))
            items.Push(keyText . ":" . ObjToString(itemValue))
        }
        return "{" . StrJoin(items, ",") . "}"
    }

    if (valueType = "Array") {
        items := []
        for element in value {
            items.Push(ObjToString(element))
        }
        return "[" . StrJoin(items, ",") . "]"
    }

    if (valueType = "String") {
        quote := Chr(34)
        return quote . JsonEscape(value) . quote
    }

    return String(value)
}

StrToObj(text) {
    try {
        pos := 1
        return Jxon_ParseValue(text, &pos)
    } catch {
        return Map()
    }
}

Jxon_ParseValue(text, &pos) {
    Jxon_SkipWhitespace(text, &pos)
    if (pos > StrLen(text))
        throw Error("Unexpected end")

    char := SubStr(text, pos, 1)
    if (char = "{")
        return Jxon_ParseObject(text, &pos)
    if (char = "[")
        return Jxon_ParseArray(text, &pos)
    if (char = Chr(34))
        return Jxon_ParseString(text, &pos)
    if (SubStr(text, pos, 4) = "null") {
        pos += 4
        return ""
    }
    if (SubStr(text, pos, 4) = "true") {
        pos += 4
        return true
    }
    if (SubStr(text, pos, 5) = "false") {
        pos += 5
        return false
    }
    return Jxon_ParseNumber(text, &pos)
}

Jxon_ParseObject(text, &pos) {
    obj := Map()
    pos += 1
    Jxon_SkipWhitespace(text, &pos)
    if (SubStr(text, pos, 1) = "}") {
        pos += 1
        return obj
    }

    while true {
        key := Jxon_ParseString(text, &pos)
        Jxon_SkipWhitespace(text, &pos)
        if (SubStr(text, pos, 1) != ":")
            throw Error("Expected ':'")
        pos += 1
        value := Jxon_ParseValue(text, &pos)
        obj[key] := value
        Jxon_SkipWhitespace(text, &pos)
        char := SubStr(text, pos, 1)
        if (char = "}") {
            pos += 1
            break
        }
        if (char != ",")
            throw Error("Expected ',' or '}'")
        pos += 1
    }
    return obj
}

Jxon_ParseArray(text, &pos) {
    arr := []
    pos += 1
    Jxon_SkipWhitespace(text, &pos)
    if (SubStr(text, pos, 1) = "]") {
        pos += 1
        return arr
    }

    while true {
        value := Jxon_ParseValue(text, &pos)
        arr.Push(value)
        Jxon_SkipWhitespace(text, &pos)
        char := SubStr(text, pos, 1)
        if (char = "]") {
            pos += 1
            break
        }
        if (char != ",")
            throw Error("Expected ',' or ']'")
        pos += 1
    }
    return arr
}

Jxon_ParseString(text, &pos) {
    quote := Chr(34)
    backslash := Chr(92)
    pos += 1
    start := pos
    result := ""

    while true {
        if (pos > StrLen(text))
            throw Error("Unexpected end of string")

        char := SubStr(text, pos, 1)
        if (char = quote) {
            result .= SubStr(text, start, pos - start)
            pos += 1
            break
        }

        if (char = backslash) {
            result .= SubStr(text, start, pos - start)
            pos += 1
            if (pos > StrLen(text))
                throw Error("Unexpected end of string")

            escapeChar := SubStr(text, pos, 1)
            if (escapeChar = quote)
                result .= quote
            else if (escapeChar = backslash)
                result .= backslash
            else if (escapeChar = "n")
                result .= "`n"
            else if (escapeChar = "r")
                result .= "`r"
            else if (escapeChar = "t")
                result .= "`t"
            pos += 1
            start := pos
        } else {
            pos += 1
        }
    }
    return result
}

Jxon_ParseNumber(text, &pos) {
    start := pos
    while (pos <= StrLen(text) && InStr("0123456789+-.eE", SubStr(text, pos, 1)))
        pos += 1
    number := SubStr(text, start, pos - start)
    if (InStr(number, ".") || InStr(number, "e") || InStr(number, "E"))
        return number + 0.0
    return Integer(number)
}

Jxon_SkipWhitespace(text, &pos) {
    while (pos <= StrLen(text) && InStr(" `t`r`n", SubStr(text, pos, 1)))
        pos += 1
}

JsonEscape(text) {
    result := ""
    backslash := Chr(92)
    Loop Parse text {
        char := A_LoopField
        code := Ord(char)
        if (code = 9)
            result .= backslash . "t"
        else if (code = 10)
            result .= backslash . "n"
        else if (code = 13)
            result .= backslash . "r"
        else if (code = 34)
            result .= backslash . Chr(34)
        else if (code = 92)
            result .= backslash . backslash
        else
            result .= char
    }
    return result
}

StrJoin(array, sep) {
    result := ""
    for index, element in array {
        result .= (index = 1 ? "" : sep) . element
    }
    return result
}
