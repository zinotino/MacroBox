# Python Stats Pivot - Strategic Solution

## Strategic Decision: Python Stats System

**Why This Makes Sense:**
- ✅ **Escape AutoHotkey GUI limitations** (sizing, layout, display issues)
- ✅ **Professional data visualization** with Plotly/Pandas
- ✅ **Interactive timeline filtering** built-in
- ✅ **Better data analysis** capabilities
- ✅ **Future-proof** expandable system

---

## PHASE 1: Python Stats System Implementation

### PROMPT 1: Python Stats Dashboard - Complete Replacement
```
PYTHON STATS SYSTEM: Replace AutoHotkey stats with professional Python/Plotly dashboard.

STRATEGIC GOAL: Eliminate all AutoHotkey stats display issues by using proper data visualization tools.

IMPLEMENTATION: Complete Python stats system with CSV integration

```python
# stats_dashboard.py - Professional Data Analytics Dashboard
import pandas as pd
import plotly.graph_objects as go
import plotly.express as px
from plotly.subplots import make_subplots
import sys
import os
from datetime import datetime, timedelta
import argparse

class MacroMasterAnalytics:
    def __init__(self, csv_path):
        self.csv_path = csv_path
        self.df = self.load_and_clean_data()
        
    def load_and_clean_data(self):
        """Load CSV data with proper parsing and cleaning"""
        try:
            # Read CSV with proper handling
            df = pd.read_csv(self.csv_path, parse_dates=['timestamp'])
            
            # Clean and standardize data
            df['execution_time_ms'] = pd.to_numeric(df['execution_time_ms'], errors='coerce')
            df['total_boxes'] = pd.to_numeric(df['total_boxes'], errors='coerce')
            df['layer'] = pd.to_numeric(df['layer'], errors='coerce')
            
            # Add derived columns
            df['date'] = df['timestamp'].dt.date
            df['hour'] = df['timestamp'].dt.hour
            df['execution_time_s'] = df['execution_time_ms'] / 1000
            
            return df
            
        except Exception as e:
            print(f"Error loading data: {e}")
            return pd.DataFrame()
    
    def filter_data(self, filter_mode="all", days_back=None):
        """Smart data filtering with multiple modes"""
        if self.df.empty:
            return self.df
            
        if filter_mode == "today":
            today = datetime.now().date()
            return self.df[self.df['date'] == today]
        elif filter_mode == "session":
            # Last 8 hours as "session"
            cutoff = datetime.now() - timedelta(hours=8)
            return self.df[self.df['timestamp'] >= cutoff]
        elif filter_mode == "week":
            cutoff = datetime.now() - timedelta(days=7)
            return self.df[self.df['timestamp'] >= cutoff]
        elif days_back:
            cutoff = datetime.now() - timedelta(days=days_back)
            return self.df[self.df['timestamp'] >= cutoff]
        else:
            return self.df
    
    def create_dashboard(self, filter_mode="all"):
        """Create comprehensive interactive dashboard"""
        
        # Filter data based on mode
        df_filtered = self.filter_data(filter_mode)
        
        if df_filtered.empty:
            self.create_empty_dashboard()
            return
        
        # Create subplots with specific layout
        fig = make_subplots(
            rows=4, cols=2,
            subplot_titles=[
                'Executions Timeline', 'Execution Type Breakdown',
                'Boxes per Hour Trend', 'JSON Degradation Profile',
                'Layer Usage Distribution', 'Daily Performance',
                'Session Activity Heatmap', 'Performance Metrics'
            ],
            specs=[
                [{"secondary_y": True}, {"type": "pie"}],
                [{"secondary_y": True}, {"type": "bar"}],
                [{"type": "bar"}, {"type": "scatter"}],
                [{"type": "heatmap"}, {"type": "table"}]
            ],
            vertical_spacing=0.08,
            horizontal_spacing=0.1
        )
        
        # 1. EXECUTIONS TIMELINE (with boxes overlay)
        self.add_timeline_chart(fig, df_filtered, row=1, col=1)
        
        # 2. EXECUTION TYPE BREAKDOWN
        self.add_execution_breakdown(fig, df_filtered, row=1, col=2)
        
        # 3. BOXES PER HOUR TREND
        self.add_boxes_trend(fig, df_filtered, row=2, col=1)
        
        # 4. JSON DEGRADATION PROFILE (FIXED DISPLAY)
        self.add_json_degradation_analysis(fig, df_filtered, row=2, col=2)
        
        # 5. LAYER USAGE DISTRIBUTION
        self.add_layer_usage(fig, df_filtered, row=3, col=1)
        
        # 6. DAILY PERFORMANCE
        self.add_daily_performance(fig, df_filtered, row=3, col=2)
        
        # 7. SESSION ACTIVITY HEATMAP
        self.add_activity_heatmap(fig, df_filtered, row=4, col=1)
        
        # 8. PERFORMANCE METRICS TABLE
        self.add_metrics_table(fig, df_filtered, row=4, col=2)
        
        # Enhanced layout with timeline controls
        fig.update_layout(
            title=f"MacroMaster Analytics Dashboard - {filter_mode.title()} View",
            showlegend=True,
            height=1200,
            template="plotly_white",
            # Timeline range selector
            xaxis=dict(
                rangeselector=dict(
                    buttons=list([
                        dict(count=1, label="1H", step="hour", stepmode="backward"),
                        dict(count=8, label="8H", step="hour", stepmode="backward"),
                        dict(count=1, label="1D", step="day", stepmode="backward"),
                        dict(count=7, label="7D", step="day", stepmode="backward"),
                        dict(step="all", label="All")
                    ])
                ),
                rangeslider=dict(visible=True),
                type="date"
            )
        )
        
        # Save and display
        output_file = f"stats_dashboard_{filter_mode}.html"
        fig.write_html(output_file, auto_open=True)
        print(f"Dashboard saved as: {output_file}")
        
        # Also save key metrics as JSON for AutoHotkey integration
        self.save_summary_metrics(df_filtered, filter_mode)
    
    def add_json_degradation_analysis(self, fig, df, row, col):
        """FIXED: JSON degradation profile analysis"""
        
        # Filter JSON profile executions
        json_df = df[df['execution_type'] == 'json_profile'].copy()
        
        if json_df.empty:
            # Show "No Data" message
            fig.add_annotation(
                text="No JSON Profile Data",
                xref="x", yref="y",
                x=0.5, y=0.5,
                showarrow=False,
                row=row, col=col
            )
            return
        
        # Parse JSON degradation data properly
        degradation_counts = {}
        severity_counts = {"high": 0, "medium": 0, "low": 0}
        
        for _, record in json_df.iterrows():
            # Parse degradation type (column 31)
            if pd.notna(record.get('json_degradation_type_breakdown')):
                deg_type = str(record['json_degradation_type_breakdown']).strip()
                degradation_counts[deg_type] = degradation_counts.get(deg_type, 0) + 1
            
            # Parse severity (column 30)
            if pd.notna(record.get('json_severity_breakdown_by_level')):
                severity = str(record['json_severity_breakdown_by_level']).strip()
                if severity in severity_counts:
                    severity_counts[severity] += 1
        
        # Create degradation breakdown chart
        if degradation_counts:
            deg_types = list(degradation_counts.keys())
            deg_values = list(degradation_counts.values())
            
            fig.add_trace(
                go.Bar(
                    x=deg_types,
                    y=deg_values,
                    name="Degradation Types",
                    marker_color='lightblue'
                ),
                row=row, col=col
            )
        
        fig.update_xaxes(title_text="Degradation Type", row=row, col=col)
        fig.update_yaxes(title_text="Count", row=row, col=col)
    
    def save_summary_metrics(self, df, filter_mode):
        """Save key metrics for AutoHotkey integration"""
        try:
            # Calculate key metrics
            total_executions = len(df)
            total_boxes = df['total_boxes'].sum()
            avg_execution_time = df['execution_time_ms'].mean()
            
            # Execution type breakdown
            macro_count = len(df[df['execution_type'] == 'macro'])
            json_count = len(df[df['execution_type'] == 'json_profile'])
            
            # Time-based metrics
            if not df.empty:
                time_span_hours = (df['timestamp'].max() - df['timestamp'].min()).total_seconds() / 3600
                boxes_per_hour = total_boxes / time_span_hours if time_span_hours > 0 else 0
                exec_per_hour = total_executions / time_span_hours if time_span_hours > 0 else 0
            else:
                boxes_per_hour = 0
                exec_per_hour = 0
            
            metrics = {
                "filter_mode": filter_mode,
                "total_executions": int(total_executions),
                "macro_executions": int(macro_count),
                "json_executions": int(json_count),
                "total_boxes": int(total_boxes),
                "avg_execution_time_ms": round(avg_execution_time, 1) if pd.notna(avg_execution_time) else 0,
                "boxes_per_hour": round(boxes_per_hour, 1),
                "executions_per_hour": round(exec_per_hour, 1),
                "generated_at": datetime.now().isoformat()
            }
            
            # Save as JSON for AutoHotkey to read
            import json
            with open(f"metrics_summary_{filter_mode}.json", 'w') as f:
                json.dump(metrics, f, indent=2)
                
        except Exception as e:
            print(f"Error saving metrics: {e}")

