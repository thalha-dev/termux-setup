#!/data/data/com.termux/files/usr/bin/bash
# backup.sh — archive a container to ~/storage/downloads (timestamped).
# Usage: bash scripts/backup.sh [container]
set -Eeuo pipefail

CONTAINER="${1:-${PD_CONTAINER_NAME:-ubuntu}}"
[ -n "${TERMUX_VERSION:-}" ] || { echo "Run inside Termux." >&2; exit 1; }

OUT_DIR="$HOME/storage/downloads"
[ -d "$OUT_DIR" ] || { echo "$OUT_DIR missing — run 'termux-setup-storage' first." >&2; exit 1; }

OUT="$OUT_DIR/termux-${CONTAINER}-$(date +%Y%m%d-%H%M%S).tar.gz"
echo "Backing up '$CONTAINER' -> $OUT"
echo "(first backup of a multi-GB container is slow; gzip is the safe choice here)"
proot-distro backup "$CONTAINER" --output "$OUT"
echo "Done: $OUT"
echo "Restore later with: bash scripts/restore.sh \"$OUT\""
