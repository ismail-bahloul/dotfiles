#!/bin/bash
# =============================================================================
# run_once_04-power-profile.sh
# Run once by chezmoi (re-runs if this file changes)
# Install power-profile service + udev rule (RyzenAdj + NVIDIA + CPU governor)
# =============================================================================
set -e

# Logging helpers: .lib_logging.sh ships in the chezmoi source dir and is always
# present when run_once scripts run under chezmoi, so no fallback is needed.
source "${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}/.lib_logging.sh"

SCRIPT_DIR="${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}"

log_info "Installing power-profile..."

# Disable power-profiles-daemon if present (conflicts with our setup)
if [ -f /usr/lib/systemd/system/power-profiles-daemon.service ]; then
  log_info "power-profiles-daemon detected, masking it..."
  sudo systemctl mask --now power-profiles-daemon.service 2>/dev/null || true
fi

# Single source of truth for power-profile: ~/.local/bin/power-profile
# (chezmoi-managed) is canonical. /usr/local/bin is a symlink to it, so the
# systemd service and `sudo` (which use secure_path incl. /usr/local/bin)
# always resolve to the same file as an interactive `power-profile`.
PROFILE_TARGET="$HOME/.local/bin/power-profile"
mkdir -p "$HOME/.local/bin"
if [ ! -f "$PROFILE_TARGET" ]; then
  # Bootstrap fallback if chezmoi hasn't deployed the file yet.
  cp "$SCRIPT_DIR/dot_local/bin/executable_power-profile" "$PROFILE_TARGET"
fi
chmod +x "$PROFILE_TARGET"
sudo ln -sf "$PROFILE_TARGET" /usr/local/bin/power-profile

# Remove old service/udev if they exist (from ryzenadj-profile rename)
sudo rm -f /etc/systemd/system/ryzenadj-profile.service /etc/systemd/system/ryzenadj.service /etc/systemd/system/ryzenadj.timer /etc/udev/rules.d/99-ryzenadj-profile.rules
sudo systemctl daemon-reload 2>/dev/null

# Write systemd service (starts at boot, triggered by udev on AC plug/unplug)
# NB 1: ExecStart uses `guard`, not `auto`. `guard` behaves like `auto` except
#   that it refuses to re-apply while the `performance` governor is active, so a
#   manually selected PERF mode is never clobbered by the periodic timer.
# NB 2: no RemainAfterExit. The periodic timer uses OnUnitActiveSec, which is
#   relative to the last *activation*. With RemainAfterExit=yes the unit stays
#   active forever, never re-activates, and the timer's next elapse resolves to
#   "infinity" after a single run (the periodic re-apply silently dies).
sudo tee /etc/systemd/system/power-profile.service > /dev/null << 'EOF'
[Unit]
Description=Power profile - AC/battery CPU/GPU power & temp limits

[Service]
Type=oneshot
ExecStart=/usr/local/bin/power-profile guard
Nice=-5

[Install]
WantedBy=multi-user.target
EOF

# Write timer: periodic re-apply (workaround for EC/firmware overriding limits)
sudo tee /etc/systemd/system/power-profile.timer > /dev/null << 'EOF'
[Unit]
Description=Power profile - periodic re-apply (EC override workaround)

[Timer]
OnBootSec=1min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOF

# Write udev rule for AC plug/unplug.
# NB: uses `guard`, not `auto`: `auto` always re-applies and would silently drop
# a manually selected PERF mode (4.4 GHz, GPU unlocked) on every AC transition.
# `guard` behaves like `auto` except that it refuses to re-apply while the
# `performance` governor is active - same rationale as the systemd service below.
sudo tee /etc/udev/rules.d/99-power-profile.rules > /dev/null << 'EOF'
ACTION=="change", SUBSYSTEM=="power_supply", KERNEL=="ACAD", ATTR{online}=="1", RUN+="/usr/bin/systemd-run --no-block /usr/local/bin/power-profile guard"
ACTION=="change", SUBSYSTEM=="power_supply", KERNEL=="ACAD", ATTR{online}=="0", RUN+="/usr/bin/systemd-run --no-block /usr/local/bin/power-profile guard"
EOF

# Set swappiness (lower = avoid disk swap, good for NVMe)
# Note: skipped if zram is active (zram prefers higher swappiness)
if ! lsblk | grep -q zram; then
  echo 'vm.swappiness=10' | sudo tee /etc/sysctl.d/99-swappiness.conf > /dev/null
  sudo sysctl -w vm.swappiness=10 > /dev/null
fi

# Enable and (re)start. `enable --now` alone is not enough on a re-run: it does
# not restart an already-active timer, so a changed schedule would never be
# picked up. Restart both unconditionally.
sudo systemctl daemon-reload
sudo systemctl enable power-profile.service power-profile.timer
sudo systemctl restart power-profile.service
sudo systemctl restart power-profile.timer

# Enable NVIDIA services (suspend/resume only)
sudo systemctl enable nvidia-suspend.service nvidia-resume.service 2>/dev/null || true

# Reload udev rules
sudo udevadm control --reload-rules

log_pass "Power profile setup complete."
