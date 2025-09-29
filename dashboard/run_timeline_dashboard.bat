@echo off
echo ========================================
echo MacroMaster Timeline Dashboard Launcher
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
echo Starting MacroMaster Timeline Dashboard...
echo.

python timeline_slider_dashboard.py "%USERPROFILE%\Documents\MacroMaster\data\master_stats.csv"

echo.
echo Dashboard generation complete!
echo If the browser didn't open automatically, look for:
echo   - open_dashboard.bat (double-click to open)
echo   - output/macromaster_timeline_slider.html
echo.
pause