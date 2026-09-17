#!/bin/bash
# test.sh — repo-side lint, run by hand before pushing.
#
# Complements validate.sh: this one checks *the repo* (the source tree has the
# expected files, shell syntax is valid, JSON parses, no untracked leftovers);
# validate.sh checks *the machine* (is everything actually deployed and running).
# Nothing calls this automatically.
set -e

# ─── Load logging library ──────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# The lib ships with the repo, so it is always present here.
source "$SCRIPT_DIR/.lib_logging.sh"

cd "$SCRIPT_DIR"
log_init

# ─── Repo ───────────────────────────────────────────────────────────────────
log_section "Repo"

if git rev-parse --git-dir &>/dev/null; then
  log_pass "Git repo"
  if git diff --quiet HEAD 2>/dev/null; then
    log_pass "No uncommitted changes"
  else
    log_warn "Uncommitted changes"
  fi
else
  log_fail "Not a git repo"
fi

# ─── Files ──────────────────────────────────────────────────────────────────
log_section "Files"

for f in install.sh validate.sh run_once_*.sh dot_local/bin/*; do
  if [ -f "$f" ]; then
    log_pass "$f"
  else
    log_fail "$f missing"
  fi
done

# ─── Cleanliness ────────────────────────────────────────────────────────────
log_section "Cleanliness"

git ls-files --others --exclude-standard 2>/dev/null | while IFS= read -r f; do
  log_warn "Untracked file: $f"
done

# ─── Shell syntax ───────────────────────────────────────────────────────────
log_section "Shell syntax"

for f in install.sh validate.sh run_once_*.sh; do
  if bash -n "$f"; then
    log_pass "$f"
  else
    log_fail "$f syntax error"
  fi
done

for f in dot_local/bin/executable_limine-boot-* dot_local/bin/executable_power-profile dot_local/bin/executable_backup-data; do
  base=$(basename "$f")
  if head -1 "$f" | grep -q bash; then
    if bash -n "$f"; then
      log_pass "$base"
    else
      log_fail "$base syntax error"
    fi
  fi
done

# ─── JSON ───────────────────────────────────────────────────────────────────
log_section "JSON"

while IFS= read -r -d '' f; do
  if jq empty "$f" &>/dev/null; then
    log_pass "$f"
  else
    log_fail "$f invalid JSON"
  fi
done < <(find . -name "*.json" -not -path "./.git/*" -print0)

# ─── KDE config ─────────────────────────────────────────────────────────────
log_section "KDE config"

for f in dot_config/kglobalshortcutsrc dot_config/kwinrulesrc dot_config/kxkbrc; do
  base=$(basename "$f")
  if [ -f "$f" ]; then
    log_pass "$base"
  else
    log_fail "$base missing"
  fi
done

# ─── KDE widgets ────────────────────────────────────────────────────────────
log_section "KDE widgets"

for d in dot_local/share/plasma/plasmoids/*; do
  base=$(basename "$d")
  if [ -d "$d" ]; then
    log_pass "$base"
  else
    log_fail "$base missing"
  fi
done

# ─── Summary ────────────────────────────────────────────────────────────────
log_summary
exit "$LOG_ERR"
