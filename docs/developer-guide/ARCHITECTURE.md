# MacroMaster Architecture Overview

**Version:** 2.0
**Last Updated:** 2025-10-08
**Status:** Production Ready

---

## System Overview

MacroMaster is a comprehensive AutoHotkey v2.0 macro recording and playback system designed for offline data labeling workflows. The system uses a modular architecture with multiple visualization layers and CSV-based analytics.

### Key Characteristics

- **Modular Design**: 20+ separate AHK modules with clear separation of concerns
- **Multi-Layer Visualization**: HBITMAP and PNG fallback systems
- **Dual Canvas Support**: Wide (16:9) and narrow (4:3) aspect ratio handling
- **Real-time Statistics**: CSV-based analytics with today/all-time display
- **Corporate Safe**: Multiple fallback mechanisms for restricted environments
- **JSON Integration**: Native support for annotation system exports

---

## High-Level Architecture

```mermaid
graph TB
    subgraph "User Interface Layer"
        GUI[Main GUI<br/>Layer Navigation<br/>Button Grid]
        STATS[Stats Display<br/>Today/All-Time View<br/>CSV-Based]
        CONFIG[Configuration<br/>Canvas Calibration<br/>Settings]
    end

    subgraph "Core Engine"
        CORE[Core.ahk<br/>State Management<br/>Initialization<br/>Configuration]
        RECORD[MacroRecording.ahk<br/>Event Capture<br/>Mouse/Keyboard Hooks]
        EXECUTE[MacroExecution.ahk<br/>Playback Engine<br/>Timing Control]
    end

    subgraph "Visualization System"
        VISUAL[VisualizationCore.ahk<br/>GDI+ Operations<br/>Bitmap Creation]
        CANVAS[VisualizationCanvas.ahk<br/>Scaling Logic<br/>Canvas Detection]
        UTILS[VisualizationUtils.ahk<br/>Event Processing<br/>Color Mapping]
    end

    subgraph "Data & Analytics"
        STATS_CORE[Stats.ahk<br/>CSV Generation<br/>Real-time Tracking]
        CSV[(CSV Files<br/>session_stats.csv<br/>master_stats.csv<br/>Execution Records)]
        STATS[Stats.ahk<br/>Simple CSV Display<br/>Today/All-Time Layout<br/><100ms Display]
    end

    subgraph "Supporting Modules"
        HOTKEYS[Hotkeys.ahk<br/>Input Handling<br/>WASD System]
        DIALOGS[Dialogs.ahk<br/>User Interaction<br/>Modal Windows]
        CONTROLS[GUIControls.ahk<br/>Button Management<br/>Event Handling]
        LAYOUT[GUILayout.ahk<br/>Window Layout<br/>Responsive Design]
    end

    GUI --> CORE
    STATS --> STATS_CORE
    CONFIG --> CORE

    CORE --> RECORD
    CORE --> EXECUTE
    CORE --> VISUAL

    RECORD --> STATS_CORE
    EXECUTE --> STATS_CORE

    VISUAL --> CANVAS
    VISUAL --> UTILS

    STATS_CORE --> CSV

    HOTKEYS --> CORE
    DIALOGS --> GUI
    CONTROLS --> GUI
    LAYOUT --> GUI
```

---

## Module Dependencies

### Core Dependencies

```mermaid
graph TD
    A[Main.ahk] --> B[Core.ahk]
    B --> C[Config.ahk]
    B --> D[Visualization.ahk]
    B --> E[Stats.ahk]
    B --> F[GUI.ahk]

    C --> G[ConfigIO.ahk]
    D --> H[VisualizationCore.ahk]
    D --> I[VisualizationCanvas.ahk]
    D --> J[VisualizationUtils.ahk]

    F --> K[GUIControls.ahk]
    F --> L[GUILayout.ahk]
    F --> M[GUIEvents.ahk]
    F --> N[Hotkeys.ahk]
    F --> O[Dialogs.ahk]
```

### Runtime Dependencies

```mermaid
graph LR
    A[Macro Execution] --> B[MacroExecution.ahk]
    A --> C[Canvas.ahk]
    A --> D[Utils.ahk]

    B --> E[Stats.ahk]
    C --> F[VisualizationCore.ahk]
    D --> G[ConfigIO.ahk]

    E --> H[(CSV Files)]
    F --> I[GDI+ Library]
    G --> J[(INI Files)]
```

---

## Data Flow Architecture

### Macro Recording Flow

