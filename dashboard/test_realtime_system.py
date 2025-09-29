#!/usr/bin/env python3
"""
Test script for MacroMaster Real-Time System
Tests database, ingestion service, and dashboard functionality
"""

import time
import requests
import json
import subprocess
import sys
import os
from datetime import datetime

def test_database():
    """Test database initialization and basic operations"""
    print("🧪 Testing Database...")

    try:
        sys.path.append(os.path.dirname(os.path.abspath(__file__)))
        from database_schema import get_database 

        db = get_database()

        # Test session creation
        session_id = f"test_session_{int(time.time())}"
        success = db.create_session(session_id, "test_user", "wide")
        assert success, "Failed to create session"

        # Test interaction recording
        interaction_data = {
            'timestamp': datetime.now(),
            'interaction_type': 'macro_execution',
            'button_key': 'Num5',
            'execution_time_ms': 1250,
            'total_boxes': 5,
            'degradation_assignments': 'smudge,glare',
            'severity_level': 'medium',
            'canvas_mode': 'wide',
            'session_active_time_ms': 5000,
            'break_mode_active': False,
            'degradation_counts': {'smudge': 1, 'glare': 1}
        }

        interaction_id = db.record_interaction(session_id, interaction_data)
        assert interaction_id, "Failed to record interaction"

        # Test metrics retrieval
        metrics = db.get_realtime_metrics(session_id)
        assert metrics, "Failed to get metrics"

        # Test interaction retrieval
        interactions = db.get_recent_interactions(session_id, limit=10)
        assert len(interactions) > 0, "No interactions retrieved"

        db.close()
        print("✅ Database tests passed")
        return True

    except Exception as e:
        print(f"❌ Database test failed: {e}")
        return False

def test_ingestion_service():
    """Test data ingestion service"""
    print("🧪 Testing Data Ingestion Service...")

    try:
        # Test health check
        response = requests.get("http://localhost:5001/health", timeout=5)
        assert response.status_code == 200, f"Health check failed: {response.status_code}"

        health_data = response.json()
        assert health_data['status'] == 'healthy', "Service not healthy"

        # Test session creation
        session_data = {
            'session_id': f'test_session_{int(time.time())}',
            'username': 'test_user',
            'canvas_mode': 'wide'
        }

        response = requests.post("http://localhost:5001/session/start",
                               json=session_data, timeout=5)
        assert response.status_code == 200, f"Session start failed: {response.status_code}"

        result = response.json()
        assert result['status'] == 'success', "Session creation failed"

        session_id = session_data['session_id']

        # Test interaction ingestion
        interaction_data = {
            'session_id': session_id,
            'interaction_type': 'macro_execution',
            'button_key': 'Num5',
            'execution_time_ms': 1250,
            'total_boxes': 5,
            'degradation_assignments': 'smudge,glare',
            'severity_level': 'medium',
            'canvas_mode': 'wide',
            'session_active_time_ms': 5000,
            'break_mode_active': False,
            'degradation_counts': {'smudge': 1, 'glare': 1}
        }

        response = requests.post("http://localhost:5001/ingest/interaction",
                               json=interaction_data, timeout=5)
        assert response.status_code == 200, f"Interaction ingestion failed: {response.status_code}"

        result = response.json()
        assert result['status'] == 'success', "Interaction recording failed"

        # Test metrics retrieval
        response = requests.get(f"http://localhost:5001/metrics/{session_id}", timeout=5)
        assert response.status_code == 200, f"Metrics retrieval failed: {response.status_code}"

        metrics = response.json()
        assert metrics['status'] == 'success', "Metrics retrieval failed"

        print("✅ Data Ingestion Service tests passed")
        return True

    except requests.exceptions.RequestException as e:
        print(f"❌ Data Ingestion Service test failed: {e}")
        return False
    except Exception as e:
        print(f"❌ Data Ingestion Service test error: {e}")
        return False

