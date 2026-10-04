#!/bin/sh
# Seed the repository's bundled themes into the quickshell theme root.
#
# Usage: seed-themes.sh <bundle-dir> <theme-root>
#
# For each immediate subdirectory of the bundle that holds a readable regular
# colors.toml, copy the bundle into <theme-root>/<name>, creating the directory
# when it is missing. The theme's own files (colors.toml and a light.mode marker)
# are refreshed, and a bundled background is added only when the installed theme
# lacks that name. An existing background is never overwritten, so a user's
# replacement, or a higher-resolution original seeded before the bundle shipped,
# survives an update. Nothing is ever deleted.
#
# A destination that is a symlink, is not a directory, or holds a symlinked
# colors.toml, backgrounds/, or light.mode is skipped rather than followed,
# matching the theme trust model's refusal to write through a link (ADR 0011).
# A skip is reported on stderr; `seeded <name>` (new directory) and
# `refreshed <name>` (existing directory) go to stdout. The benign no-ops
# (missing arguments, a missing bundle) exit 0; a real I/O failure is reported
# on stderr and exits non-zero so the installer can name it. The shell reads
# this root as data (ADR 0010).
set -u

bundle=${1:-}
root=${2:-}
[ -n "$bundle" ] || exit 0
[ -n "$root" ] || exit 0
[ -d "$bundle" ] || exit 0
[ -L "$bundle" ] && exit 0

if ! mkdir -p "$root" 2>/dev/null; then
    printf 'seed-themes: cannot create %s\n' "$root" >&2
    exit 1
fi

failed=0
for entry in "$bundle"/*; do
    [ -d "$entry" ] || continue
    [ -L "$entry" ] && continue
    name=${entry##*/}
    case $name in
        ""|.|..|*/*|*\\*|*'|'*|*'#'*|*'?'*|*[[:cntrl:]]*) continue ;;
    esac
    colors=$entry/colors.toml
    [ -f "$colors" ] || continue
    [ -L "$colors" ] && continue
    [ -r "$colors" ] || continue
    dest=$root/$name
    if [ -L "$dest" ]; then
        printf 'seed-themes: %s is a symlink, skipped\n' "$dest" >&2
        continue
    fi
    if [ -e "$dest" ] && [ ! -d "$dest" ]; then
        printf 'seed-themes: %s is not a directory, skipped\n' "$dest" >&2
        continue
    fi
    unsafe=0
    for guard in colors.toml backgrounds light.mode; do
        [ -L "$dest/$guard" ] && unsafe=1
    done
    if [ "$unsafe" -eq 1 ]; then
        printf 'seed-themes: %s holds a symlink, skipped\n' "$dest" >&2
        continue
    fi
    existed=1
    [ -d "$dest" ] || existed=0
    if ! mkdir -p "$dest"; then
        printf 'seed-themes: cannot create %s\n' "$dest" >&2
        failed=1
        continue
    fi
    ok=1
    for file in colors.toml light.mode; do
        [ -f "$entry/$file" ] || continue
        [ -L "$entry/$file" ] && continue
        cp -f "$entry/$file" "$dest/$file" || ok=0
    done
    if [ -d "$entry/backgrounds" ]; then
        if mkdir -p "$dest/backgrounds"; then
            for file in "$entry"/backgrounds/*; do
                [ -f "$file" ] || continue
                [ -L "$file" ] && continue
                [ -e "$dest/backgrounds/${file##*/}" ] && continue
                cp -f "$file" "$dest/backgrounds/" || ok=0
            done
        else
            ok=0
        fi
    fi
    if [ "$ok" -eq 0 ]; then
        printf 'seed-themes: failed to seed %s\n' "$name" >&2
        failed=1
        continue
    fi
    if [ "$existed" -eq 1 ]; then
        printf 'refreshed %s\n' "$name"
    else
        printf 'seeded %s\n' "$name"
    fi
done

exit "$failed"
