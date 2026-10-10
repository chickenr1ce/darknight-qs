#!/usr/bin/env bash
# wire-themed-apps: point installed apps at the shell's rendered theme files.
#
#   wire-themed-apps.sh [--check|--apply] [target...]
#
# Targets: hyprland kitty hyprlock btop firefox vencord spicetify. With no
# target every one is processed. --check (the default) reports what --apply
# would do and changes nothing on disk; --apply edits the user-owned files that
# consume the renderer's output. The renderer itself never touches these files;
# only this explicit command does.
#
# Each target prints one line to stdout whose first word is a status:
#   ok     already wired (both modes)
#   todo   check mode, or apply mode when blocked (e.g. the app is running)
#   wired  apply mode changed something
#   skip   app or config absent, or unsupported
#   note   an extra hint line after the status line
# Exit is 0 normally, including skip and todo. A real I/O or command failure is
# reported on stderr and the run exits 1 once the remaining targets have been
# processed, so one bad file does not hide the others.
#
# Before the first change to a file it is copied to
# <file>.bak-quickshell-<YYYYmmddHHMMSS> next to the real file. A symlinked
# config (stow-style dotfiles) stays a symlink: readlink -f resolves the link
# target and that file is replaced atomically (temp file in its directory plus
# mv), never the link. A second --apply changes no bytes and makes no new
# backup.
#
# Firefox profile resolution mirrors firefox_profile() in scripts/render-theme.sh
# (the renderer is Python and exposes no profile query, so the logic is mirrored
# faithfully here rather than shared); keep the two in step by hand.
#
# See docs/user/theme-desktop-setup.md for the manual steps behind each target.
set -euo pipefail

C=${XDG_CONFIG_HOME:-${HOME:-}/.config}
MODE=check
TARGETS=()
HAD_FAILURE=0

REQUIRE_THEME="require[[:space:]]*\(?[[:space:]]*[\"']theme[\"']"

usage() {
    cat <<'USAGE'
usage: wire-themed-apps.sh [--check|--apply] [target...]

Targets: hyprland kitty hyprlock btop firefox vencord spicetify.
With no target every one is processed.

  --check   report what --apply would do (default)
  --apply   wire the files, backing each up first
  --help    this message
USAGE
}

say() { printf 'wire-themed-apps: %s\n' "$*" >&2; }

# Strip control characters from untrusted text before printing it, so a
# newline, tab, or escape sequence in an argument cannot inject terminal lines.
safe() { printf '%s' "$1" | LC_ALL=C tr -d '[:cntrl:]'; }

ok() { printf '%-7s %s\n' ok "$1"; }
todo() { printf '%-7s %s: %s\n' todo "$1" "$2"; }
wired() { printf '%-7s %s: %s\n' wired "$1" "$2"; }
skip() { printf '%-7s %s: %s\n' skip "$1" "$2"; }
note() { printf '%-7s %s: %s\n' note "$1" "$2"; }

# --- shared file operations -------------------------------------------------

# The real file behind a path, following a symlink chain. A plain path is
# returned unchanged; a dangling symlink resolves to the path it names.
target_path() {
    local p=$1
    if [ -L "$p" ]; then
        readlink -f -- "$p" 2>/dev/null || printf '%s\n' "$p"
    else
        printf '%s\n' "$p"
    fi
}

# Copy the file to <file>.bak-quickshell-<YYYYmmddHHMMSS>. A second change in
# the same second gets a numeric suffix, so an existing backup is never
# overwritten.
backup_once() {
    local target=$1 ts dst n
    ts=$(date +%Y%m%d%H%M%S)
    dst=$target.bak-quickshell-$ts
    n=1
    while [ -e "$dst" ]; do
        dst=$target.bak-quickshell-$ts.$n
        n=$((n + 1))
    done
    cp -p -- "$target" "$dst"
}

# Replace <live path> with the bytes in <new content file>, atomically and
# through any symlink. The destination directory is created if absent.
write_atomic() {
    local path=$1 src=$2 target dir tmp
    target=$(target_path "$path")
    dir=$(dirname -- "$target")
    if [ ! -d "$dir" ]; then
        mkdir -p -- "$dir"
    fi
    tmp=$(mktemp "$dir/.wire-themed-apps-XXXXXX")
    if ! cat -- "$src" >"$tmp"; then
        rm -f -- "$tmp"
        return 1
    fi
    if [ -f "$target" ]; then
        chmod --reference="$target" "$tmp" 2>/dev/null || true
    else
        chmod "$(printf '%04o' "$(( 0666 & ~0$(umask) ))")" "$tmp" 2>/dev/null || true
    fi
    if ! mv -f -- "$tmp" "$target"; then
        rm -f -- "$tmp"
        return 1
    fi
}

