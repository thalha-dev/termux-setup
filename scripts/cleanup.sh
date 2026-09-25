#!/data/data/com.termux/files/usr/bin/bash
# cleanup.sh — undo pieces of the setup, in increasing levels of destruction.
#
#   bash scripts/cleanup.sh gui             # delete EVERYTHING GUI (see below)
#   bash scripts/cleanup.sh termux-desktop  # remove today's Termux-native XFCE (superseded)
#   bash scripts/cleanup.sh config          # fresh XFCE profile inside the container
#   bash scripts/cleanup.sh desktop         # + remove desktop packages from the container
#   bash scripts/cleanup.sh container       # + DELETE the whole Ubuntu container
#   bash scripts/cleanup.sh all             # + remove Termux-side X11/GPU packages
#
# 'gui' = container desktop+Firefox+GL stack, Termux-side X11/GPU packages,
# session artifacts and logs. KEEPS: the container itself (CLI), proot-distro,
# git, Termux base. The Termux:X11 APK (Android app) is uninstalled manually.
set -Eeuo pipefail

CONTAINER="${PD_CONTAINER_NAME:-ubuntu}"
LEVEL="${1:-}"
PD_BASE="$PREFIX/var/lib/proot-distro"
ROOTFS="$PD_BASE/containers/$CONTAINER/rootfs"

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }
run_in_container() { proot-distro login "$CONTAINER" -- /bin/bash -s; }

[ -n "${TERMUX_VERSION:-}" ] || die "Run this inside Termux."
case "$LEVEL" in
  gui|termux-desktop|config|desktop|container|all) ;;
  *) sed -n '2,10p' "$0"; exit 1 ;;
esac

log "Stopping sessions (X server needs -f: it runs under app_process)..."
pkill -f termux-x11 2>/dev/null || true
pkill -f 'startxfce4|xfce4-session|xfwm4|xfdesktop|xfce4-panel|xfsettingsd|xfconfd' 2>/dev/null || true
pkill -f virgl_test_server 2>/dev/null || true
pkill -f dbus-daemon 2>/dev/null || true
proot-distro kill "$CONTAINER" 2>/dev/null || true

# ── gui: delete everything GUI in one pass ──────────────────────────────────
if [ "$LEVEL" = gui ]; then
  if [ -d "$ROOTFS" ]; then
    log "[1/3] Container: removing desktop, Firefox, GL/Vulkan stack..."
    run_in_container <<'EOS' || true
set -e
export DEBIAN_FRONTEND=noninteractive
# drop the Firefox PPA (source + pin) first so nothing reinstalls the stub
rm -f /etc/apt/sources.list.d/mozillateam-*.list /etc/apt/preferences.d/mozilla-firefox
apt-get update -y
apt-get purge -y -q \
  'xfce4*' 'xfdesktop4' 'xfce4-goodies' 'xfce4-terminal' \
  mousepad ristretto gvfs thunar-archive-plugin xterm \
  desktop-base adwaita-icon-theme tango-icon-theme \
  dbus-x11 dbus-user-session network-manager-gnome \
  mesa-utils mesa-vulkan-drivers vulkan-tools glmark2 \
  firefox firefox-esr >/dev/null 2>&1 || true
apt-get autoremove -y -q
rm -rf /home/*/.config/xfce4 /root/.config/xfce4 \
       /home/*/.cache/xdg-runtime /root/.cache/xdg-runtime \
       /opt/xd-session.sh /opt/xd-session.log
echo "container GUI packages removed"
EOS
  fi

  log "[2/3] Termux: removing X11/GPU packages and the native-desktop remnants..."
  pkg uninstall -y \
    termux-x11-nightly virglrenderer-android x11-repo \
    xfce4 xfdesktop xfce4-terminal \
    xfce4-whiskermenu-plugin xfce4-screenshooter \
    mousepad ristretto thunar-archive-plugin gvfs \
    dbus-glib mesa-demos xorg-xdpyinfo \
    ttf-dejavu adwaita-icon-theme hicolor-icon-theme falkon 2>/dev/null || true
  pkg autoremove -y 2>/dev/null || true

  log "[3/3] Termux: removing profiles, session artifacts, logs..."
  [ -d "$HOME/.config/xfce4" ] && \
    mv "$HOME/.config/xfce4" "$HOME/.config/xfce4.bak.$(date +%Y%m%d%H%M%S)"
  rm -rf "$PREFIX/tmp/xd-shm" "$PREFIX/tmp"/xdg-runtime-* \
         "$HOME/.cache/xfce-session.log" "$HOME/.cache/termux-x11.log" \
         "$HOME/.cache/virgl.log"

  cat <<'EOF'