def main():
    parser = argparse.ArgumentParser(description='MacroMaster Analytics Dashboard')
    parser.add_argument('csv_path', help='Path to the CSV data file')
    parser.add_argument('--filter', choices=['all', 'today', 'session', 'week'], 
                       default='all', help='Data filter mode')
    parser.add_argument('--days', type=int, help='Filter to last N days')
    
    args = parser.parse_args()
    
    if not os.path.exists(args.csv_path):
        print(f"Error: CSV file not found: {args.csv_path}")
        return
    
    # Create analytics dashboard
    analytics = MacroMasterAnalytics(args.csv_path)
    analytics.create_dashboard(args.filter)

if __name__ == "__main__":
    main()
```

```ahk
; AutoHotkey Integration - Replace ShowStats() function
ShowPythonStats() {
    global masterStatsCSV, dailyResetActive
    
    ; Determine filter mode based on daily reset state
    filterMode := dailyResetActive ? "today" : "all"
    
    ; Python command
    pythonScript := A_ScriptDir . "\stats_dashboard.py"
    pythonCmd := 'python "' . pythonScript . '" "' . masterStatsCSV . '" --filter ' . filterMode
    
    try {
        ; Show loading message
        UpdateStatus("📊 Generating analytics dashboard...")
        
        ; Run Python dashboard (non-blocking)
        Run(pythonCmd, A_ScriptDir)
        
        ; Update status
        UpdateStatus("📊 Analytics dashboard opened in browser")
        
    } catch Error as e {
        MsgBox("Python analytics failed: " . e.Message . "`n`nEnsure Python and required packages are installed:`npip install pandas plotly", "Error", "Icon!")
        UpdateStatus("❌ Python analytics failed - check installation")
    }
}

