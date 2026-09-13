#!/usr/bin/env bash
# restart.sh — restart the quickshell instance (SUPER + CTRL + Q).
# Same shape as the old waybar launcher: stop what's running, start detached.
set -euo pipefail

pkill -x quickshell 2>/dev/null || true

# Wait for the old instance to exit so the new one can claim
# the notification bus and layer surfaces.
for _ in $(seq 1 20); do
    pgrep -x quickshell >/dev/null 2>&1 || break
    sleep 0.1
done

setsid quickshell >/dev/null 2>&1 < /dev/null &