```mermaid
sequenceDiagram
    participant U as User
    participant H as Hotkeys.ahk
    participant R as MacroRecording.ahk
    participant C as Core.ahk
    participant S as Stats.ahk
    participant V as Visualization.ahk

    U->>H: Press F9 (Record)
    H->>C: Set recording = true
    C->>R: Start recording session

    loop Recording Loop
        R->>R: Capture mouse/keyboard events
        U->>R: Draw bounding boxes
        U->>R: Press 1-9 (degradation keys)
        R->>R: Associate degradation with boxes
    end

    U->>H: Press F9 (Stop)
    H->>C: Set recording = false
    C->>R: Stop recording
    R->>C: Return macro events array
    C->>V: Generate visualization
    V->>C: Return thumbnail path
    C->>S: Record execution stats
    S->>S: Write to CSV files
```

### Macro Playback Flow

```mermaid
sequenceDiagram
    participant U as User
    participant H as Hotkeys.ahk
    participant C as Core.ahk
    participant E as MacroExecution.ahk
    participant S as Stats.ahk

    U->>H: Press numpad key
    H->>C: Lookup macro by layer+button
    C->>E: Execute macro events

    loop Event Playback
        E->>E: Mouse move to coordinates
        E->>E: Click and drag for boxes
        E->>E: Press degradation keys
        E->>E: Apply timing delays
    end

    E->>C: Execution complete
    C->>S: Record execution stats
    S->>S: Update CSV files
    C->>U: Show completion status
```

### Statistics Display Flow

```mermaid
sequenceDiagram
    participant U as User
    participant C as Core.ahk
    participant S as Stats.ahk
    participant CSV as CSV Files

    U->>C: Click Stats button
    C->>S: Show statistics GUI
    S->>CSV: Read session_stats.csv
    S->>CSV: Read master_stats.csv
    S->>S: Calculate today totals
    S->>S: Calculate all-time totals
    S->>U: Display horizontal stats GUI
```

---

## State Management Architecture

### Global State Variables

```mermaid
graph TD
    subgraph "Execution State"
        REC[recording<br/>boolean]
        PLAY[playback<br/>boolean]
        AWAIT[awaitingAssignment<br/>boolean]
        LAST[lastExecutionTime<br/>timestamp]
    end

    subgraph "System Configuration"
        LAYER[currentLayer<br/>1-5]
        MODE[annotationMode<br/>Wide/Narrow]
        CANVAS[canvasType<br/>wide/narrow/custom]
        DARK[darkMode<br/>boolean]
    end

    subgraph "Resource Management"
        CACHE[hbitmapCache<br/>Map]
        HOOKS[mouseHook<br/>keyboardHook]
        GUI[mainGui<br/>statusBar]
    end

    subgraph "Statistics State"
        SESSION[sessionId<br/>string]
        ACTIVE[totalActiveTime<br/>ms]
        BREAK[breakMode<br/>boolean]
        QUEUE[statsQueue<br/>array]
    end
```

### State Transitions

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> Recording: F9 press
    Recording --> Idle: F9 press
    Idle --> Playback: Numpad press
    Playback --> Idle: Execution complete
    Idle --> Break: Ctrl+B press
    Break --> Idle: Ctrl+B press

    Recording --> Error: Hook failure
    Playback --> Error: Execution failure
    Error --> Idle: ForceStateReset()

    note right of Recording
        Captures mouse/keyboard events
        Associates degradations with boxes
    end note

    note right of Playback
        Replays recorded events
        Applies timing delays
        Records execution stats
    end note

    note right of Break
        Pauses time tracking
        Stops statistics collection
    end note
```

---

## Visualization Pipeline

### Three-Tier Visualization System

```mermaid
graph TD
    A[Macro Events] --> B{HBITMAP Available?}
    B -->|Yes| C[CreateHBITMAPVisualization]
    B -->|No| D[CreateMacroVisualization]

    C --> E{HBITMAP Success?}
    E -->|Yes| F[Return HBITMAP handle]
    E -->|No| D

    D --> G{PNG Success?}
    G -->|Yes| H[Return PNG file path]
    G -->|No| I[Return empty string]

    F --> J[GUI Picture Control]
    H --> J
    I --> K[Show default icon]

    J --> L[Button Thumbnail Display]
    K --> L
```

### Canvas Detection & Scaling

```mermaid
graph TD
    A[Recorded Macro] --> B[Calculate Bounding Box]
    B --> C[Compute Aspect Ratio]
    C --> D{User Mode Set?}

    D -->|Wide| E{Calibrated?}
    D -->|Narrow| F{Calibrated?}
    D -->|Auto| G{Fits Wide Canvas?}

    E -->|Yes| H[Use Wide Canvas]
    E -->|No| I{Fits Wide?}
    I -->|Yes| H
    I -->|No| J{Use Narrow}

    F -->|Yes| K[Use Narrow Canvas]
    F -->|No| L{Fits Narrow?}
    L -->|Yes| K
    L -->|No| M{Use Legacy}

    G -->|Yes| N{Coverage Analysis}
    G -->|No| O{Fits Narrow?}

    N -->|Wide > 65%| H
    N -->|Narrow > 65%| K

    O -->|Yes| K
    O -->|No| M

    H --> P[Stretch to Fill]
    K --> Q[Letterbox 4:3]
    M --> R[Stretch to Fill]
