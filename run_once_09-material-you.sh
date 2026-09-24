#!/bin/bash
# =============================================================================
# run_once_09-material-you.sh
# Run once by chezmoi (re-runs if this file changes)
# "Material You / follows-the-wallpaper" — module separate from the rest of the dotfiles.
#
# This module makes the desktop (kitty, btop, prompt) follow the wallpaper
# colors, relying on kde-material-you-colors (which regenerates on every
# wallpaper change).
#
# Deploys:
#   - dot_local/bin/kitty-material-you.py / btop-material-you.py / hook
#   - dot_config/kitty/kitty.conf        (includes theme-wallpaper.conf)
#   - dot_config/btop/btop.conf          (color_theme = materialyou)
#   - the _prompt_material block in ~/.zshrc  (already handled via dot_zshrc)
# Here we impose the daemon config (config.conf is rewritten by the daemon -> we
# do not version the file, we set the key only):
#   - on_change_hook              -> recolors kitty/btop
# =============================================================================
set -e

source "${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}/.lib_logging.sh"

MYC_CFG="$HOME/.config/kde-material-you-colors/config.conf"
HOOK="$HOME/.local/bin/kitty-material-you-hook.sh"

# --- 1) Enable the hook in kde-material-you-colors ---------------------------
if command -v kde-material-you-colors >/dev/null 2>&1; then
  if [ -f "$MYC_CFG" ]; then
    if grep -q "on_change_hook=$HOOK" "$MYC_CFG" 2>/dev/null; then
      log_skip "on_change_hook already configured"
    else
      sed -i "s|^on_change_hook=.*|on_change_hook=$HOOK|" "$MYC_CFG"
      log_pass "on_change_hook -> $HOOK"
    fi
  else
    log_warn "kde-material-you-colors config missing ($MYC_CFG) — create the folder"
    mkdir -p "$(dirname "$MYC_CFG")"
    printf '[CUSTOM]\non_change_hook=%s\n' "$HOOK" > "$MYC_CFG"
  fi

  # restart the daemon to pick up the hook
  kde-material-you-colors --stop >/dev/null 2>&1 || true
  sleep 1
  nohup /usr/bin/kde-material-you-colors >/dev/null 2>&1 &
  log_info "kde-material-you-colors daemon restarted"
else
  log_warn "kde-material-you-colors not installed — install via AUR"
fi

# --- 2) kitty: make sure the theme-wallpaper.conf include is present ----------
KC="$HOME/.config/kitty/kitty.conf"
if [ -f "$KC" ] && ! grep -q 'theme-wallpaper.conf' "$KC"; then
  printf '\ninclude theme-wallpaper.conf\n' >> "$KC"
  log_pass "include theme-wallpaper.conf added to kitty.conf"
else
  log_skip "kitty.conf already includes theme-wallpaper.conf"
fi

# --- 3) generate kitty + btop + prompt a first time --------------------------
log_info "Initial generation of kitty + btop + prompt..."
python3 "$HOME/.local/bin/kitty-material-you.py" || true
python3 "$HOME/.local/bin/btop-material-you.py" || true
python3 "$HOME/.local/bin/material-you-prompt.py" || true

log_pass "material-you module configured."
