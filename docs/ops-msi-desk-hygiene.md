# MSI desk hygiene — open Cursor right, one repo, canonical worker dirs

**2026-09-17** applied with Maxwell “Do all of them.”

## Habits

| Do | Don’t |
|----|-------|
| `open-cursor-wsl site\|worker\|msg` | Open `D:\WSL` for coding |
| One repo per Cursor window/chat | Multi-root website+worker+messages for day work |
| Worker dirs = `SellersFirstWebsite`, `max-msi-worker`, `messages-loop` | `--worker-dir …/website` symlink |
| Soft-restart: `start-max-msi.sh --restart` | `wsl --shutdown` / PC reboot without consent |

## Soft-heal / apply

```bash
# Canonical worker-dir map (also synced to ~/bin)
bash ~/bin/msi-worker-status

# Soft-restart Max-MSI (drops in-flight Max-MSI agents only)
bash ~/Projects/active/max-msi-worker/start-max-msi.sh --restart

# Open coding window correctly
open-cursor-wsl site
```

Windows: `D:\WSL\open-cursor-wsl.ps1 site`

## Also applied on this MSI

- Cursor `shellIntegration` off + simpler WSL profile (terminal hang)
- Legacy Terminal tool flipped **off** (`state.vscdb`)
- GPU terminal accel off
- `~/.bashrc` no longer puts Windows System32 on PATH (use `winpath` / `powershell.exe` alias)
- Stale `msi-*-worker-data` dirs archived under `~/.cursor/archive/worker-data-stale-20260917/`

Details: [ops-wsl-cursor-terminal-hang.md](./ops-wsl-cursor-terminal-hang.md)
