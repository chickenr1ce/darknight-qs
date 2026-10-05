#!/bin/sh
# Seed a fallback btop retint theme so btop always lists it, even before
# ThemeService has rendered a palette.
#
# Usage: seed-btop-theme.sh <config-home> [repo-root]
#
# <config-home> is the XDG config home; the file lands at
# <config-home>/btop/themes/theme.theme. <repo-root> defaults to the parent of
# this script and must hold scripts/render-theme.sh.
#
# The fallback is what scripts/render-theme.sh writes for an empty palette (the
# no-theme default), so the repo template stays the single source of truth. The
# file is written only when it is absent: once ThemeService has rendered a
# palette, or the user has selected a theme, this is a no-op. A symlinked
# btop/, themes/, or destination file is skipped rather than followed.
#
# Benign no-ops (a missing argument, an existing destination, a symlink) exit 0;
# a real I/O failure is reported on stderr and exits non-zero. `seeded btop
# theme` goes to stdout on a fresh seed.
set -u

config_home=${1:-}
[ -n "$config_home" ] || exit 0

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
repo_root=${2:-$(CDPATH= cd -- "$script_dir/.." && pwd)}
render=$repo_root/scripts/render-theme.sh

theme_dir=$config_home/btop/themes
dest=$theme_dir/theme.theme

if [ ! -f "$render" ]; then
    printf 'seed-btop-theme: renderer not found: %s\n' "$render" >&2
    exit 1
fi

for dir in "$config_home/btop" "$theme_dir"; do
    if [ -L "$dir" ]; then
        printf 'seed-btop-theme: %s is a symlink, skipped\n' "$dir" >&2
        exit 0
    fi
done
if [ -L "$dest" ]; then
    printf 'seed-btop-theme: %s is a symlink, skipped\n' "$dest" >&2
    exit 0
fi
[ -e "$dest" ] && exit 0

tmp=$(mktemp -d 2>/dev/null) || { printf 'seed-btop-theme: cannot create a temporary directory\n' >&2; exit 1; }
trap 'rm -rf "$tmp"' EXIT

if ! XDG_CONFIG_HOME=$tmp sh "$render" "" >/dev/null 2>&1; then
    printf 'seed-btop-theme: the renderer failed\n' >&2
    exit 1
fi
src=$tmp/btop/themes/theme.theme
if [ ! -f "$src" ]; then
    printf 'seed-btop-theme: the renderer wrote no btop theme\n' >&2
    exit 1
fi

if ! mkdir -p "$theme_dir"; then
    printf 'seed-btop-theme: cannot create %s\n' "$theme_dir" >&2
    exit 1
fi
if ! cp "$src" "$dest"; then
    printf 'seed-btop-theme: cannot write %s\n' "$dest" >&2
    exit 1
fi
printf 'seeded btop theme\n'
