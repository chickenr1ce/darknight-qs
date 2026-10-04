#!/usr/bin/env bash
# Headless gate for the qs-theme CLI and the shell's theme IPC surface (ticket 04).
#
# Offline by design: install clones a local fixture git repository, so nothing
# touches the network. A stub quickshell on PATH stands in for the running
# shell, so the daily shell and the notification bus are never contacted. The
# gate covers install (root and #subdir), the name-slug traversal refusals, the
# symlink refusal, the missing-colors.toml refusal, and the IPC verb contract
# including the shell-down exit codes.
set -euo pipefail

# Git exports GIT_DIR, GIT_WORK_TREE, and GIT_INDEX_FILE into hooks. The fixture
# repositories below are created with `git -C`, which those variables override,
# so clear them or `make_repo` commits into this repository instead of the
# fixture.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLI="$ROOT/scripts/qs-theme.sh"
SVC="$ROOT/services/ThemeService.qml"
PARSE="$ROOT/services/ThemeParsers.js"
WORK="$(mktemp -d /tmp/opencode/qs-theme-XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "qs-theme FAIL: $*" >&2; exit 1; }

test -f "$CLI" || fail "scripts/qs-theme.sh is missing"

# --- 1. the shell exposes the theme IPC surface the CLI calls ---
grep -q 'IpcHandler' "$SVC" \
    || fail "ThemeService has no IpcHandler"
grep -q 'target: "theme"' "$SVC" \
    || fail "ThemeService does not register the theme IPC target"
for verb in refresh list current set background; do
    grep -q "function $verb(" "$SVC" \
        || fail "ThemeService does not expose the $verb IPC function"
done
grep -q 'ThemeParsers.backgroundName' "$SVC" \
    || fail "ThemeService does not resolve a background name through ThemeParsers"
grep -q 'reconcileActiveTheme' "$SVC" \
    || fail "ThemeService does not reconcile an active theme that left the catalog"
grep -q 'catalogReady' "$SVC" \
    || fail "ThemeService does not track a completed catalog scan"
grep -q 'displaySafe' "$SVC" \
    || fail "ThemeService does not sanitize untrusted IPC strings before echoing them"
grep -q 'hasControlChars' "$PARSE" \
    || fail "ThemeParsers does not reject control characters in names"
grep -q 'function refreshBackgrounds' "$SVC" \
    || fail "ThemeService does not expose refreshBackgrounds"
grep -q 'refreshBackgrounds()' "$SVC" \
    || fail "the refresh IPC does not rescan backgrounds"
grep -q 'defaultThemeName: "darknight"' "$SVC" \
    || fail "ThemeService does not name darknight as the bundled default theme"
grep -q 'hasTheme(root.defaultThemeName)' "$SVC" \
    || fail "the default theme is not gated on catalog membership"
grep -q 'ThemeParsers.isSelectionObject' "$SVC" \
    || fail "ThemeService does not distinguish a saved selection from a corrupt one"
grep -A8 'function applyDefaultTheme' "$SVC" | grep -q 'selectionKnown' \
    || fail "applyDefaultTheme does not respect a restored selection"
grep -q 'function isSelectionObject' "$PARSE" \
    || fail "ThemeParsers has no selection-object predicate"

# --- 2. backgroundName boundary oracle (mirror of services/ThemeParsers.js) ---
ORACLE_MANIFEST="$WORK/oracle-names.json" python3 - <<'EOF'
import json
import os
import re
import sys

CONTROL = re.compile(r"[\x00-\x1f\x7f]")

def check(name, got, want):
    if got != want:
        print(f"qs-theme FAIL: backgroundName {name}: got {got!r}, want {want!r}", file=sys.stderr)
        sys.exit(1)

# Mirror of ThemeParsers.backgroundName (services/ThemeParsers.js): take the
# last path segment, reject an empty name, a leading dot, any ".." in the
# basename, a pipe, and a missing or unlisted extension (jpg, jpeg, png, webp,
# bmp, case-insensitive). A directory part is dropped, so a path can never
# escape the backgrounds directory.
SUFFIXES = (".jpg", ".jpeg", ".png", ".webp", ".bmp")

def background_name(value):
    if not isinstance(value, str):
        return ""
    text = value.strip()
    slash = max(text.rfind("/"), text.rfind("\\"))
    base = text[slash + 1:] if slash >= 0 else text
    if base == "" or base[0] == "." or ".." in base or "|" in base:
        return ""
    if CONTROL.search(base):
        return ""
    dot = base.rfind(".")
    if dot <= 0:
        return ""
    if base[dot:].lower() not in SUFFIXES:
        return ""
    return base

check("plain", background_name("swirl.png"), "swirl.png")
check("path", background_name("/x/y.webp"), "y.webp")
check("nested-path", background_name("backgrounds/a/b.jpeg"), "b.jpeg")
check("backslash-path", background_name("a\\b.bmp"), "b.bmp")
check("case-extension", background_name("art.JPG"), "art.JPG")
check("pad", background_name("  pad.png  "), "pad.png")
check("traversal-path", background_name("../escape.png"), "escape.png")
check("inner-dotdot", background_name("a..png"), "")
check("inner-dotdot-mid", background_name("a..b.png"), "")
check("pipe", background_name("a|b.png"), "")
check("hidden", background_name(".hidden.png"), "")
check("no-extension", background_name("noext"), "")
check("other-extension", background_name("anim.gif"), "")
check("empty", background_name(""), "")
check("trailing-slash", background_name("dir/"), "")
check("non-string", background_name(None), "")
check("leading-dot-extension", background_name(".png"), "")
check("embedded-newline", background_name("a\n.png"), "")
check("ansi-escape", background_name("\x1b]0;evil\x07.png"), "")
check("embedded-tab", background_name("a\tb.png"), "")

