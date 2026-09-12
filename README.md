# Max-MSI worker

**Goal:** Cursor iPhone → **My Machines / Remote Control** → clear MSI labels (Website / Infra / Messages).

## Phone labels (what you should see)

| Phone label | Repo | Use when |
|-------------|------|----------|
| **MSI Website** | `SellersFirstWebsite` | Site / deploy / SFHS web |
| **MSI Infra** | `max-msi-worker` | This PC’s Cursor worker / bootstrap |
| **MSI Messages** | `messages-loop` | Mac texts / email notify brain |

Pull to refresh on [cursor.com/agents](https://cursor.com/agents) after restart. The old single **Max-MSI** row (website-only label) is replaced by these three.

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
3. Clone into `~/Projects/active/max-msi-worker`
4. `agent login` (same Cursor account as iPhone)
5. `bash start-max-msi.sh` → starts the three labeled workers

**Leave the WSL window open. Keep the MSI awake.**

### Then on iPhone / cursor.com/agents

Environment / Runtime picker → **pull to refresh** → select **MSI Website**, **MSI Infra**, or **MSI Messages** → start an agent.

If a worker is missing: `agent worker debug`

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

### Why three workers (2026-09-12)

Cursor shows a multi-`--worker-dir` machine under the **first** repo only (usually the website). To get honest phone labels, we run **one worker per live repo** with a friendly `--name`:

1. `MSI Website` → `~/Projects/active/SellersFirstWebsite`
2. `MSI Infra` → `~/Projects/active/max-msi-worker`
3. `MSI Messages` → `~/Projects/active/messages-loop`

Do **not** add labs, deal-packets, or archived Maximize remotes as worker dirs.

```bash
bash ~/bin/msi-worker-status          # show labels (safe; no restart)
bash ~/Projects/active/max-msi-worker/start-max-msi.sh   # restart all three labels
```

Map: `~/bin/msi-worker-dirs.sh` + `~/.cursor/memory/REPOS.md`.

Dormant GitHub remotes: `bash ~/bin/archive-dormant-github-repos.sh` (also copied here).

## Why Cloud agents cannot finish this alone

No self-hosted worker is registered until the MSI runs the bootstrap. Phone showing **No Personal Machines Available** is expected until then.

See [BLOCKED.md](./BLOCKED.md).
