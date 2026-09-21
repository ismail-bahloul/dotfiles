#!/bin/bash
# =============================================================================
# run_once_11-boot-tuning.sh
# Run once by chezmoi (re-runs if this file changes)
# Boot-time tuning for the HP OMEN 15-en1xxx (CachyOS + Limine)
# Idempotent: safe to re-run; mkinitcpio only runs if something actually changed
#
# Tuning steps, all measured on this machine (see README, "Boot tuning"):
#   1. drop nouveau + its per-chipset NVIDIA firmware from the initramfs
#      (the `kms` hook pulls in ~140 MiB of unused GSP firmware)
#   2. keep the NVIDIA kernel modules out of the initramfs: they cost ~33 MiB,
#      ~2.9 s of initrd load time and an NVRM assertion, and the internal panel
#      is driven by amdgpu. `chwd` re-adds them on hardware detection, so this
#      script re-patches its generated file on every run.
#   3. force amdgpu into the initramfs MODULES for early KMS: without it the
#      iGPU is only bound by udev coldplug ~2.3 s after switch-root, stalling
#      Plymouth and anything else that needs a DRM node.
#   4. cap the number of Limine snapshot entries: with the default ("auto") each
#      kernel update adds ~5 entries to the 4 GiB ESP until it fills up and
#      kernel updates start failing.
#   5. mask systemd-binfmt.service: it drags in proc-sys-fs-binfmt_misc.mount at
#      every boot (~1 s) for nothing; the automount mounts it on first use.
# =============================================================================
set -e

# Logging helpers: .lib_logging.sh ships in the chezmoi source dir and is always
# present when run_once scripts run under chezmoi, so no fallback is needed.
source "${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}/.lib_logging.sh"

SCRIPT_DIR="${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}"

log_info "Applying boot-time tuning..."

NEEDS_MKINITCPIO=false

# ---------------------------------------------------------------------------
# 1. nouveau-removal mkinitcpio hook
# ---------------------------------------------------------------------------
HOOK_SRC="$SCRIPT_DIR/etc/initcpio/install/no-nouveau"
HOOK_DST="/etc/initcpio/install/no-nouveau"

if [ ! -f "$HOOK_SRC" ]; then
  log_warn "hook source not found ($HOOK_SRC), skipping"
elif [ -f "$HOOK_DST" ] && cmp -s "$HOOK_SRC" "$HOOK_DST"; then
  log_skip "no-nouveau hook already installed"
else
  sudo mkdir -p "$(dirname "$HOOK_DST")"
  sudo install -m 755 "$HOOK_SRC" "$HOOK_DST"
  log_detail "installed $HOOK_DST"
fi

# ---------------------------------------------------------------------------
# 2. hook registration (must come after the `kms` hook)
# ---------------------------------------------------------------------------
CONF_SRC="$SCRIPT_DIR/etc/mkinitcpio.conf.d/20-no-nouveau.conf"
CONF_DST="/etc/mkinitcpio.conf.d/20-no-nouveau.conf"

if [ ! -f "$CONF_SRC" ]; then
  log_warn "hook config not found ($CONF_SRC), skipping"
elif [ -f "$CONF_DST" ] && cmp -s "$CONF_SRC" "$CONF_DST"; then
  log_skip "no-nouveau hook already registered"
else
  sudo mkdir -p "$(dirname "$CONF_DST")"
  sudo install -m 644 "$CONF_SRC" "$CONF_DST"
  log_detail "installed $CONF_DST"
  NEEDS_MKINITCPIO=true
fi

# ---------------------------------------------------------------------------
# 3. force early KMS for the iGPU (amdgpu) in the initramfs
# ---------------------------------------------------------------------------
AMDGPU_SRC="$SCRIPT_DIR/etc/mkinitcpio.conf.d/30-amdgpu-early.conf"
AMDGPU_DST="/etc/mkinitcpio.conf.d/30-amdgpu-early.conf"

if [ ! -f "$AMDGPU_SRC" ]; then
  log_warn "early-KMS drop-in not found ($AMDGPU_SRC), skipping"