# 0 = changed, 1 = already identical, 2 = I/O failure. A backup is taken only
# when the bytes actually differ, so a rerun is a no-op with no new backup.
apply_content() {
    local path=$1 src=$2 target
    target=$(target_path "$path")
    if [ -f "$target" ] && cmp -s -- "$src" "$target"; then
        return 1
    fi
    if [ -f "$target" ]; then
        backup_once "$target" || return 2
    fi
    write_atomic "$path" "$src" || return 2
    return 0
}

# apply_content, recording the outcome in APPLY_RC. Always returns 0, so the
# caller reads APPLY_RC: 0 changed, 1 already identical, 2 I/O failure.
try_apply() {
    if apply_content "$1" "$2"; then
        APPLY_RC=0
    else
        APPLY_RC=$?
    fi
}

ensure_trailing_newline() {
    local file=$1
    if [ -s "$file" ] && [ -n "$(tail -c 1 -- "$file")" ]; then
        printf '\n' >>"$file"
    fi
}

# --- hyprland ---------------------------------------------------------------

# Strip Lua comments from stdin: a line comment (-- ...) to end of line and a
# block comment (--[[ ... ]], --[==[ ... ]==]) across lines. Long strings are
# left alone; only comments can hide a require.
lua_strip_comments() {
    awk '
        BEGIN { inblock = 0 }
        {
            line = $0
            out = ""
            while (1) {
                if (inblock) {
                    p = index(line, endtok)
                    if (p == 0) break
                    line = substr(line, p + length(endtok))
                    inblock = 0
                    continue
                }
                p = index(line, "--")
                if (p == 0) { out = out line; break }
                rest = substr(line, p + 2)
                if (substr(rest, 1, 1) == "[") {
                    eq = 0; j = 2
                    while (substr(rest, j, 1) == "=") { eq++; j++ }
                    if (substr(rest, j, 1) == "[") {
                        endtok = "]"
                        for (k = 0; k < eq; k++) endtok = endtok "="
                        endtok = endtok "]"
                        out = out substr(line, 1, p - 1)
                        line = substr(rest, j + 1)
                        inblock = 1
                        continue
                    }
                }
                out = out substr(line, 1, p - 1)
                break
            }
            print out
        }
    '
}

# True when any *.lua under $C/hypr, excluding theme.lua, has a non-comment
# line requiring "theme". -L follows symlinks, so a stow-style dotfiles tree
# (a symlinked directory or *.lua file) is searched like a real one.
hyprland_wired() {
    local f
    while IFS= read -r f; do
        if lua_strip_comments <"$f" 2>/dev/null \
            | tr -d '\r' | grep -qE "$REQUIRE_THEME"; then
            return 0
        fi
    done < <(find -L "$C/hypr" -name '*.lua' ! -name theme.lua -type f 2>/dev/null)
    return 1
}

wire_hyprland() {
    local entry=$C/hypr/hyprland.lua out=$WORK/hyprland.new
    if [ ! -f "$entry" ]; then
        skip hyprland "no hyprland.lua (theme.lua needs the Lua config)"
        return 0
    fi
    if hyprland_wired; then
        ok hyprland
        return 0
    fi
    if [ "$MODE" = check ]; then
        todo hyprland 'append require("theme") to hyprland.lua'
        return 0
    fi
    if ! cp -p -- "$entry" "$out"; then
        say "cannot stage a new $entry"
        return 1
    fi
    ensure_trailing_newline "$out"
    {
        printf '%s\n' '-- quickshell: rendered border colors; keep this the last line'
        printf '%s\n' 'require("theme")'
    } >>"$out"
    try_apply "$entry" "$out"
    case $APPLY_RC in
        0) wired hyprland 'appended require("theme") to hyprland.lua' ;;
        1) ok hyprland ;;
        *) say "cannot update $entry"
            return 1 ;;
    esac
}

# --- kitty ------------------------------------------------------------------

