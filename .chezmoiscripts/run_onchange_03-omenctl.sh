#!/bin/bash
# =============================================================================
# run_onchange_03-omenctl.sh
# Run by chezmoi when this file changes. The pinned ref below is part of the
# content, so bumping it re-runs the install.
# Install/update omenctl — fans + power profiles for the HP OMEN 15-en1xxx.
#
# omenctl is developed in myomen15 and published as a standalone repo. Use a
# local checkout when one is present (the development loop), otherwise clone
# the standalone repo. Override either path with OMENCTL_SRC / OMENCTL_REPO.
#
# The standalone repo is PRIVATE: without credentials the clone is skipped with
# a warning (the rest of the dotfiles applies normally). Provide one of:
#   OMENCTL_SRC=/path/to/omenctl            local checkout (best on this laptop)
#   OMENCTL_REPO=git@github.com:…omenctl.git  SSH, with a key registered
#   gh auth login && gh auth setup-git      HTTPS credential helper
# =============================================================================
set -e

# Logging helpers: lib/logging.sh ships in the chezmoi source dir and is always
# present when scripts run under chezmoi, so no fallback is needed.
source "${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}/lib/logging.sh"

OMENCTL_REPO="${OMENCTL_REPO:-https://github.com/ismail-bahloul/omenctl.git}"
OMENCTL_LOCAL="${OMENCTL_SRC:-$HOME/DATA/05_Code/Projects/myomen15/omenctl}"
# Pinned release. Bump this line to publish a new version; run_onchange_ sees
# the changed content and re-runs this script.
OMENCTL_REF="${OMENCTL_REF:-v0.4.0}"
MARKER=/usr/local/share/omenctl.rev

WORKDIR=""
cleanup() { if [ -n "$WORKDIR" ]; then rm -rf "$WORKDIR"; fi; }
trap cleanup EXIT

if [ -f "$OMENCTL_LOCAL/omenctl.py" ]; then
  SRC="$OMENCTL_LOCAL"
  log_info "Using local omenctl checkout: $SRC"
else
  WORKDIR=$(mktemp -d)
  log_info "Cloning omenctl $OMENCTL_REF from $OMENCTL_REPO..."
  # The standalone repo is private. Never let git ask for a password: chezmoi
  # runs this non-interactively, where the prompt bypasses the redirection (it
  # goes to /dev/tty) and blocks or prints garbage. And do not abort the whole
  # apply on failure: omenctl drives this laptop's fans, nothing else in the
  # dotfiles depends on it, so a missing credential is a warning, not a break.
  if ! clone_err=$(GIT_TERMINAL_PROMPT=0 git clone --depth=1 --branch "$OMENCTL_REF" "$OMENCTL_REPO" "$WORKDIR/omenctl" 2>&1); then
    printf '%s\n' "$clone_err"
    log_warn "omenctl not updated: $OMENCTL_REPO is private and no credentials are available"
    log_detail "OMENCTL_SRC=/path/to/omenctl (local checkout) or OMENCTL_REPO=git@github.com:ismail-bahloul/omenctl.git"
    log_skip "skipping omenctl — the fans stay on the EC default curve"
    exit 0
  fi
  SRC="$WORKDIR/omenctl"
fi

NEW_HASH=$(cat "$SRC/omenctl.py" "$SRC/omenctl-run.sh" "$SRC/omenctl.service" | sha256sum | cut -d' ' -f1)
OLD_HASH=$(cat "$MARKER" 2>/dev/null || true)

if [ "$NEW_HASH" = "$OLD_HASH" ] && [ -x /usr/local/bin/omenctl ]; then
  log_skip "omenctl already up to date"
else
  sudo install -Dm755 "$SRC/omenctl.py" /usr/local/bin/omenctl
  sudo install -Dm755 "$SRC/omenctl-run.sh" /usr/local/bin/omenctl-run.sh
  sudo install -Dm644 "$SRC/omenctl.service" /etc/systemd/system/omenctl.service
  echo "$NEW_HASH" | sudo tee "$MARKER" > /dev/null
  sudo systemctl daemon-reload
  log_detail "installed /usr/local/bin/omenctl and /etc/systemd/system/omenctl.service"
fi

log_pass "omenctl installed."

# Stable absolute path for the desktop launcher (launchers do not use the
# user's PATH; the target is the chezmoi-deployed wrapper).
sudo ln -sf "$HOME/.local/bin/omenctl-tui" /usr/local/bin/omenctl-tui
