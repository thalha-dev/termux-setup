#!/data/data/com.termux/files/usr/bin/bash
# sanity.sh — environment report for this phone. Read-only, safe to re-run.
set -Eeuo pipefail

PD_BASE="$PREFIX/var/lib/proot-distro"

section() { printf '\n\033[1;36m── %s ──\033[0m\n' "$*"; }
best() { # best-effort: never aborts the report
  "$@" 2>/dev/null || echo "  (unavailable on this device)"
}

section "Device"
echo "  model:        $(getprop ro.product.model 2>/dev/null || echo '?')"
echo "  board/soc:    $(getprop ro.board.platform 2>/dev/null || echo '?') / $(uname -m)"
echo "  android:      $(getprop ro.build.version.release 2>/dev/null || echo '?')"
echo "  hyperos/miui: $(getprop ro.mi.os.version.name 2>/dev/null \
                     || getprop ro.miui.ui.version.name 2>/dev/null || echo '?')"
echo "  termux:       ${TERMUX_VERSION:-?}  prefix=$PREFIX"

section "Kill-switch state (phantom process killer)"
PPK="$(settings get global settings_enable_monitor_phantom_procs 2>/dev/null || echo unavailable)"
case "$PPK" in
  false|0) echo "  settings_enable_monitor_phantom_procs = $PPK  (killing DISABLED — good)" ;;
  *)       echo "  settings_enable_monitor_phantom_procs = $PPK  (null/true = killing may be ACTIVE)"
           echo "  -> Developer options: enable 'Disable child process restrictions'" ;;
esac
best dumpsys deviceidle whitelist | grep -i com.termux >/dev/null 2>&1 \
  && echo "  termux is battery-optimization whitelisted" \
  || echo "  termux NOT in doze whitelist -> Settings > Apps > Termux > Battery saver: No restrictions"

section "Termux packages"
for p in proot-distro proot; do
  dpkg -s "$p" >/dev/null 2>&1 \
    && echo "  [ok] $p" || echo "  [MISSING] $p"
done

section "Containers"
if [ -d "$PD_BASE/containers" ]; then
  found=0
  for d in "$PD_BASE/containers"/*/; do
    [ -d "$d/rootfs" ] || continue
    found=1
    name="$(basename "$d")"
    echo "  ${name}: $(du -sh "$d/rootfs" 2>/dev/null | cut -f1)"
  done
  [ "$found" = 0 ] && echo "  (none installed — run scripts/setup-ubuntu.sh)"
else
  echo "  (proot-distro runtime dir not found — run bootstrap.sh)"
fi

section "Disk"
df -h "$PREFIX" 2>/dev/null | awk 'NR==1 || NR==2 {printf "  %s\n", $0}'

section "Storage binding"
[ -d "$HOME/storage/downloads" ] \
  && echo "  $HOME/storage/downloads present (backups can be saved)" \
  || echo "  ~/storage/downloads MISSING -> run: termux-setup-storage"

echo
