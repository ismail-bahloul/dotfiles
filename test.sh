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

for f in install.sh validate.sh run_once_*.sh* run_onchange_*.sh* dot_local/bin/*; do
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

# ─── Contract: every etc/ file is covered by an etc-hash ─────────────────────
# chezmoi re-runs a script only when the script itself changes. The etc-hash
# line in a .tmpl stands in for the installed files, so a file under etc/ that
# is not listed there is never redeployed after an edit.
log_section "etc/ coverage"

while IFS= read -r -d '' f; do
  if grep -qhF "\"$f\"" run_* 2>/dev/null; then
    log_pass "$f"
  else
    log_fail "$f is not listed in any etc-hash (never redeployed)"
  fi
done < <(find etc -type f -print0 | sort -z)

for f in run_*.tmpl; do
  [ -f "$f" ] || continue
  if grep -q "install_system_file" "$f" && ! grep -q "^# etc-hash:" "$f"; then
    log_fail "$f installs etc/ files but carries no etc-hash line"
  else
    log_pass "$f"
  fi
done

# ─── Contract: scripts ↔ README ──────────────────────────────────────────────
# The README is the map of the repo. A script missing from it, or a script it
# mentions that no longer exists, is documentation drift.
log_section "Scripts documented"

for f in run_*.sh*; do
  [ -f "$f" ] || continue
  if grep -qF "$f" README.md; then
    log_pass "$f documented"
  else
    log_fail "$f is not mentioned in README.md"
  fi
done

while IFS= read -r r; do
  if [ -f "$r" ]; then
    log_pass "README mentions $r"
  else
    log_fail "README mentions $r, but the file does not exist"
  fi
done < <(grep -oE 'run_(once|onchange)_[0-9]+-[A-Za-z0-9._-]+\.sh(\.tmpl)?' README.md | sort -u)

# ─── Package lists ───────────────────────────────────────────────────────────
log_section "Package lists"

for f in packages.pacman packages.aur; do
  dups=$(grep -v '^[[:space:]]*#' "$f" | awk 'NF {print $1}' | sort | uniq -d)
  if [ -z "$dups" ]; then
    log_pass "$f: no duplicate entry"
  else
    log_fail "$f: duplicate entry: $(printf '%s ' $dups)"
  fi
done

# ─── Contract: top-level entries are deployed or explicitly ignored ──────────
log_section "chezmoi scope"

for entry in * .[!.]*; do
  case "$entry" in
    dot_*|run_*|Desktop|.git|.gitattributes|.gitignore|.chezmoi*) continue ;;
  esac
  [ -e "$entry" ] || continue
  if grep -qxF "$entry" .chezmoiignore; then
    log_pass "$entry ignored"
  else
    log_fail "$entry is neither a dot_ target nor listed in .chezmoiignore"
  fi
done

# ─── Shell syntax ───────────────────────────────────────────────────────────
log_section "Shell syntax"

for f in install.sh validate.sh run_once_*.sh* run_onchange_*.sh*; do
  # .tmpl scripts carry a chezmoi hash line: render them before the syntax check
  case "$f" in
    *.tmpl) check() { chezmoi -S "$PWD" execute-template < "$f" | bash -n; } ;;
    *)      check() { bash -n "$f"; } ;;
  esac
  if check; then
    log_pass "$f"
  else
    log_fail "$f syntax error"
  fi
done

for f in dot_local/bin/executable_limine-boot-* dot_local/bin/executable_omenctl-tui dot_local/bin/executable_backup-data; do
  base=$(basename "$f")
  if head -1 "$f" | grep -qE 'bash|sh'; then
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
