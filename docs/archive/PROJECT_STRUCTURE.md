# MacroMaster Z8W - Project Structure

**Version:** 2.0
**Last Updated:** 2025-10-09
**Status:** Production Ready

---

## 📁 Directory Structure

```
MacroMasterZ8W/
│
├── README.md                      # Main project documentation
├── DISTRIBUTION_CHECKLIST.md      # Release checklist for V555
├── PROJECT_STRUCTURE.md           # This file
│
├── src/                           # 🔧 Source Code (AutoHotkey v2.0)
│   ├── Main.ahk                   # Application entry point
│   ├── Core.ahk                   # System foundation & state management
│   ├── MacroRecording.ahk         # Event capture & degradation assignment
│   ├── MacroExecution.ahk         # Playback engine & timing control
│   ├── Visualization*.ahk         # Graphics pipeline (HBITMAP/PNG)
│   ├── Stats*.ahk                 # CSV statistics tracking & GUI display
│   ├── GUI*.ahk                   # User interface components
│   ├── Hotkeys.ahk                # Input handling & WASD system
│   ├── Canvas.ahk                 # Canvas calibration & detection
│   └── Config*.ahk                # Configuration management
│
├── docs/                          # 📚 Documentation
│   ├── user-guide/                # User-facing documentation
│   │   ├── USAGE_GUIDE.md         # Complete user manual
│   │   └── SIMPLE_STATS_SYSTEM.md # Statistics system guide
│   │
│   ├── developer-guide/           # Developer documentation
│   │   ├── ARCHITECTURE.md        # System design & data flow
│   │   ├── VISUALIZATION_SYSTEM.md# Graphics pipeline details
│   │   ├── CORE_SYSTEM.md         # Core functionality details
│   │   └── CLAUDE.md              # AI development guidelines
│   │
│   └── archive/                   # Historical development docs
│       ├── PHASE_2_PLAN.md        # Phase 2 implementation plan
│       ├── POLISH_CHANGES*.md     # Polishing phase documentation
│       ├── SYSTEM_ANALYSIS*.md    # Legacy system analysis
│       ├── dev/                   # Development snapshots
│       └── history/               # Historical code versions
│
├── tests/                         # 🧪 Test Scripts
│   ├── test_canvas*.ahk           # Canvas system tests
│   ├── test_stats*.ahk            # Statistics system tests
│   └── test_*.ahk                 # Various integration tests
│
├── archive/                       # 📦 Archived Code
│   ├── legacy-python/             # Obsolete Python/SQLite system
│   │   ├── stats/                 # Old SQLite stats backend
│   │   ├── dashboard/             # Old Plotly dashboard system
│   │   └── analytics/             # Old analytics scripts
│   └── Backroad-statsviz.zip      # Previous version backup
│
└── .claude/                       # Claude Code configuration
    ├── knowledge/                 # AI knowledge base
    └── settings.local.json        # Local Claude settings

```

---

## 🚀 Quick Navigation

### **For Users:**
1. **Start Here:** [`README.md`](README.md)
2. **User Manual:** [`docs/user-guide/USAGE_GUIDE.md`](docs/user-guide/USAGE_GUIDE.md)
3. **Statistics Guide:** [`docs/user-guide/SIMPLE_STATS_SYSTEM.md`](docs/user-guide/SIMPLE_STATS_SYSTEM.md)

### **For Developers:**
1. **System Architecture:** [`docs/developer-guide/ARCHITECTURE.md`](docs/developer-guide/ARCHITECTURE.md)
2. **Core System:** [`docs/developer-guide/CORE_SYSTEM.md`](docs/developer-guide/CORE_SYSTEM.md)
3. **Visualization:** [`docs/developer-guide/VISUALIZATION_SYSTEM.md`](docs/developer-guide/VISUALIZATION_SYSTEM.md)
4. **AI Guidelines:** [`docs/developer-guide/CLAUDE.md`](docs/developer-guide/CLAUDE.md)

### **For Distribution:**
- **Release Checklist:** [`DISTRIBUTION_CHECKLIST.md`](DISTRIBUTION_CHECKLIST.md)

---

## 📝 Key Files

### Source Code (`src/`)

| File | Purpose | Lines | Status |
|------|---------|-------|--------|
| `Main.ahk` | Application entry point, initialization | ~150 | Active |
| `Core.ahk` | State management, global variables | ~800 | Active |
| `MacroRecording.ahk` | Recording engine, event capture | ~400 | Active |
| `MacroExecution.ahk` | Playback engine, timing control | ~350 | Active |
| `VisualizationCore.ahk` | GDI+ operations, HBITMAP creation | ~500 | Active |
| `VisualizationCanvas.ahk` | Canvas detection, aspect ratio handling | ~300 | Active |
| `Stats.ahk` | CSV statistics, data collection | ~400 | Active |
| `StatsGui.ahk` | Statistics display GUI | ~350 | Active |
| `GUI.ahk` | Main GUI layout, button grid | ~600 | Active |
| `GUIControls.ahk` | Button management, event handling | ~300 | Active |
| `Hotkeys.ahk` | Hotkey definitions, input handling | ~200 | Active |

**Total:** ~4,350 lines of AutoHotkey v2.0 code

### Documentation (`docs/`)

#### User Documentation
- **USAGE_GUIDE.md** - Complete user manual with troubleshooting
- **SIMPLE_STATS_SYSTEM.md** - Statistics system documentation

