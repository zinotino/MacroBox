# MacroMaster Z8W

**Advanced AutoHotkey Macro Recording and Playback System for Offline Data Labeling**

[![Version](https://img.shields.io/badge/version-2.0-blue.svg)](https://github.com/your-repo/MacroMasterZ8W)
[![AutoHotkey](https://img.shields.io/badge/AutoHotkey-v2.0-orange.svg)](https://www.autohotkey.com/)
[![Python](https://img.shields.io/badge/Python-3.8+-blue.svg)](https://www.python.org/)
[![SQLite](https://img.shields.io/badge/SQLite-3-green.svg)](https://www.sqlite.org/)
[![License](https://img.shields.io/badge/license-MIT-red.svg)](LICENSE)

---

## 🎯 Overview

MacroMaster Z8W is a comprehensive macro recording and playback system designed specifically for offline data labeling workflows. It features a modular architecture with advanced visualization capabilities, real-time statistics tracking, and corporate environment compatibility.

### ✨ Key Features

- **🎥 Advanced Macro Recording**: Record mouse movements, clicks, and keyboard inputs with degradation assignment
- **🎨 Intelligent Visualization**: Three-tier visualization system (HBITMAP, PNG, Plotly dashboard)
- **📊 Real-time Analytics**: CSV-powered statistics with today/all-time horizontal display
- **🔧 Dual Canvas Support**: Automatic wide/narrow aspect ratio detection and scaling
- **🏢 Corporate Ready**: Multiple fallback mechanisms for restricted environments
- **⚡ High Performance**: <1ms cached rendering, optimized for 8+ hour sessions
- **🔄 Modular Architecture**: 20+ separate components for maintainability
- **📊 Simple Stats Display**: Today and All-Time statistics in horizontal layout
- **📈 CSV-Based Analytics**: Lightweight statistics with degradation breakdowns
- **💾 Permanent Data Storage**: Never-lost historical data with reset protection

### 🚀 Quick Start

#### Requirements
- Windows 10/11
- [AutoHotkey v2.0](https://www.autohotkey.com/v2/)
- Python 3.8+ (for dashboard)
- 200 MB free disk space

#### Installation

1. **Clone or download** the repository
2. **Install Python dependencies:**
   ```bash
   pip install plotly
   ```
3. **Run the application:**
   ```bash
   "C:\Program Files\AutoHotkey\v2\AutoHotkey.exe" src/Main.ahk
   ```

#### First Use

1. **Calibrate Canvas**: Click "Calibrate Canvas" and draw around your labeling area
2. **Record Macro**: Press `F9`, draw boxes, press `1-9` for degradations, press `F9` again
3. **Assign & Execute**: Press numpad key to assign, then execute
4. **View Statistics**: Click "Stats" button for interactive dashboard

---

## 📖 Documentation

### 📚 Complete Documentation Suite

| Document | Description | Link |
|----------|-------------|------|
| **🏗️ Architecture Overview** | System design, data flow, dependencies | [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) |
| **🎨 Visualization System** | Graphics pipeline, canvas handling, HBITMAP/PNG systems | [`docs/VISUALIZATION_SYSTEM.md`](docs/VISUALIZATION_SYSTEM.md) |
| **⚙️ Core System** | State management, initialization, configuration | [`docs/CORE_SYSTEM.md`](docs/CORE_SYSTEM.md) |
| **📖 Usage Guide** | Complete user manual, troubleshooting | [`docs/USAGE_GUIDE.md`](docs/USAGE_GUIDE.md) |
| **📊 Simple Stats System** | CSV statistics with today/all-time display | [`docs/SIMPLE_STATS_SYSTEM.md`](docs/SIMPLE_STATS_SYSTEM.md) |
| **🤖 AI Development Guide** | Claude/Grok integration guidelines | [`docs/CLAUDE.md`](docs/CLAUDE.md) |
| **🔍 System Analysis** | Legacy code analysis, refactoring recommendations | [`docs/SYSTEM_ANALYSIS_2025-10-08.md`](docs/SYSTEM_ANALYSIS_2025-10-08.md) |

### 🎯 Quick Links

- [**Getting Started**](docs/USAGE_GUIDE.md#quick-start) - Installation and first run
- [**Basic Workflow**](docs/USAGE_GUIDE.md#basic-workflow) - Complete labeling session
- [**Troubleshooting**](docs/USAGE_GUIDE.md#troubleshooting) - Common issues and solutions
- [**Configuration**](docs/USAGE_GUIDE.md#configuration) - Settings and customization
- [**Performance**](docs/USAGE_GUIDE.md#performance-optimization) - Optimization tips

---

## 🎮 Usage

### Basic Workflow

```mermaid
graph LR
    A[Start App] --> B[Calibrate Canvas]
    B --> C[Press F9 to Record]
    C --> D[Draw Boxes + Assign 1-9]
    D --> E[Press F9 to Stop]
    E --> F[Assign to Numpad Key]
    F --> G[Execute Macro]
    G --> H[View Dashboard]
```

### Hotkeys

| Hotkey | Function | Context |
|--------|----------|---------|
| `F9` | Toggle recording | Always |
| `Ctrl+B` | Break mode toggle | Always |
| `Numpad 0-9,.,*` | Execute macro | GUI active |
| `Shift+Numpad` | Clear execution | GUI active |
| `Shift+Enter` | Submit image | Browser focus |
| `Numpad /, -` | Change layer | GUI active |
| `RCtrl` | Emergency stop | Always |

### Degradation Types

| Key | Type | Description | Color |
|-----|------|-------------|-------|
| `1` | Smudge | Lens smudges | Orange |
| `2` | Glare | Light glare | Gold |
| `3` | Splashes | Water droplets | Purple |
| `4` | Partial Blockage | Object obstruction | Green |
| `5` | Full Blockage | Complete obstruction | Red |
| `6` | Light Flare | Lens flare | Pink |
| `7` | Rain | Rain drops | Brown |
| `8` | Haze | Atmospheric haze | Gray |
| `9` | Snow | Snow accumulation | Teal |

---

## 🏗️ Architecture

### System Components

```
src/
├── Core.ahk              # System foundation & state management
├── Main.ahk              # Application entry point
├── MacroRecording.ahk    # Event capture & degradation assignment
├── MacroExecution.ahk    # Playback engine & timing control
├── VisualizationCore.ahk # GDI+ operations & bitmap creation
├── VisualizationCanvas.ahk # Canvas detection & scaling
├── GUI*.ahk              # User interface components
└── *-related modules     # Specialized functionality

stats/
├── generate_dashboard.py # Interactive analytics dashboard
├── init_database.py      # SQLite database setup
├── migrate_csv_to_db.py  # Data migration utilities
└── test_database.py      # Database testing suite

docs/
├── ARCHITECTURE.md       # System design documentation
├── VISUALIZATION_SYSTEM.md # Graphics pipeline docs
├── CORE_SYSTEM.md        # Core functionality docs
└── USAGE_GUIDE.md        # User manual & troubleshooting
```

### Data Flow

```mermaid
graph TD
    A[User Input] --> B[MacroRecording.ahk]
    B --> C[Event Storage]
    C --> D[VisualizationCore.ahk]
    D --> E[Thumbnail Generation]
    E --> F[GUI Display]

    C --> G[Stats.ahk]
    G --> H[CSV + SQLite Storage]
    H --> I[generate_dashboard.py]
    I --> J[Interactive HTML Dashboard]
```

### Key Technologies

- **AutoHotkey v2.0**: Core automation engine
- **GDI+**: Graphics rendering and bitmap operations
- **SQLite**: High-performance database backend
- **Plotly**: Interactive data visualization
- **Python**: Analytics and dashboard generation

---

## 📊 Statistics & Analytics

### Simple Statistics Display

- **📊 Horizontal Layout**: Today and All-Time statistics side-by-side
- **📈 Degradation Breakdown**: Per-type counts for all 9 degradation types
- **⏱️ Performance Metrics**: Execution times, boxes per hour, efficiency ratios
- **🎯 Usage Analytics**: Most used buttons, active layers, execution types
- **💾 CSV Storage**: Lightweight, portable statistics in CSV format
- **🔄 Reset Protection**: Permanent master stats file preserves all historical data

### Database Schema

```sql
-- Executions table
CREATE TABLE executions (
    id INTEGER PRIMARY KEY,
    timestamp DATETIME,
    session_id TEXT,
    button_key TEXT,
    layer INTEGER,
    execution_time_ms INTEGER,
    total_boxes INTEGER,
    degradation_assignments TEXT
);

-- Degradations table (normalized)
CREATE TABLE degradations (
    execution_id INTEGER,
    degradation_type TEXT,
    count INTEGER
);
```

### Sample Dashboard

![Dashboard Preview](https://via.placeholder.com/800x400/4CAF50/FFFFFF?text=Interactive+Dashboard+Preview)

---

## 🔧 Development

### Prerequisites

- AutoHotkey v2.0 development environment
- Python 3.8+ with Plotly
- Git for version control
- VS Code with AHK extension (recommended)

### Building

```bash
# Clone repository
git clone https://github.com/your-repo/MacroMasterZ8W.git
cd MacroMasterZ8W

# Install Python dependencies
pip install -r stats/requirements.txt

# Run tests
python stats/test_database.py

# Start development
"C:\Program Files\AutoHotkey\v2\AutoHotkey.exe" src/Main.ahk
```

### Testing

```bash
# Run database tests
python stats/test_database.py

# Generate test dashboard
python stats/generate_dashboard.py --filter today

# Run AHK syntax check
"C:\Program Files\AutoHotkey\v2\AutoHotkey.exe" /ErrorStdOut src/Main.ahk
```

### Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 🏢 Corporate Environment

### Enterprise Features

- **🔒 No External Dependencies**: All components self-contained
- **📁 Multiple Fallback Paths**: Automatic directory detection
- **🔄 Silent Degradation**: Continues working with reduced features
- **🚫 No Network Required**: Complete offline operation
- **🔧 Group Policy Compatible**: Works with standard restrictions

### Deployment Considerations

- **Per-User Installation**: Isolated data directories
- **Automatic Fallbacks**: Corporate path restrictions handled
- **Memory Efficient**: Optimized for long sessions
- **Error Resilient**: Graceful failure handling

---

## 📈 Performance

### Benchmarks

| Operation | Performance | Notes |
|-----------|-------------|-------|
| **HBITMAP Rendering** | <1ms cached, 5-10ms new | Per thumbnail |
| **Macro Execution** | 50-500ms | Depends on complexity |
| **Stats Display** | <100ms | CSV parsing and GUI rendering |
| **Database Query** | <100ms | With indexes |
| **Application Startup** | 2-5s | Cold start |

### System Requirements

- **Minimum**: 4GB RAM, Dual-core CPU, 200MB storage
- **Recommended**: 8GB RAM, Quad-core CPU, 500MB storage
- **Optimal**: 16GB RAM, Modern CPU, SSD storage

---

## 🐛 Troubleshooting

### Common Issues

**Application won't start:**
```bash
# Check AutoHotkey installation
"C:\Program Files\AutoHotkey\v2\AutoHotkey.exe" --version

# Verify Python
python --version
pip list | findstr plotly
```

**Black thumbnails:**
- Check canvas calibration
- Verify GDI+ initialization
- Clear HBITMAP cache

**Statistics not recording:**
- Check file permissions
- Verify break mode is off
- Test CSV write access

**Slow performance:**
- Clear visualization cache
- Optimize macro complexity
- Check memory usage

### Debug Mode

```autohotkey
; Enable debug output in Core.ahk
UpdateStatus("Debug: GDI+ = " . gdiPlusInitialized)
UpdateStatus("Debug: Canvas = " . isCanvasCalibrated)
UpdateStatus("Debug: Cache size = " . hbitmapCache.Count)
```

### Emergency Recovery

```autohotkey
; Complete system reset
EmergencyStop()        ; Halt all operations
CleanupHBITMAPCache()  ; Clear memory
ForceStateReset()      ; Reset state
; Restart application
```

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🙏 Acknowledgments

- **AutoHotkey Community**: For the powerful automation framework
- **SQLite Team**: For the reliable embedded database
- **Plotly Team**: For the excellent visualization library
- **Open Source Community**: For the tools and libraries that make this possible

---

## 📞 Support

### Documentation
- 📖 [Complete Usage Guide](docs/USAGE_GUIDE.md)
- 🏗️ [Architecture Documentation](docs/ARCHITECTURE.md)
- 🎨 [Visualization System](docs/VISUALIZATION_SYSTEM.md)
- ⚙️ [Core System Details](docs/CORE_SYSTEM.md)
- 📊 [Simple Stats System](docs/SIMPLE_STATS_SYSTEM.md)

### Issue Reporting
- 🐛 [GitHub Issues](https://github.com/your-repo/MacroMasterZ8W/issues)
- 📧 Check documentation first
- 🔍 Search existing issues
- 📝 Provide detailed reproduction steps

### Feature Requests
- 💡 [GitHub Discussions](https://github.com/your-repo/MacroMasterZ8W/discussions)
- 📋 Use issue templates
- 🎯 Be specific about use cases
- 📊 Include performance impact analysis

---

## 🔄 Version History

### v2.0 (Current)
- ✅ Complete modular architecture
- ✅ Three-tier visualization system
- ✅ Simple CSV statistics with today/all-time display
- ✅ Dual-write recording (CSV + permanent master file)
- ✅ Never-lost historical data protection
- ✅ Corporate environment support
- ✅ Comprehensive documentation

### v1.x Legacy
- ✅ Basic macro recording/playback
- ✅ CSV statistics tracking
- ✅ Single canvas support
- ✅ Core functionality

---

**MacroMaster Z8W** - Transforming offline data labeling workflows with intelligent automation and comprehensive analytics.

---

*Built with ❤️ using AutoHotkey v2.0, Python, and SQLite*