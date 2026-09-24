#!/data/data/com.termux/files/usr/bin/bash
# desktop.sh — launch Termux:X11 + an XFCE desktop running NATIVELY in Termux.
#
# Why Termux-side and not inside the Ubuntu container: the container route
# needs --shared-tmp socket binds, cross-prefix user mapping and proot GL,
# all of which produced black screens on this device. The official
# termux-x11 README recommends exactly this setup: `pkg install xfce` from
# the x11-repo and run it on DISPLAY=:1 directly in Termux. The Ubuntu
# container stays your CLI/server Linux; run its GUI apps on this desktop
# with scripts/container-app.sh.
#
# Flow:
#   1. start the X server (background) and open the Termux:X11 activity
#   2. disable xfwm4 compositing (black desktop / vanishing panel on X11)
#   3. start XFCE in a plain background Termux shell, logging to a file
set -Eeuo pipefail

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

DISPLAY_NUM="${PD_DISPLAY:-:1}"
X11_ARGS="${PD_X11_ARGS:-}"
LOG="$HOME/.cache/xfce-session.log"

[ -n "${TERMUX_VERSION:-}" ] || die "Run this inside Termux."
command -v termux-x11 >/dev/null 2>&1 || die "termux-x11 missing — run scripts/install-x11.sh first."
command -v startxfce4 >/dev/null 2>&1 || \
  die "XFCE (Termux side) not installed — run scripts/install-desktop.sh first."

mkdir -p "$HOME/.cache"

log "Stopping any stale X server / XFCE session..."
pkill termux-x11 2>/dev/null || true
pkill -f 'startxfce4|xfce4-session|xfwm4|xfdesktop|xfce4-panel' 2>/dev/null || true
sleep 1

log "Starting Termux:X11 server on display ${DISPLAY_NUM}..."
# $X11_ARGS is intentionally unquoted: it may hold multiple flags
# shellcheck disable=SC2086
termux-x11 "$DISPLAY_NUM" $X11_ARGS >"$HOME/.cache/termux-x11.log" 2>&1 &
sleep 3

log "Opening the Termux:X11 activity on the phone..."
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1 || \
  warn "Could not auto-open the app — tap the Termux:X11 icon on your launcher."

log "Preparing the session (no compositor, sane runtime dir)..."
export XDG_RUNTIME_DIR="$PREFIX/tmp/xdg-runtime-$USER"
mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"

# compositing under Termux:X11 = black desktop / missing panel; keep it off
xfconf-query -c xfwm4 -p /general/use_compositing --create -t bool -s false >/dev/null 2>&1 || true

log "Starting XFCE (Termux-native, log: $LOG)..."
: > "$LOG"
nohup dbus-launch --exit-with-session bash -c '
  export DISPLAY="'"${DISPLAY_NUM}"'"
  exec startxfce4
' >>"$LOG" 2>&1 &

# wait for the panel to appear (max 60 s), then report state
up=0
for _ in $(seq 1 60); do
  if pgrep -x xfce4-panel >/dev/null 2>&1; then up=1; break; fi
  sleep 1
done
if [ "$up" = 1 ]; then
  log "XFCE is up. Check the Termux:X11 app."
else
  warn "panel not detected after 60 s — check the log:"
  warn "tail -40 $LOG"
  tail -20 "$LOG" || true
fi

cat <<EOF

Desktop running. Useful:
  tail -40 $LOG                   # session log
  pkill -f xfce4-session          # stop the desktop
  bash scripts/desktop.sh         # restart
  bash scripts/container-app.sh   # run an app from the Ubuntu container on this desktop

Black screen?  PD_X11_ARGS="-legacy-drawing" bash scripts/desktop.sh
Swapped colours?  PD_X11_ARGS="-force-bgra" bash scripts/desktop.sh
EOF
