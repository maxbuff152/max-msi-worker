# Max-MSI worker

Home repo for Cursor **My Machines** on the always-on Windows MSI.

Windows-native `agent worker` is broken (better-sqlite3 ABI **127 vs 137**).
Cursor support ticket **T-F70597**: official workaround is **WSL + Linux CLI**.

## Fastest path on the MSI (Windows PowerShell)

Unofficial but community-verified ABI patch, then starts **Max-MSI**:

```powershell
irm https://raw.githubusercontent.com/maxbuff152/max-msi-worker/main/fix-windows-worker.ps1 | iex
```

Sign in with the **same Cursor account as iPhone**. Leave the window open. Keep MSI awake.
Then on phone / cursor.com/agents → environment → **Max-MSI**.

## Official path (WSL Ubuntu)

```powershell
wsl --install -d Ubuntu   # once, reboot if asked
```

Inside Ubuntu:

```bash
curl https://cursor.com/install -fsS | bash
export PATH="$HOME/.local/bin:$PATH"
mkdir -p ~/projects && cd ~/projects
git clone https://github.com/maxbuff152/max-msi-worker.git
cd max-msi-worker
bash start-max-msi.sh
```

Repo must live under `~/...` in WSL, **not** `/mnt/c/...`.

## Debug

```bash
agent worker debug
```
