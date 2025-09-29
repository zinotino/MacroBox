@echo off
REM MacroMaster Simple Stats Dashboard Startup Script
REM Launches the accurate, static dashboard for viewing labeling statistics

echo ========================================
echo MacroMaster Simple Stats Dashboard
echo ========================================

REM Set working directory to script location
cd /d "%~dp0"

REM Check if Python is available
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.8+ and add it to your PATH
    pause
    exit /b 1
)

REM Install/update requirements
echo Installing Python dependencies...
pip install -r requirements.txt
if errorlevel 1 (
    echo WARNING: Failed to install some dependencies
    echo Continuing anyway...
)

REM Check if CSV file exists
if not exist "..\data\master_stats.csv" (
    echo WARNING: CSV file not found at ..\data\master_stats.csv
    echo The dashboard will show empty stats until data is available
    echo.
)

REM Start Simple Stats Dashboard
echo Starting Simple Stats Dashboard (port 5003)...
python simple_stats_dashboard.py "..\data\master_stats.csv" --host localhost --port 5003

echo.
echo Dashboard stopped.
pause