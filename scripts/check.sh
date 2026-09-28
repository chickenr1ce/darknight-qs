#!/usr/bin/env bash
# Headless verification gate. Runs every static gate and reports all failures
# before exiting nonzero. The toast smoke gate is deliberately separate: it
# boots its own instance and claims the notification bus.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

FAILED=()
TMP="$(mktemp -d /tmp/opencode/check-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

run() {
    local label="$1"
    shift
    local out="$TMP/$(echo "$label" | tr ' ' '-')"
    if "$@" >"$out" 2>&1; then
        echo "ok   $label"
    else
        echo "FAIL $label"
        sed 's/^/     /' "$out"
        FAILED+=("$label")
    fi
}

run "type lint" ./scripts/lint.sh
run "review lint" ./scripts/lint-review.sh
run "panel logic" ./scripts/test-panel-logic.sh
run "dashboard data" ./scripts/test-dashboard-data.sh
run "spotify connect" ./scripts/test-spotify-connect.sh
run "calendar clock" ./scripts/test-calendar-clock.sh
run "calendar fetch" ./scripts/test-calendar-fetch.sh
run "live log" ./scripts/check-live-log.sh

echo
if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo "check: FAIL (${FAILED[*]})"
    exit 1
fi
echo "check: all gates ok"