# Hand the same inputs and the oracle's verdict to the shell parity check
# (section 22), so the CLI's own name rule cannot drift from this mirror
# unnoticed. The inputs are the check() calls above; the verifier is the same
# background_name, so only a change to the rule moves both.
manifest = os.environ.get("ORACLE_MANIFEST")
if manifest:
    with open(manifest, "w") as handle:
        json.dump([
            {"value": value, "accept": background_name(value) != ""}
            for value in (
                "swirl.png", "/x/y.webp", "backgrounds/a/b.jpeg", "a\\b.bmp",
                "art.JPG", "  pad.png  ", "../escape.png", "a..png", "a..b.png",
                "a|b.png", ".hidden.png", "noext", "anim.gif", "", "dir/", ".png",
                "a\n.png", "\x1b]0;evil\x07.png", "a\tb.png",
                "star*.png", "-dash.png",
            )
        ], handle)
EOF
echo "qs-theme: backgroundName oracle ok"

# --- fixtures and a stub shell ---
STUBDIR="$WORK/bin"
mkdir -p "$STUBDIR"
cat > "$STUBDIR/quickshell" <<'STUB'
#!/bin/sh
if [ "${QS_THEME_STUB:-up}" = "down" ]; then
    echo "No running instances" >&2
    exit 255
fi
if [ "${QS_THEME_STUB:-up}" = "missing" ]; then
    printf '%s\n' 'Target not found.'
    exit 0
fi
fn=$4
case $fn in
    list) printf '%s\n' '  nord (dark)' '* tokyo-night (dark)' ;;
    current) printf '%s\n' 'tokyo-night' ;;
    set)
        if [ "$5" = "nope" ]; then
            printf '%s\n' 'error: no theme named nope'
        else
            printf 'ok: %s\n' "$5"
        fi
        ;;
    background) printf 'ok: %s\n' "${5##*/}" ;;
    refresh) printf '%s\n' 'ok: refreshed' ;;
    *) printf '%s\n' 'Target not found.' ;;
esac
STUB
chmod +x "$STUBDIR/quickshell"
export PATH="$STUBDIR:$PATH"

# A complete v4 palette (shared fixture), so a catalog fixture is listable under
# the full-palette requirement (M4) as well as installable.
write_theme() {
    mkdir -p "$1"
    cp "$ROOT/tests/fixtures/theme-palette.toml" "$1/colors.toml"
}

make_repo() {
    local repo="$1"
    git -C "$repo" init -q
    git -C "$repo" add -A
    git -C "$repo" -c user.name=qs-theme -c user.email=qs-theme@example.test commit -qm init
}

url_of() {
    printf 'file://%s' "$1"
}

# --- 3. install a plain repo: lands, drops .git, leaves no temp ---
PLAIN="$WORK/plain/tokyo-night"
write_theme "$PLAIN"
make_repo "$PLAIN"
DATA="$WORK/data-plain"
XDG_DATA_HOME="$DATA" sh "$CLI" install "$(url_of "$PLAIN")" >"$WORK/out" 2>"$WORK/err"
grep -q 'cloning' "$WORK/err" \
    || fail "install did not announce the clone"
grep -q '^installed tokyo-night$' "$WORK/out" \
    || fail "install did not report success on stdout"
THEME="$DATA/quickshell/themes/tokyo-night"
test -f "$THEME/colors.toml" \
    || fail "install did not land the theme in the root"
test ! -e "$THEME/.git" \
    || fail "install shipped the .git directory"
test -z "$(find "$DATA/quickshell" -maxdepth 1 -name '.qs-theme-*' -print -quit)" \
    || fail "install left a temporary directory behind"
test "$(find "$DATA/quickshell/themes" -mindepth 1 -maxdepth 1 | wc -l)" -eq 1 \
    || fail "install wrote more than the one theme directory"

# --- 3b. a failed clone is reported ---
DATA="$WORK/data-badclone"
if XDG_DATA_HOME="$DATA" sh "$CLI" install "$(url_of "$WORK/does-not-exist")" 2>"$WORK/err"; then
    fail "install accepted a repository that does not exist"
fi
grep -q 'git clone failed' "$WORK/err" \
    || fail "a failed clone did not explain itself"
test -z "$(find "$DATA/quickshell" -maxdepth 1 -name '.qs-theme-*' -print -quit 2>/dev/null)" \
    || fail "a failed clone left a temporary directory behind"

# --- 4. a nested repo installs through #subdir ---
NESTED="$WORK/nested/omarchy-themes"
write_theme "$NESTED/themes/neon"
make_repo "$NESTED"
DATA="$WORK/data-subdir"
XDG_DATA_HOME="$DATA" sh "$CLI" install "$(url_of "$NESTED")#themes/neon" >/dev/null 2>&1
test -f "$DATA/quickshell/themes/neon/colors.toml" \
    || fail "#subdir did not install the nested theme"

