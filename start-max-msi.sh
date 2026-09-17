#!/usr/bin/env bash
# Start Max-MSI My Machines worker without conflicting with private worker ~ @ MSI.
# Registers SFHS site + this repo + messages-loop via repeatable --worker-dir.
#
#   bash start-max-msi.sh           # start if missing
#   bash start-max-msi.sh --restart # soft-restart tmux worker (no PC / wsl --shutdown)
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"
export AGENT_CLI_CREDENTIAL_STORE=file
unset CURSOR_DATA_DIR CURSOR_AGENT_WORKER_EXTENSION CURSOR_AGENT_WORKER_ID AGENT_CLI_WORKER_SIGNAL_HANDLED || true
export CURSOR_DATA_DIR="$HOME/.cursor/max-msi-worker-data"
mkdir -p "$CURSOR_DATA_DIR"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Prefer machine helper; fall back to repo copy
# shellcheck source=/dev/null
source "${HOME}/bin/msi-worker-dirs.sh" 2>/dev/null || source "$ROOT/msi-worker-dirs.sh"

if ! agent whoami >/dev/null 2>&1; then
  echo "Not logged in. Run: agent login"
  exit 1
fi

SESSION=max-msi-worker
RESTART=0
case "${1:-}" in
  --restart|-r) RESTART=1 ;;
  "" ) ;;
  *)
    echo "Usage: $0 [--restart]"
    exit 2
    ;;
esac

if tmux has-session -t "$SESSION" 2>/dev/null; then
  if [[ "$RESTART" -eq 0 ]]; then
    echo "tmux session $SESSION already exists — logs:"
    tmux capture-pane -t "$SESSION" -p -J -S -20
    echo
    echo "Canonical dirs (restart to apply):"
    printf '  %s\n' "${MSI_WORKER_DIRS[@]}"
    echo "Soft-restart: bash $ROOT/start-max-msi.sh --restart"
    exit 0
  fi
  echo "Stopping tmux session $SESSION (soft worker restart)…"
  tmux kill-session -t "$SESSION" || true
  # Give the old agent process a moment to release locks.
  sleep 2
fi

tmux new-session -d -s "$SESSION" -c "$HOME/Projects/active" -- bash -lc "
  export PATH=\"\$HOME/.local/bin:\$PATH\"
  export AGENT_CLI_CREDENTIAL_STORE=file
  unset CURSOR_DATA_DIR CURSOR_AGENT_WORKER_EXTENSION CURSOR_AGENT_WORKER_ID AGENT_CLI_WORKER_SIGNAL_HANDLED || true
  export CURSOR_DATA_DIR=\"\$HOME/.cursor/max-msi-worker-data\"
  ROOT=\"$ROOT\"
  # shellcheck source=/dev/null
  source \"\$HOME/bin/msi-worker-dirs.sh\" 2>/dev/null || source \"\$ROOT/msi-worker-dirs.sh\"
  eval \"exec agent worker start --name Max-MSI --idle-release-timeout 0 \$(msi_worker_dir_flags)\"
"
sleep 2
tmux capture-pane -t "$SESSION" -p -J -S -30
echo "Max-MSI tmux session: $SESSION"
echo "Worker dirs:"
( source "${HOME}/bin/msi-worker-dirs.sh" 2>/dev/null || source "$ROOT/msi-worker-dirs.sh"; printf '%s\n' "${MSI_WORKER_DIRS[@]}" )
echo "Picker: https://cursor.com/agents"
