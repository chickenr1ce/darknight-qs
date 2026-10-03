#!/bin/sh
# Catalog scan for ThemeService: print `<name>|<raw mode value>` for each trusted
# theme directory under the root given as $1. A theme is trusted when it is a
# real directory holding a readable, regular-file colors.toml of at most the byte
# cap given as $2 whose palette the loader can build, so the catalog never lists a
# theme that yields no palette (a mode-only file would be a silent dead switch).
# The palette may be canonical v4 or the pre-semantic ANSI form omarchy v4 still
# reads; ThemeParsers.parseColors fills the latter through omarchy's cascade, and
# this scan mirrors the cascade's requirements so the two agree. Mode is the
# file's `mode`, else the legacy `theme_type`, else the `light.mode` marker, else
# the background's luminance. One awk pass validates the file, so the scan does
# not fork per theme. Only colors.toml and that one marker are read (ADR 0011).
set -u

root=${1:-}
cap=${2:-}
[ -n "$root" ] || exit 0
[ -n "$cap" ] || exit 0
[ -d "$root" ] || exit 0

# Mirror of ThemeParsers.parseColors' requirements: accent has no fallback, the
# neutral ramp derives from a background and a foreground, and the named colors
# derive from the ANSI slots. Every source value must be an opaque #rgb or
# #rrggbb, matching isOpaqueColorValue. A declared mode is printed raw so
# ThemeParsers.parseTomlString resolves it the same way; otherwise the awk
# resolves mode from the marker flag and the background's luminance.
scan_awk='
function strip(raw,   text, quote, rest, p, sp) {
    text = raw
    sub(/^[ \t\r]*/, "", text)
    quote = substr(text, 1, 1)
    if (quote == "\"" || quote == sprintf("%c", 39)) {
        rest = substr(text, 2)
        p = index(rest, quote)
        if (p > 0) return substr(rest, 1, p - 1)
        return text
    }
    sp = match(text, /[ \t\r]/)
    return sp > 0 ? substr(text, 1, sp - 1) : text
}
function isopaque(value,   len) {
    if (value !~ /^#[0-9a-fA-F]+$/) return 0
    len = length(value) - 1
    return len == 3 || len == 6
}
function validmode(value) {
    return value == "dark" || value == "light"
}
function hexval(c) {
    return index("0123456789abcdef", tolower(c)) - 1
}
function hexpair(h, i) {
    return hexval(substr(h, i, 1)) * 16 + hexval(substr(h, i + 1, 1))
}
BEGIN {
    n = split("accent selection muted background dark_background darker_background lighter_background foreground dark_foreground light_foreground bright_foreground red yellow green cyan blue magenta bright_red bright_yellow bright_green bright_cyan bright_blue bright_magenta color0 color1 color2 color3 color4 color5 color6 color7 color8 color9 color10 color11 color12 color13 color14 color15 bg dark_bg darker_bg lighter_bg fg dark_fg light_fg bright_fg selection_background selection_foreground purple bright_purple", keys, " ")
    for (i = 1; i <= n; i++) known[keys[i]] = 1
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
        mode_raw = substr(line, eq + 1)
        sub(/^[ \t\r]*/, "", mode_raw)
        mode = strip(mode_raw)
        next
    }
    if (key == "theme_type") {
        tt_raw = substr(line, eq + 1)
        sub(/^[ \t\r]*/, "", tt_raw)
        theme_type = strip(tt_raw)
        next
    }
    if (key in known) color[key] = strip(substr(line, eq + 1))
}
END {
    ok = isopaque(color["accent"]) \
        && (isopaque(color["background"]) || isopaque(color["bg"]) || isopaque(color["color0"])) \
        && (isopaque(color["foreground"]) || isopaque(color["fg"]) || isopaque(color["color7"])) \
        && (isopaque(color["red"]) || isopaque(color["color1"])) \
        && (isopaque(color["green"]) || isopaque(color["color2"])) \
        && (isopaque(color["yellow"]) || isopaque(color["color3"])) \
        && (isopaque(color["blue"]) || isopaque(color["color4"])) \
        && (isopaque(color["magenta"]) || isopaque(color["color5"]) || isopaque(color["purple"])) \
        && (isopaque(color["cyan"]) || isopaque(color["color6"]))
    if (!ok) exit 1
    if (validmode(mode)) { print mode_raw; exit }
    if (validmode(theme_type)) { print tt_raw; exit }
    if (light_marker == 1) { print "light"; exit }
    bg = color["background"]
    if (bg == "") bg = color["bg"]
    if (bg == "") bg = color["color0"]
    if (bg ~ /^#[0-9a-fA-F]{6}$/) {
        lum = hexpair(bg, 2) + hexpair(bg, 4) + hexpair(bg, 6)
        print (lum > 382) ? "light" : "dark"
    } else {
        print "dark"
    }
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
    marker=$entry/light.mode
    if [ -f "$marker" ] && [ ! -L "$marker" ]; then light_marker=1; else light_marker=0; fi
    raw=$(awk -v light_marker="$light_marker" "$scan_awk" "$colors") || continue
    [ -n "$raw" ] || continue
    printf '%s|%s\n' "$name" "$raw"
done
