#!/usr/bin/env bash
# install.sh — check this machine and wire the common Quickshell paths.
#
# Reports the required and optional tools, naming the Arch/CachyOS package for
# each missing one, the three font families the shell names, and a notification
# daemon that would fight the shell for org.freedesktop.Notifications. Then it
# owns exactly two symlinks:
#
#   ~/.config/quickshell        -> this clone        (only with --link, or ask)
#   ~/.local/bin/qs-theme       -> scripts/qs-theme.sh
#
# and seeds the bundled themes under assets/themes/ into the XDG theme root
# ~/.local/share/quickshell/themes (skip with --no-seed), so a fresh install
# has a theme to pick without a qs-theme install. The seed renews a theme's own
# files and adds a bundled background the installed theme lacks; an existing
# background is never overwritten, so a user's replacement survives an update.
# When btop is installed it also seeds a default btop theme into
# <config>/btop/themes, so btop lists the retint theme before the shell has ever
# rendered a palette.
# It never edits your Hyprland config; it prints the exec-once line
# instead. An existing real file or directory is never replaced elsewhere on
# disk. Run from any clone path.
#
# Usage: scripts/install.sh [--link|--no-link] [--seed|--no-seed] [--help]
set -euo pipefail

ROOT="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
CONFIG_LINK="${XDG_CONFIG_HOME:-$HOME/.config}/quickshell"
QS_THEME_LINK="$HOME/.local/bin/qs-theme"
THEME_BUNDLE="$ROOT/assets/themes"
THEME_ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/quickshell/themes"
BT_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

LINK_MODE=ask
SEED_MODE=yes
MISSING_REQUIRED=()

usage() {
    cat <<EOF
install.sh — check this machine and wire the common Quickshell paths.

Usage: scripts/install.sh [--link|--no-link] [--seed|--no-seed]

Options:
  --link       link this clone into $CONFIG_LINK (overwrites a symlink, not a real path)
  --no-link    skip both symlinks, but still seed the bundled themes
  --seed       seed the bundled themes and the btop theme (default)
  --no-seed    skip seeding the bundled themes and the btop theme
  --help       this message

Without a flag the clone link is offered on a terminal and skipped when not.
The qs-theme symlink is created unless --no-link is given; the theme seed
unless --no-seed is given.
EOF
}

ok()   { printf 'ok    %s\n' "$*"; }
warn() { printf 'warn  %s\n' "$*"; }
miss() { printf 'FAIL  %s\n' "$*"; }

have() { command -v "$1" >/dev/null 2>&1; }

# Required tools: missing means the bar cannot come up, so each is collected
# for a non-zero exit. Every message names the Arch/CachyOS package that
# provides the tool. Runs from any clone path; the tools live on PATH.
check_required() {
    local label="$1" package="$2"
    shift 2
    if "$@"; then
        ok "$label"
    else
        miss "$label (required) — install package: $package"
        MISSING_REQUIRED+=("$label")
    fi
}

# Optional tools: a missing one degrades one feature, so warn only.
check_optional() {
    local label="$1" package="$2"
    shift 2
    if "$@"; then
        ok "$label"
    else
        warn "$label not found (optional) — install package: $package"
    fi
}

has_hyprland() { have hyprland || have hyprctl; }

# The power menu's Lock action needs exactly one of these, so the trio is a
# single check and reads as "one of".
check_lockscreen() {
    local found
    for found in hyprlock betterlockscreen i3lock; do
        if have "$found"; then
            ok "lock screen ($found)"
            return
        fi
    done
    warn "no lock screen tool (optional) — install one of: hyprlock (official), betterlockscreen (AUR), i3lock (official)"
}

# Quickshell 0.3.1 is the floor named in the README. Parse the version and
# compare with sort -V; an unparseable string stays a warning, not a failure.
check_quickshell() {
    have quickshell || { miss "quickshell (required) — install package: quickshell"; MISSING_REQUIRED+=("quickshell"); return; }
    local raw version
    raw="$(quickshell --version 2>/dev/null | head -n1 || true)"
    version="$(printf '%s\n' "$raw" | awk '{print $2}')"
    if [[ -z "$version" ]]; then
        warn "quickshell present, version not parsed from: ${raw:-<no output>}"
        return
    fi
    if [[ "$(printf '%s\n%s\n' "0.3.1" "$version" | sort -V | head -n1)" == "0.3.1" ]]; then
        ok "quickshell $version"
    else
        miss "quickshell $version (need 0.3.1 or newer) — install package: quickshell"
        MISSING_REQUIRED+=("quickshell >= 0.3.1")
    fi
}

