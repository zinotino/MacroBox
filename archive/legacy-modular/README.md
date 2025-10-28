# Legacy Modular Architecture Files

**Date Archived:** 2025-10-28
**Reason:** Replaced by monolithic embedded implementation

## What Are These Files?

These are the **original modular architecture** files from an earlier version of the Data Labeling Assistant. The system was originally designed as separate modules that would be included via `#Include` statements.

## Why Were They Replaced?

**Problem with modular approach:**
- Path issues when transferring between machines
- Include failures causing startup errors
- Module synchronization complexity
- Multiple files to manage during deployment

**Solution: Monolithic embedded approach**
All functionality from these modules was embedded directly into `MacroLauncherIntegrated.ahk` as a single standalone file.

## Current Architecture

**Active File:** `mono/MacroLauncherIntegrated.ahk` (6,669 lines)
- All ObjPersistence code: Lines 15-260
- All Stats system: Lines 2118-2950
- All StatsGui: Lines 2950-3700
- All Visualization: Lines 995-2116
- All other functionality: Embedded

**Dependencies:** ZERO external includes

## File Mapping

These legacy modular files correspond to these sections in the main file:

| Legacy Module | Embedded Location |
|--------------|-------------------|
| ObjPersistence.ahk | Lines 15-260 |
| StatsData.ahk | Lines 2118-2xxx |
| StatsGui.ahk | Lines 2950-3700 |
| VisualizationCanvas.ahk | Lines 1148-1672 |
| VisualizationCore.ahk | Lines 995-1672 |
| Canvas.ahk | Embedded in viz system |
| Hotkeys.ahk | Embedded throughout |
| MacroRecording.ahk | Lines 3200-3700 |
| MacroExecution.ahk | Lines 1850-2100 |
| GUILayout.ahk | Lines 5400-6400 |
| Dialogs.ahk | Lines 4200-5000 |
| Config.ahk | Lines 320-670 |
| ConfigIO.ahk | Lines 450-650 |
| Core.ahk | Global variables section |
| Main.ahk | Entry point (bottom of file) |
| Stats.ahk | Lines 2533-2687 |
| Utils.ahk | Utility functions throughout |
| Macros.ahk | Macro management functions |
| GUIControls.ahk | Button creation functions |
| GUIEvents.ahk | Event handlers |
| Visualization.ahk | Wrapper (embedded) |
| VisualizationUtils.ahk | Helper functions |

## Are These Files Still Used?

**NO.** The main file does NOT include any of these modules. They are preserved here for:
1. Historical reference
2. Understanding the evolution of the codebase
3. Potential future refactoring research
4. Code archaeology if needed

## Can I Delete These?

**Yes, safely.** They are not used by the current system. However, they are kept in the archive for reference purposes.

## Should the System Be Modularized Again?

**Current recommendation: NO**

The monolithic approach has proven successful:
- ✅ Single file deployment
- ✅ No path issues
- ✅ Easy cross-machine transfer
- ✅ No include failures
- ✅ Simplified maintenance

**Trade-offs accepted:**
- ⚠️ Large file size (6,669 lines)
- ⚠️ Harder to navigate
- ⚠️ All-or-nothing loading

**When to consider re-modularization:**
- If file exceeds 10,000 lines
- If multiple developers need to work on different subsystems
- If you want to reuse individual modules in other projects

## Version History

**v1.0 - Modular Architecture (2024-2025)**
- Separate module files
- Include-based dependencies
- Cleaner separation of concerns

**v2.0 - Monolithic Architecture (2025-10-27 onwards)**
- Single embedded file
- No external dependencies
- Production-ready stability
- Current version ✅

---

**For questions about the current system architecture, see:** `mono/Issues.md`
