#!/usr/bin/env bash
# MSI My Machines workers — one friendly phone label per live repo.
# Usage:
#   source "$HOME/bin/msi-worker-dirs.sh" && msi_worker_list
#   bash "$HOME/bin/msi-worker-dirs.sh" --list
#   bash "$HOME/bin/msi-worker-dirs.sh" --print-start-lines
#
# Phone shows the --name string. A single multi-root worker only displays the
# first repo (the website), so we run three named workers instead.

set -euo pipefail

ACTIVE="${HOME}/Projects/active"

# name|worker_dir|data_dir_basename|lane_label
MSI_WORKER_SPECS=(
  "MSI Website|${ACTIVE}/SellersFirstWebsite|msi-website-worker-data|website"
  "MSI Infra|${ACTIVE}/max-msi-worker|msi-infra-worker-data|infra"
  "MSI Messages|${ACTIVE}/messages-loop|msi-messages-worker-data|messages"
)

MSI_WORKER_DIRS=(
  "${ACTIVE}/SellersFirstWebsite"
  "${ACTIVE}/max-msi-worker"
  "${ACTIVE}/messages-loop"
)

msi_worker_list() {
  local spec name dir data lane
  printf '%-14s  %-10s  %s\n' "PHONE LABEL" "LANE" "PATH"
  for spec in "${MSI_WORKER_SPECS[@]}"; do
    IFS='|' read -r name dir data lane <<<"$spec"
    printf '%-14s  %-10s  %s\n' "$name" "$lane" "$dir"
  done
}

msi_worker_dir_flags() {
  # Legacy multi-root flags (hides non-primary labels). Prefer --print-start-lines.
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

msi_worker_print_start_lines() {
  local spec name dir data lane
  for spec in "${MSI_WORKER_SPECS[@]}"; do
    IFS='|' read -r name dir data lane <<<"$spec"
    if [[ ! -d "$dir" ]]; then
      echo "warn: missing $dir (skip $name)" >&2
      continue
    fi
    printf '%s\t%s\t%s\t%s\n' "$name" "$dir" "${HOME}/.cursor/${data}" "$lane"
  done
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  case "${1:-}" in
    --print-flags|-p)
      msi_worker_dir_flags
      ;;
    --print-start-lines)
      msi_worker_print_start_lines
      ;;
    --list|-l)
      msi_worker_list
      ;;
    *)
      echo "Usage: msi-worker-dirs.sh [--list|--print-flags|--print-start-lines]"
      echo
      msi_worker_list
      ;;
  esac
fi
