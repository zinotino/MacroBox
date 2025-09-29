@echo off
REM MacroMaster Real-Time System Startup Script
REM Launches all services: Data Ingestion, Dashboard, and AHK Script

echo ========================================
echo MacroMaster Real-Time System Startup
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

REM Start Data Ingestion Service in background
echo Starting Data Ingestion Service (port 5001)...
start "DataIngestionService" cmd /c "python data_ingestion_service.py --host localhost --port 5001"

REM Wait a moment for service to start
timeout /t 3 /nobreak >nul

REM Start Real-Time Dashboard in background
echo Starting Real-Time Dashboard (port 5002)...
start "RealtimeDashboard" cmd /c "python realtime_dashboard.py --host localhost --port 5002"

REM Wait for dashboard to start
timeout /t 3 /nobreak >nul

REM Check if services are running
echo Checking service health...
curl -s http://localhost:5001/health >nul 2>&1
if errorlevel 1 (
    echo WARNING: Data Ingestion Service may not be responding
) else (
    echo ✓ Data Ingestion Service is running
)

curl -s http://localhost:5002/health >nul 2>&1
if errorlevel 1 (
    echo WARNING: Dashboard Service may not be responding
) else (
    echo ✓ Real-Time Dashboard is running
)

echo.
echo ========================================
echo Services Started Successfully!
echo ========================================
echo.
echo Real-Time Dashboard: http://localhost:5002
echo Data Ingestion API: http://localhost:5001
echo.
echo To start the AHK macro system, run:
echo   ..\src\MacroLauncherX46.ahk
echo.
echo Press any key to open the dashboard in your browser...
pause >nul

REM Open dashboard in default browser
start http://localhost:5002

echo.
echo System is running. Press Ctrl+C in the service windows to stop.
echo.