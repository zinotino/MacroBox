CLAUDE.mdThis file provides comprehensive guidance to Claude Code (claude.ai/code) when working with code in this repository. It consolidates all system documentation into a single, condensed reference for development, architecture, and maintenance of MacroMaster.Project OverviewMacroMaster V2.0 is a comprehensive AutoHotkey v2.0 macro recording and playback system designed for offline data labeling workflows. It features a modular architecture with multi-layer visualization, real-time CSV-based analytics, and corporate-safe fallbacks.Key Features:Multi-layer macro organization (5-10 layers, 12 buttons each = 60+ slots)
Three-tier visualization: HBITMAP (primary, in-memory), PNG (fallback, file-based), Plotly (stats dashboards)
Dual canvas support: Wide (16:9) and Narrow (4:3) aspect ratios with automatic detection
Degradation tracking: 9 types (smudge, glare, splashes, partial_blockage, full_blockage, light_flare, rain, haze, snow) with color-coded rendering
Statistics: Real-time tracking via CSV (session/master) and SQLite backend with Python dashboards
Break mode: Pauses time tracking and stats collection
JSON integration: Annotation exports
Corporate compatibility: No network, local storage, multiple fallbacks

Status: Production Ready (Last Updated: 2025-10-08)High-Level ArchitectureMacroMaster uses 20+ modular AHK files with clear separation of concerns. Core components include state management, macro recording/execution, visualization, GUI, and stats.System Diagrammermaid

graph TB
    subgraph "User Interface"
        GUI[Main GUI: Layers, Buttons, Stats]
        CONFIG[Config: Canvas Calibration, Settings]
    end
    subgraph "Core Engine"
        CORE[Core.ahk: State, Init, Config]
        RECORD[MacroRecording.ahk: Event Capture]
        EXECUTE[MacroExecution.ahk: Playback]
    end
    subgraph "Visualization"
        VISUAL[VisualizationCore.ahk: GDI+ Bitmaps]
        CANVAS[VisualizationCanvas.ahk: Scaling]
        UTILS[VisualizationUtils.ahk: Colors/Events]
    end
    subgraph "Data & Analytics"
        STATS[Stats.ahk: CSV/SQLite Tracking]
        DATA[(CSV/SQLite: session/master_stats)]
    end
    subgraph "Supporting"
        HOTKEYS[Hotkeys.ahk: Inputs]
        DIALOGS[Dialogs.ahk: Modals]
        CONTROLS[GUIControls.ahk: Events]
    end

    GUI --> CORE --> RECORD --> STATS --> DATA
    GUI --> CORE --> EXECUTE --> STATS --> DATA
    CORE --> VISUAL --> CANVAS --> UTILS
    HOTKEYS --> CORE
    DIALOGS --> GUI
    CONTROLS --> GUI

Module DependenciesCore: Config.ahk, Visualization.ahk, Stats.ahk, GUI.ahk
Visualization: Core.ahk (HBITMAP/PNG), Canvas.ahk (scaling), Utils.ahk (events)
Stats: CSV/SQLite writes, Python scripts (generate_dashboard.py, record_execution.py)
Runtime: GDI+ library (no external deps beyond AHK v2.0)

Data FlowRecording: F9 toggle → Capture mouse/keyboard → Assign degradations (1-9 keys) → Generate thumbnail → Save to macroEvents Map → Write stats to CSV/SQLite
Playback: Numpad key → Execute events with delays → Record stats
Stats Display: Click Stats → Read CSV/SQLite → Generate Plotly HTML → Open in browser

Core System DetailsGlobal State VariablesExecution: recording (bool), playback (bool), awaitingAssignment (bool), lastExecutionTime (timestamp)
Config: currentLayer (1-5+), canvasType (wide/narrow/custom), darkMode (bool)
Resources: hbitmapCache (Map), mouseHook/keyboardHook, mainGui/statusBar
Stats: sessionId (string), totalActiveTime (ms), breakMode (bool), statsQueue (array)

Initialization Pipeline (Main())Directories: Create Documents\MacroMaster\data & thumbnails (fallbacks: ScriptDir, UserProfile, Desktop)
Variables: Set defaults (hotkeys, timings, canvas dims)
Canvas: Set wide (1920x1080), narrow (1440x1080 centered)
Stats: Init CSV (session/master_stats.csv), SQLite (macromaster_stats.db)
Visualization: GDI+ startup, test HBITMAP support
GUI/Hotkeys: Load config, apply settings, setup timers (autosave, health checks)

Macro ManagementStorage: macroEvents Map (key: "L{layer}_{buttonName}", value: event array)
Functions: ExecuteMacro(buttonName), SafeExecuteMacroByKey, CountLoadedMacros
Cache: hbitmapCache for thumbnails; clear with CleanupHBITMAPCache() or per-macro

Time Tracking & Break ModeTrack active time (exclude breaks); toggle with Ctrl+B
UpdateActiveTime(): Accumulate ms if !breakMode
Session: ID as "sess_yyyyMMdd_HHmmss", reset on startup

