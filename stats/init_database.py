#!/usr/bin/env python3
"""
MacroMaster Stats Database Initialization
Creates SQLite database with optimized schema
"""

import sqlite3
import os
from pathlib import Path

def get_database_path():
    """Get the database path in Documents/MacroMaster/data"""
    documents_dir = Path.home() / "Documents" / "MacroMaster" / "data"
    documents_dir.mkdir(parents=True, exist_ok=True)
    return documents_dir / "macromaster_stats.db"

def initialize_database(db_path=None):
    """
    Initialize the SQLite database with schema

    Args:
        db_path: Optional custom database path. If None, uses default location.

    Returns:
        Path to the created database
    """
    if db_path is None:
        db_path = get_database_path()

    print(f"Initializing database at: {db_path}")

    # Read schema file
    schema_file = Path(__file__).parent / "database_schema.sql"
    with open(schema_file, 'r', encoding='utf-8') as f:
        schema_sql = f.read()

    # Create database and execute schema
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Execute schema (split by semicolon for multiple statements)
    cursor.executescript(schema_sql)

    conn.commit()

    # Verify tables were created
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")
    tables = cursor.fetchall()

    print(f"[OK] Database initialized successfully")
    print(f"[OK] Created {len(tables)} tables: {', '.join([t[0] for t in tables])}")

    # Check indexes
    cursor.execute("SELECT name FROM sqlite_master WHERE type='index' ORDER BY name")
    indexes = cursor.fetchall()
    print(f"[OK] Created {len(indexes)} indexes for performance")

    # Check views
    cursor.execute("SELECT name FROM sqlite_master WHERE type='view' ORDER BY name")
    views = cursor.fetchall()
    print(f"[OK] Created {len(views)} views for quick queries")

    conn.close()

    return db_path

def get_database_info(db_path=None):
    """Get information about the database"""
    if db_path is None:
        db_path = get_database_path()

    if not os.path.exists(db_path):
        return None

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Get record counts
    cursor.execute("SELECT COUNT(*) FROM executions")
    execution_count = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM degradations")
    degradation_count = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM sessions")
    session_count = cursor.fetchone()[0]

    # Get date range
    cursor.execute("SELECT MIN(timestamp), MAX(timestamp) FROM executions")
    date_range = cursor.fetchone()

    conn.close()

    return {
        'path': str(db_path),
        'executions': execution_count,
        'degradations': degradation_count,
        'sessions': session_count,
        'date_range': date_range,
        'size_mb': os.path.getsize(db_path) / (1024 * 1024)
    }

if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Initialize MacroMaster stats database")
    parser.add_argument("--path", help="Custom database path (optional)")
    parser.add_argument("--info", action="store_true", help="Show database info")
    args = parser.parse_args()

    if args.info:
        info = get_database_info(args.path)
        if info:
            print("\n=== Database Information ===")
            print(f"Path: {info['path']}")
            print(f"Executions: {info['executions']:,}")
            print(f"Degradations: {info['degradations']:,}")
            print(f"Sessions: {info['sessions']:,}")
            print(f"Date range: {info['date_range'][0]} to {info['date_range'][1]}")
            print(f"Size: {info['size_mb']:.2f} MB")
        else:
            print("Database does not exist yet. Run without --info to create it.")
    else:
        db_path = initialize_database(args.path)
        print(f"\nDatabase ready at: {db_path}")
        print("\nNext step: Run migrate_csv_to_db.py to import existing CSV data")