; Replace all ShowStats() calls with ShowPythonStats()
; Update hotkey: hotkeyStats -> ShowPythonStats()
```

PYTHON SYSTEM BENEFITS:
- ✅ **Escape AutoHotkey GUI limitations completely**
- ✅ **Professional interactive visualizations**
- ✅ **Timeline filtering built-in** (1H, 8H, 1D, 7D, All)
- ✅ **JSON degradation analysis FIXED** with proper parsing
- ✅ **Expandable** for future analytics needs
- ✅ **Export capabilities** (HTML, PNG, PDF)

Please implement this Python stats replacement system.
```

---

## PHASE 2: Daily Reset Workflow Improvement

### PROMPT 2: Intuitive Daily Reset Workflow
```
DAILY RESET WORKFLOW: Make daily reset more intuitive and user-friendly.

CURRENT ISSUES: 
- Confusing daily reset vs all-time modes
- Users don't understand what daily reset does
- Workflow not intuitive for daily labeling work

IMPROVED WORKFLOW:

```ahk
ShowIntuitiveDailyResetDialog() {
    ; CLEAR, USER-FRIENDLY DAILY RESET
    
    resetGui := Gui("+AlwaysOnTop", "📅 Daily Reset - Start Fresh Day")
    resetGui.SetFont("s11")
    
    ; Clear explanation
    resetGui.Add("Text", "x20 y20 w400 h40", "📅 DAILY RESET - START A FRESH DAY")
        .SetFont("s14 Bold", "cBlue")
    
    resetGui.Add("Text", "x20 y70 w400 h60", 
                 "This will start fresh daily tracking while preserving all your historical data.`n`n" .
                 "✅ Resets today's timing and JSON degradation counts`n" .
                 "✅ Keeps all your recorded macros and historical stats")
    
    ; Current day summary
    currentStats := GetTodayStats()
    resetGui.Add("Text", "x20 y140 w400 h20", "📊 Today's Progress:")
        .SetFont("s11 Bold")
    
    resetGui.Add("Text", "x30 y165 w400 h60", 
                 "• Executions: " . currentStats.executions . "`n" .
                 "• Boxes: " . currentStats.boxes . "`n" .
                 "• Time Active: " . currentStats.activeTime . "`n" .
                 "• JSON Degradations: " . currentStats.jsonDegradations)
    
    ; Clear action buttons
    btnReset := resetGui.Add("Button", "x30 y240 w140 h35", "📅 Start Fresh Day")
    btnReset.SetFont("s11 Bold")
    btnReset.OnEvent("Click", (*) => ConfirmDailyReset(resetGui))
    
    btnCancel := resetGui.Add("Button", "x190 y240 w100 h35", "Cancel")
    btnCancel.OnEvent("Click", (*) => resetGui.Destroy())
    
    btnViewHistory := resetGui.Add("Button", "x310 y240 w110 h35", "📊 View History")
    btnViewHistory.OnEvent("Click", (*) => ViewHistoricalStats())
    
    resetGui.Show("w440 h295")
}

