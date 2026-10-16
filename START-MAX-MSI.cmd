@echo off
REM Double-click this on the MSI (or run from cmd).
REM Starts official WSL-first Max-MSI bootstrap.
title Max-MSI bootstrap
echo.
echo === Max-MSI Cursor worker bootstrap ===
echo This will open WSL/Ubuntu, log into Cursor, and start worker Max-MSI.
echo The worker runs in WSL tmux. Leave the PC awake.
echo.
if exist "%~dp0bootstrap-max-msi.ps1" (
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0bootstrap-max-msi.ps1"
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/maxbuff152/max-msi-worker/main/bootstrap-max-msi.ps1 | iex"
)
if errorlevel 1 echo Setup failed. Read the error above before retrying.
echo.
echo If nothing stayed open, open Ubuntu WSL and run: bash ~/Projects/active/max-msi-worker/start-max-msi.sh
pause
