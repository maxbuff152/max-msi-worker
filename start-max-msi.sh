#!/usr/bin/env bash
# Start Max-MSI My Machines worker without conflicting with private worker ~ @ MSI.
# Registers SFHS site + this repo + messages-loop via repeatable --worker-dir.
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
if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "tmux session $SESSION already exists — logs:"
  tmux capture-pane -t "$SESSION" -p -J -S -20
  exit 0
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
