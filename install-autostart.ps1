# DEPRECATED for Windows-native workers — DO NOT USE as the primary path.
# Canonical autostart is WSL: Windows task Cursor-Max-MSI-WSL-Worker → start-max-msi.sh
# Soft-heal: Cursor-Max-MSI-WSL-Worker-Watcher → repair-max-msi.sh
# This script registers a Windows-native worker task and will revive the ABI-broken path.
#
# Usage (PowerShell) — discouraged:
#   irm https://raw.githubusercontent.com/maxbuff152/max-msi-worker/main/install-autostart.ps1 | iex

$ErrorActionPreference = "Stop"
$taskName = "Cursor-Max-MSI-Worker"
$workDir = Join-Path $env:USERPROFILE "projects\max-msi-worker"
$wrapper = Join-Path $workDir "run-max-msi-worker.cmd"

if (-not (Test-Path $workDir)) {
  New-Item -ItemType Directory -Force -Path $workDir | Out-Null
  git clone https://github.com/maxbuff152/max-msi-worker.git $workDir
}

# Ensure ABI patch + login have been done at least once
$fixScript = Join-Path $workDir "fix-windows-worker.ps1"
if (-not (Test-Path $fixScript)) {
  Invoke-WebRequest -Uri "https://raw.githubusercontent.com/maxbuff152/max-msi-worker/main/fix-windows-worker.ps1" -OutFile $fixScript
}

# Lightweight start wrapper (assumes agent already logged in + ABI patched)
@"
@echo off
cd /d "%USERPROFILE%\projects\max-msi-worker"
where agent >nul 2>&1 || exit /b 1
agent worker start --name "Max-MSI" --idle-release-timeout 0
"@ | Set-Content -Encoding ASCII -Path $wrapper

$action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c `"$wrapper`"" -WorkingDirectory $workDir
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal | Out-Null

Write-Host "Registered scheduled task: $taskName" -ForegroundColor Green
Write-Host "First run the ABI fix + login if you haven't:" -ForegroundColor Yellow
Write-Host "  irm https://raw.githubusercontent.com/maxbuff152/max-msi-worker/main/fix-windows-worker.ps1 | iex"
Write-Host "Then reboot or start the task:" -ForegroundColor Yellow
Write-Host "  Start-ScheduledTask -TaskName '$taskName'"
