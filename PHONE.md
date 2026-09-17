# Phone → Max-MSI

Account: `info@sellersfirsthomesolutions.com`  
Runtime: **My Machines / private worker** (WSL), never Windows Local.

## Pick this

| Want to work on… | Pick this |
|------------------|-----------|
| Anything on the MSI brain (site, infra, messages) | **Max-MSI** (phone may also show **MSI**) |

One WSL brain worker. Wire name on the process is always **Max-MSI**.

## Durability
- Logon autostart: Windows task `Cursor-Max-MSI-WSL-Worker` → `start-max-msi.sh`
- Self-heal every ~10 min: `Cursor-Max-MSI-WSL-Worker-Watcher` → `repair-max-msi.sh`
- That repair also runs `park-windows-agent-workers.sh` (trade-safe)
- Windows Cursor worker is **parked** (ABI 127 vs 137) — do not revive it

## Soft-heal proof (2026-09-17)
- Watcher path `…/max-msi-worker/repair-max-msi.sh` exists again (was missing → LastResult 127).
- After fix, `Cursor-Max-MSI-WSL-Worker-Watcher` LastResult = **0**.
- Live wire: **Max-MSI** / tmux `max-msi-worker` / three worker-dirs.
- Windows `.spec` markers parked (0 live). `agent-cli` may stay a **directory** until Maxwell fully quits Cursor desktop once.

## Start tasks from the PC
Use [cursor.com/agents](https://cursor.com/agents) or Agents Window → **Max-MSI** / **MSI**.  
Never Local / This computer / CODEX SPINE (Windows worker is ABI-broken).

## Grok Bot / sand clocks
Keep sand schedules that spawn private-worker Cursor agents **paused** unless the Max-MSI worker is proven online. Retarget any leftover clocks to **Max-MSI** (or **Mac** for iMessage).

## Worker dirs (three only)
1. `~/Projects/active/website`
2. `~/Projects/active/max-msi-worker`
3. `~/Projects/active/messages-loop`
