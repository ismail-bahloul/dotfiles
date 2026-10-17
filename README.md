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

## Structure

```
dotfiles/
├── install.sh                        # bootstrap (paru + chezmoi + apply, --dry-run)
├── validate.sh                       # post-install verification script
├── test.sh                           # pre-push lint of the repo (bash -n, JSON, untracked)
├── run_once_01-packages.sh           # pacman + AUR packages
├── run_once_02-wine-staging.sh       # wine-staging 9.21 standalone runner
├── run_once_03-omenctl.sh            # omenctl (fans + power profiles)
├── run_once_04-omenctl.sh.tmpl       # omenctl units + udev rules
├── run_once_05-vfio-setup.sh         # GPU passthrough (VFIO)
├── run_once_06-libvirt-setup.sh      # libvirt services + groups
├── run_once_07-looking-glass.sh      # Looking Glass shared memory
├── run_once_08-kde-settings.sh       # KDE settings enforced via kwriteconfig6
├── run_once_09-material-you.sh       # Material You “follows-the-wallpaper” (kitty/btop/zed hook)
├── run_once_10-fstab-shared.sh       # shared NTFS partition in fstab
├── run_once_11-boot-tuning.sh.tmpl   # initramfs slimming + Limine snapshot cap
├── run_once_12-remove-nbfc.sh        # one-time migration: remove the old nbfc fork
├── packages.pacman                   # official repo packages
├── packages.aur                      # AUR packages
├── etc/                              # system files (units, udev, initcpio) installed by run_once_03/04/11
│   ├── initcpio/install/no-nouveau    # mkinitcpio hook: drop nouveau + GSP fw
│   └── mkinitcpio.conf.d/20-no-nouveau.conf
├── docs/                              # why the config here is the way it is
│   ├── README.md                             # index
│   ├── boot-tuning.md                        # initramfs slimming + UEFI boot entries
│   ├── material-you.md                       # wallpaper-driven theming + KWin rules
│   └── notes.md                              # versioned-vs-not, audio, SSH keys
├── Desktop/
│   └── omenctl.desktop                # desktop shortcut (runs `omenctl tui`)
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
│   ├── bin/                          # boot scripts, helpers, Material You
│   │   ├── limine-boot-win           # one-time boot to Windows
│   │   ├── limine-boot-vfio          # one-time boot to VFIO kernel
│   │   ├── limine-boot-linux         # restore boot to Linux
│   │   ├── backup-data               # backup DATA to external drive
│   │   ├── omenctl-tui               # desktop launcher wrapper (sudo + terminal)
│   │   ├── mount-shared              # mount Windows SHARED (NTFS) in rw
│   │   ├── umount-shared             # unmount SHARED before rebooting to Windows
│   │   ├── deploy-plugins            # deploy Linux audio plugins (VST3/LV2/CLAP)
│   │   ├── .add-vfio-entry           # (internal) adds the VFIO entry to limine.conf
│   │   ├── material_you_lib.py       # (internal, non-executable) shared Material You palette
│   │   ├── kitty-material-you.py     # kitty colors ← wallpaper (Material You)
│   │   ├── btop-material-you.py      # btop theme ← wallpaper (Material You)
│   │   ├── zed-material-you.py       # Zed theme ← wallpaper (Material You)
│   │   ├── material-you-prompt.py    # p10k prompt cache ← wallpaper (1x, not per prompt)
│   │   ├── kitty-material-you-hook.sh# run by kde-material-you-colors → delegates to material-you-refresh
│   │   └── material-you-refresh      # manual re-sync (safety net)
│   ├── share/plasma/plasmoids/       # KDE widgets (thermal monitor, salat)
│   └── share/applications/omenctl.desktop  # application-menu entry for the TUI
```

## System files (`etc/`)

Files that live outside `~` (mkinitcpio hooks, systemd units, udev rules) are
versioned under `etc/` with the **same path they have on the machine**, so the
repo tree mirrors `/etc`. They are not deployed by chezmoi itself (`etc` is in
`.chezmoiignore`); a `run_once_` script installs them:

- `run_once_04-omenctl.sh.tmpl` — the omenctl profile/watch units and udev rules
- `run_once_11-boot-tuning.sh.tmpl` — the initramfs hooks and the VFIO drop-in

Both use `install_system_file` (`.lib_system.sh`), which copies a file only if it
differs from the installed one. Both are **templates** whose header carries an
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

## omenctl

`omenctl` is the single tool for the fans and the power profiles on this
machine: it owns the two EC fan setpoints, runs the tuned curve at 1 Hz, and
applies `auto` / `quiet` / `eco` / `perf` across the CPU limits, the platform
profile and the dGPU lock. It replaces both `nbfc` and the old `power-profile`
bash script (kept in `myomen15/omenctl/legacy/power-profile/` for reference).

- Upstream: <https://github.com/ismail-bahloul/omenctl>
- Installed by `run_once_03-omenctl.sh`: a local checkout is used when
  `OMENCTL_SRC` points at one (default: `myomen15/omenctl`), otherwise the repo
  is cloned.
- Units: `omenctl.service` (fan governor), `omenctl-profile.service` +
  `omenctl-profile.timer` (periodic re-apply), `omenctl-watch.service`
  (inotify/drift watcher), and the AC udev rule `99-omenctl.rules`.
- Commands: `omenctl status`, `omenctl profile auto|quiet|eco|perf`,
  `omenctl fan cpu|gpu|all 0-100|auto`, `omenctl tui`,
  `omenctl curve cpu|gpu`, `omenctl start|stop`.
- Rollback: `sudo systemctl stop omenctl` writes `255` to both setpoints and
  hands the fans back to the EC's own (louder) curve. The dotfiles no longer
  install or start `nbfc`; a leftover `nbfc_service` from an older install is
  left disabled and unused.
- Desktop: `dot_Desktop/omenctl.desktop` and the application-menu entry call
  `/usr/local/bin/omenctl-tui`, a symlink created by `run_once_03` to the
  chezmoi-deployed `~/.local/bin/omenctl-tui`. The wrapper runs
  `sudo -n omenctl tui` (falling back to an interactive prompt) and
  `Terminal=true` opens it in the default terminal. If KDE asks to trust the
  desktop file, right-click it and choose “Allow launching”.

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