ConfirmDailyReset(parentGui) {
    parentGui.Destroy()
    
    ; Simple confirmation
    result := MsgBox("Start a fresh daily session?`n`nYour historical data will be preserved.", "Confirm Daily Reset", "YesNo Icon!")
    
    if (result = "Yes") {
        PerformIntuitiveDailyReset()
    }
}

PerformIntuitiveDailyReset() {
    global applicationStartTime, totalActiveTime, lastActiveTime, sessionId, dailyResetActive
    
    try {
        ; Mark day boundary in CSV
        MarkDayBoundary()
        
        ; Reset daily tracking
        applicationStartTime := A_TickCount
        totalActiveTime := 0
        lastActiveTime := A_TickCount
        dailyResetActive := true
        
        ; Create new session ID
        sessionId := "day_" . FormatTime(, "yyyyMMdd_HHmmss")
        
        ; Success feedback
        UpdateStatus("📅 Fresh daily session started - Previous data preserved")
        
        ; Show today's fresh stats
        ShowPythonStats()  ; Will automatically show "today" filter
        
    } catch Error as e {
        MsgBox("Daily reset failed: " . e.Message, "Error", "Icon!")
    }
}

; Helper function to get today's stats for display
GetTodayStats() {
    ; Read today's data from CSV for summary display
    return {
        executions: GetTodayExecutionCount(),
        boxes: GetTodayBoxCount(), 
        activeTime: FormatActiveTime(GetTodayActiveTime()),
        jsonDegradations: GetTodayJSONDegradationCount()
    }
}
```

INTUITIVE WORKFLOW BENEFITS:
- ✅ **Clear explanation** of what daily reset does
- ✅ **Progress summary** before reset
- ✅ **Obvious button labels** ("Start Fresh Day")
- ✅ **Historical data access** (View History button)
- ✅ **Automatic stats display** after reset

Please implement this intuitive daily reset workflow.
```

