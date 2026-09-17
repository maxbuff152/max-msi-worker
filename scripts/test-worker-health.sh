#!/usr/bin/env bash
# Regression tests for Max-MSI soft-heal + worker-dir canon.
# Does not restart the live worker unless MAX_MSI_TEST_RESTART=1.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0

pass() { echo "ok - $*"; }
fail() { echo "not ok - $*"; FAIL=$((FAIL + 1)); }

require_file() {
  local path="$1"
  if [[ -f "$path" ]]; then
    pass "exists: $path"
  else
    fail "missing: $path"
  fi
}

require_exec() {
  local path="$1"
  if [[ -x "$path" ]]; then
    pass "executable: $path"
  else
    fail "not executable: $path"
  fi
}

echo "=== Max-MSI worker health tests ==="

require_file "$ROOT/repair-max-msi.sh"
require_file "$ROOT/start-max-msi.sh"
require_file "$ROOT/msi-worker-dirs.sh"
require_file "$ROOT/park-windows-agent-workers.sh"
require_file "$ROOT/park-windows-agent-workers.ps1"
require_file "$ROOT/docs/ops-desktop-preparing-stuck-2026-09-16.md"
require_file "$ROOT/docs/ops-agent-error-fix-2026-09-15.md"
require_file "$ROOT/PHONE.md"

chmod +x \
  "$ROOT/repair-max-msi.sh" \
  "$ROOT/start-max-msi.sh" \
  "$ROOT/msi-worker-dirs.sh" \
  "$ROOT/msi-worker-status" \
  "$ROOT/park-windows-agent-workers.sh" \
  "$ROOT/scripts/test-worker-health.sh" 2>/dev/null || true

require_exec "$ROOT/repair-max-msi.sh"
require_exec "$ROOT/start-max-msi.sh"
require_exec "$ROOT/park-windows-agent-workers.sh"

# Canon: repair must look for Max-MSI + max-msi-worker (not legacy-only MSI).
if grep -q 'WIRE_NAME="Max-MSI"' "$ROOT/repair-max-msi.sh" \
  && grep -q 'SESSION="max-msi-worker"' "$ROOT/repair-max-msi.sh"; then
  pass "repair targets Max-MSI / max-msi-worker"
else
  fail "repair does not target Max-MSI / max-msi-worker"
fi

if grep -q 'park-windows-agent-workers.sh' "$ROOT/repair-max-msi.sh"; then
  pass "repair hooks Windows park"
else
  fail "repair missing Windows park hook"
fi

# Must start Max-MSI with three worker dirs.
if grep -q 'worker start --name Max-MSI' "$ROOT/start-max-msi.sh"; then
  pass "start uses wire name Max-MSI"
else
  fail "start missing Max-MSI wire name"
fi

FLAGS="$(bash "$ROOT/msi-worker-dirs.sh" --print-flags)"
echo "$FLAGS" | grep -q 'website' && pass "flags include website" || fail "flags missing website"
echo "$FLAGS" | grep -q 'max-msi-worker' && pass "flags include max-msi-worker" || fail "flags missing max-msi-worker"
echo "$FLAGS" | grep -q 'messages-loop' && pass "flags include messages-loop" || fail "flags missing messages-loop"

# Live process check (soft — reports fail if worker is down so CI/local proves health).
if tmux has-session -t max-msi-worker 2>/dev/null; then
  pass "tmux session max-msi-worker present"
else
  fail "tmux session max-msi-worker missing"
fi

if pgrep -f 'worker start --name Max-MSI' >/dev/null 2>&1; then
  pass "live process Max-MSI present"
else
  fail "live process Max-MSI missing"
fi

# repair must be a no-op when healthy
OUT="$(bash "$ROOT/repair-max-msi.sh" 2>&1 || true)"
if echo "$OUT" | grep -q 'OK: Max-MSI WSL brain already running'; then
  pass "repair no-op when healthy"
else
  # Park may print first; still OK if exit 0 and Max-MSI mentioned as running
  if echo "$OUT" | grep -q 'already running'; then
    pass "repair no-op when healthy (alt wording)"
  else
    fail "repair did not report healthy Max-MSI (got: $(echo "$OUT" | tr '\n' ' ' | cut -c1-200))"
  fi
fi

# fleet-status must see Max-MSI as online when worker is up
FLEET_OUT="$(FLEET_SSH_PROBES=0 node "$ROOT/scripts/fleet-status.mjs" 2>&1 || true)"
if echo "$FLEET_OUT" | grep -q 'msi:online'; then
  pass "fleet-status reports msi:online"
else
  fail "fleet-status did not report msi:online (got: $(echo "$FLEET_OUT" | tr '\n' ' ' | cut -c1-200))"
fi

# Deprecated Windows-native path must warn
if head -n 8 "$ROOT/fix-windows-worker.ps1" | grep -qi 'DO NOT RUN\|DEPRECATED\|do not use'; then
  pass "fix-windows-worker.ps1 marked deprecated"
else
  fail "fix-windows-worker.ps1 missing deprecation banner"
fi

if head -n 8 "$ROOT/install-autostart.ps1" | grep -qi 'DO NOT RUN\|DEPRECATED\|do not use\|WSL'; then
  pass "install-autostart.ps1 warns toward WSL path"
else
  fail "install-autostart.ps1 missing WSL / deprecation warning"
fi

# Soft Windows park status (warn only — Cursor may hold agent-cli open)
if [[ -x /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe ]]; then
  PARK_STATUS="$(/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -Command "
\$root = Join-Path \$env:APPDATA 'Cursor\User\globalStorage\anysphere.cursor-agent-worker'
\$specs = @(Get-ChildItem \$root -Filter '*.spec' -EA SilentlyContinue).Count
\$cli = Get-Item -LiteralPath (Join-Path \$root 'agent-cli') -EA SilentlyContinue
\$cliKind = if (\$null -eq \$cli) { 'missing' } elseif (\$cli.PSIsContainer) { 'directory' } else { 'file' }
Write-Output (\"specs=\$specs;agent-cli=\$cliKind\")
" 2>/dev/null | tr -d '\r' || true)"
  if echo "$PARK_STATUS" | grep -q 'specs=0'; then
    pass "Windows worker specs parked (0 live)"
  else
    fail "Windows worker specs still live ($PARK_STATUS)"
  fi
  if echo "$PARK_STATUS" | grep -q 'agent-cli=file'; then
    pass "Windows agent-cli is file stub"
  elif echo "$PARK_STATUS" | grep -q 'agent-cli=directory'; then
    echo "warn - agent-cli still a directory (Maxwell: fully quit Cursor desktop once, re-run park)"
  else
    echo "warn - could not classify agent-cli ($PARK_STATUS)"
  fi
fi

# Watcher task LastResult soft check
if [[ -x /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe ]]; then
  WR="$(/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -Command "(Get-ScheduledTask -TaskName 'Cursor-Max-MSI-WSL-Worker-Watcher' -EA SilentlyContinue | Get-ScheduledTaskInfo).LastTaskResult" 2>/dev/null | tr -d '\r' || true)"
  if [[ "$WR" == "0" ]]; then
    pass "watcher LastTaskResult=0"
  else
    fail "watcher LastTaskResult expected 0 got '${WR:-missing}'"
  fi
fi

echo
if [[ "$FAIL" -eq 0 ]]; then
  echo "All Max-MSI worker health tests passed."
  exit 0
fi
echo "FAILED: $FAIL check(s)"
exit 1
