#!/usr/bin/env python3
"""
MacroMaster Data Ingestion Service
HTTP service for real-time data ingestion from AHK script to database
"""

from flask import Flask, request, jsonify
import json
import threading
import time
from datetime import datetime
import os
import sys

# Add current directory to path for imports
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from database_schema import get_database

class DataIngestionService:
    def __init__(self, host='localhost', port=5001):
        self.host = host
        self.port = port
        self.app = Flask(__name__)
        self.db = get_database()
        self.setup_routes()
        self.server_thread = None
        self.running = False

    def setup_routes(self):
        @self.app.route('/health', methods=['GET'])
        def health_check():
            """Health check endpoint"""
            return jsonify({
                'status': 'healthy',
                'timestamp': datetime.now().isoformat(),
                'service': 'data_ingestion'
            })

        @self.app.route('/ingest/interaction', methods=['POST'])
        def ingest_interaction():
            """Ingest user interaction data from AHK"""
            try:
                data = request.get_json()

                if not data:
                    return jsonify({'error': 'No data provided'}), 400

                # Validate required fields
                required_fields = ['session_id', 'interaction_type']
                for field in required_fields:
                    if field not in data:
                        return jsonify({'error': f'Missing required field: {field}'}), 400

                # Record the interaction
                interaction_id = self.db.record_interaction(data['session_id'], data)

                if interaction_id:
                    return jsonify({
                        'status': 'success',
                        'interaction_id': interaction_id,
                        'timestamp': datetime.now().isoformat()
                    }), 200
                else:
                    return jsonify({'error': 'Failed to record interaction'}), 500

            except Exception as e:
                self.db.log_system_event('ERROR', 'ingestion_service', f'Ingestion error: {str(e)}', str(data) if 'data' in locals() else None)
                return jsonify({'error': str(e)}), 500

        @self.app.route('/session/start', methods=['POST'])
        def start_session():
            """Start a new user session"""
            try:
                data = request.get_json()

                if not data or 'session_id' not in data or 'username' not in data:
                    return jsonify({'error': 'Missing session_id or username'}), 400

                success = self.db.create_session(
                    data['session_id'],
                    data['username'],
                    data.get('canvas_mode', 'wide')
                )

                if success:
                    return jsonify({
                        'status': 'success',
                        'message': f'Session {data["session_id"]} started',
                        'timestamp': datetime.now().isoformat()
                    }), 200
                else:
                    return jsonify({'error': 'Failed to create session'}), 500

            except Exception as e:
                self.db.log_system_event('ERROR', 'ingestion_service', f'Session start error: {str(e)}')
                return jsonify({'error': str(e)}), 500

        @self.app.route('/session/end', methods=['POST'])
        def end_session():
            """End a user session"""
            try:
                data = request.get_json()

                if not data or 'session_id' not in data:
                    return jsonify({'error': 'Missing session_id'}), 400

                success = self.db.end_session(data['session_id'])

                if success:
                    return jsonify({
                        'status': 'success',
                        'message': f'Session {data["session_id"]} ended',
                        'timestamp': datetime.now().isoformat()
                    }), 200
                else:
                    return jsonify({'error': 'Failed to end session'}), 500

            except Exception as e:
                self.db.log_system_event('ERROR', 'ingestion_service', f'Session end error: {str(e)}')
                return jsonify({'error': str(e)}), 500

        @self.app.route('/metrics/<session_id>', methods=['GET'])
        def get_metrics(session_id):
            """Get real-time metrics for a session"""
            try:
                metrics = self.db.get_realtime_metrics(session_id)

                if metrics:
                    return jsonify({
                        'status': 'success',
                        'metrics': metrics['data'],
                        'last_updated': metrics['last_updated'].isoformat() if metrics['last_updated'] else None
                    }), 200
                else:
                    return jsonify({
                        'status': 'success',
                        'metrics': None,
                        'message': 'No metrics available'
                    }), 200

            except Exception as e:
                self.db.log_system_event('ERROR', 'ingestion_service', f'Metrics retrieval error: {str(e)}')
                return jsonify({'error': str(e)}), 500

        @self.app.route('/interactions/<session_id>', methods=['GET'])
        def get_interactions(session_id):
            """Get recent interactions for a session"""
            try:
                limit = int(request.args.get('limit', 100))
                interactions = self.db.get_recent_interactions(session_id, limit)

                return jsonify({
                    'status': 'success',
                    'interactions': interactions,
                    'count': len(interactions)
                }), 200

            except Exception as e:
                self.db.log_system_event('ERROR', 'ingestion_service', f'Interactions retrieval error: {str(e)}')
                return jsonify({'error': str(e)}), 500

        @self.app.route('/maintenance/cleanup', methods=['POST'])
        def cleanup_old_data():
            """Clean up old data"""
            try:
                days = int(request.args.get('days', 30))
                self.db.cleanup_old_data(days)

                return jsonify({
                    'status': 'success',
                    'message': f'Cleaned up data older than {days} days',
                    'timestamp': datetime.now().isoformat()
                }), 200

            except Exception as e:
                self.db.log_system_event('ERROR', 'ingestion_service', f'Cleanup error: {str(e)}')
                return jsonify({'error': str(e)}), 500

        @self.app.route('/maintenance/backup', methods=['POST'])
        def create_backup():
            """Create database backup"""
            try:
                backup_path = self.db.backup_database()

                if backup_path:
                    return jsonify({
                        'status': 'success',
                        'backup_path': backup_path,
                        'timestamp': datetime.now().isoformat()
                    }), 200
                else:
                    return jsonify({'error': 'Backup failed'}), 500

            except Exception as e:
                self.db.log_system_event('ERROR', 'ingestion_service', f'Backup error: {str(e)}')
                return jsonify({'error': str(e)}), 500

    def start(self):
        """Start the ingestion service"""
        if self.running:
            return

        self.running = True

        def run_server():
            try:
                self.db.log_system_event('INFO', 'ingestion_service', f'Starting data ingestion service on {self.host}:{self.port}')
                self.app.run(host=self.host, port=self.port, debug=False, threaded=True)
            except Exception as e:
                self.db.log_system_event('ERROR', 'ingestion_service', f'Service startup failed: {str(e)}')
            finally:
                self.running = False

        self.server_thread = threading.Thread(target=run_server, daemon=True)
        self.server_thread.start()

        # Wait a moment for server to start
        time.sleep(1)

        if self.server_thread.is_alive():
            self.db.log_system_event('INFO', 'ingestion_service', 'Data ingestion service started successfully')
            return True
        else:
            self.db.log_system_event('ERROR', 'ingestion_service', 'Failed to start data ingestion service')
            return False

    def stop(self):
        """Stop the ingestion service"""
        if not self.running:
            return

        self.running = False
        self.db.log_system_event('INFO', 'ingestion_service', 'Data ingestion service stopped')

    def is_running(self):
        """Check if service is running"""
        return self.running and self.server_thread and self.server_thread.is_alive()

# Global service instance
_ingestion_service = None

def get_ingestion_service():
    """Get singleton ingestion service instance"""
    global _ingestion_service
    if _ingestion_service is None:
        _ingestion_service = DataIngestionService()
    return _ingestion_service

def start_service():
    """Start the data ingestion service"""
    service = get_ingestion_service()
    return service.start()

def stop_service():
    """Stop the data ingestion service"""
    global _ingestion_service
    if _ingestion_service:
        _ingestion_service.stop()
        _ingestion_service = None

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description='MacroMaster Data Ingestion Service')
    parser.add_argument('--host', default='localhost', help='Host to bind to')
    parser.add_argument('--port', type=int, default=5001, help='Port to bind to')

    args = parser.parse_args()

    service = DataIngestionService(args.host, args.port)

    try:
        print(f"Starting MacroMaster Data Ingestion Service on {args.host}:{args.port}")
        service.start()

        # Keep running until interrupted
        while service.is_running():
            time.sleep(1)

    except KeyboardInterrupt:
        print("Stopping service...")
        service.stop()
    except Exception as e:
        print(f"Service error: {e}")
        service.stop()