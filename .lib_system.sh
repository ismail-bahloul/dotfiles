#!/bin/bash
# =============================================================================
# .lib_system.sh — install versioned system files (etc/…) for run_once scripts
#
# Usage (after sourcing .lib_logging.sh):
#   source "$SCRIPT_DIR/.lib_system.sh"
#   install_system_file etc/udev/rules.d/99-foo.rules   # -> /etc/udev/rules.d/…
#
# The path under the source dir is the path under `/`, so the repo tree mirrors
# the machine. Returns 0 if the file was (re)installed, 1 if already identical
# (or the source is missing, with a warning), so callers can chain a reload:
#   install_system_file … && NEEDS_RELOAD=true
# =============================================================================
install_system_file() {
  local rel="$1" src dst
  src="$SCRIPT_DIR/$rel"
  dst="/${rel}"
  if [ ! -f "$src" ]; then
    log_warn "$rel not found in the source dir, skipping"
    return 1
  fi
  if [ -f "$dst" ] && cmp -s "$src" "$dst"; then
    log_skip "$dst already up to date"
    return 1
  fi
  sudo install -D -m 644 "$src" "$dst"
  log_detail "installed $dst"
}
