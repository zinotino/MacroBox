#!/usr/bin/env python3
"""
MacroMaster Stats Dashboard Generator
Creates interactive HTML dashboard with timeline filtering
"""

import sqlite3
from pathlib import Path
from datetime import datetime, timedelta
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import plotly.express as px
from collections import Counter
import json
import requests

def get_database_path():
    """Get the database path in Documents/MacroMaster/data"""
    documents_dir = Path.home() / "Documents" / "MacroMaster" / "data"
    return documents_dir / "macromaster_stats.db"

def get_plotly_js():
    """
    Get Plotly.js library content, either from cache or download from CDN.
    This ensures the dashboard works even when CDN is blocked by corporate firewalls.
    """
    plotly_url = "https://cdn.plot.ly/plotly-latest.min.js"
    cache_file = Path.home() / "Documents" / "MacroMaster" / "plotly-latest.min.js"

    # Try to use cached version first
    if cache_file.exists():
        try:
            with open(cache_file, 'r', encoding='utf-8') as f:
                return f.read()
        except:
            pass  # Fall back to download

    # Download from CDN and cache
    try:
        print("Downloading Plotly.js from CDN...")
        response = requests.get(plotly_url, timeout=10)
        response.raise_for_status()
        plotly_js = response.text

        # Cache the downloaded content
        cache_file.parent.mkdir(parents=True, exist_ok=True)
        with open(cache_file, 'w', encoding='utf-8') as f:
            f.write(plotly_js)

        print(f"Plotly.js cached to: {cache_file}")
        return plotly_js

    except Exception as e:
        print(f"Failed to download Plotly.js: {e}")
        # Return a minimal fallback that shows an error message
        return """
        console.error("Failed to load Plotly.js - check internet connection or corporate firewall settings");
        window.Plotly = {
            newPlot: function(divId, data, layout) {
                document.getElementById(divId).innerHTML = '<div style="color: red; padding: 20px; border: 1px solid red; margin: 10px;">Error: Plotly.js library failed to load. Check internet connection or corporate firewall settings.</div>';
            }
        };
        """

def get_time_filter_sql(filter_mode):
    """
    Get SQL WHERE clause for timeline filtering

    Args:
        filter_mode: 'hour', 'today', '7days', '30days', 'all', or custom date range

    Returns:
        SQL WHERE clause string
    """
    if filter_mode == 'all':
        return ""
    elif filter_mode == 'hour':
        return "WHERE timestamp >= datetime('now', '-1 hour')"
    elif filter_mode == 'today':
        return "WHERE date(timestamp) = date('now')"
    elif filter_mode == '7days':
        return "WHERE timestamp >= datetime('now', '-7 days')"
    elif filter_mode == '30days':
        return "WHERE timestamp >= datetime('now', '-30 days')"
    elif isinstance(filter_mode, tuple) and len(filter_mode) == 2:
        # Custom range (start_date, end_date)
        return f"WHERE timestamp BETWEEN '{filter_mode[0]}' AND '{filter_mode[1]}'"
    else:
        return ""

def query_degradation_totals(conn, filter_sql=""):
    """Query total degradation counts"""
    query = f"""
        SELECT
            d.degradation_type,
            SUM(d.count) as total_count
        FROM degradations d
        JOIN executions e ON d.execution_id = e.id
        {filter_sql}
        GROUP BY d.degradation_type
        ORDER BY total_count DESC
    """
    cursor = conn.cursor()
    cursor.execute(query)
    return cursor.fetchall()

def query_degradation_combinations(conn, filter_sql="", limit=10):
    """Query top degradation combinations"""
    query = f"""
        SELECT
            degradation_assignments,
            COUNT(*) as count
        FROM executions
        {filter_sql}
        GROUP BY degradation_assignments
        HAVING degradation_assignments != '' AND degradation_assignments != 'clear'
        ORDER BY count DESC
        LIMIT {limit}
    """
    cursor = conn.cursor()
    cursor.execute(query)
    return cursor.fetchall()

