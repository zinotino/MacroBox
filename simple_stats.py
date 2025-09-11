#!/usr/bin/env python3
"""
Simple stats dashboard that works without external dependencies
"""
import sys
import os
import csv
import webbrowser
from datetime import datetime, timedelta
import json

def create_simple_html_dashboard(csv_path, filter_mode="all"):
    """Create a simple HTML dashboard without external dependencies"""
    
    # Check if CSV exists
    if not os.path.exists(csv_path):
        print(f"CSV file not found: {csv_path}")
        return create_no_data_dashboard()
    
    # Read and parse CSV data
    data = []
    try:
        with open(csv_path, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                data.append(row)
    except Exception as e:
        print(f"Error reading CSV: {e}")
        return create_no_data_dashboard()
    
    # Filter data based on mode
    if filter_mode == "today":
        today = datetime.now().strftime("%Y-%m-%d")
        data = [row for row in data if row.get('timestamp', '').startswith(today)]
    elif filter_mode == "week":
        week_ago = datetime.now() - timedelta(days=7)
        data = [row for row in data if row.get('timestamp', '') >= week_ago.strftime("%Y-%m-%d")]
    
    # Calculate basic stats
    total_executions = len(data)
    total_boxes = sum(int(row.get('total_boxes', 0)) for row in data if row.get('total_boxes', '').isdigit())
    macro_count = len([row for row in data if row.get('execution_type') == 'macro'])
    json_count = len([row for row in data if row.get('execution_type') == 'json_profile'])
    
    # Create HTML dashboard
    html_content = f"""
<!DOCTYPE html>
<html>
<head>
    <title>MacroMaster Analytics Dashboard - {filter_mode.title()}</title>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }}
        .container {{ max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
        .header {{ text-align: center; color: #2c5aa0; margin-bottom: 30px; }}
        .stats-grid {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin-bottom: 30px; }}
        .stat-card {{ background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 20px; border-radius: 10px; text-align: center; }}
        .stat-value {{ font-size: 2em; font-weight: bold; margin-bottom: 5px; }}
        .stat-label {{ opacity: 0.9; }}
        .data-table {{ width: 100%; border-collapse: collapse; margin-top: 20px; }}
        .data-table th, .data-table td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
        .data-table th {{ background-color: #f2f2f2; }}
        .filter-info {{ background: #e3f2fd; padding: 15px; border-radius: 5px; margin-bottom: 20px; }}
        .timestamp {{ color: #666; font-size: 0.9em; text-align: center; margin-top: 20px; }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📊 MacroMaster Analytics Dashboard</h1>
            <h2>{filter_mode.title()} View</h2>
        </div>
        
        <div class="filter-info">
            <strong>Filter Mode:</strong> {filter_mode.title()} | 
            <strong>Data Points:</strong> {total_executions} | 
            <strong>Generated:</strong> {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}
        </div>
        
        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-value">{total_executions}</div>
                <div class="stat-label">Total Executions</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">{total_boxes}</div>
                <div class="stat-label">Total Boxes</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">{macro_count}</div>
                <div class="stat-label">Macro Executions</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">{json_count}</div>
                <div class="stat-label">JSON Profiles</div>
            </div>
        </div>
        
        <h3>📋 Recent Activity</h3>
        <table class="data-table">
            <thead>
                <tr>
                    <th>Timestamp</th>
                    <th>Type</th>
                    <th>Button</th>
                    <th>Layer</th>
                    <th>Boxes</th>
                    <th>Execution Time</th>
                </tr>
            </thead>
            <tbody>
    """
    
    # Add recent data rows (last 10)
    recent_data = data[-10:] if data else []
    for row in reversed(recent_data):
        timestamp = row.get('timestamp', 'N/A')[:19]  # Truncate to datetime
        exec_type = row.get('execution_type', 'N/A')
        button = row.get('button_key', 'N/A')
        layer = row.get('layer', 'N/A')
        boxes = row.get('total_boxes', '0')
        exec_time = row.get('execution_time_ms', '0')
        
        html_content += f"""
                <tr>
                    <td>{timestamp}</td>
                    <td>{exec_type}</td>
                    <td>{button}</td>
                    <td>{layer}</td>
                    <td>{boxes}</td>
                    <td>{exec_time}ms</td>
                </tr>
        """
    
    html_content += f"""
            </tbody>
        </table>
        
        <div class="timestamp">
            Dashboard generated with MacroMaster Analytics | 
            <a href="#" onclick="location.reload()">🔄 Refresh</a>
        </div>
    </div>
</body>
</html>
    """
    
    # Save and open dashboard
    dashboard_file = f"stats_dashboard_{filter_mode}.html"
    try:
        with open(dashboard_file, 'w', encoding='utf-8') as f:
            f.write(html_content)
        
        # Open in browser
        webbrowser.open(f"file://{os.path.abspath(dashboard_file)}")
        print(f"Dashboard opened: {dashboard_file}")
        
        # Save summary for AutoHotkey
        summary = {
            "filter_mode": filter_mode,
            "total_executions": total_executions,
            "total_boxes": total_boxes,
            "macro_executions": macro_count,
            "json_executions": json_count,
            "generated_at": datetime.now().isoformat()
        }
        
        with open(f"metrics_summary_{filter_mode}.json", 'w') as f:
            json.dump(summary, f, indent=2)
            
    except Exception as e:
        print(f"Error creating dashboard: {e}")

def create_no_data_dashboard():
    """Create dashboard when no data is available"""
    html_content = """
<!DOCTYPE html>
<html>
<head>
    <title>MacroMaster Analytics - No Data</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; text-align: center; }
        .container { max-width: 600px; margin: 100px auto; background: white; padding: 40px; border-radius: 10px; }
        .icon { font-size: 4em; margin-bottom: 20px; }
    </style>
</head>
<body>
    <div class="container">
        <div class="icon">📊</div>
        <h1>MacroMaster Analytics</h1>
        <p>No data available yet. Start using MacroMaster to generate analytics!</p>
        <p>CSV data will be created automatically as you use the application.</p>
    </div>
</body>
</html>
    """
    
    dashboard_file = "stats_dashboard_no_data.html"
    with open(dashboard_file, 'w', encoding='utf-8') as f:
        f.write(html_content)
    
    webbrowser.open(f"file://{os.path.abspath(dashboard_file)}")
    print(f"No data dashboard opened: {dashboard_file}")

def main():
    if len(sys.argv) < 2:
        print("Usage: python simple_stats.py <csv_path> [--filter <mode>]")
        sys.exit(1)
    
    csv_path = sys.argv[1]
    filter_mode = "all"
    
    # Parse filter argument
    if "--filter" in sys.argv:
        try:
            filter_idx = sys.argv.index("--filter")
            if filter_idx + 1 < len(sys.argv):
                filter_mode = sys.argv[filter_idx + 1]
        except:
            pass
    
    print(f"Creating dashboard for {csv_path} with filter: {filter_mode}")
    create_simple_html_dashboard(csv_path, filter_mode)

if __name__ == "__main__":
    main()