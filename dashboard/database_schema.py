#!/usr/bin/env python3
"""
MacroMaster Real-Time Database Schema
SQLite-based data storage for user interactions, metrics, and real-time dashboard
"""

import sqlite3
import os
from datetime import datetime
import json

class MacroMasterDatabase:
    def __init__(self, db_path=None):
        if db_path is None:
            # Use Documents folder for portability
            documents_dir = os.path.join(os.path.expanduser("~"), "Documents", "MacroMaster")
            os.makedirs(documents_dir, exist_ok=True)
            db_path = os.path.join(documents_dir, "macromaster_realtime.db")

        self.db_path = db_path
        self.connection = None
        self.initialize_database()

    def get_connection(self):
        """Get database connection with row factory"""
        if self.connection is None:
            self.connection = sqlite3.connect(self.db_path, check_same_thread=False)
            self.connection.row_factory = sqlite3.Row
            # Enable WAL mode for better concurrency
            self.connection.execute("PRAGMA journal_mode=WAL")
            self.connection.execute("PRAGMA synchronous=NORMAL")
            self.connection.execute("PRAGMA cache_size=10000")
            self.connection.commit()
        return self.connection

    def initialize_database(self):
        """Create all database tables and indexes"""
        conn = self.get_connection()
        cursor = conn.cursor()

        # User sessions table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS user_sessions (
                session_id TEXT PRIMARY KEY,
                username TEXT NOT NULL,
                start_time TIMESTAMP NOT NULL,
                end_time TIMESTAMP,
                total_active_time_ms INTEGER DEFAULT 0,
                is_active BOOLEAN DEFAULT 1,
                canvas_mode TEXT DEFAULT 'wide',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')

        # User interactions table (replaces CSV logging)
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS user_interactions (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id TEXT NOT NULL,
                timestamp TIMESTAMP NOT NULL,
                interaction_type TEXT NOT NULL, -- 'macro_execution', 'key_press', 'mouse_click', etc.
                button_key TEXT,
                layer INTEGER,
                execution_time_ms INTEGER,
                total_boxes INTEGER DEFAULT 0,
                degradation_assignments TEXT, -- JSON string of degradation types
                severity_level TEXT DEFAULT 'medium',
                canvas_mode TEXT DEFAULT 'wide',
                session_active_time_ms INTEGER DEFAULT 0,
                break_mode_active BOOLEAN DEFAULT 0,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (session_id) REFERENCES user_sessions(session_id)
            )
        ''')

        # Degradation counts table (normalized for better queries)
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS degradation_counts (
                interaction_id INTEGER NOT NULL,
                degradation_type TEXT NOT NULL, -- 'smudge', 'glare', etc.
                count INTEGER DEFAULT 0,
                FOREIGN KEY (interaction_id) REFERENCES user_interactions(id) ON DELETE CASCADE
            )
        ''')

        # Real-time metrics cache table
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS realtime_metrics (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                session_id TEXT NOT NULL,
                metric_type TEXT NOT NULL, -- 'session_stats', 'performance', 'degradation_summary'
                metric_data TEXT NOT NULL, -- JSON data
                last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (session_id) REFERENCES user_sessions(session_id) ON DELETE CASCADE
            )
        ''')

        # System health and error logging
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS system_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                log_level TEXT NOT NULL, -- 'INFO', 'WARNING', 'ERROR', 'CRITICAL'
                component TEXT NOT NULL, -- 'database', 'dashboard', 'ahk_ingestion', etc.
                message TEXT NOT NULL,
                error_details TEXT,
                resolved BOOLEAN DEFAULT 0
            )
        ''')

        # Create indexes for performance
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_interactions_session_time ON user_interactions(session_id, timestamp)')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_interactions_type ON user_interactions(interaction_type)')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_sessions_active ON user_sessions(is_active)')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_metrics_session ON realtime_metrics(session_id)')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_logs_timestamp ON system_logs(timestamp)')
        cursor.execute('CREATE INDEX IF NOT EXISTS idx_degradation_interaction ON degradation_counts(interaction_id)')

        conn.commit()

        # Log successful initialization
        self.log_system_event('INFO', 'database', 'Database schema initialized successfully')

    def create_session(self, session_id, username, canvas_mode='wide'):
        """Create a new user session"""
        conn = self.get_connection()
        cursor = conn.cursor()

        try:
            cursor.execute('''
                INSERT INTO user_sessions (session_id, username, start_time, canvas_mode)
                VALUES (?, ?, ?, ?)
            ''', (session_id, username, datetime.now(), canvas_mode))

            conn.commit()
            self.log_system_event('INFO', 'database', f'Created session {session_id} for user {username}')
            return True
        except Exception as e:
            self.log_system_event('ERROR', 'database', f'Failed to create session: {str(e)}')
            return False

    def end_session(self, session_id):
        """End a user session"""
        conn = self.get_connection()
        cursor = conn.cursor()

        try:
            # Calculate total active time
            cursor.execute('''
                SELECT SUM(execution_time_ms) as total_time
                FROM user_interactions
                WHERE session_id = ?
            ''', (session_id,))

            result = cursor.fetchone()
            total_time = result['total_time'] if result and result['total_time'] else 0

            # Update session
            cursor.execute('''
                UPDATE user_sessions
                SET end_time = ?, total_active_time_ms = ?, is_active = 0
                WHERE session_id = ?
            ''', (datetime.now(), total_time, session_id))

            conn.commit()
            self.log_system_event('INFO', 'database', f'Ended session {session_id}')
            return True
        except Exception as e:
            self.log_system_event('ERROR', 'database', f'Failed to end session: {str(e)}')
            return False

    def record_interaction(self, session_id, interaction_data):
        """Record a user interaction (replaces CSV writing)"""
        conn = self.get_connection()
        cursor = conn.cursor()

        try:
            # Insert main interaction record
            cursor.execute('''
                INSERT INTO user_interactions (
                    session_id, timestamp, interaction_type, button_key, layer,
                    execution_time_ms, total_boxes, degradation_assignments,
                    severity_level, canvas_mode, session_active_time_ms, break_mode_active
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (
                session_id,
                interaction_data.get('timestamp', datetime.now()),
                interaction_data.get('interaction_type', 'unknown'),
                interaction_data.get('button_key'),
                interaction_data.get('layer'),
                interaction_data.get('execution_time_ms', 0),
                interaction_data.get('total_boxes', 0),
                interaction_data.get('degradation_assignments'),
                interaction_data.get('severity_level', 'medium'),
                interaction_data.get('canvas_mode', 'wide'),
                interaction_data.get('session_active_time_ms', 0),
                interaction_data.get('break_mode_active', False)
            ))

            interaction_id = cursor.lastrowid

            # Insert degradation counts if present
            degradation_counts = interaction_data.get('degradation_counts', {})
            for deg_type, count in degradation_counts.items():
                if count > 0:
                    cursor.execute('''
                        INSERT INTO degradation_counts (interaction_id, degradation_type, count)
                        VALUES (?, ?, ?)
                    ''', (interaction_id, deg_type, count))

            conn.commit()

            # Update real-time metrics cache
            self.update_realtime_metrics(session_id)

            return interaction_id

        except Exception as e:
            self.log_system_event('ERROR', 'database', f'Failed to record interaction: {str(e)}')
            conn.rollback()
            return None

    def update_realtime_metrics(self, session_id):
        """Update cached metrics for real-time dashboard"""
        conn = self.get_connection()
        cursor = conn.cursor()

        try:
            # Calculate session stats for last 24 hours
            cutoff_time = datetime.now().replace(hour=datetime.now().hour-24)

            # Get session statistics
            cursor.execute('''
                SELECT
                    COUNT(*) as total_executions,
                    SUM(total_boxes) as total_boxes,
                    SUM(execution_time_ms) as total_time,
                    AVG(execution_time_ms) as avg_time,
                    MAX(timestamp) as last_activity
                FROM user_interactions
                WHERE session_id = ? AND timestamp >= ?
            ''', (session_id, cutoff_time))

            stats = cursor.fetchone()

            # Get degradation summary
            cursor.execute('''
                SELECT degradation_type, SUM(count) as total_count
                FROM degradation_counts dc
                JOIN user_interactions ui ON dc.interaction_id = ui.id
                WHERE ui.session_id = ? AND ui.timestamp >= ?
                GROUP BY degradation_type
            ''', (session_id, cutoff_time))

            degradation_summary = {row['degradation_type']: row['total_count'] for row in cursor.fetchall()}

            # Calculate performance metrics
            total_boxes = stats['total_boxes'] or 0
            total_time = stats['total_time'] or 0
            avg_time = stats['avg_time'] or 0

            metrics_data = {
                'session_stats': {
                    'total_executions': stats['total_executions'] or 0,
                    'total_boxes': total_boxes,
                    'total_time_ms': total_time,
                    'avg_execution_time_ms': round(avg_time, 1),
                    'boxes_per_second': round(total_boxes / max(total_time/1000, 1), 2),
                    'last_activity': stats['last_activity'].isoformat() if stats['last_activity'] else None
                },
                'degradation_summary': degradation_summary,
                'performance_metrics': {
                    'efficiency_score': round(total_boxes / max(stats['total_executions'] or 1, 1), 2),
                    'avg_boxes_per_execution': round(total_boxes / max(stats['total_executions'] or 1, 1), 2)
                }
            }

            # Update or insert metrics cache
            cursor.execute('''
                INSERT OR REPLACE INTO realtime_metrics (session_id, metric_type, metric_data, last_updated)
                VALUES (?, ?, ?, ?)
            ''', (session_id, 'session_metrics', json.dumps(metrics_data), datetime.now()))

            conn.commit()

        except Exception as e:
            self.log_system_event('ERROR', 'database', f'Failed to update metrics: {str(e)}')

    def get_realtime_metrics(self, session_id):
        """Get cached real-time metrics for dashboard"""
        conn = self.get_connection()
        cursor = conn.cursor()

        try:
            cursor.execute('''
                SELECT metric_data, last_updated
                FROM realtime_metrics
                WHERE session_id = ? AND metric_type = 'session_metrics'
            ''', (session_id,))

            result = cursor.fetchone()
            if result:
                return {
                    'data': json.loads(result['metric_data']),
                    'last_updated': result['last_updated']
                }
            return None

        except Exception as e:
            self.log_system_event('ERROR', 'database', f'Failed to get metrics: {str(e)}')
            return None

    def get_recent_interactions(self, session_id, limit=100):
        """Get recent interactions for dashboard charts"""
        conn = self.get_connection()
        cursor = conn.cursor()

        try:
            cursor.execute('''
                SELECT timestamp, interaction_type, button_key, execution_time_ms, total_boxes
                FROM user_interactions
                WHERE session_id = ?
                ORDER BY timestamp DESC
                LIMIT ?
            ''', (session_id, limit))

            return [dict(row) for row in cursor.fetchall()]

        except Exception as e:
            self.log_system_event('ERROR', 'database', f'Failed to get interactions: {str(e)}')
            return []

    def log_system_event(self, level, component, message, error_details=None):
        """Log system events for monitoring and debugging"""
        conn = self.get_connection()
        cursor = conn.cursor()

        try:
            cursor.execute('''
                INSERT INTO system_logs (log_level, component, message, error_details)
                VALUES (?, ?, ?, ?)
            ''', (level, component, message, error_details))

            conn.commit()
        except Exception as e:
            # If logging fails, print to console as fallback
            print(f"[{level}] {component}: {message}")

    def cleanup_old_data(self, days_to_keep=30):
        """Clean up old data to prevent database bloat"""
        conn = self.get_connection()
        cursor = conn.cursor()

        try:
            cutoff_date = datetime.now().replace(day=datetime.now().day - days_to_keep)

            # Delete old interactions (keep recent data)
            cursor.execute('DELETE FROM user_interactions WHERE timestamp < ?', (cutoff_date,))

            # Delete old sessions
            cursor.execute('DELETE FROM user_sessions WHERE start_time < ? AND is_active = 0', (cutoff_date,))

            # Clean up old logs (keep last 1000 entries)
            cursor.execute('''
                DELETE FROM system_logs
                WHERE id NOT IN (
                    SELECT id FROM system_logs ORDER BY timestamp DESC LIMIT 1000
                )
            ''')

            deleted_count = cursor.rowcount
            conn.commit()

            self.log_system_event('INFO', 'database', f'Cleaned up {deleted_count} old records')

        except Exception as e:
            self.log_system_event('ERROR', 'database', f'Cleanup failed: {str(e)}')

    def backup_database(self):
        """Create a backup of the database"""
        try:
            backup_path = self.db_path + '.backup'
            conn = self.get_connection()

            # Use SQLite backup API for safe backup
            backup_conn = sqlite3.connect(backup_path)
            conn.backup(backup_conn)
            backup_conn.close()

            self.log_system_event('INFO', 'database', f'Database backed up to {backup_path}')
            return backup_path

        except Exception as e:
            self.log_system_event('ERROR', 'database', f'Backup failed: {str(e)}')
            return None

    def close(self):
        """Close database connection"""
        if self.connection:
            self.connection.close()
            self.connection = None

# Global database instance
_db_instance = None

def get_database():
    """Get singleton database instance"""
    global _db_instance
    if _db_instance is None:
        _db_instance = MacroMasterDatabase()
    return _db_instance

if __name__ == "__main__":
    # Test database initialization
    db = get_database()
    print("Database initialized successfully")
    db.close()