# fc-list enumerates every installed family; the shell asks for an exact family
# name, so an exact match is what matters. Exit 2 means fc-list itself is
# absent, which is a distinct "cannot check" result, not "present".
font_present() {
    local want="$1" name
    if ! command -v fc-list >/dev/null 2>&1; then
        return 2
    fi
    while IFS= read -r name; do
        name="${name#"${name%%[![:space:]]*}"}"
        name="${name%"${name##*[![:space:]]}"}"
        [[ "$name" == "$want" ]] && return 0
    done < <(fc-list -f '%{family}\n' 2>/dev/null | tr ',' '\n')
    return 1
}

check_font() {
    local want="$1" package="$2" note="${3:-}" rc=0
    font_present "$want" || rc=$?
    case "$rc" in
        0) ok "font $want" ;;
        2) warn "fc-list not found; cannot check font $want — install package: $package" ;;
        *)
            if [[ -n "$note" ]]; then
                warn "font $want not installed (optional) — install package: $package; $note"
            else
                warn "font $want not installed (optional) — install package: $package"
            fi
            ;;
    esac
}

# The process holding org.freedesktop.Notifications, from busctl's table.
# Falls back to a running mako/dunst when busctl cannot answer.
notification_holder() {
    local name=""
    if command -v busctl >/dev/null 2>&1; then
        name="$(busctl --user --no-pager list 2>/dev/null \
            | awk '$1 == "org.freedesktop.Notifications" { print $3; exit }')"
        if [[ -n "$name" ]]; then
            printf '%s\n' "$name"
            return 0
        fi
    fi
    if command -v pgrep >/dev/null 2>&1; then
        if pgrep -x mako >/dev/null 2>&1; then printf 'mako\n'; return 0; fi
        if pgrep -x dunst >/dev/null 2>&1; then printf 'dunst\n'; return 0; fi
    fi
    return 1
}

# Replace only a symlink or a missing path; a real file or directory stays.
link_config() {
    if [[ -L "$CONFIG_LINK" && "$(readlink -f "$CONFIG_LINK")" == "$ROOT" ]]; then
        ok "$CONFIG_LINK already points here"
        return
    fi
    if [[ -e "$CONFIG_LINK" && ! -L "$CONFIG_LINK" ]]; then
        warn "$CONFIG_LINK exists and is not a symlink; leaving it alone"
        return
    fi
    mkdir -p "$(dirname "$CONFIG_LINK")"
    ln -sfn "$ROOT" "$CONFIG_LINK"
    ok "linked $CONFIG_LINK -> $ROOT"
}

link_qs_theme() {
    local src="$ROOT/scripts/qs-theme.sh"
    if [[ -L "$QS_THEME_LINK" && "$(readlink -f "$QS_THEME_LINK")" == "$(readlink -f "$src")" ]]; then
        ok "$QS_THEME_LINK already points here"
        return
    fi
    if [[ -L "$QS_THEME_LINK" ]]; then
        warn "$QS_THEME_LINK points elsewhere; leaving it alone"
        return
    fi
    if [[ -e "$QS_THEME_LINK" ]]; then
        warn "$QS_THEME_LINK exists and is not a symlink; leaving it alone"
        return
    fi
    mkdir -p "$(dirname "$QS_THEME_LINK")"
    ln -s "$src" "$QS_THEME_LINK"
    ok "linked $QS_THEME_LINK -> $src"
}

