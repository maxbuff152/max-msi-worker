# Ops: All Agents “Unable To Complete Request” fix (2026-09-15)

## Verdict
ERROR spam came from Grok Bot (`sand`) private-worker agents targeting label **Max-MSI** while the live worker is **MSI**, plus an extra Windows Cursor worker under CODEX SPINE.

## Before → After

```text
Unarchived sand ERROR agents
Before ████████ ~25
After  ░░░░░░░░ 0

Live workers (info@)
Before MSI + CODEX SPINE Windows worker
After  MSI + Max-MSI compat alias (same box)
```

## What changed
- Archived all visible sand/Grok ERROR background composers (iMessage ROWID polls, Max-MSI probes, weekday health retries).
- Parked Windows `anysphere.cursor-agent-worker` for CODEX SPINE (killed processes; moved `bee8853689` / `b6cfff0027` specs to `parked-2026-09-15`).
- Started **Max-MSI** as a WSL compat alias of **MSI** so leftover Grok schedules stop hard-failing.
- Glass Automations: only Slack Digest remains (left enabled).
- Mac: existing **Mac** worker process left running; keychain still locked over SSH (needs one interactive unlock for CLI).

## Why better now
- Phone/All Agents list should stop filling with permanent “No self-hosted workers…” failures.
- Canonical label stays **MSI**; alias is temporary compatibility only.

## New
- `start-max-msi.sh` starts MSI + Max-MSI alias.
- This ops note.

## Next
1. In Grok Bot desktop: confirm clocks that spawn Cursor private workers stay parked / delete iMessage+health schedules, or retarget keepers to **MSI** / **Mac**.
2. At Mac keyboard: unlock login keychain once; ensure Mac worker is `info@…`.
3. After schedules are retargeted, remove the Max-MSI alias and keep only MSI.
4. Do not revive the Windows CODEX SPINE private worker.
