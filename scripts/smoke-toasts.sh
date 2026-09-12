#!/usr/bin/env bash
# Smoke test for the notification toast layer (ticket 02).
#
# Run a throwaway quickshell on this worktree, fire test notifications, assert
# the instance survives and the runtime log is free of TypeErrors. Requires a
# running Wayland session (Hyprland); the throwaway instance owns
# org.freedesktop.Notifications for the duration.
set -euo pipefail

WORKTREE="$(cd "$(dirname "$0")/.." && pwd)"
LOG="$(mktemp /tmp/qs-smoke-XXXXXX.log)"
QSPID=""

cleanup() {
    if [[ -n "$QSPID" ]] && kill -0 "$QSPID" 2>/dev/null; then
        kill "$QSPID"
    fi
    rm -f "$LOG"
}
trap cleanup EXIT

fail() { echo "SMOKE FAIL: $*" >&2; exit 1; }

# No trailing slash on the path (stray-instance history: see ticket 02).
quickshell -p "$WORKTREE" >"$LOG" 2>&1 &
QSPID=$!

# Wait for config load (or early death).
for _ in $(seq 1 20); do
    kill -0 "$QSPID" 2>/dev/null || fail "instance died during startup; log: $LOG"
    grep -q "Configuration Loaded" "$LOG" && break
    sleep 0.5
done
grep -q "Configuration Loaded" "$LOG" || fail "config never loaded; log: $LOG"

# Normal toast: exercises delegate creation, decay animator, auto-expiry.
notify-send -a "smoke-test" "Smoke normal" "Auto-expires in 2s" -t 2000
# Sticky toast: exercises the critical path (tint, no decay, hover probe).
notify-send -u critical -a "smoke-test" "Smoke critical" "Sticky until dismissed" -t 100
sleep 3

kill -0 "$QSPID" 2>/dev/null || fail "instance died after toasts; log: $LOG"

if grep -qE "TypeError|Cannot read property|\bnull\b" "$LOG"; then
    grep -E "TypeError|Cannot read property|\bnull\b" "$LOG" | head -5
    fail "runtime errors in log; full log: $LOG"
fi

echo "SMOKE PASS (log: $LOG)"
