#!/usr/bin/env bash
# Shell lint for the repo's scripts, via shellcheck at warning severity.
# Shellcheck is optional: without it the gate skips (like check-live-log), so the
# rest of scripts/check.sh still runs. Install it with `pacman -S shellcheck`.
# Only warnings and errors fail the gate; shellcheck's notes (SC2016 and the
# rest, mostly intentional single-quoted snippets) do not.
set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 2

if ! command -v shellcheck >/dev/null 2>&1; then
    echo "lint-shell: shellcheck not installed, skipping (install package: shellcheck)"
    exit 0
fi

mapfile -t FILES < <(
    git ls-files '*.sh' '.githooks/*'
    git ls-files --others --exclude-standard '*.sh' '.githooks/*'
)
if [ "${#FILES[@]}" -eq 0 ]; then
    echo "lint-shell: no shell scripts"
    exit 0
fi

if shellcheck --severity=warning -- "${FILES[@]}"; then
    echo "lint-shell: ok (${#FILES[@]} files)"
else
    echo "lint-shell: shellcheck reported warnings" >&2
    exit 1
fi
