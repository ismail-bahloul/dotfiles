#!/bin/bash
# =============================================================================
# run_once_05-vfio-setup.sh
# Run once by chezmoi (re-runs if this file changes)
# GPU passthrough (VFIO) — NVIDIA RTX 3070 Mobile
# Idempotent: safe to re-run, mkinitcpio only if config changed
# =============================================================================
set -e

# Logging helpers: .lib_logging.sh ships in the chezmoi source dir and is always
# present when run_once scripts run under chezmoi, so no fallback is needed.
source "${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}/.lib_logging.sh"

SCRIPT_DIR="${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}"

log_info "Configuring VFIO for GPU passthrough..."

NEEDS_MKINITCPIO=false

# ---------------------------------------------------------------------------
# 1. Ensure VFIO modules in mkinitcpio.conf
# ---------------------------------------------------------------------------
MKINITCPIO="/etc/mkinitcpio.conf"
if grep -q "vfio_pci" "$MKINITCPIO"; then
  log_detail "VFIO modules already present in mkinitcpio.conf"
else
  log_detail "Adding VFIO modules to mkinitcpio.conf..."
  sudo cp "$MKINITCPIO" "${MKINITCPIO}.bak"
  if grep -q "^MODULES=()" "$MKINITCPIO"; then
    sudo sed -i 's/^MODULES=()/MODULES=(vfio_pci vfio vfio_iommu_type1)/' "$MKINITCPIO"
  else
    sudo sed -i 's/^MODULES=(\(.*\))/MODULES=(\1 vfio_pci vfio vfio_iommu_type1)/' "$MKINITCPIO"
  fi
  NEEDS_MKINITCPIO=true
fi

# ---------------------------------------------------------------------------
# 2. Remove stale kernel cmdline snippet (ids are hardcoded in the Limine VFIO entry)
# ---------------------------------------------------------------------------
sudo rm -f /etc/cmdline.d/vfio.conf 2>/dev/null || true

# ---------------------------------------------------------------------------
# 3. Regenerate initramfs (only if something changed)
# ---------------------------------------------------------------------------
if $NEEDS_MKINITCPIO; then
  log_info "Regenerating initramfs..."
  yes | sudo mkinitcpio -P 2>&1
else
  log_skip "No changes to initramfs config, skipping mkinitcpio"
fi

log_pass "VFIO setup complete. Reboot required for changes to take effect."

# ---------------------------------------------------------------------------
# 4. Add VFIO kernel entry in Limine (if not already present)
# ---------------------------------------------------------------------------
LIMINE_CONF="/boot/limine.conf"
if sudo grep -qm1 'linux-cachyos-vfio' "$LIMINE_CONF" 2>/dev/null; then
  log_detail "VFIO Limine entry already exists"
else
  log_detail "Adding VFIO kernel entry to Limine..."

  # Check if helper script exists
  if [ -f "$SCRIPT_DIR/dot_local/bin/.add-vfio-entry" ]; then
    sudo /usr/bin/python3 "$SCRIPT_DIR/dot_local/bin/.add-vfio-entry" "$LIMINE_CONF"
    log_detail "VFIO Limine entry added"
  else
    log_warn ".add-vfio-entry helper not found, skipping Limine entry"
  fi
fi
