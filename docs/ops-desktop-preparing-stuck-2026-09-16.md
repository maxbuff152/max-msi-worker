# Ops: Desktop "Preparing request" stuck — park Windows workers (2026-09-16)

## Verdict
Desktop Agents hung on **Preparing request** because Windows Cursor auto-spawned broken `anysphere.cursor-agent-worker` processes (`better-sqlite3` ABI **127 vs 137**, ticket **T-F70597**). Phone / web → WSL **Max-MSI** stayed healthy when the worker was up.

Trading / FOMC watch processes are left alone by the park script.

## Before → After

```text
Desktop task start
Before Windows worker crash-loop → Preparing forever
After  Windows workers parked; use Max-MSI

Soft-heal watcher
Before repair-max-msi.sh missing → LastResult=127
After  repo repair-max-msi.sh aligns to Max-MSI + parks Windows

Windows agent-cli
Before live (broken ABI) / recreated as directory
After  agent-cli.PARKED-ABI-BROKEN + file stub
```

## What changed
- `park-windows-agent-workers.ps1` / `.sh` kill **only** Cursor Windows worker PIDs; protect `fomc|intraday|trading|…`.
- Watcher `Cursor-Max-MSI-WSL-Worker-Watcher` → `repair-max-msi.sh` (every ~10 min) parks Windows + restarts Max-MSI if down.
- Quarantine Windows `agent-cli` → `agent-cli.PARKED-ABI-BROKEN` and leave a **file stub** at `agent-cli`.
- Leave WSL **Max-MSI** and trading alone.

## Names (do not mix)
| Role | Value |
|------|--------|
| Wire / process | **Max-MSI** |
| tmux session | `max-msi-worker` |
| Phone display | often **MSI** (same machine) |
| Do not use | Windows Local / CODEX SPINE / Windows-native agent-cli |

## How to start tasks
1. Prefer [cursor.com/agents](https://cursor.com/agents) → **Max-MSI** (or MSI if that row maps here).
2. Or Cursor Agents Window → **Max-MSI** / **MSI** (not Local / This computer).
3. Fully quit + reopen Cursor once if an old Preparing spinner is still up (needed so Windows can drop a locked `agent-cli` folder).

## Soft-heal
- Logon: `Cursor-Max-MSI-WSL-Worker` → `start-max-msi.sh`
- Every ~10 min: `Cursor-Max-MSI-WSL-Worker-Watcher` → `repair-max-msi.sh` → park + restart if needed
- Optional: `install-park-windows-workers.ps1` (may need Maxwell desktop if Access Denied)

## Do not
- Do not revive the Windows private worker.
- Do not run `fix-windows-worker.ps1` unless Maxwell explicitly wants a Windows worker again.
- Do not kill WSL Max-MSI or trading processes to “fix” desktop hang.
- Do not rename the live wire away from **Max-MSI** without updating repair, fleet-status, and sand targets together.
