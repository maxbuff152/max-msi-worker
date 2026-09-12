#Requires -Version 5.1
# Register Max-MSI to auto-start via WSL Ubuntu (official path; ticket T-F70597).
# Does NOT use Windows-native agent worker (broken better-sqlite3 ABI).
#
# Usage (PowerShell on MSI):
#   irm https://raw.githubusercontent.com/maxbuff152/max-msi-worker/main/install-autostart.ps1 | iex

$ErrorActionPreference = "Stop"
$taskName = "Cursor-Max-MSI-Worker-WSL"
$legacyTask = "Cursor-Max-MSI-Worker"
$workDir = Join-Path $env:USERPROFILE "projects\max-msi-worker"
$wrapper = Join-Path $env:TEMP "run-max-msi-wsl.cmd"

# Soft-remove legacy Windows-native autostart if present
Unregister-ScheduledTask -TaskName $legacyTask -Confirm:$false -ErrorAction SilentlyContinue

@"
@echo off
REM Start Max-MSI inside Ubuntu WSL — never Windows-native agent.
wsl.exe -d Ubuntu -- bash -lc "export PATH=\"`$HOME/.local/bin:`$PATH\"; export AGENT_CLI_CREDENTIAL_STORE=file; REPO=\"\"; for d in `$HOME/Projects/active/max-msi-worker `$HOME/Projects/max-msi-worker `$HOME/projects/max-msi-worker; do if [ -f `\"`$d/start-max-msi.sh`\" ]; then REPO=`\"`$d`\"; break; fi; done; if [ -z `\"`$REPO`\" ]; then echo max-msi-worker checkout not found; exit 1; fi; bash `\"`$REPO/start-max-msi.sh`\""
"@ | Set-Content -Encoding ASCII -Path $wrapper

$action = New-ScheduledTaskAction -Execute "cmd.exe" -Argument "/c `"$wrapper`"" -WorkingDirectory $env:TEMP
$trigger = New-ScheduledTaskTrigger -AtLogOn
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1)
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Principal $principal | Out-Null

Write-Host "Registered scheduled task: $taskName (WSL Ubuntu path)" -ForegroundColor Green
Write-Host "Removed legacy Windows-native task if it existed: $legacyTask" -ForegroundColor Yellow
Write-Host "First run the WSL bootstrap + agent login if you haven't:" -ForegroundColor Yellow
Write-Host "  irm https://raw.githubusercontent.com/maxbuff152/max-msi-worker/main/bootstrap-max-msi.ps1 | iex"
Write-Host "Then reboot or:" -ForegroundColor Yellow
Write-Host "  Start-ScheduledTask -TaskName '$taskName'"
