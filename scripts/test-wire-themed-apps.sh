#!/usr/bin/env bash
# Headless gate for scripts/wire-themed-apps.sh, the optional one-time wiring
# command for the themed apps.
#
# Offline and never touches the real HOME: every case runs the script with HOME
# and XDG_CONFIG_HOME pointed at a throwaway tree, and `pgrep`, `spicetify`, and
# `date` are shimmed first on PATH so no process, app command, or wall clock is
# ever consulted. The spicetify shim records its argv and edits the ini the way
# the real CLI would, so a rerun is a real no-op; the date shim honors
# WIRE_FAKE_TS so a backup-name collision is deterministic. Covered: each
# target's fresh wire, the rerun no-op with no new backup, --check changing
# nothing, skip when a config is absent, the hyprland nested/commented/
# block-commented/symlinked/conf-only cases, kitty with and without markers and
# with only one, the Firefox import moved to line 1 (LF and CRLF) and a spaced
# Default=, Firefox sheet file modes, a backup collision, control-character
# sanitizing, a refused wire while the app runs, a symlinked config kept a
# symlink, a single failing target among several, and an unknown target. The
# install.sh wiring hand-off is checked too.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WIRE="$ROOT/scripts/wire-themed-apps.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/qs-wire-apps-XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "wire-themed-apps FAIL: $*" >&2; exit 1; }

test -f "$WIRE" || fail "scripts/wire-themed-apps.sh is missing"
[ -x "$WIRE" ] || fail "scripts/wire-themed-apps.sh is not executable"

# --- shims first on PATH ----------------------------------------------------
SHIM="$WORK/bin"
mkdir -p "$SHIM"
REAL_DATE="$(command -v date)"
cat >"$SHIM/pgrep" <<'SHIM'
#!/bin/sh
# WIRE_PGREP is a colon list of process names considered running.
for arg in "$@"; do
    case $arg in -*) continue ;; esac
    case ":${WIRE_PGREP:-}:" in
        *":$arg:"*) echo 4242; exit 0 ;;
    esac
done
exit 1
SHIM
cat >"$SHIM/date" <<SHIM
#!/bin/sh
if [ -n "\${WIRE_FAKE_TS:-}" ]; then printf '%s\n' "\$WIRE_FAKE_TS"; exit 0; fi
exec "$REAL_DATE" "\$@"
SHIM
cat >"$SHIM/spicetify" <<'SHIM'
#!/bin/sh
printf '%s\n' "$*" >>"${WIRE_SPICETIFY_LOG:-/dev/null}"
if [ "${WIRE_SPICETIFY_FAIL:-0}" = 1 ]; then
    echo "spicetify: simulated failure" >&2
    exit 1
fi
if [ "$1" = config ] && [ -n "${WIRE_SPICETIFY_INI:-}" ] && [ -f "${WIRE_SPICETIFY_INI}" ]; then
    sed -i \
        -e 's/^current_theme[[:space:]]*=.*/current_theme = quickshell/' \
        -e 's/^color_scheme[[:space:]]*=.*/color_scheme = Quickshell/' \
        "${WIRE_SPICETIFY_INI}"
fi
exit 0
SHIM
chmod +x "$SHIM/pgrep" "$SHIM/spicetify" "$SHIM/date"
export PATH="$SHIM:$PATH"
SPICE_LOG="$WORK/spicetify.log"
export WIRE_SPICETIFY_LOG="$SPICE_LOG"
export WIRE_SPICETIFY_INI=""

# --- env helpers ------------------------------------------------------------
EH=
EC=
new_env() {
    EH="$WORK/$1-home"
    EC="$EH/.config"
    rm -rf "$WORK/$1-home"
    mkdir -p "$EC"
}
wire() { HOME="$EH" XDG_CONFIG_HOME="$EC" "$WIRE" "$@"; }