```

---

## Data Storage Architecture

### Multi-Layer Storage System

```mermaid
graph TD
    subgraph "Primary Storage"
        A[macroEvents Map<br/>Runtime storage<br/>Layer.Button → Events]
    end

    subgraph "Persistent Storage"
        B[config.ini<br/>Settings & macros<br/>INI format]
    end

    subgraph "Statistics Storage"
        C[session_stats.csv<br/>Current session data<br/>Resets on startup]
        D[master_stats.csv<br/>Permanent historical data<br/>Never deleted]
    end

    subgraph "Visualization Cache"
        E[thumbnails/ Directory<br/>PNG files<br/>Auto-cleanup]
        F[hbitmapCache Map<br/>Memory handles<br/>Runtime cache]
    end

    A --> B
    B --> A
    A --> C
    A --> D
    A --> E
    A --> F
```

### CSV Data Format

**Session Stats CSV (session_stats.csv):**
```csv
timestamp,session_id,button_key,layer,execution_time_ms,total_boxes,smudge,glare,splashes,partial_blockage,full_blockage,light_flare,rain,haze,snow
```

**Master Stats CSV (master_stats.csv):**
- Same format as session_stats.csv
- Permanent historical record
- Never reset or deleted
- Appended to with each execution

**Key Fields:**
- `timestamp`: ISO 8601 datetime
- `session_id`: UUID for session tracking
- `button_key`: Numpad key name (e.g., "NumpadDot")
- `layer`: Layer number (1-5)
- `execution_time_ms`: Macro execution duration
- `total_boxes`: Number of boxes drawn
- `smudge` through `snow`: Count of each degradation type (9 types)

---

## Error Handling & Recovery

### Error Handling Architecture

```mermaid
graph TD
    A[Error Occurs] --> B{Error Type}
    B -->|Initialization| C[Log & Continue<br/>Degraded Mode]
    B -->|Runtime| D{Recoverable?}
    B -->|Critical| E[Emergency Stop<br/>Force Reset]

    D -->|Yes| F[Graceful Recovery<br/>State Reset]
    D -->|No| E

    C --> G[Status Update<br/>User Notification]
    F --> G
    E --> H[Complete Cleanup<br/>Resource Release]

    G --> I[Continue Operation]
    H --> J[Application Exit<br/>Manual Restart]
```

### Recovery Mechanisms

- **State Reset**: `ForceStateReset()` clears stuck states
- **Emergency Stop**: `EmergencyStop()` halts all activity
- **Resource Cleanup**: `CleanupAndExit()` releases handles
- **Configuration Validation**: Periodic integrity checks
- **Fallback Paths**: Multiple storage locations
- **Silent Degradation**: Continue with reduced functionality

---

## Performance Characteristics

### Performance Metrics

| Component | Operation | Typical Time | Notes |
|-----------|-----------|---------------|-------|
| **Visualization** | HBITMAP creation | <1ms cached, 5-10ms new | Per button |
| | PNG generation | 15-30ms | File I/O overhead |
| | Canvas detection | <1ms | Aspect ratio calculation |
| **Execution** | Macro playback | 50-500ms | Depends on complexity |
| | Stats recording | <10ms | CSV write |
| **Statistics** | CSV read/parse | <50ms | Per file |
| | Stats GUI display | <100ms | Calculation + rendering |
| **Initialization** | Cold start | 2-5s | First launch |
| | Warm start | <1s | Subsequent launches |

### Memory Usage

```mermaid
pie title Memory Usage Breakdown
    "HBITMAP Cache" : 40
    "GUI Controls" : 25
    "Global Variables" : 15
    "GDI+ Resources" : 10
    "Statistics Queue" : 5
    "Other" : 5
```

### Scalability Considerations

- **Macro Count**: Handles 1000+ macros per layer
- **Execution History**: Efficient CSV parsing for large datasets
- **Visualization Cache**: Automatic cleanup prevents bloat
- **Session Length**: Optimized for 8+ hour labeling sessions
- **Concurrent Operations**: Single-threaded design, no race conditions

---

## Security & Corporate Compatibility

### Corporate Environment Features

```mermaid
graph TD
    A[Corporate Environment] --> B[Path Fallbacks]
    A --> C[Silent Degradation]
    A --> D[No External Dependencies]
    A --> E[Local Storage Only]

    B --> F[Documents Folder]
    B --> G[Script Directory]
    B --> H[User Profile]
    B --> I[Desktop]

    C --> J[Continue on Failure]
    C --> K[No Error Dialogs]
    C --> L[Reduced Functionality]

    D --> M[Self-Contained AHK]
    D --> N[CSV Files Only]
    D --> O[GDI+ Only]

    E --> P[No Network Access]
    E --> Q[No Cloud Storage]
    E --> R[Offline Operation]
