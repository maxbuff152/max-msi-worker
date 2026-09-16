# Ops: Desktop "Preparing request" stuck — park Windows workers (2026-09-16)

## Verdict
Desktop Agents hung on **Preparing request** because Windows Cursor auto-spawned broken `anysphere.cursor-agent-worker` processes (`better-sqlite3` ABI **127 vs 137**, ticket **T-F70597**). Phone / web → WSL **MSI** stayed healthy.

Trading / FOMC watch and the **Stale trading tasks** agent were left alone.

## Before → After

```text
Desktop task start
Before Windows worker crash-loop → Preparing forever
After  Windows workers parked; use MSI

Windows agent-cli
Before live (broken ABI)
After  agent-cli.PARKED-ABI-BROKEN
```

## What changed
- Added `park-windows-agent-workers.ps1` / `.sh` (kills **only** Cursor Windows worker PIDs; protects `fomc|intraday|trading|…`).
- Hooked park into existing watcher: `Cursor-Max-MSI-WSL-Worker-Watcher` → `repair-max-msi.sh` (every ~10 min). Separate Windows task registration was Access Denied from this lane — not required.
- Quarantined Windows `agent-cli` → `agent-cli.PARKED-ABI-BROKEN` and left a **file stub** at `agent-cli` so Cursor cannot recreate a usable worker CLI.
- Left WSL **MSI** / **Max-MSI** and FOMC vol watch running.

## How to start tasks from the PC now
1. Prefer [cursor.com/agents](https://cursor.com/agents) → environment **MSI**.
2. Or Cursor Agents Window → **MSI** (not Local / This computer / CODEX SPINE).
3. Fully quit + reopen Cursor once if an old Preparing spinner is still up (needed so Windows can drop the locked `agent-cli` folder and the park stub can stick).

## Soft-heal
- Every ~10 min: `Cursor-Max-MSI-WSL-Worker-Watcher` runs `repair-max-msi.sh` → `park-windows-agent-workers.sh`.
- Optional one-shot: `install-park-windows-workers.ps1` (may need an interactive Maxwell desktop session if Access Denied).

## Do not
- Do not revive the Windows private worker.
- Do not run `fix-windows-worker.ps1` unless Maxwell explicitly wants a Windows worker again.
- Do not kill WSL MSI workers or trading processes to “fix” desktop hang.
