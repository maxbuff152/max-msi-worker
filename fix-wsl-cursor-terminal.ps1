# Soft-heal Cursor WSL terminal indefinite hangs (no WSL shutdown, no PC reboot).
# Prefers the Python patcher (surgical JSON).
#
#   powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\fix-wsl-cursor-terminal.ps1

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$py = Join-Path $scriptDir "fix-wsl-cursor-terminal.py"

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
  $python = Get-Command python3 -ErrorAction SilentlyContinue
}
if (-not $python) {
  throw @"
No Windows Python found.
From WSL run:
  python3 ~/Projects/active/max-msi-worker/fix-wsl-cursor-terminal.py
"@
}

& $python.Source $py
exit $LASTEXITCODE
