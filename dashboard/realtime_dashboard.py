#!/usr/bin/env python3
"""
MacroMaster Real-Time WebSocket Dashboard
Live dashboard with instant updates using WebSocket connections
"""

import os
import sys
import json
import time
import threading
from datetime import datetime, timedelta
from flask import Flask, render_template_string, request
from flask_socketio import SocketIO, emit
import pandas as pd
import plotly.graph_objects as go
import plotly.express as px
from plotly.subplots import make_subplots

# Add current directory to path for imports
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from database_schema import get_database

class RealtimeDashboard:
    def __init__(self, host='localhost', port=5002, ingestion_host='localhost', ingestion_port=5001):
        self.host = host
        self.port = port
        self.ingestion_host = ingestion_host
        self.ingestion_port = ingestion_port

        self.app = Flask(__name__)
        self.app.config['SECRET_KEY'] = 'macromaster_realtime_dashboard'
        self.socketio = SocketIO(self.app, cors_allowed_origins="*", async_mode='threading')

        self.db = get_database()
        self.active_sessions = set()
        self.setup_routes()
        self.setup_socket_events()

        # Background thread for periodic cleanup
        self.cleanup_thread = threading.Thread(target=self.background_cleanup, daemon=True)
        self.cleanup_thread.start()

    def setup_routes(self):
        @self.app.route('/')
        def dashboard():
            return render_template_string(self.get_dashboard_html())

        @self.app.route('/health')
        def health():
            return {
                'status': 'healthy',
                'active_sessions': len(self.active_sessions),
                'timestamp': datetime.now().isoformat()
            }

    def setup_socket_events(self):
        @self.socketio.on('connect')
        def handle_connect():
            self.db.log_system_event('INFO', 'dashboard', f'Client connected: {request.sid}')
            emit('connected', {'status': 'success', 'timestamp': datetime.now().isoformat()})

        @self.socketio.on('disconnect')
        def handle_disconnect():
            self.db.log_system_event('INFO', 'dashboard', f'Client disconnected: {request.sid}')

        @self.socketio.on('join_session')
        def handle_join_session(data):
            """Client joins a session for real-time updates"""
            session_id = data.get('session_id')
            if session_id:
                self.active_sessions.add(session_id)
                self.db.log_system_event('INFO', 'dashboard', f'Client joined session: {session_id}')

                # Send initial data
                self.send_initial_data(session_id)

                emit('session_joined', {
                    'session_id': session_id,
                    'status': 'success',
                    'timestamp': datetime.now().isoformat()
                })
            else:
                emit('error', {'message': 'No session_id provided'})

        @self.socketio.on('leave_session')
        def handle_leave_session(data):
            """Client leaves a session"""
            session_id = data.get('session_id')
            if session_id and session_id in self.active_sessions:
                self.active_sessions.discard(session_id)
                self.db.log_system_event('INFO', 'dashboard', f'Client left session: {session_id}')
                emit('session_left', {'session_id': session_id})

        @self.socketio.on('request_update')
        def handle_request_update(data):
            """Client requests immediate data update"""
            session_id = data.get('session_id')
            if session_id:
                self.send_realtime_update(session_id)

    def send_initial_data(self, session_id):
        """Send initial dashboard data to client"""
        try:
            metrics = self.db.get_realtime_metrics(session_id)
            interactions = self.db.get_recent_interactions(session_id, limit=50)

            data = {
                'session_id': session_id,
                'metrics': metrics['data'] if metrics else self.get_empty_metrics(),
                'recent_interactions': interactions,
                'charts': self.generate_charts(session_id),
                'timestamp': datetime.now().isoformat()
            }

            self.socketio.emit('initial_data', data, room=request.sid)

        except Exception as e:
            self.db.log_system_event('ERROR', 'dashboard', f'Failed to send initial data: {str(e)}')
            self.socketio.emit('error', {'message': 'Failed to load initial data'}, room=request.sid)

    def send_realtime_update(self, session_id):
        """Send real-time update to all clients in session"""
        try:
            metrics = self.db.get_realtime_metrics(session_id)

            if metrics:
                update_data = {
                    'session_id': session_id,
                    'metrics': metrics['data'],
                    'charts': self.generate_charts(session_id),
                    'timestamp': datetime.now().isoformat()
                }

                # Send to all clients in this session
                self.socketio.emit('realtime_update', update_data, skip_sid=request.sid)

        except Exception as e:
            self.db.log_system_event('ERROR', 'dashboard', f'Failed to send update: {str(e)}')

    def broadcast_session_update(self, session_id):
        """Broadcast update to all clients following this session"""
        if session_id in self.active_sessions:
            self.send_realtime_update(session_id)

    def generate_charts(self, session_id):
        """Generate chart data for the dashboard"""
        try:
            interactions = self.db.get_recent_interactions(session_id, limit=200)

            if not interactions:
                return {'charts': []}

            # Convert to DataFrame for easier processing
            df = pd.DataFrame(interactions)
            df['timestamp'] = pd.to_datetime(df['timestamp'])

            charts = []

            # Speed over time chart
            if len(df) > 1 and 'execution_time_ms' in df.columns and 'total_boxes' in df.columns:
                df['execution_time_s'] = df['execution_time_ms'] / 1000
                df['boxes_per_second'] = df['total_boxes'] / df['execution_time_s']
                df['boxes_per_second'] = df['boxes_per_second'].replace([float('inf'), -float('inf')], 0)

                speed_fig = px.line(df, x='timestamp', y='boxes_per_second',
                                  title='Labeling Speed Over Time',
                                  labels={'boxes_per_second': 'Boxes/Second', 'timestamp': 'Time'})
                charts.append({
                    'id': 'speed_chart',
                    'data': speed_fig.to_json()
                })

            # Execution time distribution
            if len(df) > 0 and 'execution_time_ms' in df.columns:
                time_fig = px.histogram(df, x='execution_time_ms',
                                      title='Execution Time Distribution',
                                      labels={'execution_time_ms': 'Execution Time (ms)'})
                charts.append({
                    'id': 'time_chart',
                    'data': time_fig.to_json()
                })

            return {'charts': charts}

        except Exception as e:
            self.db.log_system_event('ERROR', 'dashboard', f'Chart generation failed: {str(e)}')
            return {'charts': []}

    def get_empty_metrics(self):
        """Return empty metrics structure"""
        return {
            'session_stats': {
                'total_executions': 0,
                'total_boxes': 0,
                'total_time_ms': 0,
                'avg_execution_time_ms': 0,
                'boxes_per_second': 0,
                'last_activity': None
            },
            'degradation_summary': {},
            'performance_metrics': {
                'efficiency_score': 0,
                'avg_boxes_per_execution': 0
            }
        }

    def background_cleanup(self):
        """Background thread for periodic cleanup and health checks"""
        while True:
            try:
                # Clean up old data every hour
                self.db.cleanup_old_data(days_to_keep=7)  # Keep only 7 days for real-time dashboard

                # Check database health
                health_status = self.check_system_health()
                if health_status != 'healthy':
                    self.db.log_system_event('WARNING', 'dashboard', f'System health: {health_status}')

            except Exception as e:
                self.db.log_system_event('ERROR', 'dashboard', f'Background cleanup error: {str(e)}')

            time.sleep(3600)  # Run every hour

    def check_system_health(self):
        """Check overall system health"""
        try:
            # Check database connectivity
            conn = self.db.get_connection()
            cursor = conn.cursor()
            cursor.execute("SELECT COUNT(*) FROM user_sessions WHERE is_active = 1")
            active_sessions = cursor.fetchone()[0]

            # Check ingestion service (basic connectivity check)
            # This would need actual HTTP check in production

            if active_sessions >= 0:  # Basic connectivity check
                return 'healthy'
            else:
                return 'degraded'

        except Exception as e:
            self.db.log_system_event('ERROR', 'dashboard', f'Health check failed: {str(e)}')
            return 'critical'

    def get_dashboard_html(self):
        """Generate the WebSocket-based dashboard HTML"""
        return f"""
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>MacroMaster Real-Time Dashboard</title>
    <script src="https://cdn.socket.io/4.7.2/socket.io.min.js"></script>
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
        .connection-status {{
            position: fixed;
            top: 10px;
            right: 10px;
            padding: 5px 10px;
            border-radius: 5px;
            font-size: 12px;
            font-weight: bold;
        }}
        .connected {{ background: #28a745; color: white; }}
        .disconnected {{ background: #dc3545; color: white; }}
        .connecting {{ background: #ffc107; color: black; }}
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
        .metrics-section {{
            background: #f8f9fa;
            border-radius: 8px;
            padding: 20px;
            margin: 20px;
            border-top: 4px solid #28a745;
        }}
        .metrics-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
            gap: 20px;
            margin-top: 15px;
        }}
        .metrics-card {{
            background: white;
            border-radius: 6px;
            padding: 15px;
            box-shadow: 0 1px 5px rgba(0,0,0,0.1);
        }}
        .metrics-card h4 {{
            margin: 0 0 10px 0;
            color: #2c3e50;
            font-size: 1.1em;
            border-bottom: 2px solid #28a745;
            padding-bottom: 5px;
        }}
        .metric-item {{
            display: flex;
            justify-content: space-between;
            padding: 6px 0;
            border-bottom: 1px solid #e9ecef;
            font-size: 0.9em;
        }}
        .metric-item:last-child {{
            border-bottom: none;
        }}
        .metric-label {{
            color: #6c757d;
            font-weight: 500;
        }}
        .metric-value {{
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
        .session-selector {{
            padding: 20px;
            background: #f8f9fa;
            border-bottom: 1px solid #dee2e6;
        }}
        .session-input {{
            padding: 8px;
            border: 1px solid #ced4da;
            border-radius: 4px;
            margin-right: 10px;
        }}
        .session-btn {{
            background: #007bff;
            color: white;
            border: none;
            padding: 8px 16px;
            border-radius: 4px;
            cursor: pointer;
        }}
        .session-btn:hover {{
            background: #0056b3;
        }}
        @media (max-width: 768px) {{
            .charts-container {{
                grid-template-columns: 1fr;
            }}
            .stats-grid {{
                grid-template-columns: 1fr;
            }}
            .metrics-grid {{
                grid-template-columns: 1fr;
            }}
        }}
    </style>
</head>
<body>
    <div id="connection-status" class="connection-status connecting">
        CONNECTING...
    </div>

    <div class="container">
        <div class="header">
            <h1>⚡ MacroMaster Real-Time Dashboard</h1>
            <p>Live labeling progress with instant updates</p>
        </div>

        <div class="session-selector">
            <input type="text" id="session-input" class="session-input" placeholder="Enter Session ID" value="default_session">
            <button id="join-btn" class="session-btn">Join Session</button>
            <button id="leave-btn" class="session-btn" style="background: #dc3545;">Leave Session</button>
        </div>

        <div id="stats-container" class="stats-grid">
            <div class="stat-card">
                <div class="stat-label">Status</div>
                <div class="stat-value">⏳</div>
                <small>Waiting for session...</small>
            </div>
        </div>

        <div class="charts-container">
            <div class="chart">
                <div id="speed-chart"></div>
            </div>
            <div class="chart">
                <div id="time-chart"></div>
            </div>
        </div>

        <div class="metrics-section">
            <h3>📊 Live Metrics</h3>
            <div id="metrics-container" class="metrics-grid">
                <div class="metrics-card">
                    <h4>Session Statistics</h4>
                    <div id="session-stats">Waiting for data...</div>
                </div>
                <div class="metrics-card">
                    <h4>Performance Metrics</h4>
                    <div id="performance-metrics">Waiting for data...</div>
                </div>
                <div class="metrics-card">
                    <h4>Degradation Summary</h4>
                    <div id="degradation-summary">Waiting for data...</div>
                </div>
            </div>
        </div>

        <div class="last-update" id="last-update">
            Last updated: Never
        </div>
    </div>

    <script>
        let socket;
        let currentSessionId = null;
        let charts = {{}};

        function initSocket() {{
            socket = io();

            socket.on('connect', function() {{
                updateConnectionStatus('connected', 'CONNECTED');
                console.log('Connected to dashboard server');
            }});

            socket.on('disconnect', function() {{
                updateConnectionStatus('disconnected', 'DISCONNECTED');
                console.log('Disconnected from dashboard server');
            }});

            socket.on('connected', function(data) {{
                console.log('Server confirmed connection:', data);
            }});

            socket.on('initial_data', function(data) {{
                console.log('Received initial data:', data);
                updateDashboard(data);
            }});

            socket.on('realtime_update', function(data) {{
                console.log('Received real-time update:', data);
                updateDashboard(data);
            }});

            socket.on('session_joined', function(data) {{
                console.log('Joined session:', data);
                currentSessionId = data.session_id;
                document.getElementById('session-input').value = currentSessionId;
            }});

            socket.on('session_left', function(data) {{
                console.log('Left session:', data);
                currentSessionId = null;
                resetDashboard();
            }});

            socket.on('error', function(data) {{
                console.error('Socket error:', data);
                alert('Error: ' + data.message);
            }});
        }}

        function updateConnectionStatus(status, text) {{
            const statusEl = document.getElementById('connection-status');
            statusEl.className = 'connection-status ' + status;
            statusEl.textContent = text;
        }}

        function joinSession() {{
            const sessionId = document.getElementById('session-input').value.trim();
            if (sessionId) {{
                socket.emit('join_session', {{ session_id: sessionId }});
            }}
        }}

        function leaveSession() {{
            if (currentSessionId) {{
                socket.emit('leave_session', {{ session_id: currentSessionId }});
            }}
        }}

        function updateDashboard(data) {{
            if (data.metrics) {{
                updateStats(data.metrics);
                updateMetrics(data.metrics);
            }}

            if (data.charts) {{
                updateCharts(data.charts);
            }}

            document.getElementById('last-update').textContent =
                'Last updated: ' + new Date(data.timestamp).toLocaleTimeString();
        }}

        function updateStats(metrics) {{
            const stats = metrics.session_stats || {{}};
            const container = document.getElementById('stats-container');

            container.innerHTML = `
                <div class="stat-card">
                    <div class="stat-label">Total Boxes</div>
                    <div class="stat-value">${{stats.total_boxes || 0}}</div>
                </div>
                <div class="stat-card">
                    <div class="stat-label">Total Executions</div>
                    <div class="stat-value">${{stats.total_executions || 0}}</div>
                </div>
                <div class="stat-card">
                    <div class="stat-label">Avg Speed</div>
                    <div class="stat-value">${{stats.boxes_per_second ? stats.boxes_per_second.toFixed(2) : 0}}</div>
                    <small>boxes/sec</small>
                </div>
                <div class="stat-card">
                    <div class="stat-label">Avg Time</div>
                    <div class="stat-value">${{stats.avg_execution_time_ms ? stats.avg_execution_time_ms.toFixed(1) : 0}}</div>
                    <small>ms</small>
                </div>
            `;
        }}

        function updateMetrics(metrics) {{
            const sessionStats = metrics.session_stats || {{}};
            const performance = metrics.performance_metrics || {{}};
            const degradation = metrics.degradation_summary || {{}};

            // Session stats
            let sessionHtml = '';
            for (const [key, value] of Object.entries(sessionStats)) {{
                const displayKey = key.replace(/_/g, ' ').replace(/\\b\\w/g, l => l.toUpperCase());
                sessionHtml += `<div class="metric-item">
                    <span class="metric-label">${{displayKey}}:</span>
                    <span class="metric-value">${{value}}</span>
                </div>`;
            }}
            document.getElementById('session-stats').innerHTML = sessionHtml || 'No data available';

            // Performance metrics
            let perfHtml = '';
            for (const [key, value] of Object.entries(performance)) {{
                const displayKey = key.replace(/_/g, ' ').replace(/\\b\\w/g, l => l.toUpperCase());
                perfHtml += `<div class="metric-item">
                    <span class="metric-label">${{displayKey}}:</span>
                    <span class="metric-value">${{value}}</span>
                </div>`;
            }}
            document.getElementById('performance-metrics').innerHTML = perfHtml || 'No data available';

            // Degradation summary
            let degHtml = '';
            for (const [key, value] of Object.entries(degradation)) {{
                const displayKey = key.replace(/_/g, ' ').replace(/\\b\\w/g, l => l.toUpperCase());
                degHtml += `<div class="metric-item">
                    <span class="metric-label">${{displayKey}}:</span>
                    <span class="metric-value">${{value}}</span>
                </div>`;
            }}
            document.getElementById('degradation-summary').innerHTML = degHtml || 'No degradation data';
        }}

        function updateCharts(chartsData) {{
            if (!chartsData.charts) return;

            chartsData.charts.forEach(chart => {{
                const chartDiv = document.getElementById(chart.id);
                if (chartDiv) {{
                    try {{
                        const figure = JSON.parse(chart.data);
                        Plotly.newPlot(chart.id, figure.data, figure.layout || {{}});
                    }} catch (e) {{
                        console.error('Chart update error:', e);
                    }}
                }}
            }});
        }}

        function resetDashboard() {{
            document.getElementById('stats-container').innerHTML = `
                <div class="stat-card">
                    <div class="stat-label">Status</div>
                    <div class="stat-value">⏸️</div>
                    <small>Session ended</small>
                </div>
            `;

            document.getElementById('metrics-container').innerHTML = `
                <div class="metrics-card">
                    <h4>Session Statistics</h4>
                    <div>Session ended</div>
                </div>
                <div class="metrics-card">
                    <h4>Performance Metrics</h4>
                    <div>Session ended</div>
                </div>
                <div class="metrics-card">
                    <h4>Degradation Summary</h4>
                    <div>Session ended</div>
                </div>
            `;

            // Clear charts
            Plotly.purge('speed-chart');
            Plotly.purge('time-chart');
        }}

        // Initialize when page loads
        document.addEventListener('DOMContentLoaded', function() {{
            initSocket();

            document.getElementById('join-btn').addEventListener('click', joinSession);
            document.getElementById('leave-btn').addEventListener('click', leaveSession);

            document.getElementById('session-input').addEventListener('keypress', function(e) {{
                if (e.key === 'Enter') {{
                    joinSession();
                }}
            }});
        }});
    </script>
</body>
</html>
        """

    def run(self):
        """Start the dashboard server"""
        self.db.log_system_event('INFO', 'dashboard', f'Starting real-time dashboard on {self.host}:{self.port}')
        self.socketio.run(self.app, host=self.host, port=self.port, debug=False)

# Global dashboard instance
_dashboard_instance = None

def get_dashboard():
    """Get singleton dashboard instance"""
    global _dashboard_instance
    if _dashboard_instance is None:
        _dashboard_instance = RealtimeDashboard()
    return _dashboard_instance

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description='MacroMaster Real-Time Dashboard')
    parser.add_argument('--host', default='localhost', help='Host to bind to')
    parser.add_argument('--port', type=int, default=5002, help='Port to bind to')
    parser.add_argument('--ingestion-host', default='localhost', help='Data ingestion service host')
    parser.add_argument('--ingestion-port', type=int, default=5001, help='Data ingestion service port')

    args = parser.parse_args()

    dashboard = RealtimeDashboard(args.host, args.port, args.ingestion_host, args.ingestion_port)
    dashboard.run()