def query_json_profile_degradations(conn, filter_sql=""):
    """Query degradations for JSON profile executions"""
    query = f"""
        SELECT
            d.degradation_type,
            SUM(d.count) as total_count
        FROM degradations d
        JOIN executions e ON d.execution_id = e.id
        {filter_sql.replace('WHERE', 'WHERE e.execution_type = "json_profile" AND' if filter_sql else 'WHERE e.execution_type = "json_profile"')}
        GROUP BY d.degradation_type
        ORDER BY total_count DESC
    """
    cursor = conn.cursor()
    cursor.execute(query)
    return cursor.fetchall()

def query_boxes_over_time(conn, filter_sql="", time_grouping='hour'):
    """Query total boxes over time"""
    time_format = {
        'hour': '%Y-%m-%d %H:00:00',
        'day': '%Y-%m-%d',
        'week': '%Y-W%W',
        'month': '%Y-%m'
    }

    format_str = time_format.get(time_grouping, '%Y-%m-%d %H:00:00')

    query = f"""
        SELECT
            strftime('{format_str}', timestamp) as time_period,
            SUM(total_boxes) as boxes,
            COUNT(*) as executions
        FROM executions
        {filter_sql}
        GROUP BY time_period
        ORDER BY time_period ASC
    """
    cursor = conn.cursor()
    cursor.execute(query)
    return cursor.fetchall()

def query_boxes_per_hour_over_time(conn, filter_sql=""):
    """Query boxes per hour rate over time"""
    query = f"""
        SELECT
            strftime('%Y-%m-%d %H:00:00', timestamp) as hour,
            SUM(total_boxes) as total_boxes,
            MAX(session_active_time_ms) as max_active_time_ms
        FROM executions
        {filter_sql}
        GROUP BY hour
        ORDER BY hour ASC
    """
    cursor = conn.cursor()
    cursor.execute(query)

    # Calculate boxes per hour for each time period
    results = []
    for row in cursor.fetchall():
        hour, boxes, active_time_ms = row
        if active_time_ms and active_time_ms > 0:
            active_hours = active_time_ms / 3600000
            boxes_per_hour = boxes / active_hours if active_hours > 0 else 0
            results.append((hour, boxes_per_hour, boxes))
        else:
            results.append((hour, 0, boxes))

    return results

def query_execution_speeds(conn, filter_sql=""):
    """Query execution speeds by type over time"""
    query = f"""
        SELECT
            strftime('%Y-%m-%d %H:00:00', timestamp) as hour,
            execution_type,
            AVG(execution_time_ms) as avg_speed,
            COUNT(*) as count
        FROM executions
        {filter_sql}
        GROUP BY hour, execution_type
        ORDER BY hour ASC, execution_type
    """
    cursor = conn.cursor()
    cursor.execute(query)
    return cursor.fetchall()

def query_execution_type_performance(conn, filter_sql=""):
    """Query performance stats by execution type"""
    query = f"""
        SELECT
            execution_type,
            COUNT(*) as count,
            AVG(execution_time_ms) as avg_time,
            MIN(execution_time_ms) as min_time,
            MAX(execution_time_ms) as max_time,
            SUM(total_boxes) as total_boxes
        FROM executions
        {filter_sql}
        GROUP BY execution_type
        ORDER BY count DESC
    """
    cursor = conn.cursor()
    cursor.execute(query)
    return cursor.fetchall()

def query_button_usage(conn, filter_sql="", limit=10):
    """Query top buttons by usage"""
    query = f"""
        SELECT
            button_key,
            COUNT(*) as executions,
            SUM(total_boxes) as total_boxes,
            AVG(execution_time_ms) as avg_time
        FROM executions
        {filter_sql}
        GROUP BY button_key
        ORDER BY executions DESC
        LIMIT {limit}
    """
    cursor = conn.cursor()
    cursor.execute(query)
    return cursor.fetchall()

def query_layer_stats(conn, filter_sql=""):
    """Query statistics by layer"""
    query = f"""
        SELECT
            layer,
            COUNT(*) as executions,
            SUM(total_boxes) as total_boxes,
            AVG(execution_time_ms) as avg_time
        FROM executions
        {filter_sql}
        GROUP BY layer
        ORDER BY layer
    """
    cursor = conn.cursor()
    cursor.execute(query)
    return cursor.fetchall()

