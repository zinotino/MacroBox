# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**MacroMaster V555** is a comprehensive AutoHotkey v2.0 macro recording and playback system designed for offline data labeling workflows. The system uses a modular architecture with multiple visualization layers and a high-performance SQLite backend for analytics.

**Key Features:**
- Multi-layer macro organization (5 layers with 12 buttons each = 60 macro slots)
- Three-tier visualization system (HBITMAP/PNG/Plotly)
- SQLite-based statistics with real-time dashboard generation
- Break mode functionality for time management
- Dual canvas support (wide/narrow aspect ratios)
- JSON annotation integration
- Per-box degradation tracking (9 types)

**Architecture:**
- **Modular AHK**: 10 separate .ahk modules in `src/`
- **Visualization**: HBITMAP (memory) primary, PNG fallback, Plotly dashboard
- **Stats Backend**: SQLite with Python analytics layer
- **Storage**: Dual-write (CSV backup + database inserts)

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

## Visualization Systems

MacroMaster uses **three distinct visualization systems** working in parallel:

### 1. HBITMAP System (Primary) - `src/GUI.ahk`

**Purpose:** Memory-only button thumbnails

**Key Functions:**
- `CreateHBITMAPVisualization(macroEvents, buttonSize)` - Lines 205-302
- `TestHBITMAPSupport()` - Lines 175-203

**Process:**
```
GDI+ Bitmap → HBITMAP Handle → Cache in hbitmapCache Map → picture.Value = "HBITMAP:*{handle}"
```

**Performance:** <1ms cached, ~5-10ms initial creation

**Advantages:** Zero file I/O, instant display, memory-efficient caching

### 2. PNG File System (Fallback) - `src/Visualization.ahk`

**Purpose:** File-based thumbnails when HBITMAP fails

**Key Functions:**
- `CreateMacroVisualization(macroEvents, buttonDims)` - Lines 5-56
- `SaveVisualizationPNG(bitmap, filePath)` - Lines 546-593
- `DrawMacroBoxesOnButton(graphics, width, height, boxes, events)` - Drawing logic

**Process:**
```
GDI+ Bitmap → Save PNG to disk → Return file path → picture.Value = "{path}"
```

**Fallback Paths:** A_Temp, A_ScriptDir, A_MyDocuments, UserProfile, Desktop

**Performance:** ~15-30ms generation, 5-50 KB file size

### 3. Plotly Dashboard (Stats) - `stats/generate_dashboard.py`

**Purpose:** Interactive analytics with charts

**Key Functions:**
- `generate_dashboard(filter_mode, output_path, db_path)` - Main generator
- `query_degradation_totals()`, `query_boxes_over_time()`, etc. - Data queries
- `create_degradation_bar_chart()`, `create_pie_chart()`, etc. - Chart builders

**Process:**
```
SQLite Query → Plotly Chart Objects → HTML Template → Single HTML File → Browser
```

**Performance:** ~2-3 seconds total, <10ms queries, 50-500 KB output

**Charts Generated:**
- 3 degradation analysis charts (bar, bar, pie)
- 3 time/efficiency line charts
- 5 detailed statistical tables

**Triggered by:** Stats button click → `LaunchDashboard()` in `src/Stats.ahk`

### Degradation Color Consistency

All three systems use identical color mapping:

```ahk
; AHK (HBITMAP/PNG)
degradationColors := Map(
    1, 0xFFFF4500,  ; Smudge
    2, 0xFFFFD700,  ; Glare
    3, 0xFF8A2BE2,  ; Splashes
    4, 0xFF00FF32,  ; Partial Blockage
    5, 0xFF8B0000,  ; Full Blockage
    6, 0xFFFF1493,  ; Light Flare
    7, 0xFFB8860B,  ; Rain
    8, 0xFF556B2F,  ; Haze
    9, 0xFF00FF7F   ; Snow
)
```

```python
# Python (Plotly)
color_map = {
    'smudge': '#FF4500',
    'glare': '#FFD700',
    # ... etc.
}
```

**Complete Documentation:** See [VISUALIZATION_SYSTEMS.md](../VISUALIZATION_SYSTEMS.md) for full technical details.

## Stats System Architecture

### SQLite Backend - `stats/`

**Current System (Recommended):**

**Database Location:** `C:\Users\{user}\Documents\MacroMaster\data\macromaster_stats.db`

**Key Scripts:**
- `generate_dashboard.py` - Plotly dashboard generator
- `record_execution.py` - Real-time database inserts
- `migrate_csv_to_db.py` - CSV to SQLite migration
- `init_database.py` - Database initialization
- `test_database.py` - System verification

**Schema:**
- `executions` table - Main execution records
- `degradations` table - Normalized per-box degradations
- `sessions` table - Session aggregations
- 9 performance indexes for <1ms queries

**Integration Points:**
- `AppendToCSV()` in `src/Stats.ahk` (lines 841-895) - Dual-write to CSV + database
- `LaunchDashboard()` in `src/Stats.ahk` (lines 265-328) - Generate and open dashboard

**Data Flow:**
```
User executes macro → RecordExecutionStats() → AppendToCSV()
→ Write CSV + Create JSON → Python record_execution.py
→ Insert to SQLite → Stats button → generate_dashboard.py
→ Query database → Generate HTML → Open in browser
```

**Complete Documentation:**
- [stats/STATS_SYSTEM_DOCUMENTATION.md](../stats/STATS_SYSTEM_DOCUMENTATION.md) - Full API
- [stats/SYSTEM_ALIGNMENT.md](../stats/SYSTEM_ALIGNMENT.md) - End-to-end flow

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