#!/usr/bin/env bash
# restart.sh — restart the quickshell instance (SUPER + CTRL + Q).
# Same shape as the old waybar launcher: stop what's running, start detached.
# With --probe DIR, boot that worktree's config (`quickshell -p DIR`) instead
# of the daily one, for live-testing unmerged changes.
# Usage: scripts/restart.sh [--probe DIR]
set -euo pipefail

PROBE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --probe)
            [[ $# -ge 2 ]] || { echo "restart: --probe needs a value" >&2; exit 2; }
            PROBE="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: scripts/restart.sh [--probe DIR]" >&2; exit 0 ;;
        *) echo "restart: unknown arg $1" >&2; exit 2 ;;
    esac
done

if [[ -n "$PROBE" ]]; then
    PROBE="$(readlink -f "$PROBE")"
    [[ -f "$PROBE/shell.qml" ]] || { echo "restart: no $PROBE/shell.qml" >&2; exit 2; }
fi

pkill -x quickshell 2>/dev/null || true

# Wait for the old instance to exit so the new one can claim
# the notification bus and layer surfaces.
for _ in $(seq 1 20); do
    pgrep -x quickshell >/dev/null 2>&1 || break
    sleep 0.1
done

if [[ -n "$PROBE" ]]; then
    setsid quickshell -p "$PROBE" >/dev/null 2>&1 < /dev/null &
else
    setsid quickshell >/dev/null 2>&1 < /dev/null &
fi
