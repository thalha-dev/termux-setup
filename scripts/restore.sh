#!/data/data/com.termux/files/usr/bin/bash
# restore.sh — restore a container from a backup made by backup.sh.
# WARNING: overwrites the existing container of the same name.
# Usage: bash scripts/restore.sh <archive.tar.gz>
set -Eeuo pipefail

ARCHIVE="${1:-}"
[ -n "$ARCHIVE" ] && [ -f "$ARCHIVE" ] || {
  echo "Usage: bash scripts/restore.sh <archive.tar.gz>" >&2
  exit 1
}
[ -n "${TERMUX_VERSION:-}" ] || { echo "Run inside Termux." >&2; exit 1; }

NAME="$(basename "$ARCHIVE" .tar.gz)"
NAME="${NAME#termux-}"
NAME="${NAME%%-*}"   # container name is the first token of the archive name

echo "About to RESTORE container '$NAME' from: $ARCHIVE"
echo "This OVERWRITES any existing container with that name. No undo."
printf 'Type the container name to confirm: '
read -r CONFIRM
[ "$CONFIRM" = "$NAME" ] || { echo "Aborted." >&2; exit 1; }

proot-distro restore "$ARCHIVE"
echo "Restored. Boot it with: proot-distro login $NAME"
