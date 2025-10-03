#!/usr/bin/env python3
"""
MacroMaster CSV to SQLite Migration Script
Migrates existing master_stats.csv data to the new SQLite database
"""

import sqlite3
import csv
from pathlib import Path
from datetime import datetime
import re

def get_paths():
    """Get paths for CSV and database"""
    documents_dir = Path.home() / "Documents" / "MacroMaster" / "data"
    csv_path = documents_dir / "master_stats.csv"
    db_path = documents_dir / "macromaster_stats.db"
    return csv_path, db_path

def parse_degradation_string(degradation_str):
    """
    Parse degradation assignments string into list of types

    Args:
        degradation_str: String like 'smudge,glare' or 'clear' or ''

    Returns:
        List of degradation types
    """
    if not degradation_str or degradation_str.strip() == '' or degradation_str.strip().lower() == 'clear':
        return ['clear']

    # Clean up the string - remove quotes and split by comma
    cleaned = degradation_str.strip().strip('"\'')
    degradations = [d.strip() for d in cleaned.split(',') if d.strip()]

    return degradations if degradations else ['clear']

def parse_degradation_counts(row):
    """
    Parse individual degradation counts from CSV row

    Args:
        row: Dictionary of CSV row data

    Returns:
        Dictionary mapping degradation type to count
    """
    degradation_map = {
        'smudge': int(row.get('smudge_count', 0) or 0),
        'glare': int(row.get('glare_count', 0) or 0),
        'splashes': int(row.get('splashes_count', 0) or 0),
        'partial_blockage': int(row.get('partial_blockage_count', 0) or 0),
        'full_blockage': int(row.get('full_blockage_count', 0) or 0),
        'light_flare': int(row.get('light_flare_count', 0) or 0),
        'rain': int(row.get('rain_count', 0) or 0),
        'haze': int(row.get('haze_count', 0) or 0),
        'snow': int(row.get('snow_count', 0) or 0),
        'clear': int(row.get('clear_count', 0) or 0),
    }

    # Filter out zeros
    return {k: v for k, v in degradation_map.items() if v > 0}

def migrate_csv_to_database(csv_path, db_path, verbose=True):
    """
    Migrate CSV data to SQLite database

    Args:
        csv_path: Path to master_stats.csv
        db_path: Path to macromaster_stats.db
        verbose: Print progress messages

    Returns:
        Dictionary with migration statistics
    """
    if not csv_path.exists():
        raise FileNotFoundError(f"CSV file not found: {csv_path}")

    if not db_path.exists():
        raise FileNotFoundError(f"Database not found: {db_path}. Run init_database.py first.")

    # Connect to database
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Track sessions for session table
    sessions = {}

    # Statistics
    stats = {
        'rows_processed': 0,
        'executions_inserted': 0,
        'degradations_inserted': 0,
        'sessions_tracked': 0,
        'errors': 0
    }

    if verbose:
        print(f"Reading CSV from: {csv_path}")

    # Read and process CSV
    with open(csv_path, 'r', encoding='utf-8-sig') as csvfile:
        reader = csv.DictReader(csvfile)

        for row_num, row in enumerate(reader, start=2):  # Start at 2 (header is line 1)
            stats['rows_processed'] += 1

            try:
                # Extract core fields
                timestamp = row['timestamp']
                session_id = row['session_id']
                username = row['username']
                execution_type = row['execution_type']
                button_key = row.get('button_key', '')
                layer = int(row['layer']) if row['layer'] else 1
                execution_time_ms = int(row['execution_time_ms']) if row['execution_time_ms'] else 0
                total_boxes = int(row['total_boxes']) if row['total_boxes'] else 0
                degradation_assignments = row.get('degradation_assignments', '')
                severity_level = row.get('severity_level', 'medium')
                canvas_mode = row.get('canvas_mode', 'wide')
                session_active_time_ms = int(row['session_active_time_ms']) if row['session_active_time_ms'] else 0
                break_mode_active = row.get('break_mode_active', 'false').lower() == 'true'
                annotation_details = row.get('annotation_details', '')
                execution_success = row.get('execution_success', 'true').lower() == 'true'
                error_details = row.get('error_details', '')

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
                stats['executions_inserted'] += 1

                # Parse and insert degradation counts
                degradation_counts = parse_degradation_counts(row)

                for deg_type, count in degradation_counts.items():
                    if count > 0:
                        cursor.execute("""
                            INSERT INTO degradations (execution_id, degradation_type, count)
                            VALUES (?, ?, ?)
                        """, (execution_id, deg_type, count))
                        stats['degradations_inserted'] += 1

                # Track session data
                if session_id not in sessions:
                    sessions[session_id] = {
                        'username': username,
                        'start_time': timestamp,
                        'end_time': timestamp,
                        'total_executions': 0,
                        'total_boxes': 0,
                        'total_active_time_ms': session_active_time_ms
                    }

                sessions[session_id]['end_time'] = timestamp
                sessions[session_id]['total_executions'] += 1
                sessions[session_id]['total_boxes'] += total_boxes
                sessions[session_id]['total_active_time_ms'] = max(
                    sessions[session_id]['total_active_time_ms'],
                    session_active_time_ms
                )

                if verbose and stats['rows_processed'] % 100 == 0:
                    print(f"  Processed {stats['rows_processed']} rows...")

            except Exception as e:
                stats['errors'] += 1
                if verbose:
                    print(f"  [WARN] Error on row {row_num}: {str(e)}")
                continue

    # Insert session records
    if verbose:
        print(f"\nInserting {len(sessions)} session records...")

    for session_id, session_data in sessions.items():
        try:
            cursor.execute("""
                INSERT OR REPLACE INTO sessions (
                    session_id, username, start_time, end_time,
                    total_executions, total_boxes, total_active_time_ms
                ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """, (
                session_id,
                session_data['username'],
                session_data['start_time'],
                session_data['end_time'],
                session_data['total_executions'],
                session_data['total_boxes'],
                session_data['total_active_time_ms']
            ))
            stats['sessions_tracked'] += 1
        except Exception as e:
            if verbose:
                print(f"  [WARN] Error inserting session {session_id}: {str(e)}")

    # Commit all changes
    conn.commit()
    conn.close()

    return stats

