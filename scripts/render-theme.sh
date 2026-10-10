#!/bin/sh
# Render the active palette into the desktop config files this repo owns:
#   ~/.config/hypr/theme.lua
#   ~/.config/kitty/theme.conf
#   ~/.config/hypr/hyprlock/colors.conf
#   ~/.config/starship.toml
#   ~/.config/yazi/theme.toml
#   ~/.config/btop/themes/theme.theme
#   ~/.config/Vencord/themes/quickshell.theme.css
#   <firefox-profile>/chrome/shell-palette.css
#   <firefox-profile>/chrome/shell-content.css
#   <firefox-profile>/user.js
#   ~/.config/spicetify/Themes/quickshell/color.ini
#   ~/.config/spicetify/Themes/quickshell/user.css
#
# Usage: render-theme.sh '<palette-json>' [<enabled-target-keys>]
#
# The palette JSON is the resolved role set parsed from the active theme
# palette. This script substitutes those roles into the templates under
# assets/templates/ and writes the result. It never reads or evaluates a theme
# directory, and it writes a file only when the rendered bytes change. An empty
# palette argument renders the built-in no-theme default below.
#
# The optional second argument is a comma-separated list of enabled target keys
# (hyprland, kitty, hyprlock, starship, yazi, btop, firefox, vencord,
# spicetify). An absent argument enables every target; an empty string enables
# none. Each target renders in isolation, so one failure never aborts the rest,
# and a disabled target writes a valid unthemed layer instead of a missing file.
#
# Output paths follow XDG_CONFIG_HOME, falling back to HOME/.config, so the
# headless gate can redirect them. The Firefox root is the exception: it reads
# XDG_CONFIG_HOME/HOME from the environment inside Python. See
# docs/user/theme-desktop-setup.md for the user-side include lines.
set -eu

palette=${1:-}
# ${2:-} collapses an absent second argument and an empty one to the same
# string, so test the argument count: only a missing argument means all-on.
# Pass the sentinel through verbatim; Python reads it before it splits the CSV.
if [ "$#" -ge 2 ]; then
    enabled_keys=$2
else
    enabled_keys=__ALL__
fi

# CDPATH= is cleared for cd; shellcheck 0.11 misreads it as SC1007.
# shellcheck disable=SC1007
script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
template_dir=$script_dir/../assets/templates
config_home=${XDG_CONFIG_HOME:-}
if [ -z "$config_home" ]; then
    [ -n "${HOME:-}" ] || exit 0
    config_home=$HOME/.config
fi

exec python3 - "$palette" "$template_dir" "$config_home" "$enabled_keys" <<'PY'
import json
import os
import re
import shutil
import subprocess
import sys

palette_raw, template_dir, config_home, enabled_raw = sys.argv[1:5]

# No palette means no active theme. The bar falls back to its hardcoded Colors
# values, so the desktop files must fall back to the same look rather than keep
# the previous theme (a medium finding in the merge review). This default
# mirrors the pre-theme hexes in config/Colors.qml; the required roles Colors
# does not name are given coherent values. It is also the disabled layer for the
# whole-config targets below, so this literal lives here alone.
DEFAULT_PALETTE = {
    "mode": "dark",
    "accent": "#b4befe",
    "selection": "#282936",
    "muted": "#9d93ad",
    "background": "#141118",
    "dark_background": "#27222f",
    "darker_background": "#0f0d13",
    "lighter_background": "#282936",
    "foreground": "#cac4d4",
    "dark_foreground": "#4f455f",
    "light_foreground": "#e8e3f0",
    "bright_foreground": "#ffffff",
    "red": "#ff5252",
    "yellow": "#d7d370",
    "green": "#a6d189",
    "cyan": "#7dcfff",
    "blue": "#82a1ff",
    "magenta": "#a980db",
    "orange": "#f0a868",
    "brown": "#a97b5e",
    "bright_red": "#ff7a93",
    "bright_yellow": "#e8c96a",
    "bright_green": "#c0e8a0",
    "bright_cyan": "#9bd4e8",
    "bright_blue": "#a6c1ff",
    "bright_magenta": "#c7a9ff",
}

if palette_raw == "":
    palette = DEFAULT_PALETTE
else:
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

