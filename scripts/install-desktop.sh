#!/data/data/com.termux/files/usr/bin/bash
# install-desktop.sh — install XFCE NATIVELY in Termux (official x11-repo
# packages; the desktop runs in the Termux prefix, no container involved).
#
# The Ubuntu container remains available for CLI/server work; run its GUI
# apps on this desktop with scripts/container-app.sh.
set -Eeuo pipefail

log() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

[ -n "${TERMUX_VERSION:-}" ] || die "Run this inside Termux."

log "Enabling the X11 repository..."
pkg install -y x11-repo

log "Installing XFCE + friends in Termux (fast — these are native arm64 builds)..."
# Names are Termux names (verified against the termux-x11 index):
# xfdesktop (not xfdesktop4), mesa-demos (not mesa-utils), xorg-xdpyinfo,
# ttf-dejavu, dbus (no dbus-x11), no xterm in Termux.
pkg install -y \
  xfce4 xfdesktop xfce4-terminal \
  xfce4-whiskermenu-plugin xfce4-screenshooter \
  mousepad ristretto thunar-archive-plugin gvfs \
  dbus dbus-glib \
  mesa-demos xorg-xdpyinfo \
  ttf-dejavu adwaita-icon-theme hicolor-icon-theme

log "Installing a light browser in Termux..."
pkg install -y falkon || log "falkon skipped — install a browser later: pkg install falkon"

command -v startxfce4 >/dev/null 2>&1 || die "startxfce4 missing after install?!"

cat <<'EOF'

XFCE is installed natively in Termux. Start it with:
  bash scripts/desktop.sh

Run apps from the Ubuntu container on this desktop:
  bash scripts/container-app.sh <app>     # e.g. firefox, gimp
  (install those apps inside the container first:
   proot-distro login ubuntu  →  apt install <app>)

Notes:
  - Wallpaper/theme: right-click the desktop -> Desktop Settings.
  - Container apps appear as ordinary windows on this same desktop.
EOF
