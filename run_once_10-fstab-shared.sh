#!/bin/bash
# =============================================================================
# run_once_10-fstab-shared.sh
# Run once by chezmoi (re-runs if this file changes)
#
# Mount the shared Windows partition "SHARED" (NTFS) AT BOOT via /etc/fstab.
# Without this, it is only mounted by hand (or by the desktop, via udisks).
#
# Choices:
#   - ntfs3 driver (kernel): faster than ntfs-3g (FUSE), and it is already what
#     udisks uses by default. ntfs-3g stays installed for its tools
#     (ntfsfix).
#   - nofail: if Windows is shut down with Fast Startup, the NTFS is "dirty" and the
#     mount fails -> without nofail, the boot would drop into emergency mode.
#   - umask=022: files 644 / folders 755 (instead of 777 by default).
#
# Idempotent: does nothing if the entry already exists.
# =============================================================================
set -e

source "${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}/.lib_logging.sh"

FSTAB="/etc/fstab"
MP="$HOME/SHARED"
PART_UUID="5CAC12755C11BA05"
OPTS="rw,uid=$(id -u),gid=$(id -g),iocharset=utf8,umask=022,windows_names,noatime,nofail,x-systemd.device-timeout=10"
LINE="UUID=$PART_UUID $MP ntfs3 $OPTS 0 0"

# --- 1) Mount point (user side) ----------------------------------------------
if [ -d "$MP" ]; then
  log_skip "mount point already present ($MP)"
else
  mkdir -p "$MP"
  log_pass "mount point created ($MP)"
fi

# --- 2) /etc/fstab entry (idempotent) ---------------------------------------
if grep -q "UUID=$PART_UUID" "$FSTAB"; then
  log_skip "fstab entry already present for $PART_UUID"
else
  sudo cp -a "$FSTAB" "$FSTAB.bak-$(date +%Y%m%d)"
  {
    echo ""
    echo "# Shared Windows partition (SHARED, NTFS) - mounted at boot"
    echo "# nofail: if Windows is in Fast Startup / NTFS \"dirty\", the mount"
    echo "# fails without blocking the boot."
    echo "$LINE"
  } | sudo tee -a "$FSTAB" > /dev/null
  log_pass "fstab entry added"
fi

# --- 3) Regenerate the systemd unit -----------------------------------------
sudo systemctl daemon-reload
log_info "systemd reloaded (unit home-...-SHARED.mount)"
log_pass "SHARED will be mounted at boot"