wire_kitty() {
    local conf=$C/kitty/kitty.conf out=$WORK/kitty.new
    if [ ! -f "$conf" ]; then
        skip kitty "no kitty.conf"
        return 0
    fi
    if sed 's/\r$//' -- "$conf" \
        | grep -qE '^[[:space:]]*include[[:space:]]+theme\.conf[[:space:]]*$'; then
        ok kitty
        return 0
    fi
    local has_begin=0 has_end=0
    if sed 's/\r$//' -- "$conf" | grep -qxE '[[:space:]]*# BEGIN_KITTY_THEME[[:space:]]*'; then
        has_begin=1
    fi
    if sed 's/\r$//' -- "$conf" | grep -qxE '[[:space:]]*# END_KITTY_THEME[[:space:]]*'; then
        has_end=1
    fi
    if [ "$has_begin" -ne "$has_end" ]; then
        todo kitty "unmatched BEGIN/END_KITTY_THEME marker; fix kitty.conf by hand"
        return 0
    fi
    if [ "$MODE" = check ]; then
        todo kitty "add 'include theme.conf' to kitty.conf"
        return 0
    fi
    if [ "$has_begin" -eq 1 ]; then
        awk '
            function trim(s) { sub(/\r$/, "", s); sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
            BEGIN { inblk = 0 }
            {
                t = trim($0)
                if (t == "# BEGIN_KITTY_THEME" && !inblk) {
                    print; print "include theme.conf"; inblk = 1; next
                }
                if (t == "# END_KITTY_THEME" && inblk) { inblk = 0; print; next }
                if (inblk) next
                print
            }
        ' "$conf" >"$out" || {
            say "cannot build the new $conf"
            return 1
        }
        try_apply "$conf" "$out"
        case $APPLY_RC in
            0) wired kitty "replaced the theme block in kitty.conf" ;;
            1) ok kitty ;;
            *) say "cannot update $conf"
                return 1 ;;
        esac
        return 0
    fi
    if ! cp -p -- "$conf" "$out"; then
        say "cannot stage a new $conf"
        return 1
    fi
    ensure_trailing_newline "$out"
    printf '%s\n' 'include theme.conf' >>"$out"
    try_apply "$conf" "$out"
    case $APPLY_RC in
        0) wired kitty "added include theme.conf to kitty.conf" ;;
        1) ok kitty ;;
        *) say "cannot update $conf"
            return 1 ;;
    esac
}

# --- hyprlock ---------------------------------------------------------------

wire_hyprlock() {
    local conf=$C/hypr/hyprlock.conf out=$WORK/hyprlock.new src
    if [ ! -f "$conf" ]; then
        skip hyprlock "no hyprlock.conf"
        return 0
    fi
    if [ "$C" = "${HOME:-}/.config" ]; then
        # The literal ~ is the form hyprlock expands; do not substitute $HOME.
        # shellcheck disable=SC2088
        src='~/.config/hypr/hyprlock/colors.conf'
    else
        src=$C/hypr/hyprlock/colors.conf
    fi
    local hint='widget colors must reference $theme_* by hand (see docs/user/theme-desktop-setup.md)'
    if sed 's/\r$//' -- "$conf" \
        | grep -qE '^[[:space:]]*source[[:space:]]*=.*hyprlock/colors\.conf[[:space:]]*$'; then
        ok hyprlock
        note hyprlock "$hint"
        return 0
    fi
    if [ "$MODE" = check ]; then
        todo hyprlock "prepend source = $src to hyprlock.conf"
        note hyprlock "$hint"
        return 0
    fi
    if ! { printf 'source = %s\n' "$src" >"$out" && cat -- "$conf" >>"$out"; }; then
        say "cannot stage a new $conf"
        return 1
    fi
    try_apply "$conf" "$out"
    case $APPLY_RC in
        0) wired hyprlock "prepended source = $src to hyprlock.conf" ;;
        1) ok hyprlock ;;
        *) say "cannot update $conf"
            return 1 ;;
    esac
    note hyprlock "$hint"
}

# --- btop -------------------------------------------------------------------

