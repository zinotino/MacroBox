# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**MacroMaster V5** is a comprehensive AutoHotkey v2.0 macro recording and playback system designed for offline data labeling workflows. The main script file is `MacroLauncherX45.txt` (~4,800 lines), which implements a complete GUI-based macro management system with advanced features including:

- Multi-layer macro organization (5 layers with 12 buttons each)
- Real-time bounding box visualization with degradation tracking
- CSV-based statistics system for usage analytics
- Break mode functionality for time management
- Dual canvas support (wide/narrow aspect ratios)
- JSON annotation integration
- Thumbnail support and offline data management

## Core Architecture

### Main Components

**Global State Management:**
- Recording/playback states: `recording`, `playback`, `awaitingAssignment`
- Layer system: `currentLayer` (1-5), button grid mapping via `macroEvents` Map
- Canvas system: `canvasType` ("wide"/"narrow"), dual aspect ratio support
- Time tracking: `applicationStartTime`, `totalActiveTime`, `breakMode`
- Degradation system: 9 types (smudge, glare, splashes, etc.) with color coding

**Key Functions:**
- `ExecuteMacro(buttonName)` - Main macro execution at line ~934
- `ShowStats()` - Comprehensive analytics display at line ~1862  
- `SafeExecuteMacroByKey(buttonName)` - Protected execution wrapper at line ~923
- Macro recording system starting around line ~983
- GUI management functions around line ~1272

**Data Storage:**
- Macros stored in `macroEvents` Map with layer-specific keys (e.g., "L1_Num7")
- CSV statistics in `data/master_stats.csv` (when implemented)
- Configuration in `config.ini`
- Thumbnails in `thumbnails/` directory

### File System Structure

```
/
├── MacroLauncherX45.txt    # Main 4,800-line AutoHotkey script
├── claude_code_exact_steps.md  # Detailed implementation plan for CSV stats
├── data/                   # CSV data storage (created at runtime)
├── thumbnails/            # Button thumbnail storage (created at runtime)
└── config.ini             # Configuration file (created at runtime)
```

## Development Commands

**Running the Application:**
```bash
# Execute with AutoHotkey v2.0 runtime
"C:\Program Files\AutoHotkey\v2\AutoHotkey.exe" MacroLauncherX45.txt
```

**Testing:**
```bash
# No automated test suite - manual testing via GUI
# Use F9 for macro recording, numpad keys for playback
# Test break mode with Ctrl+B (when implemented)
```

**Validation:**
```bash
# Check AutoHotkey syntax
"C:\Program Files\AutoHotkey\v2\AutoHotkey.exe" /ErrorStdOut MacroLauncherX45.txt
```

## Key Implementation Details

### CSV Stats System Integration

The `claude_code_exact_steps.md` file contains a detailed 11-step implementation plan for integrating CSV-based statistics tracking. Key integration points:

**Critical Functions to Modify:**
- `ExecuteMacro()` at line ~934 - Add execution tracking
- `ShowStats()` at line ~1862 - Replace data source with CSV reading
- Add new functions: `InitializeCSVFile()`, `AppendToCSV()`, `ReadStatsFromCSV()`

**CSV Schema:**
```
timestamp,session_id,username,execution_type,button_key,layer,execution_time_ms,bbox_count,degradation_assignments,severity_level,canvas_mode,session_active_time_ms,break_mode_active
```

### Safety and Version Control

**Git Integration:**
```bash
git init
git add .
git commit -m "BASELINE: 4565-line working system before modifications"
git tag v1.0-working-baseline
```

**Emergency Recovery:**
```bash
# Restore from backup
git reset --hard v1.0-working-baseline
# Or manual backup
copy MacroLauncherX45.txt MacroLauncherX45_BACKUP.txt
```

### Layer System Architecture

- 5 layers with specific purposes: Base, Advanced, Tools, Custom, AUTO
- Button mapping: 12 numpad keys (Num0-Num9, NumDot, NumMult) 
- Storage key format: "L{layer}_{buttonName}" (e.g., "L1_Num7")
- Layer switching via UI controls and hotkeys

### Degradation Tracking System

9 degradation types mapped to number keys 1-9:
- 1=smudge, 2=glare, 3=splashes, 4=partial_blockage, 5=full_blockage
- 6=light_flare, 7=rain, 8=haze, 9=snow
- Color-coded visualization with hex color mapping
- Assignment during macro recording via keypresses

## Development Guidelines

**Code Modification Safety:**
- Always test compilation after changes: script must load without errors
- Preserve existing hotkey system (F9 for recording, numpad for execution)
- Maintain backward compatibility with existing macro storage format
- Test core workflow: Record → Assign → Playback → Verify

**Variable Naming Conventions:**
- Global variables prefixed with `global`
- UI elements: descriptive names (e.g., `mainGui`, `statusBar`)
- System state: boolean flags (e.g., `recording`, `playback`, `breakMode`)
- Data structures: Maps for button/macro storage

**Error Handling:**
- File operations should include error checking
- GUI operations wrapped in try/catch where appropriate
- Status updates via `UpdateStatus()` function for user feedback

## Testing Protocol

**Manual Testing Sequence:**
1. Launch application - verify GUI loads correctly
2. Record macro with F9 - test bounding box drawing
3. Assign degradations with keys 1-9 during recording
4. Execute via numpad - verify playback accuracy
5. Test layer switching - verify macro isolation
6. Test break mode toggle - verify tracking pause
7. Check stats display - verify data accuracy
8. Restart application - verify data persistence