# --- 5. the repo slug strips omarchy- and -theme ---
SLUGGED="$WORK/slug/omarchy-rose-pine-theme"
write_theme "$SLUGGED"
make_repo "$SLUGGED"
DATA="$WORK/data-slug"
XDG_DATA_HOME="$DATA" sh "$CLI" install "$(url_of "$SLUGGED")" >/dev/null 2>&1
test -f "$DATA/quickshell/themes/rose-pine/colors.toml" \
    || fail "the repo slug did not normalize to rose-pine"

# --- 6. a traversing #subdir is refused before any write ---
DATA="$WORK/data-traverse"
if XDG_DATA_HOME="$DATA" sh "$CLI" install "$(url_of "$PLAIN")#../escape" 2>"$WORK/err"; then
    fail "install accepted a traversing #subdir"
fi
test ! -e "$DATA/quickshell/themes/escape" \
    || fail "install wrote outside the validated slug"
test -z "$(find "$DATA" -name 'escape*' -print -quit 2>/dev/null)" \
    || fail "a traversing #subdir reached the filesystem"

# --- 7. a traversing repo name is refused ---
DATA="$WORK/data-traverse-name"
if XDG_DATA_HOME="$DATA" sh "$CLI" install "$(url_of "$PLAIN")/.." 2>"$WORK/err"; then
    fail "install accepted a traversing repo name"
fi
test ! -e "$DATA/quickshell/themes/.." \
    || fail "a traversing repo name reached the root"

# --- 7b. a name with a control character is refused ---
# The slug check once used a line-oriented grep, so "a<newline>b" passed and
# created a newline-named theme directory that split the catalog output.
CTRLNAME=$'evil\nname'
CTRLREPO="$WORK/ctrl/repo"
write_theme "$CTRLREPO/$CTRLNAME"
make_repo "$CTRLREPO"
DATA="$WORK/data-control"
if XDG_DATA_HOME="$DATA" sh "$CLI" install "$(url_of "$CTRLREPO")#$CTRLNAME" 2>"$WORK/err"; then
    fail "install accepted a name with an embedded newline"
fi
test -z "$(find "$DATA" -name '*evil*' -print -quit 2>/dev/null)" \
    || fail "a control-character name reached the filesystem"
if XDG_DATA_HOME="$DATA" sh "$CLI" remove "$CTRLNAME" 2>"$WORK/err"; then
    fail "remove accepted a name with an embedded newline"
fi

# --- 7c. a git transport helper is refused before the clone ---
# git's `ext::` helper runs a command instead of fetching, so a typed helper
# must never reach the clone.
DATA="$WORK/data-transport"
if XDG_DATA_HOME="$DATA" sh "$CLI" install 'ext::true' 2>"$WORK/err"; then
    fail "install accepted a git transport helper"
fi
grep -q 'transport helper' "$WORK/err" \
    || fail "the transport-helper refusal did not explain itself"
test -z "$(find "$DATA/quickshell" -maxdepth 1 -name '.qs-theme-*' -print -quit 2>/dev/null)" \
    || fail "a refused transport helper still created a temporary directory"

# --- 8. a source holding a symlink is refused ---
LINKED="$WORK/linked/repo"
write_theme "$LINKED"
ln -s /etc/passwd "$LINKED/leak"
make_repo "$LINKED"
DATA="$WORK/data-symlink"
if XDG_DATA_HOME="$DATA" sh "$CLI" install "$(url_of "$LINKED")" 2>"$WORK/err"; then
    fail "install accepted a symlinked entry"
fi
test ! -e "$DATA/quickshell/themes/repo" \
    || fail "install installed a theme that holds a symlink"
grep -q 'symlink' "$WORK/err" \
    || fail "the symlink refusal did not explain itself"

# --- 8b. a symlinked ancestor of #subdir is refused ---
SECURE="$WORK/secure/repo"
write_theme "$WORK/secure/outside/evil"
mkdir -p "$SECURE"
ln -s "$WORK/secure/outside" "$SECURE/secure"
make_repo "$SECURE"
DATA="$WORK/data-ancestor"
if XDG_DATA_HOME="$DATA" sh "$CLI" install "$(url_of "$SECURE")#secure/evil" 2>"$WORK/err"; then
    fail "install followed a symlinked #subdir component"
fi
test ! -e "$DATA/quickshell/themes/evil" \
    || fail "install escaped the clone through a symlinked #subdir component"
grep -q 'symlink' "$WORK/err" \
    || fail "the symlinked-ancestor refusal did not explain itself"

# --- 9. a theme without colors.toml is refused ---
EMPTY="$WORK/empty/nocolors"
mkdir -p "$EMPTY"
printf 'not a theme\n' > "$EMPTY/README.md"
make_repo "$EMPTY"
DATA="$WORK/data-nocolors"
if XDG_DATA_HOME="$DATA" sh "$CLI" install "$(url_of "$EMPTY")" 2>"$WORK/err"; then
    fail "install accepted a directory without colors.toml"
fi

