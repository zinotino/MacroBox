# MacroMaster V555

A comprehensive AutoHotkey v2.0 macro recording and playback system designed for scalable, data-driven annotation workflows with real-time analytics and offline capabilities.

## 🎯 Project Vision

MacroMaster is built to enhance macro labeling workflows through intelligent automation, real-time visual feedback, and robust analytics. The system captures detailed data on each labeling action, providing immediate visual feedback while generating valuable insights for quality assurance and performance analysis.

## ✨ Core Features

### 🎬 Intelligent Macro System
- **Event-Driven Logic**: Two-part action detection (bounding box + optional numpad key)
- **State Management**: Persistent default degradation reduces repetitive input
- **Multi-Layer Organization**: 5 customizable layers with 12 buttons each (60 macro slots)
- **Automated Assignment**: Smart defaults for rapid labeling of similar categories

### 🎨 Real-Time Visualization
- **Dynamic Overlay**: Color-coded bounding boxes on canvas
- **Thumbnail Generation**: Proportional 1:1 visual representation on buttons
- **Dual Canvas Support**: Wide (16:9) and Narrow (4:3) aspect ratios
- **GDI+ Rendering**: Memory-efficient visualization without file I/O

### 📊 Comprehensive Analytics
- **Dual-Mode Operation**: Real-time dashboard + offline CSV analytics
- **Live Metrics**: Instant performance feedback via WebSocket
- **Historical Analysis**: Timeline slider for trend identification
- **Data Export**: Complete raw data access for workplace reporting

### ⌨️ Advanced Input System
- **WASD Hotkey Profile**: CapsLock + 12 keys (123/QWE/ASD/ZXC) mapped to numpad
- **Customizable Hotkeys**: Configurable keyboard shortcuts for all functions
- **Context Menus**: Right-click macro management
- **Break Mode**: Integrated time tracking with pause functionality

## 📁 Project Architecture

```
MacroMasterV555/
├── src/                          # Application source code
│   ├── Main.ahk                      # Entry point (modular system)
│   ├── MacroLauncherX45.ahk          # Original monolithic version
│   ├── MacroLauncherX46.ahk          # Real-time enabled version
│   ├── Core.ahk                      # Core variables & initialization
│   ├── GUI.ahk                       # User interface management
│   ├── Macros.ahk                    # Recording & playback engine
│   ├── Stats.ahk                     # Statistics & CSV operations
│   ├── Config.ahk                    # Configuration management
│   ├── Hotkeys.ahk                   # Input handling & WASD system
│   ├── Visualization.ahk             # GDI+ rendering & thumbnails
│   └── Utils.ahk                     # Helper functions
├── dashboard/                    # Analytics & visualization
│   ├── timeline_slider_dashboard.py      # Offline timeline dashboard
│   ├── database_schema.py                # SQLite database management
│   ├── data_ingestion_service.py         # Real-time HTTP API (port 5001)
│   ├── realtime_dashboard.py             # Live WebSocket dashboard (port 5002)
│   ├── requirements.txt                  # Python dependencies
│   ├── run_realtime_system.bat           # Real-time system launcher
│   ├── output/                           # Generated dashboard files
│   │   └── macromaster_timeline_slider.html
│   └── metrics/                          # Dashboard metrics storage
│       └── macromaster_timeline_metrics.json
├── tests/                        # Quality assurance
│   ├── test_json_tracking.ahk            # JSON annotation tests
│   └── test_stats_integration.ahk        # Statistics system tests
├── config/                       # Configuration templates
│   ├── config.ini                        # Default configuration
│   └── config_simple.txt                 # Minimal setup template
├── docs/                         # Documentation
│   └── CLAUDE.md                         # Development guidelines
├── data/                         # Runtime data storage
│   ├── master_stats.csv                  # CSV statistics (offline mode)
│   └── macromaster_realtime.db           # SQLite database (real-time mode)
└── thumbnails/                   # Button visualization cache
```

## 🚀 Quick Start

### Installation

