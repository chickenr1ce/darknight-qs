#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLOCK="$ROOT/scripts/calendar-clock.py"
NOW="2026-01-15T11:00:00+00:00"

export TZ=UTC

OUT="$(python3 "$CLOCK" --now "$NOW" UTC Europe/Berlin Asia/Singapore)"
[[ "$OUT" == *"UTC=11:00 +0"* ]] || { echo "clock: UTC wrong: $OUT" >&2; exit 1; }
[[ "$OUT" == *"Europe/Berlin=12:00 +60"* ]] || { echo "clock: Berlin wrong: $OUT" >&2; exit 1; }
[[ "$OUT" == *"Asia/Singapore=19:00 +480"* ]] || { echo "clock: Singapore wrong: $OUT" >&2; exit 1; }
echo "calendar-clock: zone conversion ok"

OUT="$(python3 "$CLOCK" --now "$NOW" "Nope/Nowhere")"
[[ "$OUT" == "Nope/Nowhere=" ]] || { echo "clock: unknown zone wrong: $OUT" >&2; exit 1; }
echo "calendar-clock: unknown-zone blank ok"

OUT="$(python3 "$CLOCK" --now "$NOW")"
[[ -z "$OUT" ]] || { echo "clock: expected empty output: $OUT" >&2; exit 1; }
echo "calendar-clock: all ok"

python3 - "$ROOT/assets/iana-zones.json" << "EOF2"
import json, sys
zones = json.load(open(sys.argv[1]))
assert isinstance(zones, list) and len(zones) > 100, "zone list too small"
assert zones == sorted(zones), "zone list not sorted"
assert {"UTC", "Europe/Berlin", "Asia/Singapore"} <= set(zones), "known zones missing"
EOF2
echo "iana zone list ok"
