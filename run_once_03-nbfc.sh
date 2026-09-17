#!/bin/bash
# =============================================================================
# run_once_03-nbfc.sh
# Run once by chezmoi (re-runs if this file changes)
# Build & install nbfc-linux and nbfc-qt from ismail-bahloul forks
# Idempotent: safe to re-run, skips if already built and configured
# =============================================================================
set -e

# Logging helpers: .lib_logging.sh ships in the chezmoi source dir and is always
# present when run_once scripts run under chezmoi, so no fallback is needed.
source "${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}/.lib_logging.sh"

# --- Check if nbfc-linux is already installed ---------------------------------------
# The binaries are stripped, so the fork cannot be identified from their content, and
# the fork's `make install` produces /usr/bin/nbfc (there is no /usr/bin/nbfc-linux).
# Track the install with a marker file instead; bump NBFB_FORK_REV to force a rebuild.
NBFB_BIN="/usr/bin/nbfc"
NBFB_MARKER="/usr/local/share/nbfc-linux-fork.rev"
NBFB_FORK_REV="1"
NBFB_BUILT=false

if [ -x "$NBFB_BIN" ] && [ "$(cat "$NBFB_MARKER" 2>/dev/null)" = "$NBFB_FORK_REV" ]; then
  log_skip "nbfc-linux already installed (fork rev $NBFB_FORK_REV)"
else
  log_info "Building nbfc-linux from ismail-bahloul/nbfc-linux..."
  NBFB_BUILT=true

  WORKDIR=$(mktemp -d)
  trap 'rm -rf "$WORKDIR"' EXIT

  # Clean any previous manual install
  sudo rm -f /usr/bin/nbfc-linux 2>/dev/null || true

  git clone --depth=1 https://github.com/ismail-bahloul/nbfc-linux "$WORKDIR/nbfc-linux"
  cd "$WORKDIR/nbfc-linux"
  ./autogen.sh > /dev/null || log_fatal "autogen.sh failed"
  ./configure --prefix=/usr --sysconfdir=/etc --bindir=/usr/bin > /dev/null || log_fatal "configure failed"
  make 2>&1 | tail -5 || log_fatal "make failed"
  sudo make install > /dev/null 2>&1
  echo "$NBFB_FORK_REV" | sudo tee "$NBFB_MARKER" > /dev/null
  cd /
fi

# --- Check if nbfc-qt is already installed -------------------------------------
NBFB_QT_BIN="/usr/bin/nbfc-qt"
if [ -f "$NBFB_QT_BIN" ]; then
  log_skip "nbfc-qt already installed"
else
  log_info "Building nbfc-qt from ismail-bahloul/nbfc-qt..."
  NBFB_BUILT=true

  if [ -z "${WORKDIR:-}" ]; then
    WORKDIR=$(mktemp -d)
    trap 'rm -rf "$WORKDIR"' EXIT
  fi

  git clone --depth=1 https://github.com/ismail-bahloul/nbfc-qt "$WORKDIR/nbfc-qt"
  cd "$WORKDIR/nbfc-qt"
  make QT_VERSION=6 > /dev/null 2>&1
  sudo make install > /dev/null 2>&1
  cd /
fi

# --- Lock nbfc packages in IgnorePkg (idempotent) -------------------------------
if grep -q "^IgnorePkg" /etc/pacman.conf; then
  for pkg in nbfc-linux nbfc-qt; do
    if ! grep -q "$pkg" /etc/pacman.conf; then
      log_info "Adding $pkg to IgnorePkg..."
      sudo sed -i "s/^IgnorePkg\s*=\s*/IgnorePkg = $pkg /" /etc/pacman.conf
    fi
  done
else
  log_info "Adding IgnorePkg = nbfc-linux nbfc-qt..."
  sudo sed -i 's/^#IgnorePkg.*/IgnorePkg = nbfc-linux nbfc-qt/' /etc/pacman.conf
fi

# --- Deploy fan profile (idempotent) -------------------------------------------
FAN_PROFILE="${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}/my-nbfc.json"

if [ ! -f "$FAN_PROFILE" ]; then
  log_fatal "my-nbfc.json not found at $FAN_PROFILE"
fi

sudo mkdir -p /usr/share/nbfc/configs

# Only copy if content differs
if [ -f /usr/share/nbfc/configs/my-nbfc.json ]; then
  if ! cmp -s "$FAN_PROFILE" /usr/share/nbfc/configs/my-nbfc.json; then
    log_info "Updating fan profile..."
    sudo cp "$FAN_PROFILE" /usr/share/nbfc/configs/
  else
    log_pass "Fan profile already up to date"
  fi
else
  log_info "Deploying fan profile..."
  sudo cp "$FAN_PROFILE" /usr/share/nbfc/configs/
fi

# --- Write service config (idempotent) -----------------------------------------
sudo mkdir -p /etc/nbfc
NBFB_CONFIG="/etc/nbfc/nbfc.json"
CURRENT_CONFIG='{"SelectedConfigId": "my-nbfc"}'
if [ -f "$NBFB_CONFIG" ]; then
  if [ "$(cat "$NBFB_CONFIG")" != "$CURRENT_CONFIG" ]; then
    log_info "Updating NBFC service config..."
    echo "$CURRENT_CONFIG" | sudo tee "$NBFB_CONFIG" > /dev/null
  fi
else
  log_info "Writing NBFC service config..."
  echo "$CURRENT_CONFIG" | sudo tee "$NBFB_CONFIG" > /dev/null
fi

# --- Enable and restart service (only if something changed) ---------------------
if $NBFB_BUILT; then
  log_info "Reloading systemd and restarting NBFC service..."
  sudo systemctl daemon-reload
  sudo systemctl enable nbfc_service.service
  # NB: restart through systemd, not `nbfc restart`. The unit is Type=forking with
  # ExecStart=/bin/nbfc start; driving the CLI directly starts the daemon outside
  # systemd, which then reports the unit as inactive and loses track of the fans.
  sudo systemctl restart nbfc_service.service
  log_pass "NBFC setup complete."
else
  log_skip "NBFC already up to date, nothing to do."
fi
