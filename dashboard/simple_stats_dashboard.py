#!/usr/bin/env python3
"""
MacroMaster Simple Stats Dashboard
Accurate, static dashboard displaying current labeling statistics
"""

import pandas as pd
import sys
import os
import json
from datetime import datetime, timedelta
from flask import Flask, render_template_string, jsonify
import argparse

class SimpleStatsDashboard:
    def __init__(self, csv_path, host='localhost', port=5003):
        self.csv_path = csv_path
        self.host = host
        self.port = port
        self.app = Flask(__name__)
        self.setup_routes()

    def setup_routes(self):
        @self.app.route('/')
        def dashboard():
            return render_template_string(self.get_dashboard_html())

        @self.app.route('/api/stats')
        def get_stats():
            return jsonify(self.get_current_stats())

    def load_and_clean_data(self):
        """Load and clean MacroMaster CSV data with comprehensive error handling"""
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
        """Get comprehensive current session statistics"""
        df = self.load_and_clean_data()

        if df.empty:
            return self._get_empty_stats()

        # Current session data (last 24 hours for active session)
        cutoff_time = datetime.now() - timedelta(hours=24)
        session_df = df[df['timestamp'] >= cutoff_time]

        if session_df.empty:
            return self._get_empty_stats()

        # Calculate comprehensive metrics
        stats = self._calculate_comprehensive_stats(session_df)

        return stats

    def _get_empty_stats(self):
        """Return empty stats structure"""
        return {
            'total_boxes': 0,
            'session_duration': '0m 0s',
            'avg_speed': 0,
            'current_speed': 0,
            'total_executions': 0,
            'macro_executions': 0,
            'json_executions': 0,
            'clear_executions': 0,
            'degradation_rate': 0,
            'top_degradations': [],
            'performance_data': {},
            'charts': [],
            'last_update': datetime.now().strftime('%H:%M:%S')
        }

    def _calculate_comprehensive_stats(self, session_df):
        """Calculate all statistics from session data"""
        # Basic metrics
        total_boxes = int(session_df['total_boxes'].sum())
        session_start = session_df['timestamp'].min()
        session_duration_seconds = (datetime.now() - session_start).total_seconds()
        session_duration_str = self.format_duration(session_duration_seconds)

        # Speed calculations
        avg_speed = session_df['boxes_per_second'].mean()

        # Current speed (last 10 minutes)
        recent_cutoff = datetime.now() - timedelta(minutes=10)
        recent_df = session_df[session_df['timestamp'] >= recent_cutoff]
        current_speed = recent_df['boxes_per_second'].mean() if not recent_df.empty else 0

        # Execution counts
        total_executions = len(session_df)
        macro_executions = len(session_df[session_df['execution_type'] == 'macro'])
        json_executions = len(session_df[session_df['execution_type'] == 'json_profile'])
        clear_executions = len(session_df[session_df['execution_type'] == 'clear'])

        # Degradation analysis
        degradation_counts = session_df['degradation_assignments'].value_counts()
        top_degradations = []
        for deg, count in degradation_counts.head(5).items():
            if deg and deg not in ['clear', 'none', '']:
                top_degradations.append({'type': deg, 'count': int(count)})

        # Calculate degradation rate
        total_degradations = sum([count for deg, count in degradation_counts.items()
                                if deg and deg not in ['clear', 'none', '']])
        degradation_rate = (total_degradations / max(total_executions, 1)) * 100


        return {
            'total_boxes': total_boxes,
            'session_duration': session_duration_str,
            'avg_speed': round(avg_speed, 2),
            'current_speed': round(current_speed, 2),
            'total_executions': total_executions,
            'macro_executions': macro_executions,
            'json_executions': json_executions,
            'clear_executions': clear_executions,
            'degradation_rate': round(degradation_rate, 1),
            'top_degradations': top_degradations,
            'last_update': datetime.now().strftime('%H:%M:%S')
        }


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
        """Generate a simple dashboard focused on key metrics"""
        return f"""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MacroMaster Simple Stats</title>
    <style>
        body {{
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
        }}
        .container {{
            max-width: 1200px;
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
            padding: 30px;
        }}
        .stat-card {{
            background: white;
            border-radius: 8px;
            padding: 25px;
            text-align: center;
            box-shadow: 0 4px 15px rgba(0,0,0,0.1);
            border-left: 5px solid #3498db;
            transition: transform 0.2s;
        }}
        .stat-card:hover {{
            transform: translateY(-2px);
        }}
        .stat-value {{
            font-size: 2.5em;
            font-weight: bold;
            color: #2c3e50;
            margin: 10px 0;
            display: block;
        }}
        .stat-label {{
            color: #6c757d;
            font-size: 1em;
            text-transform: uppercase;
            letter-spacing: 0.5px;
            font-weight: 600;
        }}
        .stat-subtitle {{
            color: #28a745;
            font-size: 0.8em;
            margin-top: 5px;
        }}
        .section-title {{
            font-size: 1.2em;
            color: #2c3e50;
            margin-bottom: 15px;
            font-weight: bold;
        }}
        .last-update {{
            text-align: center;
            color: #6c757d;
            font-size: 0.9em;
            margin: 20px;
            padding: 15px;
            background: #f8f9fa;
            border-radius: 5px;
        }}
        .refresh-btn {{
            background: #28a745;
            color: white;
            border: none;
            padding: 12px 25px;
            border-radius: 5px;
            cursor: pointer;
            font-size: 1em;
            margin: 15px;
            font-weight: 600;
        }}
        .refresh-btn:hover {{
            background: #218838;
        }}
        .macro-degradation {{
            border-left-color: #dc3545 !important;
        }}
        .json-executions {{
            border-left-color: #ffc107 !important;
        }}
        .efficiency {{
            border-left-color: #28a745 !important;
        }}
        .time-stats {{
            border-left-color: #17a2b8 !important;
        }}
        @media (max-width: 768px) {{
            .stats-grid {{
                grid-template-columns: 1fr;
                padding: 20px;
            }}
            .stat-value {{
                font-size: 2em;
            }}
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📊 MacroMaster Simple Dashboard</h1>
            <p>Key performance metrics at a glance</p>
        </div>

        <div id="stats-grid" class="stats-grid">
            <!-- Stats will be loaded here -->
        </div>

        <div style="text-align: center;">
            <button class="refresh-btn" onclick="loadDashboard()">🔄 Refresh Data</button>
        </div>

        <div class="last-update" id="last-update">
            Loading data...
        </div>
    </div>

    <script>
        function loadDashboard() {{
            document.getElementById('last-update').textContent = 'Loading data...';

            fetch('/api/stats')
                .then(response => response.json())
                .then(data => {{
                    updateStats(data);
                    document.getElementById('last-update').textContent =
                        'Last updated: ' + data.last_update + ' (Click refresh to update)';
                }})
                .catch(error => {{
                    console.error('Error loading dashboard:', error);
                    document.getElementById('last-update').textContent =
                        'Error loading data. Check console for details.';
                }});
        }}

        function updateStats(data) {{
            const grid = document.getElementById('stats-grid');
            grid.innerHTML = `
                <div class="stat-card macro-degradation">
                    <div class="section-title">🎯 Macro Degradation</div>
                    <div class="stat-value">${{data.degradation_rate}}%</div>
                    <div class="stat-label">Degradation Rate</div>
                    <div class="stat-subtitle">Top: ${{data.top_degradations.length > 0 ? data.top_degradations[0].type : 'None'}}</div>
                </div>

                <div class="stat-card json-executions">
                    <div class="section-title">📄 JSON Profile Executions</div>
                    <div class="stat-value">${{data.json_executions}}</div>
                    <div class="stat-label">JSON Executions</div>
                    <div class="stat-subtitle">${{Math.round(data.json_executions / Math.max(data.total_executions, 1) * 100)}}% of total</div>
                </div>

                <div class="stat-card efficiency">
                    <div class="section-title">⚡ Efficiency</div>
                    <div class="stat-value">${{data.avg_speed}}</div>
                    <div class="stat-label">Avg Speed (boxes/sec)</div>
                    <div class="stat-subtitle">Current: ${{data.current_speed}} boxes/sec</div>
                </div>

                <div class="stat-card time-stats">
                    <div class="section-title">⏱️ Time Stats</div>
                    <div class="stat-value">${{data.session_duration}}</div>
                    <div class="stat-label">Session Duration</div>
                    <div class="stat-subtitle">${{data.total_boxes.toLocaleString()}} total boxes</div>
                </div>

                <div class="stat-card">
                    <div class="section-title">📦 Total Executions</div>
                    <div class="stat-value">${{data.total_executions}}</div>
                    <div class="stat-label">All Types</div>
                    <div class="stat-subtitle">Macros: ${{data.macro_executions}} | Clear: ${{data.clear_executions}}</div>
                </div>

                <div class="stat-card">
                    <div class="section-title">🎯 Top Degradations</div>
                    <div class="stat-value">${{data.top_degradations.length}}</div>
                    <div class="stat-label">Types Detected</div>
                    <div class="stat-subtitle">${{data.top_degradations.slice(0, 3).map(d => d.type + '(' + d.count + ')').join(', ')}}</div>
                </div>
            `;
        }}

        // Load dashboard on page load
        loadDashboard();
    </script>
</body>
</html>
        """

    def run(self):
        """Start the Flask server"""
        print(f"Starting MacroMaster Simple Stats Dashboard on http://{self.host}:{self.port}")
        print(f"Dashboard displays accurate statistics from: {self.csv_path}")
        self.app.run(host=self.host, port=self.port, debug=False)

def main():
    parser = argparse.ArgumentParser(description='MacroMaster Simple Stats Dashboard')
    parser.add_argument('csv_path', help='Path to the MacroMaster CSV data file')
    parser.add_argument('--host', default='localhost', help='Host to bind to (default: localhost)')
    parser.add_argument('--port', type=int, default=5003, help='Port to bind to (default: 5003)')

    args = parser.parse_args()

    if not os.path.exists(args.csv_path):
        print(f"Error: CSV file not found: {args.csv_path}")
        return

    server = SimpleStatsDashboard(args.csv_path, args.host, args.port)
    server.run()

if __name__ == "__main__":
    main()