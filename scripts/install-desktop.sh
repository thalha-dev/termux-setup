#!/data/data/com.termux/files/usr/bin/bash
# install-desktop.sh — OPTIONAL: XFCE inside the Ubuntu container (~500 MB).
# Run this only when you want the GUI. Then launch with scripts/desktop.sh.
set -Eeuo pipefail

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

CONTAINER="${PD_CONTAINER_NAME:-ubuntu}"
ROOTFS="$PREFIX/var/lib/proot-distro/containers/$CONTAINER/rootfs"

[ -n "${TERMUX_VERSION:-}" ] || die "Run this inside Termux."
[ -d "$ROOTFS" ] || die "Container '$CONTAINER' not found — run scripts/setup-ubuntu.sh first."

command -v termux-x11 >/dev/null 2>&1 || \
  die "termux-x11 companion missing — run scripts/install-x11.sh first."

log "Installing/refreshing the desktop packages inside the container (fast when already installed)..."
proot-distro login "$CONTAINER" -- /bin/bash -s <<'EOS'
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends \
  xfce4 xfce4-terminal dbus-x11 \
  desktop-base xfdesktop4 \
  xfce4-whiskermenu-plugin xfce4-screenshooter \
  mousepad ristretto thunar-archive-plugin \
  xterm mesa-utils x11-xserver-utils \
  fonts-dejavu adwaita-icon-theme tango-icon-theme
EOS

[ -x "$ROOTFS/usr/bin/startxfce4" ] || die "startxfce4 still missing after install."

cat <<'EOF'

XFCE installed. Launch the desktop with:
  bash scripts/desktop.sh

The terminal running desktop.sh must stay in the foreground session (or use
Termux's wake lock). Phone tip: in Termux:X11's Preferences you can enable
"Fullscreen" and adjust the extra-keys row later.
EOF
