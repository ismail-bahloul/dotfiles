#!/bin/bash
# =============================================================================
# run_once_02-wine-staging.sh
# Run once by chezmoi (re-runs if this file changes)
# Install wine-staging 9.21 as a standalone runner in ~/.local/share/wine-runners/
# No system packages — fully portable, multiple runners can coexist.
# Idempotent: safe to re-run, skips if already set up.
# =============================================================================
set -euo pipefail

# Logging helpers: .lib_logging.sh ships in the chezmoi source dir and is always
# present when run_once scripts run under chezmoi, so no fallback is needed.
source "${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}/.lib_logging.sh"

WINE_VERSION="9.21-1"
WINE_PKG="wine-staging-${WINE_VERSION}-x86_64.pkg.tar.zst"
ALA_URL="https://archive.archlinux.org/packages/w/wine-staging/${WINE_PKG}"
RUNNER_DIR="$HOME/.local/share/wine-runners"
RUNNER_NAME="wine-staging-9.21-standalone"
RUNNER_PATH="$RUNNER_DIR/$RUNNER_NAME"
BIN_DIR="$HOME/.local/bin"
WINE_BIN="$RUNNER_PATH/bin/wine"

# ---------------------------------------------------------------------------
# Helper: detect if we're already correctly deployed
# ---------------------------------------------------------------------------
is_runner_ok() {
  [ -x "$WINE_BIN" ] || return 1
  CURRENT_WINE=$("$WINE_BIN" --version 2>/dev/null || echo "")
  echo "$CURRENT_WINE" | grep -q "wine-9.21" || return 1

  # Check symlinks in ~/.local/bin/
  for exe in wine wine64 wineserver; do
    [ -L "$BIN_DIR/$exe" ] || return 1
    [ "$(readlink "$BIN_DIR/$exe")" = "$RUNNER_PATH/bin/$exe" ] || return 1
  done

  # Check symlinks in /usr/local/bin/
  for exe in wine wine64 wineserver; do
    [ -L "/usr/local/bin/$exe" ] || return 1
    [ "$(readlink "/usr/local/bin/$exe")" = "$RUNNER_PATH/bin/$exe" ] || return 1
  done

  return 0
}

# ---------------------------------------------------------------------------
# 1. Check if already installed
# ---------------------------------------------------------------------------
if is_runner_ok; then
  log_skip "wine-staging 9.21 standalone runner already installed"
else
  log_info "Setting up wine-staging 9.21 standalone runner..."

  # --- Cleanup conflicting system packages -------------------------------------
  for pkg in wine wine-staging wine-cachyos; do
    if pacman -Q 2>/dev/null | grep -q "^$pkg "; then
      log_info "Removing conflicting system package: $pkg"
      sudo pacman -Rdd --noconfirm "$pkg" 2>/dev/null || true
    fi
  done

  # --- Cleanup IgnorePkg lock (no longer needed) -------------------------------
  if grep -q "IgnorePkg.*wine" /etc/pacman.conf 2>/dev/null; then
    log_info "Removing wine entries from IgnorePkg in pacman.conf..."
    sudo sed -i 's/\s*wine-staging\s*/ /g; s/\s*wine-cachyos\s*/ /g' /etc/pacman.conf
    sudo sed -i '/^IgnorePkg\s*=\s*$/d' /etc/pacman.conf
    sudo sed -i '/^#IgnorePkg\s*=\s*wine-cachyos$/d' /etc/pacman.conf
  fi

  # --- Download package from Arch Archive --------------------------------------
  mkdir -p "$RUNNER_DIR"
  if [ ! -f "$RUNNER_DIR/$WINE_PKG" ]; then
    log_info "Downloading wine-staging ${WINE_VERSION} from Arch Archive..."
    curl -fL --output "$RUNNER_DIR/$WINE_PKG" "$ALA_URL" || log_fatal "Download failed"
  else
    log_detail "Package already downloaded"
  fi

  # --- Extract standalone runner -----------------------------------------------
  log_info "Extracting to $RUNNER_PATH..."
  rm -rf "$RUNNER_PATH"
  mkdir -p "$RUNNER_PATH"

  # .pkg.tar.zst is a standard tar archive — extract only the usr/ prefix
  tar -xf "$RUNNER_DIR/$WINE_PKG" -C "$RUNNER_PATH" --strip-components=1 usr/ 2>/dev/null || \
    tar -xf "$RUNNER_DIR/$WINE_PKG" -C "$RUNNER_PATH" usr/ 2>/dev/null

  # If usr/ wasn't stripped, move contents up
  if [ -d "$RUNNER_PATH/usr" ]; then
    mv "$RUNNER_PATH/usr/"* "$RUNNER_PATH/" 2>/dev/null || true
    mv "$RUNNER_PATH/usr/."* "$RUNNER_PATH/" 2>/dev/null || true
    rm -rf "${RUNNER_PATH:?}/usr"
  fi

  # Verify the binary exists
  if [ ! -x "$WINE_BIN" ]; then
    log_fatal "wine binary not found in extracted archive at $WINE_BIN"
  fi

  # --- Create symlinks in ~/.local/bin/ (shell PATH) ---------------------------
  mkdir -p "$BIN_DIR"
  for exe in wine wine64 wineserver; do
    ln -sf "$RUNNER_PATH/bin/$exe" "$BIN_DIR/$exe"
  done

  # --- Create symlinks in /usr/local/bin/ (system PATH, for .desktop apps) ------
  sudo mkdir -p /usr/local/bin
  for exe in wine wine64 wineserver; do
    sudo ln -sf "$RUNNER_PATH/bin/$exe" "/usr/local/bin/$exe"
  done

  log_pass "Wine standalone runner installed: $("$WINE_BIN" --version)"
fi

# ---------------------------------------------------------------------------
# 2. Initialize Wine prefix (only if not already done)
# ---------------------------------------------------------------------------
WINE_PREFIX="$HOME/.wine"
if [ -f "$WINE_PREFIX/system.reg" ]; then
  log_skip "Wine prefix already exists"
else
  log_info "Initializing Wine prefix..."
  WINEDLLOVERRIDES="winemenubuilder.exe=d" wine wineboot -u 2>/dev/null || true

  # Install core fonts for plugin GUI compatibility
  log_info "Installing corefonts via winetricks..."
  WINEDLLOVERRIDES="winemenubuilder.exe=d" winetricks -q corefonts 2>/dev/null || log_warn "winetricks corefonts failed (may need desktop)"
fi

log_pass "Wine setup complete."
