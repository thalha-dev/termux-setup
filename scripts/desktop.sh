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
# -f: the X server runs under app_process; its name only appears in the
# cmdline, so a bare 'pkill termux-x11' never matches it.
pkill -f termux-x11 2>/dev/null || true
pkill -f 'startxfce4|xfce4-session|xfwm4|xfdesktop|xfce4-panel|xfsettingsd|xfconfd' 2>/dev/null || true
# a stale dbus-daemon hands out a dead socket address -> xfsettingsd fails
# with 'Could not connect: No such file or directory'
pkill -f dbus-daemon 2>/dev/null || true
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
# NOTE: Termux does not export $USER — use id(1); this died under set -u once
RUNTIME_UID="$(id -u 2>/dev/null || echo 0)"
export XDG_RUNTIME_DIR="$PREFIX/tmp/xdg-runtime-$RUNTIME_UID"
mkdir -p "$XDG_RUNTIME_DIR"; chmod 700 "$XDG_RUNTIME_DIR"

# compositing under Termux:X11 = black desktop / missing panel; keep it off
xfconf-query -c xfwm4 -p /general/use_compositing --create -t bool -s false >/dev/null 2>&1 || true

log "Starting XFCE (Termux-native, log: $LOG)..."
: > "$LOG"
# shellcheck disable=SC2016  # the $(...) must expand inside the session shell
nohup bash -c '
  export DISPLAY="'"${DISPLAY_NUM}"'"
  # fresh session bus; its address must be in the env of EVERY XFCE
  # component, or xfsettingsd dies with "Unable to contact settings server"
  eval "$(dbus-launch --sh-syntax)" || exit 1
  echo "dbus: $DBUS_SESSION_BUS_ADDRESS"
  exec startxfce4
' >>"$LOG" 2>&1 &

# wait for the panel to appear (max 60 s), then report state
up=0
for _ in $(seq 1 60); do
  if pgrep -af startxfce4 >/dev/null 2>&1 && pgrep -x xfwm4 >/dev/null 2>&1; then up=1; break; fi
  sleep 1
done
if [ "$up" = 1 ]; then
  log "XFCE is up. Check the Termux:X11 app."
else
  warn "session not detected after 60 s — last log lines:"
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
