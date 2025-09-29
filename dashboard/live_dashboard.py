#!/usr/bin/env python3
"""
MacroMaster Live Dashboard Server
Real-time dashboard for monitoring labeling progress with auto-refresh
"""
import pandas as pd
import plotly.graph_objects as go
import plotly.express as px
from plotly.subplots import make_subplots
import numpy as np
import sys
import os
import json
from datetime import datetime, timedelta
from flask import Flask, render_template_string, jsonify
import threading
import time
import argparse

class LiveDashboardServer:
    def __init__(self, csv_path, host='localhost', port=5000, refresh_interval=60):
        self.csv_path = csv_path
        self.host = host
        self.port = port
        self.refresh_interval = refresh_interval
        self.app = Flask(__name__)
        self.last_data_hash = None
        self.setup_routes()

    def setup_routes(self):
        @self.app.route('/')
        def dashboard():
            return render_template_string(self.get_dashboard_html())

        @self.app.route('/api/data')
        def get_data():
            return jsonify(self.get_current_stats())

        @self.app.route('/api/charts')
        def get_charts():
            return jsonify(self.generate_charts())

    def load_and_clean_data(self):
        """Load and clean MacroMaster CSV data with error handling"""
        try:
            if not os.path.exists(self.csv_path):
                print(f"CSV file not found: {self.csv_path}")
                return pd.DataFrame()

            # Read CSV with robust parsing
            df = pd.read_csv(self.csv_path, parse_dates=['timestamp'], on_bad_lines='skip')

            if df.empty:
                print("No data found in CSV")
                return pd.DataFrame()

            # Essential data validation
            required_cols = ['timestamp', 'execution_type', 'total_boxes', 'execution_time_ms']
            missing_cols = [col for col in required_cols if col not in df.columns]
            if missing_cols:
                print(f"Missing required columns: {missing_cols}")
                return pd.DataFrame()

            # Clean and validate data
            df = df.dropna(subset=['timestamp', 'execution_type', 'total_boxes', 'execution_time_ms'])
            df['execution_time_ms'] = pd.to_numeric(df['execution_time_ms'], errors='coerce')
            df['total_boxes'] = pd.to_numeric(df['total_boxes'], errors='coerce')
            df = df.dropna(subset=['execution_time_ms', 'total_boxes'])

            # Add computed columns
            df['date'] = df['timestamp'].dt.date
            df['hour'] = df['timestamp'].dt.hour
            df['execution_time_s'] = df['execution_time_ms'] / 1000
            df['boxes_per_second'] = df['total_boxes'] / df['execution_time_s']
            df['boxes_per_second'] = df['boxes_per_second'].replace([float('inf'), -float('inf')], 0)

            # Sort by timestamp
            df = df.sort_values('timestamp').reset_index(drop=True)

            print(f"Loaded {len(df)} MacroMaster execution records")
            return df

        except Exception as e:
            print(f"Error loading MacroMaster data: {e}")
            return pd.DataFrame()

    def get_current_stats(self):
        """Get current session statistics for live display with enhanced raw data"""
        df = self.load_and_clean_data()

        if df.empty:
            return {
                'total_boxes': 0,
                'session_duration': '0m 0s',
                'avg_speed': 0,
                'current_speed': 0,
                'top_degradations': [],
                'raw_data': {
                    'session_info': {},
                    'performance_metrics': {},
                    'degradation_summary': {}
                },
                'last_update': datetime.now().strftime('%H:%M:%S')
            }

        # Current session data (last 24 hours)
        cutoff_time = datetime.now() - timedelta(hours=24)
        session_df = df[df['timestamp'] >= cutoff_time]

        if session_df.empty:
            return {
                'total_boxes': 0,
                'session_duration': '0m 0s',
                'avg_speed': 0,
                'current_speed': 0,
                'top_degradations': [],
                'raw_data': {
                    'session_info': {},
                    'performance_metrics': {},
                    'degradation_summary': {}
                },
                'last_update': datetime.now().strftime('%H:%M:%S')
            }

        # Calculate metrics
        total_boxes = int(session_df['total_boxes'].sum())
        session_start = session_df['timestamp'].min()
        session_duration_seconds = (datetime.now() - session_start).total_seconds()
        session_duration_str = self.format_duration(session_duration_seconds)

        avg_speed = session_df['boxes_per_second'].mean()

        # Current speed (last 10 minutes)
        recent_cutoff = datetime.now() - timedelta(minutes=10)
        recent_df = session_df[session_df['timestamp'] >= recent_cutoff]
        current_speed = recent_df['boxes_per_second'].mean() if not recent_df.empty else 0

        # Top degradations
        degradation_counts = session_df['degradation_assignments'].value_counts().head(5)
        top_degradations = []
        for deg, count in degradation_counts.items():
            if deg and deg != 'clear' and deg != 'none':
                top_degradations.append({'type': deg, 'count': int(count)})

        # Enhanced raw data for organized display
        raw_data = {
            'session_info': {
                'total_executions': len(session_df),
                'session_duration_hours': round(session_duration_seconds / 3600, 2),
                'macro_executions': len(session_df[session_df['execution_type'] == 'macro']),
                'json_executions': len(session_df[session_df['execution_type'] == 'json_profile']),
                'unique_buttons': session_df['button_key'].nunique(),
                'start_time': session_start.strftime('%H:%M:%S'),
                'end_time': datetime.now().strftime('%H:%M:%S')
            },
            'performance_metrics': {
                'total_boxes': total_boxes,
                'avg_speed': round(avg_speed, 2),
                'current_speed': round(current_speed, 2),
                'boxes_per_hour': round(total_boxes / (session_duration_seconds / 3600), 1) if session_duration_seconds > 0 else 0,
                'fastest_execution_ms': int(session_df['execution_time_ms'].min()),
                'slowest_execution_ms': int(session_df['execution_time_ms'].max()),
                'avg_execution_time_ms': round(session_df['execution_time_ms'].mean(), 1)
            },
            'degradation_summary': {
                'total_degradations': int(sum([
                    session_df['smudge_count'].sum(),
                    session_df['glare_count'].sum(),
                    session_df['splashes_count'].sum(),
                    session_df['partial_blockage_count'].sum(),
                    session_df['full_blockage_count'].sum(),
                    session_df['light_flare_count'].sum(),
                    session_df['rain_count'].sum(),
                    session_df['haze_count'].sum(),
                    session_df['snow_count'].sum()
                ])),
                'clear_executions': int(session_df['clear_count'].sum()),
                'degradation_rate': round(sum([
                    session_df['smudge_count'].sum(),
                    session_df['glare_count'].sum(),
                    session_df['splashes_count'].sum(),
                    session_df['partial_blockage_count'].sum(),
                    session_df['full_blockage_count'].sum(),
                    session_df['light_flare_count'].sum(),
                    session_df['rain_count'].sum(),
                    session_df['haze_count'].sum(),
                    session_df['snow_count'].sum()
                ]) / max(total_boxes, 1) * 100, 1)
            }
        }

        return {
            'total_boxes': total_boxes,
            'session_duration': session_duration_str,
            'avg_speed': round(avg_speed, 2),
            'current_speed': round(current_speed, 2),
            'top_degradations': top_degradations,
            'raw_data': raw_data,
            'last_update': datetime.now().strftime('%H:%M:%S')
        }

    def generate_charts(self):
        """Generate chart data for live updates"""
        df = self.load_and_clean_data()

        if df.empty:
            return {'charts': []}

        # Current session data
        cutoff_time = datetime.now() - timedelta(hours=24)
        session_df = df[df['timestamp'] >= cutoff_time]

        if session_df.empty:
            return {'charts': []}

        charts = []

        # Speed over time chart
        if len(session_df) > 1:
            speed_fig = px.line(session_df, x='timestamp', y='boxes_per_second',
                              title='Labeling Speed Over Time',
                              labels={'boxes_per_second': 'Boxes/Second', 'timestamp': 'Time'})
            charts.append({
                'id': 'speed_chart',
                'data': speed_fig.to_json()
            })

        # Degradation distribution
        if not session_df['degradation_assignments'].empty:
            deg_counts = session_df['degradation_assignments'].value_counts().head(8)
            deg_fig = px.bar(x=deg_counts.index, y=deg_counts.values,
                           title='Degradation Types',
                           labels={'x': 'Degradation Type', 'y': 'Count'})
            charts.append({
                'id': 'degradation_chart',
                'data': deg_fig.to_json()
            })

        return {'charts': charts}

    def format_duration(self, seconds):
        """Format duration in seconds to human readable string"""
        if seconds < 60:
            return f"0m {int(seconds)}s"
        elif seconds < 3600:
            minutes = int(seconds // 60)
            secs = int(seconds % 60)
            return f"{minutes}m {secs}s"
        else:
            hours = int(seconds // 3600)
            minutes = int((seconds % 3600) // 60)
            return f"{hours}h {minutes}m"

    def get_dashboard_html(self):
        """Generate the main dashboard HTML with improved raw data organization"""
        return f"""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MacroMaster Live Dashboard</title>
    <script src="https://cdn.plot.ly/plotly-latest.min.js"></script>
    <style>
        body {{
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
        }}
        .container {{
            max-width: 1400px;
            margin: 0 auto;
            background: white;
            border-radius: 10px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.3);
            overflow: hidden;
        }}
        .header {{
            background: linear-gradient(135deg, #2c3e50 0%, #3498db 100%);
            color: white;
            padding: 20px;
            text-align: center;
        }}
        .stats-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
            gap: 20px;
            padding: 20px;
        }}
        .stat-card {{
            background: #f8f9fa;
            border-radius: 8px;
            padding: 20px;
            text-align: center;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
            border-left: 4px solid #3498db;
        }}
        .stat-value {{
            font-size: 2.5em;
            font-weight: bold;
            color: #2c3e50;
            margin: 10px 0;
        }}
        .stat-label {{
            color: #6c757d;
            font-size: 0.9em;
            text-transform: uppercase;
            letter-spacing: 1px;
        }}
        .charts-container {{
            padding: 20px;
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
        }}
        .chart {{
            background: white;
            border-radius: 8px;
            padding: 15px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }}
        .degradations {{
            background: #f8f9fa;
            border-radius: 8px;
            padding: 20px;
            margin: 20px;
        }}
        .deg-item {{
            display: flex;
            justify-content: space-between;
            padding: 8px 0;
            border-bottom: 1px solid #dee2e6;
        }}
        .raw-data-section {{
            background: #f8f9fa;
            border-radius: 8px;
            padding: 20px;
            margin: 20px;
            border-top: 4px solid #28a745;
        }}
        .raw-data-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-top: 15px;
        }}
        .raw-data-card {{
            background: white;
            border-radius: 6px;
            padding: 15px;
            box-shadow: 0 1px 5px rgba(0,0,0,0.1);
        }}
        .raw-data-card h4 {{
            margin: 0 0 10px 0;
            color: #2c3e50;
            font-size: 1.1em;
            border-bottom: 2px solid #28a745;
            padding-bottom: 5px;
        }}
        .data-item {{
            display: flex;
            justify-content: space-between;
            padding: 6px 0;
            border-bottom: 1px solid #e9ecef;
            font-size: 0.9em;
        }}
        .data-item:last-child {{
            border-bottom: none;
        }}
        .data-label {{
            color: #6c757d;
            font-weight: 500;
        }}
        .data-value {{
            color: #2c3e50;
            font-weight: bold;
        }}
        .last-update {{
            text-align: center;
            color: #6c757d;
            font-size: 0.8em;
            margin-top: 10px;
            padding: 10px;
            background: #f8f9fa;
            border-radius: 5px;
        }}
        .export-btn {{
            background: #28a745;
            color: white;
            border: none;
            padding: 8px 16px;
            border-radius: 4px;
            cursor: pointer;
            font-size: 0.9em;
            margin-top: 10px;
        }}
        .export-btn:hover {{
            background: #218838;
        }}
        @media (max-width: 768px) {{
            .charts-container {{
                grid-template-columns: 1fr;
            }}
            .stats-grid {{
                grid-template-columns: 1fr;
            }}
            .raw-data-grid {{
                grid-template-columns: 1fr;
            }}
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🎯 MacroMaster Live Dashboard</h1>
            <p>Real-time labeling progress monitoring</p>
        </div>

        <div id="stats-container" class="stats-grid">
            <!-- Stats will be loaded here -->
        </div>

        <div class="degradations">
            <h3>📊 Top Degradation Types</h3>
            <div id="degradations-list">
                <!-- Degradations will be loaded here -->
            </div>
        </div>

        <div class="charts-container">
            <div class="chart">
                <div id="speed-chart"></div>
            </div>
            <div class="chart">
                <div id="degradation-chart"></div>
            </div>
        </div>

        <div class="raw-data-section">
            <h3>📋 Raw Data Summary</h3>
            <div id="raw-data-container" class="raw-data-grid">
                <!-- Raw data will be loaded here -->
            </div>
            <button class="export-btn" onclick="exportData()">📥 Export Data</button>
        </div>

        <div class="last-update" id="last-update">
            Last updated: --
        </div>
    </div>

    <script>
        let charts = {{}};

        function updateDashboard() {{
            fetch('/api/data')
                .then(response => response.json())
                .then(data => {{
                    updateStats(data);
                    document.getElementById('last-update').textContent =
                        'Last updated: ' + data.last_update;
                }})
                .catch(error => console.error('Error updating dashboard:', error));
        }}

        function updateStats(data) {{
            const statsContainer = document.getElementById('stats-container');
            const degContainer = document.getElementById('degradations-list');
            const rawDataContainer = document.getElementById('raw-data-container');

            statsContainer.innerHTML = `
                <div class="stat-card">
                    <div class="stat-label">Total Boxes</div>
                    <div class="stat-value">${{data.total_boxes.toLocaleString()}}</div>
                </div>
                <div class="stat-card">
                    <div class="stat-label">Session Duration</div>
                    <div class="stat-value">${{data.session_duration}}</div>
                </div>
                <div class="stat-card">
                    <div class="stat-label">Avg Speed</div>
                    <div class="stat-value">${{data.avg_speed}}</div>
                    <small>boxes/sec</small>
                </div>
                <div class="stat-card">
                    <div class="stat-label">Current Speed</div>
                    <div class="stat-value">${{data.current_speed}}</div>
                    <small>boxes/sec</small>
                </div>
            `;

            degContainer.innerHTML = data.top_degradations.map(deg =>
                `<div class="deg-item">
                    <span>${{deg.type}}</span>
                    <span>${{deg.count}}</span>
                </div>`
            ).join('');

            // Update raw data section
            if (data.raw_data) {{
                rawDataContainer.innerHTML = `
                    <div class="raw-data-card">
                        <h4>📊 Session Info</h4>
                        <div class="data-item">
                            <span class="data-label">Total Executions:</span>
                            <span class="data-value">${{data.raw_data.session_info.total_executions || 0}}</span>
                        </div>
                        <div class="data-item">
                            <span class="data-label">Duration (hours):</span>
                            <span class="data-value">${{data.raw_data.session_info.session_duration_hours || 0}}</span>
                        </div>
                        <div class="data-item">
                            <span class="data-label">Macro Executions:</span>
                            <span class="data-value">${{data.raw_data.session_info.macro_executions || 0}}</span>
                        </div>
                        <div class="data-item">
                            <span class="data-label">JSON Executions:</span>
                            <span class="data-value">${{data.raw_data.session_info.json_executions || 0}}</span>
                        </div>
                        <div class="data-item">
                            <span class="data-label">Unique Buttons:</span>
                            <span class="data-value">${{data.raw_data.session_info.unique_buttons || 0}}</span>
                        </div>
                        <div class="data-item">
                            <span class="data-label">Time Range:</span>
                            <span class="data-value">${{data.raw_data.session_info.start_time || '--'}} - ${{data.raw_data.session_info.end_time || '--'}}</span>
                        </div>
                    </div>
                    <div class="raw-data-card">
                        <h4>⚡ Performance Metrics</h4>
                        <div class="data-item">
                            <span class="data-label">Total Boxes:</span>
                            <span class="data-value">${{data.raw_data.performance_metrics.total_boxes || 0}}</span>
                        </div>
                        <div class="data-item">
                            <span class="data-label">Avg Speed (boxes/sec):</span>
                            <span class="data-value">${{data.raw_data.performance_metrics.avg_speed || 0}}</span>
                        </div>
                        <div class="data-item">
                            <span class="data-label">Current Speed (boxes/sec):</span>
                            <span class="data-value">${{data.raw_data.performance_metrics.current_speed || 0}}</span>
                        </div>
                        <div class="data-item">
                            <span class="data-label">Boxes/Hour:</span>
                            <span class="data-value">${{data.raw_data.performance_metrics.boxes_per_hour || 0}}</span>
                        </div>
                        <div class="data-item">
                            <span class="data-label">Fastest Execution (ms):</span>
                            <span class="data-value">${{data.raw_data.performance_metrics.fastest_execution_ms || 0}}</span>
                        </div>
                        <div class="data-item">
                            <span class="data-label">Avg Execution Time (ms):</span>
                            <span class="data-value">${{data.raw_data.performance_metrics.avg_execution_time_ms || 0}}</span>
                        </div>
                    </div>
                    <div class="raw-data-card">
                        <h4>🎯 Degradation Summary</h4>
                        <div class="data-item">
                            <span class="data-label">Total Degradations:</span>
                            <span class="data-value">${{data.raw_data.degradation_summary.total_degradations || 0}}</span>
                        </div>
                        <div class="data-item">
                            <span class="data-label">Clear Executions:</span>
                            <span class="data-value">${{data.raw_data.degradation_summary.clear_executions || 0}}</span>
                        </div>
                        <div class="data-item">
                            <span class="data-label">Degradation Rate (%):</span>
                            <span class="data-value">${{data.raw_data.degradation_summary.degradation_rate || 0}}%</span>
                        </div>
                    </div>
                `;
            }}
        }}

        function exportData() {{
            fetch('/api/data')
                .then(response => response.json())
                .then(data => {{
                    const exportData = {{
                        timestamp: new Date().toISOString(),
                        session_data: data,
                        raw_data: data.raw_data || {{}}
                    }};

                    const blob = new Blob([JSON.stringify(exportData, null, 2)], {{
                        type: 'application/json'
                    }});

                    const url = URL.createObjectURL(blob);
                    const a = document.createElement('a');
                    a.href = url;
                    a.download = `macromaster_session_${{new Date().toISOString().split('T')[0]}}.json`;
                    document.body.appendChild(a);
                    a.click();
                    document.body.removeChild(a);
                    URL.revokeObjectURL(url);
                }})
                .catch(error => console.error('Export failed:', error));
        }}

        function updateCharts() {{
            fetch('/api/charts')
                .then(response => response.json())
                .then(data => {{
                    data.charts.forEach(chart => {{
                        const chartDiv = document.getElementById(chart.id);
                        if (chartDiv) {{
                            Plotly.newPlot(chart.id, JSON.parse(chart.data).data,
                                         JSON.parse(chart.data).layout || {{}});
                        }}
                    }});
                }})
                .catch(error => console.error('Error updating charts:', error));
        }}

        // Initial load
        updateDashboard();
        updateCharts();

        // Auto-refresh every {self.refresh_interval} seconds
        setInterval(() => {{
            updateDashboard();
            updateCharts();
        }}, {self.refresh_interval * 1000});
    </script>
</body>
</html>
        """

    def run(self):
        """Start the Flask server"""
        print(f"Starting MacroMaster Live Dashboard on http://{self.host}:{self.port}")
        print(f"Dashboard will auto-refresh every {self.refresh_interval} seconds")
        print(f"Monitoring CSV file: {self.csv_path}")
        self.app.run(host=self.host, port=self.port, debug=False)

def main():
    parser = argparse.ArgumentParser(description='MacroMaster Live Dashboard Server')
    parser.add_argument('csv_path', help='Path to the MacroMaster CSV data file')
    parser.add_argument('--host', default='localhost', help='Host to bind to (default: localhost)')
    parser.add_argument('--port', type=int, default=5000, help='Port to bind to (default: 5000)')
    parser.add_argument('--refresh', type=int, default=30, help='Auto-refresh interval in seconds (default: 30)')

    args = parser.parse_args()

    if not os.path.exists(args.csv_path):
        print(f"Error: CSV file not found: {args.csv_path}")
        return

    server = LiveDashboardServer(args.csv_path, args.host, args.port, args.refresh)
    server.run()

if __name__ == "__main__":
    main()