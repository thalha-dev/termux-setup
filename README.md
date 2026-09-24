# termux-setup

One-shot setup scripts for a full **proot Ubuntu** environment on Termux —
built and tested against a **Redmi Note 13 Pro 5G** (Snapdragon 7s Gen 2,
`aarch64`, HyperOS / Android 15). No root required.

What you end up with:

- **Termux** (GitHub build, already installed) with `proot-distro` 5.x
- A real **Ubuntu 24.04** userland pulled as an OCI image (`apt`, `git`, `curl`,
  `sudo`, locales — languages and dev toolchains come later, on purpose)
- Optional **XFCE desktop** via **Termux:X11** (companion app already installed)
- Phone hardening so Android/HyperOS stops killing the session
- Backup/restore of the whole container to your Downloads folder

## Run order

Inside the Termux app:

```sh
pkg install -y git
git clone https://github.com/thalha-dev/termux-setup.git
cd termux-setup

bash bootstrap.sh                 # 1. update Termux + install proot-distro
bash scripts/install-x11.sh       # 2. x11-repo + termux-x11-nightly companion
bash scripts/setup-ubuntu.sh      # 3. pull ubuntu:24.04, create user, sudo, locale
proot-distro login ubuntu         # 4. you are in real Ubuntu. That's the boot.
```

Optional, when you want the GUI:

```sh
bash scripts/install-desktop.sh   # XFCE inside the container (~500 MB)
bash scripts/desktop.sh           # launch Termux:X11 + XFCE, opens the app
```

Utilities:

```sh
bash scripts/sanity.sh            # environment report: Android/HyperOS, killer state, disk
bash scripts/backup.sh            # container -> ~/storage/downloads/*.tar.gz
bash scripts/restore.sh <file>    # restore (overwrites the container)
```

## Phone settings checklist (HyperOS)

Do these once, in this order — HyperOS is the most aggressive Android skin
when it comes to killing background processes:

1. **Settings → Apps → Manage apps → Termux**
   - *Battery saver* → **No restrictions**
   - *Autostart* → **On**
2. **Settings → Battery & performance → App battery saver → Termux** → **No restrictions**
3. Recents screen: long-press the Termux card → **lock** (padlock icon)
4. **Settings → Apps → Termux:X11 → Notifications** → allow (Android 13+ gates this)
5. **Developer options** (tap MIUI/HyperOS version 7× in About phone):
   - Enable **Disable child process restrictions** — this is the Android 14+
     phantom-process-killer toggle; without it long-running Termux processes
     get silently killed (`[Process completed (signal 9)]`)
6. Still in Developer options: leave **MIUI optimization** ON (safe with Termux)
7. Give Termux **storage permission** when `bootstrap.sh` triggers the prompt
   (this is what creates `~/storage/downloads` for backups)
8. Optional for long sessions: run `termux-wake-lock` before heavy work

## Architecture notes (why the scripts do what they do)

- **GitHub Termux build**: the Play Store build is dead (API 29 forbids
  `exec()` from app data dirs) and the F-Droid signature can't share a UID
  with the GitHub-signed Termux:X11 APK. You're already on the right builds.
- **`sharedUid` APK recommended**: `scripts/install-x11.sh` explains replacing
  the regular `termux-x11-universal-debug.apk` with
  `termux-x11-universal-sharedUid-debug.apk` (same GitHub nightly release).
  Android throttles apps that aren't on screen — the sharedUid variant runs
  *as part of* Termux, so the desktop stays fast when Termux goes background.
- **`--shared-tmp`**: Termux:X11's socket lives in Termux's `$PREFIX/tmp`;
  the container must bind it at `/tmp` or the desktop can't reach the X
  server. `--shared-x11` (proot-distro 5.x) binds the X11 socket dir too.
- **Ports ≥ 1024 only**: no real root under proot. Privileged ports can be
  faked with `proot-distro login --redirect-ports` (80 → 2080).
- **No systemd**: use `service`, `runit`, or plain foreground processes.
- **No Docker/mount/iptables**: proot fakes root via UID remapping; kernel
  features (FUSE, real mounts, cgroups, netfilter) don't exist here.
- **Android 16's Linux Terminal**: stock Android 16 ships a Debian VM, but
  HyperOS on this device may not expose it — and proot Ubuntu is more
  flexible anyway (any OCI image, shares your storage, no AVF dependency).

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `[Process completed (signal 9)]` | Phantom process killer — do checklist steps 1–5, reboot |
| Desktop is slow when switching apps | Replace Termux:X11 APK with the `sharedUid` variant |
| Black screen, cursor only | Run `scripts/desktop.sh` with `PD_X11_ARGS="-legacy-drawing"` |
| Swapped colours | `PD_X11_ARGS="-force-bgra"` |
| `apt` inside Ubuntu can't resolve | Edit `/etc/resolv.conf` inside the container (proot copies Termux's DNS config at install time) |
| Fonts tiny on the 120 Hz panel | Set DPI in XFCE Appearance, or add `-dpi 120` in `scripts/desktop.sh` |
| Session dies when screen locks | Checklist steps 1–3 + `termux-wake-lock` |

Env knobs (all optional):

| Variable | Default | Used by |
|---|---|---|
| `PD_CONTAINER_NAME` | `ubuntu` | setup / desktop / backup / restore |
| `PD_IMAGE` | `ubuntu:24.04` | setup-ubuntu |
| `PD_UBUNTU_USER` | `thalha` | setup-ubuntu |
| `PD_DESKTOP` | `xfce` | desktop |
| `PD_DISPLAY` | `:1` | desktop |
| `PD_X11_ARGS` | *(empty)* | desktop (extra termux-x11 flags) |

## Roadmap

- [ ] Language toolchains (Node, Python venvs, Go, Rust) — deliberately deferred
- [ ] `sshd` on 8022 + SSH from the MacBook
- [ ] Termux:Boot autostart of the container
- [ ] `cloudflared` tunnel for public reachability
- [ ] PulseAudio audio forwarding

## License

MIT — see [LICENSE](LICENSE).