# --- 10. reinstalling replaces the existing theme ---
DATA="$WORK/data-replace"
XDG_DATA_HOME="$DATA" sh "$CLI" install "$(url_of "$PLAIN")" >/dev/null 2>&1
printf 'stale\n' > "$DATA/quickshell/themes/tokyo-night/stale.txt"
XDG_DATA_HOME="$DATA" sh "$CLI" install "$(url_of "$PLAIN")" >/dev/null 2>&1
test ! -e "$DATA/quickshell/themes/tokyo-night/stale.txt" \
    || fail "reinstall did not replace the existing theme"

# --- 11. install succeeds with the shell down ---
DATA="$WORK/data-down"
QS_THEME_STUB=down XDG_DATA_HOME="$DATA" sh "$CLI" install "$(url_of "$PLAIN")" >/dev/null 2>&1 \
    || fail "install failed while the shell was down"
test -f "$DATA/quickshell/themes/tokyo-night/colors.toml" \
    || fail "install did not land the theme with the shell down"

# --- 12. the IPC verbs print the shell's result ---
sh "$CLI" list | grep -q 'tokyo-night' \
    || fail "list did not print the catalog"
sh "$CLI" list | grep -q '^\* tokyo-night' \
    || fail "list did not mark the active theme"
sh "$CLI" current | grep -q '^tokyo-night$' \
    || fail "current did not print the active theme"
sh "$CLI" set nord | grep -q '^nord$' \
    || fail "set did not report the new theme"
sh "$CLI" background /themes/x/2-swirl.webp | grep -q '^2-swirl.webp$' \
    || fail "background did not report the stored name"
if sh "$CLI" set nope 2>"$WORK/err"; then
    fail "set accepted an unknown theme"
fi
grep -q 'no theme named nope' "$WORK/err" \
    || fail "set did not explain the unknown theme"

# --- 13. set and background fail non-zero when the shell is down ---
for verb in "set nord" "background x.png"; do
    if QS_THEME_STUB=down sh "$CLI" $verb 2>"$WORK/err"; then
        fail "$verb succeeded with the shell down"
    fi
    grep -q 'not running' "$WORK/err" \
        || fail "$verb did not explain the shell-down failure"
done
if QS_THEME_STUB=down sh "$CLI" current >/dev/null 2>&1; then
    fail "current succeeded with the shell down"
fi

# --- 14. a shell without the theme service fails loudly ---
# The daily shell may run a build predating this feature. quickshell prints
# "Target not found." and still exits 0, so the CLI must catch it rather than
# reporting success.
for verb in list current "set nord"; do
    if QS_THEME_STUB=missing sh "$CLI" $verb 2>"$WORK/err"; then
        fail "$verb succeeded when the shell had no theme service"
    fi
    grep -q 'no theme service' "$WORK/err" \
        || fail "$verb did not explain the missing theme service"
done

# --- 15. the script does not force a locale on the shell ---
# LC_ALL=C leaked into quickshell and made Qt warn about a non-UTF-8 locale.
# The C locale is scoped to the slug check only.
if grep -q 'export LC_ALL' "$CLI"; then
    fail "qs-theme.sh exports LC_ALL, which leaks into the quickshell process"
fi

# --- 16. remove deletes a theme and refuses unsafe input ---
DATA="$WORK/data-remove"
XDG_DATA_HOME="$DATA" sh "$CLI" install "$(url_of "$PLAIN")" >/dev/null 2>&1
XDG_DATA_HOME="$DATA" sh "$CLI" remove tokyo-night >"$WORK/out" 2>"$WORK/err"
test ! -e "$DATA/quickshell/themes/tokyo-night" \
    || fail "remove left the theme directory behind"
grep -q '^removed tokyo-night$' "$WORK/out" \
    || fail "remove did not report success on stdout"
if XDG_DATA_HOME="$DATA" sh "$CLI" remove tokyo-night 2>"$WORK/err"; then
    fail "remove accepted a theme that is not installed"
fi
grep -q 'no theme named' "$WORK/err" \
    || fail "remove did not explain the missing theme"

DATA="$WORK/data-remove-traverse"
mkdir -p "$DATA/quickshell/themes/keep" "$DATA/outside"
printf 'x\n' > "$DATA/quickshell/themes/keep/colors.toml"
printf 'x\n' > "$DATA/outside/colors.toml"
if XDG_DATA_HOME="$DATA" sh "$CLI" remove '../outside' 2>"$WORK/err"; then
    fail "remove accepted a traversing name"
fi
test -f "$DATA/outside/colors.toml" \
    || fail "remove deleted a path outside the theme root"

DATA="$WORK/data-remove-symlink"
mkdir -p "$DATA/quickshell/themes" "$DATA/real"
printf 'x\n' > "$DATA/real/colors.toml"
ln -s "$DATA/real" "$DATA/quickshell/themes/linked"
if XDG_DATA_HOME="$DATA" sh "$CLI" remove linked 2>"$WORK/err"; then
    fail "remove deleted a symlinked theme directory"
fi
test -f "$DATA/real/colors.toml" \
    || fail "remove followed a symlink out of the theme root"

