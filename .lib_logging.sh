#!/bin/bash
# =============================================================================
# .lib_logging.sh — shared logging library for dotfiles scripts
#
# Usage:
#   source "${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}/.lib_logging.sh"
#
# Functions:
#   log_init [total]       — reset step counter (optional total for [step/N])
#   log_section title      — ━━━ title [1/N] ────────────────────
#   log_pass  "message"    — ✔ message
#   log_fail  "message"    — ✘ message (sets LOG_ERR=1)
#   log_warn  "message"    — ⚠ message
#   log_info  "message"    — → message
#   log_skip  "message"    — ⋯ message (dimmed, already done)
#   log_detail "message"   —   • message (dimmed sub-info)
#   log_cmd   "command"    — $ command (highlighted command)
#   log_summary            — show final ✅ or ⚠ count
# =============================================================================

# ─── Colors ────────────────────────────────────────────────────────────────
RESET='\033[0m'
BOLD='\033[1m'
DIM='\033[2m'
ITALIC='\033[3m'
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'

# ─── State ──────────────────────────────────────────────────────────────────
LOG_STEP=0
LOG_TOTAL=0
LOG_ERR=0

# ─── Helpers ────────────────────────────────────────────────────────────────

_ln() { printf '%s' "$1"; }

_log_sep() {
  local title="$1" count="${2:-0}" total="${3:-0}"
  local prefix
  if [ "$total" -gt 0 ]; then
    prefix=" ${count}/${total}"
  else
    prefix=""
  fi
  local left="━━━ ${title}${prefix} "
  local max_width=70
  local min_dashes=4
  local dash_count=$(( max_width - ${#left} - 1 ))
  [ "$dash_count" -lt "$min_dashes" ] && dash_count="$min_dashes"
  printf "${BOLD}${left}${RESET}"
  printf '─%.0s' $(seq 1 "$dash_count")
}

# ─── Public API ─────────────────────────────────────────────────────────────

log_init() {
  LOG_TOTAL="${1:-0}"
  LOG_STEP=0
  LOG_ERR=0
}

log_section() {
  local title="$1"
  ((LOG_STEP++)) || true
  echo ""
  _log_sep "$title" "$LOG_STEP" "$LOG_TOTAL"
  echo ""
}

log_pass() { echo -e "  ${GREEN}✔${RESET} $1"; }

log_fail() { echo -e "  ${RED}✘${RESET} $1"; LOG_ERR=1; }

log_fatal() { echo -e "  ${RED}✘${RESET} ${BOLD}$1${RESET}"; exit 1; }

log_warn() { echo -e "  ${YELLOW}⚠${RESET} $1"; }

log_info() { echo -e "  ${BLUE}→${RESET} $1"; }

log_skip() { echo -e "  ${DIM}⋯${RESET} ${DIM}$1${RESET}"; }

log_detail() { echo -e "  ${DIM}  • $1${RESET}"; }

log_cmd() { echo -e "  ${MAGENTA}\$${RESET} ${BOLD}$1${RESET}"; }

log_summary() {
  echo ""
  _log_sep "Result" 0 0
  echo ""
  if [ "$LOG_ERR" -eq 0 ]; then
    echo -e "  ${GREEN}${BOLD}✅ ALL CHECKS PASSED${RESET}"
  else
    echo -e "  ${RED}${BOLD}⚠ ${LOG_ERR} check(s) failed${RESET}"
  fi
  echo ""
}
