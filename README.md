# Max-MSI worker

Home repo for Cursor **My Machines** on the always-on Windows MSI.

Windows-native `agent worker` is broken (better-sqlite3 ABI **127 vs 137**).
Cursor support ticket **T-F70597**: official workaround is **WSL + Linux CLI**.

## One paste on the MSI (recommended)

PowerShell:

```powershell
irm https://raw.githubusercontent.com/maxbuff152/max-msi-worker/main/bootstrap-max-msi.ps1 | iex
```

This prefers WSL (official). If Ubuntu is missing it installs it. Complete `agent login` in the Ubuntu window, leave it running, keep MSI awake. Then phone → environment → **Max-MSI**.

## Manual WSL

```bash
curl https://cursor.com/install -fsS | bash
export PATH="$HOME/.local/bin:$PATH"
mkdir -p ~/projects && cd ~/projects
git clone https://github.com/maxbuff152/max-msi-worker.git
cd max-msi-worker
bash start-max-msi.sh
```

Repo must live under `~/...` in WSL, **not** `/mnt/c/...`.

## Windows-only fallback (unofficial ABI patch)

```powershell
irm https://raw.githubusercontent.com/maxbuff152/max-msi-worker/main/fix-windows-worker.ps1 | iex
```

## Autostart after first success

```powershell
irm https://raw.githubusercontent.com/maxbuff152/max-msi-worker/main/install-autostart.ps1 | iex
```

## Debug

```bash
agent worker debug
```
