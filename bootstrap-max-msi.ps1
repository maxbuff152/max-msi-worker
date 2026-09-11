#Requires -Version 5.1
# Max-MSI bootstrap — prefers official WSL path (Cursor ticket T-F70597).
# Fallback: Windows ABI patch if WSL cannot run yet.
#
# On the MSI PowerShell:
#   irm https://raw.githubusercontent.com/maxbuff152/max-msi-worker/main/bootstrap-max-msi.ps1 | iex

$ErrorActionPreference = "Stop"
$RepoUrl = "https://github.com/maxbuff152/max-msi-worker.git"
$WorkerName = "Max-MSI"

function Test-WslUbuntu {
  try {
    $distros = wsl -l -q 2>$null
    if (-not $distros) { return $false }
    return ($distros | ForEach-Object { $_.ToString().Trim() }) -match 'Ubuntu'
  } catch { return $false }
}

function Start-WslWorker {
  Write-Host "==> Using official WSL/Linux worker path" -ForegroundColor Cyan
  $bash = @'
set -euo pipefail
export PATH="$HOME/.local/bin:$HOME/.cursor/bin:$PATH"
if ! command -v agent >/dev/null 2>&1; then
  curl https://cursor.com/install -fsS | bash
  export PATH="$HOME/.local/bin:$HOME/.cursor/bin:$PATH"
fi
mkdir -p "$HOME/projects"
if [ ! -d "$HOME/projects/max-msi-worker/.git" ]; then
  git clone https://github.com/maxbuff152/max-msi-worker.git "$HOME/projects/max-msi-worker"
fi
cd "$HOME/projects/max-msi-worker"
echo "Sign in with the SAME Cursor account as your iPhone..."
agent login
agent worker debug || true
echo "Starting Max-MSI — leave this window open; keep MSI awake."
exec agent worker start --name "Max-MSI" --idle-release-timeout 0
'@
  # Interactive window so browser/device login works
  Start-Process wsl.exe -ArgumentList @("-d", "Ubuntu", "--", "bash", "-lc", $bash) -Wait:$false
  Write-Host "Launched Ubuntu WSL worker setup. Complete login in that window." -ForegroundColor Green
}

Write-Host "Max-MSI bootstrap" -ForegroundColor Cyan

if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
  Write-Host "WSL not found. Installing Ubuntu (reboot may be required)..." -ForegroundColor Yellow
  wsl --install -d Ubuntu
  Write-Host "If Windows asked for a reboot: reboot, open Ubuntu once to create a user, then re-run this script."
  return
}

if (-not (Test-WslUbuntu)) {
  Write-Host "Ubuntu distro missing. Installing..." -ForegroundColor Yellow
  wsl --install -d Ubuntu
  Write-Host "Finish Ubuntu first-run user setup, then re-run this script."
  return
}

try {
  Start-WslWorker
} catch {
  Write-Host "WSL launch failed: $_" -ForegroundColor Red
  Write-Host "Falling back to Windows ABI patch path..." -ForegroundColor Yellow
  irm "https://raw.githubusercontent.com/maxbuff152/max-msi-worker/main/fix-windows-worker.ps1" | iex
}