---

## PHASE 3: Unified Menu Sizing & Cleanup

### PROMPT 3: Unified Menu Sizing & Remove Efficiency Score
```
UNIFIED MENU SIZING: Both config and stats menus same size, efficient space usage.

ALSO: Remove efficiency score from context menu (worthless).

UNIFIED DESIGN:

```ahk
; STANDARD MENU DIMENSIONS (both config and stats)
global standardMenuWidth := 900
global standardMenuHeight := 650

CreateStandardMenuBase(title, icon := "⚙️") {
    ; Standard menu foundation for consistency
    gui := Gui("+Resize", icon . " " . title)
    gui.SetFont("s11")
    
    ; Standard header
    gui.Add("Text", "x20 y15 w860 h30 Center", icon . " " . StrUpper(title))
        .SetFont("s14 Bold", "cNavy")
    
    ; Standard content area
    contentY := 55
    contentHeight := standardMenuHeight - 100  ; Leave space for footer
    
    return {gui: gui, contentY: contentY, contentHeight: contentHeight}
}

ShowConfigStandardSize() {
    ; CONFIG MENU - Standard size with efficient layout
    menuBase := CreateStandardMenuBase("MACROMASTER CONFIGURATION")
    configGui := menuBase.gui
    
    ; Efficient tab layout
    tabs := configGui.Add("Tab3", "x20 y" . menuBase.contentY . " w860 h" . menuBase.contentHeight, 
                          ["🎮 Hotkeys", "🎯 Canvas & Performance"])
    
    ; TAB 1: Compact hotkey interface
    tabs.UseTab(1)
    CreateEfficientHotkeyInterface(configGui, menuBase.contentY + 35)
    
    ; TAB 2: Canvas and performance settings
    tabs.UseTab(2)
    CreateEfficientCanvasSettings(configGui, menuBase.contentY + 35)
    
    ; Standard footer
    CreateStandardMenuFooter(configGui, "Close")
    
    configGui.Show("w" . standardMenuWidth . " h" . standardMenuHeight)
}

ShowStatsStandardSize() {
    ; STATS MENU - Standard size (Python integration button)
    menuBase := CreateStandardMenuBase("MACROMASTER ANALYTICS", "📊")
    statsGui := menuBase.gui
    
    ; Quick stats overview (compact)
    CreateQuickStatsOverview(statsGui, menuBase.contentY + 10)
    
    ; Python dashboard integration
    CreatePythonDashboardSection(statsGui, menuBase.contentY + 200)
    
    ; Daily reset controls
    CreateDailyResetControls(statsGui, menuBase.contentY + 350)
    
    ; Standard footer
    CreateStandardMenuFooter(statsGui, "Close")
    
    statsGui.Show("w" . standardMenuWidth . " h" . standardMenuHeight)
}

CreatePythonDashboardSection(gui, y) {
    ; PYTHON INTEGRATION SECTION
    gui.Add("Text", "x40 y" . y . " w800 h25", "📊 ADVANCED ANALYTICS DASHBOARD")
        .SetFont("s12 Bold", "cNavy")
    
    gui.Add("Text", "x60 y" . (y + 35) . " w700 h40", 
            "Launch professional interactive analytics with timeline filtering, degradation analysis, and performance metrics.")
    
    ; Dashboard launch buttons
    btnToday := gui.Add("Button", "x60 y" . (y + 85) . " w150 h35", "📅 Today's Dashboard")
    btnToday.SetFont("s10 Bold")
    btnToday.OnEvent("Click", (*) => LaunchPythonDashboard("today"))
    
    btnAllTime := gui.Add("Button", "x230 y" . (y + 85) . " w150 h35", "📊 All-Time Dashboard")
    btnAllTime.SetFont("s10 Bold")
    btnAllTime.OnEvent("Click", (*) => LaunchPythonDashboard("all"))
    
    btnWeek := gui.Add("Button", "x400 y" . (y + 85) . " w150 h35", "📈 Weekly Analysis")
    btnWeek.SetFont("s10 Bold")
    btnWeek.OnEvent("Click", (*) => LaunchPythonDashboard("week"))
}

