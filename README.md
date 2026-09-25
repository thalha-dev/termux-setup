# termux-setup

One-shot setup scripts for a **CLI proot Ubuntu** environment on Termux —
built and tested against a **Redmi Note 13 Pro 5G** (Snapdragon 7s Gen 2,
`aarch64`, HyperOS / Android 15). No root required, no GUI.

What you end up with:

- **Termux** (GitHub build, already installed) with `proot-distro` 5.x
- A real **Ubuntu 24.04** userland pulled as an OCI image: `apt`, `git`,
  `curl`, `wget`, `sudo` (passwordless), `en_US.UTF-8` locale, and the basic
  CLI toolkit (`tmux`-style work happens inside; language toolchains come
  later, on purpose)
- Phone hardening so Android/HyperOS stops killing the session
- Backup/restore of the whole container to your Downloads folder

## Run order

Inside the Termux app:

```sh
pkg install -y git
git clone https://github.com/thalha-dev/termux-setup.git
cd termux-setup

bash bootstrap.sh                 # 1. update Termux + install proot-distro
bash scripts/setup-ubuntu.sh      # 2. pull ubuntu:24.04, create user, sudo, locale
proot-distro login ubuntu         # 3. you are in real Ubuntu (CLI)
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
4. **Developer options** (tap MIUI/HyperOS version 7× in About phone):
   - Enable **Disable child process restrictions** — this is the Android 14+
     phantom-process-killer toggle; without it long-running Termux processes
     get silently killed (`[Process completed (signal 9)]`)
5. Still in Developer options: leave **MIUI optimization** ON (safe with Termux)
6. Give Termux **storage permission** when `bootstrap.sh` triggers the prompt
   (this is what creates `~/storage/downloads` for backups)
7. Optional for long sessions: run `termux-wake-lock` before heavy work

## What CLI Ubuntu in your pocket is good for

- **Dev toolchains**: Python/pip/venv, Node/npm, Go, Rust, gcc/clang/cmake —
  on-device compilation works (proot overhead ≈ 30–50% on heavy builds)
- **Servers**: nginx, MariaDB/PostgreSQL, Redis, Flask/FastAPI/Express.
  Ports ≥ 1024 only (no root), no systemd — start daemons directly or from tmux
- **Web-UI apps without any GUI**: `jupyter notebook --no-browser`,
  code-server (VS Code in a browser) — open `http://<phone-ip>:<port>` from
  the MacBook; compute on the phone, interface on the laptop
- **Local AI**: `ollama` / llama.cpp with 1.5–4B quantized models (slow but real)
- **SSH into the phone**: `openssh-server` inside the container on port 8023,
  then `ssh -p 8023 thalha@<phone-ip>` from the MacBook — full Ubuntu shell
  in the Mac terminal, sessions survive via tmux
- **Daily CLI**: git with your SSH keys, rsync, yt-dlp, aria2c, sqlite3, jq…

## Architecture notes (why the scripts do what they do)

- **GitHub Termux build**: the Play Store build is dead (API 29 forbids
  `exec()` from app data dirs). You're already on the right build.
- **proot-distro 5.x** pulls Ubuntu as a real OCI image from Docker Hub —
  `proot-distro install --name ubuntu ubuntu:24.04`, not the old fixed-tarball
  flow from older tutorials.
- **`sudo` is passwordless** (`/etc/sudoers.d/90-<user>`): proot root is
  cosmetic anyway (UID remapping). Remove the file if you want prompts.
- **Ports ≥ 1024 only**: no real root under proot. Privileged ports can be
  faked with `proot-distro login --redirect-ports` (80 → 2080).
- **No systemd**: start services directly, or use `service`/runit; long
  interactive work belongs in `tmux` so disconnects don't kill it.
- **No Docker/mount/iptables/FUSE**: proot fakes root via UID remapping;
  kernel features don't exist here.
- **Android 16's Linux Terminal**: stock Android 16 ships a Debian VM, but
  HyperOS on this device may not expose it — proot Ubuntu is more flexible
  anyway (any OCI image, shares your storage, no AVF dependency).

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `[Process completed (signal 9)]` | Phantom process killer — do checklist steps 1–4, reboot |
| `apt` inside Ubuntu can't resolve | Edit `/etc/resolv.conf` inside the container (proot copies Termux's DNS config at install time) |
| Session dies when screen locks | Checklist steps 1–3 + `termux-wake-lock` |
| `proot-distro: refusing to run inside another proot` | You're already inside the container — that's the point; don't nest |
| Container eating space | `du -sh $PREFIX/var/lib/proot-distro/containers/*` — remove with `proot-distro remove ubuntu` (wipes it) |

Env knobs (all optional):

| Variable | Default | Used by |
|---|---|---|
| `PD_CONTAINER_NAME` | `ubuntu` | setup / backup / restore |
| `PD_IMAGE` | `ubuntu:24.04` | setup-ubuntu |
| `PD_UBUNTU_USER` | `thalha` | setup-ubuntu |

## Roadmap

- [ ] Language toolchains (Node, Python venvs, Go, Rust) — deliberately deferred
- [ ] `scripts/setup-ssh.sh`: container sshd on 8023 + keys + tmux
- [ ] code-server / Jupyter setup script
- [ ] Termux:Boot autostart of the container
- [ ] `cloudflared` tunnel for public reachability

## License

MIT — see [LICENSE](LICENSE).
