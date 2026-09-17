#!/bin/bash
# =============================================================================
# run_once_06-libvirt-setup.sh
# Run once by chezmoi (re-runs if this file changes)
# Post-install configuration for libvirt / QEMU
# =============================================================================
set -e

# Logging helpers: .lib_logging.sh ships in the chezmoi source dir and is always
# present when run_once scripts run under chezmoi, so no fallback is needed.
source "${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}/.lib_logging.sh"

log_info "Enabling libvirt services..."

# Socket activation: daemons start on first access (no always-on processes).
#
# Order matters. Each virt<drv>d.service lists `Also=virt<drv>d.socket` in its
# [Install] section, so `systemctl disable` on the *service* also strips the
# socket's enablement. Disabling the service after enabling the socket - as this
# loop used to do - therefore left every socket disabled, and libvirt was dead
# after a reboot while `systemctl start` had made it look fine in the session.
# Disable the service first, then enable the socket.
for drv in qemu interface network nodedev nwfilter secret storage; do
  sudo systemctl disable "virt${drv}d.service" 2>/dev/null || true
  sudo systemctl stop  "virt${drv}d.service" 2>/dev/null || true
  sudo systemctl enable "virt${drv}d.socket"
  sudo systemctl start  "virt${drv}d.socket"
done

# These come in transitively through `Also=` on virtqemud.service, which the loop
# above disables, so enable them explicitly.
for s in virtlogd.socket virtlockd.socket; do
  sudo systemctl enable "$s" 2>/dev/null || true
  sudo systemctl start  "$s" 2>/dev/null || true
done

log_info "Adding user to libvirt and kvm groups..."
sudo usermod -aG libvirt,kvm "$USER"

log_info "Setting default network to autostart..."
sudo virsh net-autostart default 2>/dev/null || true
sudo virsh net-start default 2>/dev/null || true

log_pass "libvirt setup complete."