# Every role a template may name. The optional ones a palette need not carry
# fall back to a required role, so a Vencord `--bg-4` or a Spicetify `header`
# resolves instead of failing the unresolved-token check. They stay out of
# REQUIRED: a palette missing a required role is still a no-op.
ROLES = REQUIRED + (
    "darker_background", "dark_foreground", "light_foreground", "orange",
    "brown",
)
OPTIONAL = {
    "darker_background": "dark_background",
    "dark_foreground": "muted",
    "light_foreground": "foreground",
    "orange": "yellow",
    "brown": "red",
}

# The unresolved-token check matches a {{name}} shape, not any brace pair, so
# CSS and Lua braces in a template render without failing (ADR 0018).
UNRESOLVED = re.compile(r"\{\{[A-Za-z0-9_]+\}\}")

PILL_TEXT_MIN = 3.0

# Comment-only disabled layers, one per comment syntax. The whole-config
# targets (starship, hyprlock) render their template from DEFAULT_PALETTE
# instead, because a comment-only file would wipe the prompt or leave the
# hyprlock `$theme_*` variables undefined.
DISABLED_LUA = "-- quickshell theme target disabled\n"
DISABLED_HASH = "# quickshell theme target disabled\n"
DISABLED_CSS = "/* quickshell theme target disabled */\n"


class RenderError(Exception):
    pass


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


# starship paints each pill with `bg:selection` and a per-module hue for its
# text. A hue only reads when it contrasts with the pill; when it does not (a
# light theme whose selection and hues are all mid-tone) the text falls back to
# a black-or-white ink chosen against `selection`. Themes whose hues already
# contrast keep them, so this changes nothing for those.
def luminance(value):
    parts = channels(value)
    if parts is None:
        return None
    def channel(c):
        c = c / 255
        return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = parts[:3]
    return 0.2126 * channel(r) + 0.7152 * channel(g) + 0.0722 * channel(b)


def contrast(a, b):
    la, lb = luminance(a), luminance(b)
    if la is None or lb is None:
        return 0.0
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def ink(value):
    return "#000000" if contrast("#000000", value) >= contrast("#ffffff", value) else "#ffffff"


def build_tokens(palette):
    tokens = {}
    # The CSS `color-scheme` keyword from the palette mode, so the Firefox
    # content sheet's native controls and scrollbars follow the palette instead
    # of the system scheme. Anything but an explicit "light" is dark, the same
    # default DEFAULT_PALETTE carries.
    tokens["page_scheme"] = "light" if palette.get("mode") == "light" else "dark"
    for role in ROLES:
        value = palette.get(role)
        if channels(value) is None and role in OPTIONAL:
            value = palette.get(OPTIONAL[role])
        if channels(value) is not None:
            tokens[role] = "#" + channels(value)[3][:6]
    # A bare six-digit form of every role for the INI target; {{role}} stays
    # #rrggbb. Replace order is safe: `{{accent}}` never matches `{{accent_hex}}`.
    for role in ROLES:
        if role in tokens:
            tokens[role + "_hex"] = tokens[role][1:]
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
        tokens[suffix] = rgb(tokens[key])
    selection = tokens["selection"]
    tokens["selection_ink"] = ink(selection)
    for key in ("accent", "red", "yellow", "magenta", "blue", "cyan"):
        tokens["text_" + key] = tokens[key] if contrast(tokens[key], selection) >= PILL_TEXT_MIN else tokens["selection_ink"]
    # yazi paints chip text on a colored background and body text on the app
    # background. Each hue gets a black-or-white ink chosen against itself for
    # the chips, and a background-contrast variant for body text, so a light
    # theme with mid-tone hues stays readable.
    background_ink = ink(tokens["background"])
    tokens["background_ink"] = background_ink
    for key in ("accent", "red", "yellow", "blue", "magenta", "cyan"):
        tokens["on_" + key] = ink(tokens[key])
        tokens["readable_" + key] = (
            tokens[key] if contrast(tokens[key], tokens["background"]) >= PILL_TEXT_MIN
            else background_ink)
    # A five-step text ramp for the Vencord template, which is pure
    # substitution and cannot branch on mode: the palette's foreground roles
    # ordered by contrast against the background, text_1 the highest contrast
    # down to text_5 the lowest.
    ramp = ("bright_foreground", "foreground", "light_foreground", "muted",
            "dark_foreground")
    ordered = sorted(
        (tokens.get(role, tokens["foreground"]) for role in ramp),
        key=lambda value: contrast(value, tokens["background"]),
        reverse=True)
    for index, value in enumerate(ordered, start=1):
        tokens["text_%d" % index] = value
    return tokens


