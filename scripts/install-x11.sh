#!/data/data/com.termux/files/usr/bin/bash
# install-x11.sh — step 2: Termux:X11 companion package (the app itself is
# already installed from GitHub; this installs the matching Termux-side CLI).
set -Eeuo pipefail

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

[ -n "${TERMUX_VERSION:-}" ] || die "Run this inside Termux."

log "Enabling the Termux X11 repository..."
pkg install -y x11-repo

log "Installing termux-x11-nightly (companion CLI, matches the GitHub nightly APK)..."
pkg install -y termux-x11-nightly

command -v termux-x11 >/dev/null 2>&1 || die "termux-x11 binary not found after install."
log "termux-x11 companion installed: $(command -v termux-x11)"

cat <<'EOF'

RECOMMENDED (one-time, on the phone):
  Swap the Termux:X11 APK for the sharedUid variant so Android does NOT
  throttle the desktop when Termux goes to the background:

    1. Open https://github.com/termux/termux-x11/releases/tag/nightly
    2. Uninstall the "Termux:X11" app you currently have
    3. Download and install termux-x11-universal-sharedUid-debug.apk
       (NOT the regular universal-debug one)

  This only works because your Termux is the GitHub-signed build.

  Also: Settings -> Apps -> Termux:X11 -> Notifications -> Allow
  (Android 13+ requires this or you get no Exit/Preferences notification).

Next step:
  bash scripts/setup-ubuntu.sh
EOF
