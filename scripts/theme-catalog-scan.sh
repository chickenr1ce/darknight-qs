#!/bin/sh
# Catalog scan for ThemeService: print `<name>|<raw mode value>` for each trusted
# theme directory under the root given as $1. A theme is trusted only when it is
# a real directory holding a readable, regular-file colors.toml of at most the
# byte cap given as $2 that declares a mode and carries the full v4 palette, so
# the catalog never lists a theme the palette loader would reject (a mode-only
# file would be a silent dead switch). One awk pass validates the file, so the
# scan does not fork sed and tail per theme. Nothing else in the directory is
# read (ADR 0011).
set -u

root=${1:-}
cap=${2:-}
[ -n "$root" ] || exit 0
[ -n "$cap" ] || exit 0
[ -d "$root" ] || exit 0

# Mirror of ThemeParsers.parseColors and its tables: mode must resolve to dark
# or light, every required key must be present with an opaque #rgb or #rrggbb
# value, and the optional keys are accepted but not required. The raw mode text
# is printed so ThemeParsers.parseTomlString resolves it the same way.
scan_awk='
function strip(raw,   text, q, rest, p, sp, quote) {
    text = raw
    sub(/^[ \t\r]*/, "", text)
    quote = substr(text, 1, 1)
    if (quote == "\"" || quote == sprintf("%c", 39)) {
        q = quote
        rest = substr(text, 2)
        p = index(rest, q)
        if (p > 0) return substr(rest, 1, p - 1)
        return text
    }
    sp = match(text, /[ \t\r]/)
    return sp > 0 ? substr(text, 1, sp - 1) : text
}
function ishex(value,   len) {
    if (value !~ /^#[0-9a-fA-F]+$/) return 0
    len = length(value) - 1
    return len == 3 || len == 4 || len == 6 || len == 8
}
function isopaque(value,   len) {
    if (value !~ /^#[0-9a-fA-F]+$/) return 0
    len = length(value) - 1
    return len == 3 || len == 6
}
BEGIN {
    n = split("accent selection muted background dark_background darker_background lighter_background foreground dark_foreground light_foreground bright_foreground red yellow green cyan blue magenta bright_red bright_yellow bright_green bright_cyan bright_blue bright_magenta", req, " ")
    for (i = 1; i <= n; i++) required[req[i]] = 1
    border["hyprland_active_border"] = 1
    border["hyprland_inactive_border"] = 1
}
{
    line = $0
    sub(/^[ \t\r]*/, "", line)
    if (line == "" || substr(line, 1, 1) == "#" || substr(line, 1, 1) == "[") next
    eq = index(line, "=")
    if (eq <= 1) next
    key = substr(line, 1, eq - 1)
    sub(/[ \t\r]*$/, "", key)
    if (key == "mode") {
        mode = substr(line, eq + 1)
        sub(/^[ \t\r]*/, "", mode)
        next
    }
    if (!(key in required) && !(key in border) && key != "orange" && key != "brown") next
    value = strip(substr(line, eq + 1))
    if (key in required) {
        have[key] = isopaque(value) ? 1 : 0
        next
    }
    if (key in border) {
        optional[key] = ishex(value) ? 1 : 0
        next
    }
    optional[key] = isopaque(value) ? 1 : 0
}
END {
    if (strip(mode) != "dark" && strip(mode) != "light") exit 1
    for (i = 1; i <= n; i++) if (!have[req[i]]) exit 1
    print mode
}
'

for entry in "$root"/*; do
    [ -d "$entry" ] || continue
    [ -L "$entry" ] && continue
    name=${entry##*/}
    case $name in
        *[[:cntrl:]]*|*'|'*|*'/'*|*'#'*|*'?'*|*\\*) continue ;;
    esac
    colors=$entry/colors.toml
    [ -r "$colors" ] || continue
    stat=$(stat -c '%f|%s' "$colors" 2>/dev/null) || continue
    kind=${stat%%|*}
    size=${stat##*|}
    case $kind in
        8*) ;;
        *) continue ;;
    esac
    [ "$size" -le "$cap" ] || continue
    raw=$(awk "$scan_awk" "$colors") || continue
    [ -n "$raw" ] || continue
    printf '%s|%s\n' "$name" "$raw"
done
