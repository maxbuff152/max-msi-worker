#!/usr/bin/env bash
# Start Max-MSI Cursor My Machines worker (run inside Ubuntu WSL)
set -euo pipefail
export PATH="$HOME/.local/bin:$HOME/.cursor/bin:$PATH"

if ! command -v agent >/dev/null 2>&1; then
  echo "Installing Cursor Agent CLI..."
  curl https://cursor.com/install -fsS | bash
  export PATH="$HOME/.local/bin:$HOME/.cursor/bin:$PATH"
fi

echo "==> agent --version"
agent --version || true

echo "==> Login with the SAME Cursor account as your iPhone"
agent login

echo "==> worker debug"
agent worker debug || true

echo "==> Starting Max-MSI (leave this terminal open; keep MSI awake)"
exec agent worker start --name "Max-MSI" --idle-release-timeout 0