for key in REQUIRED:
    if channels(palette.get(key)) is None:
        sys.exit(0)

tokens = build_tokens(palette)
default_tokens = build_tokens(DEFAULT_PALETTE)


def substitute(text, source_tokens):
    for key, value in source_tokens.items():
        text = text.replace("{{%s}}" % key, value)
    return text


def load(name, source_tokens):
    with open(os.path.join(template_dir, name), encoding="utf-8") as handle:
        text = substitute(handle.read(), source_tokens)
    if UNRESOLVED.search(text):
        raise RenderError("unresolved placeholder in %s" % name)
    return text


def write_if_changed(path, data):
    try:
        with open(path, "rb") as handle:
            if handle.read() == data:
                return False
    except OSError:
        pass
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "wb") as handle:
        handle.write(data)
    os.replace(tmp, path)
    return True


def emit(path, text):
    return write_if_changed(path, text.encode("utf-8"))


def render_hyprland(enabled):
    dest = os.path.join(config_home, "hypr", "theme.lua")
    if not enabled:
        return emit(dest, DISABLED_LUA)
    return emit(dest, load("hypr-theme.lua", tokens))


def render_kitty(enabled):
    dest = os.path.join(config_home, "kitty", "theme.conf")
    if not enabled:
        return emit(dest, DISABLED_HASH)
    return emit(dest, load("kitty-theme.conf", tokens))


def render_hyprlock(enabled):
    dest = os.path.join(config_home, "hypr", "hyprlock", "colors.conf")
    return emit(dest, load(
        "hyprlock-colors.conf", tokens if enabled else default_tokens))


def render_starship(enabled):
    dest = os.path.join(config_home, "starship.toml")
    return emit(dest, load(
        "starship-theme.toml", tokens if enabled else default_tokens))


def render_yazi(enabled):
    dest = os.path.join(config_home, "yazi", "theme.toml")
    if not enabled:
        return emit(dest, DISABLED_HASH)
    return emit(dest, load("yazi-theme.toml", tokens))


def render_btop(enabled):
    dest = os.path.join(config_home, "btop", "themes", "theme.theme")
    if not enabled:
        return emit(dest, DISABLED_HASH)
    return emit(dest, load("btop-theme.theme", tokens))


# Vencord lives under the app's own config root. When that root is absent the
# user has no Discord to recolor, so the target skips as success instead of
# creating a directory for an install that is not there. Enablement stays
# manual: the renderer never touches Vencord's settings file,
# which is not watched for reload and would clobber an edit.
def render_vencord(enabled):
    vencord_root = os.path.join(config_home, "Vencord")
    if not os.path.isdir(vencord_root):
        sys.stderr.write("vencord: not installed\n")
        return False
    dest = os.path.join(vencord_root, "themes", "quickshell.theme.css")
    if not enabled:
        return emit(dest, load("vencord-theme-disabled.css", {}))
    return emit(dest, load("vencord-theme.css", tokens))


# Firefox is themed by two generated sheets plus a managed block in user.js
# that turns on legacy stylesheet support. The user imports the chrome sheet
# from userChrome.css and the content sheet from userContent.css. The renderer
# never creates or edits either user sheet; it only writes the shell-* targets.
# The profile is discovered from installs.ini because profiles.ini's Default=1
# names an empty stub here. The root is read from os.environ, not the
# config_home the wrapper passes; a Snap or Flatpak Firefox root is out of scope.
INSTALL_SECTION = re.compile(r"^(?:Install)?[0-9A-Fa-f]+$")
USERJS_BEGIN = "// BEGIN quickshell"
USERJS_END = "// END quickshell"
USERJS_PREF = re.compile(
    r"""user_pref\s*\(\s*["']toolkit\.legacyUserProfileCustomizations\.stylesheets["']""")


def parse_ini_text(text):
    """Ordered (section, key/value dict) pairs from INI text."""
    entries = []
    section = None
    values = {}
    for line in text.splitlines():
        stripped = line.strip()
        if not stripped or stripped[0] in "#;":
            continue
        if stripped.startswith("[") and stripped.endswith("]"):
            if section is not None:
                entries.append((section, values))
            section = stripped[1:-1].strip()
            values = {}
            continue
        if section is None or "=" not in stripped:
            continue
        key, _, value = stripped.partition("=")
        values[key.strip()] = value.strip()
    if section is not None:
        entries.append((section, values))
    return entries


