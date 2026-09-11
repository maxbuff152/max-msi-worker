@echo off
REM Double-click this on the MSI (or run from cmd).
REM Starts official WSL-first Max-MSI bootstrap.
title Max-MSI bootstrap
echo.
echo === Max-MSI Cursor worker bootstrap ===
echo This will open WSL/Ubuntu, log into Cursor, and start worker Max-MSI.
echo Keep the resulting window open and leave the PC awake.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/maxbuff152/max-msi-worker/main/bootstrap-max-msi.ps1 | iex"
echo.
echo If nothing stayed open, open Ubuntu WSL and run: bash ~/projects/max-msi-worker/start-max-msi.sh
pause