# Seed the repository's bundled themes into the XDG theme root. The seed script
# owns the copy rules and reports one `seeded`/`refreshed` line per theme; its
# skips (a symlinked or non-directory destination) go straight to stderr. A
# missing bundle is not an error.
seed_themes() {
    if [[ ! -d "$THEME_BUNDLE" ]]; then
        return
    fi
    local out line
    if ! out="$(sh "$ROOT/scripts/seed-themes.sh" "$THEME_BUNDLE" "$THEME_ROOT")"; then
        warn "seeding bundled themes failed"
        return
    fi
    while IFS= read -r line; do
        [[ -n "$line" ]] && ok "$line"
    done <<<"$out"
    return 0
}

# Seed a default btop retint theme so btop lists it before the shell has
# rendered a palette. seed-btop-theme.sh owns the rules; it prints
# `seeded btop theme` on a fresh seed and explains its skips on stderr.
seed_btop_theme() {
    local out line
    if ! out="$(sh "$ROOT/scripts/seed-btop-theme.sh" "$BT_CONFIG_HOME" "$ROOT")"; then
        warn "seeding the btop theme failed"
        return
    fi
    while IFS= read -r line; do
        [[ -n "$line" ]] && ok "$line"
    done <<<"$out"
    return 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --link)    LINK_MODE=yes ;;
        --no-link) LINK_MODE=no ;;
        --seed)    SEED_MODE=yes ;;
        --no-seed) SEED_MODE=no ;;
        -h|--help) usage; exit 0 ;;
        *) echo "install: unknown arg $1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

echo "install: checking required tools"
check_quickshell
check_required "hyprland" "hyprland" has_hyprland
check_required "pipewire" "pipewire" have pipewire
check_required "wpctl" "wireplumber" have wpctl
check_required "cava" "cava" have cava
check_required "curl" "curl" have curl
check_required "python3" "python" have python3

echo
echo "install: checking optional tools"
check_optional "playerctl" "playerctl" have playerctl
check_optional "mpc" "mpc" have mpc
check_optional "gcalcli" "gcalcli (AUR)" have gcalcli
check_optional "awww" "awww" have awww
check_lockscreen

echo
echo "install: checking fonts"
check_font "Iosevka" "ttc-iosevka"
check_font "Geist" "otf-geist (AUR)"
check_font "GeistMono Nerd Font" "otf-geist-mono-nerd" "config/Icons.qml renders boxes without it"

echo
echo "install: checking the notification bus"
holder="$(notification_holder || true)"
case "$holder" in
    mako|dunst)
        warn "$holder holds org.freedesktop.Notifications; stop and disable it before starting the shell"
        ;;
    "")
        ok "no mako/dunst on org.freedesktop.Notifications"
        ;;
    *)
        ok "org.freedesktop.Notifications held by $holder"
        ;;
esac

echo
echo "install: install commands: see the Prerequisites block in README.md"

echo
echo "install: wiring paths"
case "$LINK_MODE" in
    yes) link_config ;;
    no)  : ;;
    ask)
        if [[ -t 0 ]]; then
            read -r -p "Link this clone into $CONFIG_LINK? [y/N] " reply
            case "$reply" in
                y|Y|yes|YES) link_config ;;
                *) warn "clone link skipped; rerun with --link to add it" ;;
            esac
        else
            echo "note  not a terminal; rerun with --link to link this clone into $CONFIG_LINK"
        fi
        ;;
esac
if [[ "$LINK_MODE" != "no" ]]; then
    link_qs_theme
fi

if [[ "$SEED_MODE" == "yes" ]]; then
    echo
    echo "install: seeding bundled themes into $THEME_ROOT"
    seed_themes
    if have btop; then
        seed_btop_theme
    fi
fi

echo
echo "install: optional Hyprland autostart (add it yourself, this never edits your config)"
printf '  exec-once = quickshell -p %s\n' "$ROOT"
printf '  exec-once = quickshell    # after linking the clone into %s\n' "$CONFIG_LINK"

echo
echo "install: optional app retint (add it yourself, this never edits your config)"
echo '  see docs/user/theme-desktop-setup.md (btop: pick "theme" in the options menu)'

echo
if [[ ${#MISSING_REQUIRED[@]} -gt 0 ]]; then
    printf 'install: FAIL, missing required: %s\n' "${MISSING_REQUIRED[*]}" >&2
    exit 1
fi
echo "install: all required tools present"