def parse_ini(path):
    """Ordered (section, key/value dict) pairs; a missing file yields none."""
    try:
        with open(path, encoding="utf-8") as handle:
            text = handle.read()
    except OSError:
        return []
    return parse_ini_text(text)


def firefox_root():
    config_home = os.environ.get("XDG_CONFIG_HOME", "")
    if not config_home:
        config_home = os.path.join(os.environ.get("HOME", ""), ".config")
    candidate = os.path.join(config_home, "mozilla", "firefox")
    if os.path.isdir(candidate):
        return candidate
    return os.path.join(os.environ.get("HOME", ""), ".mozilla", "firefox")


def firefox_profile():
    """The default profile directory, or None. installs.ini names it; a
    profiles.ini entry, matched by the exact Path name, supplies IsRelative or
    an absolute Path. The symlinked profile path is never resolved, so a psd
    target under /run stays writable."""
    root = firefox_root()
    default_name = None
    install_sections = [
        (section, values)
        for section, values in parse_ini(os.path.join(root, "installs.ini"))
        if INSTALL_SECTION.match(section)]
    winner = None
    for section, values in install_sections:
        if values.get("Default"):
            winner = (section, values)
            break
    if len(install_sections) > 1 and winner is not None:
        sys.stderr.write(
            "firefox: multiple install sections; using %s\n" % winner[0])
    if winner is None:
        return None
    default_name = winner[1]["Default"]
    profile = os.path.join(root, default_name)
    for section, values in parse_ini(os.path.join(root, "profiles.ini")):
        if not section.startswith("Profile"):
            continue
        path = values.get("Path", "")
        if path != default_name and os.path.basename(path) != default_name:
            continue
        profile = path if values.get("IsRelative") == "0" else os.path.join(root, path)
        break
    if not os.path.isdir(profile):
        return None
    return profile


def merge_userjs(existing, block):
    """Return existing with the managed block replaced or inserted, keeping
    every other line. A pref set outside the markers is adopted into the block
    instead of being duplicated."""
    if existing is None:
        return block
    kept = []
    insertion = None
    inside = False
    buffered = []
    for line in existing.splitlines(keepends=True):
        text = line.strip()
        if inside:
            if text == USERJS_END:
                inside = False
                buffered = []
                continue
            buffered.append(line)
            continue
        if text == USERJS_BEGIN:
            inside = True
            buffered = []
            if insertion is None:
                insertion = len(kept)
            continue
        if text.startswith("user_pref") and USERJS_PREF.search(text):
            if insertion is None:
                insertion = len(kept)
            continue
        kept.append(line)
    if inside:
        # No END marker: the BEGIN line was a hand-edit truncation, so keep the
        # lines that followed it as user content instead of discarding them.
        kept.extend(buffered)
    if insertion is None:
        insertion = 0
    return "".join(kept[:insertion] + block.splitlines(keepends=True) + kept[insertion:])


def emit_userjs(path, block):
    try:
        with open(path, encoding="utf-8") as handle:
            existing = handle.read()
    except OSError:
        existing = None
    return write_if_changed(path, merge_userjs(existing, block).encode("utf-8"))


def render_firefox(enabled):
    profile = firefox_profile()
    if profile is None:
        sys.stderr.write("firefox: no profile\n")
        return False
    chrome = os.path.join(profile, "chrome")
    palette_path = os.path.join(chrome, "shell-palette.css")
    content_path = os.path.join(chrome, "shell-content.css")
    if not enabled:
        wrote_palette = emit(palette_path, DISABLED_CSS)
        wrote_content = emit(content_path, DISABLED_CSS)
        return wrote_palette or wrote_content
    palette_css = load("firefox-palette.css", tokens)
    content_css = load("firefox-content.css", tokens)
    user_block = load("firefox-user.js", tokens)
    wrote_palette = emit(palette_path, palette_css)
    wrote_content = emit(content_path, content_css)
    wrote_userjs = emit_userjs(os.path.join(profile, "user.js"), user_block)
    return wrote_palette or wrote_content or wrote_userjs


