# Park broken Windows Cursor agent-workers (ABI 127 vs 137).
# Leaves WSL Max-MSI alone. Never touches trading / FOMC / intraday processes.
#
# Usage (PowerShell as Maxwell, from C:\ cwd):
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\park-windows-agent-workers.ps1
# Or from WSL:
#   bash ./park-windows-agent-workers.sh

$ErrorActionPreference = "Continue"
Set-Location C:\

$WorkerRoot = Join-Path $env:APPDATA "Cursor\User\globalStorage\anysphere.cursor-agent-worker"
$Stamp = Get-Date -Format "yyyy-MM-dd"
$ParkDir = Join-Path $WorkerRoot ("parked-" + $Stamp + "-abi-broken")
$ProtectPattern = "fomc|intraday|trading|spy-intraday|_fomc_vol_watch|LLM Trading|paper.?trad"

function Test-ProtectedCommand([string]$cmd) {
  if ([string]::IsNullOrEmpty($cmd)) { return $false }
  return ($cmd -match $ProtectPattern)
}

Write-Host "==> Park Windows Cursor agent-workers (trade-safe)" -ForegroundColor Cyan

if (-not (Test-Path $WorkerRoot)) {
  Write-Host "No Windows agent-worker dir; nothing to park." -ForegroundColor Green
  exit 0
}

$Note = Join-Path $WorkerRoot "DO-NOT-USE-WINDOWS-WORKER.txt"
$AgentCli = Join-Path $WorkerRoot "agent-cli"
$Force = ($args -contains "-Force") -or ($env:FORCE_PARK_WINDOWS_WORKERS -eq "1")

function Test-WorkerProcessPresent {
  $hit = $false
  Get-CimInstance Win32_Process | Where-Object {
    $c = $_.CommandLine
    if ([string]::IsNullOrEmpty($c)) { return $false }
    if (Test-ProtectedCommand $c) { return $false }
    return (
      $c -like "*anysphere.cursor-agent-worker*" -or
      $c -like "*cursor-agent-worker-*" -or
      ($_.Name -eq "node.exe" -and $c -like "*cursor-agent-worker*")
    )
  } | ForEach-Object { $hit = $true }
  return $hit
}

$liveMarkers = @(Get-ChildItem -Path $WorkerRoot -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Extension -in ".spec", ".pid", ".install" })
$cliItem = Get-Item -LiteralPath $AgentCli -ErrorAction SilentlyContinue
$cliIsFileStub = ($null -ne $cliItem) -and (-not $cliItem.PSIsContainer)
$noteOk = Test-Path $Note
$procsPresent = Test-WorkerProcessPresent

# Skip noisy full park when already clean (watcher runs ~every 10 min).
# Still re-park if markers/procs return, or agent-cli is a directory again.
if (-not $Force -and $noteOk -and $cliIsFileStub -and ($liveMarkers.Count -eq 0) -and (-not $procsPresent)) {
  Write-Host "Already parked (note + agent-cli stub + 0 markers); skip" -ForegroundColor DarkGray
  exit 0
}

New-Item -ItemType Directory -Force -Path $ParkDir | Out-Null

# 1) Kill only Cursor Windows worker processes (never trading)
$killed = 0
Get-CimInstance Win32_Process | Where-Object {
  $c = $_.CommandLine
  if ([string]::IsNullOrEmpty($c)) { return $false }
  if (Test-ProtectedCommand $c) { return $false }
  return (
    $c -like "*anysphere.cursor-agent-worker*" -or
    $c -like "*cursor-agent-worker-*" -or
    ($_.Name -eq "node.exe" -and $c -like "*cursor-agent-worker*")
  )
} | ForEach-Object {
  Write-Host ("KILL {0} {1}" -f $_.ProcessId, $_.Name)
  Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
  $killed++
}
Write-Host ("Killed worker processes: {0}" -f $killed)

# 2) Park live markers so Cursor stops claiming a Windows worker is ready
$moved = 0
Get-ChildItem -Path $WorkerRoot -File -ErrorAction SilentlyContinue |
  Where-Object { $_.Extension -in ".spec", ".pid", ".install" } |
  ForEach-Object {
    $dest = Join-Path $ParkDir $_.Name
    Move-Item -Force -LiteralPath $_.FullName -Destination $dest -ErrorAction SilentlyContinue
    if (Test-Path $dest) {
      Write-Host ("parked {0}" -f $_.Name)
      $moved++
    }
  }
Write-Host ("Parked markers: {0}" -f $moved)

# 3) Quarantine broken Windows agent-cli so new workers fail closed (not hang Preparing)
$AgentCliParked = Join-Path $WorkerRoot "agent-cli.PARKED-ABI-BROKEN"

if ((Test-Path $AgentCli) -and (Get-Item -LiteralPath $AgentCli).PSIsContainer) {
  if (-not (Test-Path $AgentCliParked)) {
    Rename-Item -LiteralPath $AgentCli -NewName "agent-cli.PARKED-ABI-BROKEN" -ErrorAction SilentlyContinue
  }
  if ((Test-Path $AgentCli) -and (Get-Item -LiteralPath $AgentCli -ErrorAction SilentlyContinue).PSIsContainer) {
    Remove-Item -LiteralPath $AgentCli -Recurse -Force -ErrorAction SilentlyContinue
  }
}

# Block Cursor from recreating a usable agent-cli directory: leave a FILE at that path.
$item = Get-Item -LiteralPath $AgentCli -ErrorAction SilentlyContinue
if ($null -eq $item) {
  "PARKED: Windows agent-cli disabled (better-sqlite3 ABI 127 vs 137). Use WSL Max-MSI." |
    Set-Content -Encoding ASCII -Path $AgentCli -Force
  Write-Host "Blocked agent-cli path with file stub" -ForegroundColor Yellow
} elseif (-not $item.PSIsContainer) {
  Write-Host "agent-cli already blocked (file stub)" -ForegroundColor DarkGray
} else {
  Write-Host "WARN: agent-cli directory still locked (fully quit Cursor once, then re-run park)" -ForegroundColor Yellow
}

# 4) Leave a blocker note Cursor/users can see
@"
Windows Cursor agent-worker is PARKED on purpose.

Cause: better-sqlite3 NODE_MODULE 127 vs 137 (Cursor ticket T-F70597).
Symptom: desktop Agents stuck on "Preparing request".

Use WSL worker Max-MSI instead:
  https://cursor.com/agents  -> environment Max-MSI (phone label may say MSI)
  or Agents Window -> Max-MSI / MSI (not Local / This computer / CODEX SPINE)

Do not revive this Windows worker. Prefer park-windows-agent-workers.ps1.
Trading / FOMC processes are intentionally left alone by the park script.
"@ | Set-Content -Encoding UTF8 -Path $Note

Write-Host "Done. Start tasks via Max-MSI (WSL), not Windows Local." -ForegroundColor Green
exit 0
