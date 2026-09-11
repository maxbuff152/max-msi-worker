# Max-MSI worker

Bring **Max-MSI** online for Cursor iPhone **My Machines / Remote Control**.

Windows-native `agent worker` is broken (better-sqlite3 ABI 127 vs 137; Cursor ticket **T-F70597**).
**Official workaround: WSL + Linux CLI.** Repo must live under `~/...`, not `/mnt/c`.

## On the MSI (PowerShell)

```powershell
irm https://raw.githubusercontent.com/maxbuff152/max-msi-worker/main/bootstrap-max-msi.ps1 | iex
```

Or double-click [`START-MAX-MSI.cmd`](./START-MAX-MSI.cmd).

Then on iPhone Runtime picker → refresh → **Max-MSI**.

## Manual WSL

```bash
curl https://cursor.com/install -fsS | bash
export PATH="$HOME/.local/bin:$PATH"
mkdir -p ~/projects && cd ~/projects
git clone https://github.com/maxbuff152/max-msi-worker.git
cd max-msi-worker
bash start-max-msi.sh
```

## Debug

```bash
agent worker debug
```
