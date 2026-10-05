#!/bin/sh
# Catalog scan for ThemeService: print
# `<name>|<mode>|<accent>|<magenta>|<foreground>|<surface>|<background>` for each
# trusted theme directory under the root given as $1. A theme is trusted when it
# is a real directory holding a readable, regular-file colors.toml of at most the
# byte cap given as $2 whose palette the loader can build, so the catalog never
# lists a theme that yields no palette (a mode-only file would be a silent dead
# switch). The trailing colors are the theme's preview, resolved from the same
# source roles the loader reads, resolving each the way parseColors does: the
# first key holding any hex value wins (magenta through color5/purple, foreground
# through fg/color7, background through bg/color0, surface through
# lighter_bg/background), and every required role must be opaque or the theme is
# dropped, so the scan never lists a palette the loader would reject. A surface
# that lands on the background is stepped toward the foreground, matching
# parseColors. The palette may be canonical
# v4 or the pre-semantic ANSI form omarchy v4 still reads;
# ThemeParsers.parseColors fills the latter through omarchy's cascade, and this
# scan mirrors the cascade's requirements so the two agree. Mode is the file's
# `mode`, else the legacy `theme_type`, else the `light.mode` marker, else the
# background's luminance. One awk pass validates the file, so the scan does not
# fork per theme. Only colors.toml and that one marker are read (ADR 0011).
set -u

root=${1:-}
cap=${2:-}
[ -n "$root" ] || exit 0
[ -n "$cap" ] || exit 0
[ -d "$root" ] || exit 0

# Mirror of ThemeParsers.parseColors' requirements: a role takes the first key
# that holds any hex value (accent has no fallback; the named colors fall back to
# their ANSI slot), and each required role must then be opaque #rgb or #rrggbb,
# matching isOpaqueColorValue. A value present but non-opaque is not skipped for
# a later key, because parseColors does not skip it either. A declared mode is
# printed raw so ThemeParsers.parseTomlString resolves it the same way; otherwise
# the awk resolves mode from the marker flag and the background's luminance.
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
function iscolor(value,   len) {
    if (value !~ /^#[0-9a-fA-F]+$/) return 0
    len = length(value) - 1
    return len == 3 || len == 4 || len == 6 || len == 8
}
function firstcolor(a, b, c) {
    if (iscolor(a)) return a
    if (iscolor(b)) return b
    return iscolor(c) ? c : ""
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
function expand(value,   h, len) {
    h = value
    sub(/^#/, "", h)
    len = length(h)
    if (len == 3)
        return "#" tolower(substr(h, 1, 1) substr(h, 1, 1) substr(h, 2, 1) substr(h, 2, 1) substr(h, 3, 1) substr(h, 3, 1))
    if (len == 6)
        return "#" tolower(h)
    return ""
}
function mixchannel(x, y, t) {
    return int(x * (1 - t) + y * t + 0.5)
}
function mixcolor(start, end, t,   a, b) {
    a = expand(start)
    b = expand(end)
    if (a == "" || b == "") return ""
    return sprintf("#%02x%02x%02x", mixchannel(hexpair(a, 2), hexpair(b, 2), t), mixchannel(hexpair(a, 4), hexpair(b, 4), t), mixchannel(hexpair(a, 6), hexpair(b, 6), t))
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
    accent = color["accent"]
    background = firstcolor(color["background"], color["bg"], color["color0"])
    foreground = firstcolor(color["foreground"], color["fg"], color["color7"])
    red = firstcolor(color["red"], color["color1"], "")
    green = firstcolor(color["green"], color["color2"], "")
    yellow = firstcolor(color["yellow"], color["color3"], "")
    blue = firstcolor(color["blue"], color["color4"], "")
    magenta = firstcolor(color["magenta"], color["color5"], color["purple"])
    cyan = firstcolor(color["cyan"], color["color6"], "")
    surface = firstcolor(color["lighter_background"], color["lighter_bg"], background)
    ok = isopaque(accent) && isopaque(background) && isopaque(foreground) \
        && isopaque(red) && isopaque(green) && isopaque(yellow) \
        && isopaque(blue) && isopaque(magenta) && isopaque(cyan) && isopaque(surface)
    if (!ok) exit 1
    bgraw = color["background"]
    if (bgraw == "") bgraw = color["bg"]
    if (bgraw == "") bgraw = color["color0"]
    if (validmode(mode)) resolved = mode_raw
    else if (validmode(theme_type)) resolved = tt_raw
    else if (light_marker == 1) resolved = "light"
    else if (bgraw ~ /^#[0-9a-fA-F]{6}$/) {
        lum = hexpair(bgraw, 2) + hexpair(bgraw, 4) + hexpair(bgraw, 6)
        resolved = (lum > 382) ? "light" : "dark"
    } else resolved = "dark"
    if (expand(surface) == expand(background)) {
        stepped = mixcolor(background, foreground, 0.2)
        if (stepped != "" && stepped != expand(background)) surface = stepped
    }
    printf "%s|%s|%s|%s|%s|%s\n", resolved, accent, magenta, foreground, surface, background
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
