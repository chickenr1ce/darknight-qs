#!/usr/bin/env bash
# Headless gate for scripts/restart.sh.
#
# Stubs pkill, pgrep, setsid, and quickshell on PATH so the gate never touches a
# real instance, and points XDG_RUNTIME_DIR at a fixture. The quickshell stub
# writes the by-id log the new reporting code reads, so the loaded, failed, and
# argument-error paths are all exercised offline.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() { echo "restart FAIL: $*" >&2; exit 1; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/qs-restart-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

export XDG_RUNTIME_DIR="$TMP/run"
mkdir -p "$XDG_RUNTIME_DIR/quickshell/by-id"

STUB="$TMP/bin"
mkdir -p "$STUB"

# The stub shell writes the log scripts/instance.sh resolves, in the mode named
# by QS_STUB_MODE, so restart.sh reads a load result without booting anything.
cat >"$STUB/quickshell" <<'STUBEOF'
#!/usr/bin/env bash
set -euo pipefail
config=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        -p) config="$2"; shift 2 ;;
        *) shift ;;
    esac
done
[[ -n "$config" ]] || config="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
dir="$(mktemp -d "${XDG_RUNTIME_DIR}/quickshell/by-id/test-XXXXXX")"
log="$dir/log.log"
printf 'Launching config: "%s/shell.qml"\n' "$config" >"$log"
case "${QS_STUB_MODE:-ok}" in
    ok) echo 'Configuration Loaded' >>"$log" ;;
    fail)
        echo 'Failed to load configuration' >>"$log"
        echo '  caused by @services/Broken.qml[3:5]: Broken is not a type' >>"$log"
        ;;
esac
STUBEOF
chmod +x "$STUB/quickshell"

printf '#!/bin/sh\nexit 1\n' >"$STUB/pkill"
printf '#!/bin/sh\nexit 1\n' >"$STUB/pgrep"
printf '#!/bin/sh\nexec "$@"\n' >"$STUB/setsid"
chmod +x "$STUB/pkill" "$STUB/pgrep" "$STUB/setsid"
export PATH="$STUB:$PATH"

CFG="$TMP/worktree"
mkdir -p "$CFG"
touch "$CFG/shell.qml"

RESTART="$ROOT/scripts/restart.sh"

# Loaded path: exit 0 and a loaded report.
if ! QS_STUB_MODE=ok "$RESTART" --probe "$CFG" --timeout 5 >"$TMP/out" 2>&1; then
    fail "loaded path exited nonzero: $(cat "$TMP/out")"
fi
grep -q 'loaded' "$TMP/out" || fail "loaded path did not report loaded: $(cat "$TMP/out")"

# Failed path: nonzero, with the cause.
if QS_STUB_MODE=fail "$RESTART" --probe "$CFG" --timeout 5 >"$TMP/out" 2>&1; then
    fail "failed path exited 0: $(cat "$TMP/out")"
fi
grep -q 'failed to load' "$TMP/out" || fail "failed path did not report the failure: $(cat "$TMP/out")"
grep -q 'caused by' "$TMP/out" || fail "failed path did not print the cause: $(cat "$TMP/out")"

# No --probe and no default config: boot without a load check, exit 0.
export XDG_CONFIG_HOME="$TMP/noconfig"
mkdir -p "$XDG_CONFIG_HOME"
if ! "$RESTART" --timeout 5 >"$TMP/out" 2>&1; then
    fail "no-default-config path exited nonzero: $(cat "$TMP/out")"
fi
grep -q 'without a load check' "$TMP/out" \
    || fail "no-default-config path did not note the skipped check: $(cat "$TMP/out")"
unset XDG_CONFIG_HOME

# Argument errors are exit 2.
if "$RESTART" --probe "$CFG" --timeout >/dev/null 2>&1; then fail "--timeout without a value exited 0"; fi
if "$RESTART" --probe "$TMP/nope" >/dev/null 2>&1; then fail "missing shell.qml exited 0"; fi

echo "restart: ok"
