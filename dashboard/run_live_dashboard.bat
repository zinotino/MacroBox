@echo off
echo ========================================
echo MacroMaster Live Dashboard Launcher
echo ========================================
echo.

cd /d "%~dp0"

echo Checking Python installation...
python --version >nul 2>&1
if errorlevel 1 (
    echo ERROR: Python is not installed or not in PATH
    echo Please install Python 3.7+ and try again
    pause
    exit /b 1
)

echo.
echo Starting MacroMaster Live Dashboard Server...
echo Dashboard will auto-refresh every 60 seconds
echo.
echo Server will be available at: http://localhost:5000
echo Press Ctrl+C in the terminal to stop the server
echo.

python run_live_dashboard.py --csv "../data/master_stats.csv"

echo.
echo Live dashboard server stopped.
echo.
pause