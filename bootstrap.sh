#!/bin/bash
# =============================================================================
# bootstrap.sh — the userspace entry point (any Linux distribution)
#
#   curl -fsSL https://ismailbahloul.com/d | bash
#
# Clones or updates this repository, installs chezmoi if needed, and applies it:
# ~/.zshrc, ~/.p10k.zsh, ~/.config/{kitty,gh} and ~/.gitconfig. Config files
# only: no root beyond the chezmoi package, no system file, no package list, no
# hardware, no tool.
#
# The machine layer — drivers, KDE, VFIO, audio, initramfs, udev, and the tools
# in ~/.local/bin — is a different repository and a different entry point:
# https://ismailbahloul.com/m
#
# Arguments: --dry-run (plan only), --force (overwrite existing configs).
# When the script is piped, the arguments go to the script, not to bash:
#
#   curl -fsSL https://ismailbahloul.com/d | bash -s -- --dry-run
#
# Re-running is safe and idempotent: this entry point and the machine layer's
# install.sh apply the same clone, so on a provisioned host it converges to the
# same files instead of creating a second copy.
#
# Deliberately self-contained: this file is piped before anything is cloned, so
# it cannot source a library. The glyphs below mirror lib/logging.sh of the
# machine layer, so /d and /m read the same way.
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

Piped (the usual way), the flags belong to the script, not to bash:

  curl -fsSL https://ismailbahloul.com/d | bash -s -- --dry-run
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

# --- Presentation ------------------------------------------------------------
# Same glyphs and layout as lib/logging.sh in the machine layer: ✔ pass, ✘ fail,
# ! warn, → info, • detail, sections ruled with ━ and ─. Plain text glyphs, no
# emoji, so they keep one cell of width and the same colour everywhere.
RESET=$'\033[0m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
BLUE=$'\033[0;34m'

STEP=0
TOTAL=3
ERR=0