ConfigurationFile: config.ini (sections: Settings, Macros, Canvas, Hotkeys)
Functions: LoadConfig() (restore globals/GUI), SaveConfig() (persist), ValidateConfigIntegrity() (timer-based checks)
Autosave: Every 30s if !recording && !breakMode

Error Handling & RecoveryEmergencyStop(): Halt activity, release hooks, reset states
ForceStateReset(): Clear bool flags, stop timers
MonitorExecutionState(): Detect stuck states (>30s playback, >5min recording)
Fallbacks: Silent degradation, no dialogs

PerformanceMetrics: HBITMAP <1ms cached, PNG 15-30ms, stats display <100ms
Memory: HBITMAP cache 40%, GUI 25%; cleanup every 50 executions
Scalability: 1000+ macros, efficient CSV/SQLite for long sessions

Visualization System DetailsMulti-Tier SystemHBITMAP (Primary): In-memory for GUI; CreateHBITMAPVisualization() → GDI+ bitmap → HBITMAP handle → Cache
PNG (Fallback): File-based; CreateMacroVisualization() → Save to thumbnails/ (fallbacks for corporate paths)
Plotly (Stats): Python-generated HTML dashboards from SQLite

Canvas Detection & ScalingDetect: Compute aspect ratio from boxes; prefer user mode, fit bounds, coverage >65%
Scaling: Wide → stretch fill; Narrow → letterbox to 4:3
Functions: DetectCanvasType(), DrawMacroBoxesOnButton() (sub-pixel, min size 2.5px)

Box RenderingExtractBoxEvents(): Parse events, assign degradations from keypresses
Render: GDI+ with anti-aliasing; fill rects with color from degradationColors Map

Degradation Colors (Consistent Across Systems)autohotkey

degradationColors := Map(1, 0xFF4500, 2, 0xFFD700, 3, 0x8A2BE2, 4, 0x00FF32, 5, 0x8B0000, 6, 0xFF1493, 7, 0xB8860B, 8, 0x556B2F, 9, 0x00FF7F)

Stats System ArchitectureBackendCSV: session_stats.csv (resets on startup), master_stats.csv (permanent)
Schema: timestamp,session_id,button_key,layer,execution_time_ms,total_boxes,smudge,...snow
SQLite: macromaster_stats.db (tables: executions, degradations, sessions); Python scripts for init/migrate/record/query
Integration: AppendToCSV() dual-writes CSV + JSON → record_execution.py inserts to DB

DisplayShowStats(): Read CSV/SQLite → Calculate today/all-time → Horizontal GUI or Plotly dashboard
Charts: Degradation bars/pies, time/efficiency lines, stats tables
Launch: Stats.ahk → generate_dashboard.py → HTML → Browser

Development GuidelinesFile Structure

src/                        # AHK modules (Core.ahk, Macro*.ahk, Visualization*.ahk, GUI*.ahk, Stats.ahk, etc.)
docs/                       # ARCHITECTURE.md, CORE_SYSTEM.md, VISUALIZATION_SYSTEM.md, STATS_SYSTEM.md
data/                       # session/master_stats.csv, macromaster_stats.db, config.ini
thumbnails/                 # PNG visuals
stats/                      # Python: generate_dashboard.py, record_execution.py, init_database.py
tests/                      # test_*.ahk

CommandsRun: AutoHotkey.exe MacroLauncherX45.txt (or main script)
Syntax Check: AutoHotkey.exe /ErrorStdOut script.ahk
Git Baseline: git init; git add .; git commit -m "Baseline"; git tag v1.0
Recovery: git reset --hard v1.0; or copy backup

Modification SafetyTest compilation post-changes
Preserve hotkeys (F9 record, Numpad execute, Ctrl+B break, RCtrl emergency)
Maintain macro format in config.ini
Core mods: ExecuteMacro(L934), ShowStats(L1862)
Add stats: InitializeCSVFile(), AppendToCSV(), ReadStatsFromCSV()
Naming: Global prefix, descriptive UI vars, bool flags for states

Testing ProtocolLaunch GUI
Record (F9): Draw boxes, assign 1-9
Playback (Numpad): Verify accuracy
Layer switch: Isolate macros
Break toggle: Check time pause
Stats: Verify data
Restart: Check persistence

Future EnhancementsPhase 3: Enhanced analytics, exports, filtering
Phase 4: Multi-user, network sync, ML features

Quick ReferenceHotkeys: F9 (record), Ctrl+B (break), Numpad0-9 (execute), Shift+Enter (submit), RCtrl (emergency)
Files: config.ini (settings), session/master_stats.csv (data), thumbnails/ (PNGs)
Degradations: 1=smudge (#FF4500), ..., 9=snow (#00FF7F)
Troubleshooting: Check GDI+ init, canvas calibration, cache size; use UpdateStatus() for debug; EmergencyStop() for recovery

Maintained By: MacroMaster Team
Last Review: 2025-10-08
Next Review: 2025-11-08