```

### Security Measures

- **No Network Communication**: All operations local
- **No External Executables**: Pure AutoHotkey v2.0
- **Safe File Operations**: Atomic writes with backups
- **Input Validation**: Bounds checking on all coordinates
- **Resource Limits**: Memory and file size constraints
- **Error Containment**: Failures don't compromise system state

---

## Development & Maintenance

### Code Organization

```
src/
├── Core.ahk              # System foundation
├── Main.ahk              # Entry point
├── *-recording related-  # Recording functionality
├── *-execution related-  # Playback functionality
├── *-visualization-*     # Graphics and thumbnails
├── *-gui*                # User interface
├── *-stats*              # Analytics and tracking
└── *-utils*              # Helper functions

docs/
├── ARCHITECTURE.md       # This file
├── VISUALIZATION_SYSTEM.md
├── CORE_SYSTEM.md
├── CLAUDE.md            # AI development guide
└── SIMPLE_STATS_SYSTEM.md

data/
├── session_stats.csv    # Current session data
└── master_stats.csv     # Permanent historical data

tests/
└── test_*.ahk          # AHK test scripts
```

### Development Workflow

```mermaid
graph LR
    A[Feature Request] --> B[Architect Design]
    B --> C[Implement Core.ahk]
    C --> D[Test Core Functions]
    D --> E[Implement Modules]
    E --> F[Integration Testing]
    F --> G[Update Documentation]
    G --> H[Release]
```

### Quality Assurance

- **Modular Testing**: Each .ahk file can be tested independently
- **State Validation**: Comprehensive state checking functions
- **Error Simulation**: Built-in failure mode testing
- **Performance Monitoring**: Built-in benchmarking tools
- **Configuration Validation**: Automatic integrity checking

---

## Future Evolution

### Planned Enhancements

```mermaid
timeline
    title MacroMaster Evolution
    section Phase 1-2 (Current)
        CSV Statistics : Complete
        Simple Today/All-Time Display : Complete
        Dual-Write Recording (CSV + Permanent) : Complete
        Never-Lost Historical Data : Complete
        Dual Canvas Support : Complete
        HBITMAP/PNG Visualization : Complete

    section Phase 3 (Future)
        Enhanced CSV Analytics : Planned
        Export/Import Features : Planned
        Advanced Filtering : Planned
        Performance Optimization : Planned

    section Phase 4 (Future)
        Multi-user Support : Planned
        Network Synchronization : Planned
        Advanced ML Features : Planned
        Mobile Companion : Planned
```

### Scalability Roadmap

- **Phase 3**: Enhanced CSV analytics, export features
- **Phase 4**: Multi-user collaboration features
- **Phase 5**: Network synchronization options
- **Phase 6**: Enterprise deployment tools

---

## Quick Reference

### System Components

| Component | Primary File | Purpose |
|-----------|--------------|---------|
| **Core Engine** | `Core.ahk` | State management, initialization |
| **Recording** | `MacroRecording.ahk` | Event capture, degradation assignment |
| **Playback** | `MacroExecution.ahk` | Macro execution, timing |
| **Visualization** | `Visualization*.ahk` | Thumbnails, canvas handling |
| **Statistics** | `Stats.ahk` | Data collection, CSV storage, GUI display |
| **GUI** | `GUI*.ahk` | User interface, controls |

### Key Hotkeys

| Hotkey | Function | Module |
|--------|----------|--------|
| `F9` | Toggle recording | `Hotkeys.ahk` |
| `Ctrl+B` | Break mode | `Core.ahk` |
| `Numpad 0-9` | Execute macros | `Hotkeys.ahk` |
| `Shift+Enter` | Submit image | `Core.ahk` |
| `RCtrl` | Emergency stop | `Core.ahk` |

### File Locations

| Type | Location | Purpose |
|------|----------|---------|
| **Configuration** | `Documents\MacroMaster\data\config.ini` | Settings & macros |
| **Session Stats** | `Documents\MacroMaster\data\session_stats.csv` | Current session data |
| **Historical Stats** | `Documents\MacroMaster\data\master_stats.csv` | Permanent execution history |
| **Thumbnails** | `Documents\MacroMaster\thumbnails\` | Button images |

---

**Document Maintained By:** MacroMaster Architecture Team
**Last Review:** 2025-10-08
**Next Review:** 2025-11-08