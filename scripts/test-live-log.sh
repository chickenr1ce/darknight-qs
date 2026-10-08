#!/usr/bin/env bash
# Headless gate for scripts/check-live-log.sh.
#
# Points XDG_RUNTIME_DIR at a fixture runtime root so the gate needs no live
# instance and never claims the notification bus. Asserts the running-instance
# guard (a stopped config's newest log is skipped) and the error scan on an
# explicit log.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() { echo "live-log FAIL: $*" >&2; exit 1; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/qs-live-log-XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

export XDG_RUNTIME_DIR="$TMP/run"
BY_ID="$XDG_RUNTIME_DIR/quickshell/by-id"
mkdir -p "$BY_ID/aaa"

CFG="$TMP/config"
mkdir -p "$CFG"
touch "$CFG/shell.qml"

STALE="$BY_ID/aaa/log.log"
printf 'Launching config: "%s/shell.qml"\n' "$CFG" >"$STALE"
printf 'TypeError: Cannot read property "name" of null\n' >>"$STALE"

CHECK="$ROOT/scripts/check-live-log.sh"

# No running instance: the stale log is skipped, not failed on.
if ! OUT="$("$CHECK" --config "$CFG" 2>&1)"; then fail "stale log failed instead of skipping: $OUT"; fi
echo "$OUT" | grep -q 'SKIP' || fail "no SKIP for a stopped config: $OUT"

# An explicit log is scanned even without a running instance.
if "$CHECK" --log "$STALE" >/dev/null 2>&1; then fail "error signature in an explicit log did not fail"; fi

# A clean explicit log passes.
CLEAN="$BY_ID/aaa/clean.log"
printf 'Launching config: "%s/shell.qml"\n' "$CFG" >"$CLEAN"
if ! "$CHECK" --log "$CLEAN" >/dev/null 2>&1; then fail "clean log failed"; fi

echo "live-log: ok"
