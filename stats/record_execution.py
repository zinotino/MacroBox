#!/usr/bin/env python3
"""
MacroMaster Stats Recording
Insert new execution stats into the SQLite database
"""

import sqlite3
import json
from pathlib import Path
from datetime import datetime
import sys

def get_database_path():
    """Get the database path in Documents/MacroMaster/data"""
    documents_dir = Path.home() / "Documents" / "MacroMaster" / "data"
    return documents_dir / "macromaster_stats.db"

def parse_degradation_data(execution_data):
    """
    Parse degradation data from execution record

    Args:
        execution_data: Dictionary with execution stats

    Returns:
        Dictionary mapping degradation type to count
    """
    degradations = {}

    # Check if we have individual count fields
    count_fields = [
        'smudge_count', 'glare_count', 'splashes_count',
        'partial_blockage_count', 'full_blockage_count',
        'light_flare_count', 'rain_count', 'haze_count',
        'snow_count', 'clear_count'
    ]

    for field in count_fields:
        if field in execution_data:
            count = int(execution_data[field])
            if count > 0:
                # Convert field name to degradation type (remove '_count' suffix)
                deg_type = field.replace('_count', '')
                degradations[deg_type] = count

    # If no count fields, parse from degradation_assignments string
    if not degradations:
        deg_str = execution_data.get('degradation_assignments', '')
        if deg_str and deg_str.strip() and deg_str.strip().lower() != 'clear':
            # Split by comma and count each type
            for deg in deg_str.split(','):
                deg = deg.strip().strip('"\'')
                if deg:
                    degradations[deg] = degradations.get(deg, 0) + 1
        else:
            # Default to clear if nothing specified
            degradations['clear'] = execution_data.get('total_boxes', 1)

    return degradations

def record_execution(execution_data, db_path=None):
    """
    Record a new execution to the database

    Args:
        execution_data: Dictionary with execution statistics
        db_path: Optional custom database path

    Returns:
        Execution ID of inserted record, or None on error
    """
    if db_path is None:
        db_path = get_database_path()

    if not db_path.exists():
        print(f"[ERROR] Database not found at {db_path}")
        print("Run init_database.py first")
        return None

    try:
        conn = sqlite3.connect(db_path)
        cursor = conn.cursor()

        # Extract execution fields
        timestamp = execution_data.get('timestamp', datetime.now().strftime('%Y-%m-%d %H:%M:%S'))
        session_id = execution_data.get('session_id', '')
        username = execution_data.get('username', '')
        execution_type = execution_data.get('execution_type', 'macro')
        button_key = execution_data.get('button_key', '')
        layer = int(execution_data.get('layer', 1))
        execution_time_ms = int(execution_data.get('execution_time_ms', 0))
        total_boxes = int(execution_data.get('total_boxes', 0))
        degradation_assignments = execution_data.get('degradation_assignments', '')
        severity_level = execution_data.get('severity_level', 'medium')
        canvas_mode = execution_data.get('canvas_mode', 'wide')
        session_active_time_ms = int(execution_data.get('session_active_time_ms', 0))
        break_mode_active = execution_data.get('break_mode_active', False)
        if isinstance(break_mode_active, str):
            break_mode_active = break_mode_active.lower() == 'true'
        annotation_details = execution_data.get('annotation_details', '')
        execution_success = execution_data.get('execution_success', True)
        if isinstance(execution_success, str):
            execution_success = execution_success.lower() == 'true'
        error_details = execution_data.get('error_details', '')

        # Insert execution record
        cursor.execute("""
            INSERT INTO executions (
                timestamp, session_id, username, execution_type, button_key,
                layer, execution_time_ms, total_boxes, degradation_assignments,
                severity_level, canvas_mode, session_active_time_ms, break_mode_active,
                annotation_details, execution_success, error_details
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (
            timestamp, session_id, username, execution_type, button_key,
            layer, execution_time_ms, total_boxes, degradation_assignments,
            severity_level, canvas_mode, session_active_time_ms, break_mode_active,
            annotation_details, execution_success, error_details
        ))

        execution_id = cursor.lastrowid

        # Parse and insert degradation data
        degradations = parse_degradation_data(execution_data)
        for deg_type, count in degradations.items():
            cursor.execute("""
                INSERT INTO degradations (execution_id, degradation_type, count)
                VALUES (?, ?, ?)
            """, (execution_id, deg_type, count))

        # Update or insert session record
        cursor.execute("""
            INSERT INTO sessions (session_id, username, start_time, end_time, total_executions, total_boxes, total_active_time_ms)
            VALUES (?, ?, ?, ?, 1, ?, ?)
            ON CONFLICT(session_id) DO UPDATE SET
                end_time = excluded.end_time,
                total_executions = total_executions + 1,
                total_boxes = total_boxes + excluded.total_boxes,
                total_active_time_ms = excluded.total_active_time_ms
        """, (session_id, username, timestamp, timestamp, total_boxes, session_active_time_ms))

        conn.commit()
        conn.close()

        return execution_id

    except Exception as e:
        print(f"[ERROR] Failed to record execution: {str(e)}")
        import traceback
        traceback.print_exc()
        return None

def record_execution_from_json(json_str, db_path=None):
    """
    Record execution from JSON string

    Args:
        json_str: JSON string with execution data
        db_path: Optional custom database path

    Returns:
        Execution ID or None on error
    """
    try:
        execution_data = json.loads(json_str)
        return record_execution(execution_data, db_path)
    except json.JSONDecodeError as e:
        print(f"[ERROR] Invalid JSON: {str(e)}")
        return None

def record_execution_from_csv_row(csv_row, db_path=None):
    """
    Record execution from CSV-formatted data (for backward compatibility)

    Args:
        csv_row: Dictionary with CSV column names as keys
        db_path: Optional custom database path

    Returns:
        Execution ID or None on error
    """
    # CSV row uses same field names as our database
    return record_execution(csv_row, db_path)

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Record macro execution statistics")
    parser.add_argument("--data", help="JSON string with execution data")
    parser.add_argument("--file", help="JSON file with execution data")
    parser.add_argument("--db", help="Custom database path (optional)")
    args = parser.parse_args()

    if not args.data and not args.file:
        print("[ERROR] Must provide --data or --file")
        print("\nUsage:")
        print("  python record_execution.py --data '{\"timestamp\": \"...\", ...}'")
        print("  python record_execution.py --file execution_data.json")
        sys.exit(1)

    # Get execution data
    if args.file:
        with open(args.file, 'r', encoding='utf-8') as f:
            execution_data = json.load(f)
    else:
        execution_data = json.loads(args.data)

    # Record to database
    execution_id = record_execution(execution_data, args.db)

    if execution_id:
        print(f"[OK] Recorded execution #{execution_id}")
        sys.exit(0)
    else:
        print("[ERROR] Failed to record execution")
        sys.exit(1)
