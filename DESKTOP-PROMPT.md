# Desktop Cursor prompt (paste into Cursor on the MSI)

Open **Cursor on the MSI** → Agents / Chat → paste everything below.

---

Set up Cursor My Machines / Remote Control on this PC so my iPhone can run agents here as "Max-MSI".

Context:
- Windows-native `agent worker` is broken (better-sqlite3 NODE_MODULE 127 vs 137; Cursor ticket T-F70597). Do NOT use the Windows CLI worker. Do NOT use Tailscale.
- Official workaround: WSL Ubuntu + Linux Agent CLI. Repo must live on the WSL filesystem (prefer ~/Projects/active), NOT under /mnt/c.

Do this on this machine:
1. Ensure Ubuntu WSL is installed. If missing: `wsl --install -d Ubuntu`, then finish first-run user setup if needed.
2. Inside WSL (not PowerShell):
   curl https://cursor.com/install -fsS | bash
   export PATH="$HOME/.local/bin:$PATH"
3. Clone into WSL home (not /mnt/c):
   mkdir -p ~/Projects/active && cd ~/Projects/active
   git clone https://github.com/maxbuff152/max-msi-worker.git
   cd max-msi-worker
4. Run:
   agent login
   (same Cursor account as iPhone)
   agent worker debug
   bash start-max-msi.sh
5. Keep this PC awake. The worker runs in tmux; the setup window may close.
6. If the legacy Windows-native autostart task was installed, run install-autostart.ps1 in PowerShell once to disable/stop it. Do not run fix-windows-worker.ps1; it is retired.

Prefer the bootstrap below: it updates clean main clones with fast-forward only,
reuses legacy checkouts in place, and invokes the shared start-max-msi.sh launcher.
Install git + tmux inside Ubuntu first if missing. Do not reset or delete existing work.

Or one-shot from PowerShell:
irm https://raw.githubusercontent.com/maxbuff152/max-msi-worker/main/bootstrap-max-msi.ps1 | iex

When the worker is running, say so. If anything fails, run `agent worker debug` and show the output.