make_hypr() { mkdir -p "$EC/hypr"; printf 'hl.config({})\n' >"$EC/hypr/hyprland.lua"; }
make_kitty() { mkdir -p "$EC/kitty"; printf 'font_size 12\n' >"$EC/kitty/kitty.conf"; }
make_hyprlock() { mkdir -p "$EC/hypr"; printf 'background {\n    color = black\n}\n' >"$EC/hypr/hyprlock.conf"; }
make_btop() { mkdir -p "$EC/btop"; printf 'color_theme = "Default"\n' >"$EC/btop/btop.conf"; }
make_firefox() {
    mkdir -p "$EC/mozilla/firefox/prof.default"
    printf '[Install4F96D1932A9F858E]\nDefault=prof.default\nLocked=1\n' \
        >"$EC/mozilla/firefox/installs.ini"
    printf '[Profile0]\nName=default\nIsRelative=1\nPath=prof.default\n' \
        >"$EC/mozilla/firefox/profiles.ini"
}
make_vencord() {
    mkdir -p "$EC/Vencord/settings"
    printf '{\n  "enabledThemes": [\n    "system24.css"\n  ]\n}\n' \
        >"$EC/Vencord/settings/settings.json"
}
make_spicetify() {
    mkdir -p "$EC/spicetify/Themes/quickshell"
    printf '[Setting]\ncurrent_theme = text\ncolor_scheme = base\n' \
        >"$EC/spicetify/config-xpui.ini"
    printf '[Quickshell]\naccent = #ffffff\n' \
        >"$EC/spicetify/Themes/quickshell/color.ini"
}
make_all() {
    make_hypr
    make_kitty
    make_hyprlock
    make_btop
    make_firefox
    make_vencord
    make_spicetify
}

tree_hashes() { (cd "$EC" && find . -type f -print0 | LC_ALL=C sort -z | xargs -0 md5sum); }
backup_count() { find "$EC" -name '*.bak-quickshell-*' | wc -l; }

# --- 1. a fresh --apply wires every target ----------------------------------
new_env fresh
make_all
export WIRE_SPICETIFY_INI="$EC/spicetify/config-xpui.ini"
: >"$SPICE_LOG"
out=$(wire --apply)
grep -q '^wired   hyprland' <<<"$out" || fail "hyprland was not wired: $out"
grep -q '^wired   kitty' <<<"$out" || fail "kitty was not wired: $out"
grep -q '^wired   hyprlock' <<<"$out" || fail "hyprlock was not wired: $out"
grep -q '^wired   btop' <<<"$out" || fail "btop was not wired: $out"
grep -q '^wired   firefox' <<<"$out" || fail "firefox was not wired: $out"
grep -q '^wired   vencord' <<<"$out" || fail "vencord was not wired: $out"
grep -q '^wired   spicetify' <<<"$out" || fail "spicetify was not wired: $out"
grep -q '^note    hyprlock: ' <<<"$out" || fail "hyprlock note is missing: $out"
grep -q '^note    firefox: restart Firefox' <<<"$out" || fail "firefox restart note is missing: $out"
grep -q '^note    vencord: restart Discord' <<<"$out" || fail "vencord restart note is missing: $out"

grep -qxF 'require("theme")' "$EC/hypr/hyprland.lua" \
    || fail "hyprland.lua does not require theme"
grep -qxF -- '-- quickshell: rendered border colors; keep this the last line' "$EC/hypr/hyprland.lua" \
    || fail "hyprland.lua is missing the last-line marker"
grep -qxF 'include theme.conf' "$EC/kitty/kitty.conf" \
    || fail "kitty.conf does not include theme.conf"
[ "$(sed -n '1p' "$EC/hypr/hyprlock.conf")" = 'source = ~/.config/hypr/hyprlock/colors.conf' ] \
    || fail "hyprlock.conf does not source colors.conf first"
grep -qxF "color_theme = \"$EC/btop/themes/theme.theme\"" "$EC/btop/btop.conf" \
    || fail "btop.conf does not point at the rendered theme"
[ "$(sed -n '1p' "$EC/mozilla/firefox/prof.default/chrome/userChrome.css")" = '@import url("shell-palette.css");' ] \
    || fail "userChrome.css does not import shell-palette.css on line 1"
