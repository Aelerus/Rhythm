@echo off
REM Launches a tiny Node-based static server so ES modules and JSON loads work.
REM Open http://localhost:8000 in your browser.
cd /d "%~dp0"
where node >nul 2>nul
if errorlevel 1 (
  echo ERROR: Node.js was not found on PATH.
  echo Install Node from https://nodejs.org and try again.
  pause
  exit /b 1
)
echo Starting server at http://localhost:8000 ...
echo Press Ctrl+C in this window to stop.
node serve.js
echo.
echo Server exited.
pause
