#!/data/data/com.termux/files/usr/bin/bash
# setup-ssh.sh — SSH server inside the Ubuntu container so the MacBook can
# open a full Ubuntu shell on the phone.
#
# SECURITY MODEL (nothing private lives in the repo or this script):
#   - key-only authentication: password logins are hard-DISABLED
#   - your PUBLIC key is pasted into this prompt once and written to the
#     container's authorized_keys (a public key is safe to share)
#   - host keys are generated on-device inside the container (never here)
#   - sshd listens on 8023 (>=1024, no root needed; Termux's own sshd uses 8022)
#   - LAN-only by default; never port-forward 8023 raw — use Tailscale/cloudflared
#
# Idempotent: re-running updates the key list and config, then restarts sshd.
set -Eeuo pipefail

CONTAINER="${PD_CONTAINER_NAME:-ubuntu}"
UBU_USER="${PD_UBUNTU_USER:-thalha}"
PORT="${PD_SSH_PORT:-8023}"
ROOTFS="$PREFIX/var/lib/proot-distro/containers/$CONTAINER/rootfs"

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

[ -n "${TERMUX_VERSION:-}" ] || die "Run this inside Termux."
[ -d "$ROOTFS" ] || die "Container '$CONTAINER' not found — run scripts/setup-ubuntu.sh first."
grep -q "^${UBU_USER}:" "$ROOTFS/etc/passwd" 2>/dev/null || \
  die "User '$UBU_USER' missing — rerun scripts/setup-ubuntu.sh."

# ── 1. the Mac's PUBLIC key ─────────────────────────────────────────────────
PUBKEY="${1:-}"
if [ -z "$PUBKEY" ]; then
  cat <<'EOF'
Paste your Mac's PUBLIC key (one line, ends with user@host), then press Enter.
On the Mac, if you don't have one yet:
  ssh-keygen -t ed25519
  cat ~/.ssh/id_ed25519.pub     <- paste the output of THIS on the phone
(A .pub file is safe to share; never paste a PRIVATE key anywhere.)
EOF
  printf 'public key: '
  read -r PUBKEY
fi
case "$PUBKEY" in
  ssh-ed25519\ *|ssh-rsa\ *|ecdsa-sha2-*|sk-*) ;;   # looks like a public key
  *) die "That doesn't look like a public key (want: 'ssh-ed25519 AAAA... comment'). Aborting." ;;
esac

# ── 2. install openssh-server + harden config ──────────────────────────────
log "Installing openssh-server in the container..."
proot-distro login "$CONTAINER" -- /bin/bash -s <<EOS
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends openssh-server
mkdir -p /run/sshd

# hardening drop-in (Ubuntu's sshd_config already Includes sshd_config.d)
cat > /etc/ssh/sshd_config.d/99-termux-setup.conf <<CONF
Port ${PORT}
PubkeyAuthentication yes
PasswordAuthentication no
KbdInteractiveAuthentication no
X11Forwarding no
AllowUsers ${UBU_USER}
CONF

# authorized_keys for the user (correct ownership/permissions matter)
H="/home/${UBU_USER}"
mkdir -p "\$H/.ssh"
echo "${PUBKEY}" > "\$H/.ssh/authorized_keys"
chown -R "${UBU_USER}:${UBU_USER}" "\$H/.ssh"
chmod 700 "\$H/.ssh"; chmod 600 "\$H/.ssh/authorized_keys"

ssh-keygen -A   # generate host keys on-device
echo "sshd config validated:"
/usr/sbin/sshd -t && echo "  OK"
EOS

# ── 3. start sshd as a persistent detached session ──────────────────────────
log "Starting sshd (persistent detached session; survives this script)..."
proot-distro kill "$CONTAINER" 2>/dev/null || true   # stop stale sessions incl. old sshd
proot-distro login "$CONTAINER" --detach -- /usr/sbin/sshd -D -e

PHONE_IP="$(getprop dhcp.wlan0.ipaddress 2>/dev/null || true)"
[ -n "$PHONE_IP" ] || PHONE_IP="<phone-ip>"

cat <<EOF

sshd is UP on port ${PORT}, key-only, user '${UBU_USER}'.

One-time on the MAC (creates the 'termux' shortcut — see mac/ssh-termux.sh):
  curl -fsSL https://raw.githubusercontent.com/thalha-dev/termux-setup/main/mac/ssh-termux.sh -o ssh-termux.sh
  bash ssh-termux.sh --setup ${PHONE_IP}

Then, forever, from the Mac:
  ssh termux                 # full Ubuntu shell on the phone
  sftp termux                # file browser
  scp file.txt termux:~/     # push a file
  rsync -av ./proj/ termux:~/proj/   # sync a folder

Phone-side control:
  proot-distro kill ${CONTAINER}          # stop sshd
  bash scripts/setup-ssh.sh              # restart (idempotent)

SECURITY:
  - password logins are disabled; only your key opens this
  - reachable on your LAN only. For access from outside, use Tailscale
    (pkg install tailscale in Termux) — never raw port-forwarding.
  - revoke access anytime: edit /home/${UBU_USER}/.ssh/authorized_keys
EOF