# --- 17. the catalog scan skips names that break the output protocol ---
# A newline in a directory name split the `name|mode` line into a phantom
# entry, and a pipe in a name shifted the name/mode boundary.
SCAN="$ROOT/scripts/theme-catalog-scan.sh"
CAT="$WORK/catalog"
write_theme "$CAT/real"
write_theme "$CAT/$CTRLNAME"
write_theme "$CAT/pipe|name"
out=$(sh "$SCAN" "$CAT" 262144)
printf '%s\n' "$out" | grep -q '^real|' \
    || fail "the catalog scan dropped a valid theme"
test "$(printf '%s\n' "$out" | wc -l)" -eq 1 \
    || fail "the catalog scan emitted a control or pipe name"

# --- 18. add-background copies images into a theme ---
ADD="$WORK/data-add"
mkdir -p "$ADD/quickshell/themes/tokyo-night"
write_theme "$ADD/quickshell/themes/tokyo-night"
SRC="$WORK/add-src"
mkdir -p "$SRC"
printf 'one' > "$SRC/photo.png"
printf 'two' > "$SRC/art.JPG"
printf 'no' > "$SRC/notes.txt"

# The stub's active theme is tokyo-night; backgrounds/ is created on demand.
XDG_DATA_HOME="$ADD" sh "$CLI" add-background "$SRC/photo.png" >"$WORK/out" 2>"$WORK/err"
grep -q '^added photo.png$' "$WORK/out" \
    || fail "add-background did not report the added file"
test -f "$ADD/quickshell/themes/tokyo-night/backgrounds/photo.png" \
    || fail "add-background did not copy the image into backgrounds/"

# --theme names the theme and works with the shell down.
if ! QS_THEME_STUB=down XDG_DATA_HOME="$ADD" sh "$CLI" add-background --theme tokyo-night "$SRC/art.JPG" >/dev/null 2>&1; then
    fail "add-background --theme failed with the shell down"
fi
test -f "$ADD/quickshell/themes/tokyo-night/backgrounds/art.JPG" \
    || fail "add-background --theme did not copy the image"

# The picker's scan sees the added images.
scan_out=$(sh "$ROOT/scripts/theme-backgrounds-scan.sh" "$ADD/quickshell/themes/tokyo-night/backgrounds" 33554432 | LC_ALL=C sort)
printf '%s\n' "$scan_out" | grep -q '^art.JPG$' \
    || fail "the scan missed the added JPG"
printf '%s\n' "$scan_out" | grep -q '^photo.png$' \
    || fail "the scan missed the added PNG"

# An unlisted extension is refused.
if XDG_DATA_HOME="$ADD" sh "$CLI" add-background --theme tokyo-night "$SRC/notes.txt" 2>"$WORK/err"; then
    fail "add-background accepted a .txt file"
fi
grep -q 'not a background image' "$WORK/err" \
    || fail "the extension refusal did not explain itself"

# A collision is refused without --force.
if XDG_DATA_HOME="$ADD" sh "$CLI" add-background --theme tokyo-night "$SRC/photo.png" 2>"$WORK/err"; then
    fail "add-background overwrote an existing name without --force"
fi
grep -q 'already exists' "$WORK/err" \
    || fail "the collision refusal did not explain itself"

# --force replaces the file.
printf 'replaced' > "$SRC/photo.png"
XDG_DATA_HOME="$ADD" sh "$CLI" add-background --theme tokyo-night --force "$SRC/photo.png" >/dev/null 2>&1
grep -q 'replaced' "$ADD/quickshell/themes/tokyo-night/backgrounds/photo.png" \
    || fail "add-background --force did not replace the file"

# An oversized file is refused and nothing lands.
truncate -s 33554433 "$SRC/big.png"
if XDG_DATA_HOME="$ADD" sh "$CLI" add-background --theme tokyo-night "$SRC/big.png" 2>"$WORK/err"; then
    fail "add-background accepted an oversized image"
fi
grep -q 'larger than 32 MB' "$WORK/err" \
    || fail "the size refusal did not explain itself"
test ! -e "$ADD/quickshell/themes/tokyo-night/backgrounds/big.png" \
    || fail "an oversized image reached the theme"

# A missing theme and a traversing theme name are refused.
if XDG_DATA_HOME="$ADD" sh "$CLI" add-background --theme nope "$SRC/art.JPG" 2>"$WORK/err"; then
    fail "add-background accepted a theme that is not installed"
fi
if XDG_DATA_HOME="$ADD" sh "$CLI" add-background --theme ../escape "$SRC/art.JPG" 2>"$WORK/err"; then
    fail "add-background accepted a traversing theme name"
fi

# A symlinked theme directory is refused.
mkdir -p "$WORK/add-real"
ln -s "$WORK/add-real" "$ADD/quickshell/themes/linkedtheme"
if XDG_DATA_HOME="$ADD" sh "$CLI" add-background --theme linkedtheme "$SRC/art.JPG" 2>"$WORK/err"; then
    fail "add-background wrote through a symlinked theme directory"
fi
test ! -e "$WORK/add-real/backgrounds/art.JPG" \
    || fail "add-background escaped through a symlinked theme directory"

# A symlinked backgrounds directory is refused.
mkdir -p "$ADD/quickshell/themes/bgtheme" "$WORK/add-outside"
write_theme "$ADD/quickshell/themes/bgtheme"
ln -s "$WORK/add-outside" "$ADD/quickshell/themes/bgtheme/backgrounds"
if XDG_DATA_HOME="$ADD" sh "$CLI" add-background --theme bgtheme "$SRC/art.JPG" 2>"$WORK/err"; then
    fail "add-background wrote through a symlinked backgrounds directory"
