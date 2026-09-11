# Max-MSI worker

**Goal:** Cursor iPhone → **My Machines / Remote Control** → **Max-MSI** (always-on Windows PC).

## DO THIS ON THE MSI (required)

Windows-native `agent worker` is broken (`better-sqlite3` NODE_MODULE **127 vs 137**; Cursor ticket **T-F70597**). Reinstalling the Windows CLI will **not** fix it.

**Official path: WSL Ubuntu + Linux Agent CLI.** Clone into the WSL home filesystem — **not** `/mnt/c/...`.

### Fastest (PowerShell on MSI)

```powershell
irm https://raw.githubusercontent.com/maxbuff152/max-msi-worker/main/bootstrap-max-msi.ps1 | iex
```

Or double-click [`START-MAX-MSI.cmd`](./START-MAX-MSI.cmd).

That will:
1. Install/use Ubuntu WSL if needed
2. `curl https://cursor.com/install -fsS | bash`
3. Clone into `~/projects/max-msi-worker`
4. `agent login` (same Cursor account as iPhone)
5. `agent worker start --name "Max-MSI"`

**Leave the WSL window open. Keep the MSI awake.**

### Then on iPhone / cursor.com/agents

Environment / Runtime picker → refresh → select **Max-MSI** → start an agent.

If the worker is missing: `agent worker debug`

## Manual WSL steps

```bash
curl https://cursor.com/install -fsS | bash
export PATH="$HOME/.local/bin:$PATH"
mkdir -p ~/Projects/active && cd ~/Projects/active
git clone https://github.com/maxbuff152/max-msi-worker.git
cd max-msi-worker
# Requires: agent login (same Cursor account as iPhone), then:
bash start-max-msi.sh
```

On this MSI WSL box, prefer `~/Projects/active` (Linux disk) over `/mnt/c` or lowercase `~/projects`.

## Why Cloud agents cannot finish this alone

No self-hosted worker is registered until the MSI runs the bootstrap. Phone showing **No Personal Machines Available** is expected until then.

See [BLOCKED.md](./BLOCKED.md).