wire_btop() {
    local conf=$C/btop/btop.conf out=$WORK/btop.new
    local want="color_theme = \"$C/btop/themes/theme.theme\""
    if [ ! -f "$conf" ]; then
        skip btop "no btop.conf (run btop once)"
        return 0
    fi
    if awk -v want="$want" '
        { l = $0; sub(/\r$/, "", l) }
        l == want { found = 1 }
        END { exit(found ? 0 : 1) }
    ' "$conf"; then
        ok btop
        return 0
    fi
    if [ "$MODE" = check ]; then
        todo btop "set color_theme to $C/btop/themes/theme.theme"
        return 0
    fi
    if pgrep -x btop >/dev/null 2>&1; then
        todo btop "close btop first (it rewrites btop.conf on exit)"
        return 0
    fi
    awk -v want="$want" '
        /^[[:space:]]*color_theme[[:space:]]*=/ {
            if (!done) { print want; done = 1 }
            next
        }
        { print }
        END { if (!done) print want }
    ' "$conf" >"$out" || {
        say "cannot build the new $conf"
        return 1
    }
    try_apply "$conf" "$out"
    case $APPLY_RC in
        0) wired btop "set color_theme to $C/btop/themes/theme.theme" ;;
        1) ok btop ;;
        *) say "cannot update $conf"
            return 1 ;;
    esac
}

# --- firefox ----------------------------------------------------------------

# Mirror of parse_ini_text() in scripts/render-theme.sh: emit one
# 'section<TAB>key<TAB>value' line per assignment. The whole line, the section
# name, the key, and the value are stripped of surrounding whitespace (a CRLF
# line's \r included), blank and comment lines are skipped, and a section runs
# until the next header.
ini_flatten() {
    awk '
        function trim(s) {
            sub(/^[ \t\r\n\v\f]+/, "", s)
            sub(/[ \t\r\n\v\f]+$/, "", s)
            return s
        }
        {
            line = trim($0)
            if (line == "") next
            c = substr(line, 1, 1)
            if (c == "#" || c == ";") next
            if (c == "[" && substr(line, length(line), 1) == "]") {
                section = trim(substr(line, 2, length(line) - 2))
                have = 1
                next
            }
            if (!have) next
            p = index(line, "=")
            if (p == 0) next
            print section "\t" trim(substr(line, 1, p - 1)) "\t" trim(substr(line, p + 1))
        }
    ' "$1" 2>/dev/null
}