fi
test ! -e "$WORK/add-outside/art.JPG" \
    || fail "add-background escaped through a symlinked backgrounds directory"

# No file argument is a usage error.
if XDG_DATA_HOME="$ADD" sh "$CLI" add-background --theme tokyo-night 2>"$WORK/err"; then
    fail "add-background accepted no file"
fi
grep -q 'usage: qs-theme add-background' "$WORK/err" \
    || fail "add-background did not print its usage"

# --- 19. add-background mirrors the JS backgroundName ---
# A leading space is trimmed and a backslash is a path separator in both the
# parser and the shell, so the CLI stores the name the picker will list.
MIRROR="$WORK/data-mirror"
mkdir -p "$MIRROR/quickshell/themes/mirrortheme"
write_theme "$MIRROR/quickshell/themes/mirrortheme"
MSRC="$WORK/mirror-src"
mkdir -p "$MSRC"
printf 'spaced' > "$MSRC/ pad.png"
printf 'back' > "$MSRC/a\\b.png"
XDG_DATA_HOME="$MIRROR" sh "$CLI" add-background --theme mirrortheme "$MSRC/ pad.png" >"$WORK/out" 2>"$WORK/err"
grep -q '^added pad.png$' "$WORK/out" \
    || fail "add-background did not trim a leading space in the name"
test -f "$MIRROR/quickshell/themes/mirrortheme/backgrounds/pad.png" \
    || fail "add-background stored the untrimmed name"
XDG_DATA_HOME="$MIRROR" sh "$CLI" add-background --theme mirrortheme "$MSRC/a\\b.png" >"$WORK/out" 2>"$WORK/err"
grep -q '^added b.png$' "$WORK/out" \
    || fail "add-background did not take the segment after a backslash"
test -f "$MIRROR/quickshell/themes/mirrortheme/backgrounds/b.png" \
    || fail "add-background did not store the backslash segment"

# Two inputs that share a basename are refused before anything is copied, so
# neither silently overwrites the other; --force keeps the last.
DUP="$WORK/data-dup"
mkdir -p "$DUP/quickshell/themes/duptheme" "$WORK/dup-a" "$WORK/dup-b"
write_theme "$DUP/quickshell/themes/duptheme"
printf 'one' > "$WORK/dup-a/wall.png"
printf 'two' > "$WORK/dup-b/wall.png"
if XDG_DATA_HOME="$DUP" sh "$CLI" add-background --theme duptheme "$WORK/dup-a/wall.png" "$WORK/dup-b/wall.png" 2>"$WORK/err"; then
    fail "add-background accepted two inputs sharing a basename"
fi
grep -q 'more than one input is named wall.png' "$WORK/err" \
    || fail "the duplicate-basename refusal did not explain itself"
test ! -e "$DUP/quickshell/themes/duptheme/backgrounds/wall.png" \
    || fail "a duplicate basename reached the theme before the refusal"
XDG_DATA_HOME="$DUP" sh "$CLI" add-background --theme duptheme --force "$WORK/dup-a/wall.png" "$WORK/dup-b/wall.png" >/dev/null 2>&1
grep -q 'two' "$DUP/quickshell/themes/duptheme/backgrounds/wall.png" \
    || fail "add-background --force did not keep the last duplicate"

# --- 20. install replaces a dangling symlink at the destination ---
DANGLE="$WORK/data-dangle"
mkdir -p "$DANGLE/quickshell/themes"
ln -s "$WORK/does-not-exist" "$DANGLE/quickshell/themes/tokyo-night"
if ! XDG_DATA_HOME="$DANGLE" sh "$CLI" install "$(url_of "$PLAIN")" >/dev/null 2>"$WORK/err"; then
    fail "install could not replace a dangling symlink at the destination"
fi
test -d "$DANGLE/quickshell/themes/tokyo-night" \
    || fail "the dangling symlink was not replaced by the theme directory"
test ! -L "$DANGLE/quickshell/themes/tokyo-night" \
    || fail "the destination is still a symlink"
test -f "$DANGLE/quickshell/themes/tokyo-night/colors.toml" \
    || fail "the replacement theme is missing colors.toml"
# An interrupted replace restores the backed-up theme rather than deleting it
# with the temp directory.
grep -q 'mv -- "\$backup" "\$dest"' "$CLI" \
    || fail "install cleanup does not restore a backed-up theme"

# --- 21. remove-background deletes images from a theme ---
RM="$WORK/data-remove-bg"
mkdir -p "$RM/quickshell/themes/tokyo-night/backgrounds"
write_theme "$RM/quickshell/themes/tokyo-night"
printf 'one' > "$RM/quickshell/themes/tokyo-night/backgrounds/first.png"
printf 'two' > "$RM/quickshell/themes/tokyo-night/backgrounds/second.JPG"
printf 'three' > "$RM/quickshell/themes/tokyo-night/backgrounds/third.webp"

# By name, --theme, with the shell down.
QS_THEME_STUB=down XDG_DATA_HOME="$RM" sh "$CLI" remove-background --theme tokyo-night first.png >"$WORK/out" 2>"$WORK/err"
grep -q '^removed first.png$' "$WORK/out" \
    || fail "remove-background did not report the removed name"
