# Ops: Sand / All Agents ERROR spam (2026-09-15)

## Verdict
Grok Bot / sand agents ERROR when they target a private worker that is **offline**, **renamed**, or **Windows-native ABI-broken**. Symptom in the Agents list: many archived ERROR runs with `usePrivateWorker: true` and `privateWorkerId: null`.

## Cause
1. Private worker not connected (MSI asleep, tmux dead, wrong start path).
2. Name drift — schedules targeting **MSI** while the live wire is **Max-MSI** (or the reverse).
3. Windows Local worker crash-loop (see `ops-desktop-preparing-stuck-2026-09-16.md`).

## Fix (durable)
- Keep **one** WSL brain: wire **Max-MSI**, session `max-msi-worker`.
- Autostart + watcher soft-heal (`repair-max-msi.sh`).
- Park Windows workers every watcher tick.
- Pause or retarget sand clocks that need a private worker when MSI is offline.
- Prefer [cursor.com/agents](https://cursor.com/agents) → **Max-MSI** for new work.

## Do not
- Do not spin a second MSI worker “just in case.”
- Do not leave sand iMessage / health polls firing against a dead machine.
