#!/data/data/com.termux/files/usr/bin/bash
# bootstrap.sh — step 1: update Termux, install proot-distro, enable storage.
# Run INSIDE Termux:  bash bootstrap.sh
set -Eeuo pipefail

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# --- sanity -----------------------------------------------------------------
[ -n "${TERMUX_VERSION:-}" ] || die "Run this inside Termux, not a normal shell."
ARCH="$(uname -m)"
if [ "$ARCH" != "aarch64" ]; then
  warn "Expected aarch64 (Redmi Note 13 Pro 5G is aarch64); found ${ARCH}."
  warn "Scripts will still run, but they were written for this device."
fi

log "Updating Termux package index and upgrading installed packages..."
export DEBIAN_FRONTEND=noninteractive
yes | pkg update -y >/dev/null 2>&1 || pkg update -y
yes | pkg upgrade -y >/dev/null 2>&1 || pkg upgrade -y

log "Installing proot-distro (pulls in proot), git and ncurses-utils..."
pkg install -y proot-distro git ncurses-utils

log "Requesting storage access (creates ~/storage/downloads for backups)..."
# The Android permission dialog pops up on the phone — accept it.
termux-setup-storage >/dev/null 2>&1 || \
  warn "Storage prompt may have been dismissed. Run 'termux-setup-storage' manually."

PD_VERSION="$(proot-distro --help 2>/dev/null | head -n 1 || echo 'unknown')"
log "proot-distro is ready (${PD_VERSION})."

cat <<'EOF'

Next steps:
  bash scripts/install-x11.sh      # Termux:X11 companion package
  bash scripts/setup-ubuntu.sh     # pull Ubuntu 24.04 and configure it
  proot-distro login ubuntu        # boot into Ubuntu

If you haven't already, do the phone-settings checklist in README.md
(battery saver "No restrictions", Autostart, phantom-process toggle).
EOF