test ! -e "$RM/quickshell/themes/tokyo-night/backgrounds/first.png" \
    || fail "remove-background left the image in place"

# A directory prefix is dropped, mirroring add-background and the picker.
QS_THEME_STUB=down XDG_DATA_HOME="$RM" sh "$CLI" remove-background --theme tokyo-night "/x/y/second.JPG" >"$WORK/out" 2>"$WORK/err"
grep -q '^removed second.JPG$' "$WORK/out" \
    || fail "remove-background did not take the segment after a slash"
test ! -e "$RM/quickshell/themes/tokyo-night/backgrounds/second.JPG" \
    || fail "remove-background did not remove the path-prefixed name"

QS_THEME_STUB=down XDG_DATA_HOME="$RM" sh "$CLI" remove-background --theme tokyo-night third.webp >/dev/null 2>&1
test "$(find "$RM/quickshell/themes/tokyo-night/backgrounds" -type f | wc -l)" -eq 0 \
    || fail "remove-background left files behind"

# The active theme is the default target (the stub reports tokyo-night).
printf 'active' > "$RM/quickshell/themes/tokyo-night/backgrounds/active.png"
XDG_DATA_HOME="$RM" sh "$CLI" remove-background active.png >"$WORK/out" 2>"$WORK/err"
grep -q '^removed active.png$' "$WORK/out" \
    || fail "remove-background did not default to the active theme"
test ! -e "$RM/quickshell/themes/tokyo-night/backgrounds/active.png" \
    || fail "remove-background did not remove from the active theme"

# With the shell down and no --theme, the active theme cannot be resolved.
printf 'keep' > "$RM/quickshell/themes/tokyo-night/backgrounds/keep.png"
if QS_THEME_STUB=down XDG_DATA_HOME="$RM" sh "$CLI" remove-background keep.png 2>"$WORK/err"; then
    fail "remove-background resolved a theme with the shell down and no --theme"
fi
grep -q 'no active theme' "$WORK/err" \
    || fail "the no-active-theme refusal did not explain itself"

# A name that is not there is refused and nothing else is touched.
if XDG_DATA_HOME="$RM" sh "$CLI" remove-background --theme tokyo-night missing.png 2>"$WORK/err"; then
    fail "remove-background accepted a name that is not installed"
fi
grep -q 'no background named' "$WORK/err" \
    || fail "the missing-name refusal did not explain itself"
test -f "$RM/quickshell/themes/tokyo-night/backgrounds/keep.png" \
    || fail "a refused removal deleted a file"

# Every argument is validated before any deletion: a bad second name leaves the
# first in place.
printf 'a' > "$RM/quickshell/themes/tokyo-night/backgrounds/one.png"
if XDG_DATA_HOME="$RM" sh "$CLI" remove-background --theme tokyo-night one.png nope.txt 2>"$WORK/err"; then
    fail "remove-background accepted a non-image name"
fi
grep -q 'not a background image' "$WORK/err" \
    || fail "the non-image refusal did not explain itself"
test -f "$RM/quickshell/themes/tokyo-night/backgrounds/one.png" \
    || fail "remove-background deleted before validating every argument"

# No argument is a usage error.
if XDG_DATA_HOME="$RM" sh "$CLI" remove-background --theme tokyo-night 2>"$WORK/err"; then
    fail "remove-background accepted no name"
fi
grep -q 'usage: qs-theme remove-background' "$WORK/err" \
    || fail "remove-background did not print its usage"

# An unknown option is refused.
if XDG_DATA_HOME="$RM" sh "$CLI" remove-background --bogus tokyo-night 2>"$WORK/err"; then
    fail "remove-background accepted an unknown option"
fi

# A missing theme and a traversing theme name are refused.
if XDG_DATA_HOME="$RM" sh "$CLI" remove-background --theme nope one.png 2>"$WORK/err"; then
    fail "remove-background accepted a theme that is not installed"
fi
if XDG_DATA_HOME="$RM" sh "$CLI" remove-background --theme ../escape one.png 2>"$WORK/err"; then
    fail "remove-background accepted a traversing theme name"
fi

# A symlinked theme directory is refused and its target is untouched.
mkdir -p "$WORK/remove-real"
printf 'x' > "$WORK/remove-real/one.png"
ln -s "$WORK/remove-real" "$RM/quickshell/themes/linkedrm"
if XDG_DATA_HOME="$RM" sh "$CLI" remove-background --theme linkedrm one.png 2>"$WORK/err"; then
    fail "remove-background went through a symlinked theme directory"
fi
test -f "$WORK/remove-real/one.png" \
    || fail "remove-background escaped through a symlinked theme directory"

# A symlinked backgrounds directory is refused.
mkdir -p "$RM/quickshell/themes/bgrm" "$WORK/remove-outside"
write_theme "$RM/quickshell/themes/bgrm"
printf 'x' > "$WORK/remove-outside/one.png"
ln -s "$WORK/remove-outside" "$RM/quickshell/themes/bgrm/backgrounds"
if XDG_DATA_HOME="$RM" sh "$CLI" remove-background --theme bgrm one.png 2>"$WORK/err"; then
    fail "remove-background went through a symlinked backgrounds directory"
