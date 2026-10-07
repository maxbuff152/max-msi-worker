#Requires -Version 5.1
# Retired: Windows-native Max-MSI autostart is unsupported (ticket T-F70597).
# Run this once to disable the old task without deleting its configuration.
$ErrorActionPreference = "Stop"
$taskName = "Cursor-Max-MSI-Worker"
$task = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
if ($null -ne $task) {
  Disable-ScheduledTask -TaskName $taskName | Out-Null
  Stop-ScheduledTask -TaskName $taskName
  Write-Host "Disabled/stopped legacy task: $taskName" -ForegroundColor Yellow
} else {
  Write-Host "No legacy Windows-native Max-MSI task found."
}
Write-Host "Autostart is retired. Start WSL with START-MAX-MSI.cmd or bootstrap-max-msi.ps1."
Write-Host "No new scheduled task was registered. Do not re-enable the legacy task."
