#!/usr/bin/env bash
# boot-check.sh — boot a config in a throwaway Quickshell and report whether it
# loads.
#
# The headless gate (scripts/check.sh) never boots, so a config that fails to
# load — a missing module import, a bad qmldir entry — passes it. This is the
# observed boot that catches that class: the shell logs "Configuration Loaded"
# or a "Failed to load configuration" with its `caused by` chain.
#
# The throwaway runs under its own D-Bus session (dbus-run-session), so it does
# not take org.freedesktop.Notifications from the running shell. It still uses
# the live Wayland display, so it needs a session; with none it skips (exit 0).
# Usage: scripts/boot-check.sh [CONFIG_DIR] [--timeout SECONDS]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$ROOT"
TIMEOUT=20

while [[ $# -gt 0 ]]; do
    case "$1" in
        --timeout)
            [[ $# -ge 2 ]] || { echo "boot-check: --timeout needs a value" >&2; exit 2; }
            TIMEOUT="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: scripts/boot-check.sh [CONFIG_DIR] [--timeout SECONDS]" >&2
            exit 0 ;;
        -*)
            echo "boot-check: unknown arg $1" >&2; exit 2 ;;
        *)
            [[ "$CONFIG" == "$ROOT" ]] || { echo "boot-check: only one CONFIG_DIR" >&2; exit 2; }
            CONFIG="$1"; shift ;;
    esac
done

CONFIG="$(readlink -f "$CONFIG")"
[[ -f "$CONFIG/shell.qml" ]] || { echo "boot-check: no $CONFIG/shell.qml" >&2; exit 2; }

command -v quickshell >/dev/null 2>&1 || { echo "boot-check: quickshell not found; skipping" >&2; exit 0; }
if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    echo "boot-check: no Wayland session; skipping" >&2
    exit 0
fi
command -v dbus-run-session >/dev/null 2>&1 || { echo "boot-check: dbus-run-session not found; skipping" >&2; exit 0; }

# Same error signatures as scripts/check-live-log.sh.
PATTERN='Failed to load configuration|Failed to open file|recursive rearrange|is not a type|ReferenceError|TypeError|Binding loop detected|Cannot read property'

LOG="$(mktemp "${TMPDIR:-/tmp}/qs-boot-XXXXXX.log")"
trap 'rm -f "$LOG"' EXIT

# Boot the config under a private session bus. The inner shell owns the pid, so
# the check stops exactly this instance and the bus dies with it. The surrounding
# redirect drops the portal chatter the private bus activates; quickshell's own
# output goes to $LOG.
dbus-run-session -- bash -s "$CONFIG" "$TIMEOUT" "$LOG" >/dev/null 2>&1 <<'INNER' || true
config="$1"
limit="$2"
log="$3"
quickshell -p "$config" >"$log" 2>&1 </dev/null &
qspid=$!
for _ in $(seq 1 $((limit * 2))); do
    kill -0 "$qspid" 2>/dev/null || break
    grep -q 'Configuration Loaded' "$log" && break
    grep -q 'Failed to load configuration' "$log" && break
    sleep 0.5
done
kill "$qspid" 2>/dev/null || true
wait "$qspid" 2>/dev/null || true
INNER

if grep -q 'Failed to load configuration' "$LOG"; then
    echo "boot-check: FAIL, $CONFIG failed to load" >&2
    grep -A5 'Failed to load configuration' "$LOG" | sed 's/^/boot-check: /' >&2
    exit 1
fi
if ! grep -q 'Configuration Loaded' "$LOG"; then
    echo "boot-check: FAIL, no load result for $CONFIG within ${TIMEOUT}s" >&2
    tail -10 "$LOG" | sed 's/^/boot-check: /' >&2
    exit 1
fi
HITS="$(grep -E "$PATTERN" "$LOG" || true)"
if [[ -n "$HITS" ]]; then
    echo "boot-check: FAIL, error signatures after load in $CONFIG" >&2
    echo "$HITS" | head -10 | sed 's/^/boot-check: /' >&2
    exit 1
fi
echo "boot-check: $CONFIG loaded"
