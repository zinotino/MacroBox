# MacroMaster V555

A comprehensive AutoHotkey v2.0 macro recording and playback system designed for offline data labeling workflows with advanced analytics dashboard.

## 📁 Project Structure

```
MacroMasterV555/
├── src/                      # Main application source code
│   └── MacroLauncherX45.ahk    # Main AutoHotkey application (~4,800 lines)
├── analytics/                # Data analytics and visualization
│   ├── macromaster_optimized.py    # Python dashboard generator
│   ├── install_chart_dependencies.py    # Dependency installer
│   └── requirements.txt            # Python dependencies
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
├── output/                   # Generated output files
│   ├── macromaster_optimized_*.html    # Dashboard HTML files
│   └── macromaster_optimized_*.json    # Metrics JSON files
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
# Navigate to analytics directory
cd analytics

# Generate dashboard for all data
python macromaster_optimized.py ../data/master_stats.csv --filter all

# Generate dashboard for today's data only
python macromaster_optimized.py ../data/master_stats.csv --filter today
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
- **analytics/**: Data visualization and reporting
- **tests/**: Quality assurance and validation
- **config/**: System configuration management
- **docs/**: Project documentation and guidelines

### Key Integration Points
- AutoHotkey script references Python analytics via relative path
- CSV data stored in user Documents directory structure
- Dashboard output generated in project output directory
- Configuration files support both simple and advanced setups

## 📈 Analytics Dashboard

The dashboard provides comprehensive workflow analysis with:

### Chart Types by Category
- **Timeline & Distribution**: Execution timeline, execution types, boxes distribution
- **Performance & Analysis**: Execution speed, button performance, hourly activity
- **Degradation Analysis**: Combined degradations, macro degradations, JSON degradations
- **Summary Tables**: Session metrics, workflow analysis, performance insights

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