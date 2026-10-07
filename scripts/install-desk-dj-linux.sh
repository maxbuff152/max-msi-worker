#!/usr/bin/env bash
# Install checked source and schedule; does not start music.
set -euo pipefail
SRC="$(cd "$(dirname "$0")/desk-dj" && pwd)"
INSTALL="$HOME/.local/share/maxwell/desk-dj"
UNITS="$HOME/.config/systemd/user"
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
mkdir -p "$INSTALL" "$UNITS" "$HOME/.local/bin"
if [[ -f "$INSTALL/desk-dj-linux.py" ]]; then
  BACKUP="$INSTALL/backup-$(date +%Y%m%dT%H%M%S)"
  mkdir -p "$BACKUP"
  cp "$INSTALL/desk-dj-linux.py" "$INSTALL/playlist-config.json" "$BACKUP/"
fi
cp "$SRC/desk-dj-linux.py" "$SRC/playlist-config.json" "$INSTALL/"
cat > "$HOME/.local/bin/desk-dj" <<'WRAPPER'
#!/usr/bin/env bash
exec python3 "$HOME/.local/share/maxwell/desk-dj/desk-dj-linux.py" "$@"
WRAPPER
chmod +x "$HOME/.local/bin/desk-dj"
cat > "$UNITS/maxwell-desk-dj@.service" <<'SERVICE'
[Unit]
Description=Maxwell Desk DJ (%i)
[Service]
Type=oneshot
ExecStart=%h/.local/bin/desk-dj %i
TimeoutStartSec=60
Environment=DISPLAY=:0
Environment=XAUTHORITY=%h/.Xauthority
SERVICE
for ACTION in start rotate stop; do
  case "$ACTION" in
    start) HOURS=09 ;;
    rotate) HOURS=11,13,15,17 ;;
    stop) HOURS=19 ;;
  esac
  cat > "$UNITS/maxwell-desk-dj-$ACTION.timer" <<TIMER
[Unit]
Description=Maxwell Desk DJ daily $ACTION
[Timer]
OnCalendar=*-*-* $HOURS:00:00 America/Chicago
AccuracySec=1s
Persistent=false
Unit=maxwell-desk-dj@$ACTION.service
[Install]
WantedBy=timers.target
TIMER
done
systemctl --user daemon-reload
systemctl --user enable --now maxwell-desk-dj-start.timer maxwell-desk-dj-rotate.timer maxwell-desk-dj-stop.timer
systemctl --user list-timers --all 'maxwell-desk-dj-*' --no-pager
