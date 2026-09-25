#!/usr/bin/env bash
# phone-fs — browse the PHONE's storage from the Mac as if it were local.
# Uses the 'termux' ssh shortcut (mac/ssh-termux.sh) — no IPs, works on any network.
#
#   phone-fs web      # browser file manager at http://localhost:8086 (yazi-like)
#   phone-fs finder   # mount in macOS Finder (Cmd+K -> http://localhost:8087)
#                     #   ... then use yazi/Finder/anything on /Volumes/phone
#   phone-fs stop     # stop servers and unmount
#   phone-fs shell    # plain ssh into the phone
#
# Requirements: ssh termux works. First run auto-installs rclone inside the
# phone's Ubuntu container (one time, ~10 MB).
set -Eeuo pipefail

WEB_PORT="${PHONE_FS_WEB_PORT:-8086}"
DAV_PORT="${PHONE_FS_DAV_PORT:-8087}"
MOUNT_DIR="/Volumes/phone"
WEB_URL="http://localhost:${WEB_PORT}"
DAV_URL="http://localhost:${DAV_PORT}"

green() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
die()   { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

need_ssh() { ssh -o BatchMode=yes -o ConnectTimeout=6 termux true 2>/dev/null \
  || die "phone unreachable — ssh termux fails.
Check: phone awake + same network; on the phone: bash scripts/setup-ssh.sh"; }

ensure_rclone() {
  ssh -o BatchMode=yes termux '
    command -v rclone >/dev/null 2>&1 && exit 0
    echo "installing rclone in the container (one-time)…"
    sudo apt-get update -qq && sudo apt-get install -y -qq rclone
  ' 2>&1 | grep -v '^\[sudo\]' || true
  ssh -o BatchMode=yes termux 'command -v rclone >/dev/null' \
    || die "rclone install failed inside the container. Run manually: ssh termux 'sudo apt install rclone'"
  green "rclone ready in the container."
}

start_tunnel() {  # $1 = container-side port
  ssh -o ExitOnForwardFailure=yes -f -N -L "$1:127.0.0.1:$1" termux
}

serve() {  # $1 = http|webdav, $2 = port
  local mode="$1" port="$2" url="http://localhost:${2}"
  start_tunnel "$port"
  # remote server, detached; dies with the tunnel's remote side on stop
  ssh -o BatchMode=yes termux -- \
    "pkill -f 'rclone serve .*--addr 127.0.0.1:${port}' 2>/dev/null; \
     nohup rclone serve ${mode} /sdcard --addr 127.0.0.1:${port} \
       >/tmp/rclone-${mode}.log 2>&1 & sleep 1"
  green "serving /sdcard via ${mode} -> ${url}"
}

do_web() {
  need_ssh; ensure_rclone
  serve http "$WEB_PORT"
  green "opening ${WEB_URL} — 'phone-fs stop' to end"
  sleep 1; open "$WEB_URL"
}

do_finder() {
  need_ssh; ensure_rclone
  serve webdav "$DAV_PORT"
  mkdir -p "$MOUNT_DIR"
  if mount | grep -q " on $MOUNT_DIR "; then
    green "$MOUNT_DIR already mounted"
  else
    green "mounting ${DAV_URL} at ${MOUNT_DIR}…"
    osascript -e "tell application \"Finder\" to mount volume \"${DAV_URL}\"" \
      || die "Finder mount refused — mount manually: Cmd+K in Finder -> ${DAV_URL}
(user/password: leave empty or anything; it's your own localhost tunnel)"
  fi
  green "phone storage is at ${MOUNT_DIR} — yazi, Finder, anything works.
Unmount/stop later with: phone-fs stop"
}

do_stop() {
  local p local_pid
  ssh_kill() {  # bounded remote pkill — never hangs the stop path
    ssh -o BatchMode=yes -o ConnectTimeout=4 termux "pkill -f '$1'" 2>/dev/null &
    local sp=$! sw
    { sleep 6; kill "$sp" 2>/dev/null; } & sw=$!
    wait "$sp" 2>/dev/null || true
    kill "$sw" 2>/dev/null || true
  }
  for p in "$WEB_PORT" "$DAV_PORT"; do
    local_pid="$(lsof -ti tcp:"$p" 2>/dev/null || true)"
    [ -n "$local_pid" ] && { echo "$local_pid" | xargs kill 2>/dev/null || true; }
    ssh_kill 'rclone serve .*--addr 127.0.0.1:'"$p"
  done
  if mount | grep -q " on $MOUNT_DIR "; then
    diskutil unmount "$MOUNT_DIR" >/dev/null 2>&1 || umount "$MOUNT_DIR" 2>/dev/null || true
  fi
  green "stopped."
}

case "${1:-web}" in
  web)    do_web ;;
  finder|dav|mount) do_finder ;;
  stop)   do_stop ;;
  shell)  exec ssh termux ;;
  *) sed -n '2,12p' "$0"; exit 1 ;;
esac
