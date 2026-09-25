#!/data/data/com.termux/files/usr/bin/bash
# container-app.sh — run a GUI app from the Ubuntu container on the
# Termux-native XFCE desktop (the X socket is shared via --shared-x11).
#
# Usage:
#   bash scripts/container-app.sh                  # interactive prompt
#   bash scripts/container-app.sh firefox          # named app (menu-launched apps)
#   bash scripts/container-app.sh /usr/bin/xclock  # full path to any binary
set -Eeuo pipefail

CONTAINER="${PD_CONTAINER_NAME:-ubuntu}"
UBU_USER="${PD_UBUNTU_USER:-thalha}"
DISPLAY_NUM="${PD_DISPLAY:-:1}"
ROOTFS="$PREFIX/var/lib/proot-distro/containers/$CONTAINER/rootfs"

log() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

[ -n "${TERMUX_VERSION:-}" ] || die "Run this inside Termux."
[ -d "$ROOTFS" ] || die "Container '$CONTAINER' not found — run scripts/setup-ubuntu.sh first."
pgrep -x xfce4-panel >/dev/null 2>&1 || \
  die "No Termux desktop running — start it first: bash scripts/desktop.sh"
pgrep -x termux-x11 >/dev/null 2>&1 || \
  die "termux-x11 server not running — start the desktop first: bash scripts/desktop.sh"

APP="${1:-}"
if [ -z "$APP" ]; then
  printf 'App to run from the container (e.g. firefox, xclock, gimp): '
  read -r APP
fi
[ -n "$APP" ] || die "no app given."

if ! grep -q "^${UBU_USER}:" "$ROOTFS/etc/passwd" 2>/dev/null; then
  UBU_USER="root"
fi

# Firefox's tab IPC needs a writable /dev/shm (Android has none to inherit)
mkdir -p "$PREFIX/tmp/xd-shm"; chmod 777 "$PREFIX/tmp/xd-shm"

log "Launching '${APP}' from container '${CONTAINER}' as ${UBU_USER} on ${DISPLAY_NUM}..."
# GPU: use the VirGL proxy when its server is up, else software rendering
if pgrep -f virgl_test_server >/dev/null 2>&1; then
  GPU_ENV="GALLIUM_DRIVER=virpipe MESA_GL_VERSION_OVERRIDE=4.3COMPAT MESA_GLES_VERSION_OVERRIDE=3.2"
else
  GPU_ENV="LIBGL_ALWAYS_SOFTWARE=1"
fi
# shellcheck disable=SC2086
exec proot-distro login "$CONTAINER" --user "$UBU_USER" \
  --bind "$PREFIX/tmp/xd-shm:/dev/shm" \
  --shared-tmp --shared-x11 -- \
  /bin/bash -lc "export DISPLAY='${DISPLAY_NUM}'; export ${GPU_ENV}; \
export MOZ_DISABLE_CONTENT_SANDBOX=1 MOZ_DISABLE_RDD_SANDBOX=1 MOZ_DISABLE_GPU_SANDBOX=1; exec '${APP}'"
