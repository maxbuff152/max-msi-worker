# max-msi-worker

Infra repo for Maxwell’s always-on **Max-MSI** desktop worker (SFHS / household Cursor). This is **not** an application: no package manager, tests, or server.

**Goal:** iPhone / [cursor.com/agents](https://cursor.com/agents) → **My Machines / Remote Control** → **Max-MSI**.

Official path is **WSL Ubuntu + Linux Agent CLI**. Windows-native `agent worker` is broken (`better-sqlite3` ABI **127 vs 137**, Cursor ticket **T-F70597**). Reinstalling the Windows CLI will not fix it.

## Purpose

- Document and start the Max-MSI self-hosted worker so the phone/dashboard can pick it.
- Keep the `--worker-dir` map to **three live git roots** only.
- Record human-only gates in [BLOCKED.md](./BLOCKED.md).

Product work lives in the other two worker dirs (`SellersFirstWebsite`, `messages-loop`). Prefer **one repo open per chat**.

## Layout

| Path | Role |
|------|------|
| [README.md](./README.md) | Human setup (WSL bootstrap, picker, worker dirs) |
| [BLOCKED.md](./BLOCKED.md) | Live status + remaining Maxwell clicks |
| [DESKTOP-PROMPT.md](./DESKTOP-PROMPT.md) | Paste-into-Cursor-on-MSI prompt |
| `start-max-msi.sh` | Start Max-MSI in tmux (isolated data dir) |
| `msi-worker-dirs.sh` | Canon `--worker-dir` list |
| `msi-worker-status` | Print the map (no restart) |
| `bootstrap-max-msi.ps1` / `START-MAX-MSI.cmd` | First-time MSI PowerShell → WSL bootstrap |
| `install-autostart.ps1` | Windows logon task (legacy native path) |
| `fix-windows-worker.ps1` | Unofficial Windows ABI patch — prefer WSL |
| `archive-dormant-github-repos.sh` | Archives dormant GitHub remotes |

## Safe vs mutating

Default to **read / edit docs and scripts**. Do not treat this checkout as the physical MSI.

**Read-only / safe**

- Edit markdown, rules, and helper scripts in this repo.
- `bash msi-worker-dirs.sh --list` or `--print-flags` (uses the repo copy).
- On the MSI only: `bash msi-worker-status` (sources `~/bin/msi-worker-dirs.sh`; will fail on a Cloud VM).

**Mutating — only on the physical MSI, and only when asked**

- `start-max-msi.sh` — starts a tmux worker. Exits if session `max-msi-worker` already exists. **Do not restart while an agent is mid-run.**
- `bootstrap-max-msi.ps1` / `START-MAX-MSI.cmd` — install WSL/CLI, `agent login`, start worker.
- `fix-windows-worker.ps1` — patches `cursor-agent` binaries. Unofficial; do not use unless Maxwell wants native Windows.
- `install-autostart.ps1` — registers a Windows Scheduled Task.
- `archive-dormant-github-repos.sh` — `gh repo archive` on dormant remotes. Never the three live repos or the `KEEP_UNARCHIVED` list.

**Do not**

- Use Windows-native `agent worker` as the official path.
- Clone or run the worker from `/mnt/c/...` (use the WSL Linux disk: `~/Projects/active`).
- Add labs, deal-packets, or archived remotes as worker dirs.
- Treat [BLOCKED.md](./BLOCKED.md) human clicks as agent-completable.
- Commit secrets, tokens, or anything under `CURSOR_DATA_DIR`.

## Run / test

There is no `npm`/`pytest`/`go test` loop. Verify with reads and bash syntax.

```bash
# Safe on any Linux checkout (including Cursor Cloud)
bash msi-worker-dirs.sh --list
bash -n msi-worker-dirs.sh start-max-msi.sh archive-dormant-github-repos.sh
```

On **MSI WSL** (human or an agent already running there):

```bash
export PATH="$HOME/.local/bin:$PATH"
bash ~/Projects/active/max-msi-worker/msi-worker-status   # safe; no restart
# Only when idle:
# bash ~/Projects/active/max-msi-worker/start-max-msi.sh
# agent worker debug
```

Prefer **one worker + multiple `--worker-dir`s** over many locked workers on the same machine.

## Conventions

- Worker dirs (canon, see `msi-worker-dirs.sh`):  
  1. `~/Projects/active/SellersFirstWebsite` — SFHS site  
  2. `~/Projects/active/max-msi-worker` — this infra  
  3. `~/Projects/active/messages-loop` — Mac SMS/email ops  
- Max-MSI uses isolated `CURSOR_DATA_DIR=$HOME/.cursor/max-msi-worker-data` so it does not fight the private **`~ @ MSI`** worker.
- Same Cursor account as the iPhone. `AGENT_CLI_CREDENTIAL_STORE=file`.
- Keep README, BLOCKED.md, and this file aligned when the worker map or human gates change.
- **Maxwell only:** iPhone Runtime picker pull-to-refresh, Mac TCC (Accessibility + Screen Recording for Cursor Computer Use), Tailscale sign-in (MSI / Mac / Lenovo), Enable Builds for SFHS. Details: [BLOCKED.md](./BLOCKED.md).

## Cursor Cloud specific instructions

A Cloud Agent VM is **not** the MSI. Cloud + MSI WSL setup is already done; the remaining gaps are human clicks on real devices.

- Do **not** run bootstrap, `agent login`, `agent worker start`, PowerShell, or `archive-dormant-github-repos.sh` on the Cloud VM.
- Do **not** install the Windows CLI or apply the ABI patch from Cloud.
- Stay in this repo unless the task explicitly needs a sibling checkout.
- Proof of change here is a doc/script diff plus `bash -n` / `--list`, not a live worker.
