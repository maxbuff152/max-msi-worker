#!/usr/bin/env bash
# MSI My Machines — single WSL brain worker directory map.
# One worker named "MSI". First dir = default assignment identity.
# Use neutral folder names only (never SellersFirstWebsite in worker paths).

set -euo pipefail

ACTIVE="${HOME}/Projects/active"

# Order matters: first = default workspace identity for the single MSI worker.
MSI_WORKER_DIRS=(
  "${ACTIVE}/max-msi-worker"
  "${ACTIVE}/website"
  "${ACTIVE}/messages-loop"
)

msi_worker_dirs() {
  local d
  for d in "${MSI_WORKER_DIRS[@]}"; do
    if [[ -d "$d" ]]; then
      printf '%s\n' "$d"
    else
      echo "warn: missing worker-dir $d (skip)" >&2
    fi
  done
}

msi_worker_list() {
  local d i=0
  printf '%-14s  %s\n' "PHONE LABEL" "PATHS (first = default)"
  printf '%-14s  ' "MSI"
  while IFS= read -r d; do
    if [[ $i -gt 0 ]]; then printf '\n%-14s  ' ""; fi
    printf '%s' "$d"
    i=$((i + 1))
  done < <(msi_worker_dirs)
  printf '\n'
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  case "${1:-}" in
    --dirs|-d) msi_worker_dirs ;;
    --list|-l|*) msi_worker_list ;;
  esac
fi
