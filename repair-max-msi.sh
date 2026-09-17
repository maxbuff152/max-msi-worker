#!/usr/bin/env bash
# Keep the single Max-MSI WSL brain worker healthy. No-op when already running.
# Also re-parks broken Windows Cursor agent-workers (desktop Preparing hang).
#
# Wire name (truth): Max-MSI
# tmux session: max-msi-worker
# Called by Windows task Cursor-Max-MSI-WSL-Worker-Watcher every ~10 min.
set -euo pipefail
export PATH="${HOME}/.local/bin:${PATH}"
export AGENT_CLI_CREDENTIAL_STORE=file

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
START="${ROOT}/start-max-msi.sh"
PARK_WIN="${ROOT}/park-windows-agent-workers.sh"
SESSION="max-msi-worker"
WIRE_NAME="Max-MSI"

# Soft park Windows ABI-broken workers every watcher tick (trade-safe; never kills FOMC/MSI).
if [[ -f "$PARK_WIN" ]]; then
  bash "$PARK_WIN" || echo "WARN: Windows worker park returned non-zero (ignored)"
fi

worker_alive() {
  # Exact single-brain worker (not old MSI Website / Infra / Messages).
  # Max-MSI does not share a prefix collision with legacy name MSI.
  pgrep -f "worker start --name ${WIRE_NAME}" >/dev/null 2>&1
}

need_restart=0
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  need_restart=1
elif ! worker_alive; then
  echo "Missing worker process: ${WIRE_NAME}"
  need_restart=1
fi

if [[ "$need_restart" -eq 0 ]]; then
  echo "OK: ${WIRE_NAME} WSL brain already running"
  exit 0
fi

if ! agent whoami >/dev/null 2>&1; then
  echo "Not logged in. Run: agent login"
  exit 1
fi

if [[ ! -f "$START" ]]; then
  echo "error: missing start script: $START" >&2
  exit 1
fi

echo "Repairing ${WIRE_NAME} WSL brain..."
exec bash "$START"
