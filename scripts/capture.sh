#!/usr/bin/env bash
# capture.sh — screenshot a panel from a throwaway Quickshell, without touching
# the running shell.
#
# Boots CONFIG the way scripts/boot-check.sh does (private D-Bus session, live
# Wayland display), turns on the devprobe and reduced motion, makes the IPC call
# after `--` to open the surface, reads the DevGeometry snapshot GEOM, and grabs
# its screen rectangle with grim. The running shell keeps its bus, its panels,
# and its state; the throwaway's windows draw over it only for the capture.
#
# Prints the PNG path, then the snapshot JSON. A GEOM whose window is not
# anchored top-left has no screen rectangle, so the whole first screen is
# captured instead.
#
# Usage: scripts/capture.sh [--out FILE] [--pad PX] [--settle SECONDS]
#                           [--timeout SECONDS] CONFIG GEOM -- IPC-CALL...
# Example: scripts/capture.sh --pad 12 . audio.card -- audio toggle
set -euo pipefail

OUT=""
PAD=0
SETTLE=1
TIMEOUT=20
POSITIONAL=()
CALL=()

usage() {
    echo "Usage: scripts/capture.sh [--out FILE] [--pad PX] [--settle SECONDS] [--timeout SECONDS] CONFIG GEOM -- IPC-CALL..." >&2
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --out|--pad|--settle|--timeout)
            [[ $# -ge 2 ]] || { echo "capture: $1 needs a value" >&2; exit 2; }
            case "$1" in
                --out) OUT="$2" ;;
                --pad) PAD="$2" ;;
                --settle) SETTLE="$2" ;;
                --timeout) TIMEOUT="$2" ;;
            esac
            shift 2 ;;
        -h|--help) usage; exit 0 ;;
        --) shift; CALL=("$@"); break ;;
        *) POSITIONAL+=("$1"); shift ;;
    esac
done

[[ ${#POSITIONAL[@]} -eq 2 ]] || { usage; exit 2; }
[[ ${#CALL[@]} -ge 2 ]] || { echo "capture: give the IPC call that opens the surface after --, e.g. -- audio toggle" >&2; exit 2; }
[[ "$PAD" =~ ^[0-9]+$ ]] || { echo "capture: --pad must be a whole number of pixels" >&2; exit 2; }

CONFIG="$(readlink -f "${POSITIONAL[0]}")"
GEOM="${POSITIONAL[1]}"
[[ -f "$CONFIG/shell.qml" ]] || { echo "capture: no $CONFIG/shell.qml" >&2; exit 2; }
[[ -n "${WAYLAND_DISPLAY:-}" ]] || { echo "capture: no Wayland session" >&2; exit 2; }
for tool in quickshell dbus-run-session grim python3; do
    command -v "$tool" >/dev/null 2>&1 || { echo "capture: $tool not found" >&2; exit 2; }
done

if [[ -z "$OUT" ]]; then
    mkdir -p "${TMPDIR:-/tmp}/qs-capture"
    OUT="${TMPDIR:-/tmp}/qs-capture/${GEOM}-$(date +%H%M%S).png"
fi
OUT="$(readlink -f "$OUT")"

WORK="$(mktemp -d "${TMPDIR:-/tmp}/qs-capture-XXXXXX")"
[[ -n "${QS_CAPTURE_KEEP:-}" ]] || trap 'rm -rf "$WORK"' EXIT

# The inner shell owns the instance pid, so it stops exactly this instance and
# the private bus dies with it. Every step's result lands in $WORK for the outer
# shell to report.
dbus-run-session -- bash -s "$CONFIG" "$GEOM" "$PAD" "$SETTLE" "$TIMEOUT" "$OUT" "$WORK" "${CALL[@]}" >/dev/null 2>&1 <<'INNER' || true
config="$1"; geom="$2"; pad="$3"; settle="$4"; limit="$5"; out="$6"; work="$7"
shift 7
QUICKSHELL_DEV_PROBE=1 quickshell -p "$config" >"$work/log" 2>&1 </dev/null &
qspid=$!
ipc() { quickshell ipc --pid "$qspid" call "$@"; }
finish() { kill "$qspid" 2>/dev/null || true; wait "$qspid" 2>/dev/null || true; exit 0; }

for _ in $(seq 1 $((limit * 2))); do
    kill -0 "$qspid" 2>/dev/null || { echo "instance exited before loading" >"$work/error"; finish; }
    grep -q 'Configuration Loaded' "$work/log" && break
    grep -q 'Failed to load configuration' "$work/log" && { echo "config failed to load" >"$work/error"; finish; }
    sleep 0.5
done
grep -q 'Configuration Loaded' "$work/log" || { echo "no load result within ${limit}s" >"$work/error"; finish; }

# The devprobe target registers a moment after load.
for _ in $(seq 1 20); do
    ipc devprobe setReducedMotion true >/dev/null 2>&1 && break
    sleep 0.25
done
ipc "$@" >"$work/call" 2>&1 || { echo "IPC call failed: $*" >"$work/error"; cat "$work/call" >>"$work/error"; finish; }
# Wait for the surface to be shown and placed, then let it settle and re-read.
for _ in $(seq 1 20); do
    ipc devprobe geom "$geom" >"$work/geom" 2>&1 || true
    grep -q '"visible":true' "$work/geom" && ! grep -q '"screenRect":null' "$work/geom" && break
    sleep 0.25
done
sleep "$settle"
ipc devprobe geom "$geom" >"$work/geom" 2>&1 || true

rect="$(python3 - "$work/geom" "$pad" <<'PY'
import json, sys
try:
    snap = json.load(open(sys.argv[1]))
except ValueError:
    sys.exit(0)
pad = int(sys.argv[2])
rect = snap.get("screenRect") if snap.get("found") else None
if rect:
    print(f"{rect['x'] - pad},{rect['y'] - pad} {rect['width'] + 2 * pad}x{rect['height'] + 2 * pad}")
PY
)"
if [[ -n "$rect" ]]; then
    grim -g "$rect" "$out" 2>"$work/grim" || echo "grim failed" >"$work/error"
else
    grim "$out" 2>"$work/grim" || echo "grim failed" >"$work/error"
    echo "full screen" >"$work/fallback"
fi
finish
INNER

if [[ -f "$WORK/error" ]]; then
    echo "capture: FAIL, $(head -1 "$WORK/error")" >&2
    tail -n +2 "$WORK/error" | sed 's/^/capture: /' >&2
    grep -E 'Failed to load|ReferenceError|TypeError|caused by' "$WORK/log" 2>/dev/null | head -10 | sed 's/^/capture: /' >&2 || true
    exit 1
fi
[[ -s "$OUT" ]] || { echo "capture: FAIL, no image written" >&2; exit 1; }
if [[ -f "$WORK/fallback" ]]; then
    echo "capture: $GEOM has no screen rectangle (not registered, or its window is not anchored top-left); captured the full screen" >&2
fi
echo "$OUT"
cat "$WORK/geom" 2>/dev/null || true
