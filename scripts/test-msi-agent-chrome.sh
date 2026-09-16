#!/usr/bin/env bash
# Soft tests for MSI Agent Chrome helpers (no ForceRestart; no profile wipe).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
READY="$ROOT/bin/msi-agent-chrome-ready.sh"
PS1="$ROOT/scripts/msi-agent-chrome/Start-MsiAgentChrome.ps1"
HTML="$ROOT/scripts/msi-agent-chrome/sign-in.html"
FAIL=0

pass() { echo "PASS $1"; }
fail() { echo "FAIL $1"; FAIL=1; }

[[ -f "$READY" ]] && pass "ready script exists" || fail "ready script missing"
chmod +x "$READY" "$ROOT/scripts/test-msi-agent-chrome.sh" 2>/dev/null || true
[[ -f "$PS1" ]] && pass "Start-MsiAgentChrome.ps1 exists" || fail "ps1 missing"
[[ -f "$HTML" ]] && pass "sign-in.html exists" || fail "html missing"

grep -q 'Never wipe' "$READY" && pass "ready warns never wipe" || fail "ready missing never-wipe"
grep -q '9333' "$READY" && pass "default port 9333" || fail "port missing"
grep -q 'guiApplications=false' "$READY" && pass "documents WSLg off" || fail "WSLg note missing"
grep -q 'MsiAgentChrome' "$PS1" && pass "ps1 profile name" || fail "ps1 profile"
grep -q 'remote-debugging-port' "$PS1" && pass "ps1 CDP flag" || fail "ps1 CDP"
grep -q 'Firefox' "$HTML" && pass "html mentions Firefox lane" || fail "html firefox"
grep -q 'Lenovo' "$HTML" && pass "html mentions Lenovo boundary" || fail "html lenovo"

if "$READY" --install-only >/tmp/msi-agent-chrome-install-test.log 2>&1; then
  pass "install-only exits 0"
else
  fail "install-only failed"
  cat /tmp/msi-agent-chrome-install-test.log || true
fi

WIN_ROOT="/mnt/c/Users/Maxwe/AppData/Local/Maxwell/MsiAgentChrome"
[[ -f "$WIN_ROOT/Start-MsiAgentChrome.ps1" ]] && pass "windows ps1 installed" || fail "windows ps1 missing"
[[ -f "$WIN_ROOT/sign-in.html" ]] && pass "windows html installed" || fail "windows html missing"

if [[ "$FAIL" -ne 0 ]]; then
  echo "RESULT FAIL"
  exit 1
fi
echo "RESULT PASS"
exit 0
