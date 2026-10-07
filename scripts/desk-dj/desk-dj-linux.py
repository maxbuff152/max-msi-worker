#!/usr/bin/env python3
"""Linux Desk DJ; reuse Jarvis's Spotify owner, with isolated schedule/state."""
import argparse
import datetime as dt
import fcntl
import json
import os
from pathlib import Path
import random
import subprocess
import sys
import time
from zoneinfo import ZoneInfo

def choose(config, last, now):
    pool = [s for s in config["sources"] + config.get("personal_slots", [])
            for _ in range(max(0, int(s.get("weight", 0)))) if s.get("uri")]
    if not pool:
        raise ValueError("No weighted sources")
    different = [s for s in pool if s["uri"] != last]
    pool = different or pool
    return random.Random(int(now.strftime("%Y%m%d")) * 17 + now.hour * 31 + 7).choice(pool)

def in_window(config, now):
    return config["window"]["start"] <= now.strftime("%H:%M") < config["window"]["stop"]

def volume_target(config):
    try:
        target = float(config.get("playback_volume", 0.25))
    except (TypeError, ValueError):
        target = 0.25
    if not __import__("math").isfinite(target):
        target = 0.25
    return max(0.0, min(1.0, target))

class Desktop:
    def __init__(self):
        sys.path.insert(0, str(Path.home() / "Projects/active/jarvis"))
        import jarvis_modes
        self.spotify = jarvis_modes

    def set_volume(self, target):
        subprocess.run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "0"], check=True)
        subprocess.run(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", str(target)], check=True)
        result = subprocess.check_output(["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"], text=True).strip()
        if "[MUTED]" in result or abs(float(result.split()[1]) - target) > 0.02:
            raise RuntimeError("Volume readback mismatch: " + result)
        return result

    def play(self, uri):
        if not self.spotify.spotify_open(uri):
            raise RuntimeError("Spotify did not expose MPRIS; sign-in or desktop check needed")
        for _ in range(10):
            if self.spotify.spotify_playing():
                return
            time.sleep(0.5)
        raise RuntimeError("Spotify did not report Playing; selected URI may need manual confirmation")

    def pause(self):
        if self.spotify.spotify_up():
            self.spotify.spotify_pause()
            if self.spotify.spotify_playing():
                raise RuntimeError("Spotify remained Playing after pause")

    def status(self):
        return {"spotify_up": self.spotify.spotify_up(),
                "playing": self.spotify.spotify_playing()}

def execute(action, config, state_path, desktop, now):
    if action == "status":
        return desktop.status()
    if action == "stop":
        desktop.pause()
        return {"action": action, **desktop.status()}
    if action == "rotate" and not in_window(config, now):
        return {"action": action, "skipped": "outside window"}
    try:
        last = json.loads(state_path.read_text()).get("uri", "")
    except (OSError, ValueError):
        last = ""
    source = choose(config, last, now)
    volume = desktop.set_volume(volume_target(config))
    desktop.play(source["uri"])
    state_path.parent.mkdir(parents=True, exist_ok=True)
    tmp = state_path.with_suffix(".tmp")
    tmp.write_text(json.dumps({"uri": source["uri"], "label": source["label"],
                               "at": now.isoformat()}) + "\n")
    tmp.replace(state_path)
    return {"action": action, "uri": source["uri"], "label": source["label"],
            "volume": volume, **desktop.status()}

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=["now", "start", "rotate", "stop", "status"])
    args = parser.parse_args()
    action = "start" if args.action == "now" else args.action
    root = Path(__file__).resolve().parent
    config = json.loads((root / "playlist-config.json").read_text())
    state_root = Path.home() / ".local/state/maxwell/desk-dj"
    state_root.mkdir(parents=True, exist_ok=True)
    os.environ.setdefault("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    os.environ.setdefault("DBUS_SESSION_BUS_ADDRESS", "unix:path=" + os.environ["XDG_RUNTIME_DIR"] + "/bus")
    with (state_root / "lock").open("w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        result = execute(action, config, state_root / "state.json", Desktop(),
                         dt.datetime.now(ZoneInfo(config["timezone"])))
    print(json.dumps(result))
if __name__ == "__main__":
    main()