def query_session_performance(conn, filter_sql="", limit=10):
    """Query top sessions by performance"""
    # Need to extract session data from executions
    query = f"""
        SELECT
            session_id,
            COUNT(*) as executions,
            SUM(total_boxes) as total_boxes,
            MAX(session_active_time_ms) as active_time_ms,
            AVG(execution_time_ms) as avg_exec_time
        FROM executions
        {filter_sql}
        GROUP BY session_id
        ORDER BY total_boxes DESC
        LIMIT {limit}
    """
    cursor = conn.cursor()
    cursor.execute(query)
    return cursor.fetchall()

def query_summary_stats(conn, filter_sql=""):
    """Query summary statistics"""
    query = f"""
        SELECT
            COUNT(*) as total_executions,
            SUM(total_boxes) as total_boxes,
            AVG(execution_time_ms) as avg_execution_time,
            MIN(timestamp) as first_execution,
            MAX(timestamp) as last_execution
        FROM executions
        {filter_sql}
    """
    cursor = conn.cursor()
    cursor.execute(query)
    return cursor.fetchone()

def create_degradation_bar_chart(degradation_data, title="Macro Executions by Degradation"):
    """Create bar chart for degradation totals"""
    if not degradation_data:
        return go.Figure().add_annotation(text="No data available",
                                         xref="paper", yref="paper",
                                         x=0.5, y=0.5, showarrow=False)

    types, counts = zip(*degradation_data)

    # Color mapping for degradations (matching AHK colors)
    color_map = {
        'smudge': '#FF4500',
        'glare': '#FFD700',
        'splashes': '#8A2BE2',
        'partial_blockage': '#00FF32',
        'full_blockage': '#8B0000',
        'light_flare': '#FF1493',
        'rain': '#B8860B',
        'haze': '#556B2F',
        'snow': '#00FF7F',
        'clear': '#CCCCCC'
    }

    colors = [color_map.get(t, '#888888') for t in types]

    fig = go.Figure(data=[
        go.Bar(x=[t.replace('_', ' ').title() for t in types],
               y=list(counts),
               marker_color=colors,
               text=list(counts),
               textposition='auto',
               textfont=dict(size=14, color='white'))
    ])

    fig.update_layout(
        title=dict(text=title, font=dict(size=18, color='#333')),
        xaxis_title="Degradation Type",
        yaxis_title="Total Boxes",
        template="plotly_white",
        height=400,
        margin=dict(t=50, b=80, l=60, r=20)
    )

    return fig

def create_combination_bar_chart(combo_data, title="Top 10 Degradation Combinations"):
    """Create bar chart for degradation combinations"""
    if not combo_data:
        return go.Figure().add_annotation(text="No combinations found",
                                         xref="paper", yref="paper",
                                         x=0.5, y=0.5, showarrow=False)

    combos, counts = zip(*combo_data)

    fig = go.Figure(data=[
        go.Bar(x=list(combos), y=list(counts), marker_color='steelblue',
               text=list(counts), textposition='auto')
    ])

    fig.update_layout(
        title=title,
        xaxis_title="Degradation Combination",
        yaxis_title="Occurrences",
        template="plotly_white",
        height=400,
        xaxis={'tickangle': -45}
    )

    return fig

def create_pie_chart(degradation_data, title="JSON Profile Degradations"):
    """Create pie chart for JSON profile degradations"""
    if not degradation_data:
        return go.Figure().add_annotation(text="No JSON profile data",
                                         xref="paper", yref="paper",
                                         x=0.5, y=0.5, showarrow=False)

    types, counts = zip(*degradation_data)

    fig = go.Figure(data=[
        go.Pie(labels=list(types), values=list(counts), hole=0.3)
    ])

    fig.update_layout(
        title=title,
        template="plotly_white",
        height=400
    )

    return fig

def create_boxes_line_chart(time_data, title="Total Boxes Over Time"):
    """Create line chart for boxes over time"""
    if not time_data:
        return go.Figure().add_annotation(text="No time series data",
                                         xref="paper", yref="paper",
                                         x=0.5, y=0.5, showarrow=False)

    times, boxes, _ = zip(*time_data)

    fig = go.Figure(data=[
        go.Scatter(x=list(times), y=list(boxes), mode='lines+markers',
                  line=dict(color='royalblue', width=2),
                  marker=dict(size=6))
    ])

    fig.update_layout(
        title=title,
        xaxis_title="Time",
        yaxis_title="Total Boxes",
        template="plotly_white",
        height=400
    )

    return fig

