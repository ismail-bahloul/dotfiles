# My Dotfiles

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Platform: Arch Linux](https://img.shields.io/badge/Platform-Arch_Linux-1793D1.svg)
![Managed with chezmoi](https://img.shields.io/badge/Managed_with-chezmoi-00A0B0.svg)

A reproducible **CachyOS** (Arch) laptop setup managed with
[chezmoi](https://chezmoi.io): KDE Plasma 6 on Wayland, dual-boot with Windows 11,
GPU passthrough (VFIO) for a Windows VM, a pipewire pro-audio chain, per-AC/battery
power and fan management, a slimmed initramfs, and `validate.sh` to check that every
piece of it actually landed.

Most of the value is in the things that took measurement to get right, and those
are written up in [`docs/`](docs/) — the initramfs and boot tweaks, the theming
chain, and the working notes.

## Installation

```bash
# bootstrap: clone + install
mkdir -p ~/dotfiles && git clone https://github.com/ismail-bahloul/dotfiles.git ~/dotfiles
~/dotfiles/install.sh

# afterwards: update
chezmoi update --apply
```

SSH works too if you prefer: `git@github.com:ismail-bahloul/dotfiles.git`.

### Where the source lives

`chezmoi` reads its source directory from `~/.local/share/chezmoi`. On the
development machine that path is a **symlink to this repository**, so editing a
file here and running `chezmoi apply` are the same operation — there is no
second copy that can silently drift. A fresh machine gets a real clone at the
same path from `install.sh`; the commands are identical either way.

```bash
# one-time, on a machine where the repo already lives elsewhere
mv ~/.local/share/chezmoi ~/.local/share/chezmoi.bak
ln -s ~/DATA/05_Code/Projects/dotfiles ~/.local/share/chezmoi
```

## Components

What a machine installs is driven by the `components` list in
`~/.config/chezmoi/chezmoi.toml`. Each entry is a file in `packages.d/`:
`packages.d/<name>.pacman` (always present, possibly empty when the component's
packages are installed by its own script) and optionally
`packages.d/<name>.aur`. Adding a component to the list, or removing one, is the
whole switch.

`chezmoi init` seeds the file at its defaults (everything below enabled except
`wine`); change the list there and re-apply. (No prompt: `chezmoi init --apply`
runs from `install.sh` and must not block.) A config that has **no**
`components` key at all — written before the registry existed — keeps the
previous behaviour: every component except `wine`.

| Component | What it brings |
|---|---|
| `base` | always installed, not a switch: git, python, rsync, ripgrep, snapper, fwupd, openssh… |
| `shell` | zsh + Powerlevel10k + autosuggestions/syntax-highlighting/zoxide |
| `monitoring` | btop, nvtop, duf, fastfetch, plocate |
| `gpu_nvidia` | NVIDIA driver stack (libva-nvidia-driver, opencl, vulkan layers) |
| `hardware_amd` | iGPU Vulkan, amd-ucode, acpi_call, ryzenadj + ryzen_smu |
| `audio_pro` | PipeWire/JACK, REAPER, lsp-plugins, AUR plugins, realtime group |
| `virtualization` | QEMU, libvirt, virt-manager, OVMF/swtpm |
| `containers` | podman, distrobox |
| `network_security` | ufw, proton-vpn-cli |
| `apps` | firefox, zed, obsidian, bitwarden(+cli), localsend, vesktop, zapzap |
| `creative` | blender, obs-studio, upscayl, shutter-encoder |
| `peripherals` | logiops + the MX Master 3S `logid` config |
| `looking_glass` | Looking Glass host client (IVSHMEM) |
| `wine` | wine-staging 9.21 standalone runner, winetricks, yabridge — **off by default** |

```toml
# ~/.config/chezmoi/chezmoi.toml
[data]
    components = ["shell", "monitoring", "audio_pro", "apps"]
```

```bash
chezmoi apply
```

One caveat, deliberately stated:

- **A disabled component is not uninstalled.** It stops being installed on the
  next apply; packages already present stay. Remove them with `pacman -Rns` by
  hand (same rule as `wine` since the start).

A component switch also gates the setup scripts that belong to it: those scripts
call `component-guard` (`.chezmoitemplates/component-guard`) right after
sourcing the logging library, which renders a `log_skip` + `exit 0` when the
component is absent. Dropping `virtualization` therefore skips `run_once_05`
(VFIO) and `run_once_06` (libvirt).

`looking_glass` goes one step further and **tears its own configuration down**:
its script is `run_onchange_` (not `run_once_`, which keys its state on every
content hash ever seen and would skip a second disable after a re-enable), and
the guard also calls `looking-glass-teardown`, which removes the tmpfiles/sysctl
drop-ins and `/dev/shm/looking-glass`. Packages are still never removed. Others
only gate; adding a teardown is a per-component decision (pass its template name
to the guard).

| Gated script | Component |
|---|---|
| `run_once_02-wine-staging.sh.tmpl` | `wine` |
| `run_once_05-vfio-setup.sh.tmpl` | `virtualization` |
| `run_once_06-libvirt-setup.sh.tmpl` | `virtualization` |
| `run_onchange_07-looking-glass.sh.tmpl` | `looking_glass` (with teardown) |

The rest of the `run_once_*` scripts are machine-wide (packages, omenctl, KDE
settings, boot tuning, fstab) and have no component to belong to.

`wine = true` is still honoured as a legacy switch, equivalent to adding `wine`
to the list.

## Structure

```
dotfiles/
├── install.sh                        # bootstrap (paru + chezmoi + apply, --dry-run)
├── validate.sh                       # post-install verification script
├── test.sh                           # pre-push lint of the repo (bash -n, JSON, untracked)
├── .chezmoiscripts/                   # scripts run by chezmoi, never deployed
│   ├── run_once_01-packages.sh.tmpl      # base + enabled components (packages.d/)
│   ├── run_once_02-wine-staging.sh.tmpl  # wine-staging runner (optional: "wine" component)
│   ├── run_onchange_03-omenctl.sh        # omenctl (fans + power profiles), pinned ref
│   ├── run_once_04-omenctl.sh.tmpl       # omenctl units + udev rules
│   ├── run_once_05-vfio-setup.sh.tmpl    # GPU passthrough (VFIO) — virtualization
│   ├── run_once_06-libvirt-setup.sh.tmpl # libvirt services + groups — virtualization
│   ├── run_onchange_07-looking-glass.sh.tmpl # Looking Glass shared memory — looking_glass
│   ├── run_once_08-kde-settings.sh       # KDE settings enforced via kwriteconfig6
│   ├── run_once_09-material-you.sh       # Material You “follows-the-wallpaper” (kitty/btop/zed hook)
│   ├── run_once_10-fstab-shared.sh       # shared NTFS partition in fstab
│   └── run_once_11-boot-tuning.sh.tmpl   # initramfs slimming + Limine snapshot cap
├── lib/                               # shell libraries, sourced by the scripts above
│   ├── logging.sh                     # log_* helpers (+ summary counters)
│   └── system.sh                      # install_system_file: etc/… → /etc/…
├── .chezmoitemplates/
│   └── component-guard                # no-op a script when its component is off
├── packages.d/                       # package registry: one file per component
│   ├── base.pacman                   # always installed
│   ├── audio_pro.pacman              # e.g. pro-audio chain (also audio_pro.aur)
│   └── <component>.{pacman,aur}      # installed when listed in `components`
├── dot_zshrc                         # zsh: p10k + plugins with guards (no distro config package)
├── dot_p10k.zsh                      # p10k prompt config (regenerate: `p10k configure` + `chezmoi add`)
├── dot_gitconfig                     # git config: credential helpers + aliases (identity = untracked ~/.config/git/local)
├── etc/                              # system files (units, udev, initcpio, tmpfiles, sysctl, logid)
│   ├── initcpio/install/no-nouveau    # mkinitcpio hook: drop nouveau + GSP fw
│   └── mkinitcpio.conf.d/20-no-nouveau.conf
├── docs/                              # why the config here is the way it is
│   ├── README.md                             # index
│   ├── boot-tuning.md                        # initramfs slimming + UEFI boot entries
│   ├── material-you.md                       # wallpaper-driven theming + KWin rules
│   └── notes.md                              # versioned-vs-not, audio, SSH keys
├── dot_config/create_*                # created only if absent (Plasma/Kate own them afterwards)
│   └── plasma-*.appletsrc             # panel/widgets layout (volatile → apply once)
├── dot_config/
│   ├── gh/                           # GitHub CLI config
│   ├── kitty/kitty.conf               # terminal (includes theme-wallpaper.conf)
│   ├── btop/btop.conf                 # system monitor (color_theme = materialyou)
│   ├── pipewire/pipewire.conf.d/      # PipeWire: global quantum + proprietary RME mode (TuxMix)
│   ├── wireplumber/wireplumber.conf.d/# WirePlumber: per-interface RME (CC) rules + Ryzen onboard
│   └── *.rc                           # KDE config STABLE only (shortcuts via UI, kwin rules, kate/dolphin/konsole)
├── dot_local/
│   ├── bin/                          # commands on PATH
│   │   ├── limine-boot-win           # one-time boot to Windows
│   │   ├── limine-boot-vfio          # one-time boot to VFIO kernel
│   │   ├── limine-boot-linux         # restore boot to Linux
│   │   ├── backup-data               # backup DATA to external drive
│   │   ├── omenctl-tui               # desktop launcher wrapper (sudo + terminal)
│   │   ├── mount-shared              # mount Windows SHARED (NTFS) in rw
│   │   ├── umount-shared             # unmount SHARED before rebooting to Windows
│   │   ├── deploy-plugins            # deploy Linux audio plugins (VST3/LV2/CLAP)
│   │   ├── .add-vfio-entry           # (internal) adds the VFIO entry to limine.conf
│   │   ├── kitty-material-you-hook.sh# run by kde-material-you-colors → delegates to material-you-refresh
│   │   └── material-you-refresh      # manual re-sync (safety net)
│   ├── lib/material-you/             # generators (internal, NOT on PATH)
│   │   ├── material_you_lib.py       # shared palette parser (single source of truth)
│   │   ├── kitty.py                  # kitty colors ← wallpaper
│   │   ├── btop.py                   # btop theme ← wallpaper
│   │   ├── zed.py                    # Zed theme ← wallpaper (hot-reloads)
│   │   ├── zen.py                    # Zen accent + userChrome (restart Zen)
│   │   └── prompt.py                 # p10k prompt + LS_COLORS (1x, not per prompt)
│   ├── share/plasma/plasmoids/       # KDE widgets (thermal monitor, salat)
│   ├── share/applications/omenctl.desktop  # application-menu entry for the TUI
│   └── share/icons/hicolor/scalable/apps/omenctl.svg  # launcher icon
```

Scripts live in `.chezmoiscripts/` (a chezmoi special directory: run, never
deployed). chezmoi applies entries in target-path order, so `.chezmoiscripts/`
sorts **before** `~/.config` and `~/.local`: a run script must read the repo
assets it needs from `$CHEZMOI_SOURCE_DIR`, not from `~`, or it will not find
them on a fresh machine.

## System files (`etc/`)

Files that live outside `~` (mkinitcpio hooks, systemd units, udev rules,
tmpfiles/sysctl drop-ins, the logid config) are versioned under `etc/` with the
**same path they have on the machine**, so the
repo tree mirrors `/etc`. They are not deployed by chezmoi itself (`etc` is in
`.chezmoiignore`); a script in `.chezmoiscripts/` installs them:

- `run_once_01-packages.sh.tmpl` — `/etc/logid.cfg` (the `peripherals` block)
- `run_once_04-omenctl.sh.tmpl` — the omenctl profile/watch units and udev rules
- `run_onchange_07-looking-glass.sh.tmpl` — the IVSHMEM tmpfiles entry and the hugepages sysctl
- `run_once_11-boot-tuning.sh.tmpl` — the initramfs hooks and the VFIO drop-in

They all use `install_system_file` (`lib/system.sh`), which copies a file only if
it differs from the installed one. They are **templates** whose header carries an
`etc-hash:` line: a hash of the `etc/` files the script installs. chezmoi
re-runs a `run_once_` script only when its own content changes, so without that
line editing a unit would never be redeployed. **When you add a file under
`etc/`, add its path to the `etc-hash` list of the script that installs it.**

`validate.sh` compares every file under `etc/` with its installed copy, so a
missing hash entry or a hand-edited `/etc` file shows up as a failure.

## Hardware

| Component | Model |
|---|---|
| **Laptop** | HP OMEN 15-en1037nf (4J8B4EA) |
| **CPU** | AMD Ryzen 7 5800H (8C/16T, Zen 3) |
| **iGPU** | AMD Radeon Graphics (Vega) |
| **dGPU** | NVIDIA GeForce RTX 3070 Mobile (GA104, 8 GB GDDR6) |
| **RAM** | 2× 16 GB DDR4-3200 |
| **Storage** | SK Hynix 512 GB (NVMe) + Crucial 1 TB (NVMe) |
| **Network** | Realtek RTL8111/8168 (Ethernet) + Intel Wi-Fi 6 AX200 |
| **Display** | LG UltraGear 27GP850 (2560x1440 @ 144 Hz, DP, wired to the dGPU: no external output on the iGPU) |

## Stack

- **OS**: Dualboot (Linux CachyOS + Windows 11)
- **Shell**: zsh + Powerlevel10k
- **DE**: KDE Plasma 6 (Wayland)
- **GPU**: NVIDIA RTX 3070 + AMD Vega (VFIO passthrough for VM)
- **Audio**: Pipewire (JACK) + REAPER + yabridge (Windows VST bridge)
- **Virtualization**: QEMU + virt-manager + distrobox
- **Fan control**: omenctl (EC setpoints, tuned curve, safety contract)
- **Power mgmt**: omenctl profile (auto/quiet/eco/perf, AC/battery) + RyzenAdj + NVIDIA
- **Wine**: wine-staging 9.21 standalone runner (~/.local/share/wine-runners/)
- **Peripherals**: Logitech MX Master 3S (logiops)

## Omenctl

`omenctl` is the single tool for the fans and the power profiles on this
machine: it owns the two EC fan setpoints, runs the tuned curve at 1 Hz, and
applies `auto` / `quiet` / `eco` / `perf` across the CPU limits, the platform
profile and the dGPU lock. It replaces both `nbfc` and the old `power-profile`
bash script (kept in `myomen15/omenctl/legacy/power-profile/` for reference).

- Upstream: <https://github.com/ismail-bahloul/omenctl>
- Installed by `run_onchange_03-omenctl.sh`: a local checkout is used when
  `OMENCTL_SRC` points at one (default: `myomen15/omenctl`), otherwise the
  pinned tag (`OMENCTL_REF`, default `v0.4.0`) is cloned. Bump the ref in the
  script to publish an update; `run_onchange_` re-runs on the changed content.
- Units: `omenctl.service` (fan governor), `omenctl-profile.service` +
  `omenctl-profile.timer` (periodic re-apply), `omenctl-watch.service`
  (inotify/drift watcher), and the AC udev rule `99-omenctl.rules`.
- Commands: `omenctl status`, `omenctl profile auto|quiet|eco|perf`,
  `omenctl fan cpu|gpu|all 0-100|auto`, `omenctl tui`,
  `omenctl curve cpu|gpu`, `omenctl start|stop`.
- Rollback: `sudo systemctl stop omenctl` writes `255` to both setpoints and
  hands the fans back to the EC's own (louder) curve. The dotfiles never install
  or start `nbfc`; omenctl is the only fan/power stack they set up.
- Desktop: the application-menu entry
  (`dot_local/share/applications/omenctl.desktop`) calls
  `/usr/local/bin/omenctl-tui`, a symlink created by `run_onchange_03` to the
  chezmoi-deployed `~/.local/bin/omenctl-tui`. The icon is
  `dot_local/share/icons/hicolor/scalable/apps/omenctl.svg` (installed as
  `~/.local/share/icons/hicolor/scalable/apps/omenctl.svg`). The wrapper runs
  `sudo -n omenctl tui` (falling back to an interactive prompt) and
  `Terminal=true` opens it in the default terminal. If KDE asks to trust the
  desktop file, right-click it and choose “Allow launching”. Pin it to the
  desktop from the application menu if you want a shortcut there.

## Aliases

| Alias | Action |
|---|---|
| `ff` | fastfetch |
| `ww` | One-time boot to Windows |
| `vv` | One-time boot to VFIO GPU passthrough kernel |
| `ll` | One-time boot to default Linux kernel |
| `backup` | Backup DATA to external drive |
| `power` | Show power status (CPU/GPU temps, limits, fans) |
| `auto` | Follow AC/battery (default profile) |
| `quiet` | AC/battery with CPU boost off (cooler/silent) |
| `eco` | Battery envelope even on AC (15 W / 2.4 GHz) |
| `perf` | Switch to performance mode (4.47 GHz / GPU unlocked) |
| `material-refresh` | Re-sync kitty/btop/zed/prompt to current wallpaper colors |
| `uu` | Full update: repos + AUR + Flatpak + orphan/cache cleanup |

`uu` runs `arch-auto-update`, versioned in its own private repo
(<https://github.com/ismail-bahloul/arch-auto-update>) and checked out at
`~/DATA/05_Code/Projects/arch-auto-update`. Useful flags: `-c` preview the
available updates, `-n` dry run, `--force` bypass the news guard once a
manual-intervention announcement has been read.

## Vendored third-party widgets

The two KDE plasmoids under `dot_local/share/plasma/plasmoids/` are **upstream
projects vendored as-is** (not written here). Their licenses apply to their own
code, independently of this repo's MIT license:

| Plasmoid | License | Upstream |
|---|---|---|
| `org.kde.olib.thermalmonitor` | MIT | https://invent.kde.org/olib/thermalmonitor |
| `com.github.mazen.salatprayertime` | GPL-3.0+ | https://github.com/mazenmohamed203/salaatprayertime |

They are vendored because they are not reliably available from the repos/AUR.
Upstream updates will **not** reach this copy automatically — re-vendor manually
if needed. The GPL-3.0+ text should accompany any redistribution.