**Prerequisites:**
- AutoHotkey v2.0+ ([Download](https://www.autohotkey.com/v2/))
- Python 3.8+ (for dashboard features)

**Install Python Dependencies:**
```bash
cd dashboard
pip install -r requirements.txt
```

### Running the Application

#### Option 1: Modular System (Recommended)
```bash
# Execute the new modular entry point
"C:\Program Files\AutoHotkey\v2\AutoHotkey.exe" src/Main.ahk
```

#### Option 2: Monolithic Version
```bash
# Execute the original single-file version
"C:\Program Files\AutoHotkey\v2\AutoHotkey.exe" src/MacroLauncherX45.ahk
```

#### Option 3: Real-Time Enabled System
```bash
# Start real-time services first
cd dashboard
run_realtime_system.bat

# Then start the real-time enabled AHK script
"C:\Program Files\AutoHotkey\v2\AutoHotkey.exe" src/MacroLauncherX46.ahk
```

### Canvas Configuration (First-Time Setup)

The application prompts you to define your canvas area for multi-monitor support:

1. **Launch Application**: Start MacroMaster
2. **Define Canvas**: Follow the calibration wizard to set canvas boundaries
3. **Choose Mode**: Select Wide (16:9) or Narrow (4:3) aspect ratio
4. **Save Configuration**: Settings persist across sessions

## 📊 Analytics Systems

### Real-Time Dashboard (Recommended)

**Features:**
- Live WebSocket updates as you work
- Instant performance metrics (boxes/hour, speed trends)
- Session-based tracking with isolation
- Multi-user support with concurrent access
- Automatic fallback to CSV if service unavailable

**Access:**
```bash
# Start services (runs in background)
cd dashboard
run_realtime_system.bat

# Open browser to: http://localhost:5002
# Enter session ID (shown in AHK status bar)
```

**Live Metrics:**
- Total Boxes Processed
- Session Duration (active labeling time)
- Average Speed (boxes per second)
- Current Speed (10-minute rolling window)
- Degradation Type Distribution
- Execution Time Statistics

### Offline Timeline Dashboard

**Features:**
- Historical trend analysis with interactive slider
- 6 focused charts in 3x3 layout
- Export-ready raw data tables
- No internet connection required
- Perfect for workplace reporting

**Generate Dashboard:**
```bash
cd dashboard
python timeline_slider_dashboard.py ../data/master_stats.csv

# Dashboard saves to: dashboard/output/macromaster_timeline_slider.html
# Automatically opens in default browser
```

**Chart Types:**
1. **Pie Charts**: Degradation types, combinations, JSON profiles
2. **Timeline**: Execution flow with slider controls
3. **Distribution**: Execution types and layer usage
4. **Raw Data Tables**: Complete session details

## 🎮 Usage Guide

### Recording a Macro

1. **Press F9** to enter recording mode (🔴 indicator appears)
2. **Perform Actions**: Draw bounding boxes, press keys
3. **Press Numpad Key** to assign macro to button (e.g., Num5)
4. **Macro Saved**: Button shows thumbnail preview

### Executing a Macro

**Method 1: Numpad Keys**
```
Num7, Num8, Num9    (Top row)
Num4, Num5, Num6    (Middle row)
Num1, Num2, Num3    (Bottom row)
Num0, NumDot, NumMult (Special keys)
```

**Method 2: WASD Profile** (CapsLock + Key)
```
CapsLock+1, CapsLock+2, CapsLock+3
CapsLock+Q, CapsLock+W, CapsLock+E
CapsLock+A, CapsLock+S, CapsLock+D
CapsLock+Z, CapsLock+X, CapsLock+C
```

**Method 3: Click Button**
- Left-click any button to execute its macro

### Context Menu (Right-Click)

- **Execute Macro**: Run the macro
- **Clear Macro**: Delete recording
- **View Details**: Show macro information
- **Auto-Execute**: Start automated looping
- **Export Macro**: Save for sharing

### Layer Management

- **NumpadDiv (/)**: Previous layer
- **NumpadSub (-)**: Next layer
- **Visual Indicator**: Colored border shows current layer

### Break Mode

- **Toggle**: Click "☕ Break" button or press Ctrl+B
- **Pauses Time Tracking**: Session time stops accumulating
- **Visual Feedback**: Button changes color when active

## 🔧 Configuration

### File Locations

**User Data** (Windows Documents folder):
```
C:\Users\[Username]\Documents\MacroMaster\
├── config.ini                    # User settings
├── data\
│   ├── master_stats.csv         # Offline analytics data
│   └── macromaster_realtime.db  # Real-time database
└── thumbnails\                   # Macro visualization cache
```

### Configuration Structure

```ini
[General]
CurrentLayer=1
AnnotationMode=Wide              # or "Narrow"
LastSaved=20250929120000

[Canvas]
WideCanvasLeft=0
WideCanvasTop=0
WideCanvasRight=1920
WideCanvasBottom=1080
NarrowCanvasLeft=240
NarrowCanvasTop=0
NarrowCanvasRight=1680
NarrowCanvasBottom=1080

[Hotkeys]
RecordToggle=F9
Submit=NumpadEnter
DirectClear=+Enter
Emergency=RCtrl
BreakMode=^b
Stats=F12
ProfileActive=1                   # Enable WASD hotkeys

[Layers]
TotalLayers=5
Layer1Name=Primary
Layer2Name=Secondary
Layer3Name=Tertiary
Layer4Name=Quaternary
Layer5Name=Quinary

[AutoExecution]
Num5_Enabled=1
Num5_Interval=2000               # 2 seconds
Num5_MaxCount=0                  # Infinite loop
```

### Quick Save/Load Slots

The application provides 3 quick-access configuration slots:

1. **Save to Slot**: Settings → Quick Save Slots → Save Slot [1-3]
2. **Load from Slot**: Settings → Quick Save Slots → Load Slot [1-3]
3. **Use Case**: Quickly switch between different labeling setups

## 🔌 Real-Time System Architecture

### Components

```
┌─────────────────────────────────────────────────────────┐
│  AHK Macro System (MacroLauncherX46.ahk)                │
│  • Records user interactions                            │
│  • HTTP POST to ingestion service                       │
│  • Automatic CSV fallback                               │
└──────────────────────┬──────────────────────────────────┘
                       │ HTTP POST
                       ▼
┌─────────────────────────────────────────────────────────┐
│  Data Ingestion Service (Port 5001)                     │
│  • Flask HTTP API                                        │
│  • Data validation & storage                            │
│  • Metrics calculation                                  │
└──────────────────────┬──────────────────────────────────┘
                       │ Write
                       ▼
┌─────────────────────────────────────────────────────────┐
│  SQLite Database (macromaster_realtime.db)              │
│  • ACID-compliant storage                               │
│  • WAL mode for concurrent access                       │
│  • Automatic backups                                    │
└──────────────────────┬──────────────────────────────────┘
                       │ Read
                       ▼
┌─────────────────────────────────────────────────────────┐
│  Real-Time Dashboard (Port 5002)                        │
│  • Flask-SocketIO WebSocket server                      │
│  • Live metric updates                                  │
│  • Interactive charts                                   │
└─────────────────────────────────────────────────────────┘
```

### API Endpoints

#### Data Ingestion Service (Port 5001)

**POST `/ingest/interaction`** - Record user interaction
```json
{
  "session_id": "sess_20250929_143022",
  "interaction_type": "macro_execution",
  "button_key": "Num5",
  "execution_time_ms": 1250,
  "total_boxes": 5,
  "degradation_assignments": "smudge,glare",
  "degradation_counts": {"smudge": 1, "glare": 1}
}
```

**POST `/session/start`** - Initialize new session
```json
{
  "session_id": "sess_20250929_143022",
  "username": "john_doe",
  "canvas_mode": "Wide"
}
```

**GET `/metrics/{session_id}`** - Get real-time metrics

**GET `/interactions/{session_id}?limit=100`** - Get recent interactions

**GET `/health`** - Service health check

#### Dashboard WebSocket Events

**Client → Server:**
- `join_session`: Subscribe to session updates
- `leave_session`: Unsubscribe from updates
- `request_update`: Force data refresh

**Server → Client:**
- `initial_data`: Complete dashboard data on join
- `realtime_update`: Incremental updates during session
- `error`: Error notifications with details

### Database Schema

**sessions table:**
```sql
session_id TEXT PRIMARY KEY
username TEXT
start_time TEXT
end_time TEXT
canvas_mode TEXT
total_executions INTEGER
total_boxes INTEGER
```

**interactions table:**
```sql
id INTEGER PRIMARY KEY AUTOINCREMENT
session_id TEXT
timestamp TEXT
interaction_type TEXT
button_key TEXT
execution_time_ms INTEGER
total_boxes INTEGER
degradation_assignments TEXT
degradation_counts TEXT (JSON)
```

**metrics_cache table:**
```sql
session_id TEXT PRIMARY KEY
cached_at TEXT
metrics_json TEXT
```

## 🧪 Testing

### Automated Tests

```bash
# Test statistics integration
"C:\Program Files\AutoHotkey\v2\AutoHotkey.exe" tests/test_stats_integration.ahk

# Test JSON tracking system
"C:\Program Files\AutoHotkey\v2\AutoHotkey.exe" tests/test_json_tracking.ahk
```

### Manual Testing Workflow

1. **Start Real-Time Services** (if using real-time mode)
   ```bash
   cd dashboard
   run_realtime_system.bat
   ```

2. **Launch Application**
   ```bash
   "C:\Program Files\AutoHotkey\v2\AutoHotkey.exe" src/MacroLauncherX46.ahk
   ```

3. **Open Dashboard**
   - Navigate to http://localhost:5002
   - Enter session ID from AHK status bar

4. **Perform Test Actions**
   - Record a macro (F9)
   - Execute macro (Numpad or WASD)
   - Switch layers (NumpadDiv/NumpadSub)
   - Toggle break mode (Ctrl+B)

5. **Verify Results**
   - Check live dashboard updates
   - Review CSV data in `data/master_stats.csv`
   - Inspect database: `data/macromaster_realtime.db`

### Health Checks

```bash
# Check ingestion service
curl http://localhost:5001/health

# Check dashboard service  
curl http://localhost:5002/health

# Verify database exists
dir "%USERPROFILE%\Documents\MacroMaster\data\macromaster_realtime.db"
```

## 🎨 Degradation Types & Color Scheme

### Supported Degradation Categories

| ID | Type | Color | Use Case |
|----|------|-------|----------|
| 1 | Smudge | 🟠 Orange Red | Dirt, fingerprints |
| 2 | Glare | 🟡 Gold | Reflections, bright spots |
| 3 | Splashes | 🟣 Blue Violet | Water drops, liquid |
| 4 | Partial Blockage | 🟢 Lime Green | Partial obstruction |
| 5 | Full Blockage | 🔴 Dark Red | Complete obstruction |
| 6 | Light Flare | 🔴 Deep Pink | Lens flare, light artifacts |
| 7 | Rain | 🟤 Dark Goldenrod | Rain drops, wet conditions |
| 8 | Haze | 🟢 Dark Olive Green | Fog, atmospheric haze |
| 9 | Snow | 🟢 Spring Green | Snow, ice particles |

### Dashboard Color Coordination

- 🔵 **Blue (#3498db)**: Macro executions
- 🔴 **Red (#e74c3c)**: JSON profile executions
- 🎨 **Degradation Colors**: Matched to types above

## 🚨 Troubleshooting

### Application Won't Start

**Check AutoHotkey Version:**
```bash
"C:\Program Files\AutoHotkey\v2\AutoHotkey.exe" --version
# Should be v2.0 or higher
```

**Verify File Permissions:**
- Ensure Documents folder is writable
- Check antivirus exclusions for MacroMaster folder

### Real-Time Services Issues

**Services Won't Start:**
- Verify Python installation: `python --version`
- Check ports 5001/5002 are available
- Review firewall settings
- Check Windows Defender

**No Live Updates:**
- Verify WebSocket connection in browser DevTools (F12)
- Check AHK status bar for "Real-time service unavailable"
- Review service logs in command windows
- Test with health check endpoints

**Database Errors:**
- Check file permissions on Documents folder
- Verify SQLite installation: `python -c "import sqlite3"`
- Use database backup recovery

### Macro Execution Problems

**Macros Not Recording:**
- Ensure F9 is pressed (🔴 indicator should appear)
- Check hooks are installed (status bar shows "Recording...")
- Verify no conflicting applications are blocking input

**Macros Not Playing Back:**
- Confirm macro is assigned (button shows thumbnail)
- Check browser window is focused
- Verify canvas calibration is correct

**Thumbnails Not Showing:**
- Ensure GDI+ initialized successfully
- Check thumbnail directory permissions
- Try clearing thumbnail cache (delete thumbnails folder)

### Canvas Calibration Issues

**Bounding Boxes Misaligned:**
- Re-run canvas calibration wizard
- Verify correct aspect ratio mode (Wide vs Narrow)
- Check monitor scaling settings in Windows

**Canvas Not Detected:**
- Manually define canvas area in settings
- Ensure coordinates match your monitor resolution
- Test with default canvas settings first

## 📊 CSV Data Structure

### master_stats.csv Schema

```csv
timestamp,session_id,username,execution_type,button_key,layer,
execution_time_ms,total_boxes,degradation_assignments,severity_level,
canvas_mode,session_active_time_ms,break_mode_active,
smudge_count,glare_count,splashes_count,partial_blockage_count,
full_blockage_count,light_flare_count,rain_count,haze_count,
snow_count,clear_count,annotation_details,execution_success,error_details
```

### Example Data Row

```csv
2025-09-29T14:30:22,sess_20250929_143022,john_doe,macro_execution,
Num5,1,1250,5,"smudge,glare",high,Wide,3600000,0,1,1,0,0,0,0,0,0,0,0,
"Box1: smudge (100,200,300,400); Box2: glare (150,250,350,450)",1,
```

## 🔐 Security & Privacy

### Data Storage
- All data stored locally in user's Documents folder
- No cloud uploads or external connections
- Real-time services run on localhost only

### Network Access
- Services bind to 127.0.0.1 (localhost) only
- No authentication required (single-user system)
- WebSocket connections are local

### Backup Recommendations
- Regular backups of Documents\MacroMaster folder
- Export CSV data periodically for archival
- Database automatic backups enabled (daily)

## 🚀 Performance Optimization

### Memory Management
- HBITMAP caching for visualization
- Automatic thumbnail cleanup
- Database WAL mode for concurrent access
- Chrome memory cleanup every 50 executions

### Speed Enhancements
- Event-driven architecture (no polling)
- Batch database writes
- Cached metrics computation
- Optimized GDI+ rendering

### Resource Usage
- **Typical Memory**: 50-100 MB
- **CPU Usage**: < 5% during recording
- **Disk Space**: ~10 MB per 10,000 executions

## 📈 Roadmap & Future Features

### Planned Enhancements
- [ ] Multi-user collaboration features
- [ ] Cloud backup and sync
- [ ] Machine learning for degradation detection
- [ ] Mobile companion app
- [ ] Advanced macro scripting language
- [ ] Plugin system for extensions

### Current Development Focus
- Modular architecture refinement
- Enhanced real-time analytics
- Improved visualization system
- Better error recovery mechanisms

## 🤝 Contributing

This project is designed for internal use and continuous improvement. Key areas for contribution:

1. **Module Development**: Add new functionality as separate modules
2. **Dashboard Enhancements**: Improve analytics visualizations
3. **Testing**: Expand test coverage for edge cases
4. **Documentation**: Keep guides up-to-date

## 📄 License

Internal use only. All rights reserved.

## 📞 Support

For issues or questions:
1. Check troubleshooting section above
2. Review service logs in command windows
3. Test with health check endpoints
4. Consult CLAUDE.md for development guidelines

---

**Version**: V555  
**Last Updated**: 2025-09-29  
**AutoHotkey**: v2.0+  
**Python**: 3.8+  
**Status**: Production Ready with Real-Time Capabilities

*MacroMaster - Intelligent Automation for Data Labeling Workflows*