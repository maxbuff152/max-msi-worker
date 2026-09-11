# BLOCKED — waiting on MSI keyboard

Cloud-side work is done. **Confirm Max-MSI / `~ @ MSI` on the iPhone Runtime picker.**

## What the phone may show
Runtime → Remote Control → **No Personal Machines Available** until the WSL worker is registered and the phone refreshes.

## Why desktop Remote Control toggle alone fails on Windows
Windows Agent CLI worker crashes after register (`better-sqlite3` ABI **127 vs 137**). Cursor ticket **T-F70597**. Official workaround: **WSL + Linux CLI**.

## MSI WSL status (2026-09-11)

Private Cloud Agent worker **`~ @ MSI`** is online on this WSL box. `agent worker debug` lists it under Visibility.

CLI login is persisted with `AGENT_CLI_CREDENTIAL_STORE=file` as `maxwell@sellersfirsthomesolutions.com`.

Do **not** start a second `agent worker` on the same data dir — it conflicts with the private worker lock.

On iPhone: Runtime picker → pull to refresh → select **`~ @ MSI`** / **Max-MSI**.

If worker missing: `agent worker debug`

## Done checklist
- [x] Bootstrap / clone path ready on MSI WSL (`~/Projects/active/max-msi-worker`)
- [x] `agent login` completed (same account as phone)
- [x] Worker process left running (`~ @ MSI` private worker online)
- [~] Max-MSI / `~ @ MSI` visible in iPhone Runtime picker (confirm on phone)
- [ ] Test agent started from iPhone against MSI

## Optional bootstrap (fresh machine)

**PowerShell one-liner:**
```powershell
irm https://raw.githubusercontent.com/maxbuff152/max-msi-worker/main/bootstrap-max-msi.ps1 | iex
```

**Or double-click:** [START-MAX-MSI.cmd](./START-MAX-MSI.cmd)