; REMOVE EFFICIENCY SCORE FROM CONTEXT MENU
ShowContextMenuCleaned(buttonName, *) {
    global currentLayer, degradationTypes, severityLevels
    
    contextMenu := Menu()
    
    contextMenu.Add("🎥 Record Macro", (*) => F9_RecordingOnly())
    contextMenu.Add("🗑️ Clear Macro", (*) => ClearMacro(buttonName))
    contextMenu.Add("🏷️ Edit Label", (*) => EditCustomLabel(buttonName))
    contextMenu.Add()
    
    ; JSON Profiles
    jsonMainMenu := Menu()
    for id, typeName in degradationTypes {
        typeMenu := Menu()
        for severity in severityLevels {
            presetName := StrTitle(typeName) . " (" . StrTitle(severity) . ")"
            typeMenu.Add(StrTitle(severity), AssignJsonAnnotation.Bind(buttonName, presetName))
        }
        jsonMainMenu.Add("🎨 " . StrTitle(typeName), typeMenu)
    }
    contextMenu.Add("🏷️ JSON Profiles", jsonMainMenu)
    contextMenu.Add()
    
    ; Thumbnails
    contextMenu.Add("🖼️ Add Thumbnail", (*) => AddThumbnail(buttonName))
    contextMenu.Add("🗑️ Remove Thumbnail", (*) => RemoveThumbnail(buttonName))
    contextMenu.Add()
    
    ; Auto execution
    buttonKey := "L" . currentLayer . "_" . buttonName
    hasAutoSettings := buttonAutoSettings.Has(buttonKey)
    autoEnabled := hasAutoSettings && buttonAutoSettings[buttonKey].enabled
    
    if (autoEnabled) {
        contextMenu.Add("✅ Auto Mode: ON", (*) => {})
        contextMenu.Add("❌ Disable Auto Mode", (*) => ToggleAutoEnable(buttonName))
    } else {
        contextMenu.Add("⚙️ Enable Auto Mode", (*) => ToggleAutoEnable(buttonName))
    }
    contextMenu.Add("🔧 Auto Mode: Settings", (*) => ConfigureAutoMode(buttonName))
    
    ; REMOVED: Efficiency score (worthless)
    ; REMOVED: Other redundant options
    
    contextMenu.Show()
}
```

UNIFIED SIZING BENEFITS:
- ✅ **Consistent 900x650 size** for both menus
- ✅ **Efficient space usage** with proper layouts
- ✅ **Python integration** prominently featured
- ✅ **Cleaned context menu** (removed worthless efficiency score)

Please implement unified menu sizing and context menu cleanup.
```

---

## Implementation Priority Tonight

### **Phase 1: Python Stats (30 min)**
```bash
claude-code --file MacroLauncherX45.txt --prompt "Use Prompt 1 above"
```

### **Phase 2: Daily Reset UX (15 min)**  
```bash
claude-code --file MacroLauncherX45.txt --prompt "Use Prompt 2 above"
```

### **Phase 3: Menu Sizing (10 min)**
```bash
claude-code --file MacroLauncherX45.txt --prompt "Use Prompt 3 above"
```

## Strategic Benefits

### **Python Stats System:**
- ✅ **Escape AutoHotkey limitations** forever
- ✅ **Professional visualizations** with timeline filtering
- ✅ **JSON degradation analysis FIXED** automatically  
- ✅ **Expandable** for future analytics needs

### **Better User Experience:**
- ✅ **Intuitive daily reset** with clear explanations
- ✅ **Consistent menu sizing** (900x650)
- ✅ **Cleaned context menu** (removed worthless features)

**This approach solves your display issues definitively while providing a much better analytics experience!** 🚀