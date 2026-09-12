#Requires -Version 5.1
# Max-MSI WSL bootstrap — official Cursor My Machines path (ticket T-F70597).
# Circumvents Windows-native better-sqlite3 ABI crash by using Ubuntu WSL + Linux CLI.
# Keeps existing project checkouts in place (never moves/deletes them).
#
# On the MSI PowerShell:
#   irm https://raw.githubusercontent.com/maxbuff152/max-msi-worker/main/bootstrap-max-msi.ps1 | iex
# Or after this PR merges / from a local clone:
#   .\bootstrap-max-msi.ps1

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

# Controlled before → ensure Linux CLI → restart worker → after → compare.
# Prefer git main; fall back to already-cloned paths without moving anything.
$bash = @'
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
mkdir -p "$HOME/Projects/active" "$HOME/bin" "$HOME/.cursor/max-msi-bench"

pick_repo() {
  local d
  for d in \
    "$HOME/Projects/active/max-msi-worker" \
    "$HOME/Projects/max-msi-worker" \
    "$HOME/projects/max-msi-worker" \
    "$HOME/projects/active/max-msi-worker"
  do
    if [ -d "$d/.git" ]; then
      printf '%s\n' "$d"
      return 0
    fi
  done
  return 1
}

REPO="$(pick_repo || true)"
if [ -z "${REPO:-}" ]; then
  REPO="$HOME/Projects/active/max-msi-worker"
  echo "==> Cloning max-msi-worker (missing only) → $REPO"
  git clone https://github.com/maxbuff152/max-msi-worker.git "$REPO"
else
  echo "==> Keeping existing checkout in place: $REPO"
  git -C "$REPO" fetch origin main 2>/dev/null || true
  git -C "$REPO" pull --ff-only origin main 2>/dev/null || true
fi

cd "$REPO"
chmod +x msi-controlled-test.sh msi-worker-dirs.sh msi-worker-status start-max-msi.sh 2>/dev/null || true

echo "==> BEFORE baseline (no changes)"
bash ./msi-controlled-test.sh before

echo "==> APPLY official WSL Ubuntu / Linux Agent path (no Windows-native agent)"
bash ./msi-controlled-test.sh apply

echo "==> AFTER baseline"
sleep 2
bash ./msi-controlled-test.sh after

echo "==> COMPARE"
bash ./msi-controlled-test.sh compare || true

echo
echo "Reports: $HOME/.cursor/max-msi-bench/"
echo "Leave the Max-MSI tmux worker running. Keep the PC awake."
echo "iPhone: Runtime picker → pull to refresh → Max-MSI"
'@

Write-Host "Launching Ubuntu WSL controlled setup (before → apply → after)..." -ForegroundColor Cyan
Write-Host "This uses Linux Agent CLI only (avoids Windows better-sqlite3 127 vs 137)." -ForegroundColor Cyan
Start-Process -FilePath "wsl.exe" -ArgumentList @("-d","Ubuntu","--","bash","-lc",$bash)
Write-Host "Complete agent login in the Ubuntu window if prompted, then leave Max-MSI running." -ForegroundColor Green
Write-Host "On iPhone: Runtime picker -> refresh -> Max-MSI" -ForegroundColor Green
