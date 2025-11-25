# Stop All Rojo Servers - PowerShell Script
# This script stops all running Rojo server processes

Write-Host "Stopping all Rojo servers..." -ForegroundColor Red

# Find and stop all Rojo processes
$rojoProcesses = Get-Process | Where-Object { $_.ProcessName -eq "rojo" }

if ($rojoProcesses) {
    $count = ($rojoProcesses | Measure-Object).Count
    Write-Host "Found $count Rojo process(es). Stopping..." -ForegroundColor Yellow
    
    $rojoProcesses | ForEach-Object {
        Stop-Process -Id $_.Id -Force
        Write-Host "Stopped Rojo process (PID: $($_.Id))" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "All Rojo servers stopped!" -ForegroundColor Green
} else {
    Write-Host "No Rojo servers are currently running." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

