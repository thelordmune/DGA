# Serve Both Places - PowerShell Script
# This script starts both the Main Game and Main Menu Rojo servers

Write-Host "Starting Rojo servers for Ironveil..." -ForegroundColor Cyan
Write-Host ""

# Start Main Game server
Write-Host "Starting Main Game server on port 34872..." -ForegroundColor Green
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Write-Host 'MAIN GAME SERVER' -ForegroundColor Green; rojo serve default.project.json"

# Wait a moment to avoid port conflicts
Start-Sleep -Seconds 1

# Start Main Menu server
Write-Host "Starting Main Menu server on port 34873..." -ForegroundColor Yellow
Start-Process powershell -ArgumentList "-NoExit", "-Command", "Write-Host 'MAIN MENU SERVER' -ForegroundColor Yellow; rojo serve menu.project.json --port 34873"

Write-Host ""
Write-Host "Both servers started!" -ForegroundColor Cyan
Write-Host ""
Write-Host "Main Game:  localhost:34872" -ForegroundColor Green
Write-Host "Main Menu:  localhost:34873" -ForegroundColor Yellow
Write-Host ""
Write-Host "Press any key to exit (servers will keep running)..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

