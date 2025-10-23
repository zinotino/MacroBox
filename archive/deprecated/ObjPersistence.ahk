#Requires AutoHotkey v2.0

; ===== ULTRA-SIMPLE OBJECT PERSISTENCE =====
; Bare minimum JSON save/load - no complex parsing
; Just uses AutoHotkey's native JSON capabilities

ObjSave(obj, path) {
    try {
        ; Use Jxon library if available, otherwise use basic serialization
        json := Jxon_Dump(obj)
        try FileDelete(path)
        FileAppend(json, path, "UTF-8")
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
        if (json = "")
            return Map()
        return Jxon_Load(&json)
    } catch {
        return Map()
    }
}

; ===== MINIMAL JXON IMPLEMENTATION =====
; Simplified Jxon library for basic Map/Array/Object serialization

Jxon_Load(&src) {
    key := "", is_key := false
    stack := [tree := []]
    next := '"{[01234567890-tfn'
    pos := 0

    while ((ch := SubStr(src, ++pos, 1)) != "") {
        if InStr(" `t`n`r", ch)
            continue
        if !InStr(next, ch, true) {
            return
        }

        is_array := (SubStr(src, pos, 1) == "[")

        if InStr("{[", ch) {
            val := (ch == "{") ? Map() : Array()
            stack.Push(val)
            next := (ch == "{") ? '"}' : '"]'
        } else if InStr("}]", ch) {
            stack.Pop()
            if (stack.Length == 0)
                return tree[1]
            next := (stack[stack.Length].Type == "Map") ? "}," : "],"
        } else if InStr(",:", ch) {
            is_key := (!is_array && ch == ",") ? false : !is_array
            next := is_key ? '"' : '"{[0123456789-tfn'
        } else {
            ; Parse value
            if (ch == '"') {
                val := Jxon_ParseString(&src, &pos)
            } else if InStr("tfn", ch) {
                val := Jxon_ParseLiteral(&src, &pos)
            } else {
                val := Jxon_ParseNumber(&src, &pos)
            }

            container := stack[stack.Length]
            if (Type(container) == "Map") {
                if (is_key) {
                    key := val
                } else {
                    container[key] := val
                }
            } else {
                container.Push(val)
            }

            next := (Type(container) == "Map") ? (is_key ? ":" : "},") : "],"
        }
    }

    return tree[1]
}

Jxon_ParseString(&src, &pos) {
    startPos := ++pos

    while ((ch := SubStr(src, pos, 1)) != '"' || SubStr(src, pos-1, 1) == "\") {
        pos++
    }

    str := SubStr(src, startPos, pos - startPos)
    str := StrReplace(str, '\"', '"')
    str := StrReplace(str, '\\', '\')
    str := StrReplace(str, '\n', "`n")
    str := StrReplace(str, '\r', "`r")
    str := StrReplace(str, '\t', "`t")

    return str
}

Jxon_ParseNumber(&src, &pos) {
    startPos := pos

    while InStr("0123456789+-.eE", SubStr(src, pos, 1)) {
        pos++
    }

    pos--
    return Number(SubStr(src, startPos, pos - startPos + 1))
}

Jxon_ParseLiteral(&src, &pos) {
    if (SubStr(src, pos, 4) == "true") {
        pos += 3
        return true
    }
    if (SubStr(src, pos, 5) == "false") {
        pos += 4
        return false
    }
    if (SubStr(src, pos, 4) == "null") {
        pos += 3
        return ""
    }
    return ""
}

Jxon_Dump(obj, indent := "") {
    objType := Type(obj)

    if (objType == "String") {
        return '"' . StrReplace(StrReplace(StrReplace(obj, '\', '\\'), '"', '\"'), "`n", '\n') . '"'
    }

    if (objType == "Integer" || objType == "Float") {
        return String(obj)
    }

    if (obj = true || obj = false) {
        return obj ? "true" : "false"
    }

    if (objType == "Map") {
        if (obj.Count == 0)
            return "{}"

        pairs := []
        for key, val in obj {
            pairs.Push('"' . String(key) . '":' . Jxon_Dump(val, indent))
        }
        return "{" . Jxon_Join(pairs, ",") . "}"
    }

    if (objType == "Array") {
        if (obj.Length == 0)
            return "[]"

        items := []
        for item in obj {
            items.Push(Jxon_Dump(item, indent))
        }
        return "[" . Jxon_Join(items, ",") . "]"
    }

    ; Handle generic objects
    if (objType == "Object") {
        pairs := []
        for key, val in obj.OwnProps() {
            pairs.Push('"' . String(key) . '":' . Jxon_Dump(val, indent))
        }
        return "{" . Jxon_Join(pairs, ",") . "}"
    }

    return "null"
}

Jxon_Join(arr, sep) {
    result := ""
    for i, item in arr {
        result .= (i > 1 ? sep : "") . item
    }
    return result
}