# Rule a title to the same width as the machine layer's log_section.
rule() {
  local left="$1 "
  local dashes=$((70 - ${#left} - 1))
  if [ "$dashes" -lt 4 ]; then
    dashes=4
  fi
  printf '\n%s%s%s' "$BOLD" "$left" "$RESET"
  printf '─%.0s' $(seq 1 "$dashes")
  printf '\n\n'
}

section() {
  STEP=$((STEP + 1))
  local title="━━━ $1"
  if [ "$TOTAL" -gt 0 ]; then
    title="$title $STEP/$TOTAL"
  fi
  rule "$title"
}

pass() { printf '  %s✔%s %s\n' "$GREEN" "$RESET" "$1"; }
fail() { ERR=$((ERR + 1)); printf '  %s✘%s %s\n' "$RED" "$RESET" "$1"; }
warn() { printf '  %s!%s %s\n' "$YELLOW" "$RESET" "$1"; }
info() { printf '  %s→%s %s\n' "$BLUE" "$RESET" "$1"; }
detail() { printf '  %s  • %s%s\n' "$DIM" "$1" "$RESET"; }

summary() {
  rule "━━━ Result"
  if [ "$ERR" -gt 0 ]; then
    printf '  %s%s✘ %s CHECK(S) FAILED%s\n' "$RED" "$BOLD" "$ERR" "$RESET"
  else
    printf '  %s%s✔ APPLIED%s %s— open a new shell to pick up .zshrc%s\n' \
      "$GREEN" "$BOLD" "$RESET" "$DIM" "$RESET"
  fi
}

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
  TOTAL=0
  section "Dry run"
  warn "dry run — nothing will be changed"
  info "repo:    $REPO"
  info "clone:   $DIR"
  info "missing: ${missing[*]:-none}"
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

# --- Prerequisites -----------------------------------------------------------
section "Prerequisites"

if [ "${#missing[@]}" -gt 0 ]; then
  info "installing ${missing[*]}..."
  for pkg in "${missing[@]}"; do
    if ! install_pkg "$pkg"; then
      fail "cannot install '$pkg' automatically"
      detail "install it with your package manager, then re-run"
      summary
      exit 1
    fi
  done
fi

if ! command -v chezmoi >/dev/null 2>&1; then
  fail "chezmoi is still missing after install"
  summary
  exit 1
fi
pass "git and chezmoi"

# --- Clone or update ---------------------------------------------------------
# The machine layer pins this same directory at a tag, so the checkout can be a
# detached HEAD with no upstream: pull when there is one, otherwise fetch the
# default branch and move to its tip.
section "Checkout"

if [ -d "$DIR/.git" ]; then
  if git -C "$DIR" rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    info "updating $DIR (pull)"
    git -C "$DIR" pull --quiet --ff-only >/dev/null
  else
    info "updating $DIR (fetch main)"
    git -C "$DIR" fetch --quiet --depth 1 origin HEAD
    git -C "$DIR" checkout --quiet --force FETCH_HEAD
  fi
else
  info "cloning $DIR"
  if ! git clone --quiet "$REPO" "$DIR"; then
    fail "could not clone $REPO"
    detail "check the network, or set DOTFILES_REPO to another URL"
    summary
    exit 1
  fi
fi

# A pinned, shallow clone has neither a branch nor local tags, so the readable
# name comes from origin: tag first, then the default branch, then the hash.
# Git's own chatter during the step above stays silent here, the ✔ line below
# says what the checkout is, and a stray "Already up to date." would only
# break the display.
label=$(git -C "$DIR" symbolic-ref --quiet --short HEAD || true)
rev=$(git -C "$DIR" rev-parse HEAD 2>/dev/null || true)
if [ -z "$label" ] && [ -n "$rev" ]; then
  label=$(git -C "$DIR" ls-remote --quiet origin 2>/dev/null | awk -v rev="$rev" '
    $1 == rev && $2 ~ /^refs\/tags\// && tag == ""     { tag = $2 }
    $1 == rev && $2 ~ /^refs\/heads\// && branch == "" { branch = $2 }
    END {
      name = (tag != "" ? tag : branch)
      sub(/^refs\/tags\//, "", name)
      sub(/^refs\/heads\//, "", name)
      sub(/\^\{\}$/, "", name)
      print name
    }' || true)
fi
if [ -z "$label" ]; then
  label=$(git -C "$DIR" rev-parse --short HEAD 2>/dev/null || true)
fi
pass "$DIR at ${label:-unknown}"

# --- Pre-flight: do not silently overwrite somebody's configs ----------------
# `chezmoi status` marks an existing, differing target with " M". Only those
# entries mean a file already on this machine would be replaced; on a fresh
# account there are none, so the canonical `curl | bash` still applies without
# asking — and it has to, since stdin is the script itself, not a TTY.
section "Apply"

drift=$(chezmoi --source "$DIR" status 2>/dev/null || true)
clobber=$(printf '%s\n' "$drift" | grep -E '^ M' || true)
if [ -n "$clobber" ] && [ "$FORCE" = false ]; then
  fail "these files already exist and would be overwritten:"
  printf '\n'
  printf '%s\n' "$clobber" | sed 's/^ M /      /'
  printf '\n'
  detail "nothing has been changed"
  detail "re-run with --force to replace them"
  detail "or preview the difference: chezmoi --source $DIR diff"
  summary
  exit 1
fi

# This source has no .chezmoi.toml.tmpl, so chezmoi compares it against the
# machine config and warns that the template changed. Expected, not a failure.
detail "chezmoi may warn that the config file template changed — this source has none by design"

chezmoi --source "$DIR" apply

pending=$(chezmoi --source "$DIR" status 2>/dev/null || true)
if [ -n "$pending" ]; then
  fail "the apply did not converge, still pending:"
  printf '%s\n' "$pending" | sed 's/^/      /'
  summary
  exit 1
fi
pass "portable dotfiles applied (open a new shell to pick up .zshrc)"

summary

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
