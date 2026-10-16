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
  if (-not ($names | Where-Object { $_ -eq 'Ubuntu' })) {
    Write-Host "Installing Ubuntu distro..." -ForegroundColor Yellow
    wsl --install -d Ubuntu
    Write-Host "Open Ubuntu once to finish user setup, then re-run this script."
    exit 0
  }
}

Ensure-Ubuntu

# Keep the Linux payload literal; encode it to avoid Windows native-argument quoting.
$bash = @'
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
export AGENT_CLI_CREDENTIAL_STORE=file
for prerequisite in git tmux; do
  command -v "$prerequisite" >/dev/null || { echo "Install prerequisites in Ubuntu: sudo apt-get update && sudo apt-get install -y git tmux" >&2; exit 1; }
done
canonical="$HOME/Projects/active/max-msi-worker"
repo=""
for candidate in "$canonical" "$HOME/Projects/max-msi-worker" "$HOME/projects/max-msi-worker" "$HOME/projects/active/max-msi-worker"; do
  if [[ -e "$candidate/.git" ]]; then
    repo="$candidate"
    break
  fi
done
mkdir -p "$HOME/Projects/active"
if [[ -z "$repo" ]]; then
  repo="$canonical"
  git clone https://github.com/maxbuff152/max-msi-worker.git "$repo"
else
  # No reset, stash, branch switch, or ignored update failures.
  origin="$(git -C "$repo" remote get-url origin)"
  case "$origin" in
    https://github.com/maxbuff152/max-msi-worker.git|https://github.com/maxbuff152/max-msi-worker|git@github.com:maxbuff152/max-msi-worker.git) ;;
    *) echo "Refusing to update unexpected origin: $repo" >&2; exit 1 ;;
  esac
  [[ -z "$(git -C "$repo" status --porcelain)" ]] || { echo "Checkout has local changes: $repo. Preserve/commit them before retrying." >&2; exit 1; }
  [[ "$(git -C "$repo" symbolic-ref --short HEAD)" == main ]] || { echo "Checkout must be on main: $repo" >&2; exit 1; }
  git -C "$repo" fetch origin main
  git -C "$repo" merge --ff-only FETCH_HEAD
fi
# Reuse a legacy clone in place, while keeping the canonical worker-dir valid.
if [[ "$repo" != "$canonical" ]]; then
  if [[ -e "$canonical" || -L "$canonical" ]]; then
    echo "Canonical path is occupied: $canonical. Resolve it before retrying." >&2
    exit 1
  fi
  ln -s "$repo" "$canonical"
fi
if ! command -v agent >/dev/null; then
  echo "==> Installing Linux Agent CLI"
  curl https://cursor.com/install -fsS | bash
fi
if ! agent whoami >/dev/null 2>&1; then
  echo "==> Login with the SAME Cursor account as your iPhone"
  agent login
fi
echo "==> Starting Max-MSI via the shared launcher"
exec bash "$repo/start-max-msi.sh"
'@

$encoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($bash.Replace("`r", "")))
Write-Host "Launching Ubuntu WSL setup..." -ForegroundColor Cyan
# Source from a process substitution so login still inherits interactive stdin.
& wsl.exe -d Ubuntu -- bash -c "source <(echo $encoded | base64 -d)"
if ($LASTEXITCODE -ne 0) { throw "WSL setup failed (exit $LASTEXITCODE). See the message above." }
Write-Host "Max-MSI runs in tmux. Keep the PC awake; this window may close." -ForegroundColor Green
Write-Host "On iPhone: Runtime picker -> refresh -> Max-MSI" -ForegroundColor Green
