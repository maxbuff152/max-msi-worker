# Status — Max-MSI online

Cloud + MSI WSL work is done. **Pull to refresh on iPhone Runtime picker** and pick **Max-MSI** (or **`~ @ MSI`** for the private worker).

## Why not Windows-native worker
Windows Agent CLI crashes after register (`better-sqlite3` ABI **127 vs 137**). Cursor ticket **T-F70597**. Official workaround: **WSL + Linux CLI**.

## MSI WSL status (2026-09-11)

| Worker | Role | Status |
|--------|------|--------|
| **Max-MSI** | My Machines / iPhone Remote Control | Online (isolated data dir) |
| **`~ @ MSI`** | Private Cloud Agent worker | Online |
| **Logan** | Mac computer-use | Online |

CLI login: `maxwell@sellersfirsthomesolutions.com` (`AGENT_CLI_CREDENTIAL_STORE=file`).

CLI approvals: `approvalMode=unrestricted` (approve-all / Run Everything) in `~/.cursor/cli-config.json`.

Max-MSI uses `CURSOR_DATA_DIR=~/.cursor/max-msi-worker-data` so it does **not** fight the private worker lock. Restart helper: `bash ~/Projects/active/max-msi-worker/start-max-msi.sh`

Worker roots (via `~/bin/msi-worker-dirs.sh`): `SellersFirstWebsite`, `max-msi-worker`, `messages-loop`.

## Done checklist
- [x] Bootstrap / clone path ready on MSI WSL (`~/Projects/active/max-msi-worker`)
- [x] `agent login` completed (same account as phone)
- [x] Private worker `~ @ MSI` online
- [x] `Max-MSI` worker online (isolated data dir)
- [x] Multi `--worker-dir` map for site + infra + messages-loop
- [ ] Confirm visible in iPhone Runtime picker (pull to refresh)
- [ ] Test agent started from iPhone against Max-MSI
- [ ] Restart Max-MSI once (idle) so new worker-dirs attach
