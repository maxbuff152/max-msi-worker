# Register a trade-safe watcher that re-parks broken Windows Cursor agent-workers.
# Does NOT start a Windows worker. Does NOT touch FOMC / intraday / trading processes.
#
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\install-park-windows-workers.ps1

$ErrorActionPreference = "Stop"
Set-Location C:\

$TaskName = "Cursor-Park-Windows-Agent-Workers"
$RepoDir = "\\wsl$\Ubuntu-24.04\home\maxwell\Projects\active\max-msi-worker"
$Script = Join-Path $RepoDir "park-windows-agent-workers.ps1"

# Prefer a Windows-local copy so Task Scheduler does not depend on WSL path quirks
$LocalDir = Join-Path $env:USERPROFILE "projects\max-msi-worker-ops"
$LocalScript = Join-Path $LocalDir "park-windows-agent-workers.ps1"
New-Item -ItemType Directory -Force -Path $LocalDir | Out-Null
if (Test-Path $Script) {
  Copy-Item -Force -LiteralPath $Script -Destination $LocalScript
} elseif (-not (Test-Path $LocalScript)) {
  throw "Missing park script at $Script and no local copy at $LocalScript"
}

# Run once now
& powershell.exe -NoProfile -ExecutionPolicy Bypass -File $LocalScript

$action = New-ScheduledTaskAction `
  -Execute "powershell.exe" `
  -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$LocalScript`"" `
  -WorkingDirectory $LocalDir

# Soft heal every 10 minutes for ~10 years; also at logon
$triggerRepeat = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) `
  -RepetitionInterval (New-TimeSpan -Minutes 10) `
  -RepetitionDuration (New-TimeSpan -Days 3650)
$triggerLogon = New-ScheduledTaskTrigger -AtLogOn

$settings = New-ScheduledTaskSettingsSet `
  -AllowStartIfOnBatteries `
  -DontStopIfGoingOnBatteries `
  -StartWhenAvailable `
  -MultipleInstances IgnoreNew `
  -ExecutionTimeLimit (New-TimeSpan -Minutes 8)

$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited

Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask `
  -TaskName $TaskName `
  -Action $action `
  -Trigger @($triggerRepeat, $triggerLogon) `
  -Settings $settings `
  -Principal $principal `
  -Description "Park broken Windows Cursor agent-workers (ABI bug). Leaves WSL Max-MSI and trading alone." | Out-Null

Write-Host "Registered scheduled task: $TaskName" -ForegroundColor Green
Write-Host "Canonical agent runtime remains WSL worker Max-MSI." -ForegroundColor Cyan