def create_boxes_per_hour_chart(time_data, title="Boxes Per Hour Over Time"):
    """Create line chart for boxes per hour rate"""
    if not time_data:
        return go.Figure().add_annotation(text="No rate data",
                                         xref="paper", yref="paper",
                                         x=0.5, y=0.5, showarrow=False)

    times, rates, _ = zip(*time_data)

    fig = go.Figure(data=[
        go.Scatter(x=list(times), y=list(rates), mode='lines+markers',
                  line=dict(color='green', width=2),
                  marker=dict(size=6))
    ])

    fig.update_layout(
        title=title,
        xaxis_title="Time",
        yaxis_title="Boxes/Hour",
        template="plotly_white",
        height=400
    )

    return fig

def create_execution_speed_chart(speed_data, title="Macro Execution Speeds"):
    """Create line chart for execution speeds by type"""
    if not speed_data:
        return go.Figure().add_annotation(text="No speed data",
                                         xref="paper", yref="paper",
                                         x=0.5, y=0.5, showarrow=False)

    # Organize data by execution type
    macro_data = {}
    json_data = {}

    for hour, exec_type, avg_speed, count in speed_data:
        if exec_type == 'macro':
            macro_data[hour] = avg_speed
        elif exec_type == 'json_profile':
            json_data[hour] = avg_speed

    fig = go.Figure()

    if macro_data:
        times, speeds = zip(*sorted(macro_data.items()))
        fig.add_trace(go.Scatter(
            x=list(times), y=list(speeds),
            mode='lines+markers',
            name='Macro',
            line=dict(color='blue', width=2),
            marker=dict(size=6)
        ))

    if json_data:
        times, speeds = zip(*sorted(json_data.items()))
        fig.add_trace(go.Scatter(
            x=list(times), y=list(speeds),
            mode='lines+markers',
            name='JSON Profile',
            line=dict(color='green', width=2),
            marker=dict(size=6)
        ))

    fig.update_layout(
        title=title,
        xaxis_title="Time",
        yaxis_title="Average Execution Time (ms)",
        template="plotly_white",
        height=400,
        legend=dict(x=0.02, y=0.98)
    )

    return fig

