#!/usr/bin/env bash
# Prepare MSI Agent Chrome (headed Windows Chrome + CDP :9333).
# Profile: %LOCALAPPDATA%\Maxwell\MsiAgentChrome\profile — NEVER wipe.
# Default: REUSE if CDP already up. --force-chrome-restart recycles process only.
#
# Lane split:
#   Firefox  = Maxwell (tastytrade / personal)
#   This Chrome = Cursor agents (YouTube, Google, etc. after Maxwell signs in)
#   Lenovo CDP = HAR / Matrix / Hubzu / auctions (unchanged)
#
# Why Windows Chrome (not WSL GUI): .wslconfig has guiApplications=false.
# WSL still drives it over mirrored localhost — no SSH tunnel needed.
set -euo pipefail

PORT="${MSI_AGENT_CHROME_PORT:-9333}"
FORCE_CHROME=0
INSTALL_ONLY=0
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC_DIR="$REPO_ROOT/scripts/msi-agent-chrome"
WIN_ROOT="/mnt/c/Users/Maxwe/AppData/Local/Maxwell/MsiAgentChrome"
WIN_PS1="$WIN_ROOT/Start-MsiAgentChrome.ps1"
WIN_HTML="$WIN_ROOT/sign-in.html"
PS_EXE="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"

usage() {
  cat <<EOF
Usage: $(basename "$0") [--force-chrome-restart] [--install-only] [--port N]

Default reuses Agent Chrome when CDP is listening (keeps logins).
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force-chrome-restart) FORCE_CHROME=1; shift ;;
    --install-only) INSTALL_ONLY=1; shift ;;
    --port)
      PORT="${2:?--port needs a value}"
      shift 2
      ;;
    --port=*)
      PORT="${1#*=}"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown arg: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

cdp_up() {
  curl -fsS --max-time 2 "http://127.0.0.1:${PORT}/json/version" >/dev/null 2>&1
}

install_files() {
  mkdir -p "$WIN_ROOT/profile" "$WIN_ROOT/logs"
  cp -f "$SRC_DIR/Start-MsiAgentChrome.ps1" "$WIN_PS1"
  cp -f "$SRC_DIR/sign-in.html" "$WIN_HTML"
  echo "INSTALLED → $WIN_ROOT"
}

if [[ ! -f "$PS_EXE" ]]; then
  echo "powershell.exe not found at $PS_EXE" >&2
  exit 1
fi

install_files

if [[ "$INSTALL_ONLY" -eq 1 ]]; then
  echo "install-only done"
  exit 0
fi

echo "MSI Agent Chrome — CDP :$PORT (Firefox stays yours; Lenovo keeps Matrix)"

if cdp_up && [[ "$FORCE_CHROME" -eq 0 ]]; then
  echo "CHROME_REUSED — CDP :$PORT already listening (profile left alone)"
else
  ps_args=(-NoProfile -ExecutionPolicy Bypass -File 'C:\Users\Maxwe\AppData\Local\Maxwell\MsiAgentChrome\Start-MsiAgentChrome.ps1' -Port "$PORT")
  if [[ "$FORCE_CHROME" -eq 1 ]]; then
    echo "FORCE_CHROME_RESTART requested — profile directory kept"
    ps_args+=(-ForceRestart)
  else
    echo "CDP down — starting headed Agent Chrome (reuses profile)"
  fi
  "$PS_EXE" "${ps_args[@]}"
fi

for _ in $(seq 1 25); do
  if cdp_up; then
    break
  fi
  sleep 0.4
done

if curl -fsS --max-time 5 "http://127.0.0.1:${PORT}/json/version" >/tmp/msi-agent-chrome-version.json; then
  echo "CDP_OK http://127.0.0.1:${PORT}"
  python3 -c 'import json;print(json.load(open("/tmp/msi-agent-chrome-version.json")).get("Browser","?"))'
  echo "NEXT: sign in on the Agent Chrome window (Google / YouTube / Spotify as you want)"
  echo "Never wipe: %LOCALAPPDATA%\\Maxwell\\MsiAgentChrome\\profile"
  echo "Canon: ~/.cursor/memory/msi-agent-chrome.md"
  exit 0
fi

echo "CDP_FAIL — Agent Chrome debug port :$PORT not reachable from WSL" >&2
exit 1