# Spicetify follows the shell through the community `text` theme, vendored as
# the spicetify-color.ini and spicetify-user.css templates. The renderer owns
# Themes/quickshell/ under the app's config root and writes only its own two
# files there, so it never edits a theme the user installed or the user's own
# Spicetify config (selection stays a manual step). An absent config root means
# there is no Spicetify to recolor, so the target skips as success. After a real
# byte change it refreshes the client best-effort; it never runs the
# version-gated restore command, which force-restarts Spotify.
SPICETIFY_COLOR_TEMPLATE = "spicetify-color.ini"
SPICETIFY_USER_TEMPLATE = "spicetify-user.css"


def spicetify_theme():
    """The vendored color.ini text and its own [Spicetify] default values.

    The disabled [Quickshell] layer reads these values straight from the
    shipped template, so the fallback cannot drift from the theme it ships."""
    with open(os.path.join(template_dir, SPICETIFY_COLOR_TEMPLATE),
              encoding="utf-8") as handle:
        text = handle.read()
    for section, values in parse_ini_text(text):
        if section == "Spicetify":
            return text, values
    raise RenderError("no [Spicetify] section in %s" % SPICETIFY_COLOR_TEMPLATE)


def spicetify_disabled_color(text, defaults):
    """The vendored template with [Quickshell]'s palette values replaced by the
    theme's own [Spicetify] defaults, key for key."""
    out = []
    in_quickshell = False
    for line in text.splitlines(keepends=True):
        stripped = line.strip()
        if stripped.startswith("[") and stripped.endswith("]"):
            in_quickshell = stripped[1:-1].strip() == "Quickshell"
            out.append(line)
            continue
        if in_quickshell and "=" in stripped and stripped[0] not in "#;":
            key = stripped.partition("=")[0].strip()
            if key in defaults:
                line = "%s = %s\n" % (key, defaults[key])
        out.append(line)
    result = "".join(out)
    if UNRESOLVED.search(result):
        raise RenderError("unresolved placeholder in %s" % SPICETIFY_COLOR_TEMPLATE)
    return result


def refresh_spicetify():
    """Best-effort refresh; only the on-PATH client, failures never fail the
    run. Only the refresh subcommand is ever invoked."""
    executable = shutil.which("spicetify")
    if executable is None:
        return
    try:
        subprocess.run([executable, "refresh"], check=False, timeout=60,
                       stdin=subprocess.DEVNULL,
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except Exception:
        pass


def render_spicetify(enabled):
    spicetify_root = os.path.join(config_home, "spicetify")
    if not os.path.isdir(spicetify_root):
        sys.stderr.write("spicetify: not installed\n")
        return False
    theme_dir = os.path.join(spicetify_root, "Themes", "quickshell")
    if enabled:
        color = load(SPICETIFY_COLOR_TEMPLATE, tokens)
    else:
        template_text, defaults = spicetify_theme()
        color = spicetify_disabled_color(template_text, defaults)
    css = load(SPICETIFY_USER_TEMPLATE, tokens)
    wrote_color = emit(os.path.join(theme_dir, "color.ini"), color)
    wrote_css = emit(os.path.join(theme_dir, "user.css"), css)
    if wrote_color or wrote_css:
        refresh_spicetify()
    return wrote_color or wrote_css


# Render order.
TARGETS = ("hyprland", "kitty", "hyprlock", "starship", "yazi", "btop",
           "firefox", "vencord", "spicetify")
RENDERERS = {
    "hyprland": render_hyprland,
    "kitty": render_kitty,
    "hyprlock": render_hyprlock,
    "starship": render_starship,
    "yazi": render_yazi,
    "btop": render_btop,
    "firefox": render_firefox,
    "vencord": render_vencord,
    "spicetify": render_spicetify,
}

if enabled_raw == "__ALL__":
    enabled_keys = set(TARGETS)
else:
    enabled_keys = set()
    for entry in enabled_raw.split(","):
        key = entry.strip()
        if key in TARGETS:
            enabled_keys.add(key)

# Each renderer returns whether it wrote, so a target can decide whether a
# change-dependent side effect is due; those side effects (e.g. a Spicetify
# refresh, ticket 05) live inside the renderer, which alone knows whether the
# bytes changed. Catch Exception, not a fixed tuple: a future target's
# unexpected error (configparser, subprocess) must log one clean line and skip
# rather than abort every later target.
failed = False
for key in TARGETS:
    renderer = RENDERERS.get(key)
    if renderer is None:
        continue
    try:
        renderer(key in enabled_keys)
    except Exception as exc:
        sys.stderr.write("%s: %s\n" % (key, exc))
        failed = True

sys.exit(1 if failed else 0)
PY
