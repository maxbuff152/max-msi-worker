#Requires -Version 5.1
# Max-MSI WSL bootstrap — official Cursor My Machines path (ticket T-F70597).
# On the MSI PowerShell:
#   irm https://raw.githubusercontent.com/maxbuff152/max-msi-worker/main/bootstrap-max-msi.ps1 | iex

$ErrorActionPreference = "Stop"

function Ensure-Ubuntu {
  if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
    Write-Host "Installing WSL + Ubuntu (reboot may be required)..." -ForegroundColor Yellow
    wsl --install -d Ubuntu
    Write-Host "If Windows asks to reboot: reboot, open Ubuntu once to create a user, then re-run this script."
    exit 0
  }
  $names = @(wsl -l -q 2>$null | ForEach-Object { $_.ToString().Trim() -replace '\x00','' })
  if (-not ($names | Where-Object { $_ -match 'Ubuntu' })) {
    Write-Host "Installing Ubuntu distro..." -ForegroundColor Yellow
    wsl --install -d Ubuntu
    Write-Host "Open Ubuntu once to finish user setup, then re-run this script."
    exit 0
  }
}

Ensure-Ubuntu

$bash = @'
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
echo "==> Installing Cursor Agent CLI (Linux/WSL)"
curl https://cursor.com/install -fsS | bash
export PATH="$HOME/.local/bin:$PATH"
command -v agent
agent --version || true
mkdir -p "$HOME/projects"
if [ ! -d "$HOME/projects/max-msi-worker/.git" ]; then
  git clone https://github.com/maxbuff152/max-msi-worker.git "$HOME/projects/max-msi-worker"
fi
cd "$HOME/projects/max-msi-worker"
echo "==> Login with the SAME Cursor account as your iPhone"
agent login
echo "==> Preflight"
agent worker debug || true
echo "==> Starting Max-MSI (leave this window open; keep PC awake)"
exec agent worker start --name "Max-MSI"
'@

Write-Host "Launching Ubuntu WSL worker setup..." -ForegroundColor Cyan
Start-Process -FilePath "wsl.exe" -ArgumentList @("-d","Ubuntu","--","bash","-lc",$bash)
Write-Host "Complete agent login in the Ubuntu window, then leave it running." -ForegroundColor Green
Write-Host "On iPhone: Runtime picker -> refresh -> Max-MSI" -ForegroundColor Green
