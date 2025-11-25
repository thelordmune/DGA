@echo off
REM Serve Both Places - Batch Script
REM This script starts both the Main Game and Main Menu Rojo servers

echo Starting Rojo servers for Ironveil...
echo.

echo Starting Main Game server on port 34872...
start "Ironveil - Main Game" cmd /k "echo MAIN GAME SERVER && rojo serve default.project.json"

timeout /t 1 /nobreak >nul

echo Starting Main Menu server on port 34873...
start "Ironveil - Main Menu" cmd /k "echo MAIN MENU SERVER && rojo serve menu.project.json --port 34873"

echo.
echo Both servers started!
echo.
echo Main Game:  localhost:34872
echo Main Menu:  localhost:34873
echo.
echo Press any key to exit (servers will keep running)...
pause >nul

