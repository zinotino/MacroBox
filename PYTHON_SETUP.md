# 📊 MacroMaster Professional Analytics Setup

## 🚀 Professional Plotly Dashboard (RECOMMENDED)

For the full interactive analytics experience with professional visualizations:

### 1. Install Python Dependencies
```bash
pip install pandas plotly
```

### 2. What You Get
- **Interactive Timeline Charts** with zoom/pan/hover
- **Performance Heatmaps** showing activity patterns  
- **JSON Degradation Analysis** with proper parsing
- **Execution Breakdowns** with filtering capabilities
- **Export Options** (PNG, PDF, HTML)
- **Timeline Range Selectors** (1H, 8H, 1D, 7D, All)

### 3. Features
- 📈 **Real-time Data Filtering**: Interactive controls
- 🎨 **Professional Styling**: Publication-ready charts
- 📊 **Advanced Analytics**: Trend analysis, correlations
- 💾 **Export Capabilities**: Share reports easily
- 📱 **Responsive Design**: Works on all screen sizes

---

## 📊 Simple Dashboard (FALLBACK)

If you prefer not to install dependencies, a simple HTML dashboard is available:

### Features
- ✅ Basic statistics display
- ✅ Recent activity tables
- ✅ No external dependencies
- ✅ Always works
- ❌ Limited interactivity

---

## 🎯 How It Works

1. **Press F12** or click Stats button
2. **Automatic Detection**: 
   - Tries professional Plotly dashboard first
   - Falls back to simple dashboard if dependencies missing
   - Shows built-in AutoHotkey stats as final fallback
3. **Always Works**: Guaranteed stats display regardless of setup

---

## 🛠 Installation Check

Test if professional dashboard is available:
```bash
python -c "import pandas, plotly; print('✅ Professional dashboard ready!')"
```

If this fails, install dependencies:
```bash
pip install pandas plotly
```

---

## 📁 Files

- `stats_dashboard.py` - Professional Plotly dashboard
- `simple_stats.py` - Simple HTML fallback dashboard  
- `data/master_stats.csv` - Your analytics data
- `MacroLauncherX45.ahk` - Main application with integrated stats

---

## 🎨 Dashboard Features Comparison

| Feature | Professional | Simple | Built-in |
|---------|-------------|--------|----------|
| Interactive Charts | ✅ | ❌ | ❌ |
| Timeline Filtering | ✅ | ❌ | ❌ |
| Hover Tooltips | ✅ | ❌ | ❌ |
| Export Options | ✅ | ❌ | ❌ |
| Degradation Analysis | ✅ | ✅ | ❌ |
| No Dependencies | ❌ | ✅ | ✅ |
| Always Available | ❌ | ✅ | ✅ |

**Recommendation**: Install pandas/plotly for the best experience! 🚀