#!/bin/bash
# =============================================================================
# bootstrap.sh — the userspace entry point (any Linux distribution)
#
#   curl -fsSL https://ismailbahloul.com/d | bash
#
# Clones or updates this repository, installs chezmoi if needed, and applies it:
# ~/.zshrc, ~/.config/{kitty,gh}, ~/.gitconfig and ~/.local/bin/deploy-plugins.
# No root beyond the chezmoi package, no system file, no package list, no
# hardware.
#
# The machine layer — drivers, KDE, VFIO, audio, initramfs, udev — is a
# different repository and a different entry point: https://ismailbahloul.com/m
#
# Arguments: --dry-run (plan only), --force (overwrite existing configs).
#
# Re-running is safe and idempotent: this entry point and the machine layer's
# install.sh apply the same clone, so on a provisioned host it converges to the
# same files instead of creating a second copy.
#
# Deliberately self-contained: this file is piped before anything is cloned, so
# it cannot source a library.
# =============================================================================
set -euo pipefail

REPO="${DOTFILES_REPO:-https://github.com/ismail-bahloul/dotfiles.git}"
SELF_DIR=$(cd "$(dirname "$0")" && pwd)
if [ -z "${DOTFILES_DIR:-}" ] && [ -d "$SELF_DIR/.git" ] && [ -f "$SELF_DIR/dot_zshrc" ]; then
  DIR="$SELF_DIR"
else
  DIR="${DOTFILES_DIR:-$HOME/.local/share/dotfiles-portable}"
fi

DRY_RUN=false
FORCE=false

usage() {
  cat <<'USAGE'
usage: bootstrap.sh [--dry-run] [--force]

  --dry-run  show the plan, change nothing
  --force    overwrite configs that already exist
USAGE
}

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --force)   FORCE=true ;;
    -h | --help) usage; exit 0 ;;
    *)
      echo "bootstrap: unknown argument: $arg" >&2
      usage >&2
      exit 1
      ;;
  esac
done

say() { printf '%s\n' "$*"; }

# Run a command as root, unless already root (containers, CI).
as_root() {
  if [ "$(id -u)" -eq 0 ]; then "$@"; else sudo "$@"; fi
}

# --- Is the machine layer installed here? ------------------------------------
# Only used for the closing hint. Both entry points apply the same clone, so
# running this one on a provisioned host is idempotent, not a second copy.
provisioned=false
if [ -f "$HOME/.local/share/chezmoi/packages.d/base.pacman" ] ||
   [ -f /etc/udev/rules.d/99-omenctl.rules ]; then
  provisioned=true
fi

# --- Dependencies ------------------------------------------------------------
missing=()
command -v git >/dev/null 2>&1 || missing+=("git")
command -v chezmoi >/dev/null 2>&1 || missing+=("chezmoi")

if [ "$DRY_RUN" = true ]; then
  say "bootstrap: dry run — nothing will be changed"
  say "  repo:    $REPO"
  say "  clone:   $DIR"
  say "  missing: ${missing[*]:-none}"
  exit 0
fi

install_pkg() {
  if command -v pacman >/dev/null 2>&1; then
    as_root pacman -S --needed --noconfirm "$1"
  elif command -v apt-get >/dev/null 2>&1; then
    as_root apt-get update -qq && as_root apt-get install -y "$1"
  elif command -v dnf >/dev/null 2>&1; then
    as_root dnf install -y "$1"
  elif command -v zypper >/dev/null 2>&1; then
    as_root zypper --non-interactive install "$1"
  elif command -v apk >/dev/null 2>&1; then
    as_root apk add "$1"
  else
    return 1
  fi
}

if [ "${#missing[@]}" -gt 0 ]; then
  say "bootstrap: installing ${missing[*]}..."
  for pkg in "${missing[@]}"; do
    install_pkg "$pkg" || {
      echo "bootstrap: cannot install '$pkg' automatically — install it, then re-run." >&2
      exit 1
    }
  done
fi
command -v chezmoi >/dev/null 2>&1 ||
  { echo "bootstrap: chezmoi is still missing after install." >&2; exit 1; }

# --- Clone or update ---------------------------------------------------------
# The machine layer pins this same directory at a tag, so the checkout can be a
# detached HEAD with no upstream: pull when there is one, otherwise fetch the
# default branch and move to its tip.
if [ -d "$DIR/.git" ]; then
  if git -C "$DIR" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    git -C "$DIR" pull --ff-only
  else
    git -C "$DIR" fetch --quiet --depth 1 origin HEAD
    git -C "$DIR" checkout --quiet --force FETCH_HEAD
  fi
else
  git clone "$REPO" "$DIR"
fi

# --- Pre-flight: do not silently overwrite somebody's configs ----------------
# `chezmoi status` marks an existing, differing target with " M". Only those
# entries mean a file already on this machine would be replaced; on a fresh
# account there are none, so the canonical `curl | bash` still applies without
# asking — and it has to, since stdin is the script itself, not a TTY.
drift=$(chezmoi --source "$DIR" status 2>/dev/null || true)
clobber=$(printf '%s\n' "$drift" | grep -E '^ M' || true)
if [ -n "$clobber" ] && [ "$FORCE" = false ]; then
  cat >&2 <<'MSG'
bootstrap: these files already exist and would be overwritten:

MSG
  printf '%s\n' "$clobber" | sed 's/^ M /      /' >&2
  cat >&2 <<MSG

  Nothing has been changed. Re-run with --force to replace them, or preview
  the difference first:

      chezmoi --source $DIR diff
MSG
  exit 1
fi

# --- Apply -------------------------------------------------------------------
chezmoi --source "$DIR" apply

pending=$(chezmoi --source "$DIR" status 2>/dev/null || true)
if [ -n "$pending" ]; then
  echo "bootstrap: the apply did not converge, still pending:" >&2
  printf '%s\n' "$pending" | sed 's/^/  /' >&2
  exit 1
fi
say "bootstrap: portable dotfiles applied (open a new shell to pick up .zshrc)"

if [ "$provisioned" = true ]; then
  cat <<'MSG'

This host also has the machine layer. To update both layers together:

    ~/dotfiles/install.sh
MSG
elif command -v pacman >/dev/null 2>&1; then
  cat <<'MSG'

This is the userspace layer only. For the full machine (drivers, KDE, VFIO,
audio, initramfs, udev) on CachyOS/Arch:

    curl -fsSL https://ismailbahloul.com/m | bash
MSG
fi
