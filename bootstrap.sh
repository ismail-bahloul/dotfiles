#!/bin/bash
# =============================================================================
# bootstrap.sh — the one-command entry point
#
#   curl -fsSL https://ismailbahloul.com/d | bash
#
# ismailbahloul.com/d is a redirect to this file, so what runs is exactly the
# versioned script in this repo — drop the `| bash` to read it first.
#
# This file stays deliberately tiny: it clones or updates the repo, then hands
# over to install.sh, which owns every prerequisite and the apply. Extra
# arguments are forwarded, so `… | bash -s -- --validate` works.
# =============================================================================
set -euo pipefail

REPO="${DOTFILES_REPO:-https://github.com/ismail-bahloul/dotfiles.git}"
DIR="${DOTFILES_DIR:-$HOME/dotfiles}"

# git is the one thing this file needs and cannot install itself through
# install.sh: on a bare Arch minimal install it is simply absent.
if ! command -v git >/dev/null 2>&1; then
  echo "bootstrap: git is not installed — installing it..." >&2
  if command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm git
  else
    echo "bootstrap: install git first, then re-run." >&2
    exit 1
  fi
fi

# Re-runnable: update the clone if it is already there (a dirty tree makes
# --ff-only fail loudly instead of silently rewriting something).
if [ -d "$DIR/.git" ]; then
  git -C "$DIR" pull --ff-only
else
  git clone "$REPO" "$DIR"
fi

exec "$DIR/install.sh" "$@"
