#!/bin/bash
# test.sh — offline checks for this repository.
#
# No network, no root, no package manager: chezmoi, pacman/apt-get, git and
# sudo are stubs on PATH, HOME is a throwaway, and nothing is written outside a
# temp dir.
set -u

SRC=$(cd "$(dirname "$0")" && pwd)
cd "$SRC" || exit 1
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

ok=0
ko=0
RUN_PATH=""

pass() { ok=$((ok + 1)); printf '  ok    %s\n' "$1"; }
fail() { ko=$((ko + 1)); printf '  FAIL  %s\n' "$1"; }

stubs() { # $1 = bin dir
  mkdir -p "$1"
  cat >"$1/git" <<'STUB'
#!/bin/sh
[ "$1" = "clone" ] && mkdir -p "$3"
exit 0
STUB
  cat >"$1/sudo" <<'STUB'
#!/bin/sh
case "${1:-}" in -v) exit 0 ;; esac
exec "$@"
STUB
  cat >"$1/chezmoi-clean" <<'STUB'
#!/bin/sh
[ "$1" = "--source" ] && shift 2
case "$1" in
  apply) echo "FAKE: chezmoi apply" ;;
esac
exit 0
STUB
  cat >"$1/chezmoi-dirty" <<'STUB'
#!/bin/sh
[ "$1" = "--source" ] && shift 2
case "$1" in
  apply)  echo "FAKE: chezmoi apply" ;;
  status) echo " M .zshrc" ;;
esac
exit 0
STUB
  chmod +x "$1"/*
}

pkgmgr() { # $1 = bin dir, $2 = manager: "installs" chezmoi
  cat >"$1/$2" <<STUB
#!/bin/sh
cp "$1/chezmoi-clean" "$1/chezmoi"
chmod +x "$1/chezmoi"
exit 0
STUB
  chmod +x "$1/$2"
}

# A PATH whose /usr/bin holds neither the real package managers nor chezmoi.
shadow() { # $1 = shadow dir
  mkdir -p "$1"
  for f in /usr/bin/* /usr/local/bin/*; do
    case "${f##*/}" in pacman | apt-get | dnf | zypper | apk | chezmoi | git | sudo) continue ;; esac
    [ -e "$1/${f##*/}" ] || ln -s "$f" "$1/${f##*/}" 2>/dev/null || true
  done
}

case_dir() { # $1 = dir: empty HOME + a repo dir with a .git
  mkdir -p "$WORK/$1/home" "$WORK/$1/repo/.git"
  stubs "$WORK/$1/bin"
}

run() { # dir name want_rc want_pat [args...]
  local d="$WORK/$1" name=$2 want_rc=$3 want_pat=$4; shift 4
  local log="$WORK/$name.log" rc
  (cd "$d" && env HOME="$d/home" PATH="$RUN_PATH" DOTFILES_DIR="$d/repo" \
    bash "$SRC/bootstrap.sh" "$@") >"$log" 2>&1
  rc=$?
  if [ "$rc" = "$want_rc" ] && grep -qF "$want_pat" "$log"; then
    pass "$name (exit=$rc)"
  else
    fail "$name: exit=$rc (want $want_rc) — pattern: $want_pat"
    sed -n '1,10p' "$log" | sed 's/^/          /'
  fi
}

echo "bootstrap.sh — control flow (offline)"

# 1. a host that also has the machine layer converges instead of refusing.
case_dir provisioned
mkdir -p "$WORK/provisioned/home/.local/share/chezmoi/packages.d"
touch "$WORK/provisioned/home/.local/share/chezmoi/packages.d/base.pacman"
cp "$WORK/provisioned/bin/chezmoi-clean" "$WORK/provisioned/bin/chezmoi"
RUN_PATH="$WORK/provisioned/bin:/usr/bin:/bin"
run provisioned provisioned 0 "portable dotfiles applied"

# 2. --dry-run is read-only and does not trip the guard.
case_dir dryrun
cp "$WORK/dryrun/bin/chezmoi-clean" "$WORK/dryrun/bin/chezmoi"
RUN_PATH="$WORK/dryrun/bin:/usr/bin:/bin"
run dryrun dryrun 0 "dry run — nothing will be changed" --dry-run

# 3. chezmoi missing: installed through pacman, then the layer is applied.
case_dir pacman
pkgmgr "$WORK/pacman/bin" pacman
shadow "$WORK/pacman/shadow"
RUN_PATH="$WORK/pacman/bin:$WORK/pacman/shadow"
run pacman pacman-install 0 "portable dotfiles applied"

# 4. same through apt-get, with no pacman on the PATH.
case_dir apt
pkgmgr "$WORK/apt/bin" apt-get
shadow "$WORK/apt/shadow"
RUN_PATH="$WORK/apt/bin:$WORK/apt/shadow"
run apt apt-install 0 "portable dotfiles applied"

# 5. an existing config is never overwritten without --force.
case_dir clobber
cp "$WORK/clobber/bin/chezmoi-dirty" "$WORK/clobber/bin/chezmoi"
RUN_PATH="$WORK/clobber/bin:/usr/bin:/bin"
run clobber clobber 1 "would be overwritten"

# ─── Repository ──────────────────────────────────────────────────────────────
echo "repository"

if [ -f dot_zshrc ]; then
  if ! command -v zsh >/dev/null 2>&1; then
    printf '  skip  dot_zshrc (zsh not installed)\n'
  elif zsh -n dot_zshrc; then
    pass "dot_zshrc (zsh -n)"
  else
    fail "dot_zshrc syntax error"
  fi
else
  fail "dot_zshrc missing"
fi

# Without this, an apply would drop the README and the bootstrap into ~.
missing_ignore=""
for f in README.md LICENSE bootstrap.sh test.sh docs; do
  grep -qxF "$f" .chezmoiignore || missing_ignore="$missing_ignore $f"
done
if [ -z "$missing_ignore" ]; then
  pass ".chezmoiignore covers the repo-only files"
else
  fail ".chezmoiignore missing entries:$missing_ignore"
fi

if command -v chezmoi >/dev/null 2>&1; then
  leaked=$(chezmoi --source "$SRC" managed --include files 2>/dev/null \
    | grep -xE 'README\.md|LICENSE|bootstrap\.sh|test\.sh|docs/.+' || true)
  if [ -z "$leaked" ]; then
    pass "chezmoi deploys none of the repo-only files"
  else
    fail "chezmoi would deploy: $leaked"
  fi
else
  printf '  skip  chezmoi managed (chezmoi not installed)\n'
fi

echo ""
echo "result: $ok ok, $ko failed"
[ "$ko" -eq 0 ]
