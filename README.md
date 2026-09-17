# My Dotfiles

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Platform: Arch Linux](https://img.shields.io/badge/Platform-Arch_Linux-1793D1.svg)
![Managed with chezmoi](https://img.shields.io/badge/Managed_with-chezmoi-00A0B0.svg)

A reproducible **CachyOS** (Arch) laptop setup managed with
[chezmoi](https://chezmoi.io): KDE Plasma 6 on Wayland, dual-boot with Windows 11,
GPU passthrough (VFIO) for a Windows VM, a pipewire pro-audio chain, per-AC/battery
power and fan management, a slimmed initramfs, and `validate.sh` to check that every
piece of it actually landed.

Most of the value is in the things that took measurement to get right, and those are
written up in [`docs/`](docs/) — boot time, the firmware/EC power behaviour, and the
dead ends (so they are not re-explored).

## What is non-trivial here

This is not a "here is my `.zshrc`" repo. The parts that took real work, each with
a write-up in [`docs/`](docs/):

| Area | What it involved |
|---|---|
| **Boot: 114 s → 23 s** | Two dead UEFI boot entries were costing **91 s** of POST; plus an initramfs slimmed 248 → 55 MB and a snapshot cap so the ESP cannot fill up. |
| **Firmware and EC probing** | Mapped the AMD SMU interface on a Ryzen 5800H and established that Curve Optimizer is gated off by HP's firmware on **both** Linux and Windows — including catching a Windows tuning tool that reports failed writes as applied. |
| **VFIO GPU passthrough** | The RTX 3070 bound to `vfio-pci` on demand, a one-shot Limine entry, Looking Glass shared memory, libvirt. |
| **Pro audio on Linux** | Pipewire/JACK with a per-interface quantum (64 for the RME, 256 for the internal Ryzen codec), a switchable proprietary driver mode, and yabridge for Windows VSTs. |
| **Reproducibility** | `chezmoi` plus 11 idempotent `run_once` scripts, and a `validate.sh` that checks the machine actually ended up in the intended state — down to “the NVIDIA modules are still out of the initramfs”. |
| **Debugging** | Root-caused a periodic timer that silently resolved to `infinity`, a libvirt socket loop that undid its own work, and one wrong conclusion of my own that a controlled A/B test overturned. |

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
├── docs/                              # reference + investigation record (not deployed)
│   ├── boot-tuning.md                        # boot time: what was done, measured
│   ├── firmware-limits.md                    # BIOS/power/EC limits, consolidated
│   ├── HP-OMEN-15-en1xxx-power-report.md    # the Linux investigation
│   ├── HP-OMEN-CO-verdict-Windows.md        # Curve Optimizer: verdict + proof
│   ├── HP-OMEN-LINUX-next-steps.md          # what was left open
│   └── evidence/                       # SMU prober, load generator, raw runs
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

## Findings & caveats

The non-obvious things about this machine, recorded so they are not explored
again. Details, tools and raw measurements live in `docs/`.

- **Curve Optimizer / undervolt is impossible here** — on Linux *and* on
  Windows. The SMU refuses the whole OC/CO command family. UXTU only *looks* like
  it works: it swallows the failure and still updates its UI. Do not patch
  `ryzenadj` for it, and do not install ZenTune hoping for CO.
- **The BIOS “System Configuration” power setting is inert.** Selecting
  `35W POR` changed nothing — the HP EC owns those values. It is back on the
  default `Auto`.
- **An OS-written power profile does persist.** The only thing that clobbers it
  is a write to `/sys/class/platform-profile/platform-profile-0/profile`, which
  makes the EC re-apply its own limits, even when writing back the same value.
- **BIOS modding is not an option** (HP Sure Start active), and the update
  payload cannot even be extracted for offline inspection.
- **Boot time** dropped from 114 s to 23 s, essentially all of it in firmware. See
  `docs/boot-tuning.md` for the numbers and what was done.

→ `docs/firmware-limits.md` · `docs/boot-tuning.md`
→ Full investigation: `docs/HP-OMEN-15-en1xxx-power-report.md` (Linux),
`docs/HP-OMEN-CO-verdict-Windows.md` (the CO verdict and its proof),
`docs/HP-OMEN-LINUX-next-steps.md` (what was left open).

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

## Material You — “follows-the-wallpaper” (kitty/btop/zed/prompt)

The desktop (terminal + system monitor + editor + prompt) takes the colors of the
wallpaper, recolored by **`kde-material-you-colors`** (AUR) on every
wallpaper change.

**Color source**: the Konsole colorscheme `MaterialYou.colorscheme` that
`kde-material-you-colors` regenerates (`~/.local/share/konsole/`). kitty, btop,
Zed and the p10k prompt all read that same file → total consistency. The parsing
is centralized in `material_you_lib.py` (a single source of truth).

**Chain**: wallpaper changed → `kde-material-you-colors` daemon regenerates the
Material You → `on_change_hook` (`kitty-material-you-hook.sh`) **delegates to
`material-you-refresh`** (kitty + btop + Zed + prompt cache) → kitty reloads
(`pkill -USR1`).

**p10k prompt**: `material-you-prompt.py` writes `~/.cache/material-you/prompt.zsh`
(accent `~`/`❯`), which `.zshrc` "sources" in `precmd` → **no process launched
on every prompt** (previously: 2 `awk` per prompt).

**Zed**: `zed-material-you.py` writes `~/.config/zed/themes/materialyou.json`
(custom "Material You" theme, Ayu Dark structure + wallpaper colors). Zed
watches this folder and **hot-reloads** — no need to restart the editor.
The theme is selected via the `theme` key of `~/.config/zed/settings.json`.

> ℹ️ `settings.json` **is not versioned**: Zed writes the agent's permissions
> there dynamically (absolute paths, network hosts) → it would create noise
> and a `chezmoi apply` would overwrite recent authorizations. Instead,
> `run_once_09` sets only the `theme` key (idempotent), and creates a
> minimal `settings.json` if absent (fresh machine).

**Transparency: a single KWin rule "everything at 90%".**
- **kitty**: `background_opacity 0.85` (native kitty) → transparent background, **opaque
  text**.
- **All other windows**: a single KWin rule — group
  `Transparent_windows` in `kwinrulesrc`, **without `wmclass`** so it matches
  *all* windows — applies `opacity 90/90`. Konsole, Zed, Dolphin,
  System Settings are therefore glassy like the rest, by the same mechanism.
- Adjust the level: Window Rules in Settings, or
  `kwriteconfig6 --file kwinrulesrc --group 1503ce0e-1799-40f2-9ec4-efa44a851115
  --key opacityactive 92` then `qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure`.
- `kwinrulesrc` **is versioned**: after a change via the UI, do another
  `chezmoi add` (otherwise an apply reverts it).

> Why: KWin does not render a transparent background, it **blurs what is
> behind**. Transparency must come from the app (background only) to keep the
> text sharp — possible only if the app exposes it (kitty yes; Konsole only
> for the terminal area). Otherwise the KWin rule multiplies the whole window (text
> dimmed 10%).

**Blur: "everything" mode, no whitelist.** `run_once_08` imposes
`BlurMatching=false` + `BlurNonMatching=true` with `WindowClasses` **empty** →
every **translucent** window is blurred automatically. It is simpler and it
removes the class of bugs "translucent but not blurred" (a forgotten class =
glassy window but sharp) that we ran into several times. `WindowClasses`
now only serves as an **exceptions list** (a class will appear there if one day
something blurs badly). The blur is only visible under a translucent window; the
opaque ones do not change. (The "lag" we had attributed to the global blur came in
fact from `colorPowerTradeoff=PreferAccuracy` on DP-2, a per-screen KWin setting.)

**⚠️ Two fragile points** (worth knowing):

1. **The `kde-material-you-colors` daemon** autostarts at login (reads
   `config.conf` where `on_change_hook` is set). If it dies mid-session,
   it does not restart on its own → use `material-refresh` to re-sync
   by hand. On reboot, the autostart restarts it.
2. **`kwin-effects-better-blur-dx`** (AUR, KWin blur effect) is **compiled
   against KWin**. After a Plasma/KWin update, it can break (the blur
   disappears) → **rebuild** it: `paru -S kwin-effects-better-blur-dx` (or
   a full `paru -Su`). This is the first thing to check if the blur
   disappears after an update.

**Note**: this module is entirely separate in the repo — scripts in
`dot_local/bin/`, configs in `dot_config/{kitty,btop}/`, and `run_once_09`
which sets the `on_change_hook` key + Zed's `theme` key (both idempotent).

## Notes

- **SSH keys** (`~/.ssh/id_*`): backup manually before reinstall (too sensitive for dotfiles).
- **KDE config** — only the **stable** `.rc` files are versioned
  (`kwinrulesrc`, `kxkbrc`, `kglobalshortcutsrc`, `katerc`, `dolphinrc`,
  `konsolerc`) ; after a change via the UI, do another `chezmoi add`.
  `kdeglobals` and `kwinrc` **are not versioned**: they are rewritten at
  runtime (by Plasma, and by `kde-material-you-colors` for the colors) →
  versioning them fights the daemon and `chezmoi apply` would overwrite your settings.
  `run_once_08` declaratively imposes the keys that matter.
- **Audio PipeWire** — config versioned in `dot_config/pipewire/` and
  `dot_config/wireplumber/`:
  - **RME Babyface Pro FS** switchable between **CC** mode (kernel driver,
    `51-rme.conf`) and **proprietary** mode (in-house TuxMix driver via
    `50-tuxmix.conf`) — see
    `dot_config/pipewire/pipewire.conf.d/README.md`.
  - **Per-interface quantum**: global = 64 (RME CC), but the internal Ryzen
    sound card forces 256 (`52-ryzen-quantum.conf`) — the 64 causes
    underruns there.
- These quantum/node-name rules are specific to this laptop (Ryzen
  `pci-0000_07_00.6`, RME USB) — not intended for other machines.

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