GUI fully removed. Kept intact:
  - the Ubuntu container (CLI-ready: proot-distro login ubuntu)
  - proot-distro, git, Termux itself

Manual step (apps can't be uninstalled from the CLI):
  Settings -> Apps -> Termux:X11 -> Uninstall   (the APK you installed)

Bring the desktop back anytime: bash scripts/install-desktop.sh
EOF
  exit 0
fi

# ── termux-desktop: the superseded Termux-native XFCE ───────────────────────
if [ "$LEVEL" = termux-desktop ]; then
  log "Resetting the Termux-side XFCE profile (backup kept)..."
  [ -d "$HOME/.config/xfce4" ] && \
    mv "$HOME/.config/xfce4" "$HOME/.config/xfce4.bak.$(date +%Y%m%d%H%M%S)"
  log "Removing Termux-native desktop packages (x11-repo names)..."
  pkg uninstall -y xfce4 xfdesktop xfce4-terminal \
    xfce4-whiskermenu-plugin xfce4-screenshooter \
    mousepad ristretto thunar-archive-plugin gvfs \
    dbus-glib mesa-demos xorg-xdpyinfo \
    ttf-dejavu adwaita-icon-theme hicolor-icon-theme falkon 2>/dev/null || true
  pkg autoremove -y 2>/dev/null || true
  log "Termux-native desktop removed. proot-distro + termux-x11-nightly kept."
  log "Re-add with: pkg install x11-repo && pkg install xfce4 xfdesktop ... (or ignore — harmless)"
  exit 0
fi

# ── config: fresh XFCE profile inside the container ─────────────────────────
if [ "$LEVEL" = config ]; then
  [ -d "$ROOTFS" ] || die "Container not found."
  log "Backing up and resetting XFCE config inside the container..."
  run_in_container <<'EOS'
set -e
for h in /home/* /root; do
  [ -d "$h/.config/xfce4" ] || continue
  mv "$h/.config/xfce4" "$h/.config/xfce4.bak.$(date +%Y%m%d%H%M%S)"
done
EOS
  log "Profile reset. Start the desktop again: bash scripts/desktop.sh"
  exit 0
fi

# ── desktop: remove desktop packages from the container ─────────────────────
if [ "$LEVEL" = desktop ] || [ "$LEVEL" = container ] || [ "$LEVEL" = all ]; then
  if [ -d "$ROOTFS" ]; then
    log "Resetting XFCE config inside the container (backup kept)..."
    run_in_container <<'EOS' || true
set -e
for h in /home/* /root; do
  [ -d "$h/.config/xfce4" ] || continue
  mv "$h/.config/xfce4" "$h/.config/xfce4.bak.$(date +%Y%m%d%H%M%S)"
done
EOS
    log "Removing desktop packages from the container..."
    run_in_container <<'EOS' || true
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get purge -y -q \
  'xfce4*' 'xfdesktop4' 'xfce4-goodies' \
  mousepad ristretto thunar-archive-plugin xterm \
  desktop-base tango-icon-theme adwaita-icon-theme \
  glmark2 vulkan-tools mesa-vulkan-drivers >/dev/null 2>&1 || true
apt-get autoremove -y -q
EOS
  fi
fi

# ── container: delete the whole container ───────────────────────────────────
if [ "$LEVEL" = container ] || [ "$LEVEL" = all ]; then
  log "DELETING the whole '$CONTAINER' container (no undo)..."
  proot-distro remove "$CONTAINER"
  log "Container removed. Re-run scripts/setup-ubuntu.sh to rebuild."
fi

# ── all: also remove Termux-side X11/GPU packages ───────────────────────────
if [ "$LEVEL" = all ]; then
  log "Removing Termux-side X11/GPU packages..."
  pkg uninstall -y termux-x11-nightly virglrenderer-android 2>/dev/null || true
  log "Kept: Termux itself, proot-distro, git. Re-run scripts/install-x11.sh to restore."
fi

log "Done (level: $LEVEL)."