#### Developer Documentation
- **ARCHITECTURE.md** - System design, data flow, module dependencies
- **VISUALIZATION_SYSTEM.md** - Graphics pipeline, HBITMAP/PNG systems
- **CORE_SYSTEM.md** - Core functionality, state management
- **CLAUDE.md** - AI development guidelines for Claude Code

#### Archived Documentation
- Phase 2 planning documents
- Polish phase changelogs
- System analysis reports
- Development snapshots

---

## 🗂️ Runtime Directories

These directories are **created automatically** at runtime:

### Data Directory
**Location:** `C:\Users\{user}\Documents\MacroMaster\data\`

```
data/
├── config.ini              # Application configuration
├── session_stats.csv       # Current session statistics (resets on startup)
└── master_stats.csv        # Permanent historical statistics (never deleted)
```

### Thumbnails Directory
**Location:** `C:\Users\{user}\Documents\MacroMaster\thumbnails\`

```
thumbnails/
└── *.png                   # Button thumbnail images (auto-generated)
```

**Note:** These directories are in `.gitignore` and should NOT be committed.

---

## 🏗️ Architecture Overview

### Technology Stack
- **Core:** AutoHotkey v2.0
- **Graphics:** GDI+ (HBITMAP/PNG)
- **Data Storage:** CSV files
- **Configuration:** INI files

### Module Organization
- **Core Engine:** `Core.ahk`, `Main.ahk`
- **Macro System:** `MacroRecording.ahk`, `MacroExecution.ahk`, `Macros.ahk`
- **Visualization:** `Visualization*.ahk` (3 files)
- **Statistics:** `Stats*.ahk` (3 files)
- **GUI:** `GUI*.ahk` (4 files)
- **Configuration:** `Config*.ahk` (2 files)
- **Utilities:** `Utils.ahk`, `Canvas.ahk`, `Dialogs.ahk`, `Hotkeys.ahk`

### Data Flow
```
User Input → MacroRecording → Event Storage → Visualization → GUI Display
                                    ↓
                              Stats.ahk → CSV Files (session + master)
                                    ↓
                              StatsGui.ahk → Today/All-Time Display
```

---

## 📦 Archive Directory

### What's Archived

#### `archive/legacy-python/`
Contains the **obsolete Python/SQLite/Plotly system** that was replaced with the current CSV-based system:

- **stats/** - Old SQLite database backend
  - `generate_dashboard.py` - Plotly dashboard generator
  - `record_execution.py` - Database insertion script
  - `init_database.py` - Database initialization
  - `database_schema.sql` - SQLite schema

- **dashboard/** - Old Plotly visualization system
  - `live_dashboard.py` - Real-time dashboard
  - `timeline_slider_dashboard.py` - Timeline visualization
  - Various `.bat` launcher scripts

- **analytics/** - Old analytics scripts
  - `install_chart_dependencies.py` - Dependency installer

**Status:** Archived as of 2025-10-09, replaced with CSV-only system

#### `archive/Backroad-statsviz.zip`
Backup of previous version before major refactoring

---

## 🔧 Development Workflow

### 1. Daily Development
- Work in `src/` directory
- Test with `tests/*.ahk` scripts
- Update relevant documentation in `docs/developer-guide/`

### 2. Adding Features
1. Update code in `src/`
2. Add/update tests in `tests/`
3. Update `docs/developer-guide/ARCHITECTURE.md` if architecture changes
4. Update `docs/user-guide/USAGE_GUIDE.md` if user-facing

### 3. Before Release
1. Review `DISTRIBUTION_CHECKLIST.md`
2. Update version numbers in `README.md`
3. Test all functionality
4. Update user documentation

---

## 🚫 What NOT to Commit

The following are in `.gitignore` and should **never** be committed:

- `data/` - User configuration and statistics
- `config.ini` - User-specific configuration
- `*.csv` - Statistics data files
- `thumbnails/` - Runtime-generated thumbnails
- `*.log` - Debug logs
- `*.tmp`, `*.temp`, `*.bak` - Temporary files
- `archive/legacy-python/` - Obsolete code

---

## 📋 File Count Summary

```
Source Code (src/)           : 20 files (~4,350 lines)
Documentation (docs/)        : 11 files (user + developer)
Tests (tests/)              : 12 files
Archive (archive/)          : Legacy Python system (not for distribution)
Root Files                  : 3 files (README, CHECKLIST, STRUCTURE)

Total Active Files          : ~46 files
```

---

## 🎯 Distribution Package

When distributing MacroMaster V555, include **only**:

```
MacroMasterZ8W/
├── README.md
├── DISTRIBUTION_CHECKLIST.md
├── PROJECT_STRUCTURE.md
├── src/                    (all .ahk files)
├── docs/
│   ├── user-guide/
│   └── developer-guide/
└── tests/                  (optional)
```

**Exclude:**
- `archive/` directory
- `.git/` directory
- `.claude/` directory
- `data/` directory (created at runtime)
- `thumbnails/` directory (created at runtime)

---

## 📞 Questions?

- **User Questions:** See [`docs/user-guide/USAGE_GUIDE.md`](docs/user-guide/USAGE_GUIDE.md)
- **Development Questions:** See [`docs/developer-guide/ARCHITECTURE.md`](docs/developer-guide/ARCHITECTURE.md)
- **AI Development:** See [`docs/developer-guide/CLAUDE.md`](docs/developer-guide/CLAUDE.md)

---

**Last Updated:** 2025-10-09
**Maintained By:** MacroMaster Development Team
