#!/usr/bin/env bash
# Fail on error signatures in the live log of a running test instance.
#
# Passive by design: it never boots an instance and never claims the bus.
# With --config it skips unless an instance is running, so a stopped config's
# newest log is never read as live; an explicit --log is always scanned.
# Point it at the newest by-id log for CONFIG and check only lines after the
# last launch or reload, so stale warnings from prior code cannot fail it.
# Usage: scripts/check-live-log.sh [--config DIR] [--log FILE]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$ROOT"
LOG=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)
            [[ $# -ge 2 ]] || { echo "check-live-log: --config needs a value" >&2; exit 2; }
            CONFIG="$2"; shift 2 ;;
        --log)
            [[ $# -ge 2 ]] || { echo "check-live-log: --log needs a value" >&2; exit 2; }
            LOG="$2"; shift 2 ;;
        *) echo "check-live-log: unknown arg $1" >&2; exit 2 ;;
    esac
done

fail() { echo "check-live-log FAIL: $*" >&2; exit 1; }

if [[ -z "$LOG" ]]; then
    if ! "$ROOT/scripts/instance.sh" pid --config "$CONFIG" >/dev/null 2>&1; then
        echo "check-live-log: SKIP, no running instance for $CONFIG; boot the test instance first"
        exit 0
    fi
    LOG="$("$ROOT/scripts/instance.sh" log --config "$CONFIG" 2>/dev/null || true)"
    if [[ -z "$LOG" ]]; then
        echo "check-live-log: SKIP, no live log for $CONFIG/shell.qml; boot the test instance first"
        exit 0
    fi
fi

PATTERN='Failed to load configuration|Failed to open file|recursive rearrange|is not a type|ReferenceError|TypeError|Binding loop detected|Cannot read property'

if grep -qE 'Launching config:|Reloading configuration' "$LOG"; then
    LAST="$(awk '/Launching config:|Reloading configuration/{last=NR} END{print last+0}' "$LOG")"
    HITS="$(tail -n "+$((LAST + 1))" "$LOG" | grep -E "$PATTERN" || true)"
else
    HITS="$(grep -E "$PATTERN" "$LOG" || true)"
fi

if [[ -n "$HITS" ]]; then
    echo "$HITS" | head -10 >&2
    fail "error signatures in $LOG"
fi

echo "check-live-log: clean ($LOG)"
