#!/usr/bin/env bash
# MSI My Machines — single WSL brain worker directory map.
# Worker name on the wire: Max-MSI. Phone label: MSI.
# First dir = default assignment identity (must be git + environment.json).
# Neutral folder names only (use website symlink, never SellersFirstWebsite in worker paths).
#
# Usage:
#   source "$HOME/bin/msi-worker-dirs.sh" && eval "agent worker start --name Max-MSI --idle-release-timeout 0 $(msi_worker_dir_flags)"
#   bash "$HOME/bin/msi-worker-dirs.sh" --list
#   bash "$HOME/bin/msi-worker-dirs.sh" --print-flags

set -euo pipefail

ACTIVE="${HOME}/Projects/active"

# Order matters: first = default workspace identity for the phone picker.
MSI_WORKER_DIRS=(
  "${ACTIVE}/website"
  "${ACTIVE}/max-msi-worker"
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
    --print-flags|-p) msi_worker_dir_flags ;;
    --dirs|-d) msi_worker_dirs ;;
    --list|-l) msi_worker_list ;;
    *)
      echo "Usage: msi-worker-dirs.sh [--list|--dirs|--print-flags]"
      msi_worker_list
      ;;
  esac
fi
