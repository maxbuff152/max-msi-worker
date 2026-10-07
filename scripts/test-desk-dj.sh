#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
pass(){ echo "PASS $1"; }
fail(){ echo "FAIL $1"; FAIL=1; }

[[ -f "$ROOT/bin/desk-dj.sh" ]] && pass "desk-dj.sh" || fail "desk-dj.sh"
[[ -f "$ROOT/scripts/desk-dj/Invoke-DeskDJ.ps1" ]] && pass "Invoke-DeskDJ.ps1" || fail "ps1"
[[ -f "$ROOT/scripts/desk-dj/playlist-config.json" ]] && pass "config" || fail "config"
grep -q '3w55ItlH4pvaQbxoLsXtrj' "$ROOT/scripts/desk-dj/playlist-config.json" && pass "DeeBaby hardest playlist" || fail "deebaby hardest"
grep -q '6jxLcPfLvVwcz7bmzOWwwE' "$ROOT/scripts/desk-dj/playlist-config.json" && pass "DeeBaby artist" || fail "deebaby artist"
grep -q '6EN5jR0b57rqUaGuCoZhtD' "$ROOT/scripts/desk-dj/playlist-config.json" && pass "H-Town" || fail "htown"
grep -q 'BigWalkDog' "$ROOT/scripts/desk-dj/playlist-config.json" && pass "Logan orbit artists" || fail "orbit"
grep -q 'SFHS-DeskDJ-Start' "$ROOT/scripts/desk-dj/Invoke-DeskDJ.ps1" && pass "schedule task name" || fail "schedule"

chmod +x "$ROOT/bin/desk-dj.sh" "$ROOT/scripts/test-desk-dj.sh" 2>/dev/null || true
if [[ "$FAIL" -ne 0 ]]; then echo RESULT FAIL; exit 1; fi
echo RESULT PASS