fi
test -f "$WORK/remove-outside/one.png" \
    || fail "remove-background escaped through a symlinked backgrounds directory"

# A symlinked entry is refused rather than unlinked.
mkdir -p "$RM/quickshell/themes/symrm/backgrounds"
write_theme "$RM/quickshell/themes/symrm"
printf 'x' > "$WORK/remove-outside/real.png"
ln -s "$WORK/remove-outside/real.png" "$RM/quickshell/themes/symrm/backgrounds/real.png"
if XDG_DATA_HOME="$RM" sh "$CLI" remove-background --theme symrm real.png 2>"$WORK/err"; then
    fail "remove-background accepted a symlinked entry"
fi
test -f "$WORK/remove-outside/real.png" \
    || fail "remove-background followed a symlinked entry"

# A glob character in a name is literal, and several names delete in one run.
GLOB="$WORK/data-remove-glob"
mkdir -p "$GLOB/quickshell/themes/globtheme/backgrounds"
write_theme "$GLOB/quickshell/themes/globtheme"
printf '1' > "$GLOB/quickshell/themes/globtheme/backgrounds/star*.png"
printf '2' > "$GLOB/quickshell/themes/globtheme/backgrounds/plain.png"
printf '3' > "$GLOB/quickshell/themes/globtheme/backgrounds/other.png"
XDG_DATA_HOME="$GLOB" sh "$CLI" remove-background --theme globtheme 'star*.png' plain.png >"$WORK/out" 2>"$WORK/err"
grep -qxF 'removed star*.png' "$WORK/out" \
    || fail "remove-background did not treat a glob character in a name literally"
grep -qxF 'removed plain.png' "$WORK/out" \
    || fail "remove-background did not remove both names in one run"
test -f "$GLOB/quickshell/themes/globtheme/backgrounds/other.png" \
    || fail "remove-background removed a name it was not given"
test ! -e "$GLOB/quickshell/themes/globtheme/backgrounds/plain.png" \
    || fail "remove-background left one of the requested names"

# A name repeated in one run is removed once.
printf 'd' > "$GLOB/quickshell/themes/globtheme/backgrounds/dup.png"
XDG_DATA_HOME="$GLOB" sh "$CLI" remove-background --theme globtheme dup.png dup.png >"$WORK/out" 2>"$WORK/err"
test "$(grep -c '^removed dup.png$' "$WORK/out")" -eq 1 \
    || fail "remove-background reported a repeated name more than once"
test ! -e "$GLOB/quickshell/themes/globtheme/backgrounds/dup.png" \
    || fail "remove-background did not remove a repeated name"

# A leading-dash name is reachable with --.
printf 'n' > "$GLOB/quickshell/themes/globtheme/backgrounds/-dash.png"
XDG_DATA_HOME="$GLOB" sh "$CLI" remove-background --theme globtheme -- -dash.png >"$WORK/out" 2>"$WORK/err"
grep -qxF 'removed -dash.png' "$WORK/out" \
    || fail "remove-background could not remove a leading-dash name with --"

# A theme with no backgrounds directory is refused.
mkdir -p "$GLOB/quickshell/themes/nobg"
write_theme "$GLOB/quickshell/themes/nobg"
if XDG_DATA_HOME="$GLOB" sh "$CLI" remove-background --theme nobg any.png 2>"$WORK/err"; then
    fail "remove-background accepted a theme with no backgrounds directory"
fi
grep -q 'has no backgrounds' "$WORK/err" \
    || fail "the no-backgrounds refusal did not explain itself"

# --- 22. the shell name rule agrees with the JS oracle (section 2) ---
# backgroundName lives in three live places (ThemeParsers.js, qs-theme.sh's
# background_name_of, theme-backgrounds-scan.sh). This drives the CLI's copy
# over the oracle's input table, so the CLI rejecting a name the picker would
# list (or the reverse) fails the gate.
PARITY="$WORK/data-parity"
mkdir -p "$PARITY/quickshell/themes/parity/backgrounds"
write_theme "$PARITY/quickshell/themes/parity"
CLI="$CLI" ORACLE_MANIFEST="$WORK/oracle-names.json" PARITY="$PARITY" python3 - <<'EOF'
import json
import os
import subprocess
import sys

with open(os.environ["ORACLE_MANIFEST"]) as handle:
    cases = json.load(handle)

env = dict(os.environ, XDG_DATA_HOME=os.environ["PARITY"], QS_THEME_STUB="down")
mismatches = []
for case in cases:
    value = case["value"]
    proc = subprocess.run(
        ["sh", os.environ["CLI"], "remove-background", "--theme", "parity", "--", value],
        env=env, capture_output=True, text=True,
    )
    rejected = "not a background image" in proc.stderr
    if rejected == case["accept"]:
        mismatches.append((value, case["accept"], proc.stderr.strip()))

if mismatches:
    for value, accept, err in mismatches:
        print(
            f"qs-theme FAIL: shell name rule disagrees with the oracle for {value!r}: "
            f"oracle accept={accept}, cli stderr={err!r}",
            file=sys.stderr,
        )
    sys.exit(1)
EOF
echo "qs-theme: shell name rule matches the JS oracle"

echo "qs-theme: all ok"