[ "$(sed -n '1p' "$EC/mozilla/firefox/prof.default/chrome/userContent.css")" = '@import url("shell-content.css");' ] \
    || fail "userContent.css does not import shell-content.css on line 1"
jq -e '.enabledThemes | index("quickshell.theme.css") != null' \
    "$EC/Vencord/settings/settings.json" >/dev/null \
    || fail "settings.json does not enable quickshell.theme.css"
grep -q 'config current_theme quickshell color_scheme Quickshell' "$SPICE_LOG" \
    || fail "the spicetify config command was not run"
grep -q 'restore backup apply' "$SPICE_LOG" \
    || fail "the spicetify restore/apply command was not run"

first_backups=$(backup_count)
[ "$first_backups" -ge 5 ] || fail "a fresh wire made too few backups: $first_backups"
before=$(tree_hashes)

# --- 1b. a second --apply is a byte-identical no-op with no new backup -------
out=$(wire --apply)
grep -q '^wired' <<<"$out" && fail "a rerun still reported a change: $out"
grep -q '^ok      hyprland' <<<"$out" || fail "a rerun did not report hyprland ok: $out"
[ "$(backup_count)" -eq "$first_backups" ] || fail "a rerun made a new backup"
[ "$(tree_hashes)" = "$before" ] || fail "a rerun changed a file"

# --- 2. --check changes nothing and reports todo ----------------------------
new_env check
make_all
export WIRE_SPICETIFY_INI="$EC/spicetify/config-xpui.ini"
: >"$SPICE_LOG"
before=$(tree_hashes)
out=$(wire --check)
for target in hyprland kitty hyprlock btop firefox vencord spicetify; do
    grep -q "^todo    $target:" <<<"$out" || fail "--check did not report $target todo: $out"
done
[ "$(tree_hashes)" = "$before" ] || fail "--check changed a file"
[ "$(backup_count)" -eq 0 ] || fail "--check made a backup"
[ ! -s "$SPICE_LOG" ] || fail "--check ran spicetify"

# The default mode is --check: no flag reports todo and touches nothing.
new_env default-check
make_hypr
before=$(tree_hashes)
out=$(wire hyprland)
grep -q '^todo    hyprland:' <<<"$out" || fail "the default mode is not check: $out"
[ "$(tree_hashes)" = "$before" ] || fail "the default mode changed a file"

# --- 3. skip when the config is absent --------------------------------------
new_env skip
out=$(wire --check)
for target in hyprland kitty hyprlock btop firefox vencord spicetify; do
    grep -q "^skip    $target:" <<<"$out" || fail "an absent $target did not skip: $out"
done
grep -q '^skip    hyprland: no hyprland.lua' <<<"$out" \
    || fail "the hyprland skip did not name the missing file: $out"
grep -q '^skip    btop: no btop.conf (run btop once)$' <<<"$out" \
    || fail "the btop skip did not name the fix: $out"

# --- 4. hyprland: a require in a nested module counts, entry untouched -------
new_env hypr-nested
mkdir -p "$EC/hypr/modules"
printf 'hl.config({})\n' >"$EC/hypr/hyprland.lua"
printf 'require("theme")\n' >"$EC/hypr/modules/looks.lua"
before=$(cat "$EC/hypr/hyprland.lua")
out=$(wire --apply hyprland)
grep -q '^ok      hyprland' <<<"$out" || fail "a nested require was not seen as wired: $out"
[ "$(cat "$EC/hypr/hyprland.lua")" = "$before" ] \
    || fail "hyprland.lua was edited despite a nested require"

# --- 5. hyprland: only hyprland.conf -> skip --------------------------------
new_env hypr-conf
mkdir -p "$EC/hypr"
printf 'general {}\n' >"$EC/hypr/hyprland.conf"
out=$(wire --check hyprland)
grep -q '^skip    hyprland: no hyprland.lua' <<<"$out" \
    || fail "a .conf-only hyprland did not skip: $out"

