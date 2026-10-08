#!/usr/bin/env bash
# restart.sh — restart the quickshell instance (SUPER + CTRL + Q).
# Same shape as the old waybar launcher: stop what's running, start detached,
# then wait for the new instance's log and report whether the config loaded.
# Guarantees one polkit agent: an old instance must exit before a new one starts, and a failed registration fails the run.
# With --probe DIR, boot that worktree's config (`quickshell -p DIR`) instead
# of the daily one, for live-testing unmerged changes.
# Usage: scripts/restart.sh [--probe DIR] [--timeout SECONDS]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TIMEOUT=15
PROBE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --probe)
            [[ $# -ge 2 ]] || { echo "restart: --probe needs a value" >&2; exit 2; }
            PROBE="$2"; shift 2 ;;
        --timeout)
            [[ $# -ge 2 ]] || { echo "restart: --timeout needs a value" >&2; exit 2; }
            TIMEOUT="$2"; shift 2 ;;
        -h|--help)
            echo "Usage: scripts/restart.sh [--probe DIR] [--timeout SECONDS]" >&2; exit 0 ;;
        *) echo "restart: unknown arg $1" >&2; exit 2 ;;
    esac
done

VERIFY_CONFIG=""
if [[ -n "$PROBE" ]]; then
    PROBE="$(readlink -f "$PROBE")"
    [[ -f "$PROBE/shell.qml" ]] || { echo "restart: no $PROBE/shell.qml" >&2; exit 2; }
    VERIFY_CONFIG="$PROBE"
else
    # No --probe: quickshell runs the default config at $XDG_CONFIG_HOME/quickshell.
    # Verify only when that config exists; a named config has no path to resolve.
    DEFAULT_CONFIG="$(readlink -f "${XDG_CONFIG_HOME:-$HOME/.config}/quickshell")"
    if [[ -f "$DEFAULT_CONFIG/shell.qml" ]]; then
        VERIFY_CONFIG="$DEFAULT_CONFIG"
    else
        echo "restart: no default config at $DEFAULT_CONFIG; booting without a load check" >&2
    fi
fi

# The newest log for this config before the restart. The new instance writes a
# newer one, so reading that avoids reporting the outgoing instance's result.
BEFORE=""
if [[ -n "$VERIFY_CONFIG" ]]; then
    BEFORE="$("$SCRIPT_DIR/instance.sh" log --config "$VERIFY_CONFIG" 2>/dev/null || true)"
fi

pkill -x quickshell 2>/dev/null || true

# Wait for the old instance to exit so the new one can claim the notification
# bus, layer surfaces, and the polkit agent. A surviving process still owns the
# agent, so escalate to KILL before refusing to start a second instance.
for _ in $(seq 1 50); do
    pgrep -x quickshell >/dev/null 2>&1 || break
    sleep 0.1
done

if pgrep -x quickshell >/dev/null 2>&1; then
    pkill -KILL -x quickshell 2>/dev/null || true
    for _ in $(seq 1 20); do
        pgrep -x quickshell >/dev/null 2>&1 || break
        sleep 0.1
    done
fi

if pgrep -x quickshell >/dev/null 2>&1; then
    echo "restart: old quickshell instance did not exit; not starting a second one" >&2
    exit 1
fi

if [[ -n "$PROBE" ]]; then
    setsid quickshell -p "$PROBE" >/dev/null 2>&1 < /dev/null &
else
    setsid quickshell >/dev/null 2>&1 < /dev/null &
fi

[[ -n "$VERIFY_CONFIG" ]] || exit 0

# Wait for the new instance's log, then report whether it loaded.
LOG=""
for _ in $(seq 1 $((TIMEOUT * 2))); do
    LOG="$("$SCRIPT_DIR/instance.sh" log --config "$VERIFY_CONFIG" 2>/dev/null || true)"
    [[ -n "$LOG" && "$LOG" != "$BEFORE" ]] && break
    LOG=""
    sleep 0.5
done

if [[ -z "$LOG" ]]; then
    echo "restart: no log for $VERIFY_CONFIG within ${TIMEOUT}s" >&2
    exit 1
fi
if grep -q 'Failed to load configuration' "$LOG"; then
    echo "restart: $VERIFY_CONFIG failed to load" >&2
    grep -A5 'Failed to load configuration' "$LOG" | sed 's/^/restart: /' >&2
    exit 1
fi
if grep -q 'Configuration Loaded' "$LOG"; then
    # Give the polkit agent its registration window; a stale agent makes the
    # new registration fail, which would leave polkit prompts unanswered.
    for _ in $(seq 1 20); do
        if grep -qF 'failed to register listener' "$LOG"; then
            break
        fi
        sleep 0.1
        LOG_NEW="$("$SCRIPT_DIR/instance.sh" log --config "$VERIFY_CONFIG" 2>/dev/null || true)"
        if [[ -n "$LOG_NEW" ]]; then
            LOG="$LOG_NEW"
        fi
    done
    if grep -qF 'failed to register listener' "$LOG"; then
        echo "restart: polkit agent failed to register (another agent already owns the session); polkit prompts will not appear" >&2
        grep -F 'failed to register listener' "$LOG" | sed 's/^/restart: /' >&2
        exit 1
    fi
    echo "restart: $VERIFY_CONFIG loaded"
    exit 0
fi
echo "restart: no load result for $VERIFY_CONFIG within ${TIMEOUT}s" >&2
exit 1
