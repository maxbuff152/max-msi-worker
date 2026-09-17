#!/usr/bin/env bash
# Start Max-MSI My Machines worker without conflicting with private worker ~ @ MSI.
# Registers website + this repo + messages-loop via repeatable --worker-dir.
# Flags are computed HERE (not inside tmux) so a drifted helper cannot drop them.
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

if ! type msi_worker_dir_flags >/dev/null 2>&1; then
  echo "error: msi_worker_dir_flags missing after sourcing worker-dir helper" >&2
  exit 1
fi

if ! agent whoami >/dev/null 2>&1; then
  echo "Not logged in. Run: agent login"
  exit 1
fi

DIR_FLAGS="$(msi_worker_dir_flags)"
DEFAULT_DIR="${MSI_WORKER_DIRS[0]}"
if [[ ! -d "$DEFAULT_DIR" ]]; then
  echo "error: default worker dir missing: $DEFAULT_DIR" >&2
  exit 1
fi

SESSION=max-msi-worker
if [[ "${1:-}" == "--restart" || "${1:-}" == "-r" ]]; then
  tmux kill-session -t "$SESSION" 2>/dev/null || true
  sleep 1
fi

if tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "tmux session $SESSION already exists — logs:"
  tmux capture-pane -t "$SESSION" -p -J -S -20
  echo "Re-run with --restart to rebuild worker-dirs."
  exit 0
fi

# cwd = first git root so a flag failure still lands in a phone-visible repo
tmux new-session -d -s "$SESSION" -c "$DEFAULT_DIR" -- bash -lc "
  export PATH=\"\$HOME/.local/bin:\$PATH\"
  export AGENT_CLI_CREDENTIAL_STORE=file
  unset CURSOR_DATA_DIR CURSOR_AGENT_WORKER_EXTENSION CURSOR_AGENT_WORKER_ID AGENT_CLI_WORKER_SIGNAL_HANDLED || true
  export CURSOR_DATA_DIR=\"\$HOME/.cursor/max-msi-worker-data\"
  exec agent worker start --name Max-MSI --idle-release-timeout 0 ${DIR_FLAGS}
"
sleep 2
tmux capture-pane -t "$SESSION" -p -J -S -30
echo "Max-MSI tmux session: $SESSION"
echo "Worker dirs:"
printf '%s\n' "${MSI_WORKER_DIRS[@]}"
echo "Flags: $DIR_FLAGS"
echo "Picker: https://cursor.com/agents"
