#!/usr/bin/env bash
# Start three friendly-labeled MSI My Machines workers:
#   MSI Website · MSI Infra · MSI Messages
# Replaces the old single Max-MSI multi-root worker (website-only phone label).
set -euo pipefail
export PATH="${HOME}/.local/bin:${PATH}"
export AGENT_CLI_CREDENTIAL_STORE=file

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${HOME}/bin/msi-worker-dirs.sh" 2>/dev/null || source "${ROOT}/msi-worker-dirs.sh"

if ! agent whoami >/dev/null 2>&1; then
  echo "Not logged in. Run: agent login"
  exit 1
fi

SESSION=msi-workers
OLD_SESSION=max-msi-worker

stop_session() {
  local s=$1
  if tmux has-session -t "$s" 2>/dev/null; then
    echo "Stopping tmux session ${s} ..."
    tmux kill-session -t "$s"
  fi
}

stop_session "$OLD_SESSION"
stop_session "$SESSION"

# Best-effort cleanup if a worker was started outside tmux.
pkill -f 'agent worker start --name Max-MSI' 2>/dev/null || true
pkill -f 'agent worker start --name MSI Website' 2>/dev/null || true
pkill -f 'agent worker start --name MSI Infra' 2>/dev/null || true
pkill -f 'agent worker start --name MSI Messages' 2>/dev/null || true
sleep 1

mapfile -t LINES < <(msi_worker_print_start_lines)
if [[ ${#LINES[@]} -eq 0 ]]; then
  echo "error: no worker specs to start"
  exit 1
fi

first=1
for line in "${LINES[@]}"; do
  IFS=$'\t' read -r name dir data_dir lane <<<"$line"
  mkdir -p "$data_dir"
  # Match the live CLI form used by Max-MSI today (flags after `start`).
  start_cmd="export PATH=\"\$HOME/.local/bin:\$PATH\"; \
export AGENT_CLI_CREDENTIAL_STORE=file; \
unset CURSOR_DATA_DIR CURSOR_AGENT_WORKER_EXTENSION CURSOR_AGENT_WORKER_ID AGENT_CLI_WORKER_SIGNAL_HANDLED 2>/dev/null || true; \
export CURSOR_DATA_DIR=\"${data_dir}\"; \
exec agent worker start --name \"${name}\" --idle-release-timeout 0 --label lane=${lane} --worker-dir \"${dir}\""

  if [[ $first -eq 1 ]]; then
    tmux new-session -d -s "$SESSION" -n "$lane" -c "$dir" -- bash -lc "$start_cmd"
    first=0
  else
    tmux new-window -t "$SESSION" -n "$lane" -c "$dir" -- bash -lc "$start_cmd"
  fi
  echo "Started: ${name}  (${lane})  → ${dir}"
done

sleep 4
echo
echo "tmux session: ${SESSION}"
msi_worker_list
echo
echo "Pull to refresh on https://cursor.com/agents — pick MSI Website / MSI Infra / MSI Messages"
tmux list-windows -t "$SESSION" 2>/dev/null || true
tmux capture-pane -t "${SESSION}:website" -p -J -S -20 2>/dev/null || true
