#!/usr/bin/env bash
# Shared --worker-dir list for MSI My Machines workers.
# Usage:
#   source "$HOME/bin/msi-worker-dirs.sh" && eval "agent worker start --name Max-MSI --idle-release-timeout 0 $(msi_worker_dir_flags)"
#   bash "$HOME/bin/msi-worker-dirs.sh" --list
#   bash "$HOME/bin/msi-worker-dirs.sh" --print-flags

set -euo pipefail

ACTIVE="${HOME}/Projects/active"

# Ordered: primary product first (assignment identity), then infra, then ops.
# Canon: ONLY these three live git homes — see ~/.cursor/memory/REPOS.md
MSI_WORKER_DIRS=(
  "${ACTIVE}/SellersFirstWebsite"
  "${ACTIVE}/max-msi-worker"
  "${ACTIVE}/messages-loop"
)

msi_worker_dir_flags() {
  local d
  local -a flags=()
  for d in "${MSI_WORKER_DIRS[@]}"; do
    if [[ -d "$d" ]]; then
      flags+=(--worker-dir "$d")
    else
      echo "warn: missing worker-dir $d (skip)" >&2
    fi
  done
  if [[ ${#flags[@]} -eq 0 ]]; then
    echo "error: no worker dirs found under $ACTIVE" >&2
    return 1
  fi
  printf '%q ' "${flags[@]}"
  printf '\n'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  case "${1:-}" in
    --print-flags|-p)
      msi_worker_dir_flags
      ;;
    --list|-l)
      printf '%s\n' "${MSI_WORKER_DIRS[@]}"
      ;;
    *)
      echo "Usage: msi-worker-dirs.sh [--list|--print-flags]"
      echo "Configured roots:"
      printf '  %s\n' "${MSI_WORKER_DIRS[@]}"
      ;;
  esac
fi