# --- 6. hyprland: a commented require does not count ------------------------
new_env hypr-comment
mkdir -p "$EC/hypr/modules"
printf 'hl.config({})\n' >"$EC/hypr/hyprland.lua"
printf -- '-- require("theme")\n' >"$EC/hypr/modules/looks.lua"
out=$(wire --check hyprland)
grep -q '^todo    hyprland:' <<<"$out" \
    || fail "a commented require counted as wired: $out"
wire --apply hyprland >/dev/null
grep -qxF 'require("theme")' "$EC/hypr/hyprland.lua" \
    || fail "a commented require blocked the append"

# --- 7. kitty: an existing marker block is replaced -------------------------
new_env kitty-marker
mkdir -p "$EC/kitty"
cat >"$EC/kitty/kitty.conf" <<'EOF'
font_size 12
# BEGIN_KITTY_THEME
include old.conf
# END_KITTY_THEME
shell_integration enabled
EOF
cat >"$WORK/kitty.expected" <<'EOF'
font_size 12
# BEGIN_KITTY_THEME
include theme.conf
# END_KITTY_THEME
shell_integration enabled
EOF
out=$(wire --apply kitty)
grep -q '^wired   kitty: replaced the theme block' <<<"$out" \
    || fail "the kitty marker block was not replaced: $out"
cmp -s "$WORK/kitty.expected" "$EC/kitty/kitty.conf" \
    || fail "the kitty marker block has the wrong shape"

# --- 8. kitty: without markers the include is appended ----------------------
new_env kitty-append
mkdir -p "$EC/kitty"
printf 'font_size 12\n' >"$EC/kitty/kitty.conf"
out=$(wire --apply kitty)
grep -q '^wired   kitty: added include theme.conf' <<<"$out" \
    || fail "the kitty include was not appended: $out"
printf 'font_size 12\ninclude theme.conf\n' >"$WORK/kitty.expected"
cmp -s "$WORK/kitty.expected" "$EC/kitty/kitty.conf" \
    || fail "the appended kitty.conf has the wrong shape"

# --- 9. Firefox: an import on line 3 moves to line 1, no duplicate ----------
new_env firefox-lines
make_firefox
CHROME="$EC/mozilla/firefox/prof.default/chrome"
mkdir -p "$CHROME"
cat >"$CHROME/userChrome.css" <<'EOF'
/* a */
/* b */
@import url("shell-palette.css");
/* c */
EOF
out=$(wire --apply firefox)
grep -q '^wired   firefox:' <<<"$out" || fail "firefox was not wired: $out"
grep -q '^note    firefox: restart Firefox' <<<"$out" \
    || fail "the firefox restart note is missing: $out"
[ "$(sed -n '1p' "$CHROME/userChrome.css")" = '@import url("shell-palette.css");' ] \
    || fail "the Firefox import is not on line 1"
[ "$(grep -cxF '@import url("shell-palette.css");' "$CHROME/userChrome.css")" -eq 1 ] \
    || fail "the Firefox import was duplicated"
grep -qxF '/* c */' "$CHROME/userChrome.css" \
    || fail "the Firefox move dropped user content"
[ "$(sed -n '1p' "$CHROME/userContent.css")" = '@import url("shell-content.css");' ] \
    || fail "userContent.css was not created with the import"

# --- 10. vencord and btop refuse to write while the app runs ----------------
new_env running
make_btop
make_vencord
btop_before=$(cat "$EC/btop/btop.conf")
export WIRE_PGREP=btop
out=$(wire --apply btop)
unset WIRE_PGREP
grep -q '^todo    btop: close btop first' <<<"$out" \
    || fail "btop did not refuse while running: $out"
[ "$(cat "$EC/btop/btop.conf")" = "$btop_before" ] \
    || fail "btop.conf was rewritten while btop ran"

venc_before=$(cat "$EC/Vencord/settings/settings.json")
export WIRE_PGREP=discord
out=$(wire --apply vencord)
unset WIRE_PGREP
grep -q '^todo    vencord: close Discord first' <<<"$out" \
    || fail "vencord did not refuse while Discord ran: $out"
