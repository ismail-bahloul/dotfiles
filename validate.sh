#!/bin/bash
# validate.sh — check that all dotfiles components are correctly deployed
set -e

# ─── Locate repo + load logging library from the local clone ─────────────────
REPO_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
if [ -f "$REPO_SCRIPT_DIR/.lib_logging.sh" ]; then
  # shellcheck source=.lib_logging.sh
  source "$REPO_SCRIPT_DIR/.lib_logging.sh"
else
  # Fallback: minimal logging
  log_init() { :; }
  log_section() { echo ""; echo "─── $1 ───"; }
  log_pass() { echo "  ✔ $1"; }
  log_fail() { echo "  ✘ $1"; }
  log_fatal() { echo "  ✘ $1"; exit 1; }
  log_warn() { echo "  ⚠ $1"; }
  log_info() { echo "  → $1"; }
  log_skip() { echo "  ⋯ $1"; }
  log_detail() { echo "    • $1"; }
  log_cmd() { echo "  $ $1"; }
  log_summary() { :; }
fi

log_init
SCRIPT_DIR="${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}"

# ─── Scripts in PATH ────────────────────────────────────────────────────────
log_section "Scripts"

for s in limine-boot-win limine-boot-vfio limine-boot-linux backup-data power-profile; do
  if command -v "$s" &>/dev/null || [ -f "$HOME/.local/bin/$s" ]; then
    log_pass "$s"
  else
    log_fail "$s not found"
  fi
done

# ─── Packages ───────────────────────────────────────────────────────────────
log_section "Packages"

if [ -f "$SCRIPT_DIR/packages.pacman" ]; then
  MISSING=0
  while IFS= read -r pkg; do
    [ -z "$pkg" ] && continue
    if ! pacman -Q "$pkg" &>/dev/null; then log_fail "$pkg (pacman)"; MISSING=1; fi
  done < <(grep -v '^\s*#' "$SCRIPT_DIR/packages.pacman" | awk '{print $1}')
  if [ "$MISSING" -eq 0 ]; then log_pass "All pacman packages installed"; fi
fi
if [ -f "$SCRIPT_DIR/packages.aur" ]; then
  MISSING_AUR=0
  while IFS= read -r pkg; do
    [ -z "$pkg" ] && continue
    if ! pacman -Q "$pkg" &>/dev/null; then log_fail "$pkg (AUR)"; MISSING_AUR=1; fi
  done < <(grep -v '^\s*#' "$SCRIPT_DIR/packages.aur" | awk '{print $1}')
  if [ "$MISSING_AUR" -eq 0 ]; then log_pass "All AUR packages installed"; fi
fi

# ─── Services ───────────────────────────────────────────────────────────────
log_section "Services"

# power-profile.service is a oneshot: once it has run it is inactive by design,
# so check that it is enabled and that its periodic re-apply timer is running.
if systemctl is-enabled power-profile.service &>/dev/null; then
  log_pass "power-profile.service enabled"
else
  log_fail "power-profile.service not enabled"
fi
if systemctl is-active power-profile.timer &>/dev/null; then
  log_pass "power-profile.timer active"
else
  log_fail "power-profile.timer not active"
fi
if systemctl is-active nbfc_service.service &>/dev/null; then
  log_pass "nbfc_service.service active"
else
  log_warn "nbfc_service.service not active (may need hardware)"
fi
for svc in nvidia-powerd.service nvidia-suspend.service nvidia-resume.service; do
  if systemctl is-enabled "$svc" &>/dev/null; then
    log_pass "$svc enabled"
  else
    log_pass "$svc skipped (no NVIDIA)"
  fi
done
for svc in virtqemud.socket virtnetworkd.socket; do
  if systemctl is-active "$svc" &>/dev/null; then
    log_pass "$svc active"
  else
    log_fail "$svc not active"
  fi
done

# ─── Udev ───────────────────────────────────────────────────────────────────
log_section "Udev"

if [ -f /etc/udev/rules.d/99-power-profile.rules ]; then
  log_pass "Power-profile udev rule"
else
  log_fail "Power-profile udev rule missing"
fi

# ─── VFIO ───────────────────────────────────────────────────────────────────
log_section "VFIO"

if grep -q "vfio" /etc/mkinitcpio.conf 2>/dev/null; then
  log_pass "VFIO modules in mkinitcpio"
else
  log_fail "VFIO modules missing"
fi
if [ ! -f /etc/cmdline.d/vfio.conf ]; then
  log_pass "VFIO cmdline via Limine entry (no /etc/cmdline.d)"
else
  log_fail "Stale /etc/cmdline.d/vfio.conf present - ids should live in the Limine VFIO entry only"
fi

# ─── Power profile ──────────────────────────────────────────────────────────
log_section "Power profile"

if command -v power-profile &>/dev/null; then
  log_pass "Power-profile installed"
  GOV=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)
  if [ -n "$GOV" ]; then
    log_pass "CPU governor: $GOV"
  else
    log_fail "CPU governor unknown"
  fi
else
  log_fail "Power-profile not installed"
fi

# ─── Boot tuning ────────────────────────────────────────────────────────────
log_section "Boot tuning"

