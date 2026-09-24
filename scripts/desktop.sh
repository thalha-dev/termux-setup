#!/data/data/com.termux/files/usr/bin/bash
# desktop.sh — launch Termux:X11 + an XFCE session inside the Ubuntu container.
#
# Flow (per termux-x11 README "Using with proot environment"):
#   1. start the X server on the Termux side (background)
#   2. open the Termux:X11 activity on the phone
#   3. run the desktop session inside the container, detached
#      (--shared-tmp/--shared-x11 give it access to the X socket)
#
# Stop it: expand the Termux:X11 notification -> Exit, then:
#   pkill termux-x11 && proot-distro kill "$PD_CONTAINER_NAME"
set -Eeuo pipefail

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

CONTAINER="${PD_CONTAINER_NAME:-ubuntu}"
DISPLAY_NUM="${PD_DISPLAY:-:1}"
X11_ARGS="${PD_X11_ARGS:-}"
ROOTFS="$PREFIX/var/lib/proot-distro/containers/$CONTAINER/rootfs"

[ -n "${TERMUX_VERSION:-}" ] || die "Run this inside Termux."
[ -d "$ROOTFS" ] || die "Container '$CONTAINER' not found — run scripts/setup-ubuntu.sh first."
[ -x "$ROOTFS/usr/bin/startxfce4" ] || \
  die "XFCE not installed in the container — run scripts/install-desktop.sh first."
command -v termux-x11 >/dev/null 2>&1 || die "termux-x11 missing — run scripts/install-x11.sh first."

log "Stopping any stale termux-x11 instance..."
pkill termux-x11 2>/dev/null || true
sleep 1

log "Starting Termux:X11 server on display ${DISPLAY_NUM}..."
# $X11_ARGS is intentionally unquoted: it may hold multiple flags
# shellcheck disable=SC2086
termux-x11 "$DISPLAY_NUM" $X11_ARGS >/dev/null 2>&1 &
sleep 4

log "Opening the Termux:X11 activity on the phone..."
am start --user 0 -n com.termux.x11/com.termux.x11.MainActivity >/dev/null 2>&1 || \
  warn "Could not auto-open the app — tap the Termux:X11 icon on your launcher."

log "Launching XFCE inside the container (detached)..."
proot-distro login "$CONTAINER" --shared-tmp --shared-x11 --detach -- \
  /bin/bash -lc "export DISPLAY='${DISPLAY_NUM}'; dbus-launch --exit-with-session startxfce4"

cat <<EOF

XFCE is starting. Check the Termux:X11 app on screen (give it ~10 s first time).

Useful:
  proot-distro ps                      # see running container sessions
  proot-distro kill ${CONTAINER}       # stop the desktop session
  pkill termux-x11                     # stop the X server
  Restart anytime: bash scripts/desktop.sh

If the screen is black: PD_X11_ARGS="-legacy-drawing" bash scripts/desktop.sh
If colours look swapped: PD_X11_ARGS="-force-bgra" bash scripts/desktop.sh
If fonts are huge: add '-dpi 120' via PD_X11_ARGS or fix XFCE Appearance DPI.
EOF
