#!/usr/bin/env python3
"""
MacroMaster Live Dashboard Launcher
Simple launcher for the live dashboard server
"""
import os
import sys
import argparse
from live_dashboard import LiveDashboardServer

def main():
    # Default path to the CSV file (in Documents\MacroMaster\data)
    import pathlib
    home_dir = pathlib.Path.home()
    default_csv = str(home_dir / "Documents" / "MacroMaster" / "data" / "master_stats.csv")

    parser = argparse.ArgumentParser(description='Launch MacroMaster Live Dashboard')
    parser.add_argument('--csv', default=default_csv,
                       help=f'Path to master_stats.csv (default: {default_csv})')
    parser.add_argument('--host', default='localhost',
                       help='Host to bind to (default: localhost)')
    parser.add_argument('--port', type=int, default=5000,
                       help='Port to bind to (default: 5000)')
    parser.add_argument('--refresh', type=int, default=60,
                       help='Auto-refresh interval in seconds (default: 60)')

    args = parser.parse_args()

    # Convert relative path to absolute
    csv_path = os.path.abspath(args.csv)

    if not os.path.exists(csv_path):
        print(f"Error: CSV file not found: {csv_path}")
        print("Please ensure the path to master_stats.csv is correct.")
        sys.exit(1)

    print("Starting MacroMaster Live Dashboard...")
    print(f"CSV File: {csv_path}")
    print(f"Server: http://{args.host}:{args.port}")
    print(f"Refresh: Every {args.refresh} seconds")
    print("Press Ctrl+C to stop the server")
    print("-" * 50)

    try:
        server = LiveDashboardServer(csv_path, args.host, args.port, args.refresh)
        server.run()
    except KeyboardInterrupt:
        print("\n👋 Server stopped by user")
    except Exception as e:
        print(f"Error starting server: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()