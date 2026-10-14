#!/usr/bin/env bash
# Headless verification gate. Runs every static gate and reports all failures
# before exiting nonzero. The toast smoke gate is deliberately separate: it
# boots its own instance and claims the notification bus.
# A failed check's full output is kept at ${TMPDIR:-/tmp}/qs-check-<label>.log
# (override the directory with QS_CHECK_KEEP_DIR), because $TMP is deleted on
# exit and a one-off failure otherwise leaves nothing to diagnose.
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
TMP="$(mktemp -d "${TMPDIR:-/tmp}/qs-check-XXXXXX")"
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
        local keep="${QS_CHECK_KEEP_DIR:-${TMPDIR:-/tmp}}"
        keep="$keep/qs-check-$(echo "$label" | tr ' ' '-').log"
        if mkdir -p "$(dirname "$keep")" 2>/dev/null && cp "$out" "$keep" 2>/dev/null; then
            echo "     kept: $keep"
        else
            echo "     warning: could not keep the output at $keep" >&2
        fi
        FAILED+=("$label")
    fi
}

run "type lint" ./scripts/lint.sh
run "review lint" ./scripts/lint-review.sh
run "shell lint" ./scripts/lint-shell.sh
run "conventions" ./scripts/lint-conventions.sh
run "conventions test" ./scripts/test-lint-conventions.sh
run "lint imports" ./scripts/test-lint-imports.sh
run "panel logic" ./scripts/test-panel-logic.sh
run "coalesced run" ./scripts/test-coalesced-run.sh
run "theme background" ./scripts/test-theme-background.sh
run "app launcher" ./scripts/test-app-launcher.sh
run "workspaces" ./scripts/test-workspaces.sh
run "tray menu" ./scripts/test-tray-menu.sh
run "qs-theme" ./scripts/test-qs-theme.sh
run "seed-themes" ./scripts/test-seed-themes.sh
run "seed-btop-theme" ./scripts/test-seed-btop-theme.sh
run "wire-themed-apps" ./scripts/test-wire-themed-apps.sh
run "dashboard data" ./scripts/test-dashboard-data.sh
run "spotify connect" ./scripts/test-spotify-connect.sh
run "calendar clock" ./scripts/test-calendar-clock.sh
run "calendar fetch" ./scripts/test-calendar-fetch.sh
run "instance" ./scripts/test-instance.sh
run "live-log test" ./scripts/test-live-log.sh
run "restart" ./scripts/test-restart.sh
run "boot check" ./scripts/test-boot-check.sh
run "live log" ./scripts/check-live-log.sh

echo
if [[ ${#FAILED[@]} -gt 0 ]]; then
    echo "check: FAIL (${FAILED[*]})"
    exit 1
fi
echo "check: all gates ok"