if [ -f /etc/initcpio/install/no-nouveau ]; then
  log_pass "no-nouveau hook installed"
else
  log_fail "no-nouveau hook missing"
fi
if [ -f /etc/mkinitcpio.conf.d/20-no-nouveau.conf ]; then
  log_pass "no-nouveau hook registered"
else
  log_fail "no-nouveau hook not registered"
fi
if grep -qE '^[[:space:]]*MODULES\+=\(.*nvidia' /etc/mkinitcpio.conf.d/10-chwd.conf 2>/dev/null; then
  log_fail "NVIDIA modules are back in the initramfs (chwd regenerated its config)"
else
  log_pass "NVIDIA modules excluded from the initramfs"
fi
if grep -qE '^[[:space:]]*MODULES\+=.*amdgpu' /etc/mkinitcpio.conf.d/30-amdgpu-early.conf 2>/dev/null; then
  log_pass "amdgpu early KMS configured"
else
  log_fail "amdgpu early KMS drop-in missing (/etc/mkinitcpio.conf.d/30-amdgpu-early.conf)"
fi
if [ "$(systemctl is-enabled systemd-binfmt.service 2>/dev/null)" = "masked" ]; then
  log_pass "systemd-binfmt masked (on-demand automount)"
else
  log_warn "systemd-binfmt not masked"
fi
SNAP_MAX=$(grep -E '^MAX_SNAPSHOT_ENTRIES=' /etc/limine-snapper-sync.conf 2>/dev/null | cut -d= -f2)
if [ "$SNAP_MAX" = "8" ]; then
  log_pass "MAX_SNAPSHOT_ENTRIES=8"
else
  log_warn "MAX_SNAPSHOT_ENTRIES=${SNAP_MAX:-unset} (expected 8)"
fi

# ─── Sysctl ─────────────────────────────────────────────────────────────────
log_section "Sysctl"

if lsblk | grep -q zram; then
  log_pass "Zram active (swappiness handled by kernel)"
else
  SWAP=$(cat /proc/sys/vm/swappiness 2>/dev/null)
  if [ "$SWAP" = "10" ]; then
    log_pass "Swappiness=10"
  else
    log_fail "Swappiness=$SWAP (expected 10)"
  fi
fi

# ─── Looking Glass ──────────────────────────────────────────────────────────
log_section "Looking Glass"

LG=/dev/shm/looking-glass
if [ -f "$LG" ]; then
  SIZE=$(du -h "$LG" | awk '{print $1}')
  log_pass "Shared memory ($SIZE)"
else
  log_fail "Shared memory not found"
fi
HP=$(cat /proc/sys/vm/nr_hugepages 2>/dev/null)
if [ "$HP" -ge 64 ] 2>/dev/null; then
  log_pass "Hugepages: $HP"
else
  log_fail "Hugepages: $HP (expected 64+)"
fi

# ─── KDE config ─────────────────────────────────────────────────────────────
log_section "KDE config"

for f in kglobalshortcutsrc kwinrc kwinrulesrc konsolerc dolphinrc; do
  if [ -f "$HOME/.config/$f" ]; then
    log_pass "$f"
  else
    log_fail "$f missing"
  fi
done

# ─── KDE widgets ────────────────────────────────────────────────────────────
log_section "KDE widgets"

if [ -d "$HOME/.local/share/plasma/plasmoids/org.kde.olib.thermalmonitor" ]; then
  log_pass "Thermal monitor widget"
else
  log_fail "Thermal monitor widget missing"
fi
if [ -d "$HOME/.local/share/plasma/plasmoids/com.github.mazen.salatprayertime" ]; then
  log_pass "Salat prayer widget"
else
  log_fail "Salat prayer widget missing"
fi

# ─── NBFC ───────────────────────────────────────────────────────────────────
log_section "NBFC"

if [ -f /usr/share/nbfc/configs/my-nbfc.json ]; then
  log_pass "Fan profile deployed"
else
  log_fail "Fan profile missing"
fi

# ─── ZSH ────────────────────────────────────────────────────────────────────
log_section "ZSH"

if grep -q "local/bin" "$HOME/.zshrc" 2>/dev/null; then
  log_pass "local/bin in PATH"
else
  log_fail "local/bin not in PATH"
fi

# ─── Secrets ────────────────────────────────────────────────────────────────
log_section "Secrets"

if [ -f "$HOME/.config/zsh/secrets" ]; then
  log_pass "Secrets file exists"
  PERMS=$(stat -c %a "$HOME/.config/zsh/secrets")
  if [ "$PERMS" = "600" ]; then
    log_pass "Secrets permissions 600"
  else
    log_fail "Secrets permissions $PERMS (should be 600)"
  fi
else
  log_pass "No secrets file (add one if needed)"
fi

# ─── Git ────────────────────────────────────────────────────────────────────
log_section "Git"

if cd "$SCRIPT_DIR" 2>/dev/null && git remote -v 2>/dev/null | grep -q "ismail-bahloul/dotfiles"; then
  log_pass "Dotfiles remote OK"
else
  log_fail "Dotfiles remote not found"
fi

# ─── Summary ────────────────────────────────────────────────────────────────
log_summary
exit "$LOG_ERR"