elif [ -f "$AMDGPU_DST" ] && cmp -s "$AMDGPU_SRC" "$AMDGPU_DST"; then
  log_skip "amdgpu early KMS already configured"
else
  sudo mkdir -p "$(dirname "$AMDGPU_DST")"
  sudo install -m 644 "$AMDGPU_SRC" "$AMDGPU_DST"
  log_detail "installed $AMDGPU_DST"
  NEEDS_MKINITCPIO=true
fi

# ---------------------------------------------------------------------------
# 4. keep the NVIDIA modules out of the initramfs (chwd regenerates the file)
# ---------------------------------------------------------------------------
CHWD_CONF="/etc/mkinitcpio.conf.d/10-chwd.conf"
if [ -f "$CHWD_CONF" ] && sudo grep -qE '^[[:space:]]*MODULES\+=\(.*nvidia' "$CHWD_CONF"; then
  sudo sed -i -E 's|^([[:space:]]*)(MODULES\+=\(.*nvidia.*\))|\1# \2|' "$CHWD_CONF"
  log_warn "chwd had put the NVIDIA modules back in the initramfs - commented out again"
  NEEDS_MKINITCPIO=true
else
  log_skip "NVIDIA modules already excluded from the initramfs"
fi

# ---------------------------------------------------------------------------
# 5. cap Limine snapshot entries (ESP usage)
# ---------------------------------------------------------------------------
SNAPPER_CONF="/etc/limine-snapper-sync.conf"
SNAPSHOT_MAX=8

if [ ! -f "$SNAPPER_CONF" ]; then
  log_skip "limine-snapper-sync not installed"
elif grep -qE "^MAX_SNAPSHOT_ENTRIES=${SNAPSHOT_MAX}\$" "$SNAPPER_CONF"; then
  log_skip "MAX_SNAPSHOT_ENTRIES already ${SNAPSHOT_MAX}"
elif grep -qE '^MAX_SNAPSHOT_ENTRIES=' "$SNAPPER_CONF"; then
  sudo sed -i -E "s|^MAX_SNAPSHOT_ENTRIES=.*|MAX_SNAPSHOT_ENTRIES=${SNAPSHOT_MAX}|" "$SNAPPER_CONF"
  log_detail "MAX_SNAPSHOT_ENTRIES set to ${SNAPSHOT_MAX}"
else
  printf '\n### Keep the 4 GiB ESP from filling up (see dotfiles README).\nMAX_SNAPSHOT_ENTRIES=%s\n' "$SNAPSHOT_MAX" | sudo tee -a "$SNAPPER_CONF" > /dev/null
  log_detail "MAX_SNAPSHOT_ENTRIES=${SNAPSHOT_MAX} appended"
fi

# ---------------------------------------------------------------------------
# 6. mask systemd-binfmt (register lazily via the automount instead)
# ---------------------------------------------------------------------------
# systemd-binfmt.service runs at every boot and pulls in
# proc-sys-fs-binfmt_misc.mount (~1 s on the critical chain) even when no
# binfmt.d entry exists. Masking it leaves the automount in place, so the
# registry is mounted on first actual use (e.g. qemu-user) instead of at boot.
if [ "$(systemctl is-enabled systemd-binfmt.service 2>/dev/null)" = "masked" ]; then
  log_skip "systemd-binfmt already masked"
elif sudo systemctl mask systemd-binfmt.service; then
  log_detail "masked systemd-binfmt.service (automount handles on-demand)"
else
  log_warn "could not mask systemd-binfmt.service"
fi

# ---------------------------------------------------------------------------
# 7. Regenerate the initramfs (only if something changed)
# ---------------------------------------------------------------------------
if $NEEDS_MKINITCPIO; then
  log_info "Regenerating initramfs..."
  yes | sudo mkinitcpio -P 2>&1
else
  log_skip "Initramfs unchanged, skipping mkinitcpio"
fi

log_pass "Boot tuning complete."
