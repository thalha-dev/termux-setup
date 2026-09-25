#!/usr/bin/env bash
# ssh-termux.sh — Mac-side helper: turn "ssh -p 8023 thalha@192.168.x.x" into
# just "ssh termux". Runs on macOS. Contains no secrets — it only writes a
# normal ~/.ssh/config block pointing at your key.
#
#   bash ssh-termux.sh --setup 192.168.1.42   # once (or whenever the IP changes)
#   bash ssh-termux.sh                        # connect
#   bash ssh-termux.sh --shell                # same, explicit
#   bash ssh-termux.sh --status               # show the saved config block
set -Eeuo pipefail

HOST_ALIAS="termux"
SSH_PORT="8023"
SSH_USER="thalha"
SSH_KEY="$HOME/.ssh/id_ed25519"

c_green() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
c_err()   { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

write_config() {
  local ip="$1"
  [ -d "$HOME/.ssh" ] || mkdir -m 700 "$HOME/.ssh"
  touch "$HOME/.ssh/config"; chmod 600 "$HOME/.ssh/config"
  # drop any previous block, then append fresh
  awk -v begin="# BEGIN termux-setup" -v end="# END termux-setup" '
    $0 ~ begin {skip=1; next} $0 ~ end {skip=0; next} !skip' \
    "$HOME/.ssh/config" > "$HOME/.ssh/config.tmp"
  cat >> "$HOME/.ssh/config.tmp" <<EOF
# BEGIN termux-setup
Host ${HOST_ALIAS}
    HostName ${ip}
    Port ${SSH_PORT}
    User ${SSH_USER}
    IdentityFile ${SSH_KEY}
    IdentitiesOnly yes
    ServerAliveInterval 30
    ServerAliveCountMax 4
# END termux-setup
EOF
  mv "$HOME/.ssh/config.tmp" "$HOME/.ssh/config"
  c_green "Saved '${HOST_ALIAS}' -> ${SSH_USER}@${ip}:${SSH_PORT} (key: ${SSH_KEY})"
}

[ -f "$SSH_KEY" ] || {
  c_err "$SSH_KEY not found. Create a key first:
  ssh-keygen -t ed25519
Then run: bash scripts/setup-ssh.sh on the phone and paste ${SSH_KEY}.pub"
}

case "${1:-}" in
  --setup)
    [ -n "${2:-}" ] || c_err "usage: $0 --setup <phone-ip>   (IP shows in Settings > Wi-Fi, or on the phone: getprop dhcp.wlan0.ipaddress)"
    write_config "$2"
    ;;
  --status)
    awk '/# BEGIN termux-setup/,/# END termux-setup/' "$HOME/.ssh/config" 2>/dev/null \
      || echo "no 'termux' block yet — run: $0 --setup <phone-ip>"
    ;;
  --shell|""|termux)
    grep -q "Host ${HOST_ALIAS}" "$HOME/.ssh/config" 2>/dev/null || \
      c_err "no 'termux' shortcut yet — run: $0 --setup <phone-ip>"
    exec ssh "$HOST_ALIAS"
    ;;
  *)
    c_err "usage: $0 [--setup <ip> | --status | --shell]"
    ;;
esac
