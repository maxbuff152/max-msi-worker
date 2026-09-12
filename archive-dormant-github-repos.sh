#!/usr/bin/env bash
# Archive dormant GitHub remotes (Maximize / personal shell / old mind).
# Safe to re-run. Does NOT touch the three live repos or SFHS clone-on-demand remotes.
# Usage: bash ~/bin/archive-dormant-github-repos.sh

set -euo pipefail

OWNER="${GITHUB_OWNER:-maxbuff152}"

LIVE=(
  SellersFirstWebsite
  max-msi-worker
  messages-loop
)

KEEP_UNARCHIVED=(
  sellers-first-operations-hub
  sfhs-foreclosure-intake
  maxwell-github-portfolio
)

DORMANT=(
  maximize-ai-harness
  maximize-control-plane
  maximize-desktop
  maximize-video-studio
  maximize-file-recall
  maxwell-shell
  maxwell-smart-computer
  maxwell-wallpaper-host
  opal
  wildfront
  sellers-first-mind-private
)

echo "Live (skip): ${LIVE[*]}"
echo "Keep unarchived (skip): ${KEEP_UNARCHIVED[*]}"
echo

for repo in "${DORMANT[@]}"; do
  echo "=== archive ${OWNER}/${repo} ==="
  gh repo archive "${OWNER}/${repo}" --yes 2>&1 || true
done

echo
echo "Done. Verify with: gh repo list ${OWNER} --limit 50 --json name,isArchived"
