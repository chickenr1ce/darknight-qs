#!/usr/bin/env bash
# Headless gate for scripts/instance.sh.
#
# Points XDG_RUNTIME_DIR at a fixture runtime root with three by-id dirs, so the
# gate needs no live instance and never claims the notification bus. Asserts the
# config-scoped newest-log selection, the dir and list outputs, and the error
# paths.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() { echo "instance FAIL: $*" >&2; exit 1; }

TMP="$(mktemp -d /tmp/opencode/instance-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

export XDG_RUNTIME_DIR="$TMP/run"
BY_ID="$XDG_RUNTIME_DIR/quickshell/by-id"
mkdir -p "$BY_ID/aaa" "$BY_ID/bbb"

CFG_A="$TMP/config-a"
CFG_B="$TMP/config-b"
mkdir -p "$CFG_A" "$CFG_B"
touch "$CFG_A/shell.qml" "$CFG_B/shell.qml"

printf 'Launching config: "%s/shell.qml"\n' "$CFG_A" >"$BY_ID/aaa/log.log"
printf 'Launching config: "%s/shell.qml"\n' "$CFG_B" >"$BY_ID/bbb/log.log"

INST="$ROOT/scripts/instance.sh"

# help exits 0 and prints the usage line.
"$INST" help >/dev/null 2>&1 || fail "help did not exit 0"
"$INST" help 2>&1 | grep -q 'Usage: scripts/instance.sh' || fail "help missing usage"

# log and dir resolve the config's own dir.
[[ "$("$INST" log --config "$CFG_A")" == "$BY_ID/aaa/log.log" ]] || fail "log picked the wrong dir"
[[ "$("$INST" dir --config "$CFG_A")" == "$BY_ID/aaa" ]] || fail "dir picked the wrong dir"

# list maps each by-id dir to its config.
LIST="$("$INST" list)"
echo "$LIST" | grep -q "$BY_ID/aaa.*$CFG_A" || fail "list missing config-a"
echo "$LIST" | grep -q "$BY_ID/bbb.*$CFG_B" || fail "list missing config-b"

# A second log for the same config wins on mtime.
mkdir -p "$BY_ID/ccc"
printf 'Launching config: "%s/shell.qml"\n' "$CFG_A" >"$BY_ID/ccc/log.log"
touch -d '+1 minute' "$BY_ID/ccc/log.log"
[[ "$("$INST" log --config "$CFG_A")" == "$BY_ID/ccc/log.log" ]] || fail "newest log not chosen"

# A config with no runtime dir errors instead of guessing.
if "$INST" log --config "$TMP/nope" >/dev/null 2>&1; then fail "log exited 0 for an unknown config"; fi
if "$INST" dir --config "$TMP/nope" >/dev/null 2>&1; then fail "dir exited 0 for an unknown config"; fi
if "$INST" pid --config "$CFG_A" >/dev/null 2>&1; then fail "pid exited 0 with no running process"; fi

# Argument errors are exit 2.
if "$INST" log --config >/dev/null 2>&1; then fail "--config without a value exited 0"; fi
if "$INST" bogus >/dev/null 2>&1; then fail "unknown command exited 0"; fi

echo "instance: ok"
