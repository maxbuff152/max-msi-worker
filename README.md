# Max-MSI worker

**Goal:** Cursor iPhone → **My Machines / Remote Control** → **Max-MSI** (always-on Windows PC).

**Agents:** [AGENTS.md](./AGENTS.md) (safe vs mutating, Cloud vs MSI).

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

Environment / Runtime picker → **pull to refresh** → select **Max-MSI** → start an agent.

If the worker is missing: `agent worker debug`

**Still Maxwell (human clicks — not done by agents):** iPhone Runtime picker confirm · Mac TCC (Accessibility + Screen Recording for Cursor Computer Use) · Tailscale sign-in (MSI / Mac / Lenovo) · Enable Builds for SFHS. Details: [BLOCKED.md](./BLOCKED.md).

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

### Worker dirs (2026-09-12)

`start-max-msi.sh` registers **only** these three live git roots (see `~/bin/msi-worker-dirs.sh` + `~/.cursor/memory/REPOS.md`):

1. `~/Projects/active/SellersFirstWebsite` — SFHS site (primary)
2. `~/Projects/active/max-msi-worker` — this infra repo
3. `~/Projects/active/messages-loop` — Mac SMS/email ops (Messages Continuity)

Do **not** add labs, deal-packets, or archived Maximize remotes as worker dirs.

```bash
bash ~/bin/msi-worker-status          # show map (safe; no restart)
bash ~/Projects/active/max-msi-worker/start-max-msi.sh   # start/restart Max-MSI
```

Prefer **one worker + multiple `--worker-dir`s** over many locked workers on the same machine.
Prefer **one repo open per chat** when possible (multi-root is confusing).

Dormant GitHub remotes: `bash ~/bin/archive-dormant-github-repos.sh` (also copied here).

## Why Cloud agents cannot finish this alone

No self-hosted worker is registered until the MSI runs the bootstrap. Phone showing **No Personal Machines Available** is expected until then.

See [BLOCKED.md](./BLOCKED.md).
