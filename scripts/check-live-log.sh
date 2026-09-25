#!/usr/bin/env bash
# Fail on error signatures in the live log of a running test instance.
#
# Passive by design: it never boots an instance and never claims the bus.
# Point it at the newest by-id log for CONFIG and check only lines after the
# last launch or reload, so stale warnings from prior code cannot fail it.
# Usage: scripts/check-live-log.sh [--config DIR] [--log FILE]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$ROOT"
LOG=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --config) CONFIG="$2"; shift 2 ;;
        --log) LOG="$2"; shift 2 ;;
        *) echo "check-live-log: unknown arg $1" >&2; exit 2 ;;
    esac
done

fail() { echo "check-live-log FAIL: $*" >&2; exit 1; }

if [[ -z "$LOG" ]]; then
    newest=""
    for candidate in /run/user/1000/quickshell/by-id/*/log.log; do
        [[ -f "$candidate" ]] || continue
        if grep -q "Launching config: \"$CONFIG/shell.qml\"" "$candidate" 2>/dev/null; then
            if [[ -z "$newest" || "$candidate" -nt "$newest" ]]; then
                newest="$candidate"
            fi
        fi
    done
    if [[ -z "$newest" ]]; then
        echo "check-live-log: SKIP, no live log for $CONFIG/shell.qml; boot the test instance first"
        exit 0
    fi
    LOG="$newest"
fi

PATTERN='Failed to load configuration|Failed to open file|recursive rearrange|is not a type|ReferenceError|TypeError|Binding loop detected|Cannot read property'

if grep -qE 'Launching config:|Reloading configuration' "$LOG"; then
    HITS="$(awk '/Launching config:|Reloading configuration/{skip=NR; seen=1} seen && NR>skip' "$LOG" \
        | grep -E "$PATTERN" || true)"
else
    HITS="$(grep -E "$PATTERN" "$LOG" || true)"
fi

if [[ -n "$HITS" ]]; then
    echo "$HITS" | head -10 >&2
    fail "error signatures in $LOG"
fi

echo "check-live-log: clean ($LOG)"
