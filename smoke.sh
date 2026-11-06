#!/bin/bash
# Offline smoke test of install.sh's control flow.
# No network, no sudo, no package manager: chezmoi/paru/sudo/curl are fakes on
# PATH, HOME is a throwaway, and the repo scripts are copied to a temp dir.
set -u

SRC=$(cd "$(dirname "$0")" && pwd)
WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT

ok=0
ko=0

setup() {
  d=$1
  vrc=$2
  mkdir -p "$d/home/.local/share/chezmoi/.git" "$d/bin" "$d/repo/lib"
  cp "$SRC/install.sh" "$d/repo/"
  cp "$SRC/lib/logging.sh" "$d/repo/lib/"
  printf '#!/bin/bash\necho "  v stub validate"\nexit %s\n' "$vrc" >"$d/repo/validate.sh"
  cat >"$d/bin/chezmoi" <<'EOF'
#!/bin/sh
case "$1" in
  update) exit "${FAKE_UPDATE_RC:-0}" ;;
  init)   exit "${FAKE_INIT_RC:-0}" ;;
  status) [ -n "${FAKE_STATUS:-}" ] && printf '%s\n' "$FAKE_STATUS"; exit 0 ;;
  *)      exit 0 ;;
esac
EOF
  printf '#!/bin/sh\nexit 0\n' >"$d/bin/paru"
  printf '#!/bin/sh\nexit 0\n' >"$d/bin/sudo"
  printf '#!/bin/sh\nexit 0\n' >"$d/bin/curl"
  chmod +x "$d/bin/"*
}

run_case() {
  local name=$1 want_rc=$2 want_pat=$3 vrc=$4 extra=$5
  local d="$WORK/$name" log rc clean
  setup "$d" "$vrc"
  log="$d/out.log"
  HOME="$d/home" PATH="$d/bin:$PATH" bash "$d/repo/install.sh" $extra >"$log" 2>&1
  rc=$?
  # Strip the colour spans first: a verdict is drawn in two spans ("✔ APPLIED"
  # then "— nothing validated"), so a literal match would never see it whole.
  clean=$(sed -e 's/\x1b\[[0-9;]*m//g' "$log")
  if [ "$rc" = "$want_rc" ] && printf '%s\n' "$clean" | grep -qF "$want_pat"; then
    ok=$((ok + 1))
    printf '  ok    %-22s exit=%s  %s\n' "$name" "$rc" "$want_pat"
  else
    ko=$((ko + 1))
    printf '  FAIL  %-22s exit=%s (want %s) — pattern: %s\n' "$name" "$rc" "$want_rc" "$want_pat"
    grep -aE "✘|!|✔|→|⋯" "$log" | sed 's/^/          /'
  fi
}

echo "install.sh — control flow (offline)"
FAKE_UPDATE_RC=0 FAKE_STATUS='' run_case update-ok 0 "✔ APPLIED — nothing validated" 0 ""
FAKE_UPDATE_RC=1 FAKE_INIT_RC=0 FAKE_STATUS='' run_case update-fail-fallback 0 "! PASSED WITH 1 WARNING(S)" 0 ""
FAKE_UPDATE_RC=0 FAKE_STATUS=" M .zshrc" run_case not-converged 1 "✘ 1 CHECK(S) FAILED" 0 ""
FAKE_UPDATE_RC=0 FAKE_STATUS='' run_case validate-fails 1 "✘ 1 CHECK(S) FAILED" 1 --validate
FAKE_UPDATE_RC=0 FAKE_STATUS='' run_case validate-passes 0 "✔ ALL CHECKS PASSED" 0 --validate

echo ""
echo "result: $ok ok, $ko failed"
[ "$ko" -eq 0 ]