[ "$(cat "$EC/Vencord/settings/settings.json")" = "$venc_before" ] \
    || fail "settings.json was rewritten while Discord ran"

# --- 11. a symlinked config stays a symlink and its target is edited ---------
new_env kitty-link
mkdir -p "$EC/kitty" "$WORK/dotfiles"
printf 'font_size 12\n' >"$WORK/dotfiles/kitty.conf"
ln -s "$WORK/dotfiles/kitty.conf" "$EC/kitty/kitty.conf"
out=$(wire --apply kitty)
[ -L "$EC/kitty/kitty.conf" ] || fail "the kitty.conf symlink was replaced"
grep -qxF 'include theme.conf' "$WORK/dotfiles/kitty.conf" \
    || fail "the symlink target was not edited"
ls "$WORK/dotfiles"/kitty.conf.bak-quickshell-* >/dev/null 2>&1 \
    || fail "no backup was made next to the symlink target"

# --- 12. an unknown target exits 2 with usage -------------------------------
new_env unknown
set +e
wire --check bogus >"$WORK/out" 2>"$WORK/err"
rc=$?
set -e
[ "$rc" -eq 2 ] || fail "an unknown target exited $rc, want 2"
grep -qi 'usage: wire-themed-apps.sh' "$WORK/err" \
    || fail "an unknown target did not print usage"

# An unknown option is the same error.
set +e
wire --bogus >"$WORK/out" 2>"$WORK/err"
rc=$?
set -e
[ "$rc" -eq 2 ] || fail "an unknown option exited $rc, want 2"

# --- 13. hyprlock: an unrelated XDG_CONFIG_HOME gets an absolute source ------
rm -rf "$WORK/abs-home" "$WORK/abs-cfg"
mkdir -p "$WORK/abs-home" "$WORK/abs-cfg/hypr"
printf 'background {\n}\n' >"$WORK/abs-cfg/hypr/hyprlock.conf"
out=$(HOME="$WORK/abs-home" XDG_CONFIG_HOME="$WORK/abs-cfg" "$WIRE" --apply hyprlock)
grep -q '^wired   hyprlock' <<<"$out" || fail "hyprlock was not wired: $out"
[ "$(sed -n '1p' "$WORK/abs-cfg/hypr/hyprlock.conf")" = "source = $WORK/abs-cfg/hypr/hyprlock/colors.conf" ] \
    || fail "hyprlock did not use the absolute colors.conf path"

# --- 14. btop: a missing color_theme line is appended, other lines kept -----
new_env btop-absent
mkdir -p "$EC/btop"
printf 'update_ms = 2000\n' >"$EC/btop/btop.conf"
out=$(wire --apply btop)
grep -q '^wired   btop' <<<"$out" || fail "btop was not wired: $out"
grep -qxF 'update_ms = 2000' "$EC/btop/btop.conf" \
    || fail "the btop append dropped an existing line"
grep -qxF "color_theme = \"$EC/btop/themes/theme.theme\"" "$EC/btop/btop.conf" \
    || fail "the missing color_theme line was not appended"

# --- 15. a failing spicetify command exits 1 with a message -----------------
new_env spicetify-fail
make_spicetify
export WIRE_SPICETIFY_FAIL=1
set +e
out=$(wire --apply spicetify 2>"$WORK/err")
rc=$?
set -e
[ "$rc" -eq 1 ] || fail "a failing spicetify exited $rc, want 1"
grep -q 'spicetify config failed' "$WORK/err" \
    || fail "a failing spicetify did not explain itself"
unset WIRE_SPICETIFY_FAIL

