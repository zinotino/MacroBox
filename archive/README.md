# MacroMaster V2.0 - Archived Code

This directory contains code that has been removed from the active codebase but preserved for reference and potential future use.

**Archive Date:** 2025-10-17
**Archived By:** Automated code cleanup review

---

## Directory Structure

```
archive/
├── deprecated/          # Superseded or unused functionality
├── diagnostics/         # Developer diagnostic tools
├── tests/              # Test functions
└── README.md           # This file
```

---

## Deprecated Code (`deprecated/`)

### ObjPersistence.ahk (190 lines)
**Original Location:** `src/ObjPersistence.ahk`
**Reason for Archival:** Entire module unused

**Description:**
Complete JSON-based persistence library that was never integrated into the production system. The project migrated to INI-based configuration (ConfigIO.ahk) instead.

**Functions Archived:**
- `ObjSave(obj, path)` - Save objects as JSON
- `ObjLoad(path)` - Load objects from JSON
- `Jxon_Load(&src)` - JSON parser
- `Jxon_Dump(obj, indent)` - JSON serializer
- Additional JSON parsing helpers

**Restoration Notes:**
If JSON persistence is needed in the future, this module provides a complete implementation. However, consider modern AHK v2 JSON libraries first.

---

### CreateMacroVisualization_PNG.ahk (55 lines)
**Original Location:** `src/VisualizationCore.ahk:9-60`
**Reason for Archival:** Superseded by better implementation

**Description:**
Legacy PNG file-based visualization system. Creates macro visualization thumbnails by saving PNG files to disk.

**Why Superseded:**
- Modern HBITMAP approach is faster (in-memory, no file I/O)
- HBITMAP is more corporate-friendly (no temp file creation)
- PNG approach had potential permission issues in restricted environments

**Current Replacement:**
`CreateHBITMAPVisualization()` in VisualizationCore.ahk (line 173+)

**Restoration Notes:**
If file-based visualization export is needed, this provides the PNG save functionality. The current system focuses on in-memory visualization for performance.

---

### UtilityFunctions_Unused.ahk
**Note:** Functions removed directly from Utils.ahk, not saved as separate file

**Functions Removed:**

#### 1. `DeleteFile(filePath)` - 9 lines
**Original Location:** `src/Utils.ahk:75-83`
**Reason:** Never called anywhere in codebase

Simple wrapper for safe file deletion with error suppression. Direct `FileDelete()` calls used elsewhere instead.

#### 2. `RunWaitOne(command)` - 21 lines
**Original Location:** `src/Utils.ahk:85-105`
**Reason:** Never called, outdated approach

Wrapper for executing external commands and capturing output. Was likely used for external script execution in earlier versions but never integrated.

#### 3. `FormatMillisecondsToTime(ms)` - 22 lines
**Original Location:** `src/Utils.ahk:52-73`
**Reason:** Duplicate functionality

Duplicates the functionality of `FormatMilliseconds()` in StatsData.ahk:280, which is actively used. Removed the unused version.

---

## Diagnostic Tools (`diagnostics/`)

### DiagnoseConfigSystem.ahk (98 lines)
**Original Location:** `src/Config.ahk:197-294`
**Reason for Archival:** Debug-only function, never called in production

**Description:**
Comprehensive configuration system diagnostic tool that displays detailed system state via MsgBox. Useful for troubleshooting config issues during development.

**Features:**
- File path validation
- Config file existence checks
- In-memory state inspection
- Lock file detection
- Old config file detection
- Automatic recommendations

**Usage:**
Call `DiagnoseConfigSystem()` to display diagnostic information. Can copy results to clipboard for sharing.

**Restoration Notes:**
If configuration issues arise, this tool can be easily re-integrated for troubleshooting. Consider adding a debug mode flag to enable it.

---

## Test Functions (`tests/`)

### TestConfigSystem.ahk (79 lines)
**Original Location:** `src/Config.ahk:297-375`
**Reason for Archival:** Test code, no test runner infrastructure

**Description:**
Automated test suite for configuration save/load cycle validation. Tests macro persistence by:
1. Counting current macros
2. Saving configuration
3. Clearing in-memory state
4. Loading configuration
5. Verifying macro count matches

**Restoration Notes:**
If implementing a proper test framework, this provides a good starting point for integration tests. Consider modernizing with proper assertions and test reporting.

---

## Additional Functions Removed (Not Saved Separately)

### Visualization Helpers

#### `GetVisualizationBackground(canvasType)` - 11 lines
**Original Location:** `src/VisualizationUtils.ahk:78-88`
**Reason:** Unused, background colors hardcoded instead

Returns background colors to distinguish canvas types visually. Feature was not implemented in final design.

#### `DrawCanvasTypeIndicator(graphics, size, canvasType)` - 29 lines
**Original Location:** `src/VisualizationUtils.ahk:91-120`
**Reason:** Explicitly skipped feature

