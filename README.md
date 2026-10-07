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
3. Clone into `~/Projects/active/max-msi-worker`, or safely update an existing clone on `main`
4. `agent login` if needed (same Cursor account as iPhone; Linux file credential store)
5. Invoke `start-max-msi.sh` — one `Max-MSI` tmux session with the three live worker directories

**Keep the MSI awake.** The worker runs in tmux; the setup window may close.

Ubuntu must be initialized with a Linux user. Install prerequisites there first:
`sudo apt-get update && sudo apt-get install -y git tmux`.
The bootstrap selects the exact `Ubuntu` distro, matching `wsl -d Ubuntu`.

The bootstrap prefers the canonical path, then reuses `~/Projects/max-msi-worker`,
`~/projects/max-msi-worker`, or `~/projects/active/max-msi-worker` in that order.
A legacy clone stays in place; a symlink at the canonical path keeps the infra
worker directory available. An occupied canonical path fails without overwriting it.
Existing clones must have the expected GitHub origin, a clean working tree, and
branch `main`. Updates use fetch + fast-forward only; failures stop setup without
resetting, stashing, or switching branches. Resolve local changes or divergence
before retrying. An already-running tmux session is preserved, so updated code
applies on its next start.

The double-click launcher uses an adjacent `bootstrap-max-msi.ps1` when present;
otherwise it downloads the current main version. Keep the two files updated together.

### Retired Windows-native autostart

`install-autostart.ps1` now **disables and stops** the old
`Cursor-Max-MSI-Worker` scheduled task, preserving its configuration. It registers
no replacement task and starts no worker. Run it once on any Windows machine that
used native autostart:

```powershell
irm https://raw.githubusercontent.com/maxbuff152/max-msi-worker/main/install-autostart.ps1 | iex
```

Do not re-enable that task. Use the WSL bootstrap/double-click launcher after logon.
`fix-windows-worker.ps1` is also retired and fails with WSL instructions; it no
longer patches binaries or starts a native worker. Retirement takes effect on an
existing machine when the cleanup script is run; opening this PR does not change
its Task Scheduler configuration.

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
bash ~/Projects/active/max-msi-worker/start-max-msi.sh   # start if absent (preserves existing session)
```

Prefer **one worker + multiple `--worker-dir`s** over many locked workers on the same machine.
Prefer **one repo open per chat** when possible (multi-root is confusing).

Dormant GitHub remotes: `bash ~/bin/archive-dormant-github-repos.sh` (also copied here).

## Why Cloud agents cannot finish this alone

No self-hosted worker is registered until the MSI runs the bootstrap. Phone showing **No Personal Machines Available** is expected until then.

See [BLOCKED.md](./BLOCKED.md).

## Verification

Run `python3 -m unittest discover -s tests -v` and
`bash -n start-max-msi.sh msi-worker-dirs.sh`.
CI also parses the PowerShell entrypoints on Windows. The isolated Linux tests
exercise the embedded bootstrap payload, fresh and legacy paths (including spaces),
failed/unsafe updates, the shared launch command's three directory arguments,
and duplicate-session handling. They do not install a real CLI, log in, or change
Task Scheduler. A Windows/Ubuntu run is still needed to confirm the complete
interactive double-click/login flow and legacy task cleanup on the target machine.