# --- 16. hyprland: a symlinked module file or directory still counts --------
new_env hypr-symlink
mkdir -p "$EC/hypr" "$WORK/dotfiles-hypr/modules"
printf 'hl.config({})\n' >"$EC/hypr/hyprland.lua"
printf 'require("theme")\n' >"$WORK/dotfiles-hypr/modules/looks.lua"
printf 'require("theme")\n' >"$WORK/dotfiles-hypr/runtime.lua"
ln -s "$WORK/dotfiles-hypr/modules" "$EC/hypr/modules"
ln -s "$WORK/dotfiles-hypr/runtime.lua" "$EC/hypr/runtime.lua"
before=$(cat "$EC/hypr/hyprland.lua")
out=$(wire --apply hyprland)
grep -q '^ok      hyprland' <<<"$out" \
    || fail "a symlinked module require was not seen as wired: $out"
[ "$(cat "$EC/hypr/hyprland.lua")" = "$before" ] \
    || fail "hyprland.lua was edited despite a symlinked require"

# --- 17. hyprland: a require inside a Lua block comment does not count ------
new_env hypr-blockcomment
mkdir -p "$EC/hypr/modules"
printf 'hl.config({})\n' >"$EC/hypr/hyprland.lua"
printf -- '--[[\nrequire("theme")\n]]\n' >"$EC/hypr/modules/short.lua"
printf -- '--[==[ require("theme") ]==]\n' >"$EC/hypr/modules/long.lua"
out=$(wire --check hyprland)
grep -q '^todo    hyprland:' <<<"$out" \
    || fail "a block-commented require counted as wired: $out"
wire --apply hyprland >/dev/null
grep -qxF 'require("theme")' "$EC/hypr/hyprland.lua" \
    || fail "a block-commented require blocked the append"

# --- 18. firefox: a spaced/leading-space Default= resolves ------------------
new_env firefox-spaced
mkdir -p "$EC/mozilla/firefox/prof1"
printf '[Install4F96D1932A9F858E]\n  Default = prof1  \n' \
    >"$EC/mozilla/firefox/installs.ini"
printf '[Profile0]\nName = default\nIsRelative = 1\nPath = prof1\n' \
    >"$EC/mozilla/firefox/profiles.ini"
out=$(wire --apply firefox)
grep -q '^wired   firefox' <<<"$out" || fail "a spaced Default= was not resolved: $out"
[ "$(sed -n '1p' "$EC/mozilla/firefox/prof1/chrome/userChrome.css")" = '@import url("shell-palette.css");' ] \
    || fail "the spaced-Default profile was not wired"

# --- 19. kitty: a CRLF marker block is replaced -----------------------------
new_env kitty-crlf
mkdir -p "$EC/kitty"
printf 'font_size 12\r\n# BEGIN_KITTY_THEME\r\ninclude old.conf\r\n# END_KITTY_THEME\r\nshell_integration enabled\r\n' \
    >"$EC/kitty/kitty.conf"
out=$(wire --apply kitty)
grep -q '^wired   kitty: replaced the theme block' <<<"$out" \
    || fail "a CRLF marker block was not replaced: $out"
grep -q 'include theme.conf' "$EC/kitty/kitty.conf" \
    || fail "the CRLF block lost the include"
grep -q 'include old.conf' "$EC/kitty/kitty.conf" \
    && fail "the CRLF block kept the old include"

# --- 20. firefox: a CRLF sheet with the import on line 3, no duplicate ------
new_env firefox-crlf
make_firefox
CHROME="$EC/mozilla/firefox/prof.default/chrome"
mkdir -p "$CHROME"
printf '/* a */\r\n/* b */\r\n@import url("shell-palette.css");\r\n/* c */\r\n' \
    >"$CHROME/userChrome.css"
out=$(wire --apply firefox)
grep -q '^wired   firefox' <<<"$out" || fail "a CRLF sheet was not wired: $out"
[ "$(sed -n '1p' "$CHROME/userChrome.css")" = '@import url("shell-palette.css");' ] \
    || fail "the CRLF import is not on line 1"
[ "$(grep -cxF '@import url("shell-palette.css");' "$CHROME/userChrome.css")" -eq 1 ] \
    || fail "the CRLF import was duplicated"