# Mirror of firefox_profile()'s profiles.ini loop: the first Profile section
# whose Path (or its basename) matches the default name wins; IsRelative 0 means
# an absolute Path, anything else joins it to the root. Prints nothing when no
# section matches, so the caller keeps the root/default fallback.
firefox_profiles_path() {
    awk -v root="$1" -v def="$2" '
        function trim(s) {
            sub(/^[ \t\r\n\v\f]+/, "", s)
            sub(/[ \t\r\n\v\f]+$/, "", s)
            return s
        }
        function emit() {
            if (found || ! have || sect !~ /^Profile/) return
            if (p == "") return
            base = p
            sub(/.*\//, "", base)
            if (p != def && base != def) return
            if (isrel == "0") print p
            else print root "/" p
            found = 1
        }
        {
            line = trim($0)
            if (line == "") next
            c = substr(line, 1, 1)
            if (c == "#" || c == ";") next
            if (c == "[" && substr(line, length(line), 1) == "]") {
                emit()
                sect = trim(substr(line, 2, length(line) - 2))
                have = 1; p = ""; isrel = ""
                next
            }
            if (found || ! have) next
            i = index(line, "=")
            if (i == 0) next
            key = trim(substr(line, 1, i - 1))
            val = trim(substr(line, i + 1))
            if (key == "Path") p = val
            else if (key == "IsRelative") isrel = val
        }
        END { emit() }
    ' "$3" 2>/dev/null
}

# Mirror of firefox_root()/firefox_profile() in scripts/render-theme.sh: the
# root is $C/mozilla/firefox when it is a directory, else $HOME/.mozilla/firefox;
# installs.ini names the default profile, profiles.ini supplies IsRelative or an
# absolute Path, and the profile directory must exist. The profile path is never
# resolved, so a psd target stays writable.
firefox_profile() {
    local root default_name profile resolved
    local config_home candidate
    config_home=${XDG_CONFIG_HOME:-${HOME:-}/.config}
    candidate=$config_home/mozilla/firefox
    if [ -d "$candidate" ]; then
        root=$candidate
    else
        root=${HOME:-}/.mozilla/firefox
    fi

    default_name=$(ini_flatten "$root/installs.ini" | awk -F'\t' '
        $1 ~ /^(Install)?[0-9A-Fa-f]+$/ && $2 == "Default" && $3 != "" { print $3; exit }
    ')
    [ -n "$default_name" ] || return 1

    profile=$root/$default_name
    resolved=$(firefox_profiles_path "$root" "$default_name" "$root/profiles.ini")
    [ -z "$resolved" ] || profile=$resolved

    if [ -d "$profile" ]; then
        printf '%s\n' "$profile"
        return 0
    fi
    return 1
}

# True when the sheet's line 1 is exactly the import (a trailing \r from a CRLF
# file does not count as a mismatch).
firefox_sheet_wired() {
    local file=$1 imp=$2
    [ -f "$file" ] || return 1
    [ "$(sed -n '1p' -- "$file" | tr -d '\r')" = "$imp" ]
}

# The import on line 1, every other occurrence removed (each original line's
# bytes, including a CRLF ending, are kept).
firefox_sheet_desired() {
    local file=$1 imp=$2 out=$3
    printf '%s\n' "$imp" >"$out"
    if [ -f "$file" ]; then
        awk -v imp="$imp" '
            { l = $0; sub(/\r$/, "", l) }
            l != imp { print }
        ' "$file" >>"$out"
    fi
}

# 0 = changed, 1 = already wired, 2 = I/O failure.
firefox_apply_sheet() {
    local file=$1 imp=$2 out=$WORK/firefox.sheet
    if firefox_sheet_wired "$file" "$imp"; then
        return 1
    fi
    firefox_sheet_desired "$file" "$imp" "$out" || return 2
    try_apply "$file" "$out"
    return "$APPLY_RC"
}

wire_firefox() {
    local profile chrome user_chrome user_content
    if ! profile=$(firefox_profile); then
        skip firefox "no profile"
        return 0
    fi
    chrome=$profile/chrome
    user_chrome=$chrome/userChrome.css
    user_content=$chrome/userContent.css

    if firefox_sheet_wired "$user_chrome" '@import url("shell-palette.css");' \
        && firefox_sheet_wired "$user_content" '@import url("shell-content.css");'; then
        ok firefox
        return 0
    fi
    if [ "$MODE" = check ]; then
        todo firefox "prepend the shell @import to userChrome.css and userContent.css"
        return 0
    fi

    local rc_a rc_b changed=0
    firefox_apply_sheet "$user_chrome" '@import url("shell-palette.css");' && rc_a=0 || rc_a=$?
    firefox_apply_sheet "$user_content" '@import url("shell-content.css");' && rc_b=0 || rc_b=$?
    if [ "$rc_a" -eq 2 ] || [ "$rc_b" -eq 2 ]; then
        say "cannot update the Firefox sheets under $chrome"
        return 1
    fi
    if [ "$rc_a" -eq 0 ] || [ "$rc_b" -eq 0 ]; then
        changed=1
    fi
    if [ "$changed" -eq 1 ]; then
        wired firefox "prepended the shell @import to userChrome.css and userContent.css"
        note firefox "restart Firefox"
    else
        ok firefox
    fi
}

# --- vencord ----------------------------------------------------------------

vencord_has_base() {
    jq -e 'any((.enabledThemes // [])[]?; type == "string" and test("system24"; "i"))' "$1" >/dev/null 2>&1
}

wire_vencord() {
    local settings=$C/Vencord/settings/settings.json out=$WORK/vencord.json
    local base_hint='the theme needs the system24 base theme enabled in Vencord'
    if [ ! -f "$settings" ]; then
        skip vencord "no settings.json"
        return 0
    fi
    if ! command -v jq >/dev/null 2>&1; then
        skip vencord "jq not installed"
        return 0
    fi
    if jq -e 'type == "object"' "$settings" >/dev/null 2>&1 \
        && ! jq -e '(.enabledThemes == null) or (.enabledThemes | type == "array")' "$settings" >/dev/null 2>&1; then
        todo vencord "enabledThemes in settings.json is not a list; fix by hand"
        return 0
    fi
    if jq -e '(.enabledThemes // []) | if type == "array" then index("quickshell.theme.css") != null else false end' "$settings" >/dev/null 2>&1; then
        ok vencord
        return 0
    fi
    if [ "$MODE" = check ]; then
        todo vencord "add quickshell.theme.css to enabledThemes in settings.json"
        if ! vencord_has_base "$settings"; then
            note vencord "$base_hint"
        fi
        return 0
    fi
    if pgrep -x -i discord >/dev/null 2>&1 \
        || pgrep -x -i discordcanary >/dev/null 2>&1 \
        || pgrep -x -i discordptb >/dev/null 2>&1; then
        todo vencord "close Discord first (it rewrites settings.json on exit)"
        if ! vencord_has_base "$settings"; then
            note vencord "$base_hint"
        fi
        return 0
    fi
    if ! jq --indent 4 '.enabledThemes = ((.enabledThemes // []) + ["quickshell.theme.css"])' \
        "$settings" >"$out"; then
        say "jq could not rewrite $settings"
        return 1
    fi
    try_apply "$settings" "$out"
    case $APPLY_RC in
        0) wired vencord "added quickshell.theme.css to enabledThemes" ;;
        1) ok vencord
            return 0 ;;
        *) say "cannot update $settings"
            return 1 ;;
    esac
    if ! vencord_has_base "$settings"; then
        note vencord "$base_hint"
    fi
    note vencord "restart Discord"
}

