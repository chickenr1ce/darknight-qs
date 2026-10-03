#!/bin/sh
# Render the active palette into the desktop config files this repo owns:
#   ~/.config/hypr/theme.lua
#   ~/.config/kitty/theme.conf
#   ~/.config/hypr/hyprlock/colors.conf
#   ~/.config/starship.toml
#
# Usage: render-theme.sh '<palette-json>'
#
# The palette JSON is the resolved role set parsed from the active theme
# palette. This script substitutes those roles into the templates under
# assets/templates/ and writes the result. It never reads or evaluates a theme
# directory, and it writes a file only when the rendered bytes change. An empty
# palette argument renders the built-in no-theme default below.
#
# Output paths follow XDG_CONFIG_HOME, falling back to HOME/.config, so the
# headless gate can redirect them. See docs/theme-desktop-setup.md for the
# user-side include lines.
set -eu

palette=${1:-}
# No palette means no active theme. The bar falls back to its hardcoded Colors
# values, so the desktop files must fall back to the same look rather than keep
# the previous theme (a medium finding in the merge review). This default
# mirrors the pre-theme hexes in config/Colors.qml; the required roles that
# Colors does not name are given coherent values.
if [ -z "$palette" ]; then
    palette='{"mode":"dark","accent":"#b4befe","selection":"#282936","muted":"#9d93ad","background":"#141118","dark_background":"#27222f","darker_background":"#0f0d13","lighter_background":"#282936","foreground":"#cac4d4","dark_foreground":"#4f455f","light_foreground":"#e8e3f0","bright_foreground":"#ffffff","red":"#ff5252","yellow":"#d7d370","green":"#a6d189","cyan":"#7dcfff","blue":"#82a1ff","magenta":"#a980db","bright_red":"#ff7a93","bright_yellow":"#e8c96a","bright_green":"#c0e8a0","bright_cyan":"#9bd4e8","bright_blue":"#a6c1ff","bright_magenta":"#c7a9ff"}'
fi

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
template_dir=$script_dir/../assets/templates
config_home=${XDG_CONFIG_HOME:-}
if [ -z "$config_home" ]; then
    [ -n "${HOME:-}" ] || exit 0
    config_home=$HOME/.config
fi

exec python3 - "$palette" "$template_dir" "$config_home" <<'PY'
import json
import os
import sys

palette_raw, template_dir, config_home = sys.argv[1:4]

try:
    palette = json.loads(palette_raw)
except (TypeError, ValueError):
    sys.exit(0)
if not isinstance(palette, dict):
    sys.exit(0)

HEX_DIGITS = set("0123456789abcdefABCDEF")

REQUIRED = (
    "background", "dark_background", "lighter_background", "foreground",
    "muted", "selection", "accent",
    "red", "yellow", "green", "cyan", "blue", "magenta",
    "bright_red", "bright_yellow", "bright_green", "bright_cyan",
    "bright_blue", "bright_magenta", "bright_foreground",
)


def channels(value):
    """Return (r, g, b, rrggbbaa) for a #rgb/#rgba/#rrggbb/#rrggbbaa string."""
    if not isinstance(value, str):
        return None
    text = value.strip().lstrip("#")
    if len(text) == 3:
        text = text[0] * 2 + text[1] * 2 + text[2] * 2
    elif len(text) == 4:
        text = text[0] * 2 + text[1] * 2 + text[2] * 2 + text[3] * 2
    if len(text) not in (6, 8) or any(c not in HEX_DIGITS for c in text):
        return None
    text = text.lower()
    if len(text) == 6:
        text += "ff"
    return (int(text[0:2], 16), int(text[2:4], 16), int(text[4:6], 16), text)


def rgb(value):
    parts = channels(value)
    return None if parts is None else "rgb(%d, %d, %d)" % parts[:3]


def hypr_rgba(value, alpha=None):
    parts = channels(value)
    if parts is None:
        return None
    return parts[3][:6] + (alpha if alpha is not None else parts[3][6:8])


for key in REQUIRED:
    if channels(palette.get(key)) is None:
        sys.exit(0)

tokens = {key: "#" + channels(palette[key])[3][:6] for key in REQUIRED}
active = palette.get("hyprland_active_border")
tokens["active_hex"] = hypr_rgba(
    active if channels(active) else palette["accent"])
inactive = palette.get("hyprland_inactive_border")
tokens["inactive_hex"] = hypr_rgba(
    inactive if channels(inactive) else palette["accent"],
    None if channels(inactive) else "aa")
for key, suffix in (("background", "background_rgb"),
                    ("foreground", "foreground_rgb"),
                    ("accent", "accent_rgb"),
                    ("muted", "muted_rgb"),
                    ("red", "red_rgb")):
    tokens[suffix] = rgb(palette[key])

JOBS = (
    ("hypr-theme.lua", os.path.join(config_home, "hypr", "theme.lua")),
    ("kitty-theme.conf", os.path.join(config_home, "kitty", "theme.conf")),
    ("hyprlock-colors.conf",
     os.path.join(config_home, "hypr", "hyprlock", "colors.conf")),
    ("starship-theme.toml", os.path.join(config_home, "starship.toml")),
)


def substitute(text):
    for key, value in tokens.items():
        text = text.replace("{{%s}}" % key, value)
    return text


def write_if_changed(path, data):
    try:
        with open(path, "rb") as handle:
            if handle.read() == data:
                return
    except OSError:
        pass
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "wb") as handle:
        handle.write(data)
    os.replace(tmp, path)


rendered = []
for name, dest in JOBS:
    with open(os.path.join(template_dir, name), encoding="utf-8") as handle:
        text = substitute(handle.read())
    if "{{" in text:
        sys.exit(1)
    rendered.append((dest, text.encode("utf-8")))

for dest, data in rendered:
    write_if_changed(dest, data)
PY
