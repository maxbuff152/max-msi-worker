#!/usr/bin/env bash
# Shared --worker-dir list for MSI My Machines workers.
# Resolves existing checkouts in place (never moves/renames/deletes).
#
# Usage:
#   source "$HOME/bin/msi-worker-dirs.sh" && eval "agent worker start --name Max-MSI --idle-release-timeout 0 $(msi_worker_dir_flags)"
#   bash "$HOME/bin/msi-worker-dirs.sh" --list
#   bash "$HOME/bin/msi-worker-dirs.sh" --print-flags
#   bash "$HOME/bin/msi-worker-dirs.sh" --resolve SellersFirstWebsite

set -euo pipefail

ACTIVE="${HOME}/Projects/active"

# Ordered search roots for an existing checkout (first hit wins — keep in place).
msi_resolve_worker_dir() {
  local name="$1"
  local candidate
  local -a candidates=(
    "${ACTIVE}/${name}"
    "${HOME}/Projects/${name}"
    "${HOME}/projects/${name}"
    "${HOME}/projects/active/${name}"
  )
  for candidate in "${candidates[@]}"; do
    if [[ -d "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done
  # Canonical path for a not-yet-cloned repo (caller may create it).
  printf '%s\n' "${ACTIVE}/${name}"
}

# Ordered: primary product first (assignment identity), then infra, then ops.
MSI_WORKER_DIR_NAMES=(
  SellersFirstWebsite
  max-msi-worker
  messages-loop
)

MSI_WORKER_DIRS=()
msi_refresh_worker_dirs() {
  local name
  MSI_WORKER_DIRS=()
  for name in "${MSI_WORKER_DIR_NAMES[@]}"; do
    MSI_WORKER_DIRS+=("$(msi_resolve_worker_dir "$name")")
  done
}
msi_refresh_worker_dirs

msi_worker_dir_flags() {
  msi_refresh_worker_dirs
  local d
  local -a flags=()
  for d in "${MSI_WORKER_DIRS[@]}"; do
    if [[ -d "$d" ]]; then
      if [[ "$d" == /mnt/c/* || "$d" == /mnt/c ]]; then
        echo "warn: worker-dir on /mnt/c (slow): $d" >&2
      fi
      flags+=(--worker-dir "$d")
    else
      echo "warn: missing worker-dir $d (skip)" >&2
    fi
  done
  if [[ ${#flags[@]} -eq 0 ]]; then
    echo "error: no worker dirs found (looked under $ACTIVE and legacy ~/projects)" >&2
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
      msi_refresh_worker_dirs
      printf '%s\n' "${MSI_WORKER_DIRS[@]}"
      ;;
    --resolve|-r)
      if [[ -z "${2:-}" ]]; then
        echo "Usage: $0 --resolve <repo-name>" >&2
        exit 1
      fi
      msi_resolve_worker_dir "$2"
      ;;
    *)
      echo "Usage: msi-worker-dirs.sh [--list|--print-flags|--resolve NAME]"
      echo "Configured roots (resolved in place):"
      msi_refresh_worker_dirs
      printf '  %s\n' "${MSI_WORKER_DIRS[@]}"
      ;;
  esac
fi