# --- spicetify --------------------------------------------------------------

# The [Setting] value for a key: whitespace around = varies.
spicetify_setting() {
    awk -v key="$2" '
        function trim(s) { sub(/\r$/, "", s); sub(/^[ \t]+/, "", s); sub(/[ \t]+$/, "", s); return s }
        /^\[/ {
            hdr = $0
            sub(/^\[/, "", hdr)
            sub(/\].*$/, "", hdr)
            insection = (trim(hdr) == "Setting")
            next
        }
        insection {
            t = trim($0)
            if (t ~ /^#/ || t ~ /^;/) next
            p = index(t, "=")
            if (p == 0) next
            k = trim(substr(t, 1, p - 1))
            if (k == key) last = trim(substr(t, p + 1))
        }
        END { if (last != "") print last }
    ' "$1"
}

wire_spicetify() {
    local ini=$C/spicetify/config-xpui.ini color=$C/spicetify/Themes/quickshell/color.ini
    if ! command -v spicetify >/dev/null 2>&1; then
        skip spicetify "spicetify not on PATH"
        return 0
    fi
    if [ ! -f "$ini" ]; then
        skip spicetify "no config-xpui.ini"
        return 0
    fi
    if [ "$(spicetify_setting "$ini" current_theme)" = quickshell ] \
        && [ "$(spicetify_setting "$ini" color_scheme)" = Quickshell ]; then
        ok spicetify
        return 0
    fi
    if [ ! -f "$color" ]; then
        todo spicetify "start the shell once so it renders the theme"
        return 0
    fi
    if [ "$MODE" = check ]; then
        todo spicetify "select the quickshell theme (spicetify config current_theme quickshell color_scheme Quickshell; spicetify restore backup apply)"
        return 0
    fi
    if ! spicetify config current_theme quickshell color_scheme Quickshell; then
        say "spicetify config failed"
        return 1
    fi
    if ! spicetify restore backup apply; then
        say "spicetify restore backup apply failed"
        return 1
    fi
    wired spicetify "selected the quickshell theme; Spotify restarted"
}

# --- dispatch ---------------------------------------------------------------

process_target() {
    case $1 in
        hyprland) wire_hyprland ;;
        kitty) wire_kitty ;;
        hyprlock) wire_hyprlock ;;
        btop) wire_btop ;;
        firefox) wire_firefox ;;
        vencord) wire_vencord ;;
        spicetify) wire_spicetify ;;
    esac
}

while [ $# -gt 0 ]; do
    case $1 in
        --check) MODE=check; shift ;;
        --apply) MODE=apply; shift ;;
        -h|--help) usage; exit 0 ;;
        --) shift; break ;;
        -*) say "unknown option: $(safe "$1")"; usage >&2; exit 2 ;;
        *) TARGETS+=("$1"); shift ;;
    esac
done
if [ $# -gt 0 ]; then
    TARGETS+=("$@")
fi

if [ "${#TARGETS[@]}" -eq 0 ]; then
    TARGETS=(hyprland kitty hyprlock btop firefox vencord spicetify)
fi

for target in "${TARGETS[@]}"; do
    case $target in
        hyprland|kitty|hyprlock|btop|firefox|vencord|spicetify) ;;
        *) say "unknown target: $(safe "$target")"
            usage >&2
            exit 2 ;;
    esac
done

WORK=$(mktemp -d "${TMPDIR:-/tmp}/wire-themed-apps-XXXXXX")
trap 'rm -rf "$WORK"' EXIT

# Each target runs in its own errexit subshell, so a real failure aborts that
# target only and the loop reports it after the rest have run.
for target in "${TARGETS[@]}"; do
    set +e
    ( set -e; process_target "$target" )
    status=$?
    set -e
    if [ "$status" -ne 0 ]; then
        HAD_FAILURE=1
    fi
done

exit "$HAD_FAILURE"
