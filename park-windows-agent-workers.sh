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

# Prefer a Windows-local copy under %USERPROFILE% (no hardcoded username).
WIN_PROFILE="$("$PWSH" -NoProfile -Command '[Environment]::GetFolderPath("UserProfile")' 2>/dev/null | tr -d '\r')"
WIN_COPY=""
if [[ -n "${WIN_PROFILE}" ]]; then
  WIN_OPS_DIR="$(wslpath -u "$WIN_PROFILE" 2>/dev/null)/projects/max-msi-worker-ops"
  if [[ -n "${WIN_OPS_DIR}" && "${WIN_OPS_DIR}" != "/projects/max-msi-worker-ops" ]]; then
    mkdir -p "$WIN_OPS_DIR" 2>/dev/null || true
    if cp -f "$PS1" "$WIN_OPS_DIR/park-windows-agent-workers.ps1" 2>/dev/null; then
      WIN_COPY="$WIN_OPS_DIR/park-windows-agent-workers.ps1"
    fi
  fi
fi
if [[ -z "$WIN_COPY" ]]; then
  WIN_COPY="$PS1"
fi

WIN_PATH="$(wslpath -w "$WIN_COPY" 2>/dev/null || echo "$WIN_COPY")"
"$PWSH" -NoProfile -ExecutionPolicy Bypass -File "$WIN_PATH" 2>&1 | tail -n 40
exit 0
