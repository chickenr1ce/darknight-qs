# Ticket 05: Spicetify theme (bundled text theme plus a palette option)

**Status:** ready-for-agent
**Blocking:** ticket 04
**Blocked by:** ticket 01

## Objective

Ship the community `text` Spicetify theme as a shell-owned theme whose colors
follow the palette, keeping the theme's own default color options and adding one
palette-built option.

## Acceptance criteria

1. Vendor the upstream theme (MIT, `spicetify/spicetify-themes`, `text/`,
   copyright 2019 morpheusthewhite) as two render templates:
   - `assets/templates/spicetify-user.css`, the upstream `text/user.css`
     verbatim plus the repo banner comment;
   - `assets/templates/spicetify-color.ini`, the upstream `text/color.ini`
     verbatim (every default option: `Spotify`, `Spicetify`, `CatppuccinMocha`,
     `CatppuccinMacchiato`, `CatppuccinLatte`, `Dracula`, `Gruvbox`,
     `GruvboxHard`, `Kanagawa`, `Nord`, `Rigel`, `RosePine`, `RosePineMoon`,
     `RosePineDawn`, `Solarized`, `TokyoNight`, `TokyoNightStorm`,
     `ForestGreen`, `EverforestDarkHard`, `EverforestDarkMedium`,
     `EverforestDarkSoft`, `FlexokiLight`, `FlexokiDark`, `BloodMoon`) plus the
     repo banner comment and an appended `[Quickshell]` section.
   Record the MIT attribution (spicetify-themes `text`) in `NOTICE`.

2. The `[Quickshell]` section sets all thirteen keys the theme's options use from
   the palette with `{{role}}` placeholders: `text` (foreground), `subtext`
   (muted), `main` (background), `highlight` (selection), `header`
   (dark_foreground), `banner` (accent), `accent` (accent), `accent-active`
   (bright_foreground), `accent-inactive` (dark_background), `border-active`
   (accent), `border-inactive` (selection), `notification` (accent),
   `notification-error` (red). The default options above hold no placeholders.

3. Under the target key `spicetify`, title "Spicetify", the renderer writes
   `$XDG_CONFIG_HOME/spicetify/Themes/quickshell/color.ini` and
   `.../quickshell/user.css`, creating the directory when absent. It owns that
   directory whole and never edits a theme the user installed or
   `config-xpui.ini`. When `spicetify` is not installed or its config directory
   is absent, it logs `spicetify: not installed` to stderr, writes nothing, and
   counts as skipped (exit 0).

4. Disabled, the `[Quickshell]` section renders the theme's own `[Spicetify]`
   default values instead of the palette, so a user who selected it sees the
   stock text look; the other default options are untouched.

5. After a write, the renderer runs `spicetify refresh` best-effort (only when
   `spicetify` is on PATH; failures ignored). It never runs `spicetify apply`,
   which is version-gated here (`[Backup] with=2.42.8` versus CLI `2.45.3`) and
   force-restarts Spotify. Document that without a refresh the colors appear on
   the next Spotify start.

6. Selection is a one-time user step (documented in ticket 04): pick the
   `quickshell` theme and its `Quickshell` color option. The renderer never sets
   `current_theme` or `color_scheme`.

7. `scripts/test-panel-logic.sh` section 17 stubs `spicetify` on PATH and uses a
   fixture `XDG_CONFIG_HOME` with a `spicetify` directory. It asserts the theme
   directory gains `color.ini` (all default options present, the `[Quickshell]`
   section carrying palette values, no unresolved token) and `user.css`, that the
   refresh stub was invoked, that the disabled case renders the default values,
   and that a missing `spicetify` directory skips with exit 0.

8. `scripts/check.sh` passes.

## Notes

`text` is not installed on this machine, which is why the shell bundles it; the
renderer owns `Themes/quickshell/` rather than `Themes/text/` so a future
Marketplace install of `text` cannot collide. `spicetify refresh` rewrites the
patched client's CSS without a restart; `spicetify watch -s` would live-reload
but is not required.
