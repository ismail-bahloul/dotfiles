#!/bin/bash
# =============================================================================
# lib/logging.sh — shared logging library for dotfiles scripts
#
# Usage:
#   source "${CHEZMOI_SOURCE_DIR:-$HOME/.local/share/chezmoi}/lib/logging.sh"
#
# Functions:
#   log_init [total]       — reset the counters (optional total for [step/N])
#   log_section title      — ━━━ title [1/N] ────────────────────
#   log_pass  "message"    — ✔ message
#   log_fail  "message"    — ✘ message (increments LOG_ERR)
#   log_warn  "message"    — ! message (increments LOG_WARN)
#   log_info  "message"    — → message
#   log_skip  "message"    — ⋯ message (dimmed, already done)
#   log_detail "message"   —   • message (dimmed sub-info)
#   log_cmd   "command"    — $ command (highlighted command)
#   log_summary            — verdict: ✘ failures, else ! warnings, else
#                            ⋯ LOG_UNVALIDATED, else ✔ all checks passed
#
# The glyphs are plain text (✔ ✘ ! → ⋯), never emoji: they keep the same
# single-cell width and colour in every terminal and font.
#
# State the caller may set:
#   LOG_UNVALIDATED=1      — nothing was checked, so the summary must not claim
#                            "all checks passed" (e.g. install.sh update mode)
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
LOG_ERR=0         # failed checks (log_fail)
LOG_WARN=0        # warnings (log_warn)
LOG_UNVALIDATED=0 # 1 → the summary reports that nothing was validated

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
  LOG_WARN=0
  LOG_UNVALIDATED=0
}

log_section() {
  local title="$1"
  ((LOG_STEP++)) || true
  echo ""
  _log_sep "$title" "$LOG_STEP" "$LOG_TOTAL"
  echo ""
}

log_pass() { echo -e "  ${GREEN}✔${RESET} $1"; }

log_fail() { LOG_ERR=$((LOG_ERR + 1)); echo -e "  ${RED}✘${RESET} $1"; }

log_fatal() { echo -e "  ${RED}✘${RESET} ${BOLD}$1${RESET}"; exit 1; }

log_warn() { LOG_WARN=$((LOG_WARN + 1)); echo -e "  ${YELLOW}!${RESET} $1"; }

log_info() { echo -e "  ${BLUE}→${RESET} $1"; }

log_skip() { echo -e "  ${DIM}⋯${RESET} ${DIM}$1${RESET}"; }

log_detail() { echo -e "  ${DIM}  • $1${RESET}"; }

log_cmd() { echo -e "  ${MAGENTA}\$${RESET} ${BOLD}$1${RESET}"; }

log_summary() {
  echo ""
  _log_sep "Result" 0 0
  echo ""
  if [ "$LOG_ERR" -gt 0 ]; then
    echo -e "  ${RED}${BOLD}✘ ${LOG_ERR} CHECK(S) FAILED${RESET}"
  elif [ "$LOG_WARN" -gt 0 ]; then
    echo -e "  ${YELLOW}${BOLD}! PASSED WITH ${LOG_WARN} WARNING(S)${RESET}"
  elif [ "$LOG_UNVALIDATED" -eq 1 ]; then
    echo -e "  ${DIM}⋯ NOTHING VALIDATED${RESET}"
  else
    echo -e "  ${GREEN}${BOLD}✔ ALL CHECKS PASSED${RESET}"
  fi
  echo ""
}
