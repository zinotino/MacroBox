# MacroMaster Project Structure

## Core Application Files
```
src/
├── Main.ahk                    # Application entry point
├── Core.ahk                    # Core functions and global variables
├── Config.ahk                  # Configuration processing
├── ConfigIO.ahk                # Configuration file I/O
├── Hotkeys.ahk                 # Hotkey definitions
├── Macros.ahk                  # Legacy macro compatibility
├── MacroExecution.ahk          # Macro playback and execution
├── MacroRecording.ahk          # Macro recording system
├── Stats.ahk                   # Statistics and analytics
├── Utils.ahk                   # Utility functions
├── Canvas.ahk                  # Canvas calibration (legacy)
├── Dialogs.ahk                 # Dialog windows
├── GUI.ahk                     # Legacy GUI (compatibility)
├── GUILayout.ahk               # GUI layout management
├── GUIControls.ahk             # GUI control creation
├── GUIEvents.ahk               # GUI event handlers
├── Visualization.ahk           # Legacy visualization (compatibility)
├── VisualizationCore.ahk       # Core visualization engine
├── VisualizationCanvas.ahk     # Canvas rendering
└── VisualizationUtils.ahk      # Visualization utilities
```

## Data Storage (Runtime)
```
~/Documents/MacroMaster/
├── data/
│   ├── config.ini                      # User configuration
│   ├── master_stats.csv                # Display stats (resettable)
│   ├── master_stats_permanent.csv      # Permanent archive (NEVER reset)
│   └── backup_*/                       # Automatic backups
└── thumbnails/                         # Button thumbnail cache
```

## Development Files
```
.claude/                        # Claude Code configuration
├── knowledge/
│   └── visualization_system.md # System documentation
└── settings.local.json         # Local settings

docs/
└── CLAUDE.md                   # Development notes

tests/                          # Test files
├── test_*.ahk                  # Various test scripts
└── test_log.txt               # Test output

archive/                        # Archived files
├── parent/                     # Original monolithic file
└── stats_docs/                 # Old stats documentation
```

## Analytics & Dashboard (Optional)
```
analytics/                      # Analytics tools
dashboard/                      # Python-based dashboards
stats/                          # Database integration scripts
```

## Key Features
- **Permanent Stats**: `master_stats_permanent.csv` never gets deleted
- **Live Stats Display**: 500ms refresh with horizontal layout
- **Separate Tracking**: Macro (box counts) vs JSON (selections)
- **Category Mapping**: category_id → degradation names
- **Automatic Backups**: Data preserved before resets