# --- 21. kitty: only one marker is a hand-fix todo, nothing changes ---------
new_env kitty-unmatched
mkdir -p "$EC/kitty"
printf 'font_size 12\n# BEGIN_KITTY_THEME\ninclude old.conf\n' >"$EC/kitty/kitty.conf"
before=$(cat "$EC/kitty/kitty.conf")
out=$(wire --apply kitty)
grep -q '^todo    kitty: unmatched BEGIN/END_KITTY_THEME marker; fix kitty.conf by hand' <<<"$out" \
    || fail "an unmatched kitty marker was not reported: $out"
[ "$(cat "$EC/kitty/kitty.conf")" = "$before" ] \
    || fail "the unmatched kitty marker was edited"

# --- 22. vencord: the system24 base match is case-insensitive ---------------
new_env vencord-case
mkdir -p "$EC/Vencord/settings"
printf '{\n  "enabledThemes": [\n    "System24.css"\n  ]\n}\n' \
    >"$EC/Vencord/settings/settings.json"
out=$(wire --check vencord)
grep -q '^todo    vencord:' <<<"$out" || fail "vencord was not todo: $out"
grep -q 'system24 base theme' <<<"$out" \
    && fail "a case-mismatched system24 still warned: $out"

# --- 23. vencord: the system24-absent note is printed -----------------------
new_env vencord-nobase
mkdir -p "$EC/Vencord/settings"
printf '{\n  "enabledThemes": [\n    "midnight.css"\n  ]\n}\n' \
    >"$EC/Vencord/settings/settings.json"
out=$(wire --check vencord)
grep -q '^note    vencord: the theme needs the system24 base theme enabled in Vencord' <<<"$out" \
    || fail "the system24-absent note is missing: $out"

# --- 24. vencord: a non-list enabledThemes is a todo, not an exit 1 ---------
new_env vencord-badlist
mkdir -p "$EC/Vencord/settings"
printf '{\n  "enabledThemes": "quickshell.theme.css"\n}\n' \
    >"$EC/Vencord/settings/settings.json"
before=$(cat "$EC/Vencord/settings/settings.json")
set +e
out=$(wire --apply vencord 2>"$WORK/err")
rc=$?
set -e
[ "$rc" -eq 0 ] || fail "a non-list enabledThemes exited $rc, want 0"
grep -q '^todo    vencord: enabledThemes in settings.json is not a list; fix by hand' <<<"$out" \
    || fail "a non-list enabledThemes was not reported: $out"
[ "$(cat "$EC/Vencord/settings/settings.json")" = "$before" ] \
    || fail "a non-list enabledThemes was edited"

# --- 25. Firefox sheets: a fresh file gets the umask mode, an existing one --
#         keeps its own -------------------------------------------------------
new_env firefox-mode
make_firefox
( umask 0022; HOME="$EH" XDG_CONFIG_HOME="$EC" "$WIRE" --apply firefox >/dev/null )
[ "$(stat -c %a "$EC/mozilla/firefox/prof.default/chrome/userChrome.css")" = 644 ] \
    || fail "a fresh userChrome.css did not get mode 644"
printf '/* x */\n' >"$EC/mozilla/firefox/prof.default/chrome/userContent.css"
chmod 0600 "$EC/mozilla/firefox/prof.default/chrome/userContent.css"
( umask 0022; HOME="$EH" XDG_CONFIG_HOME="$EC" "$WIRE" --apply firefox >/dev/null )
[ "$(stat -c %a "$EC/mozilla/firefox/prof.default/chrome/userContent.css")" = 600 ] \
    || fail "an existing sheet did not keep its mode"

# --- 26. a backup stamp that already exists gains a suffix ------------------
new_env backup-clash
mkdir -p "$EC/kitty"
printf 'font_size 12\n' >"$EC/kitty/kitty.conf"
stamp=20250102030405
export WIRE_FAKE_TS=$stamp
printf 'sentinel\n' >"$EC/kitty/kitty.conf.bak-quickshell-$stamp"
out=$(wire --apply kitty)
unset WIRE_FAKE_TS
grep -q '^wired   kitty' <<<"$out" || fail "kitty was not wired: $out"
[ "$(cat "$EC/kitty/kitty.conf.bak-quickshell-$stamp")" = sentinel ] \
    || fail "an existing backup was overwritten"
