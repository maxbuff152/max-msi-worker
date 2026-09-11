# BLOCKED — waiting on MSI keyboard

Cloud-side work is done. **Max-MSI cannot come online until someone runs the bootstrap on the Windows PC.**

## Why
- Windows Agent CLI worker crashes: better-sqlite3 ABI 127 vs 137
- Cursor support ticket **T-F70597**: use WSL Linux CLI until Windows package is fixed
- This cloud agent has **no shell/RDP/Sunshine/TriggerCMD/GH runner** path to the MSI

## Do this on the MSI (one of)

**A. Double-click** (download first):
[START-MAX-MSI.cmd](./START-MAX-MSI.cmd)

**B. PowerShell one-liner:**
```powershell
irm https://raw.githubusercontent.com/maxbuff152/max-msi-worker/main/bootstrap-max-msi.ps1 | iex
```

Then on iPhone: Agents → environment → **Max-MSI**.

## Done checklist
- [ ] Bootstrap ran on MSI
- [ ] `agent login` completed (same account as phone)
- [ ] Worker process left running / MSI awake
- [ ] Max-MSI visible in environment picker
- [ ] Test agent started from iPhone against Max-MSI
