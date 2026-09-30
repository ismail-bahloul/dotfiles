# Boot tuning

On this machine (HP OMEN 15-en1xxx). Everything below except the UEFI boot order
lives under `/etc` and is applied by `run_once_11-boot-tuning.sh`; the boot order
is machine state (NVRAM), not something a dotfiles repo can version.

> A note on numbers: `systemd-analyze`'s *firmware* phase counts from power-on,
> so time spent sitting in the BIOS setup menus is billed to POST. Any figure
> captured after a BIOS visit is meaningless. That is why this page describes
> what was changed rather than how many seconds it saved.

- **Dead UEFI boot entries removed.** Two stale entries sat ahead of the real
  one: a `Limine` pointing at a GPT partition that no longer existed, and a
  "Windows Boot Manager" label pointing at a deleted `\EFI\cachyos\grubx64.efi`.
  They are gone (both were unbootable) and Limine is kept early in `BootOrder`
  so it cannot be shadowed. The HP firmware re-promotes the USB entry to the
  front on its own — that one fails fast and is left in place. Check with
  `efibootmgr`, repair with `efibootmgr -o`.
- **nouveau and its per-chipset NVIDIA firmware dropped from the initramfs**
  (`etc/initcpio/install/no-nouveau`). The `kms` hook resolves the NVIDIA GPU
  modalias to *both* `nvidia` and `nouveau`, and nouveau's `modinfo` declares the
  GSP firmware of every GPU generation it supports — roughly **140 MiB** of
  unused firmware in the early CPIO. This machine uses the proprietary driver
  (nouveau is blacklisted in `nvidia-utils.conf`), so the hook removes it.
  Initramfs size: **248 MB → 55 MB**.
- **NVIDIA kernel modules kept out of the initramfs** (see the commented
  `MODULES+=(nvidia …)` in `/etc/mkinitcpio.conf.d/10-chwd.conf`). They cost
  ~33 MiB and 666 firmware files, and `nvidia_drm` alone took 2.85 s to load in
  the initrd, plus an NVRM assertion. The internal panel is AMD/amdgpu; the dGPU
  is driven by the proprietary driver (or vfio-pci, depending on the Limine
  entry) and is brought up later by udev.
  `chwd` regenerates that file and puts the modules back, so `run_once_11`
  re-comments the line on every run.
- **amdgpu forced into the initramfs for early KMS**
  (`/etc/mkinitcpio.conf.d/30-amdgpu-early.conf`, `MODULES+=(amdgpu)`). The
  `kms` hook only *copies* `amdgpu.ko` into the image; nothing pulled it in
  during the initrd, so the iGPU was bound by udev coldplug in the real root.
  Measured across five boots (`journalctl -b -o short-monotonic`), the driver
  only appears **~2.3 s after `Finished Plymouth switch root service`** — a
  window in which *nothing* logs, kernel or systemd, until the first `amdgpu`
  line. Plymouth (which needs a DRM node) and everything behind the display
  waits it out. (An earlier revision of this page wrongly claimed the `kms` hook
  already gave amdgpu early KMS; it did not.)
  **Confirmed after a reboot:** amdgpu now initialises at ~4.6 s, *during* the
  initrd (before `Starting Plymouth switch root service`), the silent window is
  gone (the kernel is busy with amdgpu/nvme/sdhci instead), and the initrd phase
  dropped **7.8 s → 5.2 s**.
- **`systemd-binfmt.service` masked.** It runs on every boot and pulls in
  `proc-sys-fs-binfmt_misc.mount` (~1 s on the critical chain) even though no
  `binfmt.d` entry exists on this machine. Masking it leaves the automount in
  place, which mounts the registry the first time something actually needs it
  (e.g. qemu-user) instead of at boot.
- **Limine snapshot entries capped at 8** (`MAX_SNAPSHOT_ENTRIES=8` in
  `/etc/limine-snapper-sync.conf`). The 4 GiB ESP is shared with the kernel
  images and each kernel update adds snapshot entries. With the default (`auto`)
  the ESP reached **85%**, at which point `limine-snapper-sync` silently stops
  adding entries and kernel updates start failing. Capped at 8 it sits near
  **14%**.

## Still on the table

The early-KMS fix above closed the gap that used to dominate the initrd. Measured
before → after (two consecutive boots, same machine):

| Phase      | before  | after   |
|------------|---------|---------|
| firmware   | 4.62 s  | 4.73 s  |
| loader     | 1.44 s  | 1.79 s  |
| kernel     | 0.88 s  | 0.88 s  |
| initrd     | 7.84 s  | 5.24 s  |
| userspace  | 6.33 s  | 5.44 s  |
| **total**  | **21.10 s** | **18.08 s** |

(firmware/loader moved the *wrong* way by ~0.45 s combined — that is BIOS POST
and Limine menu jitter, not related to the change; the OS-side gain is ~3.5 s.)
A side effect worth noting: `power-profile.service` (2.0 s → 0.12 s) and
`nvidia-persistenced.service` (1.7 s → 0.02 s) also got much faster, and
`proton.VPN.service` left the critical chain — they were previously serialised
behind the stalled udev/GPU work.

What is left, roughly in order of payoff:

- **Plymouth** (`splash` on the cmdline, `plymouth-quit.service` +
  `plymouth-quit-wait` on the chain). Purely cosmetic; dropping it
  (`plymouth.enable=0`, remove `splash`) is the next clean win if the boot splash
  is not wanted.
- The **udev coldplug tail**: `serial8250` `ttyS0..3` and the `SHARED` NTFS
  partition settle at ~5.9 s (async, after `graphical.target`, so they do not
  block the desktop). `8250.nr_uarts=0` or a module blacklist would quiet them.
- **`run-bpftune-cgroupv2.mount`** appeared on the critical chain (~4.7 s) — a
  `bpftune` unit, not investigated.
- **firmware (4.7 s) + loader (1.8 s)** are the floor: the HP POST dominates and
  cannot be tuned from the OS; the Limine menu timeout is already 1 s.

## The initramfs was 56 MiB, and most of it was firmware for GPUs this machine does not have

`systemd-analyze` before this change: firmware **4.6 s** + loader **3.6 s** + kernel
0.9 s + **initrd 7.5 s** + userspace 6.4 s = **22.9 s**. The loader reads 73 MiB
(17 MiB kernel + 56 MiB initramfs) off the vfat ESP, and the kernel then
decompresses the initramfs before switch-root -- one cause behind two of the five
lines.

The `kms` hook adds every firmware file the DRM modules declare. For amdgpu that
is **691 files** -- every ASIC AMD ships (polaris, vega, navi, aldebaran, gc_11,
gc_12, ...). This iGPU is a Renoir/Cezanne APU (`gfx_v9_0 / smu_v12_0 / psp_v12_0 /
vcn_v2_0 / sdma_v4_0`), so ~670 of them can never load. They were ~30 MiB of the
image.

`etc/initcpio/install/amdgpu-trim` keeps only the GC 9.0 APU cluster
(`renoir`/`green_sardine`/`cezanne`/`lucienne`/`barcelo`) and drops the rest;
registered by `etc/mkinitcpio.conf.d/40-amdgpu-trim.conf`, after `no-nouveau`.

| | before | after |
|---|---|---|
| initramfs | **56 MiB** | **28 MiB** |
| amdgpu firmware blobs in the image | 691 | 115 |
| `renoir_*.bin` (what this APU loads) | 10 | **10** |

The 10 `renoir_*.bin` are exactly the set the *previous* image carried, so nothing
the working boot needed was dropped (the pre-trim image had no `renoir_mec2` or
`renoir_gpu_info` either). The 115 that remain are ~3 MiB that mkinitcpio re-adds
after the hook has run -- the hook cannot see them, and they are not worth
chasing.

**Rollback:** boot a Limine **Snapshots** entry. Those point at the pre-trim image
saved under `limine_history/`, not the rebuilt one.

### Result (measured, boot by boot)

| | origin | deployed |
|---|---|---|
| firmware | 4.625 s | 4.617 s |
| loader | 3.559 s | **1.496 s** |
| kernel | 0.873 s | 0.876 s |
| initrd | 7.491 s | **5.368 s** |
| userspace | 6.361 s | **4.287 s** |
| **total** | **22.910 s** | **16.645 s** |

**22.9 → 16.6 s, −27 %**, and the firmware trim is the whole story: it took the
initramfs from 56 to 28 MiB and the loader and initrd fell with it.

**Plymouth was then removed, measured, and put back.** It is worth only
**−0.41 s** — not the 1.15 s its units account for on their own (they overlap
with other work, so most of that time was never on the critical path) — and the
price is the boot splash. The splash was judged worth more than 0.41 s, so the
hooks and the `splash` cmdline are restored and the deployed boot is the 16.6 s
row above.

The 6 `Mode Validation Warning` lines on the eDP are present **identically** on
the boot *before* the firmware trim, so nothing here introduced them.

### What is left, and what is not tunable

- **firmware, 4.6 s** — HP POST: SEC/PEI (memory training, EC handshake, PSP/SMU,
hardware GPU bring-up) then DXE enumeration and the boot manager. Already at its
floor, checked against the live `Setup` store: POST Hotkey Delay (`Timeout`) = 0,
PXE ROM (off 218) = 0, CDROM (227) = 0, floppy (228) = 0, network boot (230) = 0,
Secure Boot (233) = 0 — and this firmware's IFR has **no Fast Boot option** at
all. Nothing left to turn off from the OS.
- **loader, 1.5 s** — reading 45 MiB (17 kernel + 26 initramfs) off the vfat ESP at
~30 MB/s. That is the firmware's own EFI file I/O, not the OS; the only lever is a
smaller image.
- **initrd, 5.0 s / userspace, 4.2 s** — the remaining OS-side time.
`graphical.target` is now gated by `multi-user.target`'s wants (`wpa_supplicant`
@3.75 s, `plymouth-quit` now 14 ms), not by anything expensive.
- One POST-side surface was **not** touched: the PBS "power of <device>" rails for
devices this machine does not have (`ODD power`, `WWAN`, `EVAL Slot`, `HDD` — all
1). Speculative gain, and it needs firmware writes plus reboots to test.

## Tooling gotcha

`limine-mkinitcpio --help` and `limine-snapper-sync --help` **execute** instead
of printing help. Read the scripts under `/usr/share/libalpm/scripts/` instead.