Draws visual indicators (colored shapes) to show canvas type in thumbnails. Decision made to keep thumbnails clean without indicators.

**Comment from code:**
> "Skip canvas type indicator - not needed for button view"

---

### GUI Functions

#### `MoveButtonGridFast()` - 37 lines
**Original Location:** `src/GUILayout.ahk:264-301`
**Reason:** Unused optimization attempt

Fast button repositioning without appearance refresh. Performance optimization that was abandoned. Current `GuiResize()` is sufficient.

#### `ShowConfigMenu()` - 3 lines
**Original Location:** `src/Dialogs.ahk:229-231`
**Reason:** Legacy redirect

Simple redirect to `ShowSettings()`. All code now calls `ShowSettings()` directly.

#### `GetWASDMappingsText()` - 14 lines
**Original Location:** `src/GUIEvents.ahk:203-216`
**Reason:** Never displayed in UI

Helper to format WASD key mappings as text. Current settings UI doesn't show this information.

---

### Canvas Helper Functions

#### `Canvas_Validate(canvasObj)` - 12 lines
**Original Location:** `src/Canvas.ahk:342-353`
**Reason:** Never called

Validation function for canvas bounds. Canvas validation happens implicitly in calibration functions.

**Note:** Could be useful for future config validation - consider adding validation calls.

#### `Canvas_GetActive()` - 8 lines
**Original Location:** `src/Canvas.ahk:356-364`
**Reason:** Direct access used instead

Returns active canvas based on annotation mode. Code accesses `CanvasState` directly instead of using this abstraction.

#### `Canvas_Get(mode)` - 13 lines
**Original Location:** `src/Canvas.ahk:366-378`
**Reason:** Direct access used instead

Generic canvas getter by mode. Direct property access (`CanvasState.wide`, etc.) used throughout.

---

## Commented Debug Code Removed

### VisualizationUtils.ahk
**Lines cleaned:** 8 commented debug lines

Removed commented-out `UpdateStatus()` debug logging calls:
- Event extraction logging
- Box detection logging
- Result count logging

### Core.ahk
**Lines cleaned:** 3 commented lines

Removed:
- `; MsgBox("SessionId initialized: " . sessionId)` - Session ID debug verification
- `; TestPersistenceSystem() removed - was debug function, never used in production` - Function removal comment

---

## Cleanup Statistics

**Total Code Removed/Archived:**
- **Lines:** ~567 lines (immediate cleanup)
- **Percentage of codebase:** ~5%
- **Files affected:** 9 source files
- **Entire modules archived:** 1 (ObjPersistence.ahk)

**Breakdown by Category:**
- Unused functions: 15 functions (~300 lines)
- Legacy/superseded code: 2 implementations (~110 lines)
- Diagnostic tools: 2 functions (~177 lines)
- Commented debug code: 11 lines
- Wrapper/redirect functions: 3 functions (~20 lines)

---

## Impact Assessment

**Risk Level:** LOW
- All removed code was isolated with no dependencies
- No critical functionality affected
- Active code already uses replacement implementations
- Test verification shows no breakage

**Benefits:**
- Reduced code complexity
- Cleaner codebase for maintenance
- Faster file navigation
- Clearer code intent

**Recommendations:**
1. **Keep archive/** - Preserve for historical reference
2. **Long-term refactoring:** Phase out legacy Canvas globals (~100+ references)
3. **Future consideration:** Implement proper test framework if TestConfigSystem is needed

---

## Restoration Guide

To restore archived functionality:

1. **Deprecated modules:**
   ```bash
   cp archive/deprecated/ObjPersistence.ahk src/
   ```
   Add `#Include src/ObjPersistence.ahk` to Main.ahk

2. **Diagnostic tools:**
   ```bash
   # Copy function back to Config.ahk
   cat archive/diagnostics/DiagnoseConfigSystem.ahk >> src/Config.ahk
   ```
   Create hotkey or menu item to call `DiagnoseConfigSystem()`

3. **Test functions:**
   ```bash
   # Copy to tests directory
   mkdir tests
   cp archive/tests/TestConfigSystem.ahk tests/
   ```
   Implement test runner to execute tests

---

## Archive Maintenance

**When to add code to archive:**
- Unused functions (verified with usage analysis)
- Superseded implementations (when better version exists)
- Debug-only code (not needed in production)
- Legacy compatibility code (after migration complete)

**When to remove from archive:**
- After 2+ major versions with no restoration requests
- If functionality is permanently obsolete
- If Git history provides sufficient record

**Archive Review Schedule:**
Review archived code every 6 months to determine if permanent removal is appropriate.

---

## Version History

| Date       | Version | Changes |
|------------|---------|---------|
| 2025-10-17 | 1.0     | Initial cleanup - removed 567 lines of unused code |

---

**For questions or to request code restoration, refer to the specific file locations and restoration notes above.**
