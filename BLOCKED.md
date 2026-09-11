# BLOCKED — waiting on MSI keyboard

Cloud-side work is done. **Max-MSI cannot appear in the iPhone Runtime picker until someone runs the bootstrap on the Windows PC.**

## What the phone shows (confirmed)
Runtime → Remote Control → **No Personal Machines Available**  
"Open Cursor on your computer with Remote Control enabled to register one."

That empty state is correct today: no healthy worker is registered (cloud probe = 0).

## Why desktop Remote Control toggle alone fails on Windows
Windows Agent CLI worker crashes after register (`better-sqlite3` ABI **127 vs 137**). Cursor ticket **T-F70597**. Official workaround: **WSL + Linux CLI**.

## Do this on the MSI (required)

**PowerShell one-liner:**
```powershell
irm https://raw.githubusercontent.com/maxbuff152/max-msi-worker/main/bootstrap-max-msi.ps1 | iex
```

**Or double-click:** [START-MAX-MSI.cmd](./START-MAX-MSI.cmd)

Complete login in the Ubuntu window. Leave it running. Keep MSI awake.

Then on iPhone: Runtime picker → pull to refresh → select **Max-MSI**.

If worker missing: `agent worker debug`

## Done checklist
- [x] Bootstrap / clone path ready on MSI WSL (`~/Projects/active/max-msi-worker`)
- [ ] `agent login` completed (same account as phone) — **do this next**
- [ ] Worker process left running / MSI awake
- [ ] Max-MSI visible in iPhone Runtime picker (not only Cloud)
- [ ] Test agent started from iPhone against Max-MSI

## Update (2026-09-11)

Private Cloud Agent worker `~ @ MSI` is already running on this WSL box (Cursor Agent Worker). That covers Cloud Agents on this machine.

Still separate: CLI `agent login` + `agent worker start --name Max-MSI` for iPhone **My Machines / Remote Control**.
