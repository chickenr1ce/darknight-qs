#!/usr/bin/env bash
# Headless gate for scripts/seed-btop-theme.sh, the installer's btop theme seed.
#
# The seed writes a default btop theme when the destination is absent, so btop
# always lists the retint theme. This covers the fresh seed, the no-op when the
# file exists, the symlink and non-directory refusals, and a missing renderer.
# Offline: the renderer and its template are the repo's own.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SEED="$ROOT/scripts/seed-btop-theme.sh"
WORK="$(mktemp -d "${TMPDIR:-/tmp}/qs-seed-btop-XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

fail() { echo "seed-btop-theme FAIL: $*" >&2; exit 1; }

test -f "$SEED" || fail "scripts/seed-btop-theme.sh is missing"

# --- 1. a fresh seed lands the no-theme default btop theme ---
CFG="$WORK/cfg-fresh"
out=$(sh "$SEED" "$CFG" "$ROOT")
[[ "$out" == "seeded btop theme" ]] \
    || fail "fresh seed did not report 'seeded btop theme': $out"
DEST="$CFG/btop/themes/theme.theme"
test -f "$DEST" || fail "fresh seed did not land theme.theme"
grep -q 'theme\[main_bg\]="#141118"' "$DEST" \
    || fail "seeded theme does not use the no-theme default background"
grep -q 'theme\[hi_fg\]="#b4befe"' "$DEST" \
    || fail "seeded theme does not use the no-theme default accent"
[[ "$(grep -c '^theme\[' "$DEST")" -eq 48 ]] \
    || fail "seeded theme does not carry the full 48-key set"
if grep -q '{{' "$DEST"; then
    fail "seeded theme left an unresolved template placeholder"
fi

# --- 2. a second run is a no-op ---
out=$(sh "$SEED" "$CFG" "$ROOT")
[[ -z "$out" ]] || fail "rerun reported a seed: $out"

# --- 3. an existing file is never replaced ---
printf 'mine\n' > "$DEST"
out=$(sh "$SEED" "$CFG" "$ROOT")
[[ -z "$out" ]] || fail "an existing file still reported a seed: $out"
[[ "$(cat "$DEST")" == "mine" ]] || fail "an existing file was overwritten"

# --- 4. a symlinked destination is skipped, never followed ---
LINKCFG="$WORK/cfg-link"
mkdir -p "$LINKCFG/btop/themes" "$WORK/sentinel"
printf 'sentinel\n' > "$WORK/sentinel/theme.theme"
ln -s "$WORK/sentinel/theme.theme" "$LINKCFG/btop/themes/theme.theme"
out=$(sh "$SEED" "$LINKCFG" "$ROOT" 2>"$WORK/err")
[[ -z "$out" ]] || fail "a symlinked destination still reported a seed: $out"
[[ "$(cat "$WORK/sentinel/theme.theme")" == "sentinel" ]] \
    || fail "the seed wrote through a destination symlink"
grep -q 'symlink' "$WORK/err" \
    || fail "the destination-symlink skip did not explain itself"

# --- 5. a symlinked themes directory is skipped ---
DIRCFG="$WORK/cfg-dirlink"
mkdir -p "$DIRCFG/btop" "$WORK/outside"
ln -s "$WORK/outside" "$DIRCFG/btop/themes"
out=$(sh "$SEED" "$DIRCFG" "$ROOT" 2>"$WORK/err")
[[ -z "$out" ]] || fail "a symlinked themes dir still reported a seed: $out"
test ! -e "$WORK/outside/theme.theme" \
    || fail "the seed wrote through a symlinked themes directory"
grep -q 'symlink' "$WORK/err" \
    || fail "the themes-dir-symlink skip did not explain itself"

# --- 5b. a symlinked btop/ directory is skipped ---
BTOPCFG="$WORK/cfg-btoplink"
mkdir -p "$BTOPCFG" "$WORK/btop-outside"
ln -s "$WORK/btop-outside" "$BTOPCFG/btop"
out=$(sh "$SEED" "$BTOPCFG" "$ROOT" 2>"$WORK/err")
[[ -z "$out" ]] || fail "a symlinked btop dir still reported a seed: $out"
test ! -e "$WORK/btop-outside/themes/theme.theme" \
    || fail "the seed wrote through a symlinked btop directory"
grep -q 'symlink' "$WORK/err" \
    || fail "the btop-dir-symlink skip did not explain itself"

# --- 6. a missing argument is a quiet no-op ---
out=$(sh "$SEED")
[[ -z "$out" ]] || fail "a missing argument was not quiet: $out"

# --- 7. a non-directory btop/ is a real failure the installer can name ---
BADCFG="$WORK/cfg-file"
mkdir -p "$BADCFG"
printf 'a file\n' > "$BADCFG/btop"
if sh "$SEED" "$BADCFG" "$ROOT" >/dev/null 2>"$WORK/err"; then
    fail "a non-directory btop path exited zero"
fi
grep -q '^seed-btop-theme:' "$WORK/err" \
    || fail "a failed seed did not explain itself"

# --- 8. a missing renderer is a real failure ---
if sh "$SEED" "$WORK/cfg-norender" "$WORK/no-repo" >/dev/null 2>"$WORK/err"; then
    fail "a missing renderer exited zero"
fi
grep -q 'renderer not found' "$WORK/err" \
    || fail "a missing renderer did not explain itself"

echo "seed-btop-theme: all ok"
