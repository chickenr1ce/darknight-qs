#!/usr/bin/env bash
# update.sh — pull the latest main, re-check dependencies, restart the shell.
#
# The friend tracks main. A pull into the clone is enough for content changes:
# Quickshell reloads when watched file content changes. A structural change (a
# new file, qmldir, or import) is why a restart is still the reliable last step.
# Settings live under XDG state and cache, not the repo, so they survive. The
# dependency re-check re-seeds the bundled darknight theme into the theme root,
# so a changed bundled palette or background lands on update.
#
# Refuses a dirty tree so a pull never strands local work: commit or stash
# first. Works from any clone path. Usage: scripts/update.sh [--no-restart]
set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
RESTART=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-restart) RESTART=0 ;;
        -h|--help)
            cat <<EOF
update.sh — pull the latest main, re-check dependencies, restart the shell.

Usage: scripts/update.sh [--no-restart]

Options:
  --no-restart  pull and re-check dependencies, but do not restart the shell
  --help        this message
EOF
            exit 0 ;;
        *) echo "update: unknown arg $1" >&2; exit 2 ;;
    esac
    shift
done

say() { echo "update: $*"; }
die() { echo "update: $*" >&2; exit 1; }

cd "$ROOT"

git rev-parse --git-dir >/dev/null 2>&1 || die "not a git clone: $ROOT"

say "checking for local changes"
# Tracked modifications only: an untracked scratch file does not stop a
# fast-forward pull, so it must not block an update.
if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
    die "local changes present; commit or stash them, then rerun"
fi
say "tree clean"

branch="$(git branch --show-current)"
if [[ "$branch" != "main" ]]; then
    die "not on main (on ${branch:-detached HEAD}); run: git checkout main"
fi
say "on main"

say "pulling main (fast-forward only)"
if ! git pull --ff-only; then
    die "git pull --ff-only failed; resolve it by hand, then rerun"
fi

say "re-checking dependencies and refreshing bundled themes"
if ! "$ROOT/scripts/install.sh" --no-link; then
    die "dependency check failed; install the missing packages listed above, then rerun (shell not restarted)"
fi

if [[ "$RESTART" -eq 0 ]]; then
    say "skipping restart (--no-restart)"
    exit 0
fi

say "restarting the shell on $ROOT"
"$ROOT/scripts/restart.sh" --probe "$ROOT"
say "done"
