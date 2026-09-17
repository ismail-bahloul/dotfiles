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
chain, and the working notes. The firmware and power investigation (what the BIOS
settings actually do, why undervolting is impossible on this machine) lives in
its own repository:
[myomen15](https://github.com/ismail-bahloul/myomen15).

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
├── run_once_03-nbfc.sh               # nbfc-linux + nbfc-qt (forks)
├── run_once_04-power-profile.sh      # RyzenAdj + NVIDIA power profiles + EC re-apply timer
├── run_once_05-vfio-setup.sh         # GPU passthrough (VFIO)
├── run_once_06-libvirt-setup.sh      # libvirt services + groups
├── run_once_07-looking-glass.sh      # Looking Glass shared memory
├── run_once_08-kde-settings.sh       # KDE settings enforced via kwriteconfig6
├── run_once_09-material-you.sh       # Material You “follows-the-wallpaper” (kitty/btop/zed hook)
├── run_once_10-fstab-shared.sh       # shared NTFS partition in fstab
├── run_once_11-boot-tuning.sh        # initramfs slimming + Limine snapshot cap
├── packages.pacman                   # official repo packages
├── packages.aur                      # AUR packages
├── etc/                              # system files installed by run_once_11
│   ├── initcpio/install/no-nouveau    # mkinitcpio hook: drop nouveau + GSP fw
│   └── mkinitcpio.conf.d/20-no-nouveau.conf
├── docs/                              # why the config here is the way it is
│   ├── README.md                             # index
│   ├── boot-tuning.md                        # initramfs slimming + UEFI boot entries
│   ├── material-you.md                       # wallpaper-driven theming + KWin rules
│   └── notes.md                              # versioned-vs-not, audio, SSH keys
├── my-nbfc.json                       # custom fan profile (NBFC)
├── create_dot_config/                 # created only if absent (Plasma owns it afterwards)
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
│   │   ├── power-profile             # CPU/GPU power management
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
│   └── share/plasma/plasmoids/       # KDE widgets (thermal monitor, salat)
```

## Hardware

| Component | Model |
|---|---|
| **Laptop** | HP OMEN 15-en1xxx (15-en1022nf) |
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
- **Fan control**: nbfc-linux (fork ismail-bahloul)
- **Power mgmt**: RyzenAdj + NVIDIA power profiles (AC/battery auto, re-applied every 5 min as a safety net)
- **Wine**: wine-staging 9.21 standalone runner (~/.local/share/wine-runners/)
- **Peripherals**: Logitech MX Master 3S (logiops)

## Aliases

| Alias | Action |
|---|---|
| `ff` | fastfetch |
| `ww` | One-time boot to Windows |
| `vv` | One-time boot to VFIO GPU passthrough kernel |
| `ll` | One-time boot to default Linux kernel |
| `backup` | Backup DATA to external drive |
| `power` | Show power profile status (CPU/GPU temps, limits, fans) |
| `balanced` | Reset to balanced profile (auto AC/battery) |
| `perf` | Switch to performance mode (4.4 GHz / GPU unlocked) |
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
