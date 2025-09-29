#Requires AutoHotkey v2.0
#SingleInstance Force
SendMode "Input"
Persistent

/*
==============================================================================
MACROMASTER - Modular macro recording and playback system
==============================================================================
Refactored for maintainability with clear separation of concerns
*/

; Include all modules
#Include "Core.ahk"
#Include "Utils.ahk"
#Include "Config.ahk"
#Include "GUI.ahk"
#Include "Stats.ahk"
#Include "Macros.ahk"
#Include "Hotkeys.ahk"
#Include "Visualization.ahk"

; ===== MAIN ENTRY POINT =====
Main()