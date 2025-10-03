#!/usr/bin/env python3
"""
Test script for MacroMaster stats database
"""

import sqlite3
from pathlib import Path
from datetime import datetime, timedelta
import json
from record_execution import record_execution, get_database_path

def run_tests():
    """Run comprehensive database tests"""
    db_path = get_database_path()

    if not db_path.exists():
        print("[ERROR] Database not found. Run init_database.py first.")
        return False

    print("=" * 60)
    print("MacroMaster Database Tests")
    print("=" * 60)
    print(f"Database: {db_path}\n")

    # Test 1: Check current state
    print("Test 1: Database Current State")
    print("-" * 60)
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    cursor.execute("SELECT COUNT(*) FROM executions")
    exec_count = cursor.fetchone()[0]
    print(f"  Current executions: {exec_count}")

    cursor.execute("SELECT COUNT(*) FROM degradations")
    deg_count = cursor.fetchone()[0]
    print(f"  Current degradations: {deg_count}")

    cursor.execute("SELECT COUNT(*) FROM sessions")
    sess_count = cursor.fetchone()[0]
    print(f"  Current sessions: {sess_count}")

    conn.close()
    print("  [PASS]\n")

    # Test 2: Insert a test execution
    print("Test 2: Insert New Execution")
    print("-" * 60)

    test_execution = {
        'timestamp': datetime.now().strftime('%Y-%m-%d %H:%M:%S'),
        'session_id': 'test_session_001',
        'username': 'test_user',
        'execution_type': 'macro',
        'button_key': 'TestButton',
        'layer': 1,
        'execution_time_ms': 450,
        'total_boxes': 3,
        'degradation_assignments': 'smudge,glare',
        'severity_level': 'medium',
        'canvas_mode': 'wide',
        'session_active_time_ms': 60000,
        'break_mode_active': False,
        'smudge_count': 2,
        'glare_count': 1,
        'annotation_details': 'Test execution',
        'execution_success': True,
        'error_details': ''
    }

    exec_id = record_execution(test_execution)
    if exec_id:
        print(f"  Inserted execution ID: {exec_id}")
        print("  [PASS]\n")
    else:
        print("  [FAIL]\n")
        return False

    # Test 3: Query the inserted execution
    print("Test 3: Query Inserted Execution")
    print("-" * 60)

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    cursor.execute("SELECT * FROM executions WHERE id = ?", (exec_id,))
    row = cursor.fetchone()
    if row:
        print(f"  Found execution: {row[4]} on layer {row[6]}")  # button_key, layer

        # Check degradations
        cursor.execute("""
            SELECT degradation_type, count
            FROM degradations
            WHERE execution_id = ?
            ORDER BY degradation_type
        """, (exec_id,))
        degs = cursor.fetchall()
        print(f"  Degradations recorded: {len(degs)}")
        for deg_type, count in degs:
            print(f"    - {deg_type}: {count}")

        print("  [PASS]\n")
    else:
        print("  [FAIL] Could not find inserted execution\n")
        conn.close()
        return False

    conn.close()

    # Test 4: Test degradation summary view
    print("Test 4: Degradation Summary View")
    print("-" * 60)

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    cursor.execute("""
        SELECT degradation_type, total_count, execution_count
        FROM degradation_summary
        ORDER BY total_count DESC
        LIMIT 5
    """)
    summary = cursor.fetchall()
    print(f"  Top degradation types:")
    for deg_type, total, exec_count in summary:
        print(f"    - {deg_type}: {total} occurrences in {exec_count} executions")

    conn.close()
    print("  [PASS]\n")

    # Test 5: Test timeline filtering
    print("Test 5: Timeline Filtering")
    print("-" * 60)

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    # Get executions from last 24 hours
    yesterday = (datetime.now() - timedelta(days=1)).strftime('%Y-%m-%d %H:%M:%S')
    cursor.execute("""
        SELECT COUNT(*) FROM executions
        WHERE timestamp >= ?
    """, (yesterday,))
    recent_count = cursor.fetchone()[0]
    print(f"  Executions in last 24 hours: {recent_count}")

    # Get executions by type
    cursor.execute("""
        SELECT execution_type, COUNT(*) as count
        FROM executions
        WHERE timestamp >= ?
        GROUP BY execution_type
    """, (yesterday,))
    type_counts = cursor.fetchall()
    print(f"  Breakdown by type:")
    for exec_type, count in type_counts:
        print(f"    - {exec_type}: {count}")

    conn.close()
    print("  [PASS]\n")

    # Test 6: Test performance (indexed queries)
    print("Test 6: Query Performance (Indexed)")
    print("-" * 60)

    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    import time

    # Test indexed timestamp query
    start = time.time()
    cursor.execute("""
        SELECT COUNT(*), AVG(execution_time_ms)
        FROM executions
        WHERE timestamp >= ?
    """, (yesterday,))
    result = cursor.fetchone()
    elapsed = (time.time() - start) * 1000

    print(f"  Timestamp range query: {elapsed:.2f}ms")
    print(f"    Count: {result[0]}, Avg time: {result[1]:.1f}ms")

    # Test indexed degradation query
    start = time.time()
    cursor.execute("""
        SELECT degradation_type, COUNT(*)
        FROM degradations
        WHERE degradation_type = 'clear'
    """)
    result = cursor.fetchone()
    elapsed = (time.time() - start) * 1000

    print(f"  Degradation type query: {elapsed:.2f}ms")
    print(f"    Clear count: {result[1] if result else 0}")

    conn.close()
    print("  [PASS]\n")

    # Cleanup test data
    print("Cleanup: Removing Test Data")
    print("-" * 60)
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()

    cursor.execute("DELETE FROM executions WHERE session_id = 'test_session_001'")
    deleted = cursor.rowcount
    cursor.execute("DELETE FROM sessions WHERE session_id = 'test_session_001'")

    conn.commit()
    conn.close()

    print(f"  Deleted {deleted} test execution(s)")
    print("  [PASS]\n")

    print("=" * 60)
    print("All Tests Passed!")
    print("=" * 60)

    return True

if __name__ == "__main__":
    success = run_tests()
    exit(0 if success else 1)
