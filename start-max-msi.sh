#!/usr/bin/env bash
# MSI My Machines — ONE WSL brain worker (simple Runtime picker) + Max-MSI compat alias.
# Canonical phone label: MSI
# Compat alias: Max-MSI (same roots) so older Grok Bot / sand schedules stop ERRORING
# until those schedules are retargeted or deleted.
# Roots (first = default assignment identity):
#   1) max-msi-worker (infra / brain)
#   2) website  (neutral path → SellersFirstWebsite repo)
#   3) messages-loop
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
DATA_DIR="${HOME}/.cursor/msi-brain-worker-data"
ALIAS_DATA_DIR="${HOME}/.cursor/msi-maxmsi-alias-data"
mkdir -p "${DATA_DIR}" "${ALIAS_DATA_DIR}"

stop_session() {
  local s=$1
  if tmux has-session -t "$s" 2>/dev/null; then
    echo "Stopping tmux session ${s} ..."
    tmux kill-session -t "$s"
  fi
}

stop_session "$OLD_SESSION"
stop_session "$SESSION"

# Stop old 3-label workers and any prior MSI / Max-MSI workers.
pkill -f 'worker start --name Max-MSI' 2>/dev/null || true
pkill -f 'worker start --name MSI Website' 2>/dev/null || true
pkill -f 'worker start --name MSI Infra' 2>/dev/null || true
pkill -f 'worker start --name MSI Messages' 2>/dev/null || true
pkill -f 'worker start --name MSI' 2>/dev/null || true
sleep 1

mapfile -t DIRS < <(msi_worker_dirs 2>/dev/null || msi_worker_print_dirs 2>/dev/null || true)
if [[ ${#DIRS[@]} -eq 0 ]] && declare -F msi_worker_dirs >/dev/null; then
  mapfile -t DIRS < <(msi_worker_dirs)
fi
if [[ ${#DIRS[@]} -eq 0 ]]; then
  # Fallback to the three live homes
  DIRS=(
    "${HOME}/Projects/active/max-msi-worker"
    "${HOME}/Projects/active/website"
    "${HOME}/Projects/active/messages-loop"
  )
fi

flag_str=""
for d in "${DIRS[@]}"; do
  flag_str+=" --worker-dir $(printf '%q' "$d")"
done

start_msi="export PATH=\"\$HOME/.local/bin:\$PATH\"; \
export AGENT_CLI_CREDENTIAL_STORE=file; \
unset CURSOR_DATA_DIR CURSOR_AGENT_WORKER_EXTENSION CURSOR_AGENT_WORKER_ID AGENT_CLI_WORKER_SIGNAL_HANDLED 2>/dev/null || true; \
export CURSOR_DATA_DIR=\"${DATA_DIR}\"; \
exec agent worker start --name MSI --idle-release-timeout 0 --label lane=brain${flag_str}"

start_alias="export PATH=\"\$HOME/.local/bin:\$PATH\"; \
export AGENT_CLI_CREDENTIAL_STORE=file; \
unset CURSOR_DATA_DIR CURSOR_AGENT_WORKER_EXTENSION CURSOR_AGENT_WORKER_ID AGENT_CLI_WORKER_SIGNAL_HANDLED 2>/dev/null || true; \
export CURSOR_DATA_DIR=\"${ALIAS_DATA_DIR}\"; \
exec agent worker start --name Max-MSI --idle-release-timeout 0 --label lane=compat-alias --label canonical=MSI${flag_str}"

primary="${DIRS[0]}"
tmux new-session -d -s "$SESSION" -n brain -c "$primary" -- bash -lc "$start_msi"
tmux new-window -t "$SESSION" -n maxmsi -c "$primary" -- bash -lc "$start_alias"

sleep 4
echo
echo "tmux session: ${SESSION}"
echo "PHONE LABEL: MSI (canonical)"
echo "COMPAT ALIAS: Max-MSI (parks old Grok/sand probes)"
echo "Worker dirs:"
printf '  - %s\n' "${DIRS[@]}"
echo
echo "Pull to refresh on https://cursor.com/agents — pick MSI (WSL brain)"
tmux list-windows -t "$SESSION" 2>/dev/null || true
tmux capture-pane -t "${SESSION}:brain" -p -J -S -24 2>/dev/null || true
tmux capture-pane -t "${SESSION}:maxmsi" -p -J -S -24 2>/dev/null || true
