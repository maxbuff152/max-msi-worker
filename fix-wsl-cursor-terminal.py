#!/usr/bin/env python3
"""Soft-heal Cursor WSL terminal indefinite hangs (no WSL shutdown, no PC reboot).

Root cause: shell integration cannot attach to wsl.exe, so agent/UI waits forever
for command-finished markers. See docs/ops-wsl-cursor-terminal-hang.md.

Usage (WSL):
  python3 ~/Projects/active/max-msi-worker/fix-wsl-cursor-terminal.py

Usage (Windows PowerShell):
  python \\\\wsl$\\Ubuntu-24.04\\home\\maxwell\\Projects\\active\\max-msi-worker\\fix-wsl-cursor-terminal.py
"""

from __future__ import annotations

import json
import os
import shutil
import sys
from datetime import datetime
from pathlib import Path


def settings_path() -> Path:
    appdata = os.environ.get("APPDATA")
    if appdata:
        return Path(appdata) / "Cursor" / "User" / "settings.json"
    # Called from WSL against the Windows Cursor profile
    win_home = Path("/mnt/c/Users/maxwe")
    return win_home / "AppData" / "Roaming" / "Cursor" / "User" / "settings.json"


def main() -> int:
    path = settings_path()
    if not path.is_file():
        print(f"ERROR: Cursor settings not found: {path}", file=sys.stderr)
        return 1

    stamp = datetime.now().strftime("%Y%m%d%H%M%S")
    backup = path.with_name(f"{path.name}.bak-terminal-hang-{stamp}")
    shutil.copy2(path, backup)

    raw = path.read_text(encoding="utf-8")
    try:
        data = json.loads(raw)
    except json.JSONDecodeError as exc:
        print(
            f"ERROR: Cursor settings JSON is corrupt: {path}\n"
            f"Backup already saved at: {backup}\n"
            f"Parser detail: {exc}",
            file=sys.stderr,
        )
        return 1

    wsl_args = ["-d", "Ubuntu-24.04", "-u", "maxwell"]
    profiles = data.setdefault("terminal.integrated.profiles.windows", {})
    profiles["Ubuntu-24.04"] = {
        "path": "C:\\Windows\\System32\\wsl.exe",
        "args": wsl_args,
        "icon": "terminal-ubuntu",
    }
    profiles.setdefault(
        "PowerShell",
        {"source": "PowerShell", "icon": "terminal-powershell"},
    )

    data["terminal.integrated.defaultProfile.windows"] = "Ubuntu-24.04"
    data["terminal.integrated.automationProfile.windows"] = {
        "path": "C:\\Windows\\System32\\wsl.exe",
        "args": wsl_args,
    }
    data["terminal.integrated.shellIntegration.enabled"] = False
    data["terminal.integrated.gpuAcceleration"] = "off"
    data.setdefault("terminal.integrated.scrollback", 5000)

    # Preserve CRLF if the Windows profile used it.
    newline = "\r\n" if "\r\n" in raw else "\n"
    out = json.dumps(data, indent=4, ensure_ascii=False) + "\n"
    if newline == "\r\n":
        out = out.replace("\n", "\r\n")
    path.write_text(out, encoding="utf-8", newline="")

    print(f"OK: patched {path}")
    print(f"Backup: {backup}")
    print("Next (no reboot): kill stuck Cursor terminals → Developer: Reload Window → echo ok")
    print("Prefer Remote-WSL for coding; keep Max-MSI Linux worker for phone agents.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
