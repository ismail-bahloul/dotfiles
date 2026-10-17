#!/bin/bash
# =============================================================================
# run_once_12-remove-nbfc.sh
# One-time migration: remove the nbfc-linux/nbfc-qt install built by the old
# run_once_03-nbfc.sh. omenctl now owns the fans; the EC's own curve (255) is
# the fallback. The guard (the fork marker) means a pacman-managed nbfc is
# never touched.
# =============================================================================
set -e

# Logging helpers: .lib_logging.sh ships in the chezmoi source dir and is always
# present when run_once scripts run under chezmoi, so no fallback is needed.
source "${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}/.lib_logging.sh"

MARKER=/usr/local/share/nbfc-linux-fork.rev

if [ ! -f "$MARKER" ]; then
  log_skip "no nbfc-linux fork install found (nothing to remove)"
  exit 0
fi

log_info "Removing the legacy nbfc install..."

# Stop it if it is somehow running; omenctl.service Conflicts= would have
# stopped it, but this migration can run on an older system.
sudo systemctl disable --now nbfc_service.service 2>/dev/null || true

# Files installed by the fork's `make install` (both the /usr and an older
# /usr/local layout are cleaned; the wildcard-free list keeps this predictable).
sudo rm -f \
  /usr/lib/systemd/system/nbfc_service.service \
  /usr/local/lib/systemd/system/nbfc_service.service \
  /usr/bin/nbfc /usr/bin/nbfc_service /usr/bin/nbfc-qt /usr/bin/nbfc-qt-tray \
  /usr/share/applications/nbfc-qt.desktop /usr/share/applications/nbfc-qt-tray.desktop \
  /usr/share/bash-completion/completions/nbfc /usr/share/bash-completion/completions/nbfc_service \
  /usr/share/fish/vendor_completions.d/nbfc.fish /usr/share/fish/vendor_completions.d/nbfc_service.fish \
  /usr/share/zsh/site-functions/_nbfc /usr/share/zsh/site-functions/_nbfc_service \
  /usr/local/share/bash-completion/completions/nbfc /usr/local/share/bash-completion/completions/nbfc_service \
  /usr/local/share/fish/vendor_completions.d/nbfc.fish /usr/local/share/fish/vendor_completions.d/nbfc_service.fish \
  /usr/local/share/zsh/site-functions/_nbfc /usr/local/share/zsh/site-functions/_nbfc_service \
  /usr/share/man/man1/nbfc.1 /usr/share/man/man1/nbfc_service.1 \
  /usr/share/man/man5/nbfc_service.json.5 \
  /usr/local/man/man1/nbfc.1 /usr/local/man/man1/nbfc_service.1 \
  /usr/local/man/man5/nbfc_service.json.5 \
  /usr/local/share/nbfc-linux-fork.rev

sudo rm -rf /etc/nbfc /usr/local/etc/nbfc /usr/share/nbfc /usr/local/share/nbfc
sudo find /usr/share/icons /usr/local/share/icons /usr/share/pixmaps -iname '*nbfc*' -delete 2>/dev/null || true

# The old run_once_03 added these to IgnorePkg. Drop the line if only nbfc
# remains; otherwise strip the two tokens and keep the other packages.
if grep -qE '^IgnorePkg[[:space:]]*=.*nbfc-(linux|qt)' /etc/pacman.conf; then
  CLEAN=$(sed -n 's/^IgnorePkg[[:space:]]*=[[:space:]]*//p' /etc/pacman.conf | head -1 \
    | sed -E 's/[[:space:]]*nbfc-(linux|qt)//g' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')
  if [ -z "$CLEAN" ]; then
    sudo sed -i -E '/^IgnorePkg[[:space:]]*=[[:space:]]*.*nbfc-(linux|qt)/d' /etc/pacman.conf
    log_detail "removed the nbfc entries from IgnorePkg"
  else
    sudo sed -i -E "s|^IgnorePkg[[:space:]]*=.*|IgnorePkg = $CLEAN|" /etc/pacman.conf
    log_detail "kept other IgnorePkg entries: $CLEAN"
  fi
fi

sudo systemctl daemon-reload
log_pass "nbfc removed; omenctl owns the fans."
