#!/usr/bin/env bash
# Shared --worker-dir list for MSI My Machines workers.
# Worker name on the wire: Max-MSI. Phone label: MSI.
# First dir = default assignment identity (must be the real git home).
#
# Usage:
#   source "$HOME/bin/msi-worker-dirs.sh" && eval "agent worker start --name Max-MSI --idle-release-timeout 0 $(msi_worker_dir_flags)"
#   bash "$HOME/bin/msi-worker-dirs.sh" --list
#   bash "$HOME/bin/msi-worker-dirs.sh" --print-flags
#
# Canon: ONLY these three live git homes — see ~/.cursor/memory/REPOS.md
# Use SellersFirstWebsite (real clone), not the website symlink — PR/assignment
# tooling binds by path/remote and the symlink confused ManagePullRequest.

set -euo pipefail

ACTIVE="${HOME}/Projects/active"

MSI_WORKER_DIRS=(
  "${ACTIVE}/SellersFirstWebsite"
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
