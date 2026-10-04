#!/usr/bin/env bash
# Headless gate for scripts/seed-themes.sh, the installer's theme seed.
#
# The seed overlays the repository's bundled themes onto the XDG theme root. The
# gate covers the fresh seed, the overlay refresh that keeps a user-added
# background, the symlink and non-directory refusals, and the bundle entries it
# must ignore. Offline: every theme is a fixture under $WORK.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SEED="$ROOT/scripts/seed-themes.sh"
WORK="$(mktemp -d /tmp/opencode/seed-themes-XXXXXX)"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "seed-themes FAIL: $*" >&2; exit 1; }

test -f "$SEED" || fail "scripts/seed-themes.sh is missing"

# A complete v4 palette (shared fixture), so a seeded theme is listable.
write_theme() {
    mkdir -p "$1/backgrounds"
    cp "$ROOT/tests/fixtures/theme-palette.toml" "$1/colors.toml"
    printf 'img' > "$1/backgrounds/one.png"
}

# --- 1. a fresh seed lands the theme and reports it ---
BUNDLE="$WORK/bundle"
write_theme "$BUNDLE/darknight"
ROOTDIR="$WORK/root-fresh"
out=$(sh "$SEED" "$BUNDLE" "$ROOTDIR")
[[ "$out" == "seeded darknight" ]] \
    || fail "fresh seed did not report 'seeded darknight': $out"
test -f "$ROOTDIR/darknight/colors.toml" \
    || fail "fresh seed did not land colors.toml"
test -f "$ROOTDIR/darknight/backgrounds/one.png" \
    || fail "fresh seed did not land the background"

# --- 2. a refresh renews the palette, adds new backgrounds, keeps existing ones ---
printf 'mine' > "$ROOTDIR/darknight/backgrounds/mine.png"
printf 'original' > "$ROOTDIR/darknight/backgrounds/one.png"
printf 'stale' > "$ROOTDIR/darknight/colors.toml"
printf 'changed' > "$BUNDLE/darknight/colors.toml"
printf 'new' > "$BUNDLE/darknight/backgrounds/two.png"
out=$(sh "$SEED" "$BUNDLE" "$ROOTDIR")
[[ "$out" == "refreshed darknight" ]] \
    || fail "refresh did not report 'refreshed darknight': $out"
grep -q 'changed' "$ROOTDIR/darknight/colors.toml" \
    || fail "refresh did not renew a bundled palette file"
test -f "$ROOTDIR/darknight/backgrounds/mine.png" \
    || fail "refresh deleted a user-added background"
[[ "$(cat "$ROOTDIR/darknight/backgrounds/one.png")" == "original" ]] \
    || fail "refresh overwrote an existing background of the same name"
test -f "$ROOTDIR/darknight/backgrounds/two.png" \
    || fail "refresh did not add a new bundled background"

# --- 3. a symlinked destination is skipped, never followed ---
LINKROOT="$WORK/root-link"
mkdir -p "$LINKROOT" "$WORK/link-target"
ln -s "$WORK/link-target" "$LINKROOT/darknight"
out=$(sh "$SEED" "$BUNDLE" "$LINKROOT" 2>"$WORK/err")
[[ -z "$out" ]] || fail "a symlinked destination still reported a seed: $out"
test -L "$LINKROOT/darknight" \
    || fail "the seed replaced the destination symlink"
test ! -e "$WORK/link-target/colors.toml" \
    || fail "the seed wrote through the destination symlink"
grep -q 'symlink' "$WORK/err" \
    || fail "the symlink skip did not explain itself"

# --- 4. a non-directory destination is skipped ---
FILEROOT="$WORK/root-file"
mkdir -p "$FILEROOT"
printf 'not a dir' > "$FILEROOT/darknight"
out=$(sh "$SEED" "$BUNDLE" "$FILEROOT" 2>"$WORK/err")
[[ -z "$out" ]] || fail "a file destination still reported a seed: $out"
grep -q 'not a directory' "$WORK/err" \
    || fail "the non-directory skip did not explain itself"
test "$(cat "$FILEROOT/darknight")" == "not a dir" \
    || fail "the seed overwrote a non-directory destination"

# --- 5. a symlinked backgrounds directory in the destination is skipped ---
BGROOT="$WORK/root-bg"
mkdir -p "$BGROOT/darknight" "$WORK/bg-outside"
printf 'x\n' > "$BGROOT/darknight/colors.toml"
ln -s "$WORK/bg-outside" "$BGROOT/darknight/backgrounds"
out=$(sh "$SEED" "$BUNDLE" "$BGROOT" 2>"$WORK/err")
[[ -z "$out" ]] || fail "a symlinked backgrounds still reported a seed: $out"
test ! -e "$WORK/bg-outside/one.png" \
    || fail "the seed wrote through a symlinked backgrounds directory"
grep -q 'symlink' "$WORK/err" \
    || fail "the backgrounds-symlink skip did not explain itself"

# --- 6. a bundle entry without colors.toml is ignored, an empty bundle is quiet ---
NOCOLORS="$WORK/bundle-nocolors"
mkdir -p "$NOCOLORS/theme"
printf 'not a theme\n' > "$NOCOLORS/theme/README.md"
out=$(sh "$SEED" "$NOCOLORS" "$WORK/root-nocolors")
[[ -z "$out" ]] || fail "a bundle entry without colors.toml was seeded: $out"
test ! -e "$WORK/root-nocolors/theme" \
    || fail "a bundle entry without colors.toml landed in the root"
out=$(sh "$SEED" "$WORK/does-not-exist" "$WORK/root-missing")
[[ -z "$out" ]] || fail "a missing bundle was not quiet: $out"

# --- 7. the repository bundle is a valid theme the scan lists ---
REPO_BUNDLE="$ROOT/assets/themes"
test -d "$REPO_BUNDLE/darknight" \
    || fail "the repository ships no assets/themes/darknight"
scan=$(sh "$ROOT/scripts/theme-catalog-scan.sh" "$REPO_BUNDLE" 262144)
printf '%s\n' "$scan" | grep -q '^darknight|' \
    || fail "the shipped darknight theme did not pass the catalog scan"
bgs=$(sh "$ROOT/scripts/theme-backgrounds-scan.sh" "$REPO_BUNDLE/darknight/backgrounds" 33554432)
test -n "$bgs" \
    || fail "the shipped darknight theme lists no backgrounds"

# --- 8. a real I/O failure exits non-zero so the installer can name it ---
BLOCK="$WORK/notdir"
printf 'a file, not a directory\n' > "$BLOCK"
if sh "$SEED" "$BUNDLE" "$BLOCK/root" >/dev/null 2>"$WORK/err"; then
    fail "a theme root that cannot be created exited zero"
fi
grep -q '^seed-themes:' "$WORK/err" \
    || fail "a failed seed did not explain itself"

echo "seed-themes: all ok"
