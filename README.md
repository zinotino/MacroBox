# MacroMaster V555

A comprehensive AutoHotkey v2.0 macro recording and playback system designed for offline data labeling workflows with advanced analytics dashboard.

## 📁 Project Structure

```
MacroMasterV555/
├── src/                      # Main application source code
│   └── MacroLauncherX45.ahk    # Main AutoHotkey application (~4,800 lines)
├── dashboard/               # Data analytics and visualization
│   ├── timeline_slider_dashboard.py    # Main timeline dashboard generator
│   ├── requirements.txt            # Python dependencies
│   ├── output/                     # Generated dashboard files
│   │   └── macromaster_timeline_slider.html
│   └── metrics/                    # Dashboard metrics storage
│       └── macromaster_timeline_metrics.json
├── tests/                    # Test files
│   ├── test_json_tracking.ahk      # JSON tracking tests
│   └── test_stats_integration.ahk   # Stats system integration tests
├── config/                   # Configuration files
│   ├── config.ini               # Main configuration
│   └── config_simple.txt        # Simple configuration template
├── docs/                     # Documentation
│   └── CLAUDE.md                # Development guidelines and project overview
├── data/                     # Data storage (runtime)
│   └── master_stats.csv         # CSV statistics database
└── thumbnails/              # Button thumbnail storage (runtime)
```

## 🚀 Quick Start

### Running the Application
```bash
# Execute main application with AutoHotkey v2.0
"C:\Program Files\AutoHotkey\v2\AutoHotkey.exe" src/MacroLauncherX45.ahk
```

### Generating Analytics Dashboard
```bash
# Navigate to dashboard directory
cd dashboard

# Generate timeline dashboard (integrated with AHK GUI)
python timeline_slider_dashboard.py ../data/master_stats.csv

# Dashboard automatically opens in browser and saves to output/
```

### Running Tests
```bash
# Test basic functionality
"C:\Program Files\AutoHotkey\v2\AutoHotkey.exe" tests/test_stats_integration.ahk

# Test JSON tracking
"C:\Program Files\AutoHotkey\v2\AutoHotkey.exe" tests/test_json_tracking.ahk
```

## 📊 Features

- **Multi-layer macro organization** (5 layers with 12 buttons each)
- **Real-time bounding box visualization** with degradation tracking
- **CSV-based statistics system** for usage analytics
- **Interactive HTML dashboard** with 9 chart types
- **Unified color scheme** (blue for macros, red for JSON profiles)
- **Break mode functionality** for time management
- **Dual canvas support** (wide/narrow aspect ratios)
- **JSON annotation integration**
- **Automated backup and recovery**

## 🛠️ Development

### File Organization
- **src/**: Core application logic
- **dashboard/**: Data visualization and reporting with timeline controls
- **tests/**: Quality assurance and validation
- **config/**: System configuration management
- **docs/**: Project documentation and guidelines

### Key Integration Points
- AutoHotkey script references Python dashboard via relative path
- CSV data stored in data/ directory for analysis
- Dashboard output generated in dashboard/output/ directory
- Timeline slider integrated directly with AHK GUI system
- Configuration files support both simple and advanced setups

## 📈 Analytics Dashboard

The timeline slider dashboard provides focused workflow analysis with:

### 3x3 Layout with 6 Focused Charts
- **Top Row (Pie Charts)**: Pure macro degradations, degradation combinations, JSON profile executions
- **Middle Row**: Execution timeline with slider controls, execution types distribution, layer usage analysis
- **Bottom Section**: 3 comprehensive raw data tables with session details

### Key Features
- **Timeline Slider**: Interactive time range selection with preset controls
- **Degradation Focus**: Specialized charts for tracking degradation applications and combinations
- **Performance Metrics**: Speed analysis, boxes per hour, peak performance tracking
- **Raw Data Export**: Detailed tables for workplace reporting and analysis

### Color Coordination
- 🔵 **Blue (#3498db)**: Macro executions
- 🔴 **Red (#e74c3c)**: JSON profile executions
- 🎨 **Additional colors**: Context-specific for other chart elements

## 🔧 Configuration

The application uses a hierarchical configuration system:
1. **Documents/MacroMaster/config.ini**: User settings
2. **config/config.ini**: Default configuration template
3. **config/config_simple.txt**: Minimal configuration example

---

*Generated with Claude Code - Last updated: 2025-09-22*