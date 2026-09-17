#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/bin:$PATH"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# Drop CR if a Windows write leaked one
sed -i 's/\r$//' \
  "$HOME/bin/msi-worker-dirs.sh" \
  "$HOME/bin/msi-worker-status" \
  "$HOME/bin/repair-max-msi.sh" \
  "$ROOT/msi-worker-dirs.sh" \
  "$ROOT/msi-worker-status" \
  "$ROOT/start-max-msi.sh" \
  "$ROOT/repair-max-msi.sh" \
  "$ROOT/park-windows-agent-workers.sh" \
  "$ROOT/scripts/restart-and-verify.sh" 2>/dev/null || true

chmod +x \
  "$HOME/bin/msi-worker-dirs.sh" \
  "$HOME/bin/msi-worker-status" \
  "$HOME/bin/repair-max-msi.sh" \
  "$ROOT/msi-worker-dirs.sh" \
  "$ROOT/msi-worker-status" \
  "$ROOT/start-max-msi.sh" \
  "$ROOT/repair-max-msi.sh" \
  "$ROOT/park-windows-agent-workers.sh" \
  "$ROOT/scripts/restart-and-verify.sh" \
  "$ROOT/scripts/test-worker-health.sh"

echo "=== sync bin wrappers ==="
cp -f "$ROOT/msi-worker-dirs.sh" "$HOME/bin/msi-worker-dirs.sh"
cp -f "$ROOT/msi-worker-status" "$HOME/bin/msi-worker-status"
cat > "$HOME/bin/repair-max-msi.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
REPO="${HOME}/Projects/active/max-msi-worker/repair-max-msi.sh"
exec bash "$REPO" "$@"
EOF
chmod +x "$HOME/bin/repair-max-msi.sh"

echo "=== flags ==="
bash "$HOME/bin/msi-worker-dirs.sh" --print-flags

echo "=== health tests (no restart) ==="
bash "$ROOT/scripts/test-worker-health.sh"
node "$ROOT/scripts/test-fleet-status.mjs"

echo "=== soft repair (park + no-op if up) ==="
bash "$ROOT/repair-max-msi.sh"

echo "=== status ==="
bash "$HOME/bin/msi-worker-status"

if [[ "${1:-}" == "--restart" || "${1:-}" == "-r" ]]; then
  echo "=== restart Max-MSI ==="
  bash "$ROOT/start-max-msi.sh" --restart
  sleep 1
  pgrep -af 'worker start --name Max-MSI' || true
fi
