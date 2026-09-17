# Soft-heal Cursor WSL terminal indefinite hangs (no WSL shutdown, no PC reboot).
# Prefers the Python patcher (surgical JSON). Falls back message if python missing.
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
  $wslPy = "\\wsl$\Ubuntu-24.04\usr\bin\python3"
  if (Test-Path -LiteralPath $wslPy) {
    & wsl.exe -d Ubuntu-24.04 -u maxwell -- python3 $py
    exit $LASTEXITCODE
  }
  throw "python/python3 not found. Open WSL and run: python3 ~/Projects/active/max-msi-worker/fix-wsl-cursor-terminal.py"
}

& $python.Source $py
exit $LASTEXITCODE
