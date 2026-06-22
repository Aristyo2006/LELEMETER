@echo off
echo Installing claude-skills marketplace...
python3 "%~dp0\install_skills.py"
if errorlevel 1 (
    echo Installation failed with error code %errorlevel%
    pause
    exit /b %errorlevel%
)
echo Installation complete!
pause
