#!/usr/bin/env bash
# ssh-termux.sh — Mac-side helper for termux-setup.
#
# "ssh termux" works from ANY network without retyping IPs: the helper
# resolves the phone automatically —
#   1. last-known IP (instant if the network didn't change)
#   2. parallel scan of the Mac's current subnets for port 8023
#   3. verification: the candidate must accept YOUR ssh key (so a random
#      device with 8023 open is never confused for the phone)
# One verified phone → connect. Several → pick list. None → clear hints.
#
#   bash ssh-termux.sh                # connect (interactive pick if needed)
#   bash ssh-termux.sh --setup        # one-time: install config + autodiscovery
#   bash ssh-termux.sh --setup <ip>   # one-time, skip discovery (offline edge case)
#   bash ssh-termux.sh --pick         # discovery + explicit pick, saves the choice
#   bash ssh-termux.sh --status       # show the saved ssh-config block
set -Eeuo pipefail

ALIAS="termux"
HOSTKEY_ALIAS="termux-phone"
PORT="8023"
SSH_USER="thalha"
KEY="$HOME/.ssh/id_ed25519"
STATE_DIR="$HOME/.config/termux-setup"
INSTALLED_HELPER="$STATE_DIR/ssh-termux.sh"
LAST_IP_FILE="$STATE_DIR/last-phone-ip"

green() { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
err()   { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

[ -f "$KEY" ] || err "$KEY not found. Create it first:  ssh-keygen -t ed25519
Then run scripts/setup-ssh.sh on the phone and paste ${KEY}.pub"

port_open()  { nc -z -G 1 "$1" "$PORT" >/dev/null 2>&1; }

# our phone = sshd that accepts THIS Mac's key (BatchMode: no prompts)
key_auth_ok() {
  ssh -p "$PORT" -i "$KEY" -o IdentitiesOnly=yes -o BatchMode=yes \
      -o ConnectTimeout=3 -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      "${SSH_USER}@${1}" true 2>/dev/null
}

save_ip() { mkdir -p "$STATE_DIR"; echo "$1" > "$LAST_IP_FILE"; }

# every /24 the Mac is on right now (Wi-Fi, hotspot, ethernet…)
subnet_ips() {
  local bases ip
  bases="$(
    for ifn in $(ifconfig -l); do
      ip="$(ipconfig getifaddr "$ifn" 2>/dev/null || true)"
      [ -n "$ip" ] && printf '%s\n' "${ip%.*}"
    done | sort -u)"
  [ -n "$bases" ] || return 0
  for b in $bases; do seq 1 254 | sed "s/^/$b./"; done
}

scan_open_ports() {
  subnet_ips | xargs -P 32 -n1 -I@ \
    sh -c "nc -z -G 1 '@' $PORT >/dev/null 2>&1 && echo '@'" 2>/dev/null || true
}

verified_phones() {
  local ip found=""
  for ip in $(scan_open_ports); do
    printf '%s\033[2m (checking key…)\033[0m\r' "$ip" >&2
    if key_auth_ok "$ip"; then found="$found $ip"; fi
  done
  printf '\033[K' >&2
  echo "$found" | xargs
}

find_phone() {
  # 1. last known IP — instant path
  if [ -f "$LAST_IP_FILE" ] && port_open "$(cat "$LAST_IP_FILE")"; then
    cat "$LAST_IP_FILE"; return 0
  fi
  # 2. discovery
  green "Looking for the phone on this network (scans port $PORT, verifies your key)…"
  local hits
  hits="$(verified_phones)"
  local n; n="$(echo "$hits" | wc -w | tr -d ' ')"
  if [ "$n" = "1" ]; then save_ip "$hits"; echo "$hits"; return 0; fi
  if [ "$n" -gt 1 ]; then
    err "multiple key-authenticated phones found:$hits
Run:  $0 --pick   (choose one; it becomes the saved default)"
  fi
  return 1
}

pick_phone() {
  local hits
  hits="$(verified_phones)"
  [ -n "$hits" ] || return 1
  if command -v fzf >/dev/null 2>&1; then
    echo "$hits" | fzf --prompt="termux phone> " | head -1
  else
    echo "$hits" | nl -w2 -s'  '
    printf 'number: '
    read -r choice
    echo "$hits" | sed -n "${choice}p"
  fi
}

write_ssh_config() {
  [ -d "$HOME/.ssh" ] || mkdir -m 700 "$HOME/.ssh"
  touch "$HOME/.ssh/config"; chmod 600 "$HOME/.ssh/config"
  awk -v b="# BEGIN termux-setup" -v e="# END termux-setup" '
    $0 ~ b {skip=1; next} $0 ~ e {skip=0; next} !skip' \
    "$HOME/.ssh/config" > "$HOME/.ssh/config.tmp"
  cat >> "$HOME/.ssh/config.tmp" <<EOF
# BEGIN termux-setup
Host $ALIAS
    User $SSH_USER
    Port $PORT
    IdentityFile $KEY
    IdentitiesOnly yes
    HostKeyAlias $HOSTKEY_ALIAS
    StrictHostKeyChecking accept-new
    ProxyCommand $INSTALLED_HELPER --resolve
    ServerAliveInterval 30
    ServerAliveCountMax 4
# END termux-setup
EOF
  mv "$HOME/.ssh/config.tmp" "$HOME/.ssh/config"
}

do_setup() {
  mkdir -p "$STATE_DIR"
  cp "$0" "$INSTALLED_HELPER"; chmod +x "$INSTALLED_HELPER"
  if [ -n "${1:-}" ]; then
    save_ip "$1"
    green "Saved $1 as the phone's address."
  else
    if ip="$(find_phone)"; then
      green "Found the phone at $ip (saved)."
    else
      printf '\033[1;33mWARN:\033[0m phone not found right now — ' >&2
      echo "config installed anyway; discovery will run on every connect." >&2
      echo "(Is the phone on the same Wi-Fi? Did scripts/setup-ssh.sh run on it?)" >&2
    fi
  fi
  write_ssh_config
  green "Installed. From now on, on ANY network:  ssh $ALIAS"
  green "Testing…"
  if ssh -o BatchMode=yes -o ConnectTimeout=8 "$ALIAS" true 2>/dev/null; then
    green "works — you're set."
  else
    printf '\033[1;33mWARN:\033[0m test connect failed — ' >&2
    echo "check the phone (same Wi-Fi? sshd running: bash scripts/setup-ssh.sh)." >&2
  fi
}

case "${1:-}" in
  --setup) do_setup "${2:-}" ;;
  --pick)
    ip="$(pick_phone)" || err "no phone found (same Wi-Fi? sshd up on the phone?)"
    [ -n "$ip" ] || err "no selection made."
    save_ip "$ip"; green "saved $ip"; exec ssh "$ALIAS"
    ;;
  --status)
    awk "/# BEGIN termux-setup/,/# END termux-setup/" "$HOME/.ssh/config" 2>/dev/null \
      || echo "no '$ALIAS' block yet — run: $0 --setup"
    [ -f "$LAST_IP_FILE" ] && echo "last known phone IP: $(cat "$LAST_IP_FILE")"
    ;;
  --resolve)                     # used internally as the ssh ProxyCommand
    if ip="$(find_phone)"; then exec nc "$ip" "$PORT"; fi
    err "phone not found on this network.
Fix:  $0 --pick   (once, on this network)
Check: phone on same Wi-Fi?  sshd running? (scripts/setup-ssh.sh)"
    ;;
  --shell|"")
    grep -q "Host $ALIAS" "$HOME/.ssh/config" 2>/dev/null \
      || err "no '$ALIAS' shortcut yet — run: $0 --setup"
    exec ssh "$ALIAS"
    ;;
  *) err "usage: $0 [--setup [ip] | --pick | --status | --shell]" ;;
esac