def test_dashboard_service():
    """Test dashboard service"""
    print("🧪 Testing Dashboard Service...")

    try:
        # Test health check
        response = requests.get("http://localhost:5002/health", timeout=5)
        assert response.status_code == 200, f"Dashboard health check failed: {response.status_code}"

        health_data = response.json()
        assert 'active_sessions' in health_data, "Health check missing data"

        print("✅ Dashboard Service tests passed")
        return True

    except requests.exceptions.RequestException as e:
        print(f"❌ Dashboard Service test failed: {e}")
        return False
    except Exception as e:
        print(f"❌ Dashboard Service test error: {e}")
        return False

def run_integration_test():
    """Run complete integration test"""
    print("🧪 Running Integration Test...")

    try:
        # Create test session
        session_id = f"integration_test_{int(time.time())}"

        # Start session via ingestion service
        session_data = {
            'session_id': session_id,
            'username': 'integration_test',
            'canvas_mode': 'wide'
        }

        response = requests.post("http://localhost:5001/session/start", json=session_data)
        assert response.status_code == 200

        # Record multiple interactions
        for i in range(5):
            interaction_data = {
                'session_id': session_id,
                'interaction_type': 'macro_execution',
                'button_key': f'Num{i+1}',
                'execution_time_ms': 1000 + (i * 100),
                'total_boxes': 3 + i,
                'degradation_assignments': 'clear' if i % 2 == 0 else 'smudge',
                'severity_level': 'low',
                'canvas_mode': 'wide',
                'session_active_time_ms': 60000,
                'break_mode_active': False,
                'degradation_counts': {'clear': 1} if i % 2 == 0 else {'smudge': 1}
            }

            response = requests.post("http://localhost:5001/ingest/interaction", json=interaction_data)
            assert response.status_code == 200
            time.sleep(0.1)  # Small delay between interactions

        # Wait for metrics to update
        time.sleep(1)

        # Check metrics
        response = requests.get(f"http://localhost:5001/metrics/{session_id}")
        assert response.status_code == 200

        metrics = response.json()
        assert metrics['status'] == 'success'
        assert metrics['metrics']['session_stats']['total_executions'] == 5

        # Check interactions
        response = requests.get(f"http://localhost:5001/interactions/{session_id}")
        assert response.status_code == 200

        interactions = response.json()
        assert interactions['status'] == 'success'
        assert len(interactions['interactions']) == 5

        print("✅ Integration test passed")
        return True

    except Exception as e:
        print(f"❌ Integration test failed: {e}")
        return False

def main():
    """Run all tests"""
    print("🚀 MacroMaster Real-Time System Test Suite")
    print("=" * 50)

    # Check if services are running
    services_running = True

    try:
        requests.get("http://localhost:5001/health", timeout=2)
        requests.get("http://localhost:5002/health", timeout=2)
    except:
        services_running = False

    if not services_running:
        print("⚠️  Services not detected. Starting them for testing...")
        print("Run 'run_realtime_system.bat' first, then run this test.")
        return

    # Run tests
    results = []

    # Test database
    results.append(("Database", test_database()))

    # Test services
    results.append(("Data Ingestion Service", test_ingestion_service()))
    results.append(("Dashboard Service", test_dashboard_service()))

    # Integration test
    results.append(("Integration Test", run_integration_test()))

    # Summary
    print("\n" + "=" * 50)
    print("📊 Test Results:")

    passed = 0
    total = len(results)

    for test_name, success in results:
        status = "✅ PASS" if success else "❌ FAIL"
        print(f"  {test_name}: {status}")
        if success:
            passed += 1

    print(f"\n📈 Summary: {passed}/{total} tests passed")

    if passed == total:
        print("🎉 All tests passed! System is ready.")
        return 0
    else:
        print("⚠️  Some tests failed. Check service logs.")
        return 1

if __name__ == "__main__":
    sys.exit(main())