def verify_migration(db_path):
    """Verify the migration was successful"""
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Get counts
    cursor.execute("SELECT COUNT(*) FROM executions")
    exec_count = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM degradations")
    deg_count = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM sessions")
    sess_count = cursor.fetchone()[0]

    # Get sample data
    cursor.execute("""
        SELECT execution_type, COUNT(*) as count
        FROM executions
        GROUP BY execution_type
    """)
    exec_types = cursor.fetchall()

    cursor.execute("""
        SELECT degradation_type, SUM(count) as total
        FROM degradations
        GROUP BY degradation_type
        ORDER BY total DESC
    """)
    deg_types = cursor.fetchall()

    conn.close()

    return {
        'executions': exec_count,
        'degradations': deg_count,
        'sessions': sess_count,
        'execution_types': exec_types,
        'degradation_types': deg_types
    }

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Migrate CSV data to SQLite database")
    parser.add_argument("--csv", help="Custom CSV path (optional)")
    parser.add_argument("--db", help="Custom database path (optional)")
    parser.add_argument("--quiet", action="store_true", help="Suppress progress messages")
    args = parser.parse_args()

    # Get paths
    if args.csv and args.db:
        csv_path = Path(args.csv)
        db_path = Path(args.db)
    else:
        csv_path, db_path = get_paths()

    print("=" * 60)
    print("MacroMaster CSV to SQLite Migration")
    print("=" * 60)
    print(f"CSV: {csv_path}")
    print(f"Database: {db_path}")
    print()

    try:
        # Run migration
        stats = migrate_csv_to_database(csv_path, db_path, verbose=not args.quiet)

        print("\n" + "=" * 60)
        print("Migration Complete!")
        print("=" * 60)
        print(f"[OK] Rows processed: {stats['rows_processed']}")
        print(f"[OK] Executions inserted: {stats['executions_inserted']}")
        print(f"[OK] Degradations inserted: {stats['degradations_inserted']}")
        print(f"[OK] Sessions tracked: {stats['sessions_tracked']}")
        if stats['errors'] > 0:
            print(f"[WARN] Errors encountered: {stats['errors']}")

        # Verify migration
        print("\nVerifying migration...")
        verification = verify_migration(db_path)

        print(f"\n[OK] Database contains {verification['executions']} executions")
        print(f"[OK] Database contains {verification['degradations']} degradation records")
        print(f"[OK] Database contains {verification['sessions']} sessions")

        if verification['execution_types']:
            print("\nExecution type breakdown:")
            for exec_type, count in verification['execution_types']:
                print(f"  - {exec_type}: {count}")

        if verification['degradation_types']:
            print("\nTop degradation types:")
            for deg_type, total in verification['degradation_types'][:5]:
                print(f"  - {deg_type}: {total}")

        print("\n[OK] Migration successful!")

    except FileNotFoundError as e:
        print(f"\n[ERROR] {str(e)}")
        exit(1)
    except Exception as e:
        print(f"\n[ERROR] Migration failed: {str(e)}")
        import traceback
        traceback.print_exc()
        exit(1)
