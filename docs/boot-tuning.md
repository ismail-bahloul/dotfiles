# Boot tuning

Measured with `systemd-analyze` on this machine (HP OMEN 15-en1xxx). Everything
below except the UEFI boot order lives under `/etc` and is applied by
`run_once_11-boot-tuning.sh`; the boot order is machine state (NVRAM), not
something a dotfiles repo can version.

| Phase | Value |
|---|---:|
| firmware | 9.20 s |
| loader | 1.25 s |
| kernel | 0.87 s |
| initrd | 6.46 s |
| userspace | 5.36 s |
| **total** | **23.13 s** |

For comparison, the run right before the UEFI boot order was fixed reported
`firmware 100.20 s + loader 1.34 s + kernel 0.88 s + initrd 6.49 s + userspace
5.32 s = 114.22 s`.

- **Dead UEFI boot entries removed, Limine kept early in `BootOrder`.** The
  firmware burned **~91 s** of POST on two entries that sat ahead of the real
  one: a `Limine` pointing at a GPT partition that no longer existed, and a
  "Windows Boot Manager" label pointing at a deleted
  `\EFI\cachyos\grubx64.efi`. Moving Limine ahead of them alone dropped firmware
  time from 100.20 s to 9.20 s; both entries were then deleted so they cannot be
  promoted back in front. The HP firmware re-promotes the USB entry to the front
  on its own — that one fails fast and is left in place. Check with `efibootmgr`,
  repair with `efibootmgr -o`.
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
  the initrd, plus an NVRM assertion. The internal panel is AMD/amdgpu and still
  gets early KMS from the `kms` hook; the dGPU is brought up later by udev.
  `chwd` regenerates that file and puts the modules back, so `run_once_11`
  re-comments the line on every run.
- **Limine snapshot entries capped at 8** (`MAX_SNAPSHOT_ENTRIES=8` in
  `/etc/limine-snapper-sync.conf`). The 4 GiB ESP is shared with the kernel
  images and each kernel update adds snapshot entries. With the default (`auto`)
  the ESP reached **85%**, at which point `limine-snapper-sync` silently stops
  adding entries and kernel updates start failing. Capped at 8 it sits near
  **14%**.

## Still on the table

The initrd phase (6.46 s) is now the largest. The journal shows a ~2.5 s gap
with no log lines right after `Finished Plymouth switch root service`, before
`amdgpu` initialises. Plymouth's `splash` is a plausible suspect — not
investigated, and worth at most ~2.5 s.

## Tooling gotcha

`limine-mkinitcpio --help` and `limine-snapper-sync --help` **execute** instead
of printing help. Read the scripts under `/usr/share/libalpm/scripts/` instead.

---

See also `firmware-limits.md` for the power/BIOS/EC picture.
