#!/usr/bin/env bash
# SFHS Desk DJ — Spotify 09:00–19:00 America/Chicago
# Usage: desk-dj now|start|stop|status|rotate|install-schedule|uninstall-schedule
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/scripts/desk-dj"
WIN_ROOT="/mnt/c/Users/Maxwe/AppData/Local/Maxwell/DeskDJ"
PS_EXE="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
ACTION="${1:-status}"

usage() {
  cat <<EOF
Usage: $(basename "$0") <now|start|stop|status|rotate|install-schedule|uninstall-schedule>
Spotify desk DJ — DeeBaby / Logan library / H-Town / Drake+Wayne
EOF
}

case "$ACTION" in
  -h|--help) usage; exit 0 ;;
  now) ACTION=start ;;
  start|stop|status|rotate|install-schedule|uninstall-schedule) ;;
  *) usage >&2; exit 2 ;;
esac

mkdir -p "$WIN_ROOT/logs"
cp -f "$SRC/Invoke-DeskDJ.ps1" "$WIN_ROOT/Invoke-DeskDJ.ps1"
cp -f "$SRC/playlist-config.json" "$WIN_ROOT/playlist-config.json"

"$PS_EXE" -NoProfile -ExecutionPolicy Bypass -File \
  'C:\Users\Maxwe\AppData\Local\Maxwell\DeskDJ\Invoke-DeskDJ.ps1' \
  -Action "$ACTION"