def generate_dashboard(db_path=None, output_path=None, filter_mode='all'):
    """
    Generate complete dashboard HTML

    Args:
        db_path: Path to database (optional, uses default if None)
        output_path: Path to output HTML (optional, uses default if None)
        filter_mode: Timeline filter mode

    Returns:
        Path to generated HTML file
    """
    if db_path is None:
        db_path = get_database_path()

    if output_path is None:
        documents_dir = Path.home() / "Documents" / "MacroMaster"
        documents_dir.mkdir(parents=True, exist_ok=True)
        output_path = documents_dir / "stats_dashboard.html"

    if not db_path.exists():
        raise FileNotFoundError(f"Database not found: {db_path}")

    print(f"Generating dashboard from: {db_path}")
    print(f"Filter mode: {filter_mode}")

    # Connect to database
    conn = sqlite3.connect(db_path)

    # Get time filter SQL
    filter_sql = get_time_filter_sql(filter_mode)

    # Query all data
    print("Querying data...")
    summary = query_summary_stats(conn, filter_sql)
    print(f"Summary result: {summary}")
    if summary is None:
        summary = (0, 0, 0.0, None, None)  # Default values when no data
    print(f"Summary after default: {summary}")
    deg_totals = query_degradation_totals(conn, filter_sql)
    deg_combos = query_degradation_combinations(conn, filter_sql)
    json_degs = query_json_profile_degradations(conn, filter_sql)
    boxes_time = query_boxes_over_time(conn, filter_sql)
    boxes_rate = query_boxes_per_hour_over_time(conn, filter_sql)
    exec_speeds = query_execution_speeds(conn, filter_sql)

    # Query detailed statistics
    exec_type_perf = query_execution_type_performance(conn, filter_sql)
    button_usage = query_button_usage(conn, filter_sql, limit=10)
    layer_stats = query_layer_stats(conn, filter_sql)
    session_perf = query_session_performance(conn, filter_sql, limit=10)

    # Create charts
    print("Creating charts...")

    # Row 1: Degradation Analysis
    fig1 = create_degradation_bar_chart(deg_totals, "Macro Executions by Degradation")
    fig2 = create_combination_bar_chart(deg_combos, "Top 10 Degradation Combinations")
    fig3 = create_pie_chart(json_degs, "JSON Profile Degradations")

    # Row 2: Time & Efficiency
    fig4 = create_boxes_line_chart(boxes_time, "Total Boxes Over Time")
    fig5 = create_boxes_per_hour_chart(boxes_rate, "Boxes Per Hour Over Time")
    fig6 = create_execution_speed_chart(exec_speeds, "Execution Speeds (Macro vs JSON)")

    # Build HTML
    print("Building HTML...")

    # Get Plotly.js library content
    plotly_js_content = get_plotly_js()

    # Prepare summary stats for display
    total_executions = f"{summary[0] or 0:,}"
    total_boxes = f"{summary[1] or 0:,}"
    avg_time = f"{summary[2] or 0:.0f}ms"
    boxes_per_exec = f"{(summary[1] or 0) / (summary[0] or 1):.1f}" if (summary[0] or 0) > 0 else "0.0"

    html_content = f"""
<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>MacroMaster Analytics Dashboard</title>
    <script>
{plotly_js_content}
    </script>
    <style>
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}
        body {{
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #f5f7fa 0%, #c3cfe2 100%);
            padding: 20px;
            min-height: 100vh;
        }}
        .container {{
            max-width: 1600px;
            margin: 0 auto;
        }}
        .header {{
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 40px;
            border-radius: 15px;
            margin-bottom: 30px;
            box-shadow: 0 8px 16px rgba(0,0,0,0.2);
        }}
        .header h1 {{
            margin: 0 0 10px 0;
            font-size: 2.8em;
            font-weight: 700;
            text-shadow: 2px 2px 4px rgba(0,0,0,0.2);
        }}
        .header .subtitle {{
            font-size: 1.2em;
            opacity: 0.95;
        }}
        .timeline-filter {{
            background: white;
            padding: 20px;
            border-radius: 10px;
            margin-bottom: 30px;
            box-shadow: 0 4px 8px rgba(0,0,0,0.1);
            display: flex;
            align-items: center;
            gap: 15px;
            flex-wrap: wrap;
        }}
        .timeline-filter label {{
            font-weight: 600;
            color: #333;
            font-size: 1.1em;
        }}
        .filter-btn {{
            padding: 10px 20px;
            border: 2px solid #667eea;
            background: white;
            color: #667eea;
            border-radius: 8px;
            cursor: pointer;
            font-weight: 600;
            font-size: 1em;
            transition: all 0.3s;
        }}
        .filter-btn:hover {{
            background: #667eea;
            color: white;
            transform: translateY(-2px);
            box-shadow: 0 4px 8px rgba(102, 126, 234, 0.3);
        }}
        .filter-btn.active {{
            background: #667eea;
            color: white;
        }}
        .summary-stats {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
            gap: 20px;
            margin-bottom: 40px;
        }}
        .stat-card {{
            background: white;
            padding: 25px;
            border-radius: 12px;
            box-shadow: 0 4px 8px rgba(0,0,0,0.1);
            text-align: center;
            transition: transform 0.3s;
        }}
        .stat-card:hover {{
            transform: translateY(-5px);
            box-shadow: 0 8px 16px rgba(0,0,0,0.15);
        }}
        .stat-value {{
            font-size: 2.5em;
            font-weight: bold;
            color: #667eea;
            margin-bottom: 8px;
        }}
        .stat-label {{
            color: #666;
            font-size: 1em;
            font-weight: 500;
        }}
        .section-header {{
            background: white;
            padding: 20px;
            border-radius: 10px;
            margin: 40px 0 20px 0;
            box-shadow: 0 2px 4px rgba(0,0,0,0.1);
        }}
        .section-header h2 {{
            color: #333;
            font-size: 1.8em;
            font-weight: 600;
            margin: 0;
        }}
        .section-header p {{
            color: #666;
            margin: 5px 0 0 0;
            font-size: 0.95em;
        }}
        .chart-row-3 {{
            display: grid;
            grid-template-columns: repeat(3, 1fr);
            gap: 20px;
            margin-bottom: 30px;
        }}
        .chart-container {{
            background: white;
            padding: 20px;
            border-radius: 12px;
            box-shadow: 0 4px 8px rgba(0,0,0,0.1);
        }}
        .chart-container.full-width {{
            grid-column: 1 / -1;
        }}
        .table-section {{
            margin-top: 40px;
        }}
        .table-container {{
            background: white;
            padding: 25px;
            border-radius: 12px;
            box-shadow: 0 4px 8px rgba(0,0,0,0.1);
            overflow-x: auto;
            margin-bottom: 20px;
        }}
        .table-container h3 {{
            margin: 0 0 15px 0;
            color: #333;
            font-size: 1.3em;
            font-weight: 600;
        }}
        table {{
            width: 100%;
            border-collapse: collapse;
            font-size: 0.95em;
        }}
        th, td {{
            padding: 14px;
            text-align: left;
            border-bottom: 1px solid #e0e0e0;
        }}
        th {{
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            font-weight: 600;
            position: sticky;
            top: 0;
        }}
        tr:nth-child(even) {{
            background-color: #f9f9f9;
        }}
        tr:hover {{
            background-color: #f0f0ff;
        }}
        td {{
            color: #333;
        }}
        .footer {{
            text-align: center;
            color: #666;
            margin-top: 60px;
            padding: 30px;
            background: white;
            border-radius: 12px;
            box-shadow: 0 4px 8px rgba(0,0,0,0.1);
        }}
        .footer p {{
            margin: 5px 0;
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📊 MacroMaster Analytics Dashboard</h1>
            <div class="subtitle">Comprehensive Statistics & Performance Tracking | Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</div>
        </div>

        <div class="timeline-filter">
            <label>📅 Timeline Filter:</label>
            <button class="filter-btn {'active' if filter_mode == 'hour' else ''}" onclick="location.reload()">Last Hour</button>
            <button class="filter-btn {'active' if filter_mode == 'today' else ''}" onclick="location.reload()">Today</button>
            <button class="filter-btn {'active' if filter_mode == '7days' else ''}" onclick="location.reload()">Last 7 Days</button>
            <button class="filter-btn {'active' if filter_mode == '30days' else ''}" onclick="location.reload()">Last 30 Days</button>
            <button class="filter-btn {'active' if filter_mode == 'all' else ''}" onclick="location.reload()">All Time</button>
            <span style="margin-left: auto; color: #667eea; font-weight: 600;">Currently Viewing: {filter_mode.upper()}</span>
        </div>

        <div class="summary-stats">
            <div class="stat-card">
                <div class="stat-value">{total_executions}</div>
                <div class="stat-label">Total Executions</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">{total_boxes}</div>
                <div class="stat-label">Total Boxes Drawn</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">{avg_time}</div>
                <div class="stat-label">Avg Execution Time</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">{boxes_per_exec}</div>
                <div class="stat-label">Boxes Per Execution</div>
            </div>
        </div>

        <div class="section-header">
            <h2>📊 Degradation Analysis</h2>
            <p>Breakdown of degradation types tracked per box and execution</p>
        </div>

        <div class="chart-row-3">
            <div class="chart-container">
                <div id="chart1"></div>
            </div>
            <div class="chart-container">
                <div id="chart2"></div>
            </div>
            <div class="chart-container">
                <div id="chart3"></div>
            </div>
        </div>

        <div class="section-header">
            <h2>⏱️ Time & Efficiency Statistics</h2>
            <p>Performance metrics and productivity trends over time</p>
        </div>

        <div class="chart-row-3">
            <div class="chart-container">
                <div id="chart4"></div>
            </div>
            <div class="chart-container">
                <div id="chart5"></div>
            </div>
            <div class="chart-container">
                <div id="chart6"></div>
            </div>
        </div>

        <div class="section-header">
            <h2>📋 Detailed Statistics</h2>
            <p>Comprehensive breakdowns of execution performance, usage patterns, and productivity metrics</p>
        </div>

        <div class="table-section">
            <!-- Execution Type Performance -->
            <div class="table-container">
                <h3>⚡ Execution Type Performance</h3>
                <table>
                    <thead>
                        <tr>
                            <th>Type</th>
                            <th>Count</th>
                            <th>Total Boxes</th>
                            <th>Avg Time (ms)</th>
                            <th>Min Time (ms)</th>
                            <th>Max Time (ms)</th>
                            <th>Boxes per Execution</th>
                        </tr>
                    </thead>
                    <tbody>
    """

    for row in exec_type_perf:
        exec_type, count, avg_time, min_time, max_time, total_boxes = row
        boxes_per_exec = total_boxes / count if count > 0 else 0
        html_content += f"""
                        <tr>
                            <td><span style="background: {'#667eea' if exec_type == 'macro' else '#10b981'}; color: white; padding: 4px 12px; border-radius: 4px; font-weight: 600;">{exec_type}</span></td>
                            <td><strong>{count}</strong></td>
                            <td><strong>{total_boxes}</strong></td>
                            <td>{avg_time:.1f}</td>
                            <td>{min_time}</td>
                            <td>{max_time}</td>
                            <td>{boxes_per_exec:.1f}</td>
                        </tr>
        """

    html_content += """
                    </tbody>
                </table>
            </div>

            <!-- Top 10 Buttons -->
            <div class="table-container">
                <h3>🎯 Top 10 Most Used Buttons</h3>
                <table>
                    <thead>
                        <tr>
                            <th>Button</th>
                            <th>Executions</th>
                            <th>Total Boxes</th>
                            <th>Avg Time (ms)</th>
                            <th>Boxes per Execution</th>
                        </tr>
                    </thead>
                    <tbody>
    """

    for row in button_usage:
        button, executions, total_boxes, avg_time = row
        boxes_per_exec = total_boxes / executions if executions > 0 else 0
        html_content += f"""
                        <tr>
                            <td><strong>{button if button else 'N/A'}</strong></td>
                            <td>{executions}</td>
                            <td><strong>{total_boxes}</strong></td>
                            <td>{avg_time:.1f}</td>
                            <td>{boxes_per_exec:.1f}</td>
                        </tr>
        """

    html_content += """
                    </tbody>
                </table>
            </div>

            <!-- Layer Usage Statistics -->
            <div class="table-container">
                <h3>📊 Layer Usage Statistics</h3>
                <table>
                    <thead>
                        <tr>
                            <th>Layer</th>
                            <th>Executions</th>
                            <th>Total Boxes</th>
                            <th>Avg Time (ms)</th>
                            <th>Boxes per Execution</th>
                            <th>Usage %</th>
                        </tr>
                    </thead>
                    <tbody>
    """

    total_layer_execs = sum(row[1] for row in layer_stats) if layer_stats else 0
    for row in layer_stats:
        layer, executions, total_boxes, avg_time = row
        boxes_per_exec = total_boxes / executions if executions > 0 else 0
        usage_pct = (executions / total_layer_execs * 100) if total_layer_execs > 0 else 0
        html_content += f"""
                        <tr>
                            <td><strong>Layer {layer}</strong></td>
                            <td>{executions}</td>
                            <td><strong>{total_boxes}</strong></td>
                            <td>{avg_time:.1f}</td>
                            <td>{boxes_per_exec:.1f}</td>
                            <td>{usage_pct:.1f}%</td>
                        </tr>
        """

    html_content += """
                    </tbody>
                </table>
            </div>

            <!-- Session Performance -->
            <div class="table-container">
                <h3>📈 Top 10 Sessions by Performance</h3>
                <table>
                    <thead>
                        <tr>
                            <th>Session ID</th>
                            <th>Executions</th>
                            <th>Total Boxes</th>
                            <th>Active Time</th>
                            <th>Boxes/Hour</th>
                            <th>Avg Exec Time (ms)</th>
                        </tr>
                    </thead>
                    <tbody>
    """

    for row in session_perf:
        session_id, executions, total_boxes, active_time_ms, avg_exec_time = row
        active_hours = (active_time_ms / 3600000) if active_time_ms else 0
        boxes_per_hour = (total_boxes / active_hours) if active_hours > 0 else 0

        # Format active time
        if active_time_ms:
            hours = int(active_time_ms // 3600000)
            minutes = int((active_time_ms % 3600000) // 60000)
            time_str = f"{hours}h {minutes}m" if hours > 0 else f"{minutes}m"
        else:
            time_str = "N/A"

        # Shorten session ID for display
        short_session = session_id[-20:] if len(session_id) > 20 else session_id

        html_content += f"""
                        <tr>
                            <td style="font-family: monospace; font-size: 0.9em;">{short_session}</td>
                            <td>{executions}</td>
                            <td><strong>{total_boxes}</strong></td>
                            <td>{time_str}</td>
                            <td><strong>{boxes_per_hour:.1f}</strong></td>
                            <td>{avg_exec_time:.1f}</td>
                        </tr>
        """

    html_content += """
                    </tbody>
                </table>
            </div>
    """

    # Add degradation summary table
    html_content += """
            <div class="table-container">
                <h3>Degradation Type Summary</h3>
                <table>
                    <thead>
                        <tr>
                            <th>Degradation Type</th>
                            <th>Total Count</th>
                            <th>Execution Count</th>
                            <th>Avg Execution Time</th>
                        </tr>
                    </thead>
                    <tbody>
    """

    for deg_type, total_count in deg_totals:
        # Get execution count and avg time for this degradation
        cursor = conn.cursor()
        cursor.execute("""
            SELECT COUNT(DISTINCT e.id) as exec_count, AVG(e.execution_time_ms) as avg_time
            FROM degradations d
            JOIN executions e ON d.execution_id = e.id
            WHERE d.degradation_type = ?
        """, (deg_type,))
        exec_count, avg_time = cursor.fetchone()

        html_content += f"""
                        <tr>
                            <td><strong>{deg_type.capitalize()}</strong></td>
                            <td><strong>{total_count}</strong></td>
                            <td>{exec_count}</td>
                            <td>{avg_time:.1f}ms</td>
                        </tr>
        """

    html_content += """
                    </tbody>
                </table>
            </div>
        </div>

        <div class="footer">
            <p style="font-size: 1.1em; font-weight: 600; margin-bottom: 10px;">MacroMaster Analytics Dashboard</p>
            <p>Powered by SQLite + Plotly | Real-time Performance Tracking</p>
            <p style="font-size: 0.9em; color: #999; margin-top: 10px;">Database: """ + str(db_path) + """</p>
        </div>
    </div>

    <script>
    """

    # Add Plotly chart data
    html_content += f"Plotly.newPlot('chart1', {fig1.to_json()}, {{}});\n"
    html_content += f"Plotly.newPlot('chart2', {fig2.to_json()}, {{}});\n"
    html_content += f"Plotly.newPlot('chart3', {fig3.to_json()}, {{}});\n"
    html_content += f"Plotly.newPlot('chart4', {fig4.to_json()}, {{}});\n"
    html_content += f"Plotly.newPlot('chart5', {fig5.to_json()}, {{}});\n"
    html_content += f"Plotly.newPlot('chart6', {fig6.to_json()}, {{}});\n"

    html_content += """
    </script>
</body>
</html>
    """

    # Write to file
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(html_content)

    conn.close()

    print(f"[OK] Dashboard generated: {output_path}")
    print(f"[OK] File size: {output_path.stat().st_size / 1024:.1f} KB")

    return output_path

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Generate MacroMaster analytics dashboard")
    parser.add_argument("--db", help="Database path (optional)")
    parser.add_argument("--output", help="Output HTML path (optional)")
    parser.add_argument("--filter", default="all",
                       choices=['hour', 'today', '7days', '30days', 'all'],
                       help="Timeline filter mode")
    args = parser.parse_args()

    try:
        output_path = generate_dashboard(args.db, args.output, args.filter)
        print(f"\n[OK] Open dashboard: {output_path}")
    except Exception as e:
        print(f"\n[ERROR] Dashboard generation failed: {str(e)}")
        import traceback
        traceback.print_exc()
        exit(1)
