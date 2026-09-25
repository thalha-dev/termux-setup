#!/data/data/com.termux/files/usr/bin/bash
# install-desktop.sh — full XFCE desktop INSIDE the Ubuntu container,
# plus the GPU-acceleration pieces on the Termux side.
#
# Everything is a standard Ubuntu 24.04 package (names verified against the
# Ubuntu noble index — the Termux-name mismatch that once broke this script
# only applies to the Termux side). Bloaty on purpose: browser, media,
# GL/Vulkan tooling and benchmarks included.
set -Eeuo pipefail

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

CONTAINER="${PD_CONTAINER_NAME:-ubuntu}"
ROOTFS="$PREFIX/var/lib/proot-distro/containers/$CONTAINER/rootfs"

[ -n "${TERMUX_VERSION:-}" ] || die "Run this inside Termux."
[ -d "$ROOTFS" ] || die "Container '$CONTAINER' not found — run scripts/setup-ubuntu.sh first."

# ── Termux side: GPU proxy server ───────────────────────────────────────────
log "Installing the VirGL GPU proxy in Termux (x11-repo)..."
pkg install -y x11-repo
pkg install -y virglrenderer-android || \
  warn "virglrenderer-android failed — desktop will use software rendering."

# ── Container side: full desktop ────────────────────────────────────────────
log "Installing XFCE + apps + GL/Vulkan stack inside the container (big, one shot)..."
proot-distro login "$CONTAINER" -- /bin/bash -s <<'EOS'
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y --no-install-recommends \
  xfce4 xfce4-goodies xfce4-terminal \
  dbus-x11 dbus-user-session \
  desktop-base xfdesktop4 \
  mousepad ristretto gvfs \
  xterm x11-xserver-utils \
  mesa-utils mesa-vulkan-drivers vulkan-tools glmark2 \
  fonts-dejavu adwaita-icon-theme

# Real Firefox: Ubuntu's own 'firefox' package is a snap stub and snap cannot
# work under proot — use the Mozilla Team PPA with apt pinning instead.
if ! apt-get install -y --no-install-recommends firefox-esr 2>/dev/null; then
  apt-get install -y --no-install-recommends software-properties-common gnupg
  add-apt-repository -y ppa:mozillateam/ppa
  apt-get update -y
  apt-get install -y -t 'o=LP-PPA-mozillateam' firefox
  printf 'Package: *\nPin: release o=LP-PPA-mozillateam\nPin-Priority: 1001\n' \
    > /etc/apt/preferences.d/mozilla-firefox
fi

echo
echo "── container desktop install complete ──"
EOS

[ -x "$ROOTFS/usr/bin/startxfce4" ] || die "startxfce4 missing after install?!"

cat <<'EOF'

Desktop installed INSIDE the Ubuntu container. Start it with:
  bash scripts/desktop.sh

GPU acceleration: desktop.sh auto-starts the VirGL proxy in Termux and the
container uses it (GALLIUM_DRIVER=virpipe). Verify after start:
  bash scripts/container-app.sh glxinfo    # want "OpenGL renderer: virgl"
  bash scripts/container-app.sh glmark2    # benchmark vs llvmpipe

Included apps (Applications menu): Firefox, Xfce terminal, Thunar,
Ristretto, Mousepad, XTerm, glmark2, vulkan-tools (vkcube).
EOF
