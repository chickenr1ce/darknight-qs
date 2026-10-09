#!/usr/bin/env bash
# Headless gate for scripts/boot-check.sh.
#
# Stubs quickshell on PATH and sets WAYLAND_DISPLAY, so the gate drives the
# boot, wait, and report paths without a Wayland session. Skips when
# dbus-run-session is not installed, matching the script's own skip.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() { echo "boot-check FAIL: $*" >&2; exit 1; }

if ! command -v dbus-run-session >/dev/null 2>&1; then
    echo "boot-check: dbus-run-session not found, skipping"
    exit 0
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/qs-bootcheck-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

STUB="$TMP/bin"
mkdir -p "$STUB"
cat >"$STUB/quickshell" <<'STUBEOF'
#!/usr/bin/env bash
echo 'Launching config: test'
case "${QS_STUB_MODE:-ok}" in
    ok) echo 'Configuration Loaded' ;;
    fail)
        echo 'Failed to load configuration'
        echo '  caused by @services/Broken.qml[3:5]: Broken is not a type'
        ;;
    dirty)
        echo 'Configuration Loaded'
        echo 'TypeError: Cannot read property "x" of null'
        ;;
    anchor)
        echo 'Configuration Loaded'
        echo "QML SmoothWheel at @components/Overlay.qml[4:5]: Cannot anchor to an item that isn't a parent or sibling."
        echo '@windows/List.qml[7:9]: Unable to assign [undefined] to QString'
        ;;
esac
while :; do sleep 1; done
STUBEOF
chmod +x "$STUB/quickshell"
export PATH="$STUB:$PATH"
export WAYLAND_DISPLAY=test-wayland

CFG="$TMP/config"
mkdir -p "$CFG"
touch "$CFG/shell.qml"

BOOT="$ROOT/scripts/boot-check.sh"

# Loaded path: exit 0 and a loaded report.
if ! QS_STUB_MODE=ok "$BOOT" "$CFG" --timeout 5 >"$TMP/out" 2>&1; then
    fail "ok path exited nonzero: $(cat "$TMP/out")"
fi
grep -q 'loaded' "$TMP/out" || fail "ok path did not report loaded: $(cat "$TMP/out")"

# Failed-load path: nonzero, with the cause.
if QS_STUB_MODE=fail "$BOOT" "$CFG" --timeout 5 >"$TMP/out" 2>&1; then
    fail "fail path exited 0: $(cat "$TMP/out")"
fi
grep -q 'failed to load' "$TMP/out" || fail "fail path did not report the failure: $(cat "$TMP/out")"

# Loaded but dirty: the error scan fails it.
if QS_STUB_MODE=dirty "$BOOT" "$CFG" --timeout 5 >"$TMP/out" 2>&1; then
    fail "dirty path exited 0: $(cat "$TMP/out")"
fi
grep -q 'TypeError' "$TMP/out" || fail "dirty path did not surface the error: $(cat "$TMP/out")"

# The anchor and undefined-assignment signatures are load-clean but still fail.
if QS_STUB_MODE=anchor "$BOOT" "$CFG" --timeout 5 >"$TMP/out" 2>&1; then
    fail "anchor path exited 0: $(cat "$TMP/out")"
fi
grep -q 'Cannot anchor' "$TMP/out" || fail "anchor path did not surface the anchor warning: $(cat "$TMP/out")"
grep -q 'Unable to assign' "$TMP/out" || fail "anchor path did not surface the assignment warning: $(cat "$TMP/out")"

# No Wayland session: skip with exit 0.
if ! env -u WAYLAND_DISPLAY "$BOOT" "$CFG" >"$TMP/out" 2>&1; then
    fail "no-Wayland path exited nonzero"
fi
grep -qi 'skipping' "$TMP/out" || fail "no-Wayland path did not skip: $(cat "$TMP/out")"

# Argument errors are exit 2.
if "$BOOT" "$CFG" --timeout >/dev/null 2>&1; then fail "--timeout without a value exited 0"; fi
if "$BOOT" "$TMP/nope" >/dev/null 2>&1; then fail "missing shell.qml exited 0"; fi

echo "boot-check: ok"
