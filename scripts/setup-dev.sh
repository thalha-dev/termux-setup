#!/data/data/com.termux/files/usr/bin/bash
# setup-dev.sh — development toolchains + Neovim (repo-shipped config) inside
# the Ubuntu container.
#
# Installs: build-essential, clang/clangd, golang + gopls, node/npm +
# typescript-language-server, python3/venv/pip, ripgrep/fd/bat/jq/tree/htop,
# tmux, and Neovim v0.12.5 (GitHub arm64 tarball — Ubuntu's apt nvim 0.9.5 is
# too old for the treesitter 'main' branch used by nvim/init.lua).
#
# No private info handled here: git identity is asked interactively and only
# written to the container's ~/.gitconfig.
set -Eeuo pipefail

CONTAINER="${PD_CONTAINER_NAME:-ubuntu}"
UBU_USER="${PD_UBUNTU_USER:-thalha}"
NVIM_VERSION="${PD_NVIM_VERSION:-v0.12.5}"
ROOTFS="$PREFIX/var/lib/proot-distro/containers/$CONTAINER/rootfs"
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

log()  { printf '\033[1;32m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mWARN:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

[ -n "${TERMUX_VERSION:-}" ] || die "Run this inside Termux."
[ -d "$ROOTFS" ] || die "Container '$CONTAINER' not found — run scripts/setup-ubuntu.sh first."
[ -d "$REPO_DIR/nvim" ] || die "nvim/ config not found next to scripts/ — run from a full clone."

log "Installing toolchains + CLI tools in the container (apt)..."
proot-distro login "$CONTAINER" -- /bin/bash -s <<'EOS'
set -Eeuo pipefail
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y --no-install-recommends \
  build-essential clang clangd lld \
  golang-go \
  nodejs npm \
  python3 python3-pip python3-venv \
  ripgrep fd-find bat jq tree htop tmux \
  bash-completion man-db unzip zip ca-certificates
EOS

log "Installing gopls (Go language server)..."
# single quotes are intentional: the script must expand INSIDE the container
# shellcheck disable=SC2016
proot-distro login "$CONTAINER" --user "$UBU_USER" -- /bin/bash -lc '
  export PATH="$HOME/go/bin:$PATH"
  command -v gopls >/dev/null 2>&1 && { echo "gopls already present"; exit 0; }
  go install golang.org/x/tools/gopls@latest
  sudo ln -sf "$HOME/go/bin/gopls" /usr/local/bin/gopls
' || warn "gopls install failed — LSP for Go will be unavailable."

log "Installing TypeScript language server + bash language server (npm)..."
proot-distro login "$CONTAINER" -- /bin/bash -s <<'EOS' || warn "npm servers failed"
set -e
npm install -g typescript typescript-language-server bash-language-server
npm cache clean --force
EOS

log "Installing Neovim ${NVIM_VERSION} (official arm64 build)..."
proot-distro login "$CONTAINER" -- /bin/bash -s <<EOS
set -Eeuo pipefail
cd /tmp
curl -fsSLO "https://github.com/neovim/neovim/releases/download/${NVIM_VERSION}/nvim-linux-arm64.tar.gz"
rm -rf /opt/nvim-linux-arm64
tar -xzf nvim-linux-arm64.tar.gz -C /opt
ln -sf /opt/nvim-linux-arm64/bin/nvim /usr/local/bin/nvim
rm -f nvim-linux-arm64.tar.gz
EOS

log "Installing the repo-shipped nvim config for '${UBU_USER}'..."
proot-distro login "$CONTAINER" --user root -- /bin/bash -s <<EOS
set -e
H="/home/${UBU_USER}"
if [ -d "\$H/.config/nvim" ] && [ ! -d "\$H/.config/nvim/.git" ]; then
  mv "\$H/.config/nvim" "\$H/.config/nvim.bak.\$(date +%Y%m%d%H%M%S)"
fi
mkdir -p "\$H/.config/nvim"
grep -q 'go/bin' "\$H/.bashrc" 2>/dev/null || \\
  echo 'export PATH="\$HOME/go/bin:\$PATH"' >> "\$H/.bashrc"
chown -R "${UBU_USER}:${UBU_USER}" "\$H/.config" "\$H/.bashrc"
EOS
# copy host-side (proot-distro copy walks directories, dotfiles included);
# fallback: bind the repo into the container and cp there
if ! proot-distro copy --recursive "$REPO_DIR/nvim/." "$CONTAINER:/home/$UBU_USER/.config/nvim/"; then
  log "copy failed — falling back to a bind-mounted copy..."
  proot-distro login "$CONTAINER" --user root --bind "$REPO_DIR:/mnt/termux-setup-repo" -- \
    /bin/bash -c "cp -r /mnt/termux-setup-repo/nvim/. /home/$UBU_USER/.config/nvim/ &&
                  chown -R ${UBU_USER}: /home/$UBU_USER/.config/nvim"
fi

log "Bootstrapping plugins headlessly (first run downloads ~100 MB)..."
# shellcheck disable=SC2016  # expands inside the container, not on Termux
proot-distro login "$CONTAINER" --user "$UBU_USER" -- /bin/bash -lc '
  export PATH="/usr/local/bin:$PATH"
  nvim --headless "+Lazy! sync" +TSUpdate +qa 2>&1 | tail -5 || true
'

log "Git identity (stored only in the container's ~/.gitconfig)..."
read -r -p "  git user.name  [skip if empty]: " GIT_NAME || true
read -r -p "  git user.email [skip if empty]: " GIT_EMAIL || true
if [ -n "${GIT_NAME:-}" ] || [ -n "${GIT_EMAIL:-}" ]; then
  # shellcheck disable=SC2016  # expands inside the container, not on Termux
  proot-distro login "$CONTAINER" --user "$UBU_USER" -- /bin/bash -c '
    [ -n "$1" ] && git config --global user.name "$1"
    [ -n "$2" ] && git config --global user.email "$2"
  ' sh "${GIT_NAME:-}" "${GIT_EMAIL:-}"
fi

log "Verification:"
# shellcheck disable=SC2016  # expands inside the container, not on Termux
proot-distro login "$CONTAINER" -- /bin/bash -lc '
  echo "  nvim:    $(nvim --version | head -1)"
  echo "  clangd:  $(clangd --version | head -1)"
  echo "  go:      $(go version | cut -d" " -f3)"
  echo "  gopls:   $(gopls version 2>/dev/null | head -1 || echo MISSING)"
  echo "  node:    $(node --version)"
  echo "  ts-lsp:  $(typescript-language-server --version 2>/dev/null | head -1)"
  echo "  tmux:    $(tmux -V)"
'

cat <<'EOF'

Dev environment ready. Inside the container (proot-distro login ubuntu):
  nvim          # LSP (gd/K/gr), Telescope (Space+f), completions, catppuccin
  tmux          # long sessions: 'tmux new -s dev', detach Ctrl-b d, reattach 'tmux a -t dev'
Tool notes:
  - LSP servers: clangd, gopls, ts_ls, bashls, pyright — auto-detected by filetype
  - fd is 'fdfind', bat is 'batcat' on Ubuntu (alias them if you like)
EOF
