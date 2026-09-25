#!/data/data/com.termux/files/usr/bin/bash
# setup-ubuntu.sh — step 3: pull Ubuntu 24.04 as an OCI image with
# proot-distro 5.x and configure a minimal, usable CLI environment.
#
# Deliberately minimal CLI base (languages and heavier tooling come later):
#   sudo (passwordless), en_US.UTF-8 locale, tzdata, git, curl, wget,
#   nano, bash-completion, man, procps, iproute2, net-tools, less, unzip.
#
# Safe to re-run: skips every step that already succeeded.
set -Eeuo pipefail

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

CONTAINER="${PD_CONTAINER_NAME:-ubuntu}"
IMAGE="${PD_IMAGE:-ubuntu:24.04}"
UBU_USER="${PD_UBUNTU_USER:-thalha}"

[ -n "${TERMUX_VERSION:-}" ] || die "Run this inside Termux."
command -v proot-distro >/dev/null 2>&1 || die "proot-distro missing — run bootstrap.sh first."

PD_BASE="$PREFIX/var/lib/proot-distro"
ROOTFS="$PD_BASE/containers/$CONTAINER/rootfs"

# --- pull the image ---------------------------------------------------------
if [ -d "$ROOTFS" ]; then
  log "Container '$CONTAINER' already exists at $ROOTFS — skipping pull."
else
  log "Installing ${IMAGE} as container '${CONTAINER}' (downloads ~100-400 MB)..."
  proot-distro install --name "$CONTAINER" "$IMAGE"
  [ -d "$ROOTFS" ] || die "Install reported success but $ROOTFS is missing."
fi

# --- configure inside the container -----------------------------------------
# Configure the container with the username passed in via --env (the heredoc
# is quoted, so $UBU_USER must reach the container shell as a real variable).
log "Configuring Ubuntu (apt packages, locale, user '${UBU_USER}')..."
proot-distro login "$CONTAINER" --env "UBU_USER=$UBU_USER" -- /bin/bash -s <<'EOS'
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive

apt-get update -y
apt-get install -y --no-install-recommends \
  sudo locales tzdata \
  git curl wget nano less unzip \
  bash-completion man-db procps \
  iputils-ping iproute2 net-tools

# en_US.UTF-8 locale (Ubuntu minimal ships none)
sed -i 's/^# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen >/dev/null 2>&1
update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# user with passwordless sudo (proot has no real root passwords; the default
# login user is root — this user is for anything that insists on non-root)
if ! id -u "$UBU_USER" >/dev/null 2>&1; then
  useradd -m -s /bin/bash -G sudo "$UBU_USER"
fi
echo "$UBU_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/90-$UBU_USER"
chmod 0440 "/etc/sudoers.d/90-$UBU_USER"

echo "container-side configuration done."
EOS

log "Ubuntu is ready."
cat <<EOF

Boot it:
  proot-distro login ${CONTAINER}              # as root (default)
  proot-distro login ${CONTAINER} --user ${UBU_USER}   # as your user

Inside you have: apt, git, curl, wget, nano, sudo (passwordless), locales.
Note: no password was set on '${UBU_USER}' — use 'passwd ${UBU_USER}' inside
if you ever want one. Long work belongs in 'tmux' so disconnects don't kill it.
EOF
