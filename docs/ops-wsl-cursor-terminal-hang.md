# WSL Cursor terminal hangs indefinitely

**Symptom:** Cursor integrated terminal / agent shell spins forever after a command that already finished (or a new WSL tab never becomes usable).

**Verified on MSI (2026-09-17):** Cursor `3.20.21` + Windows host opening WSL via `wsl.exe`.

## Root cause

`ptyhost.log` repeats:

```text
Shell integration cannot be enabled for executable "C:\Windows\System32\wsl.exe"
```

Cursor’s agent terminal waits for shell-integration “command finished” markers. Those markers never arrive on a Windows→`wsl.exe` ConPTY profile, so the UI looks stuck forever even though bash already printed output.

Nested profile args (`--cd ~/ -- bash -l`) make this worse. Opening Linux trees through `\\wsl$\...` from a Windows Cursor window adds file-watcher noise on top.

## Soft heal (no reboot, no `wsl --shutdown`)

1. Kill the stuck terminal tab(s) in Cursor (trash icon), or `Terminal: Kill All Terminals`.
2. `Developer: Reload Window` (not a PC restart).
3. Open a fresh terminal with profile **Ubuntu-24.04**.
4. Prefer coding via **Remote-WSL** (`anysphere.remote-wsl`): open folder as `\\wsl$\Ubuntu-24.04\home\maxwell\Projects\active\...` *through* the WSL remote window, or from Ubuntu run `cursor .` inside the Linux repo.
5. For phone / Max-MSI agents: keep using the Linux worker (`start-max-msi.sh`) — that path does not depend on the Windows integrated terminal.

Do **not** run `wsl --shutdown` unless Maxwell explicitly allows it (drops Max-MSI + tunnels).

## Durable fix (settings)

Apply with (WSL preferred):

```bash
python3 ~/Projects/active/max-msi-worker/fix-wsl-cursor-terminal.py
```

Or from Windows PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File \\wsl$\Ubuntu-24.04\home\maxwell\Projects\active\max-msi-worker\fix-wsl-cursor-terminal.ps1
```

The patcher:

- Backs up `%APPDATA%\Cursor\User\settings.json`
- Simplifies the Ubuntu WSL profile (no nested `bash -l`)
- Sets `terminal.integrated.automationProfile.windows` to the same WSL distro
- Sets `terminal.integrated.shellIntegration.enabled` to `false` (stops waiting for markers `wsl.exe` cannot emit)
- Sets `terminal.integrated.gpuAcceleration` to `off` (fewer ConPTY freezes)

Then: kill terminals → Reload Window → smoke-test `echo ok`.

## If it still hangs

1. Cursor Settings → **Agents → Terminal → Legacy Terminal**: try the opposite of current (MSI had `useLegacyTerminalTool: true` in `state.vscdb`).
2. Temporarily set default profile to **PowerShell** and prefix agent commands with `wsl.exe -d Ubuntu-24.04 -u maxwell --`.
3. Update Cursor + `anysphere.remote-wsl`; this class of hang is a known Windows+WSL Cursor bug.

## Evidence pointers

- `%APPDATA%\Cursor\logs\<latest>\ptyhost.log`
- `%APPDATA%\Cursor\User\settings.json`
- Live Linux repos: `~/Projects/active/{SellersFirstWebsite,max-msi-worker,messages-loop}` — not `D:\WSL` and not `/mnt/c/...`
