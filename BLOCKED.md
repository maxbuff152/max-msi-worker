# Status — Max-MSI online

Cloud + MSI WSL work is done. **Pull to refresh on iPhone Runtime picker** and pick **Max-MSI** (phone may also show **MSI**). Soft-heal: `repair-max-msi.sh` + Windows park.

## Why not Windows-native worker
Windows Agent CLI crashes after register (`better-sqlite3` ABI **127 vs 137**). Cursor ticket **T-F70597**. Official workaround: **WSL + Linux CLI**.

## Devices (household)
| Device | Worker(s) | Notes |
|--------|-----------|-------|
| **MSI** | **Max-MSI** + **`~ @ MSI`** | This PC |
| **Mac** | DisplayName **`Logan`** (legacy misname) | Maxwell’s MacBook CUA/Messages |
| **Lenovo** | None yet | SSH `logan-lenovo` — person Logan’s laptop |

## MSI WSL status (2026-09-11)

| Worker | Role | Status |
|--------|------|--------|
| **Max-MSI** | My Machines / iPhone Remote Control | Online (isolated data dir) |
| **`~ @ MSI`** | Private Cloud Agent worker | Online |
| **`Logan`** (displayName) | **Mac** computer-use (misnamed) | Online |

CLI login: same Cursor account as phone (`AGENT_CLI_CREDENTIAL_STORE` / file store as configured).

CLI approvals: unrestricted / approve-all on Max-MSI as configured.

Max-MSI uses an isolated data dir so it does **not** fight the private worker lock. Restart helper: `bash ~/Projects/active/max-msi-worker/start-max-msi.sh`

Worker roots (via `~/bin/msi-worker-dirs.sh`): `SellersFirstWebsite`, `max-msi-worker`, `messages-loop`.

## Done checklist (agents / MSI)
- [x] Bootstrap / clone path ready on MSI WSL (`~/Projects/active/max-msi-worker`)
- [x] `agent login` completed (same account as phone)
- [x] Private worker `~ @ MSI` online
- [x] `Max-MSI` worker online (isolated data dir)
- [x] Multi `--worker-dir` map for site + infra + messages-loop
- [x] Max-MSI restarted once (idle) so worker-dirs attached

## Remaining human clicks (NOT done — Maxwell only)
Agents cannot finish these. Leave unchecked until Maxwell does them:

1. **iPhone Runtime picker** — pull to refresh → confirm **Max-MSI** (and/or **MSI**) appears → start a test agent against Max-MSI
2. **Fully quit Cursor desktop once** — so park can replace locked `agent-cli` directory with a file stub; then run `bash ~/Projects/active/max-msi-worker/park-windows-agent-workers.sh`
3. **Optional** — run `install-park-windows-workers.ps1` from an elevated/interactive Maxwell desktop session if Access Denied (not required; watcher already parks every ~10 min)
4. **Mac TCC** — System Settings → Privacy: grant **Accessibility** + **Screen Recording** to **Cursor Computer Use** (Mac Chrome stays Apple-integrations only)
5. **Pause sand clocks** that need a private worker while MSI is asleep (Grok/sand iMessage polls etc.)

Do **not** treat any of the above as complete until Maxwell confirms.
