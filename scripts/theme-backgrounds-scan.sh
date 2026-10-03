#!/bin/sh
# Background scan for ThemeService: print the file name of every trusted image
# directly inside the backgrounds directory given as $1. An image is trusted only
# when the directory is a real directory and not a symlink, and the entry is a
# regular file, not a symlink, not a nested directory, with extension jpg, jpeg,
# png, webp, or bmp (case-insensitive), and at most the byte cap given as $2.
# Nothing else in the theme directory is read (ADR 0011).
set -u

dir=${1:-}
cap=${2:-}
[ -n "$dir" ] || exit 0
[ -n "$cap" ] || exit 0
[ -d "$dir" ] || exit 0
[ -L "$dir" ] && exit 0

for entry in "$dir"/*; do
    [ -f "$entry" ] || continue
    [ -L "$entry" ] && continue
    name=${entry##*/}
    case $name in
        *..*|*[[:cntrl:]]*|*'|'*|*'/'*) continue ;;
    esac
    lower=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')
    case $lower in
        *.jpg|*.jpeg|*.png|*.webp|*.bmp) ;;
        *) continue ;;
    esac
    stat=$(stat -c '%f|%s' "$entry" 2>/dev/null) || continue
    kind=${stat%%|*}
    size=${stat##*|}
    case $kind in
        8*) ;;
        *) continue ;;
    esac
    [ "$size" -le "$cap" ] || continue
    printf '%s\n' "$name"
done
