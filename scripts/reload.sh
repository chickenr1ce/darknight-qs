#!/usr/bin/env bash
# reload.sh — force a content-watch reload and verify both generations.
#
# The shell watches file content, so `touch` never reloads. This appends a
# newline to shell.qml (triggering reload N), waits for it, truncates the
# file back to its original size (triggering reload N+1, preserving any
# uncommitted edits — never `git checkout -- shell.qml`), waits again, then
# fails if either generation logged an error signature. Passive like
# check-live-log.sh: it never boots an instance and never claims the bus.
# Usage: scripts/reload.sh [--config DIR] [--timeout SECONDS]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$ROOT"
TIMEOUT=30

while [[ $# -gt 0 ]]; do
    case "$1" in
        --config) CONFIG="$2"; shift 2 ;;
        --timeout) TIMEOUT="$2"; shift 2 ;;
        *) echo "reload: unknown arg $1" >&2; exit 2 ;;
    esac
done

SHELL_QML="$CONFIG/shell.qml"
[[ -f "$SHELL_QML" ]] || { echo "reload: no $SHELL_QML" >&2; exit 2; }

# Same error signatures as scripts/check-live-log.sh.
PATTERN='Failed to load configuration|Failed to open file|recursive rearrange|is not a type|ReferenceError|TypeError|Binding loop detected|Cannot read property'

LOG=""
for candidate in /run/user/1000/quickshell/by-id/*/log.log; do
    [[ -f "$candidate" ]] || continue
    if grep -q "Launching config: \"$SHELL_QML\"" "$candidate" 2>/dev/null; then
        if [[ -z "$LOG" || "$candidate" -nt "$LOG" ]]; then
            LOG="$candidate"
        fi
    fi
done
[[ -n "$LOG" ]] || { echo "reload: no live log for $SHELL_QML; boot the instance first" >&2; exit 1; }

last_gen() {
    awk '/Launching config:|Reloading configuration/{last=NR} END{print last+0}' "$LOG"
}

wait_gen() {
    local prev="$1" start gen now
    start="$(date +%s)"
    while true; do
        gen="$(last_gen)"
        if [[ "$gen" -gt "$prev" ]]; then
            echo "$gen"
            return 0
        fi
        now="$(date +%s)"
        if (( now - start >= TIMEOUT )); then
            echo "reload: timed out after ${TIMEOUT}s waiting for a reload in $LOG" >&2
            exit 1
        fi
        sleep 0.5
    done
}

check_range() {
    local from="$1" to="$2" hits
    [[ "$to" -gt "$from" ]] || return 0
    hits="$(sed -n "$((from + 1)),${to}p" "$LOG" | grep -E "$PATTERN" || true)"
    if [[ -n "$hits" ]]; then
        echo "$hits" | head -10 >&2
        return 1
    fi
}

PREV="$(last_gen)"
SIZE="$(stat -c %s "$SHELL_QML")"

printf '\n' >>"$SHELL_QML"
GEN1="$(wait_gen "$PREV")"

truncate -s "$SIZE" "$SHELL_QML"
GEN2="$(wait_gen "$GEN1")"

TOTAL="$(wc -l <"$LOG")"
FAILED=0
check_range "$GEN1" "$((GEN2 - 1))" || FAILED=1
check_range "$GEN2" "$TOTAL" || FAILED=1

if [[ "$FAILED" -ne 0 ]]; then
    echo "reload: FAIL, error signatures in $LOG" >&2
    exit 1
fi
echo "reload: clean (generations $GEN1, $GEN2 in $LOG)"
