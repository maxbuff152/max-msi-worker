#!/usr/bin/env bash
# Start Max-MSI worker inside Ubuntu WSL (official path).
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

if ! command -v agent >/dev/null 2>&1; then
  curl https://cursor.com/install -fsS | bash
  export PATH="$HOME/.local/bin:$PATH"
fi

agent --version || true
agent login
agent worker debug || true
exec agent worker start --name "Max-MSI"
