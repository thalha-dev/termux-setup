#!/data/data/com.termux/files/usr/bin/bash
# cleanup.sh — undo desktop pieces, in increasing levels of destruction.
#
#   bash scripts/cleanup.sh config      # fresh XFCE profile (keeps all packages)
#   bash scripts/cleanup.sh desktop     # + remove the desktop packages
#   bash scripts/cleanup.sh container   # + DELETE the whole Ubuntu container
#   bash scripts/cleanup.sh all         # container + Termux-side X11 packages
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
  config|desktop|container|all) ;;
  *) sed -n '2,7p' "$0"; exit 1 ;;
esac

log "Stopping sessions..."
pkill termux-x11 2>/dev/null || true
proot-distro kill "$CONTAINER" 2>/dev/null || true

if [ "$LEVEL" = config ] || [ "$LEVEL" = desktop ] || [ "$LEVEL" = container ] || [ "$LEVEL" = all ]; then
  if [ -d "$ROOTFS" ] && [ "$LEVEL" != config ]; then
    log "Resetting XFCE config inside the container..."
    run_in_container <<'EOS'
set -e
for h in /home/* /root; do
  [ -d "$h/.config/xfce4" ] || continue
  mv "$h/.config/xfce4" "$h/.config/xfce4.bak.$(date +%Y%m%d%H%M%S)"
done
EOS
  fi
  if [ "$LEVEL" = config ]; then
    log "Resetting the Termux-side XFCE profile..."
    [ -d "$HOME/.config/xfce4" ] && \
      mv "$HOME/.config/xfce4" "$HOME/.config/xfce4.bak.$(date +%Y%m%d%H%M%S)"
    log "Termux XFCE profile reset. Start the desktop again: bash scripts/desktop.sh"
    exit 0
  fi
fi

if [ "$LEVEL" = desktop ] || [ "$LEVEL" = container ] || [ "$LEVEL" = all ]; then
  if [ -d "$ROOTFS" ]; then
    log "Removing desktop packages from the container..."
    run_in_container <<'EOS'
set -e
export DEBIAN_FRONTEND=noninteractive
apt-get purge -y -q \
  'xfce4*' 'xfdesktop4' 'xfce4-whiskermenu-plugin' 'xfce4-screenshooter' \
  mousepad ristretto thunar-archive-plugin xterm \
  desktop-base tango-icon-theme adwaita-icon-theme >/dev/null 2>&1 || true
apt-get autoremove -y -q
EOS
  fi
fi

if [ "$LEVEL" = container ] || [ "$LEVEL" = all ]; then
  log "DELETING the whole '$CONTAINER' container (no undo)..."
  proot-distro remove "$CONTAINER"
  log "Container removed. Re-run scripts/setup-ubuntu.sh to rebuild."
fi

if [ "$LEVEL" = all ]; then
  log "Removing Termux-side X11 packages..."
  pkg uninstall -y termux-x11-nightly || true
  log "Kept: Termux itself, proot-distro, git. Re-run scripts/install-x11.sh to restore."
fi

log "Done (level: $LEVEL)."
