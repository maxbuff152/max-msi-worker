# Max-MSI worker

Home repo for Cursor **My Machines** on the always-on Windows MSI.

## Why this exists
Windows-native `agent worker` is currently broken (better-sqlite3 ABI 127 vs 137).
Cursor support ticket **T-F70597** confirmed: use **WSL + Linux CLI** until the Windows package is fixed.

## One-time setup on the MSI

1. Install Ubuntu WSL if needed (Admin PowerShell):
   ```powershell
   wsl --install -d Ubuntu
   ```
   Reboot if asked, open Ubuntu once to create a Linux user.

2. In **Ubuntu** (not PowerShell):
   ```bash
   curl https://cursor.com/install -fsS | bash
   export PATH="$HOME/.local/bin:$PATH"
   mkdir -p ~/projects && cd ~/projects
   git clone https://github.com/maxbuff152/max-msi-worker.git
   cd max-msi-worker
   bash start-max-msi.sh
   ```

3. Keep that terminal open. Keep the MSI awake.
4. On iPhone / cursor.com/agents → environment → **Max-MSI**.

If the machine does not appear: `agent worker debug`
