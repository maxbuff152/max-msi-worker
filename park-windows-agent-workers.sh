#!/usr/bin/env bash
# Trade-safe park of broken Windows Cursor agent-workers.
# Called from repair-max-msi.sh (watcher). Never touches WSL Max-MSI or trading.
set -u
export PATH="${HOME}/.local/bin:${PATH}"

PWSH="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PS1="${ROOT}/park-windows-agent-workers.ps1"

if [[ ! -x "$PWSH" && ! -f "$PWSH" ]]; then
  echo "No Windows PowerShell; skip Windows worker park"
  exit 0
fi

if [[ ! -f "$PS1" ]]; then
  echo "Missing $PS1"
  exit 0
fi

# Prefer a Windows-local copy so PowerShell does not depend on \\wsl$ quirks.
WIN_COPY="/mnt/c/Users/Maxwe/projects/max-msi-worker-ops/park-windows-agent-workers.ps1"
mkdir -p "/mnt/c/Users/Maxwe/projects/max-msi-worker-ops" 2>/dev/null || true
if cp -f "$PS1" "$WIN_COPY" 2>/dev/null; then
  :
else
  WIN_COPY="$PS1"
fi

WIN_PATH="$(wslpath -w "$WIN_COPY" 2>/dev/null || echo "$WIN_COPY")"
"$PWSH" -NoProfile -ExecutionPolicy Bypass -File "$WIN_PATH" 2>&1 | tail -n 40
exit 0
