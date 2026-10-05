#!/usr/bin/env bash
# Headless verification gate. Runs every static gate and reports all failures
# before exiting nonzero. The toast smoke gate is deliberately separate: it
# boots its own instance and claims the notification bus.
set -uo pipefail

# Git exports GIT_DIR, GIT_WORK_TREE, and GIT_INDEX_FILE into hooks. A gate
# script that runs `git -C <tempdir> ...` (the test scripts do) would otherwise
# target this repository and corrupt it, so drop the hook environment and let
# every git command discover its own repository.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX
unset GIT_OBJECT_DIRECTORY GIT_COMMON_DIR GIT_ALTERNATE_OBJECT_DIRECTORIES

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 2

FAILED=()
TMP="$(mktemp -d /tmp/opencode/check-XXXXXX)"
trap 'rm -rf "$TMP"' EXIT

run() {
    local label="$1"
    shift
    local out
    out="$TMP/$(echo "$label" | tr ' ' '-')"
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
run "shell lint" ./scripts/lint-shell.sh
run "panel logic" ./scripts/test-panel-logic.sh
run "qs-theme" ./scripts/test-qs-theme.sh
run "seed-themes" ./scripts/test-seed-themes.sh
run "seed-btop-theme" ./scripts/test-seed-btop-theme.sh
run "dashboard data" ./scripts/test-dashboard-data.sh
run "spotify connect" ./scripts/test-spotify-connect.sh
run "calendar clock" ./scripts/test-calendar-clock.sh
run "calendar fetch" ./scripts/test-calendar-fetch.sh
run "instance" ./scripts/test-instance.sh
run "live-log test" ./scripts/test-live-log.sh
run "live log" ./scripts/check-live-log.sh

echo
if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo "check: FAIL (${FAILED[*]})"
    exit 1
fi
echo "check: all gates ok"