[ -f "$EC/kitty/kitty.conf.bak-quickshell-$stamp.1" ] \
    || fail "a colliding backup did not get a numeric suffix"

# --- 27. spicetify: an absent color.ini reports the start-the-shell todo ----
new_env spicetify-nocolor
mkdir -p "$EC/spicetify"
export WIRE_SPICETIFY_INI="$EC/spicetify/config-xpui.ini"
printf '[Setting]\ncurrent_theme = text\ncolor_scheme = base\n' >"$WIRE_SPICETIFY_INI"
out=$(wire --check spicetify)
grep -q '^todo    spicetify: start the shell once so it renders the theme' <<<"$out" \
    || fail "a missing color.ini did not report the start-the-shell todo: $out"

# --- 28. one failing target does not stop the ones after it; exit is 1 ------
new_env multi-fail
make_hypr
make_spicetify
export WIRE_SPICETIFY_INI="$EC/spicetify/config-xpui.ini"
export WIRE_SPICETIFY_FAIL=1
set +e
out=$(wire --apply spicetify hyprland 2>"$WORK/err")
rc=$?
set -e
unset WIRE_SPICETIFY_FAIL
[ "$rc" -eq 1 ] || fail "a run with a failing target exited $rc, want 1"
grep -q 'spicetify config failed' "$WORK/err" \
    || fail "the failing target did not explain itself"
grep -q '^wired   hyprland' <<<"$out" \
    || fail "a later target did not run after a failure: $out"

# --- 29. argv echoed in an error is stripped of control characters ----------
new_env control
set +e
wire --check "$(printf 'x\ty')" >"$WORK/out" 2>"$WORK/err"
rc=$?
set -e
[ "$rc" -eq 2 ] || fail "a control-char target exited $rc, want 2"
grep -q 'unknown target: xy' "$WORK/err" \
    || fail "the unknown target was not sanitized: $(cat "$WORK/err")"
LC_ALL=C grep -q "$(printf 'x\ty')" "$WORK/err" \
    && fail "a raw control character reached stderr"

# --- 30. install.sh: the non-tty note keeps the 8-column status padding -----
INSTALL="$ROOT/scripts/install.sh"
new_env install-note
make_kitty
out=$(HOME="$EH" XDG_CONFIG_HOME="$EC" "$INSTALL" --no-link --no-seed </dev/null 2>/dev/null || true)
grep -q '^note    not a terminal; rerun with --wire-apps to wire the apps$' <<<"$out" \
    || fail "the install non-tty note lost its status padding: $out"

# --- 31. install.sh --wire-apps hides the repeated ok lines -----------------
new_env install-apply
make_kitty
make_btop
wire --apply kitty >/dev/null
out=$(HOME="$EH" XDG_CONFIG_HOME="$EC" "$INSTALL" --no-link --no-seed --wire-apps </dev/null 2>/dev/null || true)
[ "$(grep -c '^ok      kitty' <<<"$out")" -eq 1 ] \
    || fail "install.sh repeated the ok line from --apply: $out"
grep -q '^wired   btop' <<<"$out" || fail "install.sh did not wire btop: $out"

# --- 32. install.sh: an unknown arg is sanitized too ------------------------
set +e
HOME="$EH" XDG_CONFIG_HOME="$EC" "$INSTALL" "$(printf -- '--bad\topt')" \
    >"$WORK/out" 2>"$WORK/err"
rc=$?
set -e
[ "$rc" -eq 2 ] || fail "install.sh unknown arg exited $rc, want 2"
grep -q 'unknown arg --badopt' "$WORK/err" \
    || fail "install.sh did not sanitize the unknown arg: $(cat "$WORK/err")"

echo "wire-themed-apps: all